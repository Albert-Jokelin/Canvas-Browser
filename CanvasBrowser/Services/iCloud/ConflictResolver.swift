import Foundation
import os.log

/// Handles merge conflicts during CloudKit synchronization
@MainActor
class ConflictResolver {
    static let shared = ConflictResolver()

    private let logger = Logger(subsystem: "com.canvas.browser", category: "ConflictResolver")

    // MARK: - Resolution Strategy

    enum ResolutionStrategy {
        case localWins       // Always prefer local changes
        case remoteWins      // Always prefer remote changes
        case newerWins       // Prefer whichever was modified more recently
        case merge           // Attempt to merge changes
    }

    /// Default resolution strategy
    var defaultStrategy: ResolutionStrategy = .newerWins

    private init() {}

    // MARK: - Bookmark Conflict Resolution

    /// Resolve conflict between local and remote bookmark
    /// Returns the resolved bookmark, or nil if no change needed
    func resolveBookmarkConflict(local: Bookmark, remote: Bookmark) -> Bookmark? {
        // If they're identical, no change needed
        if local == remote {
            return nil
        }

        switch defaultStrategy {
        case .localWins:
            logger.info("Bookmark conflict resolved: local wins - \(local.title)")
            return local

        case .remoteWins:
            logger.info("Bookmark conflict resolved: remote wins - \(remote.title)")
            return remote

        case .newerWins:
            // Compare creation dates (bookmarks don't have modifiedAt)
            if local.createdAt > remote.createdAt {
                logger.info("Bookmark conflict resolved: local newer - \(local.title)")
                return local
            } else {
                logger.info("Bookmark conflict resolved: remote newer - \(remote.title)")
                return remote
            }

        case .merge:
            // For bookmarks, merge by preferring non-nil values
            let merged = mergeBookmarks(local: local, remote: remote)
            logger.info("Bookmark conflict resolved: merged - \(merged.title)")
            return merged
        }
    }

    private func mergeBookmarks(local: Bookmark, remote: Bookmark) -> Bookmark {
        // Use remote URL and title if local hasn't changed them
        // Prefer newer values for optional fields
        let mergedTitle = local.title != remote.title ?
            (local.createdAt > remote.createdAt ? local.title : remote.title) : local.title

        let mergedFolderId = local.folderId ?? remote.folderId
        let mergedFavicon = local.favicon ?? remote.favicon

        return Bookmark(
            id: local.id,
            url: remote.url, // URL should be consistent
            title: mergedTitle,
            folderId: mergedFolderId,
            favicon: mergedFavicon
        )
    }

    // MARK: - BookmarkFolder Conflict Resolution

    func resolveBookmarkFolderConflict(local: BookmarkFolder, remote: BookmarkFolder) -> BookmarkFolder? {
        if local == remote {
            return nil
        }

        switch defaultStrategy {
        case .localWins:
            return local

        case .remoteWins:
            return remote

        case .newerWins:
            return local.createdAt > remote.createdAt ? local : remote

        case .merge:
            // Merge folder - prefer remote name if different, keep local parentId
            let mergedName = local.name != remote.name ?
                (local.createdAt > remote.createdAt ? local.name : remote.name) : local.name

            return BookmarkFolder(
                id: local.id,
                name: mergedName,
                parentId: local.parentId ?? remote.parentId
            )
        }
    }

    // MARK: - ReadingList Conflict Resolution

    func resolveReadingListConflict(local: ReadingListItem, remote: ReadingListItem) -> ReadingListItem? {
        if local == remote {
            return nil
        }

        switch defaultStrategy {
        case .localWins:
            logger.info("Reading list conflict resolved: local wins - \(local.title)")
            return local

        case .remoteWins:
            logger.info("Reading list conflict resolved: remote wins - \(remote.title)")
            return remote

        case .newerWins:
            // For reading list, compare addedAt
            if local.addedAt > remote.addedAt {
                return local
            } else {
                return remote
            }

        case .merge:
            return mergeReadingListItems(local: local, remote: remote)
        }
    }

    private func mergeReadingListItems(local: ReadingListItem, remote: ReadingListItem) -> ReadingListItem {
        // Merge read status - if either is read, mark as read
        let mergedIsRead = local.isRead || remote.isRead

        // Use the most recent readAt date
        let mergedReadAt: Date?
        if let localReadAt = local.readAt, let remoteReadAt = remote.readAt {
            mergedReadAt = max(localReadAt, remoteReadAt)
        } else {
            mergedReadAt = local.readAt ?? remote.readAt
        }

        // Prefer longer excerpt
        let mergedExcerpt: String?
        if let localExcerpt = local.excerpt, let remoteExcerpt = remote.excerpt {
            mergedExcerpt = localExcerpt.count > remoteExcerpt.count ? localExcerpt : remoteExcerpt
        } else {
            mergedExcerpt = local.excerpt ?? remote.excerpt
        }

        return ReadingListItem(
            id: local.id,
            url: local.url,
            title: local.title.count > remote.title.count ? local.title : remote.title,
            excerpt: mergedExcerpt,
            isRead: mergedIsRead,
            addedAt: min(local.addedAt, remote.addedAt), // Use earliest addedAt
            readAt: mergedReadAt
        )
    }

