import Foundation

enum AppCopy {
    static let title = "Rekora"
    static let tagline = "Back up your Apple Music library map."
    static let privacyNote = "Saved locally on your device, not on Rekora's servers."

    static let primaryActionTitle = "Create Backup"

    static let snapshotReadyTitle = "No backups yet"
    static let snapshotReadyMessage = "Allow Apple Music access, then save your library map inside Rekora."
    static let snapshotSavingMessage = "Creating backup... Rekora can only save the playlist order Apple Music provides."
    static let snapshotSavedTitle = "Latest backup"
    static let snapshotFailedTitle = "Backup failed"
    static let snapshotNeedsPermissionMessage = "Allow Apple Music access before creating a backup."
    static let snapshotStoredLocallyMessage = "Saved inside Rekora on this iPhone."
    static let snapshotViewDetailsTitle = "View Backup"
    static let snapshotDetailTitle = "Backup"
    static let snapshotDetailIncludedTitle = "Included"
    static let snapshotDetailChangesTitle = "Changes"
    static let snapshotDetailRebuildPlanTitle = "Restore preview"
    static let snapshotDetailLocationTitle = "Where it is saved"
    static let snapshotDetailLocationMessage = "This backup is stored inside Rekora on this iPhone. Rekora does not upload it to a server. It may be included in normal iPhone or iCloud device backups, depending on your iOS settings."
    static let snapshotChangesLoadingTitle = "Checking for changes"
    static let snapshotChangesLoadingMessage = "Comparing this backup with the previous backup on this iPhone."
    static let snapshotChangesUnavailableTitle = "No previous backup yet"
    static let snapshotChangesUnavailableMessage = "Create another backup later to see what changed."
    static let snapshotChangesChangedTitle = "Changes since previous backup"
    static let snapshotChangesUnchangedTitle = "No changes found"
    static let snapshotChangesFailedTitle = "Could not check changes"
    static let rebuildPlanLoadingTitle = "Preparing restore preview"
    static let rebuildPlanLoadingMessage = "Reading this backup without changing Apple Music."
    static let rebuildPlanReadyTitle = "Preview ready"
    static let rebuildPlanCheckingTitle = "Checking Apple Music"
    static let rebuildPlanPermissionTitle = "Apple Music access needed"
    static let rebuildPlanEmptyTitle = "No playlists to restore"
    static let rebuildPlanFailedTitle = "Could not prepare preview"
    static let rebuildPlanCheckMatchesTitle = "Check Apple Music Matches"
    static let rebuildPlanCreateTitle = "Create new playlist"
    static let rebuildPlanConfirmTitle = "Create Playlist"
    static let rebuildPlanCancelTitle = "Cancel"
    static let snapshotExportTitle = "Save Copy to Files"
    static let snapshotExportMessage = "Choose where to keep a copy you can see outside Rekora."
    static let snapshotExportMissingMessage = "Create a backup before saving a copy."
    static let snapshotExportSuccessMessage = "Copy saved."
    static let snapshotExportFailedMessage = "Rekora could not prepare the backup copy."
    static let backupImportReadyTitle = "Check backup"
    static let backupImportReadyMessage = "Choose a backup file. Rekora will check whether it can read it."
    static let backupImportCheckingTitle = "Checking backup file"
    static let backupImportCheckingMessage = "Reading the selected file without changing Apple Music."
    static let backupImportValidTitle = "Rekora can read this backup"
    static let backupImportFailedTitle = "Rekora cannot read this backup"
    static let backupImportActionTitle = "Choose Backup File"
    static let backupImportAnotherActionTitle = "Choose Another File"
    static let backupImportNoSelectionMessage = "Choose a backup file to check."
    static let backupImportFailedMessage = "Rekora could not read that backup."
    static let libraryProbeTitle = "Developer validation"
    static let libraryProbeActionTitle = "Inspect Library Data"
    static let libraryProbeReadyMessage = "Temporarily checks what Apple Music data Rekora can read. Read-only."
    static let libraryProbeRunningMessage = "Inspecting Apple Music library..."
    static let libraryProbeBlockedMessage = "Allow Apple Music access before inspecting library data."
    static let libraryProbeFailedTitle = "Library inspection failed"

