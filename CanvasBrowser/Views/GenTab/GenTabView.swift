import SwiftUI
import AppKit

/// Main view for displaying a GenTab with its dynamically generated components
struct GenTabView: View {
    @EnvironmentObject var appState: AppState
    @State var genTab: GenTab
    var onSourceTap: ((SourceAttribution) -> Void)?
    var onGenTabUpdate: ((GenTab) -> Void)?

    @State private var modifyPrompt: String = ""
    @State private var isModifying: Bool = false
    @State private var showModifyInput: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            GenTabHeaderView(
                title: genTab.title,
                icon: genTab.icon,
                onExportPDF: { exportAsPDF() },
                onShare: { shareGenTab() },
                onRefresh: { refreshGenTab() },
                onModify: { showModifyInput.toggle() }
            )

            // Modification input bar
            if showModifyInput {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.purple)

                    TextField("Modify this GenTab... (e.g., 'add a summary section', 'sort by price')", text: $modifyPrompt)
                        .textFieldStyle(.plain)
                        .onSubmit {
                            modifyGenTab()
                        }

                    if isModifying {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Button(action: modifyGenTab) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title2)
                                .foregroundColor(modifyPrompt.isEmpty ? .secondary : .purple)
                        }
                        .buttonStyle(.plain)
                        .disabled(modifyPrompt.isEmpty)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(NSColor.controlBackgroundColor))
                .overlay(Divider(), alignment: .bottom)
            }

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let html = genTab.html, !html.isEmpty {
                        GenTabHTMLView(html: html)
                    } else {
                        // Render each component dynamically
                        ForEach(Array(genTab.components.enumerated()), id: \.offset) { index, component in
                            GenTabComponentView(component: component)
                        }
                    }

                    // Source attribution footer
                    if !genTab.sourceURLs.isEmpty {
                        Divider()
                            .padding(.vertical, 8)

                        SourceAttributionView(
                            sources: genTab.sourceURLs,
                            onSourceTap: onSourceTap
                        )
                    }
                }
                .padding(24)
            }
            .background(Color(NSColor.textBackgroundColor))
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Actions

    private func modifyGenTab() {
        guard !modifyPrompt.isEmpty else { return }

        isModifying = true
        let instruction = modifyPrompt
        modifyPrompt = ""

        Task {
            do {
                let modified = try await appState.aiOrchestrator.geminiService.modifyGenTab(genTab, instruction: instruction)
                await MainActor.run {
                    genTab = modified
                    onGenTabUpdate?(modified)
                    isModifying = false
                }
            } catch {
                print("Failed to modify GenTab: \(error)")
                await MainActor.run {
                    isModifying = false
                }
            }
        }
    }

    private func refreshGenTab() {
        // Re-generate the GenTab with the same sources
        Task {
            do {
                let urls = genTab.sourceURLs.map { $0.url }
                let titles = genTab.sourceURLs.map { $0.title }

                if let refreshed = try await appState.aiOrchestrator.geminiService.analyzeURLsForGenTab(urls: urls, titles: titles) {
                    await MainActor.run {
                        genTab = refreshed
                        onGenTabUpdate?(refreshed)
                    }
                }
            } catch {
                print("Failed to refresh GenTab: \(error)")
            }
        }
    }

    private func shareGenTab() {
        // Create shareable text
        var shareText = "# \(genTab.title)\n\n"

        for component in genTab.components {
            shareText += componentToText(component)
        }

        if !genTab.sourceURLs.isEmpty {
            shareText += "\n---\nSources:\n"
            for source in genTab.sourceURLs {
                shareText += "- \(source.title): \(source.url)\n"
            }
        }

        let picker = NSSharingServicePicker(items: [shareText])
        if let window = NSApp.keyWindow, let contentView = window.contentView {
            picker.show(relativeTo: .zero, of: contentView, preferredEdge: .minY)
        }
    }

    private func exportAsPDF() {
        // Create PDF content
        let pdfView = GenTabPDFContent(genTab: genTab)

        let renderer = ImageRenderer(content: pdfView.frame(width: 612)) // US Letter width in points
        renderer.scale = 2.0 // Retina

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.pdf]
        savePanel.nameFieldStringValue = "\(genTab.title).pdf"

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                renderer.render { size, context in
                    var box = CGRect(origin: .zero, size: size)

                    guard let pdf = CGContext(url as CFURL, mediaBox: &box, nil) else { return }

                    pdf.beginPDFPage(nil)
                    context(pdf)
                    pdf.endPDFPage()
                    pdf.closePDF()
                }
            }
        }
    }

    private func componentToText(_ component: GenTabComponent) -> String {
        switch component {
        case .header(let text):
            return "## \(text)\n\n"
        case .paragraph(let text):
            return "\(text)\n\n"
        case .bulletList(let items):
            return items.map { "• \($0)" }.joined(separator: "\n") + "\n\n"
        case .numberedList(let items):
            return items.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n") + "\n\n"
        case .table(let columns, let rows):
            var text = "| " + columns.joined(separator: " | ") + " |\n"
            text += "| " + columns.map { _ in "---" }.joined(separator: " | ") + " |\n"
            for row in rows {
                text += "| " + row.joined(separator: " | ") + " |\n"
            }
            return text + "\n"
        case .callout(let type, let text):
            return "[\(type.rawValue.uppercased())] \(text)\n\n"
        case .keyValue(let pairs):
            return pairs.map { "\($0.key): \($0.value)" }.joined(separator: "\n") + "\n\n"
        case .divider:
            return "---\n\n"
        case .link(let title, let url):
            return "[\(title)](\(url))\n"
        default:
            return ""
        }
    }
}

