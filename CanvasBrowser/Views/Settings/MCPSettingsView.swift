import SwiftUI

struct MCPSettingsView: View {
    @StateObject private var mcpClient = MCPClient.shared
    @State private var showAddServer = false
    @State private var selectedServer: MCPServerConfig?
    @State private var isConnecting = false

    var body: some View {
        Form {
            Section {
                HStack {
                    Image(systemName: "cpu")
                        .foregroundColor(.accentColor)
                    Text("Model Context Protocol")
                        .font(.headline)
                    Spacer()
                    Link("Learn More", destination: URL(string: "https://modelcontextprotocol.io")!)
                        .font(.caption)
                }

                Text("Connect to MCP servers to extend AI capabilities with tools and resources.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Servers") {
                if mcpClient.serverConfigs.isEmpty {
                    Text("No MCP servers configured")
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ForEach(mcpClient.serverConfigs) { server in
                        MCPServerRow(
                            server: server,
                            isConnected: mcpClient.connectedServers[server.id] != nil,
                            onToggle: { enabled in
                                var updated = server
                                updated.isEnabled = enabled
                                mcpClient.updateServer(updated)
                            },
                            onEdit: {
                                selectedServer = server
                            },
                            onDelete: {
                                mcpClient.removeServer(server)
                            }
                        )
                    }
                }

                Button(action: { showAddServer = true }) {
                    Label("Add Server", systemImage: "plus.circle")
                }
            }

            if !mcpClient.availableTools.isEmpty {
                Section("Available Tools (\(mcpClient.availableTools.count))") {
                    ForEach(mcpClient.availableTools) { tool in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "wrench.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                Text(tool.name)
                                    .font(.subheadline.weight(.medium))
                            }
                            Text(tool.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            if !mcpClient.availableResources.isEmpty {
                Section("Available Resources (\(mcpClient.availableResources.count))") {
                    ForEach(mcpClient.availableResources) { resource in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "doc.fill")
                                    .foregroundColor(.blue)
                                    .font(.caption)
                                Text(resource.name)
                                    .font(.subheadline.weight(.medium))
                            }
                            Text(resource.uri)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            Section {
                HStack {
                    Button("Connect All") {
                        isConnecting = true
                        Task {
                            await mcpClient.connectAll()
                            isConnecting = false
                        }
                    }
                    .disabled(mcpClient.serverConfigs.isEmpty || isConnecting)

                    if isConnecting {
                        ProgressView()
                            .controlSize(.small)
                    }

                    Spacer()

                    Button("Disconnect All") {
                        mcpClient.disconnectAll()
                    }
                    .disabled(mcpClient.connectedServers.isEmpty)
                }
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showAddServer) {
            AddMCPServerSheet(mcpClient: mcpClient)
        }
        .sheet(item: $selectedServer) { server in
            EditMCPServerSheet(mcpClient: mcpClient, server: server)
        }
    }
}

// MARK: - Server Row

struct MCPServerRow: View {
    let server: MCPServerConfig
    let isConnected: Bool
    let onToggle: (Bool) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Image(systemName: isConnected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isConnected ? .green : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(server.name)
                    .font(.subheadline.weight(.medium))
                Text(serverDetailText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { server.isEnabled },
                set: onToggle
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)

            Menu {
                Button("Edit", action: onEdit)
                Divider()
                Button("Delete", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(.secondary)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 24)
        }
    }

    private var serverDetailText: String {
        switch server.transport {
        case .stdio:
            return (server.command + " " + server.args.joined(separator: " ")).trimmingCharacters(in: .whitespaces)
        case .httpSSE, .webSocket:
            return server.url ?? "No URL set"
        }
    }
}

// MARK: - Add Server Sheet

struct AddMCPServerSheet: View {
    @ObservedObject var mcpClient: MCPClient
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var transport: MCPTransportType = .stdio
    @State private var command = "npx"
    @State private var argsString = ""
    @State private var envString = ""
    @State private var urlString = ""
    @State private var headersString = ""
    @State private var isTesting = false
    @State private var testResult: MCPConnectionTestResult?
    @State private var validationError: String?

    private var currentConfig: MCPServerConfig {
        let args = argsString.split(separator: " ").map(String.init)
        var env: [String: String]? = nil
        if !envString.isEmpty {
            env = [:]
            for line in envString.components(separatedBy: "\n") {
                let parts = line.split(separator: "=", maxSplits: 1)
                if parts.count == 2 {
                    env?[String(parts[0])] = String(parts[1])
                }
            }
        }
        return MCPServerConfig(
            name: name,
            command: command,
            args: args,
            env: env,
            transport: transport,
            url: urlString.isEmpty ? nil : urlString,
            headers: parseHeaders(headersString)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Text("Add MCP Server")
                    .font(.headline)
                Spacer()
                Button("Add") {
                    addServer()
                    dismiss()
                }
                .disabled(isConfigIncomplete)
            }
            .padding()

            Divider()

            Form {
                Section("Transport") {
                    Picker("Transport", selection: $transport) {
                        Text("Stdio").tag(MCPTransportType.stdio)
                        Text("HTTP SSE").tag(MCPTransportType.httpSSE)
                        Text("WebSocket").tag(MCPTransportType.webSocket)
                    }
                    .onChange(of: transport) { _, _ in clearTestResult() }
                }

                if transport == .stdio {
                    Section("Server Details") {
                        TextField("Name", text: $name)
                            .onChange(of: name) { _, _ in clearTestResult() }
                        TextField("Command (e.g., npx, uvx, /path/to/server)", text: $command)
                            .onChange(of: command) { _, _ in clearTestResult() }
                        TextField("Arguments (space-separated)", text: $argsString)
                            .onChange(of: argsString) { _, _ in clearTestResult() }
                    }

                    Section("Environment Variables (optional)") {
                        TextField("KEY=value, one per line", text: $envString, axis: .vertical)
                            .lineLimit(3...6)
                            .onChange(of: envString) { _, _ in clearTestResult() }
                    }
                } else {
                    Section("Server Details") {
                        TextField("Name", text: $name)
                            .onChange(of: name) { _, _ in clearTestResult() }
                        TextField("URL", text: $urlString)
                            .onChange(of: urlString) { _, _ in clearTestResult() }
                    }

                    Section("Headers (optional)") {
                        TextField("Header-Name=value, one per line", text: $headersString, axis: .vertical)
                            .lineLimit(3...6)
                            .onChange(of: headersString) { _, _ in clearTestResult() }

                        Text("Headers are optional. Use one per line: Header-Name=Value")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Test Connection Section
                Section {
                    HStack {
                        Button(action: testConnection) {
                            HStack {
                                if isTesting {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: "bolt.fill")
                                }
                                Text("Test Connection")
                            }
                        }
                        .disabled(isConfigIncomplete || isTesting)

                        Spacer()

                        if let result = testResult {
                            switch result {
                            case .success(let message, _):
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text(message)
                                        .foregroundColor(.green)
                                        .font(.caption)
                                }
                            case .failed:
                                HStack(spacing: 4) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                    Text("Failed")
                                        .foregroundColor(.red)
                                        .font(.caption)
                                }
                            }
                        }
                    }

                    if case .failed(let error) = testResult {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.vertical, 4)
                    }

                    if case .success(_, let details) = testResult {
                        Text(details)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if transport == .stdio {
                    Section {
                        Text("Common examples:")
                            .font(.caption.weight(.medium))

                        Button("Filesystem Server") {
                            name = "Filesystem"
                            command = "npx"
                            argsString = "-y @modelcontextprotocol/server-filesystem /Users"
                        }

                        Button("GitHub Server") {
                            name = "GitHub"
                            command = "npx"
                            argsString = "-y @modelcontextprotocol/server-github"
                            envString = "GITHUB_PERSONAL_ACCESS_TOKEN=your_token"
                        }
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 450, height: 500)
    }

    private func clearTestResult() {
        testResult = nil
        validationError = nil
    }

    private var isConfigIncomplete: Bool {
        switch transport {
        case .stdio:
            return name.isEmpty || command.isEmpty
        case .httpSSE, .webSocket:
            return name.isEmpty || urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func testConnection() {
        isTesting = true
        testResult = nil

        Task {
            let result = await mcpClient.testConnection(to: currentConfig)
            await MainActor.run {
                testResult = result
                isTesting = false
            }
        }
    }

    private func addServer() {
        mcpClient.addServer(currentConfig)
    }

    private func parseHeaders(_ headersString: String) -> [String: String]? {
        let lines = headersString
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else { return nil }

        var headers: [String: String] = [:]
        for line in lines {
            let parts = line.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                headers[String(parts[0]).trimmingCharacters(in: .whitespaces)] =
                    String(parts[1]).trimmingCharacters(in: .whitespaces)
            }
        }
        return headers.isEmpty ? nil : headers
    }
}

// MARK: - Edit Server Sheet

struct EditMCPServerSheet: View {
    @ObservedObject var mcpClient: MCPClient
    @Environment(\.dismiss) var dismiss

    let server: MCPServerConfig

    @State private var name: String
    @State private var transport: MCPTransportType
    @State private var command: String
    @State private var argsString: String
    @State private var envString: String
    @State private var urlString: String
    @State private var headersString: String
    @State private var isTesting = false
    @State private var testResult: MCPConnectionTestResult?

    private var currentConfig: MCPServerConfig {
        let args = argsString.split(separator: " ").map(String.init)
        var env: [String: String]? = nil
        if !envString.isEmpty {
            env = [:]
            for line in envString.components(separatedBy: "\n") {
                let parts = line.split(separator: "=", maxSplits: 1)
                if parts.count == 2 {
                    env?[String(parts[0])] = String(parts[1])
                }
            }
        }
        return MCPServerConfig(
            id: server.id,
            name: name,
            command: command,
            args: args,
            env: env,
            transport: transport,
            url: urlString.isEmpty ? nil : urlString,
            headers: parseHeaders(headersString),
            isEnabled: server.isEnabled
        )
    }

    init(mcpClient: MCPClient, server: MCPServerConfig) {
        self.mcpClient = mcpClient
        self.server = server
        _name = State(initialValue: server.name)
        _transport = State(initialValue: server.transport)
        _command = State(initialValue: server.command)
        _argsString = State(initialValue: server.args.joined(separator: " "))
        _envString = State(initialValue: server.env?.map { "\($0.key)=\($0.value)" }.joined(separator: "\n") ?? "")
        _urlString = State(initialValue: server.url ?? "")
        _headersString = State(initialValue: server.headers?.map { "\($0.key)=\($0.value)" }.joined(separator: "\n") ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Text("Edit MCP Server")
                    .font(.headline)
                Spacer()
                Button("Save") {
                    saveServer()
                    dismiss()
                }
                .disabled(isConfigIncomplete)
            }
            .padding()

            Divider()

            Form {
                Section("Transport") {
                    Picker("Transport", selection: $transport) {
                        Text("Stdio").tag(MCPTransportType.stdio)
                        Text("HTTP SSE").tag(MCPTransportType.httpSSE)
                        Text("WebSocket").tag(MCPTransportType.webSocket)
                    }
                    .onChange(of: transport) { _, _ in testResult = nil }
                }

                if transport == .stdio {
                    Section("Server Details") {
                        TextField("Name", text: $name)
                            .onChange(of: name) { _, _ in testResult = nil }
                        TextField("Command", text: $command)
                            .onChange(of: command) { _, _ in testResult = nil }
                        TextField("Arguments (space-separated)", text: $argsString)
                            .onChange(of: argsString) { _, _ in testResult = nil }
                    }

                    Section("Environment Variables (optional)") {
                        TextField("KEY=value, one per line", text: $envString, axis: .vertical)
                            .lineLimit(3...6)
                            .onChange(of: envString) { _, _ in testResult = nil }
                    }
                } else {
                    Section("Server Details") {
                        TextField("Name", text: $name)
                            .onChange(of: name) { _, _ in testResult = nil }
                        TextField("URL", text: $urlString)
                            .onChange(of: urlString) { _, _ in testResult = nil }
                    }

                    Section("Headers (optional)") {
                        TextField("Header-Name=value, one per line", text: $headersString, axis: .vertical)
                            .lineLimit(3...6)
                            .onChange(of: headersString) { _, _ in testResult = nil }

                        Text("Headers are optional. Use one per line: Header-Name=Value")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Test Connection Section
                Section {
                    HStack {
                        Button(action: testConnection) {
                            HStack {
                                if isTesting {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: "bolt.fill")
                                }
                                Text("Test Connection")
                            }
                        }
                        .disabled(isConfigIncomplete || isTesting)

                        Spacer()

                        if let result = testResult {
                            switch result {
                            case .success(let message, _):
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text(message)
                                        .foregroundColor(.green)
                                        .font(.caption)
                                }
                            case .failed:
                                HStack(spacing: 4) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                    Text("Failed")
                                        .foregroundColor(.red)
                                        .font(.caption)
                                }
                            }
                        }
                    }

                    if case .failed(let error) = testResult {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.vertical, 4)
                    }

                    if case .success(_, let details) = testResult {
                        Text(details)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 450, height: 450)
    }

    private func testConnection() {
        isTesting = true
        testResult = nil

        Task {
            let result = await mcpClient.testConnection(to: currentConfig)
            await MainActor.run {
                testResult = result
                isTesting = false
            }
        }
    }

    private func saveServer() {
        mcpClient.updateServer(currentConfig)
    }

    private var isConfigIncomplete: Bool {
        switch transport {
        case .stdio:
            return name.isEmpty || command.isEmpty
        case .httpSSE, .webSocket:
            return name.isEmpty || urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func parseHeaders(_ headersString: String) -> [String: String]? {
        let lines = headersString
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else { return nil }

        var headers: [String: String] = [:]
        for line in lines {
            let parts = line.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                headers[String(parts[0]).trimmingCharacters(in: .whitespaces)] =
                    String(parts[1]).trimmingCharacters(in: .whitespaces)
            }
        }
        return headers.isEmpty ? nil : headers
    }
}
