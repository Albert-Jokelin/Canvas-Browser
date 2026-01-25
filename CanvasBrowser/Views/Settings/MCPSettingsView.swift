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
                Text(server.command + " " + server.args.joined(separator: " "))
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
}

// MARK: - Add Server Sheet

struct AddMCPServerSheet: View {
    @ObservedObject var mcpClient: MCPClient
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var command = "npx"
    @State private var argsString = ""
    @State private var envString = ""

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
                .disabled(name.isEmpty || command.isEmpty)
            }
            .padding()

            Divider()

            Form {
                Section("Server Details") {
                    TextField("Name", text: $name)
                    TextField("Command (e.g., npx, uvx, /path/to/server)", text: $command)
                    TextField("Arguments (space-separated)", text: $argsString)
                }

                Section("Environment Variables (optional)") {
                    TextField("KEY=value, one per line", text: $envString, axis: .vertical)
                        .lineLimit(3...6)
                }

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
            .formStyle(.grouped)
        }
        .frame(width: 450, height: 400)
    }

    private func addServer() {
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

        let config = MCPServerConfig(
            name: name,
            command: command,
            args: args,
            env: env
        )

        mcpClient.addServer(config)
    }
}

// MARK: - Edit Server Sheet

struct EditMCPServerSheet: View {
    @ObservedObject var mcpClient: MCPClient
    @Environment(\.dismiss) var dismiss

    let server: MCPServerConfig

    @State private var name: String
    @State private var command: String
    @State private var argsString: String
    @State private var envString: String

    init(mcpClient: MCPClient, server: MCPServerConfig) {
        self.mcpClient = mcpClient
        self.server = server
        _name = State(initialValue: server.name)
        _command = State(initialValue: server.command)
        _argsString = State(initialValue: server.args.joined(separator: " "))
        _envString = State(initialValue: server.env?.map { "\($0.key)=\($0.value)" }.joined(separator: "\n") ?? "")
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
                .disabled(name.isEmpty || command.isEmpty)
            }
            .padding()

            Divider()

            Form {
                Section("Server Details") {
                    TextField("Name", text: $name)
                    TextField("Command", text: $command)
                    TextField("Arguments (space-separated)", text: $argsString)
                }

                Section("Environment Variables (optional)") {
                    TextField("KEY=value, one per line", text: $envString, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 450, height: 350)
    }

    private func saveServer() {
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

        let updated = MCPServerConfig(
            id: server.id,
            name: name,
            command: command,
            args: args,
            env: env,
            isEnabled: server.isEnabled
        )

        mcpClient.updateServer(updated)
    }
}