// MARK: - PDF Export View

struct GenTabPDFContent: View {
    let genTab: GenTab

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title
            HStack {
                Image(systemName: genTab.icon)
                    .font(.title)
                    .foregroundColor(.purple)
                Text(genTab.title)
                    .font(.title)
                    .fontWeight(.bold)
            }
            .padding(.bottom, 8)

            Divider()

            // Components
            ForEach(Array(genTab.components.enumerated()), id: \.offset) { _, component in
                GenTabComponentView(component: component)
            }

            // Sources
            if !genTab.sourceURLs.isEmpty {
                Divider()
                    .padding(.vertical, 8)

                Text("Sources")
                    .font(.headline)

                ForEach(genTab.sourceURLs) { source in
                    Text("• \(source.title): \(source.url)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Footer
            HStack {
                Spacer()
                Text("Generated by Canvas Browser")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(40)
        .background(Color.white)
    }
}

// MARK: - Header View

struct GenTabHeaderView: View {
    let title: String
    let icon: String
    var onExportPDF: (() -> Void)?
    var onShare: (() -> Void)?
    var onRefresh: (() -> Void)?
    var onModify: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.purple)

            Text(title)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            Spacer()

            // Modify button
            Button(action: { onModify?() }) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)
            .foregroundColor(.purple)
            .help("Modify with AI")

            // Actions menu
            Menu {
                Button(action: { onExportPDF?() }) {
                    Label("Export as PDF", systemImage: "doc.fill")
                }
                Button(action: { onShare?() }) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                Divider()
                Button(action: { onRefresh?() }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 30)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(NSColor.windowBackgroundColor))
        .border(width: 1, edges: [.bottom], color: Color.secondary.opacity(0.2))
    }
}

// MARK: - Border Extension

extension View {
    func border(width: CGFloat, edges: [Edge], color: Color) -> some View {
        overlay(EdgeBorder(width: width, edges: edges).foregroundColor(color))
    }
}

struct EdgeBorder: Shape {
    var width: CGFloat
    var edges: [Edge]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for edge in edges {
            var x: CGFloat {
                switch edge {
                case .top, .bottom, .leading: return rect.minX
                case .trailing: return rect.maxX - width
                }
            }

            var y: CGFloat {
                switch edge {
                case .top, .leading, .trailing: return rect.minY
                case .bottom: return rect.maxY - width
                }
            }

            var w: CGFloat {
                switch edge {
                case .top, .bottom: return rect.width
                case .leading, .trailing: return width
                }
            }

            var h: CGFloat {
                switch edge {
                case .top, .bottom: return width
                case .leading, .trailing: return rect.height
                }
            }
            path.addRect(CGRect(x: x, y: y, width: w, height: h))
        }
        return path
    }
}

// MARK: - Preview Support

#if DEBUG
struct GenTabView_Previews: PreviewProvider {
    static var previews: some View {
        GenTabView(genTab: GenTab(
            title: "MacBook Comparison",
            icon: "laptopcomputer",
            components: [
                .header(text: "Top Picks"),
                .paragraph(text: "Based on your browsing, here are the best options:"),
                .table(
                    columns: ["Model", "Price", "Rating"],
                    rows: [
                        ["MacBook Air M3", "$1,099", "4.8/5"],
                        ["MacBook Pro 14\"", "$1,599", "4.9/5"],
                        ["MacBook Pro 16\"", "$2,499", "4.7/5"]
                    ]
                ),
                .callout(type: .tip, text: "The MacBook Air M3 offers the best value for most users."),
                .divider,
                .bulletList(items: [
                    "All models include 8GB RAM base",
                    "M3 chip offers 20% better performance",
                    "Battery life: 15-22 hours"
                ])
            ],
            sourceURLs: [
                SourceAttribution(url: "https://apple.com", title: "Apple", domain: "apple.com"),
                SourceAttribution(url: "https://amazon.com", title: "Amazon", domain: "amazon.com")
            ]
        ))
        .environmentObject(AppState())
        .frame(width: 600, height: 700)
    }
}
#endif
