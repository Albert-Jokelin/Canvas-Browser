import Foundation
import Vision
import AppKit
import os.log

/// Identifies objects, landmarks, plants, animals in web images using Visual Look Up
@MainActor
class VisualLookUpManager: ObservableObject {
    static let shared = VisualLookUpManager()

    // MARK: - Published Properties

    @Published var isAnalyzing = false
    @Published var lastAnalysisResult: VisualAnalysisResult?
    @Published var detectedSubjects: [VisualSubject] = []

    private let logger = Logger(subsystem: "com.canvas.browser", category: "VisualLookUp")

    private init() {}

    // MARK: - Image Analysis

    /// Analyze an image for recognizable subjects
    func analyzeImage(_ image: NSImage) async throws -> VisualAnalysisResult {
        isAnalyzing = true
        defer { isAnalyzing = false }

        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw VisualLookUpError.invalidImage
        }

        var subjects: [VisualSubject] = []

        // Run multiple Vision requests in parallel
        async let classificationResults = classifyImage(cgImage)
        async let objectResults = detectObjects(cgImage)
        async let faceResults = detectFaces(cgImage)
        async let barcodeResults = detectBarcodes(cgImage)
        async let textResults = detectText(cgImage)

        // Combine results
        subjects.append(contentsOf: try await classificationResults)
        subjects.append(contentsOf: try await objectResults)
        subjects.append(contentsOf: try await faceResults)
        subjects.append(contentsOf: try await barcodeResults)
        subjects.append(contentsOf: try await textResults)

        // Sort by confidence
        subjects.sort { $0.confidence > $1.confidence }

        // Deduplicate similar subjects
        subjects = deduplicateSubjects(subjects)

        let result = VisualAnalysisResult(subjects: subjects, imageSize: image.size)
        lastAnalysisResult = result
        detectedSubjects = subjects