    // MARK: - GenTab Conflict Resolution

    func resolveGenTabConflict(local: GenTab, remote: GenTab) -> GenTab? {
        // GenTabs are generally immutable after creation
        // Prefer the one with more components (more complete)
        if local.components.count >= remote.components.count {
            return local
        } else {
            return remote
        }
    }

    // MARK: - TabGroup Conflict Resolution

    func resolveTabGroupConflict(local: TabGroup, remote: TabGroup) -> TabGroup? {
        if local == remote {
            return nil
        }

        switch defaultStrategy {
        case .localWins:
            return local

        case .remoteWins:
            return remote

        case .newerWins:
            return local.createdAt > remote.createdAt ? local : remote

        case .merge:
            return mergeTabGroups(local: local, remote: remote)
        }
    }

    private func mergeTabGroups(local: TabGroup, remote: TabGroup) -> TabGroup {
        // Merge tab IDs - union of both sets
        let mergedTabIds = Array(Set(local.tabIds + remote.tabIds))

        // Use local visual preferences if set
        return TabGroup(
            id: local.id,
            name: local.name,
            icon: local.icon,
            colorName: local.colorName,
            tabIds: mergedTabIds,
            isCollapsed: local.isCollapsed
        )
    }

    // MARK: - Batch Conflict Resolution

    /// Resolve conflicts for a batch of items
    func resolveBookmarkBatch(local: [Bookmark], remote: [Bookmark]) -> [Bookmark] {
        var result: [Bookmark] = []
        var processedIds = Set<UUID>()

        // Process local items
        for localItem in local {
            processedIds.insert(localItem.id)
            if let remoteItem = remote.first(where: { $0.id == localItem.id }) {
                if let resolved = resolveBookmarkConflict(local: localItem, remote: remoteItem) {
                    result.append(resolved)
                } else {
                    result.append(localItem)
                }
            } else {
                result.append(localItem)
            }
        }

        // Add remote-only items
        for remoteItem in remote where !processedIds.contains(remoteItem.id) {
            result.append(remoteItem)
        }

        return result
    }

    func resolveReadingListBatch(local: [ReadingListItem], remote: [ReadingListItem]) -> [ReadingListItem] {
        var result: [ReadingListItem] = []
        var processedIds = Set<UUID>()

        for localItem in local {
            processedIds.insert(localItem.id)
            if let remoteItem = remote.first(where: { $0.id == localItem.id }) {
                if let resolved = resolveReadingListConflict(local: localItem, remote: remoteItem) {
                    result.append(resolved)
                } else {
                    result.append(localItem)
                }
            } else {
                result.append(localItem)
            }
        }

        for remoteItem in remote where !processedIds.contains(remoteItem.id) {
            result.append(remoteItem)
        }

        return result
    }

    // MARK: - Conflict Detection

    /// Check if two items have a conflict
    func hasConflict<T: Equatable>(_ local: T, _ remote: T) -> Bool {
        return local != remote
    }

    /// Generate a conflict report
    func generateConflictReport(
        bookmarkConflicts: Int,
        readingListConflicts: Int,
        genTabConflicts: Int,
        tabGroupConflicts: Int
    ) -> String {
        let total = bookmarkConflicts + readingListConflicts + genTabConflicts + tabGroupConflicts

        if total == 0 {
            return "No conflicts detected during sync."
        }

        var report = "Sync Conflict Report:\n"
        if bookmarkConflicts > 0 {
            report += "- Bookmarks: \(bookmarkConflicts) conflicts resolved\n"
        }
        if readingListConflicts > 0 {
            report += "- Reading List: \(readingListConflicts) conflicts resolved\n"
        }
        if genTabConflicts > 0 {
            report += "- GenTabs: \(genTabConflicts) conflicts resolved\n"
        }
        if tabGroupConflicts > 0 {
            report += "- Tab Groups: \(tabGroupConflicts) conflicts resolved\n"
        }
        report += "Resolution strategy: \(strategyDescription)"

        return report
    }

    private var strategyDescription: String {
        switch defaultStrategy {
        case .localWins: return "Local changes preferred"
        case .remoteWins: return "Remote changes preferred"
        case .newerWins: return "Newer changes preferred"
        case .merge: return "Changes merged"
        }
    }
}

// MARK: - Conflict Result

struct ConflictResult<T> {
    let original: T
    let conflicting: T
    let resolved: T
    let strategy: ConflictResolver.ResolutionStrategy
}
