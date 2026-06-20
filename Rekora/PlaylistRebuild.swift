import Foundation
import MusicKit

struct MatchedPlaylistTrack: Equatable, Sendable {
    var songID: String
    var title: String
    var artistName: String
    var order: Int
    var match: LiveMusicTrackMatch
}

struct PlaylistRebuildPreview: Equatable, Identifiable, Sendable {
    var playlistID: String
    var sourcePlaylistName: String
    var newPlaylistName: String
    var matchedTrackCount: Int
    var skippedTrackCount: Int
    var totalTrackCount: Int

    var id: String { playlistID }
}

struct PlaylistRebuildRequest: Equatable, Sendable {
    var playlistID: String
    var sourcePlaylistName: String
    var newPlaylistName: String
    var matchedTracks: [MatchedPlaylistTrack]
    var skippedTrackCount: Int
    var totalTrackCount: Int

    var preview: PlaylistRebuildPreview {
        PlaylistRebuildPreview(
            playlistID: playlistID,
            sourcePlaylistName: sourcePlaylistName,
            newPlaylistName: newPlaylistName,
            matchedTrackCount: matchedTracks.count,
            skippedTrackCount: skippedTrackCount,
            totalTrackCount: totalTrackCount
        )
    }

    static func make(from playlist: PlaylistRebuildPlan) throws -> PlaylistRebuildRequest {
        let matchedTracks = playlist.tracks.compactMap { track -> MatchedPlaylistTrack? in
            guard let match = track.liveMatch,
                  match.isAutomaticRebuildEligible else {
                return nil
            }

            return MatchedPlaylistTrack(
                songID: track.songID,
                title: track.title,
                artistName: track.artistName,
                order: track.order,
                match: match
            )
        }

        guard !matchedTracks.isEmpty else {
            throw PlaylistRebuildError.noMatchedTracks
        }

        return PlaylistRebuildRequest(
            playlistID: playlist.playlistID,
            sourcePlaylistName: playlist.name,
            newPlaylistName: PlaylistRebuildNamer.restoredPlaylistName(for: playlist.name),
            matchedTracks: matchedTracks.sorted { first, second in
                first.order < second.order
            },
            skippedTrackCount: playlist.tracks.count - matchedTracks.count,
            totalTrackCount: playlist.tracks.count
        )
    }

    static func previews(in plan: RebuildPlanSummary) -> [PlaylistRebuildPreview] {
        plan.playlists.compactMap { playlist in
            try? make(from: playlist).preview
        }
    }
}

struct PlaylistRebuildResult: Equatable, Sendable {
    var sourcePlaylistName: String
    var createdPlaylist: MusicPlaylistSummary
    var addedTrackCount: Int
    var skippedTrackCount: Int
    var totalTrackCount: Int
}

enum PlaylistRebuildError: Error, Equatable {
    case noMatchedTracks
    case permissionRequired
    case checkMatchesFirst
    case playlistNotFound
    case matchedSongUnavailable(String)
}

enum PlaylistRebuildState: Equatable {
    case idle
    case confirming(PlaylistRebuildRequest)
    case rebuilding(PlaylistRebuildPreview)
    case completed(PlaylistRebuildResult)
    case failed(String)
}

protocol PlaylistRebuilding {
    func rebuild(_ request: PlaylistRebuildRequest) async throws -> PlaylistRebuildResult
}

@MainActor
final class PlaylistRebuildViewModel: ObservableObject {
    @Published private(set) var state = PlaylistRebuildState.idle

    private let service: PlaylistRebuilding

    init(service: PlaylistRebuilding = PlaylistRebuildService()) {
        self.service = service
    }

    func prepareConfirmation(
        playlistID: String,
        plan: RebuildPlanSummary,
        permissionStatus: AppleMusicPermissionStatus
    ) {
        guard permissionStatus == .authorized else {
            state = .failed(PlaylistRebuildStatusCopy.message(for: PlaylistRebuildError.permissionRequired))
            return
        }

        guard plan.liveCheckedCount > 0 else {
            state = .failed(PlaylistRebuildStatusCopy.message(for: PlaylistRebuildError.checkMatchesFirst))
            return
        }

        guard let playlist = plan.playlists.first(where: { $0.playlistID == playlistID }) else {
            state = .failed(PlaylistRebuildStatusCopy.message(for: PlaylistRebuildError.playlistNotFound))
            return
        }

        do {
            state = .confirming(try PlaylistRebuildRequest.make(from: playlist))
        } catch {
            state = .failed(PlaylistRebuildStatusCopy.message(for: error))
        }
    }

    func cancelConfirmation() {
        if case .confirming = state {
            state = .idle
        }
    }

    func confirmRebuild() async {
        guard case .confirming(let request) = state else {
            return
        }

        state = .rebuilding(request.preview)

        do {
            state = .completed(try await service.rebuild(request))
        } catch {
            state = .failed(PlaylistRebuildStatusCopy.message(for: error))
        }
    }
}

protocol MusicPlaylistWriting {
    func createPlaylist(
        name: String,
        description: String?,
        matchedTracks: [MatchedPlaylistTrack]
    ) async throws -> MusicPlaylistSummary
}

struct PlaylistRebuildService: PlaylistRebuilding {
    private let writer: MusicPlaylistWriting

    init(writer: MusicPlaylistWriting = AppleMusicPlaylistWriter()) {
        self.writer = writer
    }