        logger.info("Analyzed image: found \(subjects.count) subjects")
        return result
    }

    // MARK: - Classification

    private func classifyImage(_ cgImage: CGImage) async throws -> [VisualSubject] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNClassifyImageRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNClassificationObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                // Take top 5 classifications with confidence > 0.3
                let subjects = observations
                    .filter { $0.confidence > 0.3 }
                    .prefix(5)
                    .map { observation -> VisualSubject in
                        VisualSubject(
                            type: self.categorizeClassification(observation.identifier),
                            identifier: observation.identifier,
                            displayName: self.formatIdentifier(observation.identifier),
                            confidence: Double(observation.confidence),
                            boundingBox: nil
                        )
                    }

                continuation.resume(returning: Array(subjects))
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func categorizeClassification(_ identifier: String) -> VisualSubjectType {
        let lowerIdentifier = identifier.lowercased()

        if lowerIdentifier.contains("dog") || lowerIdentifier.contains("cat") ||
           lowerIdentifier.contains("bird") || lowerIdentifier.contains("fish") ||
           lowerIdentifier.contains("animal") {
            return .animal
        }

        if lowerIdentifier.contains("flower") || lowerIdentifier.contains("plant") ||
           lowerIdentifier.contains("tree") || lowerIdentifier.contains("leaf") {
            return .plant
        }

        if lowerIdentifier.contains("building") || lowerIdentifier.contains("bridge") ||
           lowerIdentifier.contains("monument") || lowerIdentifier.contains("tower") {
            return .landmark
        }

        if lowerIdentifier.contains("food") || lowerIdentifier.contains("dish") ||
           lowerIdentifier.contains("meal") || lowerIdentifier.contains("fruit") {
            return .food
        }

        if lowerIdentifier.contains("art") || lowerIdentifier.contains("painting") ||
           lowerIdentifier.contains("sculpture") {
            return .artwork
        }

        if lowerIdentifier.contains("book") || lowerIdentifier.contains("movie") ||
           lowerIdentifier.contains("album") {
            return .media
        }

        return .object
    }

    private func formatIdentifier(_ identifier: String) -> String {
        identifier
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.capitalized }
            .joined(separator: " ")
    }

    // MARK: - Object Detection

    private func detectObjects(_ cgImage: CGImage) async throws -> [VisualSubject] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeAnimalsRequest { request, error in
                if let error = error {
                    self.logger.warning("Animal detection failed: \(error.localizedDescription)")
                    continuation.resume(returning: [])
                    return
                }

                guard let observations = request.results as? [VNRecognizedObjectObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                let subjects = observations.compactMap { observation -> VisualSubject? in
                    guard let label = observation.labels.first else { return nil }
                    return VisualSubject(
                        type: .animal,
                        identifier: label.identifier,
                        displayName: self.formatIdentifier(label.identifier),
                        confidence: Double(label.confidence),
                        boundingBox: observation.boundingBox
                    )
                }

                continuation.resume(returning: subjects)
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: [])
            }
        }
    }

    // MARK: - Face Detection

    private func detectFaces(_ cgImage: CGImage) async throws -> [VisualSubject] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectFaceRectanglesRequest { request, error in
                if let error = error {
                    self.logger.warning("Face detection failed: \(error.localizedDescription)")
                    continuation.resume(returning: [])
                    return
                }

                guard let observations = request.results as? [VNFaceObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                let subjects = observations.enumerated().map { index, observation in
                    VisualSubject(
                        type: .person,
                        identifier: "face_\(index)",
                        displayName: "Person \(index + 1)",
                        confidence: Double(observation.confidence),
                        boundingBox: observation.boundingBox
                    )
                }

                continuation.resume(returning: subjects)
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: [])
            }
        }
    }

    // MARK: - Barcode Detection

    private func detectBarcodes(_ cgImage: CGImage) async throws -> [VisualSubject] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectBarcodesRequest { request, error in
                if let error = error {
                    self.logger.warning("Barcode detection failed: \(error.localizedDescription)")
                    continuation.resume(returning: [])
                    return
                }

                guard let observations = request.results as? [VNBarcodeObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                let subjects = observations.compactMap { observation -> VisualSubject? in
                    guard let payload = observation.payloadStringValue else { return nil }

                    var type: VisualSubjectType = .barcode
                    if payload.hasPrefix("http://") || payload.hasPrefix("https://") {
                        type = .qrCode
                    }

                    return VisualSubject(
                        type: type,
                        identifier: payload,
                        displayName: type == .qrCode ? "QR Code" : "Barcode",
                        confidence: Double(observation.confidence),
                        boundingBox: observation.boundingBox,
                        actionData: payload
                    )
                }

                continuation.resume(returning: subjects)
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: [])
            }
        }
    }

    // MARK: - Text Detection (for context)

    private func detectText(_ cgImage: CGImage) async throws -> [VisualSubject] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(returning: [])
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                // Only include if significant text found
                let textBlocks = observations.compactMap { $0.topCandidates(1).first?.string }
                if textBlocks.count > 3 {
                    let subject = VisualSubject(
                        type: .text,
                        identifier: "text_content",
                        displayName: "Text Detected",
                        confidence: 0.8,
                        boundingBox: nil,
                        actionData: textBlocks.joined(separator: "\n")
                    )
                    continuation.resume(returning: [subject])
                } else {
                    continuation.resume(returning: [])
                }
            }

            request.recognitionLevel = .fast

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: [])
            }
        }
    }

    // MARK: - Deduplication

    private func deduplicateSubjects(_ subjects: [VisualSubject]) -> [VisualSubject] {
        var seen = Set<String>()
        return subjects.filter { subject in
            let key = "\(subject.type)-\(subject.identifier)"
            if seen.contains(key) {
                return false
            }
            seen.insert(key)
            return true
        }
    }

    // MARK: - Actions

    /// Search for more information about a subject
    func searchForSubject(_ subject: VisualSubject) {
        let query = subject.displayName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject.displayName

        let searchURL: String
        switch subject.type {
        case .animal, .plant:
            searchURL = "https://www.google.com/search?q=\(query)&tbm=isch"
        case .landmark:
            searchURL = "https://www.google.com/search?q=\(query)+landmark"
        case .artwork:
            searchURL = "https://www.google.com/search?q=\(query)+art"
        case .food:
            searchURL = "https://www.google.com/search?q=\(query)+recipe"
        case .qrCode:
            if let data = subject.actionData, let url = URL(string: data) {
                NotificationCenter.default.post(
                    name: .openURLFromIntent,
                    object: nil,
                    userInfo: ["url": url.absoluteString, "newTab": true]
                )
                return
            }
            searchURL = "https://www.google.com/search?q=\(query)"
        default:
            searchURL = "https://www.google.com/search?q=\(query)"
        }

        NotificationCenter.default.post(
            name: .openURLFromIntent,
            object: nil,
            userInfo: ["url": searchURL, "newTab": true]
        )

        logger.info("Searching for subject: \(subject.displayName)")
    }

    /// Get available actions for a subject
    func getActions(for subject: VisualSubject) -> [VisualLookUpAction] {
        var actions: [VisualLookUpAction] = []

        // Common actions
        actions.append(VisualLookUpAction(
            title: "Search",
            icon: "magnifyingglass",
            action: { [weak self] in self?.searchForSubject(subject) }
        ))

        // Type-specific actions
        switch subject.type {
        case .qrCode:
            if let url = subject.actionData {
                actions.insert(VisualLookUpAction(
                    title: "Open Link",
                    icon: "link",
                    action: { [weak self] in self?.searchForSubject(subject) }
                ), at: 0)

                actions.append(VisualLookUpAction(
                    title: "Copy URL",
                    icon: "doc.on.doc",
                    action: {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(url, forType: .string)
                    }
                ))
            }

        case .animal, .plant:
            actions.append(VisualLookUpAction(
                title: "Wikipedia",
                icon: "book",
                action: {
                    let query = subject.displayName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject.displayName
                    NotificationCenter.default.post(
                        name: .openURLFromIntent,
                        object: nil,
                        userInfo: ["url": "https://en.wikipedia.org/wiki/\(query)", "newTab": true]
                    )
                }
            ))

        case .food:
            actions.append(VisualLookUpAction(
                title: "Find Recipe",
                icon: "fork.knife",
                action: {
                    let query = subject.displayName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject.displayName
                    NotificationCenter.default.post(
                        name: .openURLFromIntent,
                        object: nil,
                        userInfo: ["url": "https://www.google.com/search?q=\(query)+recipe", "newTab": true]
                    )
                }
            ))

        case .landmark:
            actions.append(VisualLookUpAction(
                title: "Show in Maps",
                icon: "map",
                action: {
                    let query = subject.displayName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject.displayName
                    if let url = URL(string: "https://maps.apple.com/?q=\(query)") {
                        NSWorkspace.shared.open(url)
                    }
                }
            ))

        case .text:
            if let text = subject.actionData {
                actions.append(VisualLookUpAction(
                    title: "Copy Text",
                    icon: "doc.on.doc",
                    action: {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(text, forType: .string)
                    }
                ))
            }

        default:
            break
        }

        return actions
    }
}

