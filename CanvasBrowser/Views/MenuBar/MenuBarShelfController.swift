import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Controller for the Menu Bar Dynamic Shelf - a system-wide staging area
class MenuBarShelfController: NSObject, ObservableObject {
    static let shared = MenuBarShelfController()

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?

    @Published var shelfItems: [ShelfItem] = []
    @Published var isGlowing = false
    @Published var suggestedIntent: String?

    private var analysisTimer: Timer?

    override init() {
        super.init()
        loadShelfItems()
    }

    // MARK: - Setup

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "tray.and.arrow.down.fill", accessibilityDescription: "Dynamic Shelf")
            button.action = #selector(toggleShelf)
            button.target = self
            updateBadge()
        }

        // Create popover
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 400, height: 500)
        popover?.behavior = .transient
        popover?.animates = true
        popover?.contentViewController = NSHostingController(
            rootView: DynamicShelfPopoverView(controller: self)
        )

        startAIMonitoring()
    }

    @objc func toggleShelf() {
        guard let button = statusItem?.button, let popover = popover else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    // MARK: - Badge Management

    func updateBadge() {
        DispatchQueue.main.async {
            if let button = self.statusItem?.button {
                if self.shelfItems.isEmpty {
                    button.title = ""
                    button.image = NSImage(systemSymbolName: "tray.and.arrow.down", accessibilityDescription: "Dynamic Shelf")
                } else {
                    button.title = " \(self.shelfItems.count)"
                    button.image = NSImage(systemSymbolName: "tray.and.arrow.down.fill", accessibilityDescription: "Dynamic Shelf")
                }
            }
        }
    }

    // MARK: - AI Monitoring

    func startAIMonitoring() {
        analysisTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.analyzeShelfContents()
        }
    }

    func stopAIMonitoring() {
        analysisTimer?.invalidate()
        analysisTimer = nil
    }

    func analyzeShelfContents() {
        guard shelfItems.count >= 2 else {
            DispatchQueue.main.async {
                self.isGlowing = false
                self.suggestedIntent = nil
            }
            return
        }

        Task {
            let result = await checkIfReadyForGenTab()

            await MainActor.run {
                self.isGlowing = result.ready
                self.suggestedIntent = result.intent

                if result.ready {
                    self.animateMenuBarGlow()
                }
            }
        }
    }

    func checkIfReadyForGenTab() async -> (ready: Bool, intent: String?) {
        let itemDescriptions = shelfItems.map { $0.description }.joined(separator: "\n")

        let prompt = """
        The user has collected these items in their Dynamic Shelf:
        \(itemDescriptions)

        Analyze if there's a clear intent that would benefit from creating a GenTab (interactive visualization).

        Respond in this exact JSON format:
        {"ready": true/false, "intent": "brief description of detected intent or null"}

        Examples of intents:
        - Trip planning (multiple travel-related URLs)
        - Product comparison (shopping URLs)
        - Research collection (articles on same topic)
        - Recipe gathering (food-related content)

        Respond with ONLY the JSON, no other text.
        """

        do {
            let response = try await GeminiService().generateResponse(prompt: prompt)
            let cleaned = response.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")

            if let data = cleaned.data(using: .utf8) {
                struct AnalysisResult: Codable {
                    let ready: Bool
                    let intent: String?
                }
                let result = try JSONDecoder().decode(AnalysisResult.self, from: data)
                return (result.ready, result.intent)
            }
        } catch {
            print("Shelf analysis error: \(error)")
        }

        return (false, nil)
    }

    func animateMenuBarGlow() {
        guard let button = statusItem?.button else { return }

        // Add subtle glow animation
        let animation = CABasicAnimation(keyPath: "backgroundColor")
        animation.fromValue = NSColor.clear.cgColor
        animation.toValue = NSColor.systemBlue.withAlphaComponent(0.3).cgColor
        animation.duration = 0.5
        animation.autoreverses = true
        animation.repeatCount = 3

        button.layer?.add(animation, forKey: "glow")
    }

    // MARK: - Item Management

    func addItem(_ item: ShelfItem) {
        DispatchQueue.main.async {
            // Avoid duplicates
            if !self.shelfItems.contains(where: { $0.preview == item.preview }) {
                self.shelfItems.insert(item, at: 0)
                self.saveShelfItems()
                self.updateBadge()
            }
        }
    }

    func removeItem(_ item: ShelfItem) {
        DispatchQueue.main.async {
            self.shelfItems.removeAll { $0.id == item.id }
            self.saveShelfItems()
            self.updateBadge()
        }
    }

    func clearAll() {
        DispatchQueue.main.async {
            self.shelfItems.removeAll()
            self.isGlowing = false
            self.suggestedIntent = nil
            self.saveShelfItems()
            self.updateBadge()
        }
    }

    // MARK: - GenTab Building

    func buildGenTabFromShelf() async throws -> GenTab {
        let context = shelfItems.map { item -> String in
            switch item.type {
            case .url:
                return "URL: \(item.preview)"
            case .text:
                return "Text snippet: \(item.preview)"
            case .image:
                return "Image"
            case .file:
                return "File: \(item.preview)"
            }
        }.joined(separator: "\n")

        let prompt = """
        Create a GenTab based on these collected items:
        \(context)

        Detected intent: \(suggestedIntent ?? "General collection")

        Create an interactive, useful visualization that helps the user accomplish their goal.
        """

        let genTab = try await GeminiService().buildGenTab(for: prompt)

        // Clear shelf after building
        await MainActor.run {
            self.clearAll()
        }

        return genTab
    }

    // MARK: - Persistence

    private let storageKey = "canvas_shelf_items"

    func saveShelfItems() {
        if let data = try? JSONEncoder().encode(shelfItems) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    func loadShelfItems() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let items = try? JSONDecoder().decode([ShelfItem].self, from: data) {
            shelfItems = items
        }
    }
}

