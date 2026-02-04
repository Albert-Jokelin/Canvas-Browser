import Foundation
import CloudKit
import Security
import Combine
import os.log

/// Manages CloudKit database operations for syncing data across devices
@MainActor
class CloudKitManager: ObservableObject {
    static let shared = CloudKitManager()

    // MARK: - Published Properties

    @Published var iCloudAvailable = false
    @Published var isConfigured = false
    @Published var syncStatus: SyncStatus = .idle
    @Published var lastSyncDate: Date?
    @Published var syncError: Error?

    // MARK: - CloudKit Configuration

    private let containerIdentifier = "iCloud.com.canvas.browser"
    private var _container: CKContainer?
    private var _privateDatabase: CKDatabase?
    private var _sharedDatabase: CKDatabase?

    private var container: CKContainer? {
        if _container == nil {
            _container = createContainer()
        }
        return _container
    }

    private var privateDatabase: CKDatabase? {
        return container?.privateCloudDatabase
    }

    private var sharedDatabase: CKDatabase? {
        return container?.sharedCloudDatabase
    }

    /// Safely create CloudKit container - returns nil if not properly configured
    private func createContainer() -> CKContainer? {
        // If the app isn't provisioned with iCloud container entitlements,
        // even CKContainer(identifier:) can crash with a CKException.
        guard hasICloudEntitlement else {
            logger.warning("Missing iCloud container entitlement; CloudKit disabled.")
            return nil
        }
        return CKContainer(identifier: containerIdentifier)
    }

    private var hasICloudEntitlement: Bool {
        guard let task = SecTaskCreateFromSelf(nil) else { return false }
        let entitlement = "com.apple.developer.icloud-container-identifiers" as CFString
        let value = SecTaskCopyValueForEntitlement(task, entitlement, nil)
        if let containers = value as? [String] {
            return !containers.isEmpty
        }
        if let container = value as? String {
            return !container.isEmpty
        }
        return false
    }

    // MARK: - Record Types

    enum RecordType: String {
        case bookmark = "Bookmark"
        case bookmarkFolder = "BookmarkFolder"
        case readingListItem = "ReadingListItem"
        case genTab = "GenTab"
        case tabGroup = "TabGroup"
        case userSettings = "UserSettings"
    }

    // MARK: - Sync Status

    enum SyncStatus: Equatable {
        case idle
        case syncing
        case success
        case error(String)
        case notConfigured

        var description: String {
            switch self {
            case .idle: return "Ready"
            case .syncing: return "Syncing..."
            case .success: return "Up to date"
            case .error(let message): return "Error: \(message)"
            case .notConfigured: return "iCloud not configured"
            }
        }
    }

    // MARK: - Zone Configuration

    private let zoneID = CKRecordZone.ID(zoneName: "CanvasBrowserZone", ownerName: CKCurrentUserDefaultName)
    private var zone: CKRecordZone?

    private let logger = Logger(subsystem: "com.canvas.browser", category: "CloudKit")

    // MARK: - Subscriptions

    private var subscriptions: Set<AnyCancellable> = []

    // MARK: - Initialization

    private init() {
        // Don't auto-initialize CloudKit - wait for explicit check
        // This prevents crashes when CloudKit isn't properly configured
        logger.info("CloudKitManager initialized (CloudKit check deferred)")
    }

    /// Call this to initialize CloudKit - safe to call at any time
    func initializeIfNeeded() async {
        guard !isConfigured else { return }
        await checkiCloudAvailability()
        if iCloudAvailable {
            await setupZone()
            await setupSubscriptions()
        }
    }

    // MARK: - iCloud Availability