// MARK: - Supporting Types

struct VisualAnalysisResult {
    let subjects: [VisualSubject]
    let imageSize: NSSize

    var isEmpty: Bool { subjects.isEmpty }

    var primarySubject: VisualSubject? { subjects.first }
}

struct VisualSubject: Identifiable {
    let id = UUID()
    let type: VisualSubjectType
    let identifier: String
    let displayName: String
    let confidence: Double
    let boundingBox: CGRect?
    var actionData: String?

    var confidencePercentage: Int {
        Int(confidence * 100)
    }
}

enum VisualSubjectType: String {
    case animal
    case plant
    case landmark
    case food
    case artwork
    case media
    case person
    case object
    case barcode
    case qrCode
    case text

    var icon: String {
        switch self {
        case .animal: return "pawprint.fill"
        case .plant: return "leaf.fill"
        case .landmark: return "building.columns.fill"
        case .food: return "fork.knife"
        case .artwork: return "paintpalette.fill"
        case .media: return "play.rectangle.fill"
        case .person: return "person.fill"
        case .object: return "cube.fill"
        case .barcode: return "barcode"
        case .qrCode: return "qrcode"
        case .text: return "text.alignleft"
        }
    }

    var displayName: String {
        switch self {
        case .animal: return "Animal"
        case .plant: return "Plant"
        case .landmark: return "Landmark"
        case .food: return "Food"
        case .artwork: return "Artwork"
        case .media: return "Media"
        case .person: return "Person"
        case .object: return "Object"
        case .barcode: return "Barcode"
        case .qrCode: return "QR Code"
        case .text: return "Text"
        }
    }
}

struct VisualLookUpAction {
    let title: String
    let icon: String
    let action: () -> Void
}

enum VisualLookUpError: LocalizedError {
    case invalidImage
    case analysisFailed
    case noSubjectsFound

    var errorDescription: String? {
        switch self {
        case .invalidImage: return "Could not process the image"
        case .analysisFailed: return "Image analysis failed"
        case .noSubjectsFound: return "No recognizable subjects found"
        }
    }
}
