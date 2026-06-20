import Foundation

struct BackupSnapshot: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1
    static let formatIdentifier = "rekora.backup.snapshot"

    var format: String
    var schemaVersion: Int
    var snapshotID: UUID
    var createdAt: Date
    var source: SnapshotSource
    var songs: [BackupSong]
    var albums: [BackupAlbum]
    var playlists: [BackupPlaylist]

    init(
        format: String = Self.formatIdentifier,
        schemaVersion: Int = Self.currentSchemaVersion,
        snapshotID: UUID = UUID(),
        createdAt: Date = Date(),
        source: SnapshotSource,
        songs: [BackupSong] = [],
        albums: [BackupAlbum] = [],
        playlists: [BackupPlaylist] = []
    ) {
        self.format = format
        self.schemaVersion = schemaVersion
        self.snapshotID = snapshotID
        self.createdAt = createdAt
        self.source = source
        self.songs = songs
        self.albums = albums
        self.playlists = playlists
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if container.contains(.format) {
            if try container.decodeNil(forKey: .format) {
                throw DecodingError.dataCorruptedError(
                    forKey: .format,
                    in: container,
                    debugDescription: "Backup format marker cannot be null."
                )
            }
            self.format = try container.decode(String.self, forKey: .format)
        } else {
            self.format = Self.formatIdentifier
        }
        self.schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        self.snapshotID = try container.decode(UUID.self, forKey: .snapshotID)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.source = try container.decode(SnapshotSource.self, forKey: .source)
        self.songs = try container.decode([BackupSong].self, forKey: .songs)
        self.albums = try container.decode([BackupAlbum].self, forKey: .albums)
        self.playlists = try container.decode([BackupPlaylist].self, forKey: .playlists)
    }

    enum CodingKeys: String, CodingKey {
        case format
        case schemaVersion
        case snapshotID
        case createdAt
        case source
        case songs
        case albums
        case playlists
    }
}

struct SnapshotSource: Codable, Equatable, Sendable {
    var appVersion: String
    var platform: String
    var storefrontID: String?

    init(appVersion: String, platform: String = "iOS", storefrontID: String? = nil) {
        self.appVersion = appVersion
        self.platform = platform
        self.storefrontID = storefrontID
    }
}

struct BackupSong: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var identifiers: MusicItemIdentifiers
    var libraryStatus: BackupSongLibraryStatus
    var title: String
    var artistName: String
    var albumTitle: String?
    var albumArtistName: String?
    var durationMilliseconds: Int?
    var trackNumber: Int?
    var discNumber: Int?

    init(
        id: String,
        identifiers: MusicItemIdentifiers = MusicItemIdentifiers(),
        libraryStatus: BackupSongLibraryStatus = .unknown,
        title: String,
        artistName: String,
        albumTitle: String? = nil,
        albumArtistName: String? = nil,
        durationMilliseconds: Int? = nil,
        trackNumber: Int? = nil,
        discNumber: Int? = nil
    ) {
        self.id = id
        self.identifiers = identifiers
        self.libraryStatus = libraryStatus
        self.title = title
        self.artistName = artistName
        self.albumTitle = albumTitle
        self.albumArtistName = albumArtistName
        self.durationMilliseconds = durationMilliseconds
        self.trackNumber = trackNumber
        self.discNumber = discNumber
    }
}

enum BackupSongLibraryStatus: String, Codable, Equatable, Sendable {
    case saved
    case playlistOnly
    case unknown
}

struct BackupAlbum: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var identifiers: MusicItemIdentifiers
    var title: String
    var artistName: String
    var releaseYear: Int?
    var songIDs: [String]

    init(
        id: String,
        identifiers: MusicItemIdentifiers = MusicItemIdentifiers(),
        title: String,
        artistName: String,
        releaseYear: Int? = nil,
        songIDs: [String] = []
    ) {
        self.id = id
        self.identifiers = identifiers
        self.title = title
        self.artistName = artistName
        self.releaseYear = releaseYear
        self.songIDs = songIDs
    }
}

struct BackupPlaylist: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var identifiers: MusicItemIdentifiers
    var name: String
    var description: String?
    var tracks: [BackupPlaylistTrack]

    init(
        id: String,
        identifiers: MusicItemIdentifiers = MusicItemIdentifiers(),
        name: String,
        description: String? = nil,
        tracks: [BackupPlaylistTrack] = []
    ) {
        self.id = id
        self.identifiers = identifiers
        self.name = name
        self.description = description
        self.tracks = tracks
    }
}

struct BackupPlaylistTrack: Codable, Equatable, Identifiable, Sendable {
    var id: String { "\(playlistID):\(snapshotOrder ?? position)" }

    var playlistID: String
    var songID: String
    var position: Int
    var snapshotOrder: Int?
    var addedAt: Date?

    init(
        playlistID: String,
        songID: String,
        position: Int,
        snapshotOrder: Int? = nil,
        addedAt: Date? = nil
    ) {
        self.playlistID = playlistID
        self.songID = songID
        self.position = position
        self.snapshotOrder = snapshotOrder
        self.addedAt = addedAt
    }
}

struct MusicItemIdentifiers: Codable, Equatable, Sendable {
    var libraryID: String?
    var catalogID: String?
    var appleMusicID: String?
    var isrc: String?

    init(
        libraryID: String? = nil,
        catalogID: String? = nil,
        appleMusicID: String? = nil,
        isrc: String? = nil
    ) {
        self.libraryID = libraryID
        self.catalogID = catalogID
        self.appleMusicID = appleMusicID
        self.isrc = isrc
    }
}

enum BackupSnapshotCoding {
    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
