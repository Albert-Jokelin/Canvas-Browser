import Foundation
import SwiftUI

/// Manages cloud deployment and sharing of GenTabs
class CloudDeploymentManager: ObservableObject {
    static let shared = CloudDeploymentManager()

    @Published var deployedGenTabs: [DeployedGenTab] = []
    @Published var isDeploying = false
    @Published var deploymentError: String?

    private let storageKey = "canvas_deployed_gentabs"

    private init() {
        loadDeployedGenTabs()
    }

    // MARK: - Deployed GenTab Model

    struct DeployedGenTab: Identifiable, Codable {
        let id: UUID
        let genTabId: UUID
        let title: String
        let shareURL: URL
        let shortCode: String
        let createdAt: Date
        let expiresAt: Date?
        var viewCount: Int

        init(genTab: GenTab, shareURL: URL, shortCode: String, expiresAt: Date? = nil) {
            self.id = UUID()
            self.genTabId = genTab.id
            self.title = genTab.title
            self.shareURL = shareURL
            self.shortCode = shortCode
            self.createdAt = Date()
            self.expiresAt = expiresAt
            self.viewCount = 0
        }

        var isExpired: Bool {
            if let expiresAt = expiresAt {
                return Date() > expiresAt
            }
            return false
        }
    }

    // MARK: - Deployment

    /// Deploy a GenTab to the cloud and get a shareable URL
    func deployToCloud(_ genTab: GenTab, expiresIn: TimeInterval? = nil) async throws -> DeployedGenTab {
        await MainActor.run {
            isDeploying = true
            deploymentError = nil
        }

        defer {
            Task { @MainActor in
                isDeploying = false
            }
        }

        // Serialize GenTab to JSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let genTabData = try encoder.encode(genTab)

        // Generate a short code for the share URL
        let shortCode = generateShortCode()

        // In a real implementation, you would upload to your cloud backend
        // For now, we'll use a local data URL as a placeholder
        // This would be replaced with actual API call like:
        // let uploadURL = URL(string: "https://api.canvasbrowser.app/gentabs/deploy")!

        // Create a base64 encoded data URL for demonstration
        let base64Data = genTabData.base64EncodedString()
        let shareURL = URL(string: "canvas://gentab/\(shortCode)")!

        // Store the GenTab data locally (in production, this would be on server)
        storeGenTabData(shortCode: shortCode, data: genTabData)

        let expiresAt = expiresIn.map { Date().addingTimeInterval($0) }

        let deployed = DeployedGenTab(
            genTab: genTab,
            shareURL: shareURL,
            shortCode: shortCode,
            expiresAt: expiresAt
        )

        await MainActor.run {
            deployedGenTabs.append(deployed)
            saveDeployedGenTabs()
        }

        return deployed
    }

