import Foundation
import Vision
import AppKit
import os.log

/// Manages Live Text extraction and interaction with text in images
@MainActor
class LiveTextManager: ObservableObject {
    static let shared = LiveTextManager()

    // MARK: - Published Properties

    @Published var isProcessing = false
    @Published var lastExtractedText: String?
    @Published var detectedItems: [DetectedItem] = []

    private let logger = Logger(subsystem: "com.canvas.browser", category: "LiveText")

    private init() {}

    // MARK: - Text Recognition

    /// Extract text from an image
    func extractText(from image: NSImage) async throws -> TextExtractionResult {
        isProcessing = true
        defer { isProcessing = false }

        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw LiveTextError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { [weak self] request, error in
                Task { @MainActor in
                    if let error = error {
                        self?.logger.error("Text recognition failed: \(error.localizedDescription)")
                        continuation.resume(throwing: error)
                        return
                    }

                    guard let observations = request.results as? [VNRecognizedTextObservation] else {
                        continuation.resume(returning: TextExtractionResult(text: "", items: []))
                        return
                    }

                    let result = self?.processTextObservations(observations, imageSize: image.size)
                    self?.lastExtractedText = result?.text
                    self?.detectedItems = result?.items ?? []

                    continuation.resume(returning: result ?? TextExtractionResult(text: "", items: []))
                }
            }

            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["en-US", "en-GB", "de-DE", "fr-FR", "es-ES", "it-IT", "pt-BR", "zh-Hans", "zh-Hant", "ja-JP", "ko-KR"]
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func processTextObservations(_ observations: [VNRecognizedTextObservation], imageSize: NSSize) -> TextExtractionResult {
        var allText: [String] = []
        var items: [DetectedItem] = []

        for observation in observations {
            guard let candidate = observation.topCandidates(1).first else { continue }

            let text = candidate.string
            allText.append(text)

            // Detect special items (phone numbers, URLs, addresses, emails)
            let detectedSpecialItems = detectSpecialItems(in: text, boundingBox: observation.boundingBox, imageSize: imageSize)
            items.append(contentsOf: detectedSpecialItems)
        }

        let fullText = allText.joined(separator: "\n")
        logger.info("Extracted \(allText.count) text blocks, detected \(items.count) special items")

        return TextExtractionResult(text: fullText, items: items)
    }

    // MARK: - Special Item Detection

    private func detectSpecialItems(in text: String, boundingBox: CGRect, imageSize: NSSize) -> [DetectedItem] {
        var items: [DetectedItem] = []

        // Phone number detection
        let phonePattern = #"[\+]?[(]?[0-9]{1,3}[)]?[-\s\.]?[(]?[0-9]{1,4}[)]?[-\s\.]?[0-9]{1,4}[-\s\.]?[0-9]{1,9}"#
        if let phoneMatches = text.matches(of: try! Regex(phonePattern)).first {
            let phoneNumber = String(text[phoneMatches.range])
            items.append(DetectedItem(
                type: .phoneNumber,
                text: phoneNumber,
                boundingBox: boundingBox,
                action: .call(phoneNumber)
            ))
        }

        // Email detection
        let emailPattern = #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#
        if let emailMatches = text.matches(of: try! Regex(emailPattern)).first {
            let email = String(text[emailMatches.range])
            items.append(DetectedItem(
                type: .email,
                text: email,
                boundingBox: boundingBox,
                action: .email(email)
            ))
        }

        // URL detection
        let urlPattern = #"https?://[^\s]+"#
        if let urlMatches = text.matches(of: try! Regex(urlPattern)).first {
            let urlString = String(text[urlMatches.range])
            if let url = URL(string: urlString) {
                items.append(DetectedItem(
                    type: .url,
                    text: urlString,
                    boundingBox: boundingBox,
                    action: .openURL(url)
                ))
            }
        }

        // Address detection (simplified)
        let addressPattern = #"\d+\s+[\w\s]+(?:Street|St|Avenue|Ave|Road|Rd|Boulevard|Blvd|Drive|Dr|Lane|Ln|Way|Court|Ct)"#
        if let addressMatches = text.matches(of: try! Regex(addressPattern, as: Substring.self)).first {
            let address = String(addressMatches.output)
            items.append(DetectedItem(
                type: .address,
                text: address,
                boundingBox: boundingBox,
                action: .showInMaps(address)
            ))
        }

        // Date detection
        let datePattern = #"\d{1,2}[/\-\.]\d{1,2}[/\-\.]\d{2,4}"#
        if let dateMatches = text.matches(of: try! Regex(datePattern)).first {
            let dateString = String(text[dateMatches.range])
            items.append(DetectedItem(
                type: .date,
                text: dateString,
                boundingBox: boundingBox,
                action: .createEvent(dateString)
            ))
        }

        return items
    }

    // MARK: - Actions

    /// Copy extracted text to clipboard
    func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        logger.info("Copied text to clipboard: \(text.prefix(50))...")
    }

