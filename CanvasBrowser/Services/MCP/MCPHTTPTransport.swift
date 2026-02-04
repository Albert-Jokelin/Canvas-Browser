import Foundation

enum MCPHTTPTransportError: LocalizedError {
    case invalidURL(String)
    case httpError(Int)
    case requestTimedOut

    var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .httpError(let status):
            return "HTTP error: \(status)"
        case .requestTimedOut:
            return "HTTP request timed out"
        }
    }
}

/// Transport layer for MCP communication over HTTP SSE
final class MCPHTTPTransport: NSObject, MCPTransport, URLSessionDataDelegate {
    private var session: URLSession?
    private var task: URLSessionDataTask?
    private var url: URL?
    private var headers: [String: String] = [:]

    private var buffer = ""
    private var eventDataLines: [String] = []

    var onMessage: ((Data) -> Void)?
    var onError: ((String) -> Void)?
    var onClose: (() -> Void)?

    func start(config: MCPServerConfig) throws {
        guard let urlString = config.url,
              let url = URL(string: urlString) else {
            throw MCPHTTPTransportError.invalidURL(config.url ?? "")
        }

        self.url = url
        self.headers = config.headers ?? [:]

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 0
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData

        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        self.session = session

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let task = session.dataTask(with: request)
        self.task = task
        task.resume()
    }

    func send(_ data: Data) throws {
        guard let url else {
            throw MCPHTTPTransportError.invalidURL("")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = data
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let semaphore = DispatchSemaphore(value: 0)
        var responseError: Error?
        var statusCode: Int?

        URLSession.shared.dataTask(with: request) { _, response, error in
            responseError = error
            if let http = response as? HTTPURLResponse {
                statusCode = http.statusCode
            }
            semaphore.signal()
        }.resume()

        if semaphore.wait(timeout: .now() + 30) == .timedOut {
            throw MCPHTTPTransportError.requestTimedOut
        }

        if let error = responseError {
            throw error
        }

        if let status = statusCode, !(200...299).contains(status) {
            throw MCPHTTPTransportError.httpError(status)
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        session?.invalidateAndCancel()
        session = nil
        buffer = ""
        eventDataLines = []
    }

    // MARK: - URLSessionDataDelegate

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let chunk = String(data: data, encoding: .utf8) else { return }
        buffer.append(chunk)
        processBuffer()
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            onError?("HTTP error: \(http.statusCode)")
            completionHandler(.cancel)
            return
        }
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            onError?(error.localizedDescription)
        }
        onClose?()
    }

    // MARK: - SSE Parsing

    private func processBuffer() {
        while let range = buffer.range(of: "\n") {
            let line = String(buffer[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            buffer.removeSubrange(..<range.upperBound)

            if line.isEmpty {
                if !eventDataLines.isEmpty {
                    let message = eventDataLines.joined(separator: "\n")
                    eventDataLines.removeAll()
                    if let data = message.data(using: .utf8) {
                        DispatchQueue.main.async { [weak self] in
                            self?.onMessage?(data)
                        }
                    }
                }
                continue
            }

            if line.hasPrefix("data:") {
                let dataPart = line.dropFirst("data:".count).trimmingCharacters(in: .whitespaces)
                eventDataLines.append(dataPart)
            }
        }
    }
}
