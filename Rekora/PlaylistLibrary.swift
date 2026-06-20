import Combine
import Foundation
import MusicKit

private let unknownPlaylistErrorMessage = "Apple Music returned an unknown error while checking playlists. Verify the bundle ID, explicit App ID, MusicKit capability, signed-in Apple Music account, and real-device setup."

struct MusicPlaylistSummary: Equatable, Identifiable, Sendable {
    var id: String
    var name: String
}

struct PlaylistLoadSummary: Equatable, Sendable {
    var count: Int
    var sampleNames: [String]
}

enum PlaylistLibraryState: Equatable {
    case idle
    case loading
    case loaded(PlaylistLoadSummary)
    case blockedByPermission
    case failed(String)

    var isLoading: Bool {
        if case .loading = self {
            return true
        }
        return false
    }
}

protocol MusicPlaylistProviding {
    func fetchPlaylists() async throws -> [MusicPlaylistSummary]
}

struct AppleMusicSubscriptionStatus: Equatable, Sendable {
    var canPlayCatalogContent: Bool
    var canBecomeSubscriber: Bool
    var hasCloudLibraryEnabled: Bool
}

protocol AppleMusicSubscriptionProviding {
    func currentStatus() async throws -> AppleMusicSubscriptionStatus
}

struct AppleMusicSubscriptionClient: AppleMusicSubscriptionProviding {
    func currentStatus() async throws -> AppleMusicSubscriptionStatus {
        let subscription = try await MusicSubscription.current

        return AppleMusicSubscriptionStatus(
            canPlayCatalogContent: subscription.canPlayCatalogContent,
            canBecomeSubscriber: subscription.canBecomeSubscriber,
            hasCloudLibraryEnabled: subscription.hasCloudLibraryEnabled
        )
    }
}

enum PlaylistLibraryError: Error, Equatable {
    case cloudLibraryDisabled
    case subscriptionRequired
}

enum PlaylistLibraryErrorMessage {
    static func make(from error: Error) -> String {
        switch error {
        case PlaylistLibraryError.cloudLibraryDisabled:
            return "Apple Music Sync Library is off for this account or device. Turn on Sync Library, then try again."
        case PlaylistLibraryError.subscriptionRequired:
            return "An active Apple Music subscription is needed before Rekora can read Apple Music library playlists."
        case let tokenError as MusicTokenRequestError:
            return message(for: tokenError)
        case let subscriptionError as MusicSubscription.Error:
            return message(for: subscriptionError)
        case let libraryError as MusicLibrary.Error:
            return message(for: libraryError)
        case let dataRequestError as MusicDataRequest.Error:
            return message(for: dataRequestError)
        default:
            return fallbackMessage(for: error)
        }
    }

    private static func message(for error: MusicTokenRequestError) -> String {
        switch error {
        case .permissionDenied:
            return "Apple Music permission was denied. Allow Rekora access in Settings, then try again."
        case .userNotSignedIn:
            return "Sign in to Media & Purchases with an Apple Music account, then try again."
        case .userTokenRevoked:
            return "Apple Music revoked Rekora's user token. Allow Apple Music access again, then retry playlist checking."
        case .privacyAcknowledgementRequired:
            return "Apple Music needs a privacy acknowledgement in the Music app before Rekora can read playlists."
        case .developerTokenRequestFailed:
            return "MusicKit could not create a developer token. Verify the bundle ID, explicit App ID, and MusicKit capability in the Apple Developer portal."
        case .userTokenRequestFailed:
            return "MusicKit could not create a user token. Verify Apple Music permission, account sign-in, and MusicKit capability setup."
        case .unknown:
            return unknownPlaylistErrorMessage
        @unknown default:
            return unknownPlaylistErrorMessage
        }
    }

