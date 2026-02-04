import Foundation

enum MCPWebSocketTransportError: LocalizedError {
    case invalidURL(String)
    case requestTimedOut

    var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Invalid WebSocket URL: \(url)"
        case .requestTimedOut:
            return "WebSocket request timed out"
        }
    }
}

final class MCPWebSocketTransport: NSObject, MCPTransport {
    private var task: URLSessionWebSocketTask?
    private var url: URL?
    private var headers: [String: String] = [:]

    var onMessage: ((Data) -> Void)?
    var onError: ((String) -> Void)?
    var onClose: (() -> Void)?

    func start(config: MCPServerConfig) throws {
        guard let urlString = config.url,
              let url = URL(string: urlString) else {
            throw MCPWebSocketTransportError.invalidURL(config.url ?? "")
        }

        self.url = url
        self.headers = config.headers ?? [:]

        var request = URLRequest(url: url)
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let task = URLSession.shared.webSocketTask(with: request)
        self.task = task
        task.resume()
        receiveLoop()
    }

    func send(_ data: Data) throws {
        guard let task else {
            throw MCPTransportError.notConnected
        }

        let semaphore = DispatchSemaphore(value: 0)
        var sendError: Error?
        task.send(.data(data)) { error in
            sendError = error
            semaphore.signal()
        }

        if semaphore.wait(timeout: .now() + 30) == .timedOut {
            throw MCPWebSocketTransportError.requestTimedOut
        }

        if let error = sendError {
            throw error
        }
    }

    func stop() {
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
    }

    private func receiveLoop() {
        task?.receive { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let message):
                switch message {
                case .data(let data):
                    DispatchQueue.main.async {
                        self.onMessage?(data)
                    }
                case .string(let text):
                    if let data = text.data(using: .utf8) {
                        DispatchQueue.main.async {
                            self.onMessage?(data)
                        }
                    }
                @unknown default:
                    break
                }
                self.receiveLoop()
            case .failure(let error):
                self.onError?(error.localizedDescription)
                self.onClose?()
            }
        }
    }
}
