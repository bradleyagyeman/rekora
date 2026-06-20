import XCTest
@testable import Rekora

final class SnapshotDiffTests: XCTestCase {
    func testDiffReportsAddedAndRemovedSongs() throws {
        let older = snapshot(
            songs: [
                song("song-a", title: "A", libraryID: "library-a"),
                song("song-b", title: "B", libraryID: "library-b")
            ]
        )
        let newer = snapshot(
            songs: [
                song("song-b-renamed", title: "B", libraryID: "library-b"),
                song("song-c", title: "C", libraryID: "library-c")
            ]
        )

        let diff = SnapshotDiff.compare(older: older, newer: newer)

        XCTAssertEqual(diff.addedSongs.map(\.id), ["song-c"])
        XCTAssertEqual(diff.removedSongs.map(\.id), ["song-a"])
        XCTAssertTrue(diff.hasChanges)
    }

    func testDiffReportsAddedAndRemovedPlaylists() throws {
        let older = snapshot(
            playlists: [
                playlist("playlist-a", name: "Morning", libraryID: "library-playlist-a"),
                playlist("playlist-b", name: "Evening", libraryID: "library-playlist-b")
            ]
        )
        let newer = snapshot(
            playlists: [
                playlist("playlist-b-renamed", name: "Evening", libraryID: "library-playlist-b"),
                playlist("playlist-c", name: "Night", libraryID: "library-playlist-c")
            ]
        )

        let diff = SnapshotDiff.compare(older: older, newer: newer)

        XCTAssertEqual(diff.addedPlaylists.map(\.name), ["Night"])
        XCTAssertEqual(diff.removedPlaylists.map(\.name), ["Morning"])
    }

    func testDiffReportsPlaylistTrackAdditionsAndRemovals() throws {
        let older = snapshot(
            songs: [
                song("song-a", title: "A", libraryID: "library-a"),
                song("song-b", title: "B", libraryID: "library-b")
            ],
            playlists: [
                playlist(
                    "playlist-1",
                    name: "Favorites",
                    tracks: [
                        track(playlistID: "playlist-1", songID: "song-a", order: 0),
                        track(playlistID: "playlist-1", songID: "song-b", order: 1)
                    ]
                )
            ]
        )
        let newer = snapshot(
            songs: [
                song("song-b", title: "B", libraryID: "library-b"),
                song("song-c", title: "C", libraryID: "library-c")
            ],
            playlists: [
                playlist(
                    "playlist-1",
                    name: "Favorites",
                    tracks: [
                        track(playlistID: "playlist-1", songID: "song-b", order: 0),
                        track(playlistID: "playlist-1", songID: "song-c", order: 1)
                    ]
                )
            ]
        )

        let diff = SnapshotDiff.compare(older: older, newer: newer)
        let playlistDiff = try XCTUnwrap(diff.changedPlaylists.first)

        XCTAssertEqual(playlistDiff.name, "Favorites")
        XCTAssertEqual(playlistDiff.addedTracks.map(\.songID), ["song-c"])
        XCTAssertEqual(playlistDiff.removedTracks.map(\.songID), ["song-a"])
        XCTAssertFalse(playlistDiff.orderChanged)
        XCTAssertEqual(diff.playlistTrackAddedCount, 1)
        XCTAssertEqual(diff.playlistTrackRemovedCount, 1)
    }

    func testDiffDetectsPlaylistOrderChangeUsingSnapshotOrderWhenPositionsAreInvalid() throws {
        let songs = [
            song("song-a", title: "A", libraryID: "library-a"),
            song("song-b", title: "B", libraryID: "library-b")
        ]
        let older = snapshot(
            songs: songs,
            playlists: [
                playlist(
                    "playlist-1",
                    name: "Favorites",
                    tracks: [
                        track(playlistID: "playlist-1", songID: "song-a", position: 0, snapshotOrder: 0),
                        track(playlistID: "playlist-1", songID: "song-b", position: 0, snapshotOrder: 1)
                    ]
                )
            ]
        )
        let newer = snapshot(
            songs: songs,
            playlists: [
                playlist(
                    "playlist-1",
                    name: "Favorites",
                    tracks: [
                        track(playlistID: "playlist-1", songID: "song-b", position: 0, snapshotOrder: 0),
                        track(playlistID: "playlist-1", songID: "song-a", position: 0, snapshotOrder: 1)
                    ]
                )
            ]
        )

        let diff = SnapshotDiff.compare(older: older, newer: newer)
        let playlistDiff = try XCTUnwrap(diff.changedPlaylists.first)

        XCTAssertTrue(playlistDiff.orderChanged)
        XCTAssertTrue(playlistDiff.addedTracks.isEmpty)
        XCTAssertTrue(playlistDiff.removedTracks.isEmpty)
        XCTAssertEqual(diff.playlistOrderChangeCount, 1)
    }