    func checkiCloudAvailability() async {
        // First check if we can even access FileManager's ubiquity identity token
        // This is a safer check that doesn't require CloudKit entitlements
        guard FileManager.default.ubiquityIdentityToken != nil else {
            iCloudAvailable = false
            isConfigured = true
            syncStatus = .notConfigured
            logger.info("iCloud not signed in or not available")
            return
        }

        // Try to access CloudKit - this may fail if entitlements aren't set up
        guard let container = container else {
            iCloudAvailable = false
            isConfigured = true
            syncStatus = .notConfigured
            logger.warning("CloudKit container could not be created")
            return
        }

        do {
            let status = try await container.accountStatus()
            isConfigured = true
            switch status {
            case .available:
                iCloudAvailable = true
                syncStatus = .idle
                logger.info("iCloud account available")
            case .noAccount:
                iCloudAvailable = false
                syncStatus = .notConfigured
                logger.warning("No iCloud account configured")
            case .restricted:
                iCloudAvailable = false
                syncStatus = .error("Restricted")
                logger.warning("iCloud account restricted")
            case .couldNotDetermine:
                iCloudAvailable = false
                syncStatus = .notConfigured
                logger.warning("Could not determine iCloud status")
            case .temporarilyUnavailable:
                iCloudAvailable = false
                syncStatus = .error("Temporarily unavailable")
                logger.warning("iCloud temporarily unavailable")
            @unknown default:
                iCloudAvailable = false
                syncStatus = .notConfigured
            }
        } catch {
            iCloudAvailable = false
            isConfigured = true
            syncStatus = .notConfigured
            logger.error("Failed to check iCloud status: \(error.localizedDescription)")
        }
    }

    // MARK: - Zone Setup

    private func setupZone() async {
        guard iCloudAvailable, let database = privateDatabase else { return }

        let zone = CKRecordZone(zoneID: zoneID)
        do {
            let savedZone = try await database.save(zone)
            self.zone = savedZone
            logger.info("CloudKit zone created/verified")
        } catch let error as CKError where error.code == .serverRecordChanged {
            // Zone already exists, which is fine
            self.zone = zone
            logger.info("CloudKit zone already exists")
        } catch {
            logger.error("Failed to create CloudKit zone: \(error.localizedDescription)")
        }
    }

    // MARK: - Subscriptions

    private func setupSubscriptions() async {
        guard iCloudAvailable, privateDatabase != nil else { return }

        // Subscribe to changes for each record type
        for recordType in [RecordType.bookmark, .bookmarkFolder, .readingListItem, .genTab, .tabGroup] {
            await createSubscription(for: recordType)
        }
    }

    private func createSubscription(for recordType: RecordType) async {
        guard let database = privateDatabase else { return }

        let subscriptionID = "subscription-\(recordType.rawValue)"
        let subscription = CKRecordZoneSubscription(zoneID: zoneID, subscriptionID: subscriptionID)

        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo

        do {
            _ = try await database.save(subscription)
            logger.info("Subscription created for \(recordType.rawValue)")
        } catch let error as CKError where error.code == .serverRecordChanged {
            // Subscription already exists
            logger.info("Subscription already exists for \(recordType.rawValue)")
        } catch {
            logger.error("Failed to create subscription for \(recordType.rawValue): \(error.localizedDescription)")
        }
    }

    // MARK: - CRUD Operations

    /// Save a record to CloudKit
    func save(_ record: CKRecord) async throws -> CKRecord {
        guard iCloudAvailable, let database = privateDatabase else {
            throw CloudKitError.notAvailable
        }

        syncStatus = .syncing

        do {
            let savedRecord = try await database.save(record)
            syncStatus = .success
            lastSyncDate = Date()
            logger.info("Record saved: \(record.recordID.recordName)")
            return savedRecord
        } catch {
            syncStatus = .error(error.localizedDescription)
            syncError = error
            logger.error("Failed to save record: \(error.localizedDescription)")
            throw error
        }
    }

    /// Save multiple records in a batch
    func saveRecords(_ records: [CKRecord]) async throws -> [CKRecord] {
        guard iCloudAvailable, let database = privateDatabase else {
            throw CloudKitError.notAvailable
        }

        guard !records.isEmpty else { return [] }

        syncStatus = .syncing

        let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
        operation.savePolicy = .changedKeys
        operation.qualityOfService = .userInitiated

        return try await withCheckedThrowingContinuation { continuation in
            var savedRecords: [CKRecord] = []

            operation.perRecordSaveBlock = { _, result in
                switch result {
                case .success(let record):
                    savedRecords.append(record)
                case .failure(let error):
                    self.logger.error("Failed to save record: \(error.localizedDescription)")
                }
            }

            operation.modifyRecordsResultBlock = { result in
                Task { @MainActor in
                    switch result {
                    case .success:
                        self.syncStatus = .success
                        self.lastSyncDate = Date()
                        continuation.resume(returning: savedRecords)
                    case .failure(let error):
                        self.syncStatus = .error(error.localizedDescription)
                        self.syncError = error
                        continuation.resume(throwing: error)
                    }
                }
            }

            database.add(operation)
        }
    }

