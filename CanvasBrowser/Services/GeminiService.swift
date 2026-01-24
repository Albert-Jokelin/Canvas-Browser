import Foundation

enum GeminiError: LocalizedError {
    case invalidURL
    case noData
    case decodingError
    case missingAPIKey
    case invalidJSONResponse
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL for Gemini API"
        case .noData:
            return "No data received from Gemini API"
        case .decodingError:
            return "Failed to parse Gemini API response"
        case .missingAPIKey:
            return "Gemini API key is missing. Please add it in Settings."
        case .invalidJSONResponse:
            return "Invalid JSON response from Gemini API"
        case .apiError(let message):
            return "Gemini API error: \(message)"
        }
    }
}

class GeminiService: ObservableObject {
    @Published var apiKey: String = ""

    /// The model to use - loaded from UserDefaults
    var selectedModel: String {
        UserDefaults.standard.string(forKey: "aiModel") ?? "gemini-2.0-flash"
    }

    init() {
        // Load from UserDefaults or secure storage
        self.apiKey = UserDefaults.standard.string(forKey: "geminiApiKey") ?? ""
    }

    @Published var availableModels: [String] = ["gemini-2.0-flash", "gemini-2.0-flash-lite", "gemini-1.5-pro"]
    
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
    
    func generateResponse(prompt: String, model: String? = nil) async throws -> String {
        guard !apiKey.isEmpty else { throw GeminiError.missingAPIKey }

        let modelToUse = model ?? selectedModel

        // Use URLComponents to properly encode query parameters
        var components = URLComponents(string: "https://generativelanguage.googleapis.com/v1beta/models/\(modelToUse):generateContent")
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
            // Parse error message if possible
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorData["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw GeminiError.apiError(message)
            }
            throw GeminiError.apiError(errorText)
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
    
    // MARK: - Locale Information

    /// Get system locale information for context-aware responses
    private var localeContext: String {
        let locale = Locale.current
        let currency = locale.currency?.identifier ?? "USD"
        let currencySymbol = locale.currencySymbol ?? "$"
        let measurementSystem = Locale.current.measurementSystem == .metric ? "metric" : "imperial"
        let region = locale.region?.identifier ?? "US"
        let language = locale.language.languageCode?.identifier ?? "en"
        let timezone = TimeZone.current.identifier

        return """
        User Locale:
        - Currency: \(currency) (\(currencySymbol))
        - Measurement System: \(measurementSystem) (use km/kg for metric, miles/lbs for imperial)
        - Region: \(region)
        - Language: \(language)
        - Timezone: \(timezone)
        """
    }

    // MARK: - Dynamic GenTab Generation (Component-Based)

    func buildGenTab(for prompt: String, sourceURLs: [SourceAttribution] = []) async throws -> GenTab {
        // Create a structured prompt for the component-based system
        let structuredPrompt = """
        ### ROLE
        You are the Lead Product Designer for "Canvas macOS." Create a "GenTab"—a dynamic, interactive mini-app using flexible components.

        ### LOCALIZATION
        \(localeContext)
        Use the user's currency and measurement system in all outputs. Format prices, distances, weights, and temperatures according to their locale.

        ### COMPONENT SCHEMA
        Respond with JSON matching this exact structure:
        {
          "title": "string",
          "icon": "SF Symbol name (e.g., cart.fill, airplane, book.fill)",
          "components": [
            {"type": "header", "text": "Section Title"},
            {"type": "paragraph", "text": "Descriptive text..."},
            {"type": "bulletList", "items": ["Item 1", "Item 2", "Item 3"]},
            {"type": "numberedList", "items": ["Step 1", "Step 2", "Step 3"]},
            {"type": "table", "columns": ["Col1", "Col2", "Col3"], "rows": [["a", "b", "c"], ["d", "e", "f"]]},
            {"type": "cardGrid", "cards": [
              {"title": "Card Title", "subtitle": "Optional", "description": "Details", "imageURL": null, "sourceURL": "https://...", "metadata": {"actionTitle": "View"}}
            ]},
            {"type": "map", "locations": [{"title": "Place", "latitude": 37.7749, "longitude": -122.4194}]},
            {"type": "keyValue", "pairs": [{"key": "Price", "value": "$99"}, {"key": "Rating", "value": "4.5/5"}]},
            {"type": "callout", "calloutType": "tip|warning|info|price", "text": "Important note..."},
            {"type": "divider"},
            {"type": "link", "title": "Link Text", "url": "https://..."}
          ]
        }

        ### COMPONENT SELECTION GUIDE
        Choose components based on content type:
        - **Product comparisons**: table + cardGrid + price callouts
        - **Travel planning**: cardGrid + map + numberedList for itinerary
        - **Research/study**: headers + paragraphs + bulletLists
        - **Recipes**: cardGrid + bulletList for ingredients + numberedList for steps
        - **Price tracking**: table + keyValue pairs + price callouts
        - **News/articles**: cardGrid with article cards

        ### DESIGN RULES
        1. Use authentic Apple SF Symbols (cart.fill, airplane, book.fill, chart.bar.fill, etc.)
        2. Keep descriptions concise (max 100 chars)
        3. Use tables for comparisons, cardGrid for visual items
        4. Add callouts for tips, warnings, or price highlights
        5. Structure content logically with headers and dividers

        ### USER REQUEST
        "\(prompt)"

        ### OUTPUT
        Respond ONLY with valid JSON. No markdown, no explanation.
        """

        let jsonResponse = try await generateResponse(prompt: structuredPrompt)

        // Clean the response
        let cleanedJSON = jsonResponse
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = cleanedJSON.data(using: .utf8) else {
            throw GeminiError.invalidJSONResponse
        }

        // Decode the new component-based structure
        struct GenTabResponse: Codable {
            let title: String
            let icon: String
            let components: [GenTabComponent]
        }

        do {
            let response = try JSONDecoder().decode(GenTabResponse.self, from: jsonData)

            return GenTab(
                title: response.title,
                icon: response.icon,
                components: response.components,
                sourceURLs: sourceURLs
            )
        } catch {
            print("JSON Decode Error: \(error)")
            print("Response was: \(cleanedJSON.prefix(500))")
            throw GeminiError.decodingError
        }
    }

    // MARK: - Legacy GenTab Builder (for backward compatibility)

    func buildLegacyGenTab(for prompt: String) async throws -> GenTab {
        let structuredPrompt = """
        Create a GenTab with this JSON format:
        {
          "title": "string",
          "icon": "SF Symbol",
          "contentType": "cardGrid",
          "items": [{"title": "...", "description": "...", "imageURL": null, "actionTitle": "View"}],
          "availableActions": ["Action 1", "Action 2"]
        }

        Request: "\(prompt)"
        Respond with JSON only.
        """

        let jsonResponse = try await generateResponse(prompt: structuredPrompt)

        let cleanedJSON = jsonResponse
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = cleanedJSON.data(using: .utf8) else {
            throw GeminiError.invalidJSONResponse
        }

        struct LegacyResponse: Codable {
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

        let response = try JSONDecoder().decode(LegacyResponse.self, from: jsonData)

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
            let response = try await generateResponse(prompt: prompt)
            return response.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == "YES"
        } catch {
            return false
        }
    }
    
    // MARK: - GenTab from URL Analysis

    func analyzeURLsForGenTab(urls: [String], titles: [String]) async throws -> GenTab? {
        let urlList = zip(urls, titles).map { "- \($1): \($0)" }.joined(separator: "\n")

        // First check if there's a clear intent
        let intentPrompt = """
        The user has visited these pages:
        \(urlList)

        Is there a clear intent that would benefit from an interactive GenTab?
        Answer YES or NO only.
        """

        let intentResponse = try await generateResponse(prompt: intentPrompt)
        let hasIntent = intentResponse.trimmingCharacters(in: .whitespacesAndNewlines).uppercased().contains("YES")

        if !hasIntent {
            return nil
        }

        // Create source attributions from URLs
        let sourceAttrs = zip(urls, titles).map { url, title in
            let domain = URL(string: url)?.host ?? url
            return SourceAttribution(url: url, title: title, domain: domain)
        }

        // Build the GenTab with source attributions
        return try await buildGenTab(
            for: "Create a helpful GenTab based on this browsing context:\n\(urlList)",
            sourceURLs: sourceAttrs
        )
    }

    // MARK: - Modify Existing GenTab

    /// Modify an existing GenTab based on user instructions
    func modifyGenTab(_ existingGenTab: GenTab, instruction: String) async throws -> GenTab {
        // Encode current GenTab to JSON for context
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let currentJSON = try? encoder.encode(existingGenTab.components)
        let currentJSONString = currentJSON.flatMap { String(data: $0, encoding: .utf8) } ?? "[]"

        let modifyPrompt = """
        ### ROLE
        You are modifying an existing GenTab based on user instructions.

        ### LOCALIZATION
        \(localeContext)
        Use the user's currency and measurement system in all outputs.

        ### CURRENT GENTAB
        Title: \(existingGenTab.title)
        Icon: \(existingGenTab.icon)
        Components:
        \(currentJSONString)

        ### USER INSTRUCTION
        "\(instruction)"

        ### COMPONENT SCHEMA
        Respond with JSON matching this exact structure:
        {
          "title": "string (keep or modify based on instruction)",
          "icon": "SF Symbol name",
          "components": [
            {"type": "header", "text": "Section Title"},
            {"type": "paragraph", "text": "Descriptive text..."},
            {"type": "bulletList", "items": ["Item 1", "Item 2"]},
            {"type": "numberedList", "items": ["Step 1", "Step 2"]},
            {"type": "table", "columns": ["Col1", "Col2"], "rows": [["a", "b"]]},
            {"type": "cardGrid", "cards": [{"title": "...", "subtitle": "...", "description": "..."}]},
            {"type": "keyValue", "pairs": [{"key": "Key", "value": "Value"}]},
            {"type": "callout", "calloutType": "tip|warning|info|price", "text": "..."},
            {"type": "divider"},
            {"type": "link", "title": "Link Text", "url": "https://..."}
          ]
        }

        ### INSTRUCTIONS
        - Apply the user's modification to the existing GenTab
        - Keep relevant existing content unless the user wants it removed
        - You can add, remove, or modify components as requested
        - Respond ONLY with valid JSON. No markdown, no explanation.
        """

        let jsonResponse = try await generateResponse(prompt: modifyPrompt)

        // Clean the response
        let cleanedJSON = jsonResponse
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = cleanedJSON.data(using: .utf8) else {
            throw GeminiError.invalidJSONResponse
        }

        struct GenTabResponse: Codable {
            let title: String
            let icon: String
            let components: [GenTabComponent]
        }

        do {
            let response = try JSONDecoder().decode(GenTabResponse.self, from: jsonData)

            return GenTab(
                id: existingGenTab.id, // Keep the same ID
                title: response.title,
                icon: response.icon,
                components: response.components,
                sourceURLs: existingGenTab.sourceURLs // Keep original sources
            )
        } catch {
            print("JSON Decode Error: \(error)")
            print("Response was: \(cleanedJSON.prefix(500))")
            throw GeminiError.decodingError
        }
    }
}
