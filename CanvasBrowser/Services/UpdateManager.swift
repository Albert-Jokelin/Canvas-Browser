import Foundation
import SwiftUI

/// Manages over-the-air updates for Canvas Browser
/// In production, this would integrate with Sparkle framework
class UpdateManager: ObservableObject {
    static let shared = UpdateManager()

    @Published var isCheckingForUpdates = false
    @Published var updateAvailable = false
    @Published var latestVersion: String?
    @Published var currentVersion: String
    @Published var releaseNotes: String?
    @Published var downloadProgress: Double = 0
    @Published var isDownloading = false
    @Published var lastCheckDate: Date?
    @Published var error: String?
    @Published var downloadURL: URL?

    @AppStorage("autoCheckForUpdates") var autoCheckEnabled = true
    @AppStorage("autoDownloadUpdates") var autoDownloadEnabled = true
    @AppStorage("lastUpdateCheck") private var lastUpdateCheckTimestamp: Double = 0

    // GitHub releases API endpoint
    private let releasesURL = URL(string: "https://api.github.com/repos/Albert-Jokelin/Canvas-Browser/releases/latest")!
    private let releasesPageURL = URL(string: "https://github.com/Albert-Jokelin/Canvas-Browser/releases")!

    private init() {
        // Get current version from bundle
        currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"

        // Load last check date
        if lastUpdateCheckTimestamp > 0 {
            lastCheckDate = Date(timeIntervalSince1970: lastUpdateCheckTimestamp)
        }

        // Schedule automatic update checks if enabled
        if autoCheckEnabled {
            scheduleAutomaticCheck()
        }
    }

    // MARK: - Update Check

    func checkForUpdates() async {
        guard !isCheckingForUpdates else { return }

        await MainActor.run {
            isCheckingForUpdates = true
            error = nil
        }

        defer {
            Task { @MainActor in
                isCheckingForUpdates = false
                lastCheckDate = Date()
                lastUpdateCheckTimestamp = Date().timeIntervalSince1970
            }
        }

        // Fetch latest release from GitHub API
        do {
            var request = URLRequest(url: releasesURL)
            request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
            request.setValue("Canvas-Browser", forHTTPHeaderField: "User-Agent")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw UpdateError.invalidResponse
            }

            if httpResponse.statusCode == 404 {
                // No releases yet
                await MainActor.run {
                    updateAvailable = false
                    latestVersion = currentVersion
                }
                return
            }

            guard httpResponse.statusCode == 200 else {
                throw UpdateError.httpError(httpResponse.statusCode)
            }

            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)

            // Extract version from tag (remove 'v' prefix if present)
            let latestVersionString = release.tagName.hasPrefix("v")
                ? String(release.tagName.dropFirst())
                : release.tagName

            let hasUpdate = compareVersions(current: currentVersion, latest: latestVersionString)

            await MainActor.run {
                if hasUpdate {
                    updateAvailable = true
                    latestVersion = latestVersionString
                    releaseNotes = release.body
                    downloadURL = release.assets.first { $0.name.hasSuffix(".dmg") || $0.name.hasSuffix(".zip") }?.browserDownloadURL
                } else {
                    updateAvailable = false
                    latestVersion = currentVersion
                }
            }

            // Auto-download if enabled and update available
            if hasUpdate && autoDownloadEnabled && downloadURL != nil {
                await downloadUpdate()
            }
        } catch {
            await MainActor.run {
                self.error = "Failed to check for updates: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Download & Install

    func downloadUpdate() async {
        guard updateAvailable, !isDownloading, let url = downloadURL else { return }

        await MainActor.run {
            isDownloading = true
            downloadProgress = 0
        }

        do {
            // Download to temporary location
            let (tempURL, response) = try await URLSession.shared.download(from: url, delegate: nil)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw UpdateError.downloadFailed
            }

            // Move to Downloads folder
            let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
            let fileName = url.lastPathComponent
            let destinationURL = downloadsURL.appendingPathComponent(fileName)

            // Remove existing file if present
            try? FileManager.default.removeItem(at: destinationURL)
            try FileManager.default.moveItem(at: tempURL, to: destinationURL)

            await MainActor.run {
                isDownloading = false
                downloadProgress = 1.0
                downloadedFileURL = destinationURL
            }
        } catch {
            await MainActor.run {
                isDownloading = false
                self.error = "Download failed: \(error.localizedDescription)"
            }
        }
    }

    @Published var downloadedFileURL: URL?

    func installUpdate() {
        // Open the downloaded file or the releases page
        if let fileURL = downloadedFileURL {
            NSWorkspace.shared.open(fileURL)
        } else {
            // Open GitHub releases page
            NSWorkspace.shared.open(releasesPageURL)
        }
    }

    func openReleasesPage() {
        NSWorkspace.shared.open(releasesPageURL)
    }

    // MARK: - Helpers

    private func compareVersions(current: String, latest: String) -> Bool {
        let currentParts = current.split(separator: ".").compactMap { Int($0) }
        let latestParts = latest.split(separator: ".").compactMap { Int($0) }

        for i in 0..<max(currentParts.count, latestParts.count) {
            let currentPart = i < currentParts.count ? currentParts[i] : 0
            let latestPart = i < latestParts.count ? latestParts[i] : 0

            if latestPart > currentPart {
                return true
            } else if latestPart < currentPart {
                return false
            }
        }

        return false
    }

    private func scheduleAutomaticCheck() {
        // Check once per day
        let checkInterval: TimeInterval = 86400

        if let lastCheck = lastCheckDate, Date().timeIntervalSince(lastCheck) < checkInterval {
            return
        }

        Task {
            await checkForUpdates()
        }
    }
}

