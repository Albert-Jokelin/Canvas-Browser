import SwiftUI
import AppKit

/// Manages floating desktop widgets that display GenTabs
class FloatingWidgetManager: ObservableObject {
    static let shared = FloatingWidgetManager()

    @Published var activeWidgets: [FloatingWidget] = []

    private init() {
        loadSavedWidgets()
    }

    // MARK: - Widget Creation

    func createWidget(from genTab: GenTab, position: NSPoint? = nil) {
        // Check if widget already exists for this GenTab
        if activeWidgets.contains(where: { $0.genTab.id == genTab.id }) {
            // Bring existing widget to front
            if let widget = activeWidgets.first(where: { $0.genTab.id == genTab.id }) {
                widget.window?.makeKeyAndOrderFront(nil)
            }
            return
        }

        let widget = FloatingWidget(genTab: genTab)
        activeWidgets.append(widget)

        // Create and show the floating window
        let window = createFloatingWindow(for: widget, position: position)
        widget.window = window
        window.makeKeyAndOrderFront(nil)

        saveWidgetState()
    }

    func createFloatingWindow(for widget: FloatingWidget, position: NSPoint? = nil) -> NSPanel {
        let initialRect: NSRect
        if let pos = position {
            initialRect = NSRect(x: pos.x, y: pos.y, width: 320, height: 400)
        } else {
            // Center on screen with offset for each widget
            let offset = CGFloat(activeWidgets.count - 1) * 30
            initialRect = NSRect(x: 100 + offset, y: 100 + offset, width: 320, height: 400)
        }

        let window = NSPanel(
            contentRect: initialRect,
            styleMask: [.titled, .closable, .resizable, .miniaturizable, .nonactivatingPanel, .utilityWindow],
            backing: .buffered,
            defer: false
        )

        window.title = widget.genTab.title
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .managed]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.minSize = NSSize(width: 200, height: 150)

        // Set up visual effect for vibrancy
        let visualEffect = NSVisualEffectView()
        visualEffect.material = .popover
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 12
        visualEffect.layer?.masksToBounds = true

        let hostingView = NSHostingView(rootView: FloatingWidgetView(widget: widget, manager: self))
        hostingView.frame = visualEffect.bounds
        hostingView.autoresizingMask = [.width, .height]

        visualEffect.addSubview(hostingView)
        window.contentView = visualEffect

        // Handle window close
        window.delegate = widget

        return window
    }

    // MARK: - Widget Management

    func closeWidget(_ widget: FloatingWidget) {
        widget.window?.close()
        activeWidgets.removeAll { $0.id == widget.id }
        saveWidgetState()
    }

    func closeAllWidgets() {
        for widget in activeWidgets {
            widget.window?.close()
        }
        activeWidgets.removeAll()
        saveWidgetState()
    }

    func bringAllToFront() {
        for widget in activeWidgets {
            widget.window?.makeKeyAndOrderFront(nil)
        }
    }

    // MARK: - Persistence

    private let storageKey = "canvas_floating_widgets"

    func saveWidgetState() {
        struct WidgetState: Codable {
            let genTabId: UUID
            let genTab: GenTab
            let isCompact: Bool
            let frame: CGRect
        }

        let states = activeWidgets.compactMap { widget -> WidgetState? in
            guard let frame = widget.window?.frame else { return nil }
            return WidgetState(
                genTabId: widget.genTab.id,
                genTab: widget.genTab,
                isCompact: widget.isCompact,
                frame: frame
            )
        }

        if let data = try? JSONEncoder().encode(states) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    func loadSavedWidgets() {
        struct WidgetState: Codable {
            let genTabId: UUID
            let genTab: GenTab
            let isCompact: Bool
            let frame: CGRect
        }

        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let states = try? JSONDecoder().decode([WidgetState].self, from: data) else {
            return
        }

        // Restore widgets after a delay to ensure app is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            for state in states {
                let widget = FloatingWidget(genTab: state.genTab)
                widget.isCompact = state.isCompact
                self.activeWidgets.append(widget)

                let position = NSPoint(x: state.frame.origin.x, y: state.frame.origin.y)
                let window = self.createFloatingWindow(for: widget, position: position)
                window.setFrame(state.frame, display: true)
                widget.window = window
                window.orderFront(nil)
            }
        }
    }
}

// MARK: - Floating Widget

class FloatingWidget: NSObject, Identifiable, ObservableObject, NSWindowDelegate {
    let id = UUID()
    let genTab: GenTab
    var window: NSWindow?
    @Published var isCompact = false
    @Published var opacity: Double = 1.0

    init(genTab: GenTab) {
        self.genTab = genTab
        super.init()
    }

    func windowWillClose(_ notification: Notification) {
        FloatingWidgetManager.shared.activeWidgets.removeAll { $0.id == self.id }
        FloatingWidgetManager.shared.saveWidgetState()
    }
}

// MARK: - Floating Widget View

struct FloatingWidgetView: View {
    @ObservedObject var widget: FloatingWidget
    @ObservedObject var manager: FloatingWidgetManager
    @State private var isHoveringHeader = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            widgetHeader

            if !widget.isCompact {
                Divider()

                // Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(widget.genTab.components.enumerated()), id: \.offset) { _, component in
                            GenTabComponentView(component: component)
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(minWidth: widget.isCompact ? 200 : 280, minHeight: widget.isCompact ? 50 : 200)
        .opacity(widget.opacity)
    }

    private var widgetHeader: some View {
        HStack(spacing: 8) {
            // Icon
            Image(systemName: widget.genTab.icon)
                .font(.title3)
                .foregroundColor(.accentColor)

            // Title
            Text(widget.genTab.title)
                .font(.headline)
                .lineLimit(1)

            Spacer()

            // Controls (visible on hover)
            if isHoveringHeader {
                HStack(spacing: 4) {
                    // Opacity slider
                    Slider(value: $widget.opacity, in: 0.3...1.0)
                        .frame(width: 60)

                    // Compact toggle
                    Button(action: { widget.isCompact.toggle() }) {
                        Image(systemName: widget.isCompact ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left")
                    }
                    .buttonStyle(.borderless)
                    .help(widget.isCompact ? "Expand" : "Collapse")

                    // Open in Canvas
                    Button(action: openInCanvas) {
                        Image(systemName: "arrow.up.forward.square")
                    }
                    .buttonStyle(.borderless)
                    .help("Open in Canvas")

                    // Close
                    Button(action: { manager.closeWidget(widget) }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .help("Close Widget")
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.8))
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHoveringHeader = hovering
            }
        }
    }

    func openInCanvas() {
        NotificationCenter.default.post(
            name: NSNotification.Name("openGenTabInCanvas"),
            object: nil,
            userInfo: ["genTab": widget.genTab]
        )
        manager.closeWidget(widget)
    }
}

// MARK: - Context Menu for GenTabs

extension GenTab {
    var contextMenuItems: some View {
        Group {
            Button(action: {
                FloatingWidgetManager.shared.createWidget(from: self)
            }) {
                Label("Open as Widget", systemImage: "macwindow.badge.plus")
            }

            Button(action: {
                NotificationCenter.default.post(
                    name: .addToShelf,
                    object: nil,
                    userInfo: ["genTab": self]
                )
            }) {
                Label("Add to Shelf", systemImage: "tray.and.arrow.down")
            }
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let openGenTabInCanvas = Notification.Name("openGenTabInCanvas")
    static let createFloatingWidget = Notification.Name("createFloatingWidget")
}