// MARK: - Shelf Item Model

struct ShelfItem: Identifiable, Codable {
    let id: UUID
    let type: ItemType
    let preview: String
    let fullContent: String
    let timestamp: Date
    let sourceDomain: String?

    enum ItemType: String, Codable {
        case url
        case text
        case image
        case file
    }

    init(type: ItemType, preview: String, fullContent: String, sourceDomain: String? = nil) {
        self.id = UUID()
        self.type = type
        self.preview = preview
        self.fullContent = fullContent
        self.timestamp = Date()
        self.sourceDomain = sourceDomain
    }

    var description: String {
        switch type {
        case .url:
            if let domain = sourceDomain {
                return "URL from \(domain): \(preview)"
            }
            return "URL: \(preview)"
        case .text:
            return "Text: \(preview)"
        case .image:
            return "Image"
        case .file:
            return "File: \(preview)"
        }
    }

    var icon: String {
        switch type {
        case .url: return "link"
        case .text: return "text.alignleft"
        case .image: return "photo"
        case .file: return "doc"
        }
    }

    var color: Color {
        switch type {
        case .url: return .blue
        case .text: return .orange
        case .image: return .purple
        case .file: return .green
        }
    }
}

// MARK: - Shelf Popover View

struct DynamicShelfPopoverView: View {
    @ObservedObject var controller: MenuBarShelfController
    @State private var dragOver = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            shelfHeader

            Divider()

            // Content
            if controller.shelfItems.isEmpty {
                emptyState
            } else {
                shelfContent
            }

            Divider()