    static let musicPermissionActionTitle = "Allow Apple Music Access"
    static let musicPermissionLoadingTitle = "Checking Apple Music access"
    static let musicPermissionRequestingMessage = "Waiting for Apple Music permission..."

    static let playlistActionTitle = "Check Playlists"
    static let playlistReadyTitle = "Apple Music playlists"
    static let playlistReadyMessage = "Allow Apple Music access, then check for real playlist data."
    static let playlistAuthorizedMessage = "Ready to check your Apple Music playlists."
    static let playlistLoadingMessage = "Checking Apple Music playlists..."
    static let playlistBlockedMessage = "Apple Music access is needed before Rekora can check playlists."
    static let playlistFailedTitle = "Playlist check failed"

    static let sectionPermission = "Access"
    static let sectionPlaylists = "Library check"
    static let sectionBackup = "Local backup"
    static let sectionImport = "Backup import"
}

enum SnapshotStatusCopy {
    static func savedDetailText(
        for manifest: SnapshotManifest,
        timeZone: TimeZone = .current
    ) -> String {
        [
            "\(savedSummaryText(for: manifest)) saved \(savedTimestampText(for: manifest.createdAt, timeZone: timeZone)).",
            AppCopy.snapshotStoredLocallyMessage
        ].joined(separator: " ")
    }

    static func savedTimestampText(for date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = makeSavedDateFormatter(timeZone: timeZone)
        return formatter.string(from: date)
    }

    static func savedSummaryText(for manifest: SnapshotManifest) -> String {
        [
            countText(manifest.songCount, singular: "song"),
            countText(manifest.albumCount, singular: "album"),
            countText(manifest.playlistCount, singular: "playlist")
        ].joined(separator: ", ")
    }

    static func playlistOrderSummaryText(for manifest: SnapshotManifest) -> String? {
        guard manifest.playlistOrderWarningCount > 0 else {
            return nil
        }

        let count = countText(manifest.playlistOrderWarningCount, singular: "playlist")
        return "\(count) had unusual Apple-reported order data; Rekora saved observed order too."
    }

    private static func countText(_ count: Int, singular: String) -> String {
        if count == 1 {
            return "1 \(singular)"
        }
        return "\(count) \(singular)s"
    }

    private static func makeSavedDateFormatter(timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
        return formatter
    }
}

enum BackupImportStatusCopy {
    static func validDetailText(
        for summary: BackupImportSummary,
        timeZone: TimeZone = .current
    ) -> String {
        let timestamp = SnapshotStatusCopy.savedTimestampText(
            for: summary.createdAt,
            timeZone: timeZone
        )
        return "Rekora backup from \(timestamp). No Apple Music changes were made."
    }

    static func countSummaryText(for summary: BackupImportSummary) -> String {
        [
            countText(summary.songCount, singular: "song"),
            countText(summary.albumCount, singular: "album"),
            countText(summary.playlistCount, singular: "playlist")
        ].joined(separator: ", ")
    }

    static func metadataText(for summary: BackupImportSummary) -> String {
        "Created with Rekora for \(platformDisplayName(summary.platform))"
    }

    private static func countText(_ count: Int, singular: String) -> String {
        if count == 1 {
            return "1 \(singular)"
        }
        return "\(count) \(singular)s"
    }

    private static func platformDisplayName(_ platform: String) -> String {
        platform == "iOS" ? "iPhone" : platform
    }
}

enum SnapshotDiffStatusCopy {
    static func detailText(for diff: SnapshotDiffSummary, timeZone: TimeZone = .current) -> String {
        let timestamp = SnapshotStatusCopy.savedTimestampText(
            for: diff.olderCreatedAt,
            timeZone: timeZone
        )

        return "Compared with backup from \(timestamp). This is read-only; Rekora did not change Apple Music."
    }

    static func rows(for diff: SnapshotDiffSummary) -> [String] {
        var rows = [String]()

        appendCount(diff.addedSongs.count, singular: "song", suffix: "added to this backup", to: &rows)
        appendCount(diff.removedSongs.count, singular: "song", suffix: "removed from this backup", to: &rows)
        appendCount(diff.addedPlaylists.count, singular: "playlist", suffix: "added to this backup", to: &rows)
        appendCount(diff.removedPlaylists.count, singular: "playlist", suffix: "removed from this backup", to: &rows)
        appendCount(diff.changedPlaylists.count, singular: "playlist", suffix: "changed", to: &rows)
        appendCount(diff.playlistTrackAddedCount, singular: "playlist track", suffix: "added to this backup", to: &rows)
        appendCount(
            diff.playlistTrackRemovedCount,
            singular: "playlist track",
            suffix: "removed from this backup",
            to: &rows
        )
        appendCount(
            diff.playlistOrderChangeCount,
            singular: "playlist order",
            suffix: "changed",
            to: &rows
        )

        return rows
    }

