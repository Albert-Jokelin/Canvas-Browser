import Foundation

enum GeminiError: Error {
    case invalidURL
    case noData
    case decodingError
    case missingAPIKey
    case invalidJSONResponse
}

class GeminiService: ObservableObject {
    @Published var apiKey: String = ""
    
    init() {
        // Load from UserDefaults or secure storage
        self.apiKey = UserDefaults.standard.string(forKey: "geminiApiKey") ?? ""
    }
    
    @Published var availableModels: [String] = ["gemini-1.5-flash", "gemini-1.5-pro", "gemini-pro"]
    
    func fetchModels() async throws -> [String] {
        guard !apiKey.isEmpty else { throw GeminiError.missingAPIKey }
        
        var components = URLComponents(string: "https://generativelanguage.googleapis.com/v1beta/models")
        components?.queryItems = [
            URLQueryItem(name: "key", value: apiKey)
        ]
        
        guard let url = components?.url else { throw GeminiError.invalidURL }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        struct ModelListResponse: Codable {
            struct Model: Codable {
                let name: String
                let displayName: String
                let supportedGenerationMethods: [String]
            }
            let models: [Model]
        }
        
        let response = try JSONDecoder().decode(ModelListResponse.self, from: data)
        let chatModels = response.models
            .filter { $0.supportedGenerationMethods.contains("generateContent") }
            .map { $0.name.replacingOccurrences(of: "models/", with: "") }
        
        DispatchQueue.main.async {
            self.availableModels = chatModels
        }
        
        return chatModels
    }
    
