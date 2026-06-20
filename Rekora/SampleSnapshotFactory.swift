import Foundation

enum SampleSnapshotFactory {
    static func makeSnapshot(createdAt: Date = Date()) -> BackupSnapshot {
        let song = BackupSong(
            id: "sample-song-1",
            identifiers: MusicItemIdentifiers(
                libraryID: "sample-library-song-1",
                catalogID: "sample-catalog-song-1",
                appleMusicID: "sample-apple-music-song-1",
                isrc: "USRC17607839"
            ),
            title: "Sample Song",
            artistName: "Sample Artist",
            albumTitle: "Sample Album",
            albumArtistName: "Sample Album Artist",
            durationMilliseconds: 181_000,
            trackNumber: 1,
            discNumber: 1
        )

        return BackupSnapshot(
            snapshotID: UUID(),
            createdAt: createdAt,
            source: SnapshotSource(appVersion: "0.1.0", storefrontID: "us"),
            songs: [song],
            albums: [
                BackupAlbum(
                    id: "sample-album-1",
                    identifiers: MusicItemIdentifiers(catalogID: "sample-catalog-album-1"),
                    title: "Sample Album",
                    artistName: "Sample Album Artist",
                    releaseYear: 2026,
                    songIDs: [song.id]
                )
            ],
            playlists: [
                BackupPlaylist(
                    id: "sample-playlist-1",
                    identifiers: MusicItemIdentifiers(libraryID: "sample-library-playlist-1"),
                    name: "Sample Playlist",
                    description: "Temporary sample data until MusicKit is wired up.",
                    tracks: [
                        BackupPlaylistTrack(
                            playlistID: "sample-playlist-1",
                            songID: song.id,
                            position: 0,
                            snapshotOrder: 0,
                            addedAt: createdAt
                        )
                    ]
                )
            ]
        )
    }
}
