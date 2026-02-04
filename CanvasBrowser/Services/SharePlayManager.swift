import Foundation
import GroupActivities
import Combine
import os.log

/// Manages SharePlay browsing sessions during FaceTime calls
@MainActor
class SharePlayManager: ObservableObject {
    static let shared = SharePlayManager()

    // MARK: - Published Properties

    @Published var isSharePlayAvailable = false
    @Published var isSessionActive = false
    @Published var participants: [Participant] = []
    @Published var currentSharedURL: URL?
    @Published var syncEnabled = true

    // MARK: - Group Session

    private var groupSession: GroupSession<BrowsingActivity>?
    private var messenger: GroupSessionMessenger?
    private var subscriptions = Set<AnyCancellable>()
    private var tasks = Set<Task<Void, Never>>()

    private let logger = Logger(subsystem: "com.canvas.browser", category: "SharePlay")

    // MARK: - Initialization

    private init() {
        checkSharePlayAvailability()
        observeGroupSessions()
    }

    // MARK: - Availability

    private func checkSharePlayAvailability() {
        // SharePlay is available on macOS 12+ when FaceTime is active
        isSharePlayAvailable = true
    }

    // MARK: - Session Observation

    private func observeGroupSessions() {
        let task = Task {
            for await session in BrowsingActivity.sessions() {
                await configureGroupSession(session)
            }
        }
        tasks.insert(task)
    }

    private func configureGroupSession(_ session: GroupSession<BrowsingActivity>) async {
        groupSession = session
        messenger = GroupSessionMessenger(session: session)

        // Observe session state
        session.$state
            .sink { [weak self] state in
                Task { @MainActor in
                    switch state {
                    case .joined:
                        self?.isSessionActive = true
                        self?.logger.info("Joined SharePlay session")
                    case .waiting:
                        self?.isSessionActive = false
                    case .invalidated:
                        self?.isSessionActive = false
                        self?.groupSession = nil
                        self?.messenger = nil
                        self?.logger.info("SharePlay session invalidated")
                    @unknown default:
                        break
                    }
                }
            }
            .store(in: &subscriptions)

        // Observe participants
        session.$activeParticipants
            .sink { [weak self] participants in
                Task { @MainActor in
                    self?.participants = participants.map { Participant(id: $0.id, isLocal: $0 == session.localParticipant) }
                    self?.logger.info("Participants updated: \(participants.count)")
                }
            }
            .store(in: &subscriptions)

        // Listen for messages
        if let messenger = messenger {
            let task = Task {
                for await (message, _) in messenger.messages(of: BrowsingMessage.self) {
                    await handleMessage(message)
                }
            }
            tasks.insert(task)
        }

        // Join the session
        session.join()

        // Set initial URL from activity
        currentSharedURL = session.activity.url
    }

    // MARK: - Message Handling

    private func handleMessage(_ message: BrowsingMessage) async {
        guard syncEnabled else { return }

        switch message.type {
        case .navigate:
            if let url = message.url {
                currentSharedURL = url
                NotificationCenter.default.post(
                    name: .sharePlayNavigate,
                    object: nil,
                    userInfo: ["url": url]
                )
                logger.info("Received navigation to: \(url.absoluteString)")
            }

        case .scroll:
            if let position = message.scrollPosition {
                NotificationCenter.default.post(
                    name: .sharePlayScroll,
                    object: nil,
                    userInfo: ["position": position]
                )
            }

        case .highlight:
            if let selection = message.selection {
                NotificationCenter.default.post(
                    name: .sharePlayHighlight,
                    object: nil,
                    userInfo: ["selection": selection]
                )
            }

        case .cursor:
            if let position = message.cursorPosition {
                NotificationCenter.default.post(
                    name: .sharePlayCursor,
                    object: nil,
                    userInfo: ["position": position, "participantId": message.participantId ?? ""]
                )
            }
        }
    }

    // MARK: - Start Session

    /// Start a new SharePlay browsing session
    func startSession(with url: URL) async throws {
        let activity = BrowsingActivity(url: url)

        switch await activity.prepareForActivation() {
        case .activationPreferred:
            _ = try await activity.activate()
            logger.info("SharePlay session started with URL: \(url.absoluteString)")

        case .activationDisabled:
            throw SharePlayError.activationDisabled

        case .cancelled:
            throw SharePlayError.cancelled

        @unknown default:
            throw SharePlayError.unknown
        }
    }

    /// Start session with current page
    func startSessionWithCurrentPage() async throws {
        guard let url = currentSharedURL else {
            throw SharePlayError.noURL
        }
        try await startSession(with: url)
    }

    // MARK: - End Session

    func endSession() {
        groupSession?.end()
        groupSession = nil
        messenger = nil
        isSessionActive = false
        participants = []
        currentSharedURL = nil
        logger.info("SharePlay session ended")
    }

