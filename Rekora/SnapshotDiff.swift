import Foundation

struct SnapshotDiffSummary: Equatable, Sendable {
    var olderCreatedAt: Date
    var newerCreatedAt: Date
    var addedSongs: [BackupSong]
    var removedSongs: [BackupSong]
    var addedPlaylists: [BackupPlaylist]
    var removedPlaylists: [BackupPlaylist]
    var changedPlaylists: [PlaylistDiff]

    var hasChanges: Bool {
        !addedSongs.isEmpty ||
            !removedSongs.isEmpty ||
            !addedPlaylists.isEmpty ||
            !removedPlaylists.isEmpty ||
            !changedPlaylists.isEmpty
    }

    var playlistTrackAddedCount: Int {
        changedPlaylists.reduce(0) { count, playlist in
            count + playlist.addedTracks.count
        }
    }

    var playlistTrackRemovedCount: Int {
        changedPlaylists.reduce(0) { count, playlist in
            count + playlist.removedTracks.count
        }
    }

    var playlistOrderChangeCount: Int {
        changedPlaylists.filter(\.orderChanged).count
    }
}

struct PlaylistDiff: Equatable, Sendable {
    var playlistID: String
    var name: String
    var addedTracks: [BackupPlaylistTrack]
    var removedTracks: [BackupPlaylistTrack]
    var orderChanged: Bool

    var hasChanges: Bool {
        !addedTracks.isEmpty || !removedTracks.isEmpty || orderChanged
    }
}

enum SnapshotDiff {
    static func compare(older: BackupSnapshot, newer: BackupSnapshot) -> SnapshotDiffSummary {
        let olderSongs = keyedSongs(in: older)
        let newerSongs = keyedSongs(in: newer)
        let olderPlaylists = keyedPlaylists(in: older)
        let newerPlaylists = keyedPlaylists(in: newer)

        let addedSongs = values(in: newerSongs, missingFrom: olderSongs)
            .sorted(by: sortSongs)
        let removedSongs = values(in: olderSongs, missingFrom: newerSongs)
            .sorted(by: sortSongs)
        let addedPlaylists = values(in: newerPlaylists, missingFrom: olderPlaylists)
            .sorted(by: sortPlaylists)
        let removedPlaylists = values(in: olderPlaylists, missingFrom: newerPlaylists)
            .sorted(by: sortPlaylists)
        let changedPlaylists = playlistDiffs(
            older: older,
            newer: newer,
            olderPlaylists: olderPlaylists,
            newerPlaylists: newerPlaylists
        )

        return SnapshotDiffSummary(
            olderCreatedAt: older.createdAt,
            newerCreatedAt: newer.createdAt,
            addedSongs: addedSongs,
            removedSongs: removedSongs,
            addedPlaylists: addedPlaylists,
            removedPlaylists: removedPlaylists,
            changedPlaylists: changedPlaylists
        )
    }

    private static func playlistDiffs(
        older: BackupSnapshot,
        newer: BackupSnapshot,
        olderPlaylists: [PlaylistIdentity: BackupPlaylist],
        newerPlaylists: [PlaylistIdentity: BackupPlaylist]
    ) -> [PlaylistDiff] {
        let olderSongs = songLookup(in: older)
        let newerSongs = songLookup(in: newer)

        return olderPlaylists.keys
            .filter { newerPlaylists[$0] != nil }
            .compactMap { playlistID in
                guard
                    let olderPlaylist = olderPlaylists[playlistID],
                    let newerPlaylist = newerPlaylists[playlistID]
                else {
                    return nil
                }

                let olderTracks = effectiveOrderedTracks(in: olderPlaylist)
                let newerTracks = effectiveOrderedTracks(in: newerPlaylist)
                let olderTrackIDs = olderTracks.map { trackIdentity(for: $0, songsByID: olderSongs) }
                let newerTrackIDs = newerTracks.map { trackIdentity(for: $0, songsByID: newerSongs) }
                let addedTracks = extraTracks(newerTracks, comparedTo: olderTrackIDs, songsByID: newerSongs)
                let removedTracks = extraTracks(olderTracks, comparedTo: newerTrackIDs, songsByID: olderSongs)
                let orderChanged = addedTracks.isEmpty &&
                    removedTracks.isEmpty &&
                    olderTrackIDs != newerTrackIDs
                let diff = PlaylistDiff(
                    playlistID: newerPlaylist.id,
                    name: newerPlaylist.name,
                    addedTracks: addedTracks,
                    removedTracks: removedTracks,
                    orderChanged: orderChanged
                )

                return diff.hasChanges ? diff : nil
            }
            .sorted { first, second in
                first.name.localizedCaseInsensitiveCompare(second.name) == .orderedAscending
            }
    }

