import Foundation

enum ClaudeError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError
    case missingAPIKey
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .decodingError:
            return "Failed to decode response"
        case .missingAPIKey:
            return "Claude API key is not configured"
        case .apiError(let message):
            return "API Error: \(message)"
        }
    }
}

class ClaudeService: ObservableObject {
    @Published var apiKey: String = ""
    @Published var availableModels: [String] = [
        "claude-sonnet-4-20250514",
        "claude-3-5-sonnet-20241022",
        "claude-3-5-haiku-20241022",
        "claude-3-opus-20240229"
    ]

    private let baseURL = "https://api.anthropic.com/v1"
    private let apiVersion = "2023-06-01"

    init() {
        self.apiKey = UserDefaults.standard.string(forKey: "claudeApiKey") ?? ""
    }

    func generateResponse(prompt: String, model: String = "claude-sonnet-4-20250514", systemPrompt: String? = nil) async throws -> String {
        guard !apiKey.isEmpty else { throw ClaudeError.missingAPIKey }

        let urlString = "\(baseURL)/messages"
        guard let url = URL(string: urlString) else { throw ClaudeError.invalidURL }

        // Build messages array
        let messages: [[String: Any]] = [
            ["role": "user", "content": prompt]
        ]

        // Build request body
        var body: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "messages": messages
        ]

        if let system = systemPrompt {
            body["system"] = system
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, httpResponse) = try await URLSession.shared.data(for: request)

        guard let httpResponse = httpResponse as? HTTPURLResponse else {
            throw ClaudeError.noData
        }

        if httpResponse.statusCode != 200 {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown Error"
            print("Claude API Error (\(httpResponse.statusCode)): \(errorText)")
            throw ClaudeError.apiError(errorText)
        }

        // Parse response
        struct MessageResponse: Codable {
            struct Content: Codable {
                let type: String
                let text: String?
            }
            let id: String
            let content: [Content]
            let model: String
            let role: String
        }

        let response = try JSONDecoder().decode(MessageResponse.self, from: data)
        let textContent = response.content.first { $0.type == "text" }?.text ?? "No response generated."
        return textContent
    }

    /// Chat with conversation history support
    func chat(messages: [(role: String, content: String)], model: String = "claude-sonnet-4-20250514", systemPrompt: String? = nil) async throws -> String {
        guard !apiKey.isEmpty else { throw ClaudeError.missingAPIKey }

        let urlString = "\(baseURL)/messages"
        guard let url = URL(string: urlString) else { throw ClaudeError.invalidURL }

        // Build messages array
        let messagesArray = messages.map { ["role": $0.role, "content": $0.content] }

        var body: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "messages": messagesArray
        ]

        if let system = systemPrompt {
            body["system"] = system
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, httpResponse) = try await URLSession.shared.data(for: request)

        guard let httpResponse = httpResponse as? HTTPURLResponse else {
            throw ClaudeError.noData
        }

        if httpResponse.statusCode != 200 {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown Error"
            throw ClaudeError.apiError(errorText)
        }

        struct MessageResponse: Codable {
            struct Content: Codable {
                let type: String
                let text: String?
            }
            let content: [Content]
        }

        let response = try JSONDecoder().decode(MessageResponse.self, from: data)
        return response.content.first { $0.type == "text" }?.text ?? "No response generated."
    }

    /// Build a GenTab based on a prompt using Claude
    func buildGenTab(for prompt: String) async throws -> GenTab {
        let systemPrompt = """
        You are a helpful assistant that creates structured data for visualizations.
        When asked to create something, respond with JSON in this exact format:
        {
            "title": "Tab Title",
            "icon": "sf.symbol.name",
            "items": [
                {"title": "Item 1", "description": "Description 1"},
                {"title": "Item 2", "description": "Description 2"}
            ],
            "actions": ["Action 1", "Action 2"]
        }
        Only respond with valid JSON, no other text.
        """

        let response = try await generateResponse(
            prompt: "Create a visualization for: \(prompt)",
            systemPrompt: systemPrompt
        )

        // Try to parse JSON response
        if let jsonData = response.data(using: .utf8) {
            struct GenTabResponse: Codable {
                let title: String
                let icon: String?
                let items: [ItemResponse]?
                let actions: [String]?

                struct ItemResponse: Codable {
                    let title: String
                    let description: String
                }
            }

            if let parsed = try? JSONDecoder().decode(GenTabResponse.self, from: jsonData) {
                return GenTab(
                    title: parsed.title,
                    icon: parsed.icon ?? "sparkles",
                    contentType: .cardGrid,
                    items: (parsed.items ?? []).map { item in
                        CardItem(
                            title: item.title,
                            description: item.description,
                            imageURL: nil,
                            actionTitle: "View"
                        )
                    },
                    availableActions: parsed.actions ?? ["Refine", "Export"]
                )
            }
        }

        // Fallback if parsing fails
        return GenTab(
            title: "Generated Content",
            icon: "sparkles",
            contentType: .cardGrid,
            items: [
                CardItem(
                    title: "AI Response",
                    description: response,
                    imageURL: nil,
                    actionTitle: "View Details"
                )
            ],
            availableActions: ["Refine", "Export"]
        )
    }
}
