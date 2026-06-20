import XCTest
@testable import Rekora

@MainActor
final class PlaylistRebuildViewModelTests: XCTestCase {
    func testPrepareConfirmationRequiresAppleMusicPermission() {
        let model = PlaylistRebuildViewModel(service: FakePlaylistRebuildService())

        model.prepareConfirmation(
            playlistID: "playlist-1",
            plan: PlaylistRebuildFixtures.makePlan(liveChecked: true),
            permissionStatus: .denied
        )

        XCTAssertEqual(
            model.state,
            .failed("Allow Apple Music access before rebuilding a playlist.")
        )
    }

    func testPrepareConfirmationRequiresLiveMatchCheck() {
        let model = PlaylistRebuildViewModel(service: FakePlaylistRebuildService())

        model.prepareConfirmation(
            playlistID: "playlist-1",
            plan: PlaylistRebuildFixtures.makePlan(liveChecked: false),
            permissionStatus: .authorized
        )

        XCTAssertEqual(
            model.state,
            .failed("Check Apple Music matches before rebuilding a playlist.")
        )
    }

    func testPrepareConfirmationBuildsNewPlaylistRequest() throws {
        let model = PlaylistRebuildViewModel(service: FakePlaylistRebuildService())

        model.prepareConfirmation(
            playlistID: "playlist-1",
            plan: PlaylistRebuildFixtures.makePlan(liveChecked: true),
            permissionStatus: .authorized
        )

        guard case .confirming(let request) = model.state else {
            return XCTFail("Expected rebuild confirmation.")
        }
        XCTAssertEqual(request.sourcePlaylistName, "Favorites")
        XCTAssertEqual(request.newPlaylistName, "Rekora Restore - Favorites")
        XCTAssertEqual(request.matchedTracks.map(\.songID), ["song-1", "song-1"])
        XCTAssertEqual(request.matchedTracks.map { $0.match.matchedID }, ["live-song-1", "live-song-1"])
        XCTAssertEqual(request.skippedTrackCount, 1)
        XCTAssertEqual(request.totalTrackCount, 3)
    }

    func testConfirmRebuildDoesNotCallWriterUntilUserConfirms() async throws {
        let service = RecordingPlaylistRebuildService()
        let model = PlaylistRebuildViewModel(service: service)

        model.prepareConfirmation(
            playlistID: "playlist-1",
            plan: PlaylistRebuildFixtures.makePlan(liveChecked: true),
            permissionStatus: .authorized
        )

        XCTAssertTrue(service.requests.isEmpty)

        await model.confirmRebuild()

        XCTAssertEqual(service.requests.map(\.newPlaylistName), ["Rekora Restore - Favorites"])
        guard case .completed(let result) = model.state else {
            return XCTFail("Expected completed rebuild.")
        }
        XCTAssertEqual(result.createdPlaylist.name, "Rekora Restore - Favorites")
        XCTAssertEqual(result.addedTrackCount, 2)
        XCTAssertEqual(result.skippedTrackCount, 1)
    }

    func testCancelConfirmationAvoidsWriterCall() {
        let service = RecordingPlaylistRebuildService()
        let model = PlaylistRebuildViewModel(service: service)

        model.prepareConfirmation(
            playlistID: "playlist-1",
            plan: PlaylistRebuildFixtures.makePlan(liveChecked: true),
            permissionStatus: .authorized
        )
        model.cancelConfirmation()

        XCTAssertEqual(model.state, .idle)
        XCTAssertTrue(service.requests.isEmpty)
    }
}

final class PlaylistRebuildRequestTests: XCTestCase {
    func testRequestPreservesOrderAndDuplicateMatchedTracks() throws {
        let request = try PlaylistRebuildRequest.make(
            from: PlaylistRebuildFixtures.makePlaylist(liveChecked: true)
        )

        XCTAssertEqual(request.matchedTracks.map(\.songID), ["song-1", "song-1"])
        XCTAssertEqual(request.matchedTracks.map(\.order), [0, 2])
        XCTAssertEqual(request.skippedTrackCount, 1)
        XCTAssertEqual(request.preview.matchedTrackCount, 2)
        XCTAssertEqual(request.preview.skippedTrackCount, 1)
    }

    func testRequestSkipsMetadataOnlyMatchesInsteadOfGuessing() throws {
        let playlist = PlaylistRebuildPlan(
            playlistID: "playlist-1",
            name: "Favorites",
            tracks: [
                RebuildTrackPlan(
                    playlistID: "playlist-1",
                    songID: "song-1",
                    title: "Song",
                    artistName: "Artist",
                    order: 0,
                    readiness: .metadataOnly,
                    liveMatch: LiveMusicTrackMatch(
                        songID: "song-1",
                        status: .matched,
                        matchedID: "metadata-match",
                        reason: .metadata
                    )
                ),
                RebuildTrackPlan(
                    playlistID: "playlist-1",
                    songID: "song-2",
                    title: "Other Song",
                    artistName: "Artist",
                    order: 1,
                    readiness: .strongIdentifier,
                    liveMatch: LiveMusicTrackMatch(
                        songID: "song-2",
                        status: .matched,
                        matchedID: "catalog-match",
                        reason: .catalogID
                    )
                )
            ],
            usesObservedOrder: false
        )

        let request = try PlaylistRebuildRequest.make(from: playlist)

        XCTAssertEqual(request.matchedTracks.map(\.songID), ["song-2"])
        XCTAssertEqual(request.skippedTrackCount, 1)
    }

