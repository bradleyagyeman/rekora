import XCTest
@testable import Rekora

final class RekoraTests: XCTestCase {
    func testAppCopyIntroducesRekoraAsMusicBackup() {
        XCTAssertEqual(AppCopy.title, "Rekora")
        XCTAssertTrue(AppCopy.tagline.contains("Apple Music"))
        XCTAssertFalse(AppCopy.primaryActionTitle.isEmpty)
    }

    func testSavedBackupCopyUsesFriendlyTimestampInsteadOfElapsedSeconds() throws {
        let createdAt = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-06-07T00:44:50Z"))
        let timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let manifest = SnapshotManifest(
            latestSnapshotFileName: "rekora-snapshot-2026-06-07T004450Z.json",
            createdAt: createdAt,
            songCount: 9_453,
            albumCount: 93,
            playlistCount: 19,
            playlistTrackCount: 10_654,
            schemaVersion: 1
        )

        let copy = SnapshotStatusCopy.savedDetailText(for: manifest, timeZone: timeZone)

        XCTAssertEqual(
            copy,
            "9453 songs, 93 albums, 19 playlists saved Jun 6, 2026 at 8:44 PM. Saved inside Rekora on this iPhone."
        )
        XCTAssertFalse(copy.localizedCaseInsensitiveContains("saved in 0 seconds"))
        XCTAssertFalse(copy.localizedCaseInsensitiveContains("seconds"))
    }

    func testBackupImportCopyUsesNonTechnicalLanguage() {
        let visibleCopy = [
            AppCopy.backupImportReadyTitle,
            AppCopy.backupImportReadyMessage,
            AppCopy.backupImportCheckingTitle,
            AppCopy.backupImportCheckingMessage,
            AppCopy.backupImportValidTitle,
            AppCopy.backupImportFailedTitle,
            AppCopy.backupImportNoSelectionMessage,
            AppCopy.backupImportFailedMessage
        ].joined(separator: " ")

        XCTAssertTrue(visibleCopy.contains("check"))
        XCTAssertFalse(visibleCopy.localizedCaseInsensitiveContains("schema"))
        XCTAssertFalse(visibleCopy.localizedCaseInsensitiveContains("validate"))
        XCTAssertFalse(visibleCopy.localizedCaseInsensitiveContains("contents"))
        XCTAssertFalse(visibleCopy.localizedCaseInsensitiveContains("filename"))
    }

    func testBackupImportMetadataCopyUsesDeviceLanguage() {
        let summary = BackupImportSummary(
            snapshotID: UUID(uuidString: "00000000-0000-0000-0000-000000000014")!,
            createdAt: Date(timeIntervalSince1970: 0),
            schemaVersion: 1,
            appVersion: "0.3.0",
            platform: "iOS",
            songCount: 1,
            albumCount: 1,
            playlistCount: 1,
            playlistTrackCount: 1,
            playlistOrderWarningCount: 0
        )

        XCTAssertEqual(
            BackupImportStatusCopy.metadataText(for: summary),
            "Created with Rekora for iPhone"
        )
    }

    func testSnapshotDiffCopyAvoidsAppleMusicMutationLanguage() throws {
        let olderDate = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-06-10T20:00:00Z"))
        let newerDate = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-06-11T20:00:00Z"))
        let diff = SnapshotDiffSummary(
            olderCreatedAt: olderDate,
            newerCreatedAt: newerDate,
            addedSongs: [
                BackupSong(id: "song-1", title: "Song", artistName: "Artist")
            ],
            removedSongs: [
                BackupSong(id: "song-2", title: "Other Song", artistName: "Artist")
            ],
            addedPlaylists: [],
            removedPlaylists: [],
            changedPlaylists: [
                PlaylistDiff(
                    playlistID: "playlist-1",
                    name: "Favorites",
                    addedTracks: [],
                    removedTracks: [],
                    orderChanged: true
                )
            ]
        )

        let detail = SnapshotDiffStatusCopy.detailText(
            for: diff,
            timeZone: try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        )
        let rows = SnapshotDiffStatusCopy.rows(for: diff).joined(separator: " ")

        XCTAssertEqual(
            detail,
            "Compared with backup from Jun 10, 2026 at 4:00 PM. This is read-only; Rekora did not change Apple Music."
        )
        XCTAssertTrue(rows.contains("1 song added to this backup"))
        XCTAssertTrue(rows.contains("1 song removed from this backup"))
        XCTAssertTrue(rows.contains("1 playlist changed"))
        XCTAssertTrue(rows.contains("1 playlist order changed"))
        XCTAssertFalse(rows.localizedCaseInsensitiveContains("deleted"))
    }

