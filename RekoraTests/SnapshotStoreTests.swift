import XCTest
@testable import Rekora

final class SnapshotStoreTests: XCTestCase {
    func testSaveCreatesJSONFileThatDecodesToSnapshot() throws {
        let directory = temporaryDirectory()
        let store = SnapshotStore(snapshotsDirectory: directory)
        let createdAt = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-05-25T18:30:00Z"))
        let snapshot = SampleSnapshotFactory.makeSnapshot(createdAt: createdAt)

        let savedSnapshot = try store.save(snapshot)
        let data = try Data(contentsOf: savedSnapshot.fileURL)
        let decoded = try BackupSnapshotCoding.makeDecoder().decode(BackupSnapshot.self, from: data)

        XCTAssertTrue(FileManager.default.fileExists(atPath: savedSnapshot.fileURL.path))
        XCTAssertEqual(savedSnapshot.fileName, "rekora-snapshot-2026-05-25T183000Z.json")
        XCTAssertEqual(decoded, snapshot)
        XCTAssertEqual(decoded.schemaVersion, 1)
    }

    func testSnapshotDirectoryIsCreatedWhenMissing() throws {
        let directory = temporaryDirectory().appendingPathComponent("Nested/Snapshots", isDirectory: true)
        let store = SnapshotStore(snapshotsDirectory: directory)
        let snapshot = SampleSnapshotFactory.makeSnapshot()

        _ = try store.save(snapshot)

        var isDirectory: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
    }

    func testSaveWritesLatestManifest() throws {
        let directory = temporaryDirectory()
        let store = SnapshotStore(snapshotsDirectory: directory)
        let createdAt = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-05-25T18:30:00Z"))
        let snapshot = SampleSnapshotFactory.makeSnapshot(createdAt: createdAt)

        let savedSnapshot = try store.save(snapshot)
        let manifest = try XCTUnwrap(store.loadLatestManifest())

        XCTAssertEqual(manifest, savedSnapshot.manifest)
        XCTAssertEqual(manifest.latestSnapshotFileName, "rekora-snapshot-2026-05-25T183000Z.json")
        XCTAssertEqual(manifest.createdAt, createdAt)
        XCTAssertEqual(manifest.songCount, 1)
        XCTAssertEqual(manifest.albumCount, 1)
        XCTAssertEqual(manifest.playlistCount, 1)
        XCTAssertEqual(manifest.playlistTrackCount, 1)
        XCTAssertEqual(manifest.playlistOrderWarningCount, 0)
        XCTAssertEqual(manifest.schemaVersion, 1)
    }

    func testManifestCountsPlaylistsWithSuspiciousReportedOrder() throws {
        let directory = temporaryDirectory()
        let store = SnapshotStore(snapshotsDirectory: directory)
        let snapshot = BackupSnapshot(
            source: SnapshotSource(appVersion: "0.1.0"),
            songs: [
                BackupSong(id: "song-a", title: "First", artistName: "Artist"),
                BackupSong(id: "song-b", title: "Second", artistName: "Artist"),
                BackupSong(id: "song-c", title: "Third", artistName: "Artist")
            ],
            playlists: [
                BackupPlaylist(
                    id: "valid-playlist",
                    name: "Valid",
                    tracks: [
                        BackupPlaylistTrack(
                            playlistID: "valid-playlist",
                            songID: "song-a",
                            position: 0,
                            snapshotOrder: 0
                        ),
                        BackupPlaylistTrack(
                            playlistID: "valid-playlist",
                            songID: "song-b",
                            position: 1,
                            snapshotOrder: 1
                        )
                    ]
                ),
                BackupPlaylist(
                    id: "all-zero-playlist",
                    name: "All Zero",
                    tracks: [
                        BackupPlaylistTrack(
                            playlistID: "all-zero-playlist",
                            songID: "song-a",
                            position: 0,
                            snapshotOrder: 0
                        ),
                        BackupPlaylistTrack(
                            playlistID: "all-zero-playlist",
                            songID: "song-c",
                            position: 0,
                            snapshotOrder: 1
                        )
                    ]
                )
            ]
        )

        _ = try store.save(snapshot)
        let manifest = try XCTUnwrap(store.loadLatestManifest())

        XCTAssertEqual(manifest.playlistOrderWarningCount, 1)
    }

