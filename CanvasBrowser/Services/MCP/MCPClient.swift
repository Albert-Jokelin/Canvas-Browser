import Foundation
import Combine

/// MCP Client for managing Model Context Protocol server connections
class MCPClient: ObservableObject {
    static let shared = MCPClient()

    @Published var serverConfigs: [MCPServerConfig] = []
    @Published var connectedServers: [UUID: MCPServerConnection] = [:]
    @Published var availableTools: [MCPTool] = []
    @Published var availableResources: [MCPResource] = []

    private let configKey = "mcpServerConfigs"

    init() {
        loadConfigs()
    }

    // MARK: - Configuration Management

    func loadConfigs() {
        if let data = UserDefaults.standard.data(forKey: configKey),
           let configs = try? JSONDecoder().decode([MCPServerConfig].self, from: data) {
            serverConfigs = configs
        }
    }

    func saveConfigs() {
        if let data = try? JSONEncoder().encode(serverConfigs) {
            UserDefaults.standard.set(data, forKey: configKey)
        }
    }

    func addServer(_ config: MCPServerConfig) {
        serverConfigs.append(config)
        saveConfigs()
    }

    func removeServer(_ config: MCPServerConfig) {
        disconnect(from: config)
        serverConfigs.removeAll { $0.id == config.id }
        saveConfigs()
    }

    func updateServer(_ config: MCPServerConfig) {
        if let index = serverConfigs.firstIndex(where: { $0.id == config.id }) {
            let wasConnected = connectedServers[config.id] != nil
            if wasConnected {
                disconnect(from: serverConfigs[index])
            }
            serverConfigs[index] = config
            saveConfigs()
            if wasConnected && config.isEnabled {
                Task {
                    try? await connect(to: config)
                }
            }
        }
    }

    // MARK: - Connection Management

    /// Validate server configuration before attempting connection
    func validateConfig(_ config: MCPServerConfig) -> MCPConfigValidationResult {
        switch config.transport {
        case .stdio:
            // Check command is not empty
            guard !config.command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return .invalid("Command cannot be empty")
            }

            // Check if command is an absolute path
            if config.command.hasPrefix("/") {
                let fileManager = FileManager.default
                if !fileManager.fileExists(atPath: config.command) {
                    return .invalid("Executable not found at path: \(config.command)")
                }
                if !fileManager.isExecutableFile(atPath: config.command) {
                    return .invalid("File is not executable: \(config.command)")
                }
            }
        case .httpSSE, .webSocket:
            guard let urlString = config.url?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !urlString.isEmpty else {
                return .invalid("URL cannot be empty")
            }
            guard let url = URL(string: urlString), let scheme = url.scheme?.lowercased() else {
                return .invalid("Invalid URL: \(urlString)")
            }
            if config.transport == .httpSSE && !(scheme == "http" || scheme == "https") {
                return .invalid("HTTP SSE requires http/https URL")
            }
            if config.transport == .webSocket && !(scheme == "ws" || scheme == "wss") {
                return .invalid("WebSocket requires ws/wss URL")
            }
        }

