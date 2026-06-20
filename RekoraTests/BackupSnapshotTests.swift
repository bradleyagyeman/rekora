import XCTest
@testable import Rekora

final class BackupSnapshotTests: XCTestCase {
    func testSnapshotRoundTripsThroughVersionedJSON() throws {
        let createdAt = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-05-24T20:00:00Z"))
        let addedAt = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-05-24T20:01:00Z"))
        let song = BackupSong(
            id: "song-1",
            identifiers: MusicItemIdentifiers(
                libraryID: "library-song-1",
                catalogID: "catalog-song-1",
                appleMusicID: "apple-music-song-1",
                isrc: "USRC17607839"
            ),
            libraryStatus: .saved,
            title: "Test Song",
            artistName: "Test Artist",
            albumTitle: "Test Album",
            albumArtistName: "Test Album Artist",
            durationMilliseconds: 181_000,
            trackNumber: 1,
            discNumber: 1
        )
        let snapshot = BackupSnapshot(
            snapshotID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            createdAt: createdAt,
            source: SnapshotSource(appVersion: "0.1.0", storefrontID: "us"),
            songs: [song],
            albums: [
                BackupAlbum(
                    id: "album-1",
                    identifiers: MusicItemIdentifiers(catalogID: "catalog-album-1"),
                    title: "Test Album",
                    artistName: "Test Album Artist",
                    releaseYear: 1976,
                    songIDs: ["song-1"]
                )
            ],
            playlists: [
                BackupPlaylist(
                    id: "playlist-1",
                    identifiers: MusicItemIdentifiers(libraryID: "library-playlist-1"),
                    name: "Test Playlist",
                    description: "A playlist worth saving.",
                    tracks: [
                        BackupPlaylistTrack(
                            playlistID: "playlist-1",
                            songID: "song-1",
                            position: 0,
                            snapshotOrder: 0,
                            addedAt: addedAt
                        )
                    ]
                )
            ]
        )

        let data = try BackupSnapshotCoding.makeEncoder().encode(snapshot)
        let decoded = try BackupSnapshotCoding.makeDecoder().decode(BackupSnapshot.self, from: data)

        XCTAssertEqual(decoded, snapshot)
        XCTAssertEqual(decoded.format, BackupSnapshot.formatIdentifier)
        XCTAssertEqual(decoded.schemaVersion, 1)
        XCTAssertEqual(decoded.songs[0].libraryStatus, .saved)

        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["format"] as? String, BackupSnapshot.formatIdentifier)
    }

    func testPlaylistTracksPreserveObservedOrderIndependentlyOfSongArrayOrder() {
        let snapshot = BackupSnapshot(
            source: SnapshotSource(appVersion: "0.1.0"),
            songs: [
                BackupSong(id: "song-b", title: "Second Song", artistName: "Artist"),
                BackupSong(id: "song-a", title: "First Song", artistName: "Artist")
            ],
            playlists: [
                BackupPlaylist(
                    id: "playlist-1",
                    name: "Ordered Playlist",
                    tracks: [
                        BackupPlaylistTrack(
                            playlistID: "playlist-1",
                            songID: "song-a",
                            position: 0,
                            snapshotOrder: 0
                        ),
                        BackupPlaylistTrack(
                            playlistID: "playlist-1",
                            songID: "song-b",
                            position: 1,
                            snapshotOrder: 1
                        )
                    ]
                )
            ]
        )

        XCTAssertEqual(snapshot.playlists[0].tracks.map(\.songID), ["song-a", "song-b"])
        XCTAssertEqual(snapshot.playlists[0].tracks.map(\.position), [0, 1])
        XCTAssertEqual(snapshot.playlists[0].tracks.map(\.snapshotOrder), [0, 1])
    }

    func testPlaylistTracksKeepObservedOrderWhenReportedPositionsAreInvalid() throws {
        let snapshot = BackupSnapshot(
            source: SnapshotSource(appVersion: "0.1.0"),
            songs: [
                BackupSong(id: "song-a", title: "First Song", artistName: "Artist"),
                BackupSong(id: "song-b", title: "Second Song", artistName: "Artist"),
                BackupSong(id: "song-c", title: "Third Song", artistName: "Artist")
            ],
            playlists: [
                BackupPlaylist(
                    id: "playlist-1",
                    name: "All Zero Position Playlist",
                    tracks: [
                        BackupPlaylistTrack(
                            playlistID: "playlist-1",
                            songID: "song-a",
                            position: 0,
                            snapshotOrder: 0
                        ),
                        BackupPlaylistTrack(
                            playlistID: "playlist-1",
                            songID: "song-b",
                            position: 0,
                            snapshotOrder: 1
                        ),
                        BackupPlaylistTrack(
                            playlistID: "playlist-1",
                            songID: "song-c",
                            position: 0,
                            snapshotOrder: 2
                        )
                    ]
                )
            ]
        )

        let data = try BackupSnapshotCoding.makeEncoder().encode(snapshot)
        let decoded = try BackupSnapshotCoding.makeDecoder().decode(BackupSnapshot.self, from: data)

        XCTAssertEqual(decoded.playlists[0].tracks.map(\.position), [0, 0, 0])
        XCTAssertEqual(decoded.playlists[0].tracks.map(\.snapshotOrder), [0, 1, 2])
        XCTAssertEqual(decoded.playlists[0].tracks.map(\.songID), ["song-a", "song-b", "song-c"])
    }

    func testPlaylistTracksDecodeOlderBackupsWithoutSnapshotOrder() throws {
        let json = """
        {
          "playlistID" : "playlist-1",
          "position" : 0,
          "songID" : "song-1"
        }
        """

        let data = try XCTUnwrap(json.data(using: .utf8))
        let track = try BackupSnapshotCoding.makeDecoder().decode(BackupPlaylistTrack.self, from: data)

        XCTAssertEqual(track.playlistID, "playlist-1")
        XCTAssertEqual(track.songID, "song-1")
        XCTAssertEqual(track.position, 0)
        XCTAssertNil(track.snapshotOrder)
    }

    func testPlainMetadataWorksWhenAppleIdentifiersAreMissing() {
        let song = BackupSong(
            id: "fallback-song",
            title: "Unknown Catalog Match",
            artistName: "Local Metadata Artist",
            albumTitle: "Local Metadata Album"
        )

        XCTAssertNil(song.identifiers.appleMusicID)
        XCTAssertNil(song.identifiers.isrc)
        XCTAssertEqual(song.libraryStatus, .unknown)
        XCTAssertEqual(song.title, "Unknown Catalog Match")
        XCTAssertEqual(song.artistName, "Local Metadata Artist")
        XCTAssertEqual(song.albumTitle, "Local Metadata Album")
    }

    func testAppleMusicSnapshotFactoryStoresSongsAlbumsAndPlaylistTracks() throws {
        let createdAt = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-05-26T20:15:00Z"))
        let songs = [
            BackupSong(
                id: "song-1",
                identifiers: MusicItemIdentifiers(libraryID: "song-1"),
                libraryStatus: .saved,
                title: "First Song",
                artistName: "Artist"
            )
        ]
        let albums = [
            BackupAlbum(
                id: "album-1",
                identifiers: MusicItemIdentifiers(libraryID: "album-1"),
                title: "Album",
                artistName: "Artist"
            )
        ]
        let playlists = [
            BackupPlaylist(
                id: "playlist-1",
                identifiers: MusicItemIdentifiers(libraryID: "playlist-1"),
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

        let snapshot = AppleMusicBackupSnapshotFactory.makeSnapshot(
            songs: songs,
            albums: albums,
            playlists: playlists,
            createdAt: createdAt,
            appVersion: "0.2.0"
        )

        XCTAssertEqual(snapshot.createdAt, createdAt)
        XCTAssertEqual(snapshot.source.appVersion, "0.2.0")
        XCTAssertEqual(snapshot.songs, songs)
        XCTAssertEqual(snapshot.albums, albums)
        XCTAssertEqual(snapshot.playlists, playlists)
    }

    func testAppleMusicSnapshotFactoryUsesRealPlaylistMetadata() throws {
        let createdAt = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-05-26T20:15:00Z"))
        let snapshot = AppleMusicBackupSnapshotFactory.makeSnapshot(
            playlists: [
                MusicPlaylistSummary(id: "playlist-library-1", name: "Morning"),
                MusicPlaylistSummary(id: "playlist-library-2", name: "Evening")
            ],
            createdAt: createdAt,
            appVersion: "0.2.0"
        )

        XCTAssertEqual(snapshot.createdAt, createdAt)
        XCTAssertEqual(snapshot.source.appVersion, "0.2.0")
        XCTAssertTrue(snapshot.songs.isEmpty)
        XCTAssertTrue(snapshot.albums.isEmpty)
        XCTAssertEqual(snapshot.playlists.map(\.id), ["playlist-library-1", "playlist-library-2"])
        XCTAssertEqual(snapshot.playlists.map(\.name), ["Morning", "Evening"])
        XCTAssertEqual(snapshot.playlists.map(\.identifiers.libraryID), ["playlist-library-1", "playlist-library-2"])
        XCTAssertTrue(snapshot.playlists.allSatisfy { $0.tracks.isEmpty })
    }

    func testImportValidationAcceptsValidBackupContentsRegardlessOfFileName() throws {
        let snapshot = BackupSnapshot(
            snapshotID: UUID(uuidString: "00000000-0000-0000-0000-000000000014")!,
            createdAt: try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-06-08T16:00:00Z")),
            source: SnapshotSource(appVersion: "0.3.0"),
            songs: [
                BackupSong(id: "song-1", title: "First", artistName: "Artist"),
                BackupSong(id: "song-2", title: "Second", artistName: "Artist")
            ],
            albums: [
                BackupAlbum(id: "album-1", title: "Album", artistName: "Artist")
            ],
            playlists: [
                BackupPlaylist(
                    id: "playlist-1",
                    name: "Renamed File Playlist",
                    tracks: [
                        BackupPlaylistTrack(playlistID: "playlist-1", songID: "song-1", position: 0, snapshotOrder: 0),
                        BackupPlaylistTrack(playlistID: "playlist-1", songID: "song-2", position: 1, snapshotOrder: 1)
                    ]
                )
            ]
        )
        let data = try BackupSnapshotCoding.makeEncoder().encode(snapshot)

        let summary = try BackupImportValidator.validate(data: data)

        XCTAssertEqual(summary.snapshotID, snapshot.snapshotID)
        XCTAssertEqual(summary.schemaVersion, 1)
        XCTAssertEqual(summary.songCount, 2)
        XCTAssertEqual(summary.albumCount, 1)
        XCTAssertEqual(summary.playlistCount, 1)
        XCTAssertEqual(summary.playlistTrackCount, 2)
    }

    func testImportValidationAcceptsLegacyV1BackupWithoutFormatMarker() throws {
        let snapshot = BackupSnapshot(
            source: SnapshotSource(appVersion: "0.3.0"),
            songs: [
                BackupSong(id: "song-1", title: "First", artistName: "Artist")
            ]
        )
        let data = try legacyV1DataWithoutFormatMarker(for: snapshot)

        let summary = try BackupImportValidator.validate(data: data)

        XCTAssertEqual(summary.schemaVersion, 1)
        XCTAssertEqual(summary.songCount, 1)
    }

    func testImportValidationRejectsBackupWithWrongFormatMarker() throws {
        let snapshot = BackupSnapshot(
            format: "example.other.backup",
            source: SnapshotSource(appVersion: "0.3.0"),
            songs: [
                BackupSong(id: "song-1", title: "First", artistName: "Artist")
            ]
        )
        let data = try BackupSnapshotCoding.makeEncoder().encode(snapshot)

        XCTAssertThrowsError(try BackupImportValidator.validate(data: data)) { error in
            XCTAssertEqual(error as? BackupImportValidationError, .notRekoraBackup)
        }
    }

    func testImportValidationRejectsNullFormatMarker() throws {
        let data = try XCTUnwrap(
            #"{"format":null,"schemaVersion":1}"#.data(using: .utf8)
        )

        XCTAssertThrowsError(try BackupImportValidator.validate(data: data)) { error in
            XCTAssertEqual(error as? BackupImportValidationError, .notRekoraBackup)
        }
    }

    func testImportValidationRejectsWrongFormatMarkerBeforeUnsupportedSchema() throws {
        let data = try XCTUnwrap(
            #"{"format":"example.other.backup","schemaVersion":999}"#.data(using: .utf8)
        )

        XCTAssertThrowsError(try BackupImportValidator.validate(data: data)) { error in
            XCTAssertEqual(error as? BackupImportValidationError, .notRekoraBackup)
        }
    }

    func testImportValidationReadsRenamedFileWithoutJsonExtension() throws {
        let snapshot = BackupSnapshot(
            source: SnapshotSource(appVersion: "0.3.0"),
            songs: [
                BackupSong(id: "song-1", title: "First", artistName: "Artist")
            ]
        )
        let data = try BackupSnapshotCoding.makeEncoder().encode(snapshot)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("My Music Backup")
        try data.write(to: fileURL)

        let summary = try BackupImportValidator.validate(fileURL: fileURL)

        XCTAssertEqual(summary.songCount, 1)
        XCTAssertEqual(summary.schemaVersion, 1)
    }

    func testImportValidationRejectsOversizedFilesBeforeReading() throws {
        let snapshot = BackupSnapshot(source: SnapshotSource(appVersion: "0.3.0"))
        let data = try BackupSnapshotCoding.makeEncoder().encode(snapshot)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("Large Backup")
        try data.write(to: fileURL)

        XCTAssertThrowsError(
            try BackupImportValidator.validate(fileURL: fileURL, maxFileSizeBytes: 1)
        ) { error in
            XCTAssertEqual(error as? BackupImportValidationError, .fileTooLarge)
        }
    }

    func testImportValidationRejectsJsonThatIsNotARekoraBackup() throws {
        let data = try XCTUnwrap(#"{"name":"My Music Backup"}"#.data(using: .utf8))

        XCTAssertThrowsError(try BackupImportValidator.validate(data: data)) { error in
            XCTAssertEqual(error as? BackupImportValidationError, .notRekoraBackup)
        }
    }

    func testImportValidationRejectsUnsupportedSchemaVersion() throws {
        let data = try XCTUnwrap(#"{"schemaVersion":999}"#.data(using: .utf8))

        XCTAssertThrowsError(try BackupImportValidator.validate(data: data)) { error in
            XCTAssertEqual(error as? BackupImportValidationError, .unsupportedSchemaVersion(999))
        }
    }

    func testImportValidationRejectsCorruptBackupContents() throws {
        let data = try XCTUnwrap(#"{"schemaVersion":1,"songs":[]}"#.data(using: .utf8))

        XCTAssertThrowsError(try BackupImportValidator.validate(data: data)) { error in
            XCTAssertEqual(error as? BackupImportValidationError, .invalidBackup)
        }
    }

    private func legacyV1DataWithoutFormatMarker(for snapshot: BackupSnapshot) throws -> Data {
        let data = try BackupSnapshotCoding.makeEncoder().encode(snapshot)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "format")
        return try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
    }
}