    func leaveSession() {
        groupSession?.leave()
        isSessionActive = false
        participants = []
        logger.info("Left SharePlay session")
    }

    // MARK: - Send Updates

    /// Share navigation to a new URL
    func shareNavigation(to url: URL) async {
        guard isSessionActive, syncEnabled, let messenger = messenger else { return }

        let message = BrowsingMessage(type: .navigate, url: url)

        do {
            try await messenger.send(message)
            currentSharedURL = url
            logger.debug("Shared navigation to: \(url.absoluteString)")
        } catch {
            logger.error("Failed to share navigation: \(error.localizedDescription)")
        }
    }

    /// Share scroll position
    func shareScrollPosition(_ position: CGPoint) async {
        guard isSessionActive, syncEnabled, let messenger = messenger else { return }

        let message = BrowsingMessage(type: .scroll, scrollPosition: position)

        do {
            try await messenger.send(message)
        } catch {
            logger.error("Failed to share scroll: \(error.localizedDescription)")
        }
    }

    /// Share text selection/highlight
    func shareSelection(_ selection: String, range: NSRange?) async {
        guard isSessionActive, syncEnabled, let messenger = messenger else { return }

        let message = BrowsingMessage(type: .highlight, selection: selection)

        do {
            try await messenger.send(message)
            logger.debug("Shared selection: \(selection.prefix(50))...")
        } catch {
            logger.error("Failed to share selection: \(error.localizedDescription)")
        }
    }

    /// Share cursor position
    func shareCursorPosition(_ position: CGPoint) async {
        guard isSessionActive, syncEnabled, let messenger = messenger else { return }

        let message = BrowsingMessage(
            type: .cursor,
            cursorPosition: position,
            participantId: groupSession?.localParticipant.id.uuidString
        )

        do {
            try await messenger.send(message)
        } catch {
            // Cursor updates are frequent, don't log errors
        }
    }

    // MARK: - Sync Control

    func toggleSync() {
        syncEnabled.toggle()
        logger.info("Sync \(self.syncEnabled ? "enabled" : "disabled")")
    }

    // MARK: - Cleanup

    func cleanup() {
        for task in tasks {
            task.cancel()
        }
        tasks.removeAll()
        subscriptions.removeAll()
        endSession()
    }

    deinit {
        for task in tasks {
            task.cancel()
        }
    }
}

// MARK: - Browsing Activity

struct BrowsingActivity: GroupActivity {
    static let activityIdentifier = "com.canvas.browser.shareplay.browsing"

    let url: URL
    let title: String

    init(url: URL, title: String = "Canvas Browser") {
        self.url = url
        self.title = title
    }

    var metadata: GroupActivityMetadata {
        var metadata = GroupActivityMetadata()
        metadata.type = .generic
        metadata.title = title
        metadata.subtitle = url.host ?? url.absoluteString
        metadata.previewImage = nil // Could add a preview image
        metadata.fallbackURL = url
        return metadata
    }
}

// MARK: - Browsing Message

struct BrowsingMessage: Codable {
    enum MessageType: String, Codable {
        case navigate
        case scroll
        case highlight
        case cursor
    }

    let type: MessageType
    var url: URL?
    var scrollPosition: CGPoint?
    var selection: String?
    var cursorPosition: CGPoint?
    var participantId: String?

    init(type: MessageType, url: URL? = nil, scrollPosition: CGPoint? = nil, selection: String? = nil, cursorPosition: CGPoint? = nil, participantId: String? = nil) {
        self.type = type
        self.url = url
        self.scrollPosition = scrollPosition
        self.selection = selection
        self.cursorPosition = cursorPosition
        self.participantId = participantId
    }
}

// MARK: - Participant

struct Participant: Identifiable {
    let id: UUID
    let isLocal: Bool
}

// MARK: - Errors

enum SharePlayError: LocalizedError {
    case activationDisabled
    case cancelled
    case noURL
    case notInCall
    case unknown

    var errorDescription: String? {
        switch self {
        case .activationDisabled:
            return "SharePlay is disabled for this app"
        case .cancelled:
            return "SharePlay activation was cancelled"
        case .noURL:
            return "No URL to share"
        case .notInCall:
            return "You must be in a FaceTime call to use SharePlay"
        case .unknown:
            return "An unknown error occurred"
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let sharePlayNavigate = Notification.Name("com.canvas.browser.sharePlay.navigate")
    static let sharePlayScroll = Notification.Name("com.canvas.browser.sharePlay.scroll")
    static let sharePlayHighlight = Notification.Name("com.canvas.browser.sharePlay.highlight")
    static let sharePlayCursor = Notification.Name("com.canvas.browser.sharePlay.cursor")
}
