import XCTest
@testable import Rekora

@MainActor
final class RestorePreviewViewModelTests: XCTestCase {
    func testLoadBuildsLocalRestorePreview() async throws {
        let snapshot = makeSnapshot()
        let model = RestorePreviewViewModel(
            snapshotStore: FakeSnapshotLoader(snapshot: snapshot),
            matcher: FakeLiveMatcher(matches: [:])
        )

        await model.load(fileName: "backup.json")

        guard case .ready(let plan) = model.state else {
            return XCTFail("Expected ready restore preview.")
        }
        XCTAssertEqual(plan.playlistCount, 1)
        XCTAssertEqual(plan.trackCount, 1)
        XCTAssertEqual(plan.liveCheckedCount, 0)
    }

    func testCheckMatchesBlocksWithoutPermissionButKeepsLocalPreview() async throws {
        let snapshot = makeSnapshot()
        let model = RestorePreviewViewModel(
            snapshotStore: FakeSnapshotLoader(snapshot: snapshot),
            matcher: FailingLiveMatcher()
        )

        await model.checkMatches(fileName: "backup.json", permissionStatus: .denied)

        guard case .blockedByPermission(let plan) = model.state else {
            return XCTFail("Expected permission-blocked restore preview.")
        }
        XCTAssertEqual(plan.playlistCount, 1)
        XCTAssertEqual(plan.liveCheckedCount, 0)
    }

    func testCheckMatchesMergesLiveResultsIntoPreview() async throws {
        let snapshot = makeSnapshot()
        let model = RestorePreviewViewModel(
            snapshotStore: FakeSnapshotLoader(snapshot: snapshot),
            matcher: FakeLiveMatcher(
                matches: [
                    "song-1": LiveMusicTrackMatch(
                        songID: "song-1",
                        status: .matched,
                        matchedID: "live-song-1",
                        reason: .libraryID
                    )
                ]
            )
        )

        await model.checkMatches(fileName: "backup.json", permissionStatus: .authorized)

        guard case .ready(let plan) = model.state else {
            return XCTFail("Expected live-checked restore preview.")
        }
        XCTAssertEqual(plan.liveCheckedCount, 1)
        XCTAssertEqual(plan.liveMatchCount, 1)
        XCTAssertEqual(plan.liveNeedsReviewCount, 0)
    }

    func testCheckMatchesOnlySendsPlaylistSongsToMatcher() async throws {
        let snapshot = BackupSnapshot(
            createdAt: Date(timeIntervalSince1970: 0),
            source: SnapshotSource(appVersion: "0.3.0"),
            songs: [
                BackupSong(
                    id: "playlist-song",
                    title: "Playlist Song",
                    artistName: "Artist"
                ),
                BackupSong(
                    id: "library-only-song",
                    title: "Library Only",
                    artistName: "Artist"
                )
            ],
            playlists: [
                BackupPlaylist(
                    id: "playlist-1",
                    name: "Favorites",
                    tracks: [
                        BackupPlaylistTrack(
                            playlistID: "playlist-1",
                            songID: "playlist-song",
                            position: 0,
                            snapshotOrder: 0
                        )
                    ]
                )
            ]
        )
        let matcher = RecordingLiveMatcher()
        let model = RestorePreviewViewModel(
            snapshotStore: FakeSnapshotLoader(snapshot: snapshot),
            matcher: matcher
        )

        await model.checkMatches(fileName: "backup.json", permissionStatus: .authorized)

        XCTAssertEqual(matcher.receivedSongIDs, ["playlist-song"])
    }

    func testLoadReportsSnapshotFailure() async {
        let model = RestorePreviewViewModel(
            snapshotStore: FailingSnapshotLoader(),
            matcher: FakeLiveMatcher(matches: [:])
        )

        await model.load(fileName: "missing.json")

        guard case .failed(let message) = model.state else {
            return XCTFail("Expected load failure state.")
        }
        XCTAssertEqual(message, "Snapshot unavailable")
    }

    func testCheckMatchesReportsMatcherFailure() async {
        let model = RestorePreviewViewModel(
            snapshotStore: FakeSnapshotLoader(snapshot: makeSnapshot()),
            matcher: ThrowingLiveMatcher()
        )

        await model.checkMatches(fileName: "backup.json", permissionStatus: .authorized)

        guard case .failed(let message) = model.state else {
            return XCTFail("Expected matcher failure state.")
        }
        XCTAssertEqual(message, "Apple Music unavailable")
    }

    private func makeSnapshot() -> BackupSnapshot {
        BackupSnapshot(
            createdAt: Date(timeIntervalSince1970: 0),
            source: SnapshotSource(appVersion: "0.3.0"),
            songs: [
                BackupSong(
                    id: "song-1",
                    identifiers: MusicItemIdentifiers(libraryID: "library-1"),
                    title: "Song",
                    artistName: "Artist"
                )
            ],
            playlists: [
                BackupPlaylist(
                    id: "playlist-1",
                    name: "Favorites",
                    tracks: [
                        BackupPlaylistTrack(
                            playlistID: "playlist-1",
                            songID: "song-1",
                            position: 0,
                            snapshotOrder: 0
                        )
                    ]
                )
            ]
        )
    }
}

private struct FakeSnapshotLoader: SnapshotLoading {
    var snapshot: BackupSnapshot

    func loadSnapshot(fileName: String) throws -> SavedSnapshot {
        let url = URL(fileURLWithPath: "/tmp/\(fileName)")
        return SavedSnapshot(
            snapshot: snapshot,
            fileURL: url,
            manifest: SnapshotManifest(snapshot: snapshot, fileName: fileName)
        )
    }
}

private struct FailingSnapshotLoader: SnapshotLoading {
    func loadSnapshot(fileName: String) throws -> SavedSnapshot {
        throw FakeRestorePreviewError.snapshotUnavailable
    }
}

private struct FakeLiveMatcher: LiveMusicTrackMatching {
    var matches: [String: LiveMusicTrackMatch]

    func matchTracks(for songs: [BackupSong]) async throws -> [String: LiveMusicTrackMatch] {
        matches
    }
}

private struct FailingLiveMatcher: LiveMusicTrackMatching {
    func matchTracks(for songs: [BackupSong]) async throws -> [String: LiveMusicTrackMatch] {
        XCTFail("Matcher should not run without Apple Music permission.")
        return [:]
    }
}

private struct ThrowingLiveMatcher: LiveMusicTrackMatching {
    func matchTracks(for songs: [BackupSong]) async throws -> [String: LiveMusicTrackMatch] {
        throw FakeRestorePreviewError.appleMusicUnavailable
    }
}

private final class RecordingLiveMatcher: LiveMusicTrackMatching {
    private(set) var receivedSongIDs: [String] = []

    func matchTracks(for songs: [BackupSong]) async throws -> [String: LiveMusicTrackMatch] {
        receivedSongIDs = songs.map(\.id)
        return [:]
    }
}

private enum FakeRestorePreviewError: LocalizedError {
    case snapshotUnavailable
    case appleMusicUnavailable

    var errorDescription: String? {
        switch self {
        case .snapshotUnavailable:
            return "Snapshot unavailable"
        case .appleMusicUnavailable:
            return "Apple Music unavailable"
        }
    }
}