    /// Fetch a single record by ID
    func fetch(recordID: CKRecord.ID) async throws -> CKRecord {
        guard iCloudAvailable, let database = privateDatabase else {
            throw CloudKitError.notAvailable
        }

        return try await database.record(for: recordID)
    }

    /// Fetch all records of a type
    func fetchAll(recordType: RecordType) async throws -> [CKRecord] {
        guard iCloudAvailable, let database = privateDatabase else {
            throw CloudKitError.notAvailable
        }

        let query = CKQuery(recordType: recordType.rawValue, predicate: NSPredicate(value: true))

        var allRecords: [CKRecord] = []
        var cursor: CKQueryOperation.Cursor?

        repeat {
            let (records, newCursor) = try await database.records(
                matching: query,
                inZoneWith: zoneID,
                desiredKeys: nil,
                resultsLimit: CKQueryOperation.maximumResults
            )

            for (_, result) in records {
                if case .success(let record) = result {
                    allRecords.append(record)
                }
            }

            cursor = newCursor
        } while cursor != nil

        logger.info("Fetched \(allRecords.count) \(recordType.rawValue) records")
        return allRecords
    }

    /// Delete a record
    func delete(recordID: CKRecord.ID) async throws {
        guard iCloudAvailable, let database = privateDatabase else {
            throw CloudKitError.notAvailable
        }

        syncStatus = .syncing

        do {
            try await database.deleteRecord(withID: recordID)
            syncStatus = .success
            lastSyncDate = Date()
            logger.info("Record deleted: \(recordID.recordName)")
        } catch {
            syncStatus = .error(error.localizedDescription)
            syncError = error
            throw error
        }
    }

    /// Delete multiple records
    func deleteRecords(_ recordIDs: [CKRecord.ID]) async throws {
        guard iCloudAvailable, let database = privateDatabase else {
            throw CloudKitError.notAvailable
        }

        guard !recordIDs.isEmpty else { return }

        syncStatus = .syncing

        let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIDs)
        operation.qualityOfService = .userInitiated