        // Check name is not empty
        guard !config.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .invalid("Server name cannot be empty")
        }

        return .valid
    }

    /// Test connection to a server without persisting
    func testConnection(to config: MCPServerConfig) async -> MCPConnectionTestResult {
        // Validate config first
        let validation = validateConfig(config)
        if case .invalid(let reason) = validation {
            return .failed(reason)
        }

        let connection = MCPServerConnection(config: config)
        do {
            try await connection.connect()
            let serverInfo = connection.serverInfo
            let toolCount = connection.tools.count
            let resourceCount = connection.resources.count
            connection.disconnect()

            let message = "Connected to \(serverInfo?.name ?? config.name)"
            let details = "Tools: \(toolCount), Resources: \(resourceCount)"
            return .success(message: message, details: details)
        } catch {
            return .failed(describeConnectionError(error, config: config))
        }
    }

    /// Provide human-readable error descriptions
    private func describeConnectionError(_ error: Error, config: MCPServerConfig) -> String {
        if let mcpError = error as? MCPClientError {
            return mcpError.errorDescription ?? error.localizedDescription
        }

        if let transportError = error as? MCPTransportError {
            return transportError.errorDescription ?? error.localizedDescription
        }

        if let httpError = error as? MCPHTTPTransportError {
            return httpError.errorDescription ?? error.localizedDescription
        }

        if let wsError = error as? MCPWebSocketTransportError {
            return wsError.errorDescription ?? error.localizedDescription
        }

        let nsError = error as NSError

        // Common error cases
        if nsError.domain == NSPOSIXErrorDomain {
            switch nsError.code {
            case 2: // ENOENT
                return "Command '\(config.command)' not found. Make sure it's installed and in your PATH."
            case 13: // EACCES
                return "Permission denied when running '\(config.command)'. Check file permissions."
            default:
                break
            }
        }

        if nsError.domain == NSCocoaErrorDomain && nsError.code == 4 {
            return "Could not launch '\(config.command)'. Make sure the path is correct."
        }

        return "Connection failed: \(error.localizedDescription)"
    }

    func connect(to config: MCPServerConfig) async throws {
        guard config.isEnabled else { return }

        // Validate before connecting
        let validation = validateConfig(config)
        if case .invalid(let reason) = validation {
            throw MCPClientError.configurationInvalid(reason)
        }

        let connection = MCPServerConnection(config: config)

        do {
            try await connection.connect()
        } catch {
            throw MCPClientError.connectionFailed(describeConnectionError(error, config: config))
        }

        await MainActor.run {
            connectedServers[config.id] = connection
            refreshAvailableTools()
        }
    }

    func disconnect(from config: MCPServerConfig) {
        if let connection = connectedServers[config.id] {
            connection.disconnect()
            connectedServers.removeValue(forKey: config.id)
            refreshAvailableTools()
        }
    }

    func connectAll() async {
        for config in serverConfigs where config.isEnabled {
            do {
                try await connect(to: config)
            } catch {
                print("Failed to connect to MCP server \(config.name): \(error)")
            }
        }
    }

    func disconnectAll() {
        for config in serverConfigs {
            disconnect(from: config)
        }
    }

    // MARK: - Tool Management

    private func refreshAvailableTools() {
        var tools: [MCPTool] = []
        var resources: [MCPResource] = []

        for connection in connectedServers.values {
            tools.append(contentsOf: connection.tools)
            resources.append(contentsOf: connection.resources)
        }

        availableTools = tools
        availableResources = resources
    }

    /// Call a tool on the appropriate server
    func callTool(name: String, arguments: [String: Any]) async throws -> MCPToolCallResult {
        // Find the server that has this tool
        for (_, connection) in connectedServers {
            if connection.tools.contains(where: { $0.name == name }) {
                return try await connection.callTool(name: name, arguments: arguments)
            }
        }

        throw MCPClientError.toolNotFound(name)
    }

    /// Read a resource from the appropriate server
    func readResource(uri: String) async throws -> String {
        // Find the server that has this resource
        for (_, connection) in connectedServers {
            if connection.resources.contains(where: { $0.uri == uri }) {
                return try await connection.readResource(uri: uri)
            }
        }

        throw MCPClientError.resourceNotFound(uri)
    }
}

// MARK: - MCP Server Connection

class MCPServerConnection: ObservableObject {
    let config: MCPServerConfig
    private var transport: MCPTransport?
    private var requestId = 0
    private var pendingRequests: [Int: CheckedContinuation<JSONRPCResponse, Error>] = [:]

    @Published var isConnected = false
    @Published var tools: [MCPTool] = []
    @Published var resources: [MCPResource] = []
    @Published var serverInfo: MCPServerInfo?

    init(config: MCPServerConfig) {
        self.config = config
    }

    func connect() async throws {
        let transport: MCPTransport
        switch config.transport {
        case .stdio:
            transport = MCPStdioTransport()
        case .httpSSE:
            transport = MCPHTTPTransport()
        case .webSocket:
            transport = MCPWebSocketTransport()
        }

        transport.onMessage = { [weak self] data in
            self?.handleMessage(data)
        }

        transport.onError = { error in
            print("MCP Error: \(error)")
        }

        transport.onClose = { [weak self] in
            Task { @MainActor in
                self?.isConnected = false
            }
        }

        try transport.start(config: config)
        self.transport = transport

        // Initialize the connection
        try await initialize()

        // Get available tools and resources
        await refreshCapabilities()

        await MainActor.run {
            isConnected = true
        }
    }

    func disconnect() {
        transport?.stop()
        transport = nil
        isConnected = false
        tools = []
        resources = []
    }

    private func initialize() async throws {
        let params = MCPInitializeParams(
            protocolVersion: "2024-11-05",
            capabilities: MCPClientCapabilities(roots: nil),
            clientInfo: MCPClientInfo(name: "Canvas Browser", version: "1.0.0")
        )

        let response = try await sendRequest(method: "initialize", params: params)

        if let result = response.result {
            // Parse initialization result
            let data = try JSONSerialization.data(withJSONObject: result.value)
            let initResult = try JSONDecoder().decode(MCPInitializeResult.self, from: data)
            await MainActor.run {
                serverInfo = initResult.serverInfo
            }
        }

        // Send initialized notification (no response expected)
        sendNotification(method: "notifications/initialized")
    }