    func testRebuildPlanCopyIsReadOnlyAndNonTechnical() {
        let plan = RebuildPlanSummary(
            snapshotCreatedAt: Date(timeIntervalSince1970: 0),
            playlists: [
                PlaylistRebuildPlan(
                    playlistID: "playlist-1",
                    name: "Favorites",
                    tracks: [
                        RebuildTrackPlan(
                            playlistID: "playlist-1",
                            songID: "song-1",
                            title: "Song",
                            artistName: "Artist",
                            order: 0,
                            readiness: .strongIdentifier
                        ),
                        RebuildTrackPlan(
                            playlistID: "playlist-1",
                            songID: "song-2",
                            title: "Other Song",
                            artistName: "Artist",
                            order: 1,
                            readiness: .metadataOnly
                        )
                    ],
                    usesObservedOrder: true
                )
            ]
        )

        let detail = RebuildPlanStatusCopy.detailText(for: plan)
        let rows = RebuildPlanStatusCopy.rows(for: plan).joined(separator: " ")

        XCTAssertTrue(detail.contains("read-only"))
        XCTAssertTrue(detail.contains("did not change Apple Music"))
        XCTAssertEqual(
            detail,
            "Rekora found 1 playlist and 2 playlist entries it can prepare. This is read-only; Rekora did not change Apple Music."
        )
        XCTAssertTrue(rows.contains("1 track looks ready to match automatically"))
        XCTAssertTrue(rows.contains("1 track may need review before rebuilding"))
        XCTAssertTrue(rows.contains("1 playlist will use saved playlist order"))
        XCTAssertFalse(rows.localizedCaseInsensitiveContains("schema"))
        XCTAssertFalse(rows.localizedCaseInsensitiveContains("json"))
        XCTAssertFalse(rows.localizedCaseInsensitiveContains("isrc"))
        XCTAssertFalse(rows.localizedCaseInsensitiveContains("identifier"))
    }

    func testLiveCheckedRebuildPlanCopyStaysReadOnlyAndPlainLanguage() {
        let plan = RebuildPlanSummary(
            snapshotCreatedAt: Date(timeIntervalSince1970: 0),
            playlists: [
                PlaylistRebuildPlan(
                    playlistID: "playlist-1",
                    name: "Favorites",
                    tracks: [
                        RebuildTrackPlan(
                            playlistID: "playlist-1",
                            songID: "song-1",
                            title: "Song",
                            artistName: "Artist",
                            order: 0,
                            readiness: .strongIdentifier,
                            liveMatch: LiveMusicTrackMatch(
                                songID: "song-1",
                                status: .matched,
                                matchedID: "live-song-1",
                                reason: .libraryID
                            )
                        ),
                        RebuildTrackPlan(
                            playlistID: "playlist-1",
                            songID: "song-2",
                            title: "Other Song",
                            artistName: "Artist",
                            order: 1,
                            readiness: .metadataOnly,
                            liveMatch: LiveMusicTrackMatch(
                                songID: "song-2",
                                status: .needsReview,
                                reason: .multipleCandidates
                            )
                        )
                    ],
                    usesObservedOrder: false
                )
            ]
        )

        let detail = RebuildPlanStatusCopy.detailText(for: plan)
        let checking = RebuildPlanStatusCopy.checkingText(for: plan)
        let permission = RebuildPlanStatusCopy.permissionText(for: plan)
        let rows = RebuildPlanStatusCopy.rows(for: plan).joined(separator: " ")

        XCTAssertEqual(
            detail,
            "Rekora checked this backup against Apple Music. This is read-only; Rekora did not change Apple Music."
        )
        XCTAssertEqual(
            checking,
            "Checking this backup against Apple Music. This is read-only; Rekora is not creating or editing playlists."
        )
        XCTAssertEqual(
            permission,
            "Allow Apple Music access before checking matches. Rekora can still read this backup without changing Apple Music."
        )
        XCTAssertTrue(rows.contains("1 track is ready to rebuild now"))
        XCTAssertTrue(rows.contains("1 track needs review before rebuilding"))
        XCTAssertFalse(rows.localizedCaseInsensitiveContains("isrc"))
        XCTAssertFalse(rows.localizedCaseInsensitiveContains("identifier"))
        XCTAssertFalse(rows.localizedCaseInsensitiveContains("json"))
    }

