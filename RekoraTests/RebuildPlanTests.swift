import XCTest
@testable import Rekora

final class RebuildPlanTests: XCTestCase {
    func testPlanCountsTrackReadinessWithoutChangingAppleMusic() {
        let snapshot = makeSnapshot(
            songs: [
                song("catalog-song", title: "Catalog", catalogID: "catalog-1"),
                song("isrc-song", title: "ISRC", isrc: "USRC17607839"),
                song("metadata-song", title: "Metadata")
            ],
            playlists: [
                playlist(
                    "playlist-1",
                    tracks: [
                        track(songID: "catalog-song", order: 0),
                        track(songID: "isrc-song", order: 1),
                        track(songID: "metadata-song", order: 2),
                        track(songID: "missing-song", order: 3)
                    ]
                )
            ]
        )

        let plan = RebuildPlan.make(from: snapshot)

        XCTAssertEqual(plan.playlistCount, 1)
        XCTAssertEqual(plan.trackCount, 4)
        XCTAssertEqual(plan.strongIdentifierTrackCount, 1)
        XCTAssertEqual(plan.searchIdentifierTrackCount, 1)
        XCTAssertEqual(plan.metadataOnlyTrackCount, 1)
        XCTAssertEqual(plan.missingSongRecordCount, 1)
    }

    func testPlanPreservesObservedOrderWhenReportedPositionsAreInvalid() throws {
        let snapshot = makeSnapshot(
            songs: [
                song("song-a", title: "A", catalogID: "catalog-a"),
                song("song-b", title: "B", catalogID: "catalog-b")
            ],
            playlists: [
                playlist(
                    "playlist-1",
                    tracks: [
                        track(songID: "song-b", position: 0, snapshotOrder: 1),
                        track(songID: "song-a", position: 0, snapshotOrder: 0)
                    ]
                )
            ]
        )

        let plan = RebuildPlan.make(from: snapshot)
        let playlistPlan = try XCTUnwrap(plan.playlists.first)

        XCTAssertTrue(playlistPlan.usesObservedOrder)
        XCTAssertEqual(playlistPlan.tracks.map(\.songID), ["song-a", "song-b"])
        XCTAssertEqual(playlistPlan.tracks.map(\.order), [0, 1])
        XCTAssertEqual(plan.observedOrderPlaylistCount, 1)
    }

    func testPlanUsesReportedPositionsWhenSnapshotOrderIsMissing() throws {
        let snapshot = makeSnapshot(
            songs: [
                song("song-a", title: "A", catalogID: "catalog-a"),
                song("song-b", title: "B", catalogID: "catalog-b")
            ],
            playlists: [
                playlist(
                    "playlist-1",
                    tracks: [
                        track(songID: "song-b", position: 1),
                        track(songID: "song-a", position: 0)
                    ]
                )
            ]
        )

        let plan = RebuildPlan.make(from: snapshot)
        let playlistPlan = try XCTUnwrap(plan.playlists.first)

        XCTAssertFalse(playlistPlan.usesObservedOrder)
        XCTAssertEqual(playlistPlan.tracks.map(\.songID), ["song-a", "song-b"])
    }

    func testPlanHandlesBackupsWithNoPlaylists() {
        let plan = RebuildPlan.make(from: makeSnapshot())

        XCTAssertEqual(plan.playlistCount, 0)
        XCTAssertEqual(plan.trackCount, 0)
        XCTAssertEqual(plan.strongIdentifierTrackCount, 0)
    }

    func testPlanMergesLiveMatchesWithoutChangingPlaylistOrder() throws {
        let snapshot = makeSnapshot(
            songs: [
                song("song-a", title: "A", catalogID: "catalog-a"),
                song("song-b", title: "B", catalogID: "catalog-b")
            ],
            playlists: [
                playlist(
                    "playlist-1",
                    tracks: [
                        track(songID: "song-b", position: 0, snapshotOrder: 1),
                        track(songID: "song-a", position: 0, snapshotOrder: 0),
                        track(songID: "song-a", position: 0, snapshotOrder: 2)
                    ]
                )
            ]
        )

        let plan = RebuildPlan.make(
            from: snapshot,
            liveMatches: [
                "song-a": LiveMusicTrackMatch(
                    songID: "song-a",
                    status: .matched,
                    matchedID: "live-a",
                    reason: .catalogID
                ),
                "song-b": LiveMusicTrackMatch(
                    songID: "song-b",
                    status: .needsReview,
                    reason: .multipleCandidates
                )
            ]
        )
        let playlistPlan = try XCTUnwrap(plan.playlists.first)

        XCTAssertEqual(playlistPlan.tracks.map(\.songID), ["song-a", "song-b", "song-a"])
        XCTAssertEqual(plan.liveCheckedCount, 3)
        XCTAssertEqual(plan.liveMatchCount, 2)
        XCTAssertEqual(plan.liveAutomaticRebuildTrackCount, 2)
        XCTAssertEqual(plan.liveNeedsReviewCount, 1)
        XCTAssertEqual(plan.liveNeedsReviewForRebuildCount, 1)
        XCTAssertEqual(plan.liveUncheckedCount, 0)
    }

    func testPlanCountsMetadataOnlyLiveMatchesAsNeedingReviewForRebuild() {
        let snapshot = makeSnapshot(
            songs: [
                song("metadata-song", title: "Metadata")
            ],
            playlists: [
                playlist(
                    "playlist-1",
                    tracks: [
                        track(songID: "metadata-song", order: 0)
                    ]
                )
            ]
        )

        let plan = RebuildPlan.make(
            from: snapshot,
            liveMatches: [
                "metadata-song": LiveMusicTrackMatch(
                    songID: "metadata-song",
                    status: .matched,
                    matchedID: "metadata-match",
                    reason: .metadata
                )
            ]
        )

        XCTAssertEqual(plan.liveMatchCount, 1)
        XCTAssertEqual(plan.liveAutomaticRebuildTrackCount, 0)
        XCTAssertEqual(plan.liveNeedsReviewForRebuildCount, 1)
    }

    private func makeSnapshot(
        songs: [BackupSong] = [],
        playlists: [BackupPlaylist] = []
    ) -> BackupSnapshot {
        BackupSnapshot(
            createdAt: Date(timeIntervalSince1970: 0),
            source: SnapshotSource(appVersion: "0.3.0"),
            songs: songs,
            playlists: playlists
        )
    }

    private func song(
        _ id: String,
        title: String,
        catalogID: String? = nil,
        isrc: String? = nil
    ) -> BackupSong {
        BackupSong(
            id: id,
            identifiers: MusicItemIdentifiers(catalogID: catalogID, isrc: isrc),
            libraryStatus: .saved,
            title: title,
            artistName: "Artist"
        )
    }

    private func playlist(
        _ id: String,
        tracks: [BackupPlaylistTrack]
    ) -> BackupPlaylist {
        BackupPlaylist(
            id: id,
            name: "Favorites",
            tracks: tracks
        )
    }

    private func track(songID: String, order: Int) -> BackupPlaylistTrack {
        track(songID: songID, position: order, snapshotOrder: order)
    }

    private func track(songID: String, position: Int) -> BackupPlaylistTrack {
        BackupPlaylistTrack(
            playlistID: "playlist-1",
            songID: songID,
            position: position
        )
    }

    private func track(
        songID: String,
        position: Int,
        snapshotOrder: Int
    ) -> BackupPlaylistTrack {
        BackupPlaylistTrack(
            playlistID: "playlist-1",
            songID: songID,
            position: position,
            snapshotOrder: snapshotOrder
        )
    }
}