        return try await withCheckedThrowingContinuation { continuation in
            operation.modifyRecordsResultBlock = { result in
                Task { @MainActor in
                    switch result {
                    case .success:
                        self.syncStatus = .success
                        self.lastSyncDate = Date()
                        self.logger.info("Deleted \(recordIDs.count) records")
                        continuation.resume()
                    case .failure(let error):
                        self.syncStatus = .error(error.localizedDescription)
                        self.syncError = error
                        continuation.resume(throwing: error)
                    }
                }
            }

            database.add(operation)
        }
    }

    // MARK: - Record Conversion Helpers

    /// Create a CKRecord ID for a given type and UUID
    func recordID(for type: RecordType, uuid: UUID) -> CKRecord.ID {
        CKRecord.ID(recordName: "\(type.rawValue)-\(uuid.uuidString)", zoneID: zoneID)
    }

    /// Create a new CKRecord for a given type
    func createRecord(type: RecordType, uuid: UUID) -> CKRecord {
        CKRecord(recordType: type.rawValue, recordID: recordID(for: type, uuid: uuid))
    }

    // MARK: - Bookmark Sync

    func bookmarkToRecord(_ bookmark: Bookmark) -> CKRecord {
        let record = createRecord(type: .bookmark, uuid: bookmark.id)
        record["url"] = bookmark.url
        record["title"] = bookmark.title
        record["folderId"] = bookmark.folderId?.uuidString
        record["favicon"] = bookmark.favicon
        record["createdAt"] = bookmark.createdAt
        return record
    }

    func recordToBookmark(_ record: CKRecord) -> Bookmark? {
        guard let url = record["url"] as? String,
              let title = record["title"] as? String,
              let createdAt = record["createdAt"] as? Date else {
            return nil
        }

        let idString = record.recordID.recordName.replacingOccurrences(of: "Bookmark-", with: "")
        guard let id = UUID(uuidString: idString) else { return nil }

        let folderIdString = record["folderId"] as? String
        let folderId = folderIdString.flatMap { UUID(uuidString: $0) }
        let favicon = record["favicon"] as? String

        return Bookmark(id: id, url: url, title: title, folderId: folderId, favicon: favicon, createdAt: createdAt)
    }

    // MARK: - BookmarkFolder Sync

    func folderToRecord(_ folder: BookmarkFolder) -> CKRecord {
        let record = createRecord(type: .bookmarkFolder, uuid: folder.id)
        record["name"] = folder.name
        record["parentId"] = folder.parentId?.uuidString
        record["createdAt"] = folder.createdAt
        return record
    }

    func recordToFolder(_ record: CKRecord) -> BookmarkFolder? {
        guard let name = record["name"] as? String,
              let createdAt = record["createdAt"] as? Date else {
            return nil
        }

        let idString = record.recordID.recordName.replacingOccurrences(of: "BookmarkFolder-", with: "")
        guard let id = UUID(uuidString: idString) else { return nil }

        let parentIdString = record["parentId"] as? String
        let parentId = parentIdString.flatMap { UUID(uuidString: $0) }

        return BookmarkFolder(id: id, name: name, parentId: parentId, createdAt: createdAt)
    }

    // MARK: - ReadingListItem Sync

    func readingListItemToRecord(_ item: ReadingListItem) -> CKRecord {
        let record = createRecord(type: .readingListItem, uuid: item.id)
        record["url"] = item.url
        record["title"] = item.title
        record["excerpt"] = item.excerpt
        record["isRead"] = item.isRead
        record["addedAt"] = item.addedAt
        record["readAt"] = item.readAt
        return record
    }

    func recordToReadingListItem(_ record: CKRecord) -> ReadingListItem? {
        guard let url = record["url"] as? String,
              let title = record["title"] as? String,
              let addedAt = record["addedAt"] as? Date else {
            return nil
        }

        let idString = record.recordID.recordName.replacingOccurrences(of: "ReadingListItem-", with: "")
        guard let id = UUID(uuidString: idString) else { return nil }

        let excerpt = record["excerpt"] as? String
        let isRead = record["isRead"] as? Bool ?? false
        let readAt = record["readAt"] as? Date

        return ReadingListItem(id: id, url: url, title: title, excerpt: excerpt, isRead: isRead, addedAt: addedAt, readAt: readAt)
    }

    // MARK: - GenTab Sync

    func genTabToRecord(_ genTab: GenTab) -> CKRecord {
        let record = createRecord(type: .genTab, uuid: genTab.id)
        record["title"] = genTab.title
        record["icon"] = genTab.icon
        record["createdAt"] = genTab.createdAt

        // Encode components as JSON data
        if let componentsData = try? JSONEncoder().encode(genTab.components) {
            record["componentsData"] = componentsData
        }

        if let html = genTab.html {
            record["html"] = html
        }

        // Encode source URLs as JSON data
        if let sourcesData = try? JSONEncoder().encode(genTab.sourceURLs) {
            record["sourceURLsData"] = sourcesData
        }

        return record
    }

    func recordToGenTab(_ record: CKRecord) -> GenTab? {
        guard let title = record["title"] as? String,
              let icon = record["icon"] as? String else {
            return nil
        }

        let idString = record.recordID.recordName.replacingOccurrences(of: "GenTab-", with: "")
        guard let id = UUID(uuidString: idString) else { return nil }

        var components: [GenTabComponent] = []
        if let componentsData = record["componentsData"] as? Data {
            components = (try? JSONDecoder().decode([GenTabComponent].self, from: componentsData)) ?? []
        }

        var sourceURLs: [SourceAttribution] = []
        if let sourcesData = record["sourceURLsData"] as? Data {
            sourceURLs = (try? JSONDecoder().decode([SourceAttribution].self, from: sourcesData)) ?? []
        }

        let html = record["html"] as? String

        return GenTab(id: id, title: title, icon: icon, components: components, html: html, sourceURLs: sourceURLs)
    }

    // MARK: - TabGroup Sync

    func tabGroupToRecord(_ group: TabGroup) -> CKRecord {
        let record = createRecord(type: .tabGroup, uuid: group.id)
        record["name"] = group.name
        record["icon"] = group.icon
        record["colorName"] = group.colorName
        record["isCollapsed"] = group.isCollapsed
        record["createdAt"] = group.createdAt

        // Encode tab IDs as JSON array
        let tabIdStrings = group.tabIds.map { $0.uuidString }
        if let tabIdsData = try? JSONEncoder().encode(tabIdStrings) {
            record["tabIdsData"] = tabIdsData
        }

        return record
    }

    func recordToTabGroup(_ record: CKRecord) -> TabGroup? {
        guard let name = record["name"] as? String else {
            return nil
        }

        let idString = record.recordID.recordName.replacingOccurrences(of: "TabGroup-", with: "")
        guard let id = UUID(uuidString: idString) else { return nil }

        let icon = record["icon"] as? String ?? "folder.fill"
        let colorName = record["colorName"] as? String ?? "blue"
        let isCollapsed = record["isCollapsed"] as? Bool ?? false

        var tabIds: [UUID] = []
        if let tabIdsData = record["tabIdsData"] as? Data,
           let tabIdStrings = try? JSONDecoder().decode([String].self, from: tabIdsData) {
            tabIds = tabIdStrings.compactMap { UUID(uuidString: $0) }
        }

        return TabGroup(id: id, name: name, icon: icon, colorName: colorName, tabIds: tabIds, isCollapsed: isCollapsed)
    }

    // MARK: - Fetch Changes

    /// Fetch changes since last sync using change tokens
    func fetchChanges() async throws -> ChangeBatch {
        guard iCloudAvailable, let database = privateDatabase else {
            throw CloudKitError.notAvailable
        }

        syncStatus = .syncing

        // Get stored change token
        let tokenKey = "CloudKitChangeToken"
        var serverChangeToken: CKServerChangeToken?
        if let tokenData = UserDefaults.standard.data(forKey: tokenKey) {
            serverChangeToken = try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: tokenData)
        }

        var changedRecords: [CKRecord] = []
        var deletedRecordIDs: [CKRecord.ID] = []
        var newToken: CKServerChangeToken?

        let configuration = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
        configuration.previousServerChangeToken = serverChangeToken

        let operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: [zoneID], configurationsByRecordZoneID: [zoneID: configuration])

        operation.recordWasChangedBlock = { _, result in
            if case .success(let record) = result {
                changedRecords.append(record)
            }
        }

        operation.recordWithIDWasDeletedBlock = { recordID, _ in
            deletedRecordIDs.append(recordID)
        }

        operation.recordZoneChangeTokensUpdatedBlock = { _, token, _ in
            newToken = token
        }

        operation.recordZoneFetchResultBlock = { (_, result: Result<(serverChangeToken: CKServerChangeToken, clientChangeTokenData: Data?, moreComing: Bool), Error>) in
            if case .success(let successResult) = result {
                newToken = successResult.serverChangeToken
            }
        }

        return try await withCheckedThrowingContinuation { continuation in
            operation.fetchRecordZoneChangesResultBlock = { result in
                Task { @MainActor in
                    switch result {
                    case .success:
                        // Save new change token
                        if let token = newToken,
                           let tokenData = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true) {
                            UserDefaults.standard.set(tokenData, forKey: tokenKey)
                        }

                        self.syncStatus = .success
                        self.lastSyncDate = Date()

                        let batch = ChangeBatch(changedRecords: changedRecords, deletedRecordIDs: deletedRecordIDs)
                        continuation.resume(returning: batch)

                    case .failure(let error):
                        self.syncStatus = .error(error.localizedDescription)
                        self.syncError = error
                        continuation.resume(throwing: error)
                    }
                }
            }

            database.add(operation)
        }
    }

    // MARK: - Error Types

    enum CloudKitError: LocalizedError {
        case notAvailable
        case recordNotFound
        case invalidData
        case quotaExceeded

        var errorDescription: String? {
            switch self {
            case .notAvailable:
                return "iCloud is not available. Please sign in to iCloud in System Settings."
            case .recordNotFound:
                return "The requested record was not found."
            case .invalidData:
                return "The data could not be processed."
            case .quotaExceeded:
                return "iCloud storage quota exceeded."
            }
        }
    }

    // MARK: - Change Batch

    struct ChangeBatch {
        let changedRecords: [CKRecord]
        let deletedRecordIDs: [CKRecord.ID]

        var isEmpty: Bool {
            changedRecords.isEmpty && deletedRecordIDs.isEmpty
        }
    }
}
