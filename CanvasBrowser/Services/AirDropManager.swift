import Foundation
import AppKit
import UniformTypeIdentifiers
import os.log

/// Manages AirDrop sharing for pages and GenTabs
@MainActor
class AirDropManager: ObservableObject {
    static let shared = AirDropManager()

    private let logger = Logger(subsystem: "com.canvas.browser", category: "AirDrop")

    private init() {}

    // MARK: - Share Current Page

    /// Share the current page URL via AirDrop
    func shareURL(_ url: URL, title: String?, from view: NSView? = nil) {
        let items: [Any] = [url]
        presentSharingService(items: items, from: view)
    }

    /// Share URL with preview text
    func shareURLWithPreview(url: URL, title: String, selectedText: String?, from view: NSView? = nil) {
        var items: [Any] = []

        // Create a rich text representation
        let shareText = buildShareText(url: url, title: title, selectedText: selectedText)
        items.append(shareText)
        items.append(url)

        presentSharingService(items: items, from: view)
    }

    private func buildShareText(url: URL, title: String, selectedText: String?) -> String {
        var text = title

        if let selected = selectedText, !selected.isEmpty {
            text += "\n\n\"\(selected)\""
        }

        text += "\n\n\(url.absoluteString)"
        text += "\n\nShared from Canvas Browser"

        return text
    }

    // MARK: - Share GenTab

    /// Share a GenTab as a shareable package
    func shareGenTab(_ genTab: GenTab, from view: NSView? = nil) {
        // Create a temporary file with GenTab data
        let tempURL = createGenTabShareFile(genTab)

        guard let fileURL = tempURL else {
            logger.error("Failed to create GenTab share file")
            return
        }

        // Also create a text summary
        let summary = createGenTabSummary(genTab)

        let items: [Any] = [summary, fileURL]
        presentSharingService(items: items, from: view)
    }

    private func createGenTabShareFile(_ genTab: GenTab) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "\(genTab.title.replacingOccurrences(of: " ", with: "_")).gentab"
        let fileURL = tempDir.appendingPathComponent(fileName)

        do {
            let data = try JSONEncoder().encode(genTab)
            try data.write(to: fileURL)
            return fileURL
        } catch {
            logger.error("Failed to encode GenTab: \(error.localizedDescription)")
            return nil
        }
    }

    private func createGenTabSummary(_ genTab: GenTab) -> String {
        var summary = "GenTab: \(genTab.title)\n"
        summary += "Created: \(formatDate(genTab.createdAt))\n\n"

        // Extract text content from components
        for component in genTab.components.prefix(5) {
            switch component {
            case .header(let text):
                summary += "## \(text)\n"
            case .paragraph(let text):
                summary += "\(text)\n\n"
            case .bulletList(let items):
                for item in items.prefix(3) {
                    summary += "• \(item)\n"
                }
                if items.count > 3 {
                    summary += "• ...\n"
                }
            case .keyValue(let pairs):
                for pair in pairs.prefix(3) {
                    summary += "\(pair.key): \(pair.value)\n"
                }
            default:
                break
            }
        }

        summary += "\nShared from Canvas Browser"
        return summary
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    // MARK: - Share Selected Text

    /// Share selected text with source URL
    func shareSelectedText(_ text: String, sourceURL: URL?, from view: NSView? = nil) {
        var shareContent = "\"\(text)\""

        if let url = sourceURL {
            shareContent += "\n\nSource: \(url.absoluteString)"
        }

        shareContent += "\n\nShared from Canvas Browser"

        var items: [Any] = [shareContent]
        if let url = sourceURL {
            items.append(url)
        }

        presentSharingService(items: items, from: view)
    }

    // MARK: - Share Image

    /// Share an image from the web page
    func shareImage(_ image: NSImage, caption: String?, sourceURL: URL?, from view: NSView? = nil) {
        var items: [Any] = [image]

        if let caption = caption {
            items.append(caption)
        }

        if let url = sourceURL {
            items.append(url)
        }

        presentSharingService(items: items, from: view)
    }

    // MARK: - Share Reading List Item

    /// Share a reading list item
    func shareReadingListItem(_ item: ReadingListItem, from view: NSView? = nil) {
        var shareText = item.title

        if let excerpt = item.excerpt, !excerpt.isEmpty {
            shareText += "\n\n\(excerpt)"
        }

        shareText += "\n\n\(item.url)"
        shareText += "\n\nFrom my Reading List - Canvas Browser"

        let items: [Any] = [shareText, URL(string: item.url)].compactMap { $0 }
        presentSharingService(items: items, from: view)
    }

    // MARK: - Sharing Service Presentation

    private func presentSharingService(items: [Any], from view: NSView?) {
        let picker = NSSharingServicePicker(items: items)

        // Filter to show AirDrop prominently
        picker.delegate = AirDropPickerDelegate.shared

        if let view = view {
            picker.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
        } else if let window = NSApp.mainWindow, let contentView = window.contentView {
            // Show from center of window if no view specified
            let rect = NSRect(x: contentView.bounds.midX - 1, y: contentView.bounds.midY - 1, width: 2, height: 2)
            picker.show(relativeTo: rect, of: contentView, preferredEdge: .minY)
        }

        logger.info("Presented sharing service with \(items.count) items")
    }

    // MARK: - AirDrop-Specific Share

    /// Share directly via AirDrop without showing picker
    func shareViaAirDropDirectly(items: [Any]) {
        guard let airDropService = NSSharingService(named: .sendViaAirDrop) else {
            logger.warning("AirDrop service not available")
            return
        }

        if airDropService.canPerform(withItems: items) {
            airDropService.perform(withItems: items)
            logger.info("Initiated AirDrop share")
        } else {
            logger.warning("Cannot perform AirDrop with provided items")
        }
    }

    // MARK: - Check AirDrop Availability

    var isAirDropAvailable: Bool {
        NSSharingService(named: .sendViaAirDrop) != nil
    }
}

// MARK: - Sharing Picker Delegate

class AirDropPickerDelegate: NSObject, NSSharingServicePickerDelegate {
    static let shared = AirDropPickerDelegate()

    func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker,
                              sharingServicesForItems items: [Any],
                              proposedSharingServices proposedServices: [NSSharingService]) -> [NSSharingService] {
        // Move AirDrop to the front if available
        var services = proposedServices

        if let airDropIndex = services.firstIndex(where: { $0.title == "AirDrop" }) {
            let airDrop = services.remove(at: airDropIndex)
            services.insert(airDrop, at: 0)
        }

        return services
    }

    func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker,
                              didChoose service: NSSharingService?) {
        // Log which service was chosen
        if let service = service {
            print("User chose sharing service: \(service.title)")
        }
    }
}

// MARK: - GenTab File Type

extension UTType {
    static var genTab: UTType {
        UTType(exportedAs: "com.canvas.browser.gentab")
    }
}
