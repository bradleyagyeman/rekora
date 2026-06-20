import Foundation
import MusicKit

enum AppleMusicBackupSnapshotFactory {
    static func makeSnapshot(
        songs: [BackupSong],
        albums: [BackupAlbum],
        playlists: [BackupPlaylist],
        createdAt: Date = Date(),
        appVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    ) -> BackupSnapshot {
        BackupSnapshot(
            createdAt: createdAt,
            source: SnapshotSource(appVersion: appVersion),
            songs: songs,
            albums: albums,
            playlists: playlists
        )
    }

    static func makeSnapshot(
        playlists: [MusicPlaylistSummary],
        createdAt: Date = Date(),
        appVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    ) -> BackupSnapshot {
        BackupSnapshot(
            createdAt: createdAt,
            source: SnapshotSource(appVersion: appVersion),
            playlists: playlists.map { playlist in
                BackupPlaylist(
                    id: playlist.id,
                    identifiers: MusicItemIdentifiers(libraryID: playlist.id),
                    name: playlist.name
                )
            }
        )
    }
}

protocol AppleMusicBackupProviding {
    func createSnapshot() async throws -> BackupSnapshot
}

struct AppleMusicBackupClient: AppleMusicBackupProviding {
    private let subscriptionProvider: AppleMusicSubscriptionProviding

    init(subscriptionProvider: AppleMusicSubscriptionProviding = AppleMusicSubscriptionClient()) {
        self.subscriptionProvider = subscriptionProvider
    }

    func createSnapshot() async throws -> BackupSnapshot {
        let subscription = try await subscriptionProvider.currentStatus()
        guard subscription.hasCloudLibraryEnabled else {
            throw PlaylistLibraryError.cloudLibraryDisabled
        }

        guard subscription.canPlayCatalogContent else {
            throw PlaylistLibraryError.subscriptionRequired
        }

        async let librarySongs = fetchSongs()
        async let libraryAlbums = fetchAlbums()
        async let libraryPlaylists = fetchPlaylists()

        let songResults = try await librarySongs
        let albumResults = try await libraryAlbums
        let playlistResults = try await libraryPlaylists

        return AppleMusicBackupSnapshotFactory.makeSnapshot(
            songs: mergedSongs(
                savedSongs: songResults,
                playlistOnlySongs: playlistResults.playlistOnlySongs
            ),
            albums: albumResults,
            playlists: playlistResults.playlists
        )
    }

    private func fetchSongs() async throws -> [BackupSong] {
        let request = MusicLibraryRequest<Song>()
        let response = try await request.response()

        return response.items.map { song in
            BackupSong(
                id: song.id.rawValue,
                identifiers: MusicItemIdentifiers(
                    libraryID: song.id.rawValue,
                    isrc: song.isrc
                ),
                libraryStatus: .saved,
                title: song.title,
                artistName: song.artistName,
                albumTitle: song.albumTitle,
                durationMilliseconds: Self.milliseconds(from: song.duration),
                trackNumber: song.trackNumber,
                discNumber: song.discNumber
            )
        }
    }

    private func fetchAlbums() async throws -> [BackupAlbum] {
        let request = MusicLibraryRequest<Album>()
        let response = try await request.response()

        return response.items.map { album in
            BackupAlbum(
                id: album.id.rawValue,
                identifiers: MusicItemIdentifiers(libraryID: album.id.rawValue),
                title: album.title,
                artistName: album.artistName
            )
        }
    }

    private func fetchPlaylists() async throws -> PlaylistBackupResult {
        let request = MusicLibraryRequest<Playlist>()
        let response = try await request.response()
        var playlists: [BackupPlaylist] = []
        var playlistOnlySongs: [BackupSong] = []

        for playlist in response.items {
            let playlistID = playlist.id.rawValue
            let playlistWithEntries = try await playlist.with([.entries], preferredSource: .library)
            let entries = playlistWithEntries.entries ?? []

            playlistOnlySongs.append(
                contentsOf: entries.map { entry in
                    let songID = Self.songID(for: entry)
                    return BackupSong(
                        id: songID,
                        identifiers: MusicItemIdentifiers(
                            libraryID: songID,
                            isrc: entry.isrc
                        ),
                        libraryStatus: .playlistOnly,
                        title: entry.title,
                        artistName: entry.artistName,
                        albumTitle: entry.albumTitle,
                        durationMilliseconds: Self.milliseconds(from: entry.duration)
                    )
                }
            )

            playlists.append(
                BackupPlaylist(
                    id: playlistID,
                    identifiers: MusicItemIdentifiers(libraryID: playlistID),
                    name: playlist.name,
                    tracks: entries.enumerated().map { snapshotOrder, entry in
                        let songID = Self.songID(for: entry)
                        return BackupPlaylistTrack(
                            playlistID: playlistID,
                            songID: songID,
                            position: entry.position,
                            snapshotOrder: snapshotOrder,
                            addedAt: entry.libraryAddedDate
                        )
                    }
                )
            )
        }

        return PlaylistBackupResult(playlists: playlists, playlistOnlySongs: playlistOnlySongs)
    }

    private func mergedSongs(savedSongs: [BackupSong], playlistOnlySongs: [BackupSong]) -> [BackupSong] {
        var songsByID: [String: BackupSong] = [:]
        var orderedIDs: [String] = []

        func remember(_ song: BackupSong) {
            if songsByID[song.id] == nil {
                orderedIDs.append(song.id)
            }
            songsByID[song.id] = song
        }

        for song in savedSongs {
            remember(song)
        }

        for song in playlistOnlySongs where songsByID[song.id] == nil {
            remember(song)
        }

        return orderedIDs.compactMap { songsByID[$0] }
    }

    private struct PlaylistBackupResult: Sendable {
        var playlists: [BackupPlaylist]
        var playlistOnlySongs: [BackupSong]
    }

    private static func songID(for entry: Playlist.Entry) -> String {
        entry.item?.id.rawValue ?? entry.id.rawValue
    }

    private static func milliseconds(from duration: TimeInterval?) -> Int? {
        guard let duration else {
            return nil
        }

        return Int((duration * 1000).rounded())
    }
}
