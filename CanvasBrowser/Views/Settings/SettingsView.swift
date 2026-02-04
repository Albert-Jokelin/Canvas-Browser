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

            MCPSettingsView()
                .tabItem {
                    Label("MCP", systemImage: "cpu")
                }

            iCloudSettingsView()
                .tabItem {
                    Label("iCloud", systemImage: "icloud")
                }

            FocusSettingsView()
                .tabItem {
                    Label("Focus", systemImage: "moon.fill")
                }

            PrivacySettingsView()
                .tabItem {
                    Label("Privacy", systemImage: "hand.raised.fill")
                }

            UpdateSettingsView()
                .tabItem {
                    Label("Updates", systemImage: "arrow.down.circle")
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
        .frame(width: 650, height: 560)
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

            Section("Apple Developer Program Required") {
                Text("These features are disabled without a paid Apple Developer Program membership:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("- iCloud / CloudKit sync\n- Apple Pay in web checkout\n- Widget data sync (App Groups)")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
    @AppStorage("aiModel") var aiModel = "gemini-2.0-flash"
    @AppStorage("claudeModel") var claudeModel = "claude-sonnet-4-20250514"
    @AppStorage("enableAutoSuggest") var enableAutoSuggest = true
    @AppStorage("enableAIWebSearch") var enableAIWebSearch = false
    @AppStorage("autoThinkingMode") var autoThinkingMode = true
    @AppStorage("thinkingBudgetTokens") var thinkingBudgetTokens: Double = 8192

    // API keys stored in Keychain, with local state for editing
    @State private var geminiApiKey: String = ""
    @State private var claudeApiKey: String = ""

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

            Section("Web Search") {
                Toggle("Enable AI Web Search", isOn: $enableAIWebSearch)
                Text("Allow AI to search the internet for current information like news, weather, and prices.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Thinking Mode") {
                Toggle("Auto Thinking Mode", isOn: $autoThinkingMode)
                Text("Automatically enable extended thinking for complex queries that benefit from deeper analysis.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if autoThinkingMode {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Thinking Budget: \(Int(thinkingBudgetTokens)) tokens")
                            .font(.subheadline)
                        Slider(value: $thinkingBudgetTokens, in: 1024...24576, step: 1024)
                    }
                    Text("Higher budgets allow for more thorough reasoning but may increase response time.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            // Load API keys from UserDefaults
            geminiApiKey = UserDefaults.standard.string(forKey: "geminiApiKey") ?? ""
            claudeApiKey = UserDefaults.standard.string(forKey: "claudeApiKey") ?? ""
        }
        .onChange(of: geminiApiKey) { _, newValue in
            let sanitized = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if sanitized != newValue {
                geminiApiKey = sanitized
                return
            }
            // Save to UserDefaults and update service
            if !sanitized.isEmpty {
                UserDefaults.standard.set(sanitized, forKey: "geminiApiKey")
            } else {
                UserDefaults.standard.removeObject(forKey: "geminiApiKey")
            }
            geminiService.apiKey = sanitized
        }
        .onChange(of: claudeApiKey) { _, newValue in
            let sanitized = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            // Save to UserDefaults and update service
            if !sanitized.isEmpty {
                UserDefaults.standard.set(sanitized, forKey: "claudeApiKey")
            } else {
                UserDefaults.standard.removeObject(forKey: "claudeApiKey")
            }
            claudeService.apiKey = sanitized
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

// MARK: - iCloud Settings

struct iCloudSettingsView: View {
    @ObservedObject private var cloudKitManager = CloudKitManager.shared
    @ObservedObject private var syncCoordinator = SyncCoordinator.shared

    @AppStorage("syncBookmarks") private var syncBookmarks = true
    @AppStorage("syncReadingList") private var syncReadingList = true
    @AppStorage("syncGenTabs") private var syncGenTabs = true
    @AppStorage("syncTabGroups") private var syncTabGroups = false

    var body: some View {
        Form {
            Section {
                HStack {
                    Image(systemName: cloudKitManager.iCloudAvailable ? "checkmark.icloud.fill" : "xmark.icloud")
                        .font(.title2)
                        .foregroundColor(cloudKitManager.iCloudAvailable ? .green : .red)

                    VStack(alignment: .leading) {
                        Text(cloudKitManager.iCloudAvailable ? "iCloud Connected" : "iCloud Not Available")
                            .font(.headline)
                        Text(cloudKitManager.syncStatus.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if syncCoordinator.isSyncing {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }

            Section("Sync Options") {
                Toggle("Bookmarks", isOn: $syncBookmarks)
                Toggle("Reading List", isOn: $syncReadingList)
                Toggle("GenTabs", isOn: $syncGenTabs)
                Toggle("Tab Groups", isOn: $syncTabGroups)

                Text("Synced data is encrypted and stored in your personal iCloud account.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Requires a paid Apple Developer Program membership with iCloud capability enabled.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Sync Status") {
                if let lastSync = syncCoordinator.lastSyncTime {
                    LabeledContent("Last Sync", value: formatDate(lastSync))
                } else {
                    LabeledContent("Last Sync", value: "Never")
                }

                LabeledContent("Pending Changes", value: "\(syncCoordinator.pendingChanges)")

                Button("Sync Now") {
                    syncCoordinator.triggerSync()
                }
                .disabled(!cloudKitManager.iCloudAvailable || syncCoordinator.isSyncing)
            }

            Section("Handoff") {
                Toggle("Enable Handoff", isOn: .constant(true))
                    .disabled(true) // Always enabled when entitlements are correct

                Text("Continue browsing on your iPhone, iPad, or another Mac signed into the same iCloud account.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Focus Settings

struct FocusSettingsView: View {
    @ObservedObject private var focusManager = FocusFilterManager.shared

    @State private var customDomainsText = ""

    var body: some View {
        Form {
            Section {
                HStack {
                    Image(systemName: focusManager.isFocusModeActive ? "moon.fill" : "moon")
                        .font(.title2)
                        .foregroundColor(focusManager.isFocusModeActive ? .purple : .secondary)

                    VStack(alignment: .leading) {
                        Text(focusManager.isFocusModeActive ? "Focus Mode Active" : "Focus Mode Inactive")
                            .font(.headline)
                        Text("Configure via System Settings > Focus")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section("When Focus is Active") {
                Toggle("Hide Social Media Bookmarks", isOn: Binding(
                    get: { focusManager.currentConfiguration.hideSocialBookmarks },
                    set: { newValue in
                        var config = focusManager.currentConfiguration
                        config.hideSocialBookmarks = newValue
                        focusManager.applyConfiguration(config)
                    }
                ))

                Toggle("Block Distracting Sites", isOn: Binding(
                    get: { focusManager.currentConfiguration.blockDistractingSites },
                    set: { newValue in
                        var config = focusManager.currentConfiguration
                        config.blockDistractingSites = newValue
                        focusManager.applyConfiguration(config)
                    }
                ))

                Toggle("Disable AI Suggestions", isOn: Binding(
                    get: { focusManager.currentConfiguration.disableAISuggestions },
                    set: { newValue in
                        var config = focusManager.currentConfiguration
                        config.disableAISuggestions = newValue
                        focusManager.applyConfiguration(config)
                    }
                ))

                Toggle("Simplified UI", isOn: Binding(
                    get: { focusManager.currentConfiguration.useSimplifiedUI },
                    set: { newValue in
                        var config = focusManager.currentConfiguration
                        config.useSimplifiedUI = newValue
                        focusManager.applyConfiguration(config)
                    }
                ))
            }

            Section("Custom Blocked Domains") {
                TextField("Enter domains (comma-separated)", text: $customDomainsText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        updateCustomDomains()
                    }

                Text("Example: example.com, another-site.org")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if !focusManager.currentConfiguration.customBlockedDomains.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(focusManager.currentConfiguration.customBlockedDomains, id: \.self) { domain in
                                HStack(spacing: 4) {
                                    Text(domain)
                                        .font(.caption)
                                    Button(action: { removeDomain(domain) }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.caption)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.secondary.opacity(0.2))
                                .cornerRadius(8)
                            }
                        }
                    }
                }
            }

            if !focusManager.blockedNavigationAttempts.isEmpty {
                Section("Recently Blocked") {
                    let stats = focusManager.blockStatistics
                    LabeledContent("Total Blocked", value: "\(stats.totalBlocked)")

                    Button("Clear History") {
                        focusManager.clearBlockedAttempts()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            customDomainsText = focusManager.currentConfiguration.customBlockedDomains.joined(separator: ", ")
        }
    }

    private func updateCustomDomains() {
        let domains = customDomainsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var config = focusManager.currentConfiguration
        config.customBlockedDomains = domains
        focusManager.applyConfiguration(config)
    }

    private func removeDomain(_ domain: String) {
        var config = focusManager.currentConfiguration
        config.customBlockedDomains.removeAll { $0 == domain }
        focusManager.applyConfiguration(config)
        customDomainsText = config.customBlockedDomains.joined(separator: ", ")
    }
}