    /// Send a notification (no response expected)
    private func sendNotification(method: String, params: [String: AnyCodable]? = nil) {
        guard let transport = transport else { return }

        struct JSONRPCNotification: Encodable {
            let jsonrpc: String = "2.0"
            let method: String
            let params: [String: AnyCodable]?
        }

        let notification = JSONRPCNotification(method: method, params: params)

        do {
            let data = try JSONEncoder().encode(notification)
            try transport.send(data)
        } catch {
            print("Failed to send MCP notification: \(error)")
        }
    }

    private func refreshCapabilities() async {
        // Get tools
        do {
            let response = try await sendRequest(method: "tools/list", params: nil as MCPInitializeParams?)
            if let result = response.result?.value as? [String: Any],
               let toolsArray = result["tools"] as? [[String: Any]] {
                let data = try JSONSerialization.data(withJSONObject: toolsArray)
                let parsedTools = try JSONDecoder().decode([MCPTool].self, from: data)
                await MainActor.run {
                    tools = parsedTools
                }
            }
        } catch {
            print("Failed to list tools: \(error)")
        }

        // Get resources
        do {
            let response = try await sendRequest(method: "resources/list", params: nil as MCPInitializeParams?)
            if let result = response.result?.value as? [String: Any],
               let resourcesArray = result["resources"] as? [[String: Any]] {
                let data = try JSONSerialization.data(withJSONObject: resourcesArray)
                let parsedResources = try JSONDecoder().decode([MCPResource].self, from: data)
                await MainActor.run {
                    resources = parsedResources
                }
            }
        } catch {
            print("Failed to list resources: \(error)")
        }
    }

    func callTool(name: String, arguments: [String: Any]) async throws -> MCPToolCallResult {
        let params: [String: Any] = [
            "name": name,
            "arguments": arguments
        ]

        let response = try await sendRequest(method: "tools/call", params: AnyCodable(params))

        guard let result = response.result?.value as? [String: Any] else {
            throw MCPClientError.invalidResponse
        }

        let data = try JSONSerialization.data(withJSONObject: result)
        return try JSONDecoder().decode(MCPToolCallResult.self, from: data)
    }

    func readResource(uri: String) async throws -> String {
        let params: [String: Any] = ["uri": uri]

        let response = try await sendRequest(method: "resources/read", params: AnyCodable(params))

        guard let result = response.result?.value as? [String: Any],
              let contents = result["contents"] as? [[String: Any]],
              let firstContent = contents.first,
              let text = firstContent["text"] as? String else {
            throw MCPClientError.invalidResponse
        }

        return text
    }

    private func sendRequest<T: Encodable>(method: String, params: T?) async throws -> JSONRPCResponse {
        requestId += 1
        let currentId = requestId

        var paramsDict: [String: AnyCodable]? = nil
        if let params = params {
            let data = try JSONEncoder().encode(params)
            if let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                paramsDict = dict.mapValues { AnyCodable($0) }
            }
        }

        let request = JSONRPCRequest(id: currentId, method: method, params: paramsDict)
        let requestData = try JSONEncoder().encode(request)

        guard let transport = transport else {
            throw MCPClientError.notConnected
        }

        return try await withCheckedThrowingContinuation { continuation in
            pendingRequests[currentId] = continuation

            do {
                try transport.send(requestData)
            } catch {
                pendingRequests.removeValue(forKey: currentId)
                continuation.resume(throwing: error)
            }

            // Timeout after 30 seconds
            Task {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                if let cont = self.pendingRequests.removeValue(forKey: currentId) {
                    cont.resume(throwing: MCPClientError.timeout)
                }
            }
        }
    }

    private func handleMessage(_ data: Data) {
        do {
            let response = try JSONDecoder().decode(JSONRPCResponse.self, from: data)

            if let id = response.id, let continuation = pendingRequests.removeValue(forKey: id) {
                continuation.resume(returning: response)
            }
        } catch {
            print("Failed to parse MCP response: \(error)")
        }
    }
}

// MARK: - Validation Types

enum MCPConfigValidationResult {
    case valid
    case invalid(String)
}

enum MCPConnectionTestResult {
    case success(message: String, details: String)
    case failed(String)

    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}

// MARK: - Errors

enum MCPClientError: LocalizedError {
    case notConnected
    case toolNotFound(String)
    case resourceNotFound(String)
    case invalidResponse
    case timeout
    case configurationInvalid(String)
    case connectionFailed(String)

    var errorDescription: String? {
        switch self {
        case .notConnected: return "Not connected to MCP server"
        case .toolNotFound(let name): return "Tool '\(name)' not found"
        case .resourceNotFound(let uri): return "Resource '\(uri)' not found"
        case .invalidResponse: return "Invalid response from MCP server"
        case .timeout: return "Request timed out after 30 seconds"
        case .configurationInvalid(let reason): return "Invalid configuration: \(reason)"
        case .connectionFailed(let reason): return reason
        }
    }
}