    func testLoadLatestSnapshotExportReturnsLatestSnapshotData() throws {
        let directory = temporaryDirectory()
        let store = SnapshotStore(snapshotsDirectory: directory)
        let createdAt = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-05-25T18:30:00Z"))
        let snapshot = SampleSnapshotFactory.makeSnapshot(createdAt: createdAt)

        _ = try store.save(snapshot)
        let export = try XCTUnwrap(store.loadLatestSnapshotExport())
        let decoded = try BackupSnapshotCoding.makeDecoder().decode(BackupSnapshot.self, from: export.data)

        XCTAssertEqual(export.fileName, SnapshotStore.exportFileName(for: createdAt))
        XCTAssertEqual(decoded, snapshot)
    }

    func testListSnapshotsReturnsSavedSnapshotsInCreatedOrder() throws {
        let directory = temporaryDirectory()
        let store = SnapshotStore(snapshotsDirectory: directory)
        let olderDate = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-05-25T18:30:00Z"))
        let newerDate = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-05-26T18:30:00Z"))
        let older = SampleSnapshotFactory.makeSnapshot(createdAt: olderDate)
        let newer = SampleSnapshotFactory.makeSnapshot(createdAt: newerDate)

        _ = try store.save(newer)
        _ = try store.save(older)
        try Data("not a snapshot".utf8).write(to: directory.appendingPathComponent("notes.json"))

        let snapshots = try store.listSnapshots()

        XCTAssertEqual(snapshots.map(\.snapshot.createdAt), [olderDate, newerDate])
        XCTAssertEqual(
            snapshots.map(\.fileName),
            [
                "rekora-snapshot-2026-05-25T183000Z.json",
                "rekora-snapshot-2026-05-26T183000Z.json"
            ]
        )
    }

    func testLoadLatestSnapshotReturnsFullSnapshotForLatestManifest() throws {
        let directory = temporaryDirectory()
        let store = SnapshotStore(snapshotsDirectory: directory)
        let older = SampleSnapshotFactory.makeSnapshot(
            createdAt: try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-05-25T18:30:00Z"))
        )
        let newer = SampleSnapshotFactory.makeSnapshot(
            createdAt: try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-05-26T18:30:00Z"))
        )

        _ = try store.save(older)
        let savedNewer = try store.save(newer)
        let latest = try XCTUnwrap(store.loadLatestSnapshot())

        XCTAssertEqual(latest, savedNewer)
    }

    func testLoadPreviousSnapshotFindsSnapshotBeforeManifest() throws {
        let directory = temporaryDirectory()
        let store = SnapshotStore(snapshotsDirectory: directory)
        let oldest = SampleSnapshotFactory.makeSnapshot(
            createdAt: try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-05-25T18:30:00Z"))
        )
        let middle = SampleSnapshotFactory.makeSnapshot(
            createdAt: try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-05-26T18:30:00Z"))
        )
        let newest = SampleSnapshotFactory.makeSnapshot(
            createdAt: try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-05-27T18:30:00Z"))
        )

        _ = try store.save(oldest)
        let savedMiddle = try store.save(middle)
        let savedNewest = try store.save(newest)

        let previous = try XCTUnwrap(store.loadPreviousSnapshot(before: savedNewest.manifest))

        XCTAssertEqual(previous, savedMiddle)
    }

    func testLoadPreviousSnapshotIsNilForFirstSnapshot() throws {
        let directory = temporaryDirectory()
        let store = SnapshotStore(snapshotsDirectory: directory)
        let snapshot = SampleSnapshotFactory.makeSnapshot(
            createdAt: try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-05-25T18:30:00Z"))
        )

        let savedSnapshot = try store.save(snapshot)

        XCTAssertNil(try store.loadPreviousSnapshot(before: savedSnapshot.manifest))
    }

