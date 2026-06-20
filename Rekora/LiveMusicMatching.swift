import Foundation
import MusicKit

struct LiveMusicTrackMatch: Equatable, Sendable {
    var songID: String
    var status: LiveMusicMatchStatus
    var matchedID: String?
    var title: String?
    var artistName: String?
    var reason: LiveMusicMatchReason

    init(
        songID: String,
        status: LiveMusicMatchStatus,
        matchedID: String? = nil,
        title: String? = nil,
        artistName: String? = nil,
        reason: LiveMusicMatchReason
    ) {
        self.songID = songID
        self.status = status
        self.matchedID = matchedID
        self.title = title
        self.artistName = artistName
        self.reason = reason
    }
}

enum LiveMusicMatchStatus: Equatable, Sendable {
    case notChecked
    case matched
    case needsReview
    case ambiguous
    case notFound
    case unavailable
    case failed
}

enum LiveMusicMatchReason: Equatable, Sendable {
    case libraryID
    case catalogID
    case appleMusicID
    case isrc
    case metadata
    case missingSearchData
    case noCandidate
    case multipleCandidates
    case requestFailed
    case notChecked
}

extension LiveMusicTrackMatch {
    var isAutomaticRebuildEligible: Bool {
        status == .matched &&
            matchedID?.isEmpty == false &&
            reason.isAutomaticRebuildIdentifier
    }
}

extension LiveMusicMatchReason {
    var isAutomaticRebuildIdentifier: Bool {
        switch self {
        case .libraryID, .catalogID, .appleMusicID, .isrc:
            true
        case .metadata, .missingSearchData, .noCandidate, .multipleCandidates, .requestFailed, .notChecked:
            false
        }
    }
}

protocol LiveMusicTrackMatching {
    func matchTracks(for songs: [BackupSong]) async throws -> [String: LiveMusicTrackMatch]
}

struct AppleMusicLiveMatchClient: LiveMusicTrackMatching {
    private let subscriptionProvider: AppleMusicSubscriptionProviding
    private let songSearcher: MusicSongSearching

    init(
        subscriptionProvider: AppleMusicSubscriptionProviding = AppleMusicSubscriptionClient(),
        songSearcher: MusicSongSearching = MusicSongSearchClient()
    ) {
        self.subscriptionProvider = subscriptionProvider
        self.songSearcher = songSearcher
    }

    func matchTracks(for songs: [BackupSong]) async throws -> [String: LiveMusicTrackMatch] {
        let subscription = try await subscriptionProvider.currentStatus()
        guard subscription.hasCloudLibraryEnabled else {
            throw PlaylistLibraryError.cloudLibraryDisabled
        }

        guard subscription.canPlayCatalogContent else {
            throw PlaylistLibraryError.subscriptionRequired
        }

        var matches: [String: LiveMusicTrackMatch] = [:]
        for song in songs {
            matches[song.id] = await match(song)
        }
        return matches
    }

    private func match(_ song: BackupSong) async -> LiveMusicTrackMatch {
        if let libraryID = song.identifiers.libraryID, !libraryID.isEmpty {
            do {
                if let candidate = try await songSearcher.librarySong(id: libraryID) {
                    return matched(song: song, candidate: candidate, reason: .libraryID)
                }
            } catch {
                return failed(song: song)
            }
        }

        if let catalogID = song.identifiers.catalogID, !catalogID.isEmpty {
            do {
                if let candidate = try await songSearcher.catalogSong(id: catalogID) {
                    return matched(song: song, candidate: candidate, reason: .catalogID)
                }
            } catch {
                return failed(song: song)
            }
        }

        if let appleMusicID = song.identifiers.appleMusicID, !appleMusicID.isEmpty {
            do {
                if let candidate = try await songSearcher.catalogSong(id: appleMusicID) {
                    return matched(song: song, candidate: candidate, reason: .appleMusicID)
                }
            } catch {
                return failed(song: song)
            }
        }

        if let isrc = song.identifiers.isrc, !isrc.isEmpty {
            do {
                let candidates = try await songSearcher.catalogSongs(isrc: isrc)
                if let candidate = uniqueCandidate(in: candidates, matching: song) {
                    return matched(song: song, candidate: candidate, reason: .isrc)
                }
                if !candidates.isEmpty {
                    return needsReview(song: song, reason: .multipleCandidates)
                }
            } catch {
                return failed(song: song)
            }
        }

        let term = searchTerm(for: song)
        guard !term.isEmpty else {
            return LiveMusicTrackMatch(
                songID: song.id,
                status: .notFound,
                reason: .missingSearchData
            )
        }

        do {
            let candidates = try await songSearcher.catalogSongs(term: term)
            if let candidate = uniqueCandidate(in: candidates, matching: song) {
                return matched(song: song, candidate: candidate, reason: .metadata)
            }
            if candidates.isEmpty {
                return LiveMusicTrackMatch(
                    songID: song.id,
                    status: .notFound,
                    reason: .noCandidate
                )
            }
            return needsReview(song: song, reason: .multipleCandidates)
        } catch {
            return failed(song: song)
        }
    }

