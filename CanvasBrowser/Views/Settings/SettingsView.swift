import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            BrowserSettingsView()
                .tabItem {
                    Label("Browser", systemImage: "safari")
                }

            AISettingsView()
                .tabItem {
                    Label("AI Features", systemImage: "brain")
                }

            PrivacySettingsView()
                .tabItem {
                    Label("Privacy", systemImage: "hand.raised.fill")
                }

            AccountSettingsView(account: UserAccount.shared)
                .tabItem {
                    Label("Account", systemImage: "person.circle")
                }

            ShortcutsSettingsView()
                .tabItem {
                    Label("Shortcuts", systemImage: "command")
                }
        }
        .padding()
        .frame(width: 550, height: 450)
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @AppStorage("defaultSearchEngine") var defaultSearchEngine = "Google"
    @AppStorage("theme") var theme = "System"

    var body: some View {
        Form {
            Picker("Search Engine", selection: $defaultSearchEngine) {
                Text("Google").tag("Google")
                Text("DuckDuckGo").tag("DuckDuckGo")
                Text("Bing").tag("Bing")
            }

            Picker("Theme", selection: $theme) {
                Text("System").tag("System")
                Text("Light").tag("Light")
                Text("Dark").tag("Dark")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Browser Settings

struct BrowserSettingsView: View {
    @AppStorage("blockPopups") var blockPopups = true
    @AppStorage("enableJavaScript") var enableJavaScript = true

    var body: some View {
        Form {
            Toggle("Block Pop-up Windows", isOn: $blockPopups)
            Toggle("Enable JavaScript", isOn: $enableJavaScript)

            Section("Downloads") {
                LabeledContent("Download Location", value: "Downloads")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - AI Settings

struct AISettingsView: View {
    @AppStorage("aiProvider") var aiProvider = "gemini"
    @AppStorage("aiModel") var aiModel = "gemini-1.5-flash"
    @AppStorage("geminiApiKey") var geminiApiKey = ""
    @AppStorage("claudeApiKey") var claudeApiKey = ""
    @AppStorage("claudeModel") var claudeModel = "claude-sonnet-4-20250514"
    @AppStorage("enableAutoSuggest") var enableAutoSuggest = true

    @StateObject private var geminiService = GeminiService()
    @StateObject private var claudeService = ClaudeService()
    @State private var isFetching = false
    @State private var fetchError: String?

    var body: some View {
        Form {
            Section("AI Provider") {
                Picker("Provider", selection: $aiProvider) {
                    Text("Google Gemini").tag("gemini")
                    Text("Anthropic Claude").tag("claude")
                }
                .pickerStyle(.segmented)
            }

            if aiProvider == "gemini" {
                Section("Gemini Configuration") {
                    HStack {
                        SecureField("Gemini API Key", text: $geminiApiKey)
                            .textFieldStyle(.roundedBorder)

                        if !geminiApiKey.isEmpty {
                            Image(systemName: CanvasSymbols.success)
                                .foregroundColor(.canvasGreen)
                        }
                    }

                    HStack {
                        Picker("Model", selection: $aiModel) {
                            ForEach(geminiService.availableModels, id: \.self) { model in
                                Text(model).tag(model)
                            }
                        }
                        .disabled(geminiService.availableModels.isEmpty)

                        Button(action: fetchGeminiModels) {
                            if isFetching {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Text("Refresh")
                            }
                        }
                    }

                    Link("Get API Key", destination: URL(string: "https://aistudio.google.com/app/apikey")!)
                        .font(.caption)
                }
            } else {
                Section("Claude Configuration") {
                    HStack {
                        SecureField("Claude API Key", text: $claudeApiKey)
                            .textFieldStyle(.roundedBorder)

                        if !claudeApiKey.isEmpty {
                            Image(systemName: CanvasSymbols.success)
                                .foregroundColor(.canvasGreen)
                        }
                    }

                    Picker("Model", selection: $claudeModel) {
                        ForEach(claudeService.availableModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }

                    Link("Get API Key", destination: URL(string: "https://console.anthropic.com/")!)
                        .font(.caption)
                }
            }

            if let error = fetchError {
                Text("Error: \(error)")
                    .font(.caption)
                    .foregroundColor(.red)
            }

            Section("Behavior") {
                Toggle("Proactive Suggestions", isOn: $enableAutoSuggest)
                Text("Allows Canvas to analyze browsing patterns to suggest GenTabs.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .onChange(of: geminiApiKey) { _, newValue in
            let sanitized = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if sanitized != newValue {
                geminiApiKey = sanitized
            }
            geminiService.apiKey = sanitized
        }
        .onChange(of: claudeApiKey) { _, newValue in
            claudeService.apiKey = newValue
        }
    }

    private func fetchGeminiModels() {
        isFetching = true
        Task {
            geminiService.apiKey = geminiApiKey
            do {
                _ = try await geminiService.fetchModels()
                fetchError = nil
            } catch {
                fetchError = error.localizedDescription
            }
            isFetching = false
        }
    }
}

// MARK: - Privacy Settings

struct PrivacySettingsView: View {
    @AppStorage("doNotTrack") var doNotTrack = true

    var body: some View {
        Form {
            Toggle("Send 'Do Not Track' Request", isOn: $doNotTrack)

            Button("Clear Browsing Data...") {
                // TODO: Implement clear data action
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Account Settings

struct AccountSettingsView: View {
    @ObservedObject var account: UserAccount

    var body: some View {
        Form {
            Section("Profile") {
                HStack {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 60, height: 60)
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading) {
                        Text(account.name)
                            .font(.headline)
                        Text(account.email)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Button("Edit Profile") { }
            }

            Section("Sync") {
                Toggle("Sync History", isOn: $account.syncHistory)
                Toggle("Sync Bookmarks", isOn: $account.syncBookmarks)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Shortcuts Settings

struct ShortcutsSettingsView: View {
    var body: some View {
        KeyboardShortcutsReferenceView()
    }
}