    /// Perform action for detected item
    func performAction(_ item: DetectedItem) {
        switch item.action {
        case .call(let phoneNumber):
            callPhoneNumber(phoneNumber)

        case .email(let address):
            composeEmail(to: address)

        case .openURL(let url):
            openURL(url)

        case .showInMaps(let address):
            showInMaps(address)

        case .createEvent(let dateString):
            createCalendarEvent(dateString)

        case .translate(let text):
            translateText(text)

        case .lookup(let text):
            lookupText(text)

        case .copy(let text):
            copyToClipboard(text)
        }
    }

    private func callPhoneNumber(_ number: String) {
        let cleanedNumber = number.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
        if let url = URL(string: "tel:\(cleanedNumber)") {
            NSWorkspace.shared.open(url)
        }
    }

    private func composeEmail(to address: String) {
        if let url = URL(string: "mailto:\(address)") {
            NSWorkspace.shared.open(url)
        }
    }

    private func openURL(_ url: URL) {
        NotificationCenter.default.post(
            name: .openURLFromIntent,
            object: nil,
            userInfo: ["url": url.absoluteString, "newTab": true]
        )
    }

    private func showInMaps(_ address: String) {
        let encodedAddress = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? address
        if let url = URL(string: "https://maps.apple.com/?q=\(encodedAddress)") {
            NSWorkspace.shared.open(url)
        }
    }

    private func createCalendarEvent(_ dateString: String) {
        // Open Calendar app - in production would create actual event
        if let url = URL(string: "x-apple-calendar://") {
            NSWorkspace.shared.open(url)
        }
    }

    private func translateText(_ text: String) {
        // Open in Translate - macOS 14+
        let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text
        if let url = URL(string: "x-apple-translate://?text=\(encodedText)") {
            NSWorkspace.shared.open(url)
        }
    }

    private func lookupText(_ text: String) {
        // Use Dictionary lookup
        // This would typically use NSTextView's showDefinition method
        logger.info("Looking up: \(text)")
    }

    // MARK: - Quick Actions

    /// Get available quick actions for extracted text
    func getQuickActions(for text: String) -> [QuickAction] {
        var actions: [QuickAction] = []

        // Always available
        actions.append(QuickAction(title: "Copy", icon: "doc.on.doc", action: { [weak self] in
            self?.copyToClipboard(text)
        }))

        actions.append(QuickAction(title: "Translate", icon: "globe", action: { [weak self] in
            self?.translateText(text)
        }))

        actions.append(QuickAction(title: "Look Up", icon: "book", action: { [weak self] in
            self?.lookupText(text)
        }))

        // Search
        actions.append(QuickAction(title: "Search", icon: "magnifyingglass", action: {
            let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text
            if let url = URL(string: "https://www.google.com/search?q=\(encodedText)") {
                NotificationCenter.default.post(
                    name: .openURLFromIntent,
                    object: nil,
                    userInfo: ["url": url.absoluteString, "newTab": true]
                )
            }
        }))

        return actions
    }
}

// MARK: - Supporting Types

struct TextExtractionResult {
    let text: String
    let items: [DetectedItem]

    var isEmpty: Bool {
        text.isEmpty && items.isEmpty
    }
}

struct DetectedItem: Identifiable {
    let id = UUID()
    let type: DetectedItemType
    let text: String
    let boundingBox: CGRect
    let action: DetectedItemAction
}

enum DetectedItemType {
    case phoneNumber
    case email
    case url
    case address
    case date
    case text

    var icon: String {
        switch self {
        case .phoneNumber: return "phone.fill"
        case .email: return "envelope.fill"
        case .url: return "link"
        case .address: return "map.fill"
        case .date: return "calendar"
        case .text: return "text.alignleft"
        }
    }
}

enum DetectedItemAction {
    case call(String)
    case email(String)
    case openURL(URL)
    case showInMaps(String)
    case createEvent(String)
    case translate(String)
    case lookup(String)
    case copy(String)
}

struct QuickAction {
    let title: String
    let icon: String
    let action: () -> Void
}

enum LiveTextError: LocalizedError {
    case invalidImage
    case recognitionFailed
    case noTextFound

    var errorDescription: String? {
        switch self {
        case .invalidImage: return "Could not process the image"
        case .recognitionFailed: return "Text recognition failed"
        case .noTextFound: return "No text found in image"
        }
    }
}
