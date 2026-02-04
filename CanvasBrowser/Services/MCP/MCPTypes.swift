import Foundation

// MARK: - MCP Server Configuration

enum MCPTransportType: String, Codable {
    case stdio
    case httpSSE
    case webSocket
}

/// Configuration for an MCP server connection
struct MCPServerConfig: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var command: String       // e.g., "npx", "uvx", "/path/to/server"
    var args: [String]        // e.g., ["-y", "@modelcontextprotocol/server-filesystem", "/path"]
    var env: [String: String]?
    var transport: MCPTransportType
    var url: String?
    var headers: [String: String]?
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        name: String,
        command: String,
        args: [String],
        env: [String: String]? = nil,
        transport: MCPTransportType = .stdio,
        url: String? = nil,
        headers: [String: String]? = nil,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.command = command
        self.args = args
        self.env = env
        self.transport = transport
        self.url = url
        self.headers = headers
        self.isEnabled = isEnabled
    }

    static func == (lhs: MCPServerConfig, rhs: MCPServerConfig) -> Bool {
        lhs.id == rhs.id
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, command, args, env, transport, url, headers, isEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        command = try container.decodeIfPresent(String.self, forKey: .command) ?? ""
        args = try container.decodeIfPresent([String].self, forKey: .args) ?? []
        env = try container.decodeIfPresent([String: String].self, forKey: .env)
        transport = try container.decodeIfPresent(MCPTransportType.self, forKey: .transport) ?? .stdio
        url = try container.decodeIfPresent(String.self, forKey: .url)
        headers = try container.decodeIfPresent([String: String].self, forKey: .headers)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(command, forKey: .command)
        try container.encode(args, forKey: .args)
        try container.encodeIfPresent(env, forKey: .env)
        try container.encode(transport, forKey: .transport)
        try container.encodeIfPresent(url, forKey: .url)
        try container.encodeIfPresent(headers, forKey: .headers)
        try container.encode(isEnabled, forKey: .isEnabled)
    }
}

// MARK: - MCP Tool Definition

/// A tool exposed by an MCP server
struct MCPTool: Codable, Identifiable {
    var id: String { name }
    let name: String
    let description: String
    let inputSchema: MCPInputSchema

    struct MCPInputSchema: Codable {
        let type: String
        let properties: [String: MCPProperty]?
        let required: [String]?
    }

    struct MCPProperty: Codable {
        let type: String
        let description: String?
    }
}

// MARK: - MCP Resource Definition

/// A resource exposed by an MCP server
struct MCPResource: Codable, Identifiable {
    var id: String { uri }
    let uri: String
    let name: String
    let description: String?
    let mimeType: String?
}

// MARK: - JSON-RPC Types

/// JSON-RPC 2.0 request structure
struct JSONRPCRequest: Codable {
    let jsonrpc: String = "2.0"
    let id: Int
    let method: String
    let params: [String: AnyCodable]?

    init(id: Int, method: String, params: [String: AnyCodable]? = nil) {
        self.id = id
        self.method = method
        self.params = params
    }
}

/// JSON-RPC 2.0 response structure
struct JSONRPCResponse: Codable {
    let jsonrpc: String
    let id: Int?
    let result: AnyCodable?
    let error: JSONRPCError?
}

/// JSON-RPC error
struct JSONRPCError: Codable {
    let code: Int
    let message: String
    let data: AnyCodable?
}

// MARK: - MCP Protocol Messages

/// MCP Initialize request params
struct MCPInitializeParams: Codable {
    let protocolVersion: String
    let capabilities: MCPClientCapabilities
    let clientInfo: MCPClientInfo
}

struct MCPClientCapabilities: Codable {
    let roots: MCPRootsCapability?

    struct MCPRootsCapability: Codable {
        let listChanged: Bool?
    }
}

struct MCPClientInfo: Codable {
    let name: String
    let version: String
}

/// MCP Initialize result
struct MCPInitializeResult: Codable {
    let protocolVersion: String
    let capabilities: MCPServerCapabilities
    let serverInfo: MCPServerInfo?
}

struct MCPServerCapabilities: Codable {
    let tools: MCPToolsCapability?
    let resources: MCPResourcesCapability?
    let prompts: MCPPromptsCapability?

    struct MCPToolsCapability: Codable {
        let listChanged: Bool?
    }

    struct MCPResourcesCapability: Codable {
        let subscribe: Bool?
        let listChanged: Bool?
    }

    struct MCPPromptsCapability: Codable {
        let listChanged: Bool?
    }
}

struct MCPServerInfo: Codable {
    let name: String
    let version: String?
}

/// MCP Tool call result
struct MCPToolCallResult: Codable {
    let content: [MCPContent]
    let isError: Bool?

    struct MCPContent: Codable {
        let type: String
        let text: String?
        let data: String?
        let mimeType: String?
    }
}

// MARK: - AnyCodable Helper

/// A type-erased Codable value for handling dynamic JSON
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            self.value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unable to decode value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: container.codingPath, debugDescription: "Unable to encode value"))
        }
    }
}
