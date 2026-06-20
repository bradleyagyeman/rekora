import Foundation

struct RebuildPlanSummary: Equatable, Sendable {
    var snapshotCreatedAt: Date
    var playlists: [PlaylistRebuildPlan]

    var playlistCount: Int {
        playlists.count
    }

    var trackCount: Int {
        playlists.reduce(0) { count, playlist in
            count + playlist.tracks.count
        }
    }

    var strongIdentifierTrackCount: Int {
        trackCount(for: .strongIdentifier)
    }

    var searchIdentifierTrackCount: Int {
        trackCount(for: .searchIdentifier)
    }

    var metadataOnlyTrackCount: Int {
        trackCount(for: .metadataOnly)
    }

    var missingSongRecordCount: Int {
        trackCount(for: .missingSongRecord)
    }

    var observedOrderPlaylistCount: Int {
        playlists.filter(\.usesObservedOrder).count
    }

    var liveMatchCount: Int {
        liveMatchTrackCount(for: .matched)
    }

    var liveAutomaticRebuildTrackCount: Int {
        playlists.reduce(0) { count, playlist in
            count + playlist.tracks.filter { $0.liveMatch?.isAutomaticRebuildEligible == true }.count
        }
    }

    var liveNeedsReviewForRebuildCount: Int {
        guard liveCheckedCount > 0 else {
            return 0
        }
        return liveCheckedCount - liveAutomaticRebuildTrackCount
    }

    var liveNeedsReviewCount: Int {
        liveMatchTrackCount(for: .needsReview) +
            liveMatchTrackCount(for: .ambiguous) +
            liveMatchTrackCount(for: .notFound) +
            liveMatchTrackCount(for: .unavailable) +
            liveMatchTrackCount(for: .failed)
    }

    var liveUncheckedCount: Int {
        trackCount - liveCheckedCount
    }

    var liveCheckedCount: Int {
        playlists.reduce(0) { count, playlist in
            count + playlist.tracks.filter { $0.liveMatch != nil }.count
        }
    }

    private func trackCount(for readiness: RebuildTrackReadiness) -> Int {
        playlists.reduce(0) { count, playlist in
            count + playlist.tracks.filter { $0.readiness == readiness }.count
        }
    }

    private func liveMatchTrackCount(for status: LiveMusicMatchStatus) -> Int {
        playlists.reduce(0) { count, playlist in
            count + playlist.tracks.filter { $0.liveMatch?.status == status }.count
        }
    }
}

struct PlaylistRebuildPlan: Equatable, Sendable {
    var playlistID: String
    var name: String
    var tracks: [RebuildTrackPlan]
    var usesObservedOrder: Bool
}

struct RebuildTrackPlan: Equatable, Sendable {
    var playlistID: String
    var songID: String
    var title: String
    var artistName: String
    var order: Int
    var readiness: RebuildTrackReadiness
    var liveMatch: LiveMusicTrackMatch?

    init(
        playlistID: String,
        songID: String,
        title: String,
        artistName: String,
        order: Int,
        readiness: RebuildTrackReadiness,
        liveMatch: LiveMusicTrackMatch? = nil
    ) {
        self.playlistID = playlistID
        self.songID = songID
        self.title = title
        self.artistName = artistName
        self.order = order
        self.readiness = readiness
        self.liveMatch = liveMatch
    }
}

enum RebuildTrackReadiness: Equatable, Sendable {
    case strongIdentifier
    case searchIdentifier
    case metadataOnly
    case missingSongRecord
}

enum RebuildPlan {
    static func make(from snapshot: BackupSnapshot) -> RebuildPlanSummary {
        make(from: snapshot, liveMatches: [:])
    }

    static func make(
        from snapshot: BackupSnapshot,
        liveMatches: [String: LiveMusicTrackMatch]
    ) -> RebuildPlanSummary {
        let songsByID = Dictionary(uniqueKeysWithValues: snapshot.songs.map { ($0.id, $0) })
        let playlists = snapshot.playlists
            .map { playlist in
                makePlaylistPlan(playlist, songsByID: songsByID, liveMatches: liveMatches)
            }
            .sorted { first, second in
                first.name.localizedCaseInsensitiveCompare(second.name) == .orderedAscending
            }

        return RebuildPlanSummary(
            snapshotCreatedAt: snapshot.createdAt,
            playlists: playlists
        )
    }

    private static func makePlaylistPlan(
        _ playlist: BackupPlaylist,
        songsByID: [String: BackupSong],
        liveMatches: [String: LiveMusicTrackMatch]
    ) -> PlaylistRebuildPlan {
        let orderedTracks = effectiveOrderedTracks(in: playlist)
        let tracks = orderedTracks.enumerated().map { index, track in
            makeTrackPlan(
                track,
                order: index,
                song: songsByID[track.songID],
                liveMatch: liveMatches[track.songID]
            )
        }

        return PlaylistRebuildPlan(
            playlistID: playlist.id,
            name: playlist.name,
            tracks: tracks,
            usesObservedOrder: usesObservedOrder(in: playlist)
        )
    }

    private static func makeTrackPlan(
        _ track: BackupPlaylistTrack,
        order: Int,
        song: BackupSong?,
        liveMatch: LiveMusicTrackMatch?
    ) -> RebuildTrackPlan {
        guard let song else {
            return RebuildTrackPlan(
                playlistID: track.playlistID,
                songID: track.songID,
                title: "Unknown song",
                artistName: "Unknown artist",
                order: order,
                readiness: .missingSongRecord,
                liveMatch: liveMatch
            )
        }

        return RebuildTrackPlan(
            playlistID: track.playlistID,
            songID: track.songID,
            title: song.title,
            artistName: song.artistName,
            order: order,
            readiness: readiness(for: song),
            liveMatch: liveMatch
        )
    }

    private static func readiness(for song: BackupSong) -> RebuildTrackReadiness {
        if hasValue(song.identifiers.catalogID) || hasValue(song.identifiers.appleMusicID) {
            return .strongIdentifier
        }

        if hasValue(song.identifiers.isrc) {
            return .searchIdentifier
        }

        if !song.title.isEmpty && !song.artistName.isEmpty {
            return .metadataOnly
        }

        return .missingSongRecord
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

    private static func usesObservedOrder(in playlist: BackupPlaylist) -> Bool {
        guard playlist.tracks.allSatisfy({ $0.snapshotOrder != nil }) else {
            return false
        }

        let positions = playlist.tracks.map(\.position)
        return positions.sorted() != Array(0..<playlist.tracks.count)
    }

    private static func hasValue(_ value: String?) -> Bool {
        guard let value else {
            return false
        }

        return !value.isEmpty
    }
}