    private static func message(for error: MusicSubscription.Error) -> String {
        switch error {
        case .permissionDenied:
            return "Apple Music permission was denied. Allow Rekora access in Settings, then try again."
        case .privacyAcknowledgementRequired:
            return "Apple Music needs a privacy acknowledgement in the Music app before Rekora can read playlists."
        case .unknown:
            return unknownPlaylistErrorMessage
        @unknown default:
            return unknownPlaylistErrorMessage
        }
    }

    private static func message(for error: MusicLibrary.Error) -> String {
        switch error {
        case .permissionDenied:
            return "Apple Music permission was denied. Allow Rekora access in Settings, then try again."
        case .unknown:
            return unknownPlaylistErrorMessage
        default:
            return fallbackMessage(for: error)
        }
    }

    private static func message(for error: MusicDataRequest.Error) -> String {
        let detail = error.detailText.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = error.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let reason = detail.isEmpty ? title : detail

        if reason.isEmpty {
            return "Apple Music request failed with status \(error.status) and code \(error.code). Verify MusicKit setup and try again."
        }

        return "Apple Music request failed with status \(error.status): \(reason)"
    }

    private static func fallbackMessage(for error: Error) -> String {
        let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)

        if message.isEmpty || message.localizedCaseInsensitiveCompare("Unknown error") == .orderedSame {
            return unknownPlaylistErrorMessage
        }

        return message
    }
}

struct MusicPlaylistClient: MusicPlaylistProviding {
    private let subscriptionProvider: AppleMusicSubscriptionProviding
    private let playlistFetcher: () async throws -> [MusicPlaylistSummary]

    init(
        subscriptionProvider: AppleMusicSubscriptionProviding = AppleMusicSubscriptionClient(),
        playlistFetcher: @escaping () async throws -> [MusicPlaylistSummary] = MusicPlaylistClient.fetchLibraryPlaylists
    ) {
        self.subscriptionProvider = subscriptionProvider
        self.playlistFetcher = playlistFetcher
    }

    func fetchPlaylists() async throws -> [MusicPlaylistSummary] {
        let subscription = try await subscriptionProvider.currentStatus()
        guard subscription.hasCloudLibraryEnabled else {
            throw PlaylistLibraryError.cloudLibraryDisabled
        }

        guard subscription.canPlayCatalogContent else {
            throw PlaylistLibraryError.subscriptionRequired
        }

        return try await playlistFetcher()
    }

    private static func fetchLibraryPlaylists() async throws -> [MusicPlaylistSummary] {
        let request = MusicLibraryRequest<Playlist>()
        let response = try await request.response()

        return response.items.map { playlist in
            MusicPlaylistSummary(id: playlist.id.rawValue, name: playlist.name)
        }
    }
}

@MainActor
final class PlaylistLibraryViewModel: ObservableObject {
    @Published private(set) var state = PlaylistLibraryState.idle

    private let playlistProvider: MusicPlaylistProviding
    private let sampleLimit: Int

    init(
        playlistProvider: MusicPlaylistProviding = MusicPlaylistClient(),
        sampleLimit: Int = 0
    ) {
        self.playlistProvider = playlistProvider
        self.sampleLimit = sampleLimit
    }

    func loadPlaylists(permissionStatus: AppleMusicPermissionStatus) async {
        guard permissionStatus == .authorized else {
            state = .blockedByPermission
            return
        }

        state = .loading

        do {
            let playlists = try await playlistProvider.fetchPlaylists()
            state = .loaded(
                PlaylistLoadSummary(
                    count: playlists.count,
                    sampleNames: playlists.prefix(sampleLimit).map(\.name)
                )
            )
        } catch {
            state = .failed(PlaylistLibraryErrorMessage.make(from: error))
        }
    }

    func recordLoadedPlaylists(_ playlists: [MusicPlaylistSummary]) {
        state = .loaded(summary(for: playlists))
    }

    private func summary(for playlists: [MusicPlaylistSummary]) -> PlaylistLoadSummary {
        PlaylistLoadSummary(
            count: playlists.count,
            sampleNames: playlists.prefix(sampleLimit).map(\.name)
        )
    }
}