            // Footer actions
            shelfFooter
        }
        .frame(width: 400, height: 500)
        .onDrop(of: [.url, .text, .fileURL, .utf8PlainText], isTargeted: $dragOver) { providers in
            handleDrop(providers)
            return true
        }
    }

    // MARK: - Header

    private var shelfHeader: some View {
        HStack {
            Image(systemName: "tray.and.arrow.down.fill")
                .foregroundColor(.accentColor)

            Text("Dynamic Shelf")
                .font(.headline)

            Spacer()

            if controller.isGlowing, let intent = controller.suggestedIntent {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.blue)
                    Text(intent)
                        .font(.caption)
                        .foregroundColor(.blue)
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .clipShape(Capsule())
            }

            Text("\(controller.shelfItems.count)")
                .font(.caption.weight(.medium))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.secondary)
                .clipShape(Capsule())
        }
        .padding()
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: "tray.and.arrow.down")
                    .font(.system(size: 32))
                    .foregroundColor(.accentColor)
            }

            Text("Drop items here")
                .font(.title3.weight(.medium))

            Text("Collect URLs, text, images, or files\nfrom anywhere on your Mac")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(dragOver ? Color.accentColor.opacity(0.1) : Color.clear)
        .animation(.easeInOut(duration: 0.2), value: dragOver)
    }

    // MARK: - Content

    private var shelfContent: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(controller.shelfItems) { item in
                    ShelfItemRow(item: item) {
                        controller.removeItem(item)
                    }
                }
            }
            .padding()
        }
        .background(dragOver ? Color.accentColor.opacity(0.05) : Color.clear)
    }

    // MARK: - Footer

    private var shelfFooter: some View {
        HStack {
            Button("Clear All") {
                controller.clearAll()
            }
            .buttonStyle(.borderless)
            .disabled(controller.shelfItems.isEmpty)

            Spacer()

            if controller.isGlowing {
                Button(action: buildGenTab) {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("Build GenTab")
                    }
                }
                .buttonStyle(.borderedProminent)
            } else if !controller.shelfItems.isEmpty {
                Button(action: buildGenTab) {
                    Text("Build GenTab")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
    }

    // MARK: - Actions

    func handleDrop(_ providers: [NSItemProvider]) {
        for provider in providers {
            // Handle URLs
            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.url.identifier) { item, _ in
                    if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        let shelfItem = ShelfItem(
                            type: .url,
                            preview: url.absoluteString,
                            fullContent: url.absoluteString,
                            sourceDomain: url.host
                        )
                        controller.addItem(shelfItem)
                    } else if let url = item as? URL {
                        let shelfItem = ShelfItem(
                            type: .url,
                            preview: url.absoluteString,
                            fullContent: url.absoluteString,
                            sourceDomain: url.host
                        )
                        controller.addItem(shelfItem)
                    }
                }
            }

            // Handle plain text
            if provider.hasItemConformingToTypeIdentifier(UTType.utf8PlainText.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.utf8PlainText.identifier) { item, _ in
                    if let data = item as? Data, let text = String(data: data, encoding: .utf8) {
                        let preview = String(text.prefix(100)) + (text.count > 100 ? "..." : "")
                        let shelfItem = ShelfItem(
                            type: .text,
                            preview: preview,
                            fullContent: text
                        )
                        controller.addItem(shelfItem)
                    }
                }
            }

            // Handle file URLs
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                    if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        let shelfItem = ShelfItem(
                            type: .file,
                            preview: url.lastPathComponent,
                            fullContent: url.path
                        )
                        controller.addItem(shelfItem)
                    }
                }
            }
        }
    }

    func buildGenTab() {
        Task {
            do {
                let genTab = try await controller.buildGenTabFromShelf()

                NotificationCenter.default.post(
                    name: NSNotification.Name("genTabCreated"),
                    object: nil,
                    userInfo: ["genTab": genTab]
                )
            } catch {
                print("Failed to build GenTab: \(error)")
            }
        }
    }
}

// MARK: - Shelf Item Row

struct ShelfItemRow: View {
    let item: ShelfItem
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: item.icon)
                .font(.title3)
                .foregroundColor(item.color)
                .frame(width: 36, height: 36)
                .background(item.color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(item.preview)
                    .font(.body)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    if let domain = item.sourceDomain {
                        Text(domain)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text(item.timestamp, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Delete button
            if isHovered {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    static let addToShelf = Notification.Name("CanvasAddToShelf")
}