    func testDiffUsesValidReportedPositionsWhenSnapshotOrderIsMissing() throws {
        let songs = [
            song("song-a", title: "A", libraryID: "library-a"),
            song("song-b", title: "B", libraryID: "library-b")
        ]
        let older = snapshot(
            songs: songs,
            playlists: [
                playlist(
                    "playlist-1",
                    name: "Favorites",
                    tracks: [
                        track(playlistID: "playlist-1", songID: "song-b", position: 1),
                        track(playlistID: "playlist-1", songID: "song-a", position: 0)
                    ]
                )
            ]
        )
        let newer = snapshot(
            songs: songs,
            playlists: [
                playlist(
                    "playlist-1",
                    name: "Favorites",
                    tracks: [
                        track(playlistID: "playlist-1", songID: "song-a", position: 0),
                        track(playlistID: "playlist-1", songID: "song-b", position: 1)
                    ]
                )
            ]
        )

        let diff = SnapshotDiff.compare(older: older, newer: newer)

        XCTAssertFalse(diff.hasChanges)
    }

    func testDiffKeepsDuplicateSongReferencesScopedToEachPlaylist() throws {
        let songs = [
            song("song-a", title: "A", libraryID: "library-a")
        ]
        let older = snapshot(
            songs: songs,
            playlists: [
                playlist(
                    "playlist-1",
                    name: "One",
                    tracks: [
                        track(playlistID: "playlist-1", songID: "song-a", order: 0)
                    ]
                ),
                playlist(
                    "playlist-2",
                    name: "Two",
                    tracks: [
                        track(playlistID: "playlist-2", songID: "song-a", order: 0)
                    ]
                )
            ]
        )
        let newer = snapshot(
            songs: songs,
            playlists: [
                playlist(
                    "playlist-1",
                    name: "One",
                    tracks: [
                        track(playlistID: "playlist-1", songID: "song-a", order: 0),
                        track(playlistID: "playlist-1", songID: "song-a", order: 1)
                    ]
                ),
                playlist(
                    "playlist-2",
                    name: "Two",
                    tracks: [
                        track(playlistID: "playlist-2", songID: "song-a", order: 0)
                    ]
                )
            ]
        )

        let diff = SnapshotDiff.compare(older: older, newer: newer)

        XCTAssertEqual(diff.changedPlaylists.map(\.name), ["One"])
        XCTAssertEqual(diff.playlistTrackAddedCount, 1)
    }

    func testDiffReportsNoChangesForEquivalentSnapshots() throws {
        let backup = snapshot(
            songs: [
                song("song-a", title: "A", libraryID: "library-a")
            ],
            playlists: [
                playlist(
                    "playlist-1",
                    name: "Favorites",
                    tracks: [
                        track(playlistID: "playlist-1", songID: "song-a", order: 0)
                    ]
                )
            ]
        )

        let diff = SnapshotDiff.compare(older: backup, newer: backup)

        XCTAssertFalse(diff.hasChanges)
    }

    private func snapshot(
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
        libraryID: String
    ) -> BackupSong {
        BackupSong(
            id: id,
            identifiers: MusicItemIdentifiers(libraryID: libraryID),
            libraryStatus: .saved,
            title: title,
            artistName: "Artist"
        )
    }

    private func playlist(
        _ id: String,
        name: String,
        libraryID: String? = nil,
        tracks: [BackupPlaylistTrack] = []
    ) -> BackupPlaylist {
        BackupPlaylist(
            id: id,
            identifiers: MusicItemIdentifiers(libraryID: libraryID),
            name: name,
            tracks: tracks
        )
    }

    private func track(
        playlistID: String,
        songID: String,
        order: Int
    ) -> BackupPlaylistTrack {
        track(
            playlistID: playlistID,
            songID: songID,
            position: order,
            snapshotOrder: order
        )
    }

    private func track(
        playlistID: String,
        songID: String,
        position: Int
    ) -> BackupPlaylistTrack {
        BackupPlaylistTrack(
            playlistID: playlistID,
            songID: songID,
            position: position,
            snapshotOrder: nil
        )
    }

    private func track(
        playlistID: String,
        songID: String,
        position: Int,
        snapshotOrder: Int
    ) -> BackupPlaylistTrack {
        BackupPlaylistTrack(
            playlistID: playlistID,
            songID: songID,
            position: position,
            snapshotOrder: snapshotOrder
        )
    }
}