// MARK: - Update Settings View

struct UpdateSettingsView: View {
    @StateObject private var updateManager = UpdateManager.shared
    @AppStorage("autoCheckForUpdates") private var autoCheckEnabled = true
    @AppStorage("autoDownloadUpdates") private var autoDownloadEnabled = true

    var body: some View {
        Form {
            Section("Current Version") {
                HStack {
                    Text("Canvas Browser")
                    Spacer()
                    Text("v\(updateManager.currentVersion)")
                        .foregroundColor(.secondary)
                }
            }

            Section("Automatic Updates") {
                Toggle("Check for updates automatically", isOn: $autoCheckEnabled)

                if autoCheckEnabled {
                    Toggle("Download updates in background", isOn: $autoDownloadEnabled)
                }
            }

            Section("Manual Update") {
                HStack {
                    if updateManager.isCheckingForUpdates {
                        ProgressView()
                            .controlSize(.small)
                        Text("Checking for updates...")
                            .foregroundColor(.secondary)
                    } else if updateManager.updateAvailable {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "arrow.down.circle.fill")
                                    .foregroundColor(.green)
                                Text("Update Available: v\(updateManager.latestVersion ?? "")")
                                    .font(.headline)
                            }

                            if updateManager.isDownloading {
                                ProgressView(value: updateManager.downloadProgress)
                                    .progressViewStyle(.linear)
                            } else if updateManager.downloadProgress >= 1.0 {
                                Button("Install & Restart") {
                                    updateManager.installUpdate()
                                }
                                .buttonStyle(.borderedProminent)
                            } else {
                                Button("Download Update") {
                                    Task {
                                        await updateManager.downloadUpdate()
                                    }
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    } else {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Canvas Browser is up to date")
                        }
                    }

                    Spacer()

                    if !updateManager.isCheckingForUpdates && !updateManager.updateAvailable {
                        Button("Check Now") {
                            Task {
                                await updateManager.checkForUpdates()
                            }
                        }
                    }
                }

                if let lastCheck = updateManager.lastCheckDate {
                    Text("Last checked: \(lastCheck, style: .relative) ago")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let error = updateManager.error {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            if updateManager.updateAvailable, let notes = updateManager.releaseNotes {
                Section("Release Notes") {
                    ScrollView {
                        Text(try! AttributedString(markdown: notes))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 150)
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Update Available Banner

struct UpdateAvailableBanner: View {
    @StateObject private var updateManager = UpdateManager.shared
    @State private var isDismissed = false

    var body: some View {
        if updateManager.updateAvailable && !isDismissed {
            HStack(spacing: 12) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Update Available")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Canvas Browser v\(updateManager.latestVersion ?? "") is ready")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }

                Spacer()

                if updateManager.downloadProgress >= 1.0 {
                    Button("Install") {
                        updateManager.installUpdate()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.white)
                    .foregroundColor(.blue)
                } else if updateManager.isDownloading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    Button("Download") {
                        Task {
                            await updateManager.downloadUpdate()
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                }

                Button(action: { isDismissed = true }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .shadow(radius: 4)
        }
    }
}

// MARK: - GitHub Release Model

struct GitHubRelease: Codable {
    let tagName: String
    let name: String?
    let body: String?
    let assets: [GitHubAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case assets
    }
}

struct GitHubAsset: Codable {
    let name: String
    let browserDownloadURL: URL

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
    }
}

// MARK: - Update Errors

enum UpdateError: LocalizedError {
    case invalidResponse
    case httpError(Int)
    case downloadFailed

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid response from server"
        case .httpError(let code): return "HTTP error: \(code)"
        case .downloadFailed: return "Failed to download update"
        }
    }
}
