import Combine
import Foundation
import MusicKit

struct LibraryProbeReport: Equatable, Sendable {
    var songCount: Int
    var albumCount: Int
    var playlistCount: Int
    var checkedPlaylistCount: Int
    var playlistTrackCount: Int
    var playlistTracksReadable: Bool
    var playlistOrderReadable: Bool
    var playlistTracksWithAddedDateCount: Int
    var missingTrackIdentifierCount: Int
    var missingTrackTitleCount: Int
    var failedPlaylistTrackCount: Int
    var duration: TimeInterval
}

enum LibraryProbeState: Equatable {
    case idle
    case running
    case completed(LibraryProbeReport)
    case blockedByPermission
    case failed(String)

    var isRunning: Bool {
        if case .running = self {
            return true
        }
        return false
    }
}

protocol LibraryProbing {
    func inspectLibrary() async throws -> LibraryProbeReport
}

struct MusicLibraryProbeClient: LibraryProbing {
    private let subscriptionProvider: AppleMusicSubscriptionProviding

    init(subscriptionProvider: AppleMusicSubscriptionProviding = AppleMusicSubscriptionClient()) {
        self.subscriptionProvider = subscriptionProvider
    }

    func inspectLibrary() async throws -> LibraryProbeReport {
        let startedAt = Date()
        let subscription = try await subscriptionProvider.currentStatus()
        guard subscription.hasCloudLibraryEnabled else {
            throw PlaylistLibraryError.cloudLibraryDisabled
        }

        guard subscription.canPlayCatalogContent else {
            throw PlaylistLibraryError.subscriptionRequired
        }

        async let songs = fetchSongs()
        async let albums = fetchAlbums()
        async let playlistProbe = inspectPlaylists()

        let songCount = try await songs
        let albumCount = try await albums
        let playlistSummary = try await playlistProbe

        return LibraryProbeReport(
            songCount: songCount,
            albumCount: albumCount,
            playlistCount: playlistSummary.playlistCount,
            checkedPlaylistCount: playlistSummary.checkedPlaylistCount,
            playlistTrackCount: playlistSummary.trackCount,
            playlistTracksReadable: playlistSummary.trackCount > 0,
            playlistOrderReadable: playlistSummary.trackCount > 0,
            playlistTracksWithAddedDateCount: playlistSummary.addedDateCount,
            missingTrackIdentifierCount: playlistSummary.missingIdentifierCount,
            missingTrackTitleCount: playlistSummary.missingTitleCount,
            failedPlaylistTrackCount: playlistSummary.failedPlaylistCount,
            duration: Date().timeIntervalSince(startedAt)
        )
    }

    private func fetchSongs() async throws -> Int {
        let request = MusicLibraryRequest<Song>()
        let response = try await request.response()
        return response.items.count
    }

    private func fetchAlbums() async throws -> Int {
        let request = MusicLibraryRequest<Album>()
        let response = try await request.response()
        return response.items.count
    }

    private func inspectPlaylists() async throws -> PlaylistProbeSummary {
        let request = MusicLibraryRequest<Playlist>()
        let response = try await request.response()

        var summary = PlaylistProbeSummary(playlistCount: response.items.count)

        for playlist in response.items {
            summary.checkedPlaylistCount += 1

            let playlistWithEntries = try await playlist.with([.entries], preferredSource: .library)

            guard let entries = playlistWithEntries.entries else {
                summary.failedPlaylistCount += 1
                continue
            }

            for entry in entries {
                let trackSummary = ProbeTrackSummary(entry: entry)
                summary.trackCount += 1

                if trackSummary.identifier.isEmpty {
                    summary.missingIdentifierCount += 1
                }

                if trackSummary.title.isEmpty {
                    summary.missingTitleCount += 1
                }

                if trackSummary.addedAt != nil {
                    summary.addedDateCount += 1
                }
            }
        }

        return summary
    }
}

private struct PlaylistProbeSummary: Equatable {
    var playlistCount: Int
    var checkedPlaylistCount = 0
    var trackCount = 0
    var missingIdentifierCount = 0
    var missingTitleCount = 0
    var addedDateCount = 0
    var failedPlaylistCount = 0
}

private struct ProbeTrackSummary: Equatable {
    var identifier: String
    var title: String
    var position: Int
    var addedAt: Date?

    init(entry: Playlist.Entry) {
        identifier = entry.item?.id.rawValue ?? entry.id.rawValue
        title = entry.title
        position = entry.position
        addedAt = entry.libraryAddedDate
    }
}

@MainActor
final class LibraryProbeViewModel: ObservableObject {
    @Published private(set) var state = LibraryProbeState.idle

    private let probe: LibraryProbing

    init(probe: LibraryProbing = MusicLibraryProbeClient()) {
        self.probe = probe
    }

    func inspect(permissionStatus: AppleMusicPermissionStatus) async {
        guard permissionStatus == .authorized else {
            state = .blockedByPermission
            return
        }

        state = .running

        do {
            state = .completed(try await probe.inspectLibrary())
        } catch {
            state = .failed(PlaylistLibraryErrorMessage.make(from: error))
        }
    }
}
