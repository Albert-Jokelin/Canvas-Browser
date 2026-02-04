import Foundation
import CloudKit
import Combine
import os.log

/// Orchestrates synchronization between local storage and CloudKit
@MainActor
class SyncCoordinator: ObservableObject {
    static let shared = SyncCoordinator()

    // MARK: - Published Properties

    @Published var isSyncing = false
    @Published var lastSyncTime: Date?
    @Published var pendingChanges = 0

    // MARK: - Dependencies

    private let cloudKitManager = CloudKitManager.shared
    private let conflictResolver = ConflictResolver.shared
    private let logger = Logger(subsystem: "com.canvas.browser", category: "SyncCoordinator")

    // MARK: - Sync Configuration

    private var syncTimer: Timer?
    private let autoSyncInterval: TimeInterval = 30 // 30 seconds
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Sync State

    private var localChangesSinceLastSync: [SyncableItem] = []

    // MARK: - Initialization

    private init() {
        setupObservers()
        startAutoSync()
    }

    // MARK: - Setup

    private func setupObservers() {
        // Observe CloudKit availability changes
        cloudKitManager.$iCloudAvailable
            .sink { [weak self] available in
                if available {
                    Task {
                        await self?.performFullSync()
                    }
                }
            }
            .store(in: &cancellables)

        // Observe bookmark changes
        BookmarkManager.shared.$bookmarks
            .dropFirst()
            .debounce(for: .seconds(2), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.markBookmarksChanged()
            }
            .store(in: &cancellables)

        // Observe reading list changes
        ReadingListManager.shared.$items
            .dropFirst()
            .debounce(for: .seconds(2), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.markReadingListChanged()
            }
            .store(in: &cancellables)
    }