    private static func appendCount(
        _ count: Int,
        singular: String,
        suffix: String,
        to rows: inout [String]
    ) {
        guard count > 0 else {
            return
        }

        let label = count == 1 ? singular : "\(singular)s"
        rows.append("\(count) \(label) \(suffix)")
    }
}

enum RebuildPlanStatusCopy {
    static func detailText(for plan: RebuildPlanSummary) -> String {
        guard plan.playlistCount > 0 else {
            return "This backup does not include playlists. Rekora did not change Apple Music."
        }

        if plan.liveCheckedCount > 0 {
            return "Rekora checked this backup against Apple Music. This is read-only; Rekora did not change Apple Music."
        }

        return "Rekora found \(countText(plan.playlistCount, singular: "playlist")) and \(countText(plan.trackCount, singular: "playlist entry", plural: "playlist entries")) it can prepare. This is read-only; Rekora did not change Apple Music."
    }

    static func checkingText(for plan: RebuildPlanSummary) -> String {
        guard plan.playlistCount > 0 else {
            return detailText(for: plan)
        }

        return "Checking this backup against Apple Music. This is read-only; Rekora is not creating or editing playlists."
    }

    static func permissionText(for plan: RebuildPlanSummary) -> String {
        guard plan.playlistCount > 0 else {
            return detailText(for: plan)
        }

        return "Allow Apple Music access before checking matches. Rekora can still read this backup without changing Apple Music."
    }

    static func rows(for plan: RebuildPlanSummary) -> [String] {
        var rows = [String]()

        if plan.liveCheckedCount > 0 {
            appendCount(
                plan.liveAutomaticRebuildTrackCount,
                singular: "track",
                suffix: "is ready to rebuild now",
                pluralSuffix: "are ready to rebuild now",
                to: &rows
            )
            appendCount(
                plan.liveNeedsReviewForRebuildCount,
                singular: "track",
                suffix: "needs review before rebuilding",
                pluralSuffix: "need review before rebuilding",
                to: &rows
            )
            appendCount(
                plan.observedOrderPlaylistCount,
                singular: "playlist",
                suffix: "will use saved playlist order",
                pluralSuffix: "will use saved playlist order",
                to: &rows
            )

            return rows
        }

        let needsReviewCount = plan.searchIdentifierTrackCount +
            plan.metadataOnlyTrackCount +
            plan.missingSongRecordCount

        appendCount(
            plan.strongIdentifierTrackCount,
            singular: "track",
            suffix: "looks ready to match automatically",
            pluralSuffix: "look ready to match automatically",
            to: &rows
        )
        appendCount(
            needsReviewCount,
            singular: "track",
            suffix: "may need review before rebuilding",
            pluralSuffix: "may need review before rebuilding",
            to: &rows
        )
        appendCount(
            plan.missingSongRecordCount,
            singular: "playlist entry",
            suffix: "is missing song details",
            pluralSuffix: "are missing song details",
            to: &rows
        )
        appendCount(
            plan.observedOrderPlaylistCount,
            singular: "playlist",
            suffix: "will use saved playlist order",
            pluralSuffix: "will use saved playlist order",
            to: &rows
        )
        return rows
    }

    private static func countText(_ count: Int, singular: String, plural: String? = nil) -> String {
        if count == 1 {
            return "1 \(singular)"
        }
        return "\(count) \(plural ?? "\(singular)s")"
    }

    private static func appendCount(
        _ count: Int,
        singular: String,
        suffix: String,
        pluralSuffix: String? = nil,
        to rows: inout [String]
    ) {
        guard count > 0 else {
            return
        }

        if count == 1 {
            rows.append("1 \(singular) \(suffix)")
        } else {
            rows.append("\(count) \(singular)s \(pluralSuffix ?? suffix)")
        }
    }
}