    /// Generate HTML for a deployable GenTab
    func generateShareableHTML(for genTab: GenTab) -> String {
        let encoder = JSONEncoder()
        let jsonData = (try? encoder.encode(genTab)) ?? Data()
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"

        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(genTab.title) - Canvas GenTab</title>
            <style>
                :root {
                    --bg-color: #1a1a1a;
                    --card-bg: #2a2a2a;
                    --text-primary: #ffffff;
                    --text-secondary: #888888;
                    --accent: #007AFF;
                }
                @media (prefers-color-scheme: light) {
                    :root {
                        --bg-color: #f5f5f5;
                        --card-bg: #ffffff;
                        --text-primary: #000000;
                        --text-secondary: #666666;
                    }
                }
                * { box-sizing: border-box; margin: 0; padding: 0; }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    background: var(--bg-color);
                    color: var(--text-primary);
                    padding: 20px;
                    line-height: 1.6;
                }
                .container { max-width: 800px; margin: 0 auto; }
                .header {
                    display: flex;
                    align-items: center;
                    gap: 12px;
                    margin-bottom: 24px;
                    padding-bottom: 16px;
                    border-bottom: 1px solid var(--text-secondary);
                }
                .header h1 { font-size: 24px; }
                .component { margin-bottom: 16px; }
                .card-grid {
                    display: grid;
                    grid-template-columns: repeat(auto-fill, minmax(250px, 1fr));
                    gap: 16px;
                }
                .card {
                    background: var(--card-bg);
                    border-radius: 12px;
                    padding: 16px;
                    box-shadow: 0 2px 8px rgba(0,0,0,0.1);
                }
                .card h3 { margin-bottom: 8px; }
                .card p { color: var(--text-secondary); font-size: 14px; }
                .callout {
                    padding: 12px 16px;
                    border-radius: 8px;
                    margin: 8px 0;
                }
                .callout.info { background: rgba(0,122,255,0.1); border-left: 3px solid #007AFF; }
                .callout.warning { background: rgba(255,149,0,0.1); border-left: 3px solid #FF9500; }
                .callout.tip { background: rgba(255,204,0,0.1); border-left: 3px solid #FFCC00; }
                ul, ol { padding-left: 24px; }
                table { width: 100%; border-collapse: collapse; margin: 8px 0; }
                th, td { padding: 8px 12px; text-align: left; border-bottom: 1px solid var(--text-secondary); }
                th { background: var(--card-bg); }
                .footer {
                    margin-top: 32px;
                    padding-top: 16px;
                    border-top: 1px solid var(--text-secondary);
                    font-size: 12px;
                    color: var(--text-secondary);
                    text-align: center;
                }
                .footer a { color: var(--accent); text-decoration: none; }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>\(genTab.title)</h1>
                </div>
                <div id="content"></div>
                <div class="footer">
                    Created with <a href="https://canvasbrowser.app">Canvas Browser</a>
                </div>
            </div>
            <script>
                const genTabData = \(jsonString);
                const container = document.getElementById('content');

                function renderComponents(components) {
                    components.forEach(comp => {
                        const div = document.createElement('div');
                        div.className = 'component';

                        switch(comp.type) {
                            case 'header':
                                div.innerHTML = '<h2>' + comp.text + '</h2>';
                                break;
                            case 'paragraph':
                                div.innerHTML = '<p>' + comp.text + '</p>';
                                break;
                            case 'bulletList':
                                div.innerHTML = '<ul>' + comp.items.map(i => '<li>' + i + '</li>').join('') + '</ul>';
                                break;
                            case 'numberedList':
                                div.innerHTML = '<ol>' + comp.items.map(i => '<li>' + i + '</li>').join('') + '</ol>';
                                break;
                            case 'cardGrid':
                                div.className = 'card-grid';
                                div.innerHTML = comp.cards.map(c =>
                                    '<div class="card"><h3>' + c.title + '</h3>' +
                                    (c.subtitle ? '<p><strong>' + c.subtitle + '</strong></p>' : '') +
                                    (c.description ? '<p>' + c.description + '</p>' : '') +
                                    '</div>'
                                ).join('');
                                break;
                            case 'callout':
                                div.className = 'callout ' + comp.calloutType;
                                div.innerHTML = comp.text;
                                break;
                            case 'table':
                                let tableHtml = '<table><thead><tr>' +
                                    comp.columns.map(c => '<th>' + c + '</th>').join('') +
                                    '</tr></thead><tbody>' +
                                    comp.rows.map(row => '<tr>' + row.map(cell => '<td>' + cell + '</td>').join('') + '</tr>').join('') +
                                    '</tbody></table>';
                                div.innerHTML = tableHtml;
                                break;
                            case 'keyValue':
                                div.innerHTML = comp.pairs.map(p =>
                                    '<p><strong>' + p.key + ':</strong> ' + p.value + '</p>'
                                ).join('');
                                break;
                            case 'divider':
                                div.innerHTML = '<hr>';
                                break;
                            case 'link':
                                div.innerHTML = '<a href="' + comp.url + '" target="_blank">' + comp.title + '</a>';
                                break;
                        }

                        container.appendChild(div);
                    });
                }

                if (genTabData.components) {
                    renderComponents(genTabData.components);
                }
            </script>
        </body>
        </html>
        """
    }

    /// Export GenTab as HTML file
    func exportAsHTML(_ genTab: GenTab) -> URL? {
        let html = generateShareableHTML(for: genTab)

        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "\(genTab.title.replacingOccurrences(of: " ", with: "_")).html"
        let fileURL = tempDir.appendingPathComponent(fileName)

        do {
            try html.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Failed to export HTML: \(error)")
            return nil
        }
    }

    // MARK: - Retrieval

    /// Get a deployed GenTab by its short code
    func getDeployedGenTab(shortCode: String) -> DeployedGenTab? {
        return deployedGenTabs.first { $0.shortCode == shortCode && !$0.isExpired }
    }

    /// Load the original GenTab data from a short code
    func loadGenTabData(shortCode: String) -> GenTab? {
        guard let data = retrieveGenTabData(shortCode: shortCode) else { return nil }

        do {
            return try JSONDecoder().decode(GenTab.self, from: data)
        } catch {
            print("Failed to decode GenTab: \(error)")
            return nil
        }
    }

    // MARK: - Management

    func deleteDeployment(_ deployment: DeployedGenTab) {
        deployedGenTabs.removeAll { $0.id == deployment.id }
        removeGenTabData(shortCode: deployment.shortCode)
        saveDeployedGenTabs()
    }

    func incrementViewCount(shortCode: String) {
        if let index = deployedGenTabs.firstIndex(where: { $0.shortCode == shortCode }) {
            deployedGenTabs[index].viewCount += 1
            saveDeployedGenTabs()
        }
    }

    // MARK: - Helpers

    private func generateShortCode() -> String {
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<8).map { _ in characters.randomElement()! })
    }

    // MARK: - Local Storage (would be cloud in production)

    private func storeGenTabData(shortCode: String, data: Data) {
        UserDefaults.standard.set(data, forKey: "gentab_\(shortCode)")
    }

    private func retrieveGenTabData(shortCode: String) -> Data? {
        UserDefaults.standard.data(forKey: "gentab_\(shortCode)")
    }

    private func removeGenTabData(shortCode: String) {
        UserDefaults.standard.removeObject(forKey: "gentab_\(shortCode)")
    }

    // MARK: - Persistence

    private func saveDeployedGenTabs() {
        if let data = try? JSONEncoder().encode(deployedGenTabs) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadDeployedGenTabs() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let deployed = try? JSONDecoder().decode([DeployedGenTab].self, from: data) {
            deployedGenTabs = deployed.filter { !$0.isExpired }
        }
    }
}

// MARK: - Share Sheet

struct ShareGenTabSheet: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var deploymentManager = CloudDeploymentManager.shared

    let genTab: GenTab

    @State private var shareURL: URL?
    @State private var isDeploying = false
    @State private var expirationOption: ExpirationOption = .never
    @State private var showCopiedConfirmation = false

    enum ExpirationOption: String, CaseIterable {
        case oneHour = "1 hour"
        case oneDay = "24 hours"
        case oneWeek = "7 days"
        case oneMonth = "30 days"
        case never = "Never"

        var timeInterval: TimeInterval? {
            switch self {
            case .oneHour: return 3600
            case .oneDay: return 86400
            case .oneWeek: return 604800
            case .oneMonth: return 2592000
            case .never: return nil
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") { dismiss() }

                Spacer()

                Text("Share GenTab")
                    .font(.headline)

                Spacer()

                Button("Done") { dismiss() }
                    .disabled(shareURL == nil)
            }
            .padding()

            Divider()

            VStack(spacing: 20) {
                // GenTab preview
                HStack {
                    Image(systemName: genTab.icon)
                        .font(.title2)
                        .foregroundColor(.accentColor)
                        .frame(width: 44, height: 44)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(10)

                    VStack(alignment: .leading) {
                        Text(genTab.title)
                            .font(.headline)
                        Text("\(genTab.components.count) components")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)

                // Expiration
                Picker("Link expires", selection: $expirationOption) {
                    ForEach(ExpirationOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)

                // Deploy button or share URL
                if let url = shareURL {
                    VStack(spacing: 12) {
                        HStack {
                            Text(url.absoluteString)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.accentColor)
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Button(action: copyToClipboard) {
                                Image(systemName: showCopiedConfirmation ? "checkmark" : "doc.on.doc")
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding()
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(8)

                        HStack(spacing: 12) {
                            Button(action: exportHTML) {
                                Label("Export HTML", systemImage: "arrow.down.doc")
                            }
                            .buttonStyle(.bordered)

                            Button(action: shareViaSystem) {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                } else {
                    Button(action: deployGenTab) {
                        if isDeploying {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label("Create Share Link", systemImage: "link.badge.plus")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isDeploying)
                }

                if let error = deploymentManager.deploymentError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            .padding()

            Spacer()
        }
        .frame(width: 400, height: 350)
    }

    func deployGenTab() {
        isDeploying = true

        Task {
            do {
                let deployed = try await deploymentManager.deployToCloud(
                    genTab,
                    expiresIn: expirationOption.timeInterval
                )

                await MainActor.run {
                    shareURL = deployed.shareURL
                    isDeploying = false
                }
            } catch {
                await MainActor.run {
                    deploymentManager.deploymentError = error.localizedDescription
                    isDeploying = false
                }
            }
        }
    }

    func copyToClipboard() {
        guard let url = shareURL else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.absoluteString, forType: .string)

        showCopiedConfirmation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCopiedConfirmation = false
        }
    }

    func exportHTML() {
        guard let fileURL = deploymentManager.exportAsHTML(genTab) else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.html]
        panel.nameFieldStringValue = "\(genTab.title).html"

        panel.begin { response in
            if response == .OK, let destinationURL = panel.url {
                try? FileManager.default.copyItem(at: fileURL, to: destinationURL)
            }
        }
    }

    func shareViaSystem() {
        guard let url = shareURL else { return }

        let picker = NSSharingServicePicker(items: [url])
        if let window = NSApp.keyWindow {
            picker.show(relativeTo: .zero, of: window.contentView!, preferredEdge: .minY)
        }
    }
}
