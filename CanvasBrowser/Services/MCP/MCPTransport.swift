import Foundation

/// Transport layer for MCP communication over stdio
class MCPStdioTransport: @unchecked Sendable {
    private var process: Process?
    private var stdin: FileHandle?
    private var stdout: FileHandle?
    private var stderr: FileHandle?

    private var isRunning = false
    private var outputBuffer = Data()
    private let bufferQueue = DispatchQueue(label: "com.canvas.mcp.buffer")

    var onMessage: ((Data) -> Void)?
    var onError: ((String) -> Void)?
    var onClose: (() -> Void)?

    init() {}

    /// Start the MCP server process
    func start(command: String, args: [String], env: [String: String]? = nil) throws {
        let process = Process()

        // Determine the executable path
        if command.hasPrefix("/") {
            process.executableURL = URL(fileURLWithPath: command)
        } else {
            // Use /usr/bin/env to find the command in PATH
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [command] + args
        }

        if command.hasPrefix("/") {
            process.arguments = args
        }

        // Set up environment
        var environment = ProcessInfo.processInfo.environment
        if let env = env {
            for (key, value) in env {
                environment[key] = value
            }
        }
        process.environment = environment

        // Set up pipes
        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        stdin = stdinPipe.fileHandleForWriting
        stdout = stdoutPipe.fileHandleForReading
        stderr = stderrPipe.fileHandleForReading

        // Handle stdout
        stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            self?.handleStdoutData(data)
        }

        // Handle stderr
        stderrPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            if let errorString = String(data: data, encoding: .utf8) {
                self?.onError?(errorString)
            }
        }

        // Handle process termination
        process.terminationHandler = { [weak self] _ in
            self?.isRunning = false
            self?.onClose?()
        }

        try process.run()
        self.process = process
        self.isRunning = true
    }

    /// Handle incoming stdout data
    private func handleStdoutData(_ data: Data) {
        bufferQueue.async { [weak self] in
            guard let self = self else { return }

            self.outputBuffer.append(data)

            // Try to parse complete JSON-RPC messages
            while let message = self.extractMessage() {
                DispatchQueue.main.async {
                    self.onMessage?(message)
                }
            }
        }
    }

    /// Extract a complete JSON-RPC message from the buffer
    private func extractMessage() -> Data? {
        // MCP uses newline-delimited JSON
        guard let newlineIndex = outputBuffer.firstIndex(of: UInt8(ascii: "\n")) else {
            return nil
        }

        let messageData = outputBuffer[..<newlineIndex]
        outputBuffer = Data(outputBuffer[(newlineIndex + 1)...])

        return Data(messageData)
    }

    /// Send a message to the server
    func send(_ data: Data) throws {
        guard isRunning, let stdin = stdin else {
            throw MCPTransportError.notConnected
        }

        var dataToSend = data
        if !data.hasSuffix("\n".data(using: .utf8)!) {
            dataToSend.append("\n".data(using: .utf8)!)
        }

        stdin.write(dataToSend)
    }

    /// Stop the server process
    func stop() {
        stdin?.closeFile()
        stdout?.readabilityHandler = nil
        stderr?.readabilityHandler = nil
        process?.terminate()
        process = nil
        isRunning = false
    }

    deinit {
        stop()
    }
}

// MARK: - Data Extension

private extension Data {
    func hasSuffix(_ suffix: Data) -> Bool {
        guard self.count >= suffix.count else { return false }
        return self.suffix(suffix.count) == suffix
    }
}

// MARK: - Errors

enum MCPTransportError: LocalizedError {
    case notConnected
    case sendFailed
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notConnected: return "MCP server is not connected"
        case .sendFailed: return "Failed to send message to MCP server"
        case .invalidResponse: return "Invalid response from MCP server"
        }
    }
}