    private static func keyedSongs(in snapshot: BackupSnapshot) -> [SongIdentity: BackupSong] {
        Dictionary(snapshot.songs.map { (SongIdentity(song: $0), $0) }) { first, _ in first }
    }

    private static func keyedPlaylists(in snapshot: BackupSnapshot) -> [PlaylistIdentity: BackupPlaylist] {
        Dictionary(snapshot.playlists.map { (PlaylistIdentity(playlist: $0), $0) }) { first, _ in first }
    }

    private static func songLookup(in snapshot: BackupSnapshot) -> [String: BackupSong] {
        Dictionary(uniqueKeysWithValues: snapshot.songs.map { ($0.id, $0) })
    }

    private static func values<Key: Hashable, Value>(
        in included: [Key: Value],
        missingFrom excluded: [Key: Value]
    ) -> [Value] {
        included.compactMap { key, value in
            excluded[key] == nil ? value : nil
        }
    }

    private static func sortSongs(_ first: BackupSong, _ second: BackupSong) -> Bool {
        let firstValue = "\(first.artistName)\u{0}\(first.title)"
        let secondValue = "\(second.artistName)\u{0}\(second.title)"
        return firstValue.localizedCaseInsensitiveCompare(secondValue) == .orderedAscending
    }

    private static func sortPlaylists(_ first: BackupPlaylist, _ second: BackupPlaylist) -> Bool {
        first.name.localizedCaseInsensitiveCompare(second.name) == .orderedAscending
    }

    private static func effectiveOrderedTracks(in playlist: BackupPlaylist) -> [BackupPlaylistTrack] {
        if playlist.tracks.allSatisfy({ $0.snapshotOrder != nil }) {
            return playlist.tracks.sorted { first, second in
                (first.snapshotOrder ?? first.position) < (second.snapshotOrder ?? second.position)
            }
        }

        let positions = playlist.tracks.map(\.position)
        if positions.sorted() == Array(0..<playlist.tracks.count) {
            return playlist.tracks.sorted { first, second in
                first.position < second.position
            }
        }

        return playlist.tracks
    }

    private static func extraTracks(
        _ tracks: [BackupPlaylistTrack],
        comparedTo otherTrackIDs: [TrackIdentity],
        songsByID: [String: BackupSong]
    ) -> [BackupPlaylistTrack] {
        var remaining = otherTrackIDs.reduce(into: [TrackIdentity: Int]()) { counts, identity in
            counts[identity, default: 0] += 1
        }

        return tracks.filter { track in
            let identity = trackIdentity(for: track, songsByID: songsByID)
            guard let count = remaining[identity], count > 0 else {
                return true
            }

            remaining[identity] = count - 1
            return false
        }
    }

    private static func trackIdentity(
        for track: BackupPlaylistTrack,
        songsByID: [String: BackupSong]
    ) -> TrackIdentity {
        if let song = songsByID[track.songID] {
            return TrackIdentity(value: SongIdentity(song: song).value)
        }

        return TrackIdentity(value: "song-id:\(track.songID)")
    }
}

private struct SongIdentity: Hashable {
    var value: String

    init(song: BackupSong) {
        if let libraryID = song.identifiers.libraryID, !libraryID.isEmpty {
            value = "library:\(libraryID)"
        } else if let catalogID = song.identifiers.catalogID, !catalogID.isEmpty {
            value = "catalog:\(catalogID)"
        } else if let appleMusicID = song.identifiers.appleMusicID, !appleMusicID.isEmpty {
            value = "apple:\(appleMusicID)"
        } else if let isrc = song.identifiers.isrc, !isrc.isEmpty {
            value = "isrc:\(isrc.uppercased())"
        } else {
            value = "snapshot:\(song.id)"
        }
    }
}

private struct PlaylistIdentity: Hashable {
    var value: String

    init(playlist: BackupPlaylist) {
        if let libraryID = playlist.identifiers.libraryID, !libraryID.isEmpty {
            value = "library:\(libraryID)"
        } else {
            value = "snapshot:\(playlist.id)"
        }
    }
}

private struct TrackIdentity: Hashable {
    var value: String
}
