import SwiftUI

struct ChatPanelView: View {
    var onClose: () -> Void

    @State private var inputMessage: String = ""
    @State private var messages: [ChatMessage] = [
        ChatMessage(role: .assistant, content: "Hello! I'm your Canvas AI assistant. How can I help you today?")
    ]
    @State private var isLoading = false
    @EnvironmentObject var appState: AppState

    @AppStorage("aiModel") var aiModel = "gemini-2.0-flash"

    /// Access the shared GeminiService through the orchestrator
    private var geminiService: GeminiService {
        appState.aiOrchestrator.geminiService
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with Apple gradient (indigo to teal instead of purple)
            HStack {
                HStack(spacing: CanvasSpacing.sm) {
                    Image(systemName: CanvasSymbols.aiSpark)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.canvasAIGradientStart, .canvasAIGradientEnd],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .font(.system(size: 18, weight: .semibold))

                    Text("Canvas AI")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.canvasLabel)
                }

                Spacer()

                HStack(spacing: CanvasSpacing.xs) {
                    Button(action: { messages = [] }) {
                        Image(systemName: CanvasSymbols.delete)
                            .foregroundColor(.canvasSecondaryLabel)
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                    .help("Clear conversation")

                    Button(action: onClose) {
                        Image(systemName: CanvasSymbols.close)
                            .foregroundColor(.canvasSecondaryLabel)
                            .font(.system(size: 16))
                    }
                    .buttonStyle(.plain)
                    .help("Close chat panel")
                }
            }
            .padding(.horizontal, CanvasSpacing.lg)
            .padding(.vertical, CanvasSpacing.md)
            .background(
                LinearGradient(
                    colors: [
                        Color.canvasSecondaryBackground,
                        Color.canvasSecondaryBackground.opacity(0.95)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            Divider()

            // Messages List
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }

                        if isLoading {
                            LoadingIndicator()
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _, _ in
                    if let lastId = messages.last?.id {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Input Area with modern styling
            VStack(spacing: 8) {
                HStack(alignment: .bottom, spacing: 12) {
                    TextField("Ask anything...", text: $inputMessage, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(1...5)
                        .onSubmit {
                            sendMessage()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(NSColor.textBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        )

                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(
                                inputMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading
                                ? Color.canvasSecondaryLabel.opacity(0.5)
                                : Color.canvasBlue
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(inputMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                }
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .background(Color(NSColor.windowBackgroundColor))
        .onReceive(NotificationCenter.default.publisher(for: .voiceAIQuery)) { notification in
            if let query = notification.userInfo?["query"] as? String {
                injectVoiceQuery(query)
            }
        }
    }

    private func injectVoiceQuery(_ query: String) {
        let userMsg = ChatMessage(role: .user, content: query)
        messages.append(userMsg)
        isLoading = true

        Task {
            do {
                if geminiService.apiKey.isEmpty {
                    try await Task.sleep(nanoseconds: 500_000_000)
                    messages.append(ChatMessage(role: .assistant, content: "Please set your Gemini API Key in Settings to chat with me."))
                } else {
                    var history: [(role: String, content: String)] = []
                    for msg in messages {
                        let role = msg.role == .user ? "user" : "model"
                        history.append((role: role, content: msg.content))
                    }
                    let response = try await geminiService.generateConversationResponse(history: history, model: aiModel)
                    messages.append(ChatMessage(role: .assistant, content: response))
                }
            } catch {
                messages.append(ChatMessage(role: .assistant, content: "Error: \(error.localizedDescription)"))
            }
            isLoading = false
        }
    }

    private func sendMessage() {
        let text = inputMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let userMsg = ChatMessage(role: .user, content: text)
        messages.append(userMsg)
        inputMessage = ""
        isLoading = true

        Task {
            do {
                if geminiService.apiKey.isEmpty {
                    try await Task.sleep(nanoseconds: 500_000_000)
                    messages.append(ChatMessage(role: .assistant, content: "Please set your Gemini API Key in Settings to chat with me."))
                } else {
                    let lowerText = text.lowercased()
                    if lowerText.contains("gentab") || lowerText.contains("build") || lowerText.contains("garden") || lowerText.contains("plan") {

                        messages.append(ChatMessage(role: .assistant, content: "Sure, I'm analyzing your request to build a GenTab..."))

                        let genTab = try await buildContextAwareGenTab(for: text)

                        await MainActor.run {
                            appState.sessionManager.addGenTab(genTab)
                        }

                        messages.append(ChatMessage(role: .assistant, content: "Done! I've created the '\(genTab.title)' GenTab for you."))

                    } else {
                        // Build conversation history for multi-turn context
                        var history: [(role: String, content: String)] = []
                        for msg in messages {
                            let role = msg.role == .user ? "user" : "model"
                            history.append((role: role, content: msg.content))
                        }

                        // Enrich the latest user message with current page context
                        if let currentTab = appState.sessionManager.currentTab, case .web(let webTab) = currentTab {
                            if let lastIndex = history.indices.last, history[lastIndex].role == "user" {
                                history[lastIndex].content = "Current Context: \(webTab.title) (\(webTab.url.absoluteString))\n\nUser Query: \(history[lastIndex].content)"
                            }
                        }

                        let response = try await geminiService.generateConversationResponse(history: history, model: aiModel)
                        messages.append(ChatMessage(role: .assistant, content: response))
                    }
                }
            } catch {
                messages.append(ChatMessage(role: .assistant, content: "Error: \(error.localizedDescription)"))
            }
            isLoading = false
        }
    }

    private func buildContextAwareGenTab(for userText: String) async throws -> GenTab {
        guard let currentTab = appState.sessionManager.currentTab,
              case .web(let webTab) = currentTab,
              let webView = appState.sessionManager.webViewCache[webTab.id] else {
            return try await geminiService.buildGenTab(for: userText)
        }

        let contentExtractor = ContentExtractor.shared
        let selection = await contentExtractor.extractSelection(from: webView)
        let extracted = await contentExtractor.extractContent(from: webView, tabId: webTab.id)

        var contextParts: [String] = []
        if let selection = selection {
            contextParts.append("Selected Text:\n\(selection)")
        }

        var sources: [SourceAttribution] = []
        if let extracted = extracted {
            contextParts.append("Page Title: \(extracted.title)")
            contextParts.append("Page URL: \(extracted.url)")
            if let description = extracted.metaDescription, !description.isEmpty {
                contextParts.append("Summary: \(description)")
            } else if !extracted.textContent.isEmpty {
                let summary = String(extracted.textContent.prefix(800))
                contextParts.append("Summary: \(summary)")
            }
            sources.append(SourceAttribution(url: extracted.url, title: extracted.title, domain: extracted.domain))
        } else {
            contextParts.append("Page Title: \(webTab.title)")
            contextParts.append("Page URL: \(webTab.url.absoluteString)")
            sources.append(SourceAttribution(url: webTab.url.absoluteString, title: webTab.title, domain: webTab.url.host ?? webTab.url.absoluteString))
        }

        let contextBlock = contextParts.joined(separator: "\n")
        let finalPrompt = """
        Create a GenTab using the context below.

        \(contextBlock)

        User Request: "\(userText)"
        """

        return try await geminiService.buildGenTab(for: finalPrompt, sourceURLs: sources)
    }
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    let content: String

    enum Role {
        case user
        case assistant
    }
}

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: CanvasSpacing.md) {
            if message.role == .assistant {
                // AI Avatar with Apple gradient (indigo to teal)
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.canvasAIGradientStart.opacity(0.2), .canvasAIGradientEnd.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)

                    Image(systemName: CanvasSymbols.aiSpark)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.canvasAIGradientStart, .canvasAIGradientEnd],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .font(.system(size: 14, weight: .medium))
                }
            } else {
                Spacer()
            }

            Group {
                if message.role == .assistant {
                    // Use markdown rendering for AI responses
                    MarkdownText(message.content, fontSize: 14)
                } else {
                    // Plain text for user messages
                    Text(message.content)
                        .font(.system(size: 14))
                }
            }
            .padding(CanvasSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: CanvasRadius.large)
                    .fill(message.role == .user
                        ? LinearGradient(
                            colors: [.canvasBlue.opacity(0.15), .canvasTeal.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(
                            colors: [Color.canvasTertiaryBackground, Color.canvasTertiaryBackground],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .foregroundColor(.canvasLabel)

            if message.role == .user {
                // User Avatar
                ZStack {
                    Circle()
                        .fill(Color.canvasSecondaryLabel.opacity(0.2))
                        .frame(width: 32, height: 32)

                    Image(systemName: "person.fill")
                        .foregroundColor(.canvasSecondaryLabel)
                        .font(.system(size: 14))
                }
            } else {
                Spacer()
            }
        }
    }
}

struct LoadingIndicator: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(alignment: .top, spacing: CanvasSpacing.md) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.canvasAIGradientStart.opacity(0.2), .canvasAIGradientEnd.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)

                Image(systemName: CanvasSymbols.aiSpark)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.canvasAIGradientStart, .canvasAIGradientEnd],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .font(.system(size: 14, weight: .medium))
            }

            HStack(spacing: CanvasSpacing.xs) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.canvasAIAccent)
                        .frame(width: 8, height: 8)
                        .scaleEffect(isAnimating ? 1.0 : 0.5)
                        .animation(
                            .easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                            value: isAnimating
                        )
                }
            }
            .padding(CanvasSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: CanvasRadius.large)
                    .fill(Color.canvasTertiaryBackground)
            )

            Spacer()
        }
        .onAppear {
            isAnimating = true
        }
    }
}
