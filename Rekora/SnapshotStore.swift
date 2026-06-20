import Foundation

struct SavedSnapshot: Equatable {
    var snapshot: BackupSnapshot
    var fileURL: URL
    var manifest: SnapshotManifest

    var fileName: String {
        fileURL.lastPathComponent
    }
}

struct SnapshotManifest: Codable, Equatable, Sendable {
    var latestSnapshotFileName: String
    var createdAt: Date
    var songCount: Int
    var albumCount: Int
    var playlistCount: Int
    var playlistTrackCount: Int
    var playlistOrderWarningCount: Int
    var schemaVersion: Int

    init(snapshot: BackupSnapshot, fileName: String) {
        self.latestSnapshotFileName = fileName
        self.createdAt = snapshot.createdAt
        self.songCount = snapshot.songs.count
        self.albumCount = snapshot.albums.count
        self.playlistCount = snapshot.playlists.count
        self.playlistTrackCount = snapshot.playlists.reduce(0) { count, playlist in
            count + playlist.tracks.count
        }
        self.playlistOrderWarningCount = Self.playlistOrderWarningCount(in: snapshot)
        self.schemaVersion = snapshot.schemaVersion
    }

    init(
        latestSnapshotFileName: String,
        createdAt: Date,
        songCount: Int,
        albumCount: Int,
        playlistCount: Int,
        playlistTrackCount: Int = 0,
        playlistOrderWarningCount: Int = 0,
        schemaVersion: Int
    ) {
        self.latestSnapshotFileName = latestSnapshotFileName
        self.createdAt = createdAt
        self.songCount = songCount
        self.albumCount = albumCount
        self.playlistCount = playlistCount
        self.playlistTrackCount = playlistTrackCount
        self.playlistOrderWarningCount = playlistOrderWarningCount
        self.schemaVersion = schemaVersion
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.latestSnapshotFileName = try container.decode(String.self, forKey: .latestSnapshotFileName)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.songCount = try container.decode(Int.self, forKey: .songCount)
        self.albumCount = try container.decode(Int.self, forKey: .albumCount)
        self.playlistCount = try container.decode(Int.self, forKey: .playlistCount)
        self.playlistTrackCount = try container.decodeIfPresent(Int.self, forKey: .playlistTrackCount) ?? 0
        self.playlistOrderWarningCount =
            try container.decodeIfPresent(Int.self, forKey: .playlistOrderWarningCount) ?? 0
        self.schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
    }

    static func playlistOrderWarningCount(in snapshot: BackupSnapshot) -> Int {
        snapshot.playlists.filter { playlist in
            let positions = playlist.tracks.map(\.position)

            guard positions.count > 1 else {
                return false
            }

            return positions != Array(0..<positions.count)
        }.count
    }
}

struct SnapshotExport: Equatable {
    var fileName: String
    var data: Data
}

enum SnapshotStoreError: Error, Equatable {
    case missingSnapshot(String)
}

struct SnapshotStore {
    static let latestManifestFileName = "latest-backup.json"
    static let fileProtection: FileProtectionType = .complete

    private let fileManager: FileManager
    private let snapshotsDirectoryOverride: URL?

    init(fileManager: FileManager = .default, snapshotsDirectory: URL? = nil) {
        self.fileManager = fileManager
        self.snapshotsDirectoryOverride = snapshotsDirectory
    }

