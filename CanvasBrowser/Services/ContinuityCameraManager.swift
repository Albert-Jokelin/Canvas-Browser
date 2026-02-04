import Foundation
import AppKit
import Vision
import VisionKit
import os.log

/// Manages Continuity Camera for document scanning and photo capture
@MainActor
class ContinuityCameraManager: NSObject, ObservableObject {
    static let shared = ContinuityCameraManager()

    // MARK: - Published Properties

    @Published var isProcessing = false
    @Published var lastCapturedImage: NSImage?
    @Published var lastExtractedText: String?
    @Published var scanResults: [ScanResult] = []

    private let logger = Logger(subsystem: "com.canvas.browser", category: "ContinuityCamera")

    override private init() {
        super.init()
    }

    // MARK: - Continuity Camera Menu Items

    /// Get Continuity Camera menu items for a view
    func getContinuityCameraMenuItems(for view: NSView, completion: @escaping (CaptureResult) -> Void) -> [NSMenuItem] {
        var items: [NSMenuItem] = []

        // Take Photo
        let photoItem = NSMenuItem(title: "Take Photo", action: #selector(capturePhoto(_:)), keyEquivalent: "")
        photoItem.target = self
        photoItem.representedObject = CaptureContext(type: .photo, view: view, completion: completion)
        items.append(photoItem)

        // Scan Documents
        let scanItem = NSMenuItem(title: "Scan Documents", action: #selector(scanDocuments(_:)), keyEquivalent: "")
        scanItem.target = self
        scanItem.representedObject = CaptureContext(type: .document, view: view, completion: completion)
        items.append(scanItem)

        return items
    }

    // MARK: - Capture Actions

    @objc private func capturePhoto(_ sender: NSMenuItem) {
        guard let context = sender.representedObject as? CaptureContext else { return }

        // In macOS 14+, we can use the Continuity Camera API
        // For now, we'll open a file dialog for testing
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.message = "Select an image (Continuity Camera would capture directly)"

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }

            Task { @MainActor in
                do {
                    let image = NSImage(contentsOf: url)
                    self?.lastCapturedImage = image
                    context.completion(.photo(image))
                    self?.logger.info("Photo captured/selected")
                } catch {
                    self?.logger.error("Failed to load image: \(error.localizedDescription)")
                }
            }
        }
    }

    @objc private func scanDocuments(_ sender: NSMenuItem) {
        guard let context = sender.representedObject as? CaptureContext else { return }

        // Similar to photo, would use VNDocumentCameraViewController on iOS
        // On macOS, we simulate with file selection
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, .pdf]
        panel.allowsMultipleSelection = true
        panel.message = "Select documents to scan (Continuity Camera would scan directly)"

        panel.begin { [weak self] response in
            guard response == .OK, !panel.urls.isEmpty else { return }

            Task { @MainActor in
                self?.isProcessing = true
                defer { self?.isProcessing = false }

                var results: [ScanResult] = []

                for url in panel.urls {
                    if let result = await self?.processScannedDocument(url) {
                        results.append(result)
                    }
                }

                self?.scanResults = results
                context.completion(.documents(results))
                self?.logger.info("Processed \(results.count) documents")
            }
        }
    }

    // MARK: - Document Processing

    private func processScannedDocument(_ url: URL) async -> ScanResult? {
        guard let image = NSImage(contentsOf: url) else { return nil }

        // Perform OCR
        let extractedText = await performOCR(on: image)

        // Detect QR codes
        let qrCodes = await detectQRCodes(in: image)

        return ScanResult(
            id: UUID(),
            image: image,
            extractedText: extractedText,
            qrCodes: qrCodes,
            timestamp: Date()
        )
    }

    // MARK: - OCR

    private func performOCR(on image: NSImage) async -> String? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    self.logger.error("OCR failed: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: nil)
                    return
                }

                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")

                continuation.resume(returning: text.isEmpty ? nil : text)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }

    // MARK: - QR Code Detection

    private func detectQRCodes(in image: NSImage) async -> [String] {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return []
        }

        return await withCheckedContinuation { continuation in
            let request = VNDetectBarcodesRequest { request, error in
                if let error = error {
                    self.logger.error("QR detection failed: \(error.localizedDescription)")
                    continuation.resume(returning: [])
                    return
                }

                guard let observations = request.results as? [VNBarcodeObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                let codes = observations.compactMap { $0.payloadStringValue }
                continuation.resume(returning: codes)
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: [])
            }
        }
    }

    // MARK: - Actions

    /// Copy extracted text to clipboard
    func copyExtractedText(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        logger.info("Copied extracted text to clipboard")
    }

    /// Open QR code URL
    func openQRCodeURL(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            logger.warning("Invalid QR code URL: \(urlString)")
            return
        }

        NotificationCenter.default.post(
            name: .openURLFromIntent,
            object: nil,
            userInfo: ["url": url.absoluteString, "newTab": true]
        )

        logger.info("Opening QR code URL: \(urlString)")
    }

    /// Search with scanned text
    func searchWithText(_ text: String) {
        let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text
        let searchURL = "https://www.google.com/search?q=\(encodedText)"

        NotificationCenter.default.post(
            name: .openURLFromIntent,
            object: nil,
            userInfo: ["url": searchURL, "newTab": true]
        )

        logger.info("Searching with scanned text")
    }

    /// Reverse image search
    func reverseImageSearch(_ image: NSImage) {
        // Save image temporarily and perform reverse image search
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("canvas_search_\(UUID().uuidString).png")

        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            logger.error("Failed to convert image for search")
            return
        }

        do {
            try pngData.write(to: tempURL)
            // In production, you'd upload this to a reverse image search service
            // For now, open Google Images
            let searchURL = "https://images.google.com/"
            NotificationCenter.default.post(
                name: .openURLFromIntent,
                object: nil,
                userInfo: ["url": searchURL, "newTab": true]
            )
            logger.info("Initiated reverse image search")
        } catch {
            logger.error("Failed to save image for search: \(error.localizedDescription)")
        }
    }

    // MARK: - Clear Results

    func clearResults() {
        lastCapturedImage = nil
        lastExtractedText = nil
        scanResults.removeAll()
    }
}

// MARK: - Supporting Types

struct CaptureContext {
    enum CaptureType {
        case photo
        case document
    }

    let type: CaptureType
    let view: NSView
    let completion: (CaptureResult) -> Void
}

enum CaptureResult {
    case photo(NSImage?)
    case documents([ScanResult])
    case cancelled
}

struct ScanResult: Identifiable {
    let id: UUID
    let image: NSImage
    let extractedText: String?
    let qrCodes: [String]
    let timestamp: Date

    var hasText: Bool { extractedText != nil && !extractedText!.isEmpty }
    var hasQRCodes: Bool { !qrCodes.isEmpty }
}

// MARK: - Continuity Camera Service Provider

/// Provides Continuity Camera services to NSResponder chain
class ContinuityCameraServiceProvider: NSObject, NSServicesMenuRequestor {
    weak var targetView: NSView?
    var completionHandler: ((NSImage) -> Void)?

    func readSelection(from pasteboard: NSPasteboard) -> Bool {
        // Handle incoming image from Continuity Camera
        guard let imageData = pasteboard.data(forType: .tiff),
              let image = NSImage(data: imageData) else {
            return false
        }

        completionHandler?(image)
        return true
    }

    func writeSelection(to pasteboard: NSPasteboard, types: [NSPasteboard.PasteboardType]) -> Bool {
        return false
    }
}