    func generateResponse(prompt: String, model: String = "gemini-1.5-flash") async throws -> String {
        guard !apiKey.isEmpty else { throw GeminiError.missingAPIKey }
        
        // Use URLComponents to properly encode query parameters
        var components = URLComponents(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent")
        components?.queryItems = [
            URLQueryItem(name: "key", value: apiKey)
        ]
        
        guard let url = components?.url else { throw GeminiError.invalidURL }
        
        let body: [String: Any] = [
            "contents": [
                ["parts": [["text": prompt]]]
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, httpResponse) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = httpResponse as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown Error"
            print("Gemini API Error: \(errorText)")
            throw GeminiError.invalidURL
        }
        
        struct GenerateContentResponse: Codable {
            struct Candidate: Codable {
                struct Content: Codable {
                    struct Part: Codable {
                        let text: String
                    }
                    let parts: [Part]
                }
                let content: Content
            }
            let candidates: [Candidate]?
        }
        
        let apiResponse = try JSONDecoder().decode(GenerateContentResponse.self, from: data)
        return apiResponse.candidates?.first?.content.parts.first?.text ?? "No response generated."
    }
    
    // MARK: - Dynamic GenTab Generation
    
    func buildGenTab(for prompt: String) async throws -> GenTab {
        // Create a structured prompt that asks Gemini to return JSON
        let structuredPrompt = """
        ### ROLE
        You are the Lead Product Designer for "Canvas macOS." Your task is to transform a user's web-browsing intent into a "GenTab"—a native-feeling, interactive macOS mini-app.

        ### DATA CONTRACT (JSON SCHEMA)
        Your response must be a single, valid JSON object following this strict schema:
        {
        "title": String (Title of the tool),
        "icon": String (Valid Apple SF Symbol name),
        "contentType": "cardGrid" | "listView" | "dashboard",
        "items": [
            {
            "title": String,
            "description": String (Max 60 chars),
            "imageURL": String or null,
            "actionTitle": String (Call to action for this specific item)
            }
        ],
        "availableActions": [String] (3-4 global commands like "Export to PDF", "Add to Calendar", etc.)
        }

        ### DESIGN RULES
        1. SF SYMBOLS: Use only authentic Apple SF Symbols (e.g., 'sparkles', 'safari', 'shippingbox.fill', 'airplane.departure', 'chart.xyaxis.line'). Avoid generic names.
        2. ACTION ORIENTATION: 'actionTitle' should be a verb (e.g., "View Deal", "Book Now", "Track Price").
        3. CONTENT TYPE: Use 'cardGrid' for visual items (products/travel) and 'listView' for data-heavy items (expenses/tasks).
        4. ITEM COUNT: Generate exactly 5 high-quality, relevant items.

        ### USER REQUEST
        "\(prompt)"

        ### OUTPUT INSTRUCTIONS
        - Respond ONLY with the raw JSON. 
        - DO NOT use markdown code blocks (```json ... ```).
        - Ensure all quotes are escaped properly.
        - NO conversational filler.
        """
        
        let jsonResponse = try await generateResponse(prompt: structuredPrompt, model: "gemini-1.5-flash")
        
        // Clean the response (remove markdown fences if present)
        let cleanedJSON = jsonResponse
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Parse JSON
        guard let jsonData = cleanedJSON.data(using: .utf8) else {
            throw GeminiError.invalidJSONResponse
        }
        
        struct GenTabResponse: Codable {
            let title: String
            let icon: String
            let contentType: String
            let items: [CardItemResponse]
            let availableActions: [String]
            
            struct CardItemResponse: Codable {
                let title: String
                let description: String
                let imageURL: String?
                let actionTitle: String
            }
        }
        
        do {
            let response = try JSONDecoder().decode(GenTabResponse.self, from: jsonData)
            
            // Convert to GenTab model
            let items = response.items.map { item in
                CardItem(
                    title: item.title,
                    description: item.description,
                    imageURL: item.imageURL != nil ? URL(string: item.imageURL!) : nil,
                    actionTitle: item.actionTitle
                )
            }
            
            return GenTab(
                title: response.title,
                icon: response.icon,
                contentType: GenTabContentType(rawValue: response.contentType) ?? .cardGrid,
                items: items,
                availableActions: response.availableActions
            )
        } catch {
            print("JSON Decode Error: \(error)")
            print("Response was: \(cleanedJSON)")
            throw GeminiError.decodingError
        }
    }
    
    // MARK: - Intelligent GenTab Detection
    
    func shouldCreateGenTab(for message: String) async -> Bool {
        // Ask Gemini if this message warrants creating a GenTab
        let prompt = """
        Act as a high-precision Intent Classifier for "Canvas Browser macOS," an agentic browser. Your goal is to determine if a user’s request requires a "GenTab" (a dynamic, interactive UI tool) or just a standard chat response.

        USER MESSAGE: "\(message)"

        CRITERIA FOR YES (GenTab):
        1. MULTI-SOURCE SYNTHESIS: Does the user need to aggregate or compare data across multiple tabs/websites?
        2. PERSISTENT UTILITY: Is this something the user will interact with more than once (e.g., a tracker, a dashboard, a filtered view)?
        3. FUNCTIONAL LOGIC: Does the request involve math, sorting, filtering, or status-tracking (e.g., "Which flight is the best value?")?
        4. DATA VISUALIZATION: Does the user need a chart, map, or grid layout to understand the info?
        5. Anything else you think can be visualized well using reactJS rather than text

        CRITERIA FOR NO (Chat):
        1. LINEAR INFORMATION: Simple facts, explanations, or "Tell me a story/joke."
        2. TEXT-ONLY SUMMARIES: "What does this page say?" without a request for a tool.
        3. SYSTEM COMMANDS: "Open a new tab," "Change theme," "Close Safari."

        EXAMPLES:
        - "Find me the best price for an M3 MacBook across these tabs." -> YES (Comparison Tool)
        - "What is the capital of France?" -> NO (Fact)
        - "Help me track my water intake today." -> YES (Tracker Tool)
        - "Summarize this long legal PDF." -> NO (Text Summary)
        - "Show these apartment listings on a map." -> YES (Interactive Map)

        RESPONSE FORMAT:
        Answer with a single word: YES or NO.
        """
        
        do {
            let response = try await generateResponse(prompt: prompt, model: "gemini-1.5-flash")
            return response.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == "YES"
        } catch {
            return false
        }
    }
    
    // MARK: - GenTab from URL Analysis
    
    func analyzeURLsForGenTab(urls: [String], titles: [String]) async throws -> GenTab? {
        let urlList = zip(urls, titles).map { "- \($1): \($0)" }.joined(separator: "\n")
        
        let prompt = """
        The user has visited these pages:
        \(urlList)
        
        Detect their intent and create a helpful GenTab. Respond with ONLY valid JSON:
        {
            "title": "Intent-based title",
            "icon": "SF Symbol name",
            "contentType": "cardGrid",
            "items": [
                {
                    "title": "Item from browsing",
                    "description": "Helpful info",
                    "imageURL": null,
                    "actionTitle": "Action"
                }
            ],
            "availableActions": ["Relevant", "Actions"]
        }
        
        If no clear intent, respond with: {"title": null}
        """
        
        let jsonResponse = try await generateResponse(prompt: prompt, model: "gemini-1.5-flash")
        let cleanedJSON = jsonResponse
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let jsonData = cleanedJSON.data(using: .utf8) else {
            return nil
        }
        
        struct IntentResponse: Codable {
            let title: String?
        }
        
        let intentCheck = try JSONDecoder().decode(IntentResponse.self, from: jsonData)
        
        if intentCheck.title == nil {
            return nil // No intent detected
        }
        
        // Parse full GenTab
        return try await buildGenTab(for: "Based on: \(urlList)")
    }
}