    func rebuild(_ request: PlaylistRebuildRequest) async throws -> PlaylistRebuildResult {
        let playlist = try await writer.createPlaylist(
            name: request.newPlaylistName,
            description: "Created by Rekora from the backup playlist \"\(request.sourcePlaylistName)\".",
            matchedTracks: request.matchedTracks
        )

        return PlaylistRebuildResult(
            sourcePlaylistName: request.sourcePlaylistName,
            createdPlaylist: playlist,
            addedTrackCount: request.matchedTracks.count,
            skippedTrackCount: request.skippedTrackCount,
            totalTrackCount: request.totalTrackCount
        )
    }
}

struct AppleMusicPlaylistWriter: MusicPlaylistWriting {
    private let subscriptionProvider: AppleMusicSubscriptionProviding
    private let songResolver: MusicMatchedSongResolving

    init(
        subscriptionProvider: AppleMusicSubscriptionProviding = AppleMusicSubscriptionClient(),
        songResolver: MusicMatchedSongResolving = MusicMatchedSongResolver()
    ) {
        self.subscriptionProvider = subscriptionProvider
        self.songResolver = songResolver
    }

    func createPlaylist(
        name: String,
        description: String?,
        matchedTracks: [MatchedPlaylistTrack]
    ) async throws -> MusicPlaylistSummary {
        let subscription = try await subscriptionProvider.currentStatus()
        guard subscription.hasCloudLibraryEnabled else {
            throw PlaylistLibraryError.cloudLibraryDisabled
        }

        guard subscription.canPlayCatalogContent else {
            throw PlaylistLibraryError.subscriptionRequired
        }

        var songs: [Song] = []
        for track in matchedTracks {
            guard let song = try await songResolver.song(for: track.match) else {
                throw PlaylistRebuildError.matchedSongUnavailable(track.title)
            }
            songs.append(song)
        }

        let playlist = try await MusicLibrary.shared.createPlaylist(
            name: name,
            description: description,
            authorDisplayName: "Rekora",
            items: songs
        )

        return MusicPlaylistSummary(id: playlist.id.rawValue, name: playlist.name)
    }
}

protocol MusicMatchedSongResolving {
    func song(for match: LiveMusicTrackMatch) async throws -> Song?
}

struct MusicMatchedSongResolver: MusicMatchedSongResolving {
    func song(for match: LiveMusicTrackMatch) async throws -> Song? {
        guard let matchedID = match.matchedID, !matchedID.isEmpty else {
            return nil
        }

        switch match.reason {
        case .libraryID:
            return try await librarySong(id: matchedID)
        case .catalogID, .appleMusicID, .isrc:
            return try await catalogSong(id: matchedID)
        case .metadata, .missingSearchData, .noCandidate, .multipleCandidates, .requestFailed, .notChecked:
            return nil
        }
    }

    private func librarySong(id: String) async throws -> Song? {
        var request = MusicLibraryRequest<Song>()
        request.limit = 1
        request.filter(matching: \.id, equalTo: MusicItemID(id))
        let response = try await request.response()
        return response.items.first
    }

    private func catalogSong(id: String) async throws -> Song? {
        var request = MusicCatalogResourceRequest<Song>(
            matching: \.id,
            equalTo: MusicItemID(id)
        )
        request.limit = 1
        let response = try await request.response()
        return response.items.first
    }
}

enum PlaylistRebuildNamer {
    private static let prefix = "Rekora Restore - "
    private static let fallbackName = "Untitled Playlist"
    private static let maxLength = 100

    static func restoredPlaylistName(for sourceName: String) -> String {
        let trimmed = sourceName.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseName = trimmed.isEmpty ? fallbackName : trimmed
        let fullName = "\(prefix)\(baseName)"

        guard fullName.count > maxLength else {
            return fullName
        }

        return String(fullName.prefix(maxLength)).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum PlaylistRebuildStatusCopy {
    static func actionTitle(for preview: PlaylistRebuildPreview) -> String {
        "Rebuild \"\(preview.sourcePlaylistName)\""
    }

    static func previewText(for preview: PlaylistRebuildPreview) -> String {
        "\(countText(preview.matchedTrackCount, singular: "track")) will be added to a new playlist. \(countText(preview.skippedTrackCount, singular: "track")) will be skipped."
    }

    static func confirmationText(for preview: PlaylistRebuildPreview) -> String {
        "Rekora will create a new Apple Music playlist named \"\(preview.newPlaylistName)\". Your existing playlists will not be changed."
    }

    static func rebuildingText(for preview: PlaylistRebuildPreview) -> String {
        "Creating \"\(preview.newPlaylistName)\" in Apple Music. Existing playlists are not being changed."
    }

    static func completedText(for result: PlaylistRebuildResult) -> String {
        let skippedSuffix = result.skippedTrackCount == 1 ? "was skipped" : "were skipped"
        return "Created \"\(result.createdPlaylist.name)\" with \(countText(result.addedTrackCount, singular: "track")). \(countText(result.skippedTrackCount, singular: "track")) needed review and \(skippedSuffix)."
    }

    static func message(for error: Error) -> String {
        switch error {
        case PlaylistRebuildError.noMatchedTracks:
            return "No matched tracks are ready to rebuild yet."
        case PlaylistRebuildError.permissionRequired:
            return "Allow Apple Music access before rebuilding a playlist."
        case PlaylistRebuildError.checkMatchesFirst:
            return "Check Apple Music matches before rebuilding a playlist."
        case PlaylistRebuildError.playlistNotFound:
            return "Rekora could not find that playlist in this backup."
        case PlaylistRebuildError.matchedSongUnavailable:
            return "Apple Music could not load one of the matched tracks. Check matches again, then retry."
        default:
            return PlaylistLibraryErrorMessage.make(from: error)
        }
    }

    private static func countText(_ count: Int, singular: String) -> String {
        if count == 1 {
            return "1 \(singular)"
        }
        return "\(count) \(singular)s"
    }
}