    func testLiveCheckedCopyDoesNotOverstateMetadataOnlyMatches() {
        let plan = RebuildPlanSummary(
            snapshotCreatedAt: Date(timeIntervalSince1970: 0),
            playlists: [
                PlaylistRebuildPlan(
                    playlistID: "playlist-1",
                    name: "Favorites",
                    tracks: [
                        RebuildTrackPlan(
                            playlistID: "playlist-1",
                            songID: "song-1",
                            title: "Song",
                            artistName: "Artist",
                            order: 0,
                            readiness: .metadataOnly,
                            liveMatch: LiveMusicTrackMatch(
                                songID: "song-1",
                                status: .matched,
                                matchedID: "metadata-match",
                                reason: .metadata
                            )
                        )
                    ],
                    usesObservedOrder: false
                )
            ]
        )

        let rows = RebuildPlanStatusCopy.rows(for: plan).joined(separator: " ")

        XCTAssertTrue(rows.contains("1 track needs review before rebuilding"))
        XCTAssertFalse(rows.localizedCaseInsensitiveContains("ready to rebuild now"))
        XCTAssertFalse(rows.localizedCaseInsensitiveContains("found in Apple Music"))
    }

    func testPlaylistRebuildCopyIsExplicitAboutNewPlaylistOnly() {
        let preview = PlaylistRebuildPreview(
            playlistID: "playlist-1",
            sourcePlaylistName: "Favorites",
            newPlaylistName: "Rekora Restore - Favorites",
            matchedTrackCount: 2,
            skippedTrackCount: 1,
            totalTrackCount: 3
        )
        let result = PlaylistRebuildResult(
            sourcePlaylistName: "Favorites",
            createdPlaylist: MusicPlaylistSummary(id: "created-playlist", name: "Rekora Restore - Favorites"),
            addedTrackCount: 2,
            skippedTrackCount: 1,
            totalTrackCount: 3
        )

        XCTAssertEqual(
            PlaylistRebuildStatusCopy.confirmationText(for: preview),
            "Rekora will create a new Apple Music playlist named \"Rekora Restore - Favorites\". Your existing playlists will not be changed."
        )
        XCTAssertEqual(
            PlaylistRebuildStatusCopy.previewText(for: preview),
            "2 tracks will be added to a new playlist. 1 track will be skipped."
        )
        XCTAssertEqual(
            PlaylistRebuildStatusCopy.completedText(for: result),
            "Created \"Rekora Restore - Favorites\" with 2 tracks. 1 track needed review and was skipped."
        )
    }

    func testStartupBrandingUsesThirteenHundredMillisecondsOnFirstLaunch() {
        XCTAssertEqual(
            StartupBrandingPolicy.displayDuration(hasSeenStartupBranding: false),
            .milliseconds(1_300)
        )
    }

    func testStartupBrandingUsesShorterDurationAfterFirstLaunch() {
        XCTAssertEqual(
            StartupBrandingPolicy.displayDuration(hasSeenStartupBranding: true),
            .milliseconds(250)
        )
    }
}