    func testRequestRejectsPlaylistWithNoMatchedTracks() {
        XCTAssertThrowsError(
            try PlaylistRebuildRequest.make(from: PlaylistRebuildFixtures.makePlaylist(liveChecked: false))
        ) { error in
            XCTAssertEqual(error as? PlaylistRebuildError, .noMatchedTracks)
        }
    }

    func testRestoredPlaylistNameIsExplicitAndBounded() {
        XCTAssertEqual(
            PlaylistRebuildNamer.restoredPlaylistName(for: "Favorites"),
            "Rekora Restore - Favorites"
        )
        XCTAssertEqual(
            PlaylistRebuildNamer.restoredPlaylistName(for: "   "),
            "Rekora Restore - Untitled Playlist"
        )
        XCTAssertLessThanOrEqual(
            PlaylistRebuildNamer.restoredPlaylistName(for: String(repeating: "A", count: 200)).count,
            100
        )
    }
}

final class PlaylistRebuildServiceTests: XCTestCase {
    func testServiceDelegatesCreatePlaylistWithRequestDetails() async throws {
        let writer = RecordingPlaylistWriter()
        let service = PlaylistRebuildService(writer: writer)
        let request = try PlaylistRebuildRequest.make(
            from: PlaylistRebuildFixtures.makePlaylist(liveChecked: true)
        )

        let result = try await service.rebuild(request)

        XCTAssertEqual(writer.calls.count, 1)
        XCTAssertEqual(writer.calls.first?.name, "Rekora Restore - Favorites")
        XCTAssertEqual(
            writer.calls.first?.description,
            "Created by Rekora from the backup playlist \"Favorites\"."
        )
        XCTAssertEqual(writer.calls.first?.matchedTracks.map(\.songID), ["song-1", "song-1"])
        XCTAssertEqual(result.createdPlaylist.name, "Rekora Restore - Favorites")
        XCTAssertEqual(result.addedTrackCount, 2)
        XCTAssertEqual(result.skippedTrackCount, 1)
        XCTAssertEqual(result.totalTrackCount, 3)
    }
}

private struct FakePlaylistRebuildService: PlaylistRebuilding {
    func rebuild(_ request: PlaylistRebuildRequest) async throws -> PlaylistRebuildResult {
        PlaylistRebuildResult(
            sourcePlaylistName: request.sourcePlaylistName,
            createdPlaylist: MusicPlaylistSummary(id: "created-playlist", name: request.newPlaylistName),
            addedTrackCount: request.matchedTracks.count,
            skippedTrackCount: request.skippedTrackCount,
            totalTrackCount: request.totalTrackCount
        )
    }
}

private final class RecordingPlaylistWriter: MusicPlaylistWriting {
    struct Call: Equatable {
        var name: String
        var description: String?
        var matchedTracks: [MatchedPlaylistTrack]
    }

    private(set) var calls: [Call] = []

    func createPlaylist(
        name: String,
        description: String?,
        matchedTracks: [MatchedPlaylistTrack]
    ) async throws -> MusicPlaylistSummary {
        calls.append(
            Call(
                name: name,
                description: description,
                matchedTracks: matchedTracks
            )
        )

        return MusicPlaylistSummary(id: "created-playlist", name: name)
    }
}

@MainActor
private final class RecordingPlaylistRebuildService: PlaylistRebuilding {
    private(set) var requests: [PlaylistRebuildRequest] = []

    func rebuild(_ request: PlaylistRebuildRequest) async throws -> PlaylistRebuildResult {
        requests.append(request)

        return PlaylistRebuildResult(
            sourcePlaylistName: request.sourcePlaylistName,
            createdPlaylist: MusicPlaylistSummary(id: "created-playlist", name: request.newPlaylistName),
            addedTrackCount: request.matchedTracks.count,
            skippedTrackCount: request.skippedTrackCount,
            totalTrackCount: request.totalTrackCount
        )
    }
}

private enum PlaylistRebuildFixtures {
    static func makePlan(liveChecked: Bool) -> RebuildPlanSummary {
        RebuildPlanSummary(
            snapshotCreatedAt: Date(timeIntervalSince1970: 0),
            playlists: [makePlaylist(liveChecked: liveChecked)]
        )
    }

    static func makePlaylist(liveChecked: Bool) -> PlaylistRebuildPlan {
        PlaylistRebuildPlan(
            playlistID: "playlist-1",
            name: "Favorites",
            tracks: [
                makeTrack(
                    songID: "song-1",
                    order: 0,
                    liveMatch: liveChecked ? matchedTrack(songID: "song-1") : nil
                ),
                makeTrack(
                    songID: "song-2",
                    order: 1,
                    liveMatch: liveChecked
                        ? LiveMusicTrackMatch(
                            songID: "song-2",
                            status: .needsReview,
                            reason: .multipleCandidates
                        )
                        : nil
                ),
                makeTrack(
                    songID: "song-1",
                    order: 2,
                    liveMatch: liveChecked ? matchedTrack(songID: "song-1") : nil
                )
            ],
            usesObservedOrder: true
        )
    }

    static func makeTrack(
        songID: String,
        order: Int,
        liveMatch: LiveMusicTrackMatch?
    ) -> RebuildTrackPlan {
        RebuildTrackPlan(
            playlistID: "playlist-1",
            songID: songID,
            title: songID == "song-1" ? "Song" : "Other Song",
            artistName: "Artist",
            order: order,
            readiness: .strongIdentifier,
            liveMatch: liveMatch
        )
    }

    static func matchedTrack(songID: String) -> LiveMusicTrackMatch {
        LiveMusicTrackMatch(
            songID: songID,
            status: .matched,
            matchedID: "live-\(songID)",
            title: "Song",
            artistName: "Artist",
            reason: .catalogID
        )
    }
}