    private func startAutoSync() {
        syncTimer = Timer.scheduledTimer(withTimeInterval: autoSyncInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.syncIfNeeded()
            }
        }
    }

    // MARK: - Change Tracking

    private func markBookmarksChanged() {
        pendingChanges += 1
        logger.debug("Bookmarks changed, pending sync")
    }

    private func markReadingListChanged() {
        pendingChanges += 1
        logger.debug("Reading list changed, pending sync")
    }

    func markGenTabsChanged() {
        pendingChanges += 1
        logger.debug("GenTabs changed, pending sync")
    }

    func markTabGroupsChanged() {
        pendingChanges += 1
        logger.debug("Tab groups changed, pending sync")
    }

    // MARK: - Sync Operations

    /// Perform sync if there are pending changes
    func syncIfNeeded() async {
        guard pendingChanges > 0 else { return }
        await performFullSync()
    }

    /// Force a full sync regardless of pending changes
    func performFullSync() async {
        guard cloudKitManager.iCloudAvailable else {
            logger.warning("Sync skipped: iCloud not available")
            return
        }

        guard !isSyncing else {
            logger.debug("Sync already in progress")
            return
        }

        isSyncing = true
        defer {
            isSyncing = false
            pendingChanges = 0
        }

        logger.info("Starting full sync")

        do {
            // 1. Fetch remote changes first
            let changes = try await cloudKitManager.fetchChanges()

            if !changes.isEmpty {
                // 2. Apply remote changes to local data
                await applyRemoteChanges(changes)
            }

            // 3. Push local changes to CloudKit
            await pushLocalChanges()

            lastSyncTime = Date()
            logger.info("Sync completed successfully")

        } catch {
            logger.error("Sync failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Apply Remote Changes

    private func applyRemoteChanges(_ changes: CloudKitManager.ChangeBatch) async {
        // Process changed records
        for record in changes.changedRecords {
            await processChangedRecord(record)
        }

        // Process deleted records
        for recordID in changes.deletedRecordIDs {
            await processDeletedRecord(recordID)
        }
    }

    private func processChangedRecord(_ record: CKRecord) async {
        let recordType = record.recordType

        switch recordType {
        case CloudKitManager.RecordType.bookmark.rawValue:
            await processBookmarkChange(record)

        case CloudKitManager.RecordType.bookmarkFolder.rawValue:
            await processBookmarkFolderChange(record)

        case CloudKitManager.RecordType.readingListItem.rawValue:
            await processReadingListChange(record)

        case CloudKitManager.RecordType.genTab.rawValue:
            await processGenTabChange(record)

        case CloudKitManager.RecordType.tabGroup.rawValue:
            await processTabGroupChange(record)

        default:
            logger.warning("Unknown record type: \(recordType)")
        }
    }

    private func processBookmarkChange(_ record: CKRecord) async {
        guard let remoteBookmark = cloudKitManager.recordToBookmark(record) else {
            logger.error("Failed to parse bookmark from record")
            return
        }

        let bookmarkManager = BookmarkManager.shared

        if let existingIndex = bookmarkManager.bookmarks.firstIndex(where: { $0.id == remoteBookmark.id }) {
            let localBookmark = bookmarkManager.bookmarks[existingIndex]

            // Check for conflicts
            if let resolvedBookmark = conflictResolver.resolveBookmarkConflict(local: localBookmark, remote: remoteBookmark) {
                bookmarkManager.bookmarks[existingIndex] = resolvedBookmark
            }
        } else {
            // New bookmark from remote
            bookmarkManager.bookmarks.insert(remoteBookmark, at: 0)
        }
    }

    private func processBookmarkFolderChange(_ record: CKRecord) async {
        guard let remoteFolder = cloudKitManager.recordToFolder(record) else {
            logger.error("Failed to parse bookmark folder from record")
            return
        }

        let bookmarkManager = BookmarkManager.shared

        if let existingIndex = bookmarkManager.folders.firstIndex(where: { $0.id == remoteFolder.id }) {
            let localFolder = bookmarkManager.folders[existingIndex]

            if let resolvedFolder = conflictResolver.resolveBookmarkFolderConflict(local: localFolder, remote: remoteFolder) {
                bookmarkManager.folders[existingIndex] = resolvedFolder
            }
        } else {
            bookmarkManager.folders.append(remoteFolder)
        }
    }

    private func processReadingListChange(_ record: CKRecord) async {
        guard let remoteItem = cloudKitManager.recordToReadingListItem(record) else {
            logger.error("Failed to parse reading list item from record")
            return
        }

        let readingListManager = ReadingListManager.shared

        if let existingIndex = readingListManager.items.firstIndex(where: { $0.id == remoteItem.id }) {
            let localItem = readingListManager.items[existingIndex]

            if let resolvedItem = conflictResolver.resolveReadingListConflict(local: localItem, remote: remoteItem) {
                readingListManager.items[existingIndex] = resolvedItem
            }
        } else {
            readingListManager.items.insert(remoteItem, at: 0)
        }
    }

    private func processGenTabChange(_ record: CKRecord) async {
        // GenTabs are handled through AppState's recent GenTabs
        guard let remoteGenTab = cloudKitManager.recordToGenTab(record) else {
            logger.error("Failed to parse GenTab from record")
            return
        }

        // Store in UserDefaults for persistence
        var savedGenTabs = loadSavedGenTabs()
        if let existingIndex = savedGenTabs.firstIndex(where: { $0.id == remoteGenTab.id }) {
            savedGenTabs[existingIndex] = remoteGenTab
        } else {
            savedGenTabs.insert(remoteGenTab, at: 0)
        }
        saveGenTabs(savedGenTabs)
    }

    private func processTabGroupChange(_ record: CKRecord) async {
        guard let remoteGroup = cloudKitManager.recordToTabGroup(record) else {
            logger.error("Failed to parse TabGroup from record")
            return
        }

        // TabGroups are managed by TabGroupManager
        // This would need to be connected to AppState's tabGroupManager
        logger.info("Received tab group update: \(remoteGroup.name)")
    }

    private func processDeletedRecord(_ recordID: CKRecord.ID) async {
        let recordName = recordID.recordName

        if recordName.hasPrefix("Bookmark-") {
            let idString = recordName.replacingOccurrences(of: "Bookmark-", with: "")
            if let id = UUID(uuidString: idString) {
                BookmarkManager.shared.bookmarks.removeAll { $0.id == id }
            }
        } else if recordName.hasPrefix("BookmarkFolder-") {
            let idString = recordName.replacingOccurrences(of: "BookmarkFolder-", with: "")
            if let id = UUID(uuidString: idString) {
                BookmarkManager.shared.folders.removeAll { $0.id == id }
            }
        } else if recordName.hasPrefix("ReadingListItem-") {
            let idString = recordName.replacingOccurrences(of: "ReadingListItem-", with: "")
            if let id = UUID(uuidString: idString) {
                ReadingListManager.shared.items.removeAll { $0.id == id }
            }
        } else if recordName.hasPrefix("GenTab-") {
            let idString = recordName.replacingOccurrences(of: "GenTab-", with: "")
            if let id = UUID(uuidString: idString) {
                var savedGenTabs = loadSavedGenTabs()
                savedGenTabs.removeAll { $0.id == id }
                saveGenTabs(savedGenTabs)
            }
        }
    }

    // MARK: - Push Local Changes

    private func pushLocalChanges() async {
        await pushBookmarks()
        await pushBookmarkFolders()
        await pushReadingList()
        await pushGenTabs()
    }

    private func pushBookmarks() async {
        let bookmarks = BookmarkManager.shared.bookmarks
        let records = bookmarks.map { cloudKitManager.bookmarkToRecord($0) }

        guard !records.isEmpty else { return }

        do {
            _ = try await cloudKitManager.saveRecords(records)
            logger.info("Pushed \(records.count) bookmarks to CloudKit")
        } catch {
            logger.error("Failed to push bookmarks: \(error.localizedDescription)")
        }
    }

    private func pushBookmarkFolders() async {
        let folders = BookmarkManager.shared.folders
        let records = folders.map { cloudKitManager.folderToRecord($0) }

        guard !records.isEmpty else { return }

        do {
            _ = try await cloudKitManager.saveRecords(records)
            logger.info("Pushed \(records.count) bookmark folders to CloudKit")
        } catch {
            logger.error("Failed to push bookmark folders: \(error.localizedDescription)")
        }
    }

    private func pushReadingList() async {
        let items = ReadingListManager.shared.items
        let records = items.map { cloudKitManager.readingListItemToRecord($0) }

        guard !records.isEmpty else { return }

        do {
            _ = try await cloudKitManager.saveRecords(records)
            logger.info("Pushed \(records.count) reading list items to CloudKit")
        } catch {
            logger.error("Failed to push reading list: \(error.localizedDescription)")
        }
    }

    private func pushGenTabs() async {
        let genTabs = loadSavedGenTabs()
        let records = genTabs.map { cloudKitManager.genTabToRecord($0) }

        guard !records.isEmpty else { return }

        do {
            _ = try await cloudKitManager.saveRecords(records)
            logger.info("Pushed \(records.count) GenTabs to CloudKit")
        } catch {
            logger.error("Failed to push GenTabs: \(error.localizedDescription)")
        }
    }

    // MARK: - GenTab Persistence Helpers

    private let genTabsKey = "canvas_synced_gentabs"

    private func loadSavedGenTabs() -> [GenTab] {
        guard let data = UserDefaults.standard.data(forKey: genTabsKey) else { return [] }
        return (try? JSONDecoder().decode([GenTab].self, from: data)) ?? []
    }

    private func saveGenTabs(_ genTabs: [GenTab]) {
        if let data = try? JSONEncoder().encode(genTabs) {
            UserDefaults.standard.set(data, forKey: genTabsKey)
        }
    }

    // MARK: - Manual Sync Actions

    /// Sync a specific bookmark immediately
    func syncBookmark(_ bookmark: Bookmark) async {
        let record = cloudKitManager.bookmarkToRecord(bookmark)
        do {
            _ = try await cloudKitManager.save(record)
            logger.info("Synced bookmark: \(bookmark.title)")
        } catch {
            logger.error("Failed to sync bookmark: \(error.localizedDescription)")
        }
    }

    /// Delete a bookmark from CloudKit
    func deleteBookmarkFromCloud(_ bookmark: Bookmark) async {
        let recordID = cloudKitManager.recordID(for: .bookmark, uuid: bookmark.id)
        do {
            try await cloudKitManager.delete(recordID: recordID)
            logger.info("Deleted bookmark from cloud: \(bookmark.title)")
        } catch {
            logger.error("Failed to delete bookmark from cloud: \(error.localizedDescription)")
        }
    }

    /// Sync a GenTab immediately
    func syncGenTab(_ genTab: GenTab) async {
        // Save locally first
        var savedGenTabs = loadSavedGenTabs()
        if let existingIndex = savedGenTabs.firstIndex(where: { $0.id == genTab.id }) {
            savedGenTabs[existingIndex] = genTab
        } else {
            savedGenTabs.insert(genTab, at: 0)
        }
        saveGenTabs(savedGenTabs)

        // Push to CloudKit
        let record = cloudKitManager.genTabToRecord(genTab)
        do {
            _ = try await cloudKitManager.save(record)
            logger.info("Synced GenTab: \(genTab.title)")
        } catch {
            logger.error("Failed to sync GenTab: \(error.localizedDescription)")
        }
    }

    // MARK: - Sync Trigger for External Use

    func triggerSync() {
        Task {
            await performFullSync()
        }
    }

    // MARK: - Cleanup

    func stopAutoSync() {
        syncTimer?.invalidate()
        syncTimer = nil
    }

    deinit {
        syncTimer?.invalidate()
    }
}

// MARK: - Syncable Item Protocol

protocol SyncableItem {
    var id: UUID { get }
    var modifiedAt: Date { get }
}

// MARK: - Sync Notification Names

extension Notification.Name {
    static let cloudSyncCompleted = Notification.Name("com.canvas.browser.cloudSyncCompleted")
    static let cloudSyncFailed = Notification.Name("com.canvas.browser.cloudSyncFailed")
    static let cloudSyncStarted = Notification.Name("com.canvas.browser.cloudSyncStarted")
}