    func testExportFileNameUsesFriendlyLocalTimestamp() throws {
        let createdAt = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-06-07T00:44:50Z"))
        let timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))

        XCTAssertEqual(
            SnapshotStore.exportFileName(for: createdAt, timeZone: timeZone),
            "Rekora Backup - 2026-06-06 at 8-44 PM"
        )
    }

    func testLatestSnapshotExportIsNilBeforeFirstSnapshot() throws {
        let store = SnapshotStore(snapshotsDirectory: temporaryDirectory())

        XCTAssertNil(try store.loadLatestSnapshotExport())
    }

    func testSaveAppliesFileProtectionToSnapshotAndManifest() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("The iOS Simulator does not expose file protection attributes reliably.")
        #else
        let directory = temporaryDirectory()
        let store = SnapshotStore(snapshotsDirectory: directory)
        let snapshot = SampleSnapshotFactory.makeSnapshot()

        let savedSnapshot = try store.save(snapshot)
        let manifestURL = directory.appendingPathComponent(SnapshotStore.latestManifestFileName)

        XCTAssertEqual(
            try protectionValue(at: savedSnapshot.fileURL),
            SnapshotStore.fileProtection
        )
        XCTAssertEqual(
            try protectionValue(at: manifestURL),
            SnapshotStore.fileProtection
        )
        #endif
    }

    func testLatestManifestIsNilBeforeFirstSnapshot() throws {
        let store = SnapshotStore(snapshotsDirectory: temporaryDirectory())

        XCTAssertNil(try store.loadLatestManifest())
    }

    func testLatestManifestLoadsWithoutDecodingSnapshotFile() throws {
        let directory = temporaryDirectory()
        let store = SnapshotStore(snapshotsDirectory: directory)
        let createdAt = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-05-25T18:30:00Z"))
        let snapshot = SampleSnapshotFactory.makeSnapshot(createdAt: createdAt)

        let savedSnapshot = try store.save(snapshot)
        try Data("not a snapshot".utf8).write(to: savedSnapshot.fileURL, options: [.atomic])

        let manifest = try XCTUnwrap(store.loadLatestManifest())

        XCTAssertEqual(manifest.latestSnapshotFileName, savedSnapshot.fileName)
        XCTAssertEqual(manifest.createdAt, createdAt)
        XCTAssertEqual(manifest.songCount, 1)
    }

    func testLatestManifestDefaultsPlaylistTrackCountForOlderManifests() throws {
        let directory = temporaryDirectory()
        let store = SnapshotStore(snapshotsDirectory: directory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let manifestURL = directory.appendingPathComponent(SnapshotStore.latestManifestFileName)
        let manifestJSON = """
        {
          "latestSnapshotFileName" : "rekora-snapshot-2026-05-25T183000Z.json",
          "createdAt" : "2026-05-25T18:30:00Z",
          "songCount" : 1,
          "albumCount" : 1,
          "playlistCount" : 1,
          "schemaVersion" : 1
        }
        """
        try Data(manifestJSON.utf8).write(to: manifestURL, options: [.atomic])

        let manifest = try XCTUnwrap(store.loadLatestManifest())

        XCTAssertEqual(manifest.playlistTrackCount, 0)
        XCTAssertEqual(manifest.playlistOrderWarningCount, 0)
    }

    func testFileNameUsesSafeTimestamp() throws {
        let createdAt = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-05-25T18:30:00Z"))
        let snapshot = SampleSnapshotFactory.makeSnapshot(createdAt: createdAt)

        XCTAssertEqual(
            SnapshotStore.fileName(for: snapshot),
            "rekora-snapshot-2026-05-25T183000Z.json"
        )
        XCTAssertFalse(SnapshotStore.fileName(for: snapshot).contains(":"))
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("RekoraTests-\(UUID().uuidString)", isDirectory: true)
    }

    private func protectionValue(at fileURL: URL) throws -> FileProtectionType? {
        try FileManager.default.attributesOfItem(atPath: fileURL.path)[.protectionKey] as? FileProtectionType
    }
}
