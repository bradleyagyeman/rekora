import XCTest
@testable import Rekora

@MainActor
final class PlaylistLibraryTests: XCTestCase {
    func testLoadPlaylistsBlocksWithoutPermission() async {
        let model = PlaylistLibraryViewModel(
            playlistProvider: FakePlaylistProvider(result: .success([]))
        )

        await model.loadPlaylists(permissionStatus: .denied)

        XCTAssertEqual(model.state, .blockedByPermission)
    }

    func testLoadPlaylistsSummarizesFetchedPlaylists() async {
        let playlists = [
            MusicPlaylistSummary(id: "playlist-1", name: "Road Trip"),
            MusicPlaylistSummary(id: "playlist-2", name: "Gym"),
            MusicPlaylistSummary(id: "playlist-3", name: "Focus"),
            MusicPlaylistSummary(id: "playlist-4", name: "Dinner")
        ]
        let model = PlaylistLibraryViewModel(
            playlistProvider: FakePlaylistProvider(result: .success(playlists))
        )

        await model.loadPlaylists(permissionStatus: .authorized)

        XCTAssertEqual(
            model.state,
            .loaded(
                PlaylistLoadSummary(
                    count: 4,
                    sampleNames: []
                )
            )
        )
    }

    func testLoadPlaylistsCanIncludeSampleNamesWhenRequested() async {
        let playlists = [
            MusicPlaylistSummary(id: "playlist-1", name: "Road Trip"),
            MusicPlaylistSummary(id: "playlist-2", name: "Gym"),
            MusicPlaylistSummary(id: "playlist-3", name: "Focus")
        ]
        let model = PlaylistLibraryViewModel(
            playlistProvider: FakePlaylistProvider(result: .success(playlists)),
            sampleLimit: 2
        )

        await model.loadPlaylists(permissionStatus: .authorized)

        XCTAssertEqual(
            model.state,
            .loaded(
                PlaylistLoadSummary(
                    count: 3,
                    sampleNames: ["Road Trip", "Gym"]
                )
            )
        )
    }

    func testLoadPlaylistsSupportsEmptyLibraries() async {
        let model = PlaylistLibraryViewModel(
            playlistProvider: FakePlaylistProvider(result: .success([]))
        )

        await model.loadPlaylists(permissionStatus: .authorized)

        XCTAssertEqual(
            model.state,
            .loaded(PlaylistLoadSummary(count: 0, sampleNames: []))
        )
    }

    func testLoadPlaylistsReportsFailure() async {
        let model = PlaylistLibraryViewModel(
            playlistProvider: FakePlaylistProvider(result: .failure(FakePlaylistError.unavailable))
        )

        await model.loadPlaylists(permissionStatus: .authorized)

        XCTAssertEqual(model.state, .failed("Apple Music unavailable"))
    }

    func testLoadPlaylistsDoesNotSurfaceUnknownErrorWithoutContext() async {
        let model = PlaylistLibraryViewModel(
            playlistProvider: FakePlaylistProvider(result: .failure(FakePlaylistError.unknown))
        )

        await model.loadPlaylists(permissionStatus: .authorized)

        XCTAssertEqual(
            model.state,
            .failed(
                "Apple Music returned an unknown error while checking playlists. Verify the bundle ID, explicit App ID, MusicKit capability, signed-in Apple Music account, and real-device setup."
            )
        )
    }

    func testMusicPlaylistClientBlocksWhenCloudLibraryIsDisabled() async {
        let client = MusicPlaylistClient(
            subscriptionProvider: FakeSubscriptionProvider(
                result: .success(
                    AppleMusicSubscriptionStatus(
                        canPlayCatalogContent: true,
                        canBecomeSubscriber: false,
                        hasCloudLibraryEnabled: false
                    )
                )
            ),
            playlistFetcher: {
                [MusicPlaylistSummary(id: "playlist-1", name: "Road Trip")]
            }
        )

        do {
            _ = try await client.fetchPlaylists()
            XCTFail("Expected cloud library setup to block playlist fetching.")
        } catch {
            XCTAssertEqual(
                PlaylistLibraryErrorMessage.make(from: error),
                "Apple Music Sync Library is off for this account or device. Turn on Sync Library, then try again."
            )
        }
    }

    func testMusicPlaylistClientBlocksWhenSubscriptionIsMissing() async {
        let client = MusicPlaylistClient(
            subscriptionProvider: FakeSubscriptionProvider(
                result: .success(
                    AppleMusicSubscriptionStatus(
                        canPlayCatalogContent: false,
                        canBecomeSubscriber: true,
                        hasCloudLibraryEnabled: true
                    )
                )
            ),
            playlistFetcher: {
                [MusicPlaylistSummary(id: "playlist-1", name: "Road Trip")]
            }
        )

        do {
            _ = try await client.fetchPlaylists()
            XCTFail("Expected subscription setup to block playlist fetching.")
        } catch {
            XCTAssertEqual(
                PlaylistLibraryErrorMessage.make(from: error),
                "An active Apple Music subscription is needed before Rekora can read Apple Music library playlists."
            )
        }
    }
}

private struct FakePlaylistProvider: MusicPlaylistProviding {
    var result: Result<[MusicPlaylistSummary], Error>

    func fetchPlaylists() async throws -> [MusicPlaylistSummary] {
        try result.get()
    }
}

private enum FakePlaylistError: LocalizedError {
    case unavailable
    case unknown

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Apple Music unavailable"
        case .unknown:
            return "Unknown error"
        }
    }
}

private struct FakeSubscriptionProvider: AppleMusicSubscriptionProviding {
    var result: Result<AppleMusicSubscriptionStatus, Error>

    func currentStatus() async throws -> AppleMusicSubscriptionStatus {
        try result.get()
    }
}