    private func matched(
        song: BackupSong,
        candidate: LiveMusicSongCandidate,
        reason: LiveMusicMatchReason
    ) -> LiveMusicTrackMatch {
        LiveMusicTrackMatch(
            songID: song.id,
            status: .matched,
            matchedID: candidate.id,
            title: candidate.title,
            artistName: candidate.artistName,
            reason: reason
        )
    }

    private func needsReview(
        song: BackupSong,
        reason: LiveMusicMatchReason
    ) -> LiveMusicTrackMatch {
        LiveMusicTrackMatch(
            songID: song.id,
            status: .needsReview,
            reason: reason
        )
    }

    private func failed(song: BackupSong) -> LiveMusicTrackMatch {
        LiveMusicTrackMatch(
            songID: song.id,
            status: .failed,
            reason: .requestFailed
        )
    }

    private func uniqueCandidate(
        in candidates: [LiveMusicSongCandidate],
        matching song: BackupSong
    ) -> LiveMusicSongCandidate? {
        let scored = candidates
            .filter { coreIdentityMatches($0, song) }
            .map { candidate in (candidate, matchScore(candidate, for: song)) }
            .filter { $0.1 >= 4 }
            .sorted { first, second in first.1 > second.1 }

        guard let best = scored.first else {
            return nil
        }

        if scored.count > 1, scored[1].1 == best.1 {
            return nil
        }

        return best.0
    }

    private func coreIdentityMatches(_ candidate: LiveMusicSongCandidate, _ song: BackupSong) -> Bool {
        stringsMatch(candidate.title, song.title) &&
            stringsMatch(candidate.artistName, song.artistName)
    }

    private func matchScore(_ candidate: LiveMusicSongCandidate, for song: BackupSong) -> Int {
        var score = 0

        if stringsMatch(candidate.title, song.title) {
            score += 2
        }
        if stringsMatch(candidate.artistName, song.artistName) {
            score += 2
        }
        if let candidateAlbum = candidate.albumTitle,
           let songAlbum = song.albumTitle,
           stringsMatch(candidateAlbum, songAlbum) {
            score += 1
        }
        if let candidateDuration = candidate.durationMilliseconds,
           let songDuration = song.durationMilliseconds,
           abs(candidateDuration - songDuration) <= 2_000 {
            score += 1
        }

        return score
    }

    private func stringsMatch(_ first: String, _ second: String) -> Bool {
        normalized(first) == normalized(second)
    }

    private func normalized(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func searchTerm(for song: BackupSong) -> String {
        [song.title, song.artistName, song.albumTitle]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

struct LiveMusicSongCandidate: Equatable, Sendable {
    var id: String
    var title: String
    var artistName: String
    var albumTitle: String?
    var durationMilliseconds: Int?
}

protocol MusicSongSearching {
    func librarySong(id: String) async throws -> LiveMusicSongCandidate?
    func catalogSong(id: String) async throws -> LiveMusicSongCandidate?
    func catalogSongs(isrc: String) async throws -> [LiveMusicSongCandidate]
    func catalogSongs(term: String) async throws -> [LiveMusicSongCandidate]
}

struct MusicSongSearchClient: MusicSongSearching {
    func librarySong(id: String) async throws -> LiveMusicSongCandidate? {
        var request = MusicLibraryRequest<Song>()
        request.limit = 1
        request.filter(matching: \.id, equalTo: MusicItemID(id))
        let response = try await request.response()
        return response.items.first.map(Self.candidate)
    }

    func catalogSong(id: String) async throws -> LiveMusicSongCandidate? {
        var request = MusicCatalogResourceRequest<Song>(
            matching: \.id,
            equalTo: MusicItemID(id)
        )
        request.limit = 1
        let response = try await request.response()
        return response.items.first.map(Self.candidate)
    }

    func catalogSongs(isrc: String) async throws -> [LiveMusicSongCandidate] {
        var request = MusicCatalogResourceRequest<Song>(
            matching: \.isrc,
            equalTo: isrc
        )
        request.limit = 5
        let response = try await request.response()
        return response.items.map(Self.candidate)
    }

    func catalogSongs(term: String) async throws -> [LiveMusicSongCandidate] {
        var request = MusicCatalogSearchRequest(term: term, types: [Song.self])
        request.limit = 5
        let response = try await request.response()
        return response.songs.map(Self.candidate)
    }

    private static func candidate(from song: Song) -> LiveMusicSongCandidate {
        LiveMusicSongCandidate(
            id: song.id.rawValue,
            title: song.title,
            artistName: song.artistName,
            albumTitle: song.albumTitle,
            durationMilliseconds: milliseconds(from: song.duration)
        )
    }

    private static func milliseconds(from duration: TimeInterval?) -> Int? {
        guard let duration else {
            return nil
        }

        return Int((duration * 1000).rounded())
    }
}