    var snapshotsDirectory: URL {
        get throws {
            if let snapshotsDirectoryOverride {
                return snapshotsDirectoryOverride
            }

            let documentsDirectory = try fileManager.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )

            return documentsDirectory.appendingPathComponent("Snapshots", isDirectory: true)
        }
    }

    func save(_ snapshot: BackupSnapshot) throws -> SavedSnapshot {
        let directory = try snapshotsDirectory
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let fileURL = directory.appendingPathComponent(Self.fileName(for: snapshot))
        let data = try BackupSnapshotCoding.makeEncoder().encode(snapshot)
        try data.write(to: fileURL, options: [.atomic])
        try protectFile(at: fileURL)

        let manifest = SnapshotManifest(snapshot: snapshot, fileName: fileURL.lastPathComponent)
        let manifestData = try BackupSnapshotCoding.makeEncoder().encode(manifest)
        let manifestURL = latestManifestURL(in: directory)
        try manifestData.write(to: manifestURL, options: [.atomic])
        try protectFile(at: manifestURL)

        return SavedSnapshot(snapshot: snapshot, fileURL: fileURL, manifest: manifest)
    }

    func loadLatestManifest() throws -> SnapshotManifest? {
        let directory = try snapshotsDirectory
        let fileURL = latestManifestURL(in: directory)

        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: fileURL)
        return try BackupSnapshotCoding.makeDecoder().decode(SnapshotManifest.self, from: data)
    }

    func loadLatestSnapshotExport() throws -> SnapshotExport? {
        let directory = try snapshotsDirectory

        guard let manifest = try loadLatestManifest() else {
            return nil
        }

        let snapshotURL = directory.appendingPathComponent(manifest.latestSnapshotFileName)
        let data = try Data(contentsOf: snapshotURL)

        return SnapshotExport(
            fileName: Self.exportFileName(for: manifest.createdAt),
            data: data
        )
    }

    func listSnapshots() throws -> [SavedSnapshot] {
        let directory = try snapshotsDirectory

        guard fileManager.fileExists(atPath: directory.path) else {
            return []
        }

        let fileURLs = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )

        return try fileURLs
            .filter(Self.isSnapshotFile)
            .map { try loadSnapshot(fileName: $0.lastPathComponent) }
            .sorted { first, second in
                if first.snapshot.createdAt == second.snapshot.createdAt {
                    return first.fileName < second.fileName
                }
                return first.snapshot.createdAt < second.snapshot.createdAt
            }
    }

    func loadSnapshot(fileName: String) throws -> SavedSnapshot {
        let directory = try snapshotsDirectory
        let fileURL = directory.appendingPathComponent(fileName)

        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw SnapshotStoreError.missingSnapshot(fileName)
        }

        let data = try Data(contentsOf: fileURL)
        let snapshot = try BackupSnapshotCoding.makeDecoder().decode(BackupSnapshot.self, from: data)
        let manifest = SnapshotManifest(snapshot: snapshot, fileName: fileName)

        return SavedSnapshot(snapshot: snapshot, fileURL: fileURL, manifest: manifest)
    }

    func loadLatestSnapshot() throws -> SavedSnapshot? {
        guard let manifest = try loadLatestManifest() else {
            return nil
        }

        return try loadSnapshot(fileName: manifest.latestSnapshotFileName)
    }

    func loadPreviousSnapshot(before manifest: SnapshotManifest) throws -> SavedSnapshot? {
        let snapshots = try listSnapshots()

        if let index = snapshots.firstIndex(where: { $0.fileName == manifest.latestSnapshotFileName }) {
            guard index > snapshots.startIndex else {
                return nil
            }

            return snapshots[snapshots.index(before: index)]
        }

        return snapshots.last { $0.snapshot.createdAt < manifest.createdAt }
    }

    static func fileName(for snapshot: BackupSnapshot) -> String {
        "rekora-snapshot-\(fileDateFormatter.string(from: snapshot.createdAt)).json"
    }

    static func exportFileName(for createdAt: Date) -> String {
        exportFileName(for: createdAt, timeZone: .current)
    }

    static func exportFileName(for createdAt: Date, timeZone: TimeZone) -> String {
        let formatter = makeExportDateFormatter(timeZone: timeZone)
        return "Rekora Backup - \(formatter.string(from: createdAt))"
    }

    private func latestManifestURL(in directory: URL) -> URL {
        directory.appendingPathComponent(Self.latestManifestFileName)
    }

    private static func isSnapshotFile(_ fileURL: URL) -> Bool {
        let fileName = fileURL.lastPathComponent
        return fileName.hasPrefix("rekora-snapshot-") && fileName.hasSuffix(".json")
    }

    private func protectFile(at fileURL: URL) throws {
        try fileManager.setAttributes(
            [.protectionKey: Self.fileProtection],
            ofItemAtPath: fileURL.path
        )
    }

    private static let fileDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HHmmss'Z'"
        return formatter
    }()

    private static func makeExportDateFormatter(timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd 'at' h-mm a"
        return formatter
    }
}
