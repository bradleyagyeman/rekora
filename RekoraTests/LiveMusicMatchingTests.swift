import XCTest
@testable import Rekora

final class LiveMusicMatchingTests: XCTestCase {
    func testMatcherUsesLibraryIDBeforeOtherSearches() async throws {
        let matcher = AppleMusicLiveMatchClient(
            subscriptionProvider: FakeSubscriptionProvider(
                status: AppleMusicSubscriptionStatus(
                    canPlayCatalogContent: true,
                    canBecomeSubscriber: false,
                    hasCloudLibraryEnabled: true
                )
            ),
            songSearcher: FakeSongSearcher(
                librarySongsByID: [
                    "library-1": LiveMusicSongCandidate(
                        id: "library-1",
                        title: "Song",
                        artistName: "Artist"
                    )
                ]
            )
        )

        let matches = try await matcher.matchTracks(
            for: [
                BackupSong(
                    id: "song-1",
                    identifiers: MusicItemIdentifiers(
                        libraryID: "library-1",
                        catalogID: "catalog-1",
                        isrc: "USRC17607839"
                    ),
                    title: "Song",
                    artistName: "Artist"
                )
            ]
        )

        XCTAssertEqual(matches["song-1"]?.status, .matched)
        XCTAssertEqual(matches["song-1"]?.reason, .libraryID)
        XCTAssertEqual(matches["song-1"]?.matchedID, "library-1")
    }

    func testMatcherMarksAmbiguousISRCMatchesForReview() async throws {
        let matcher = AppleMusicLiveMatchClient(
            subscriptionProvider: FakeSubscriptionProvider.ready,
            songSearcher: FakeSongSearcher(
                catalogSongsByISRC: [
                    "USRC17607839": [
                        LiveMusicSongCandidate(
                            id: "candidate-1",
                            title: "Song",
                            artistName: "Artist"
                        ),
                        LiveMusicSongCandidate(
                            id: "candidate-2",
                            title: "Song",
                            artistName: "Artist"
                        )
                    ]
                ]
            )
        )

        let matches = try await matcher.matchTracks(
            for: [
                BackupSong(
                    id: "song-1",
                    identifiers: MusicItemIdentifiers(isrc: "USRC17607839"),
                    title: "Song",
                    artistName: "Artist"
                )
            ]
        )

        XCTAssertEqual(matches["song-1"]?.status, .needsReview)
        XCTAssertEqual(matches["song-1"]?.reason, .multipleCandidates)
    }

    func testMatcherFallsBackToCatalogIDWhenLibraryIDIsMissing() async throws {
        let matcher = AppleMusicLiveMatchClient(
            subscriptionProvider: FakeSubscriptionProvider.ready,
            songSearcher: FakeSongSearcher(
                catalogSongsByID: [
                    "catalog-1": LiveMusicSongCandidate(
                        id: "catalog-1",
                        title: "Song",
                        artistName: "Artist"
                    )
                ]
            )
        )

        let matches = try await matcher.matchTracks(
            for: [
                BackupSong(
                    id: "song-1",
                    identifiers: MusicItemIdentifiers(
                        libraryID: "missing-library",
                        catalogID: "catalog-1"
                    ),
                    title: "Song",
                    artistName: "Artist"
                )
            ]
        )

        XCTAssertEqual(matches["song-1"]?.status, .matched)
        XCTAssertEqual(matches["song-1"]?.reason, .catalogID)
        XCTAssertEqual(matches["song-1"]?.matchedID, "catalog-1")
    }

    func testMatcherFallsBackToAppleMusicIDWhenCatalogIDIsMissing() async throws {
        let matcher = AppleMusicLiveMatchClient(
            subscriptionProvider: FakeSubscriptionProvider.ready,
            songSearcher: FakeSongSearcher(
                catalogSongsByID: [
                    "apple-1": LiveMusicSongCandidate(
                        id: "apple-1",
                        title: "Song",
                        artistName: "Artist"
                    )
                ]
            )
        )

        let matches = try await matcher.matchTracks(
            for: [
                BackupSong(
                    id: "song-1",
                    identifiers: MusicItemIdentifiers(appleMusicID: "apple-1"),
                    title: "Song",
                    artistName: "Artist"
                )
            ]
        )

        XCTAssertEqual(matches["song-1"]?.status, .matched)
        XCTAssertEqual(matches["song-1"]?.reason, .appleMusicID)
        XCTAssertEqual(matches["song-1"]?.matchedID, "apple-1")
    }

    func testMatcherAutoMatchesUniqueISRCWithCoreIdentityAgreement() async throws {
        let matcher = AppleMusicLiveMatchClient(
            subscriptionProvider: FakeSubscriptionProvider.ready,
            songSearcher: FakeSongSearcher(
                catalogSongsByISRC: [
                    "USRC17607839": [
                        LiveMusicSongCandidate(
                            id: "isrc-song",
                            title: "Song",
                            artistName: "Artist"
                        )
                    ]
                ]
            )
        )

        let matches = try await matcher.matchTracks(
            for: [
                BackupSong(
                    id: "song-1",
                    identifiers: MusicItemIdentifiers(isrc: "USRC17607839"),
                    title: "Song",
                    artistName: "Artist"
                )
            ]
        )

        XCTAssertEqual(matches["song-1"]?.status, .matched)
        XCTAssertEqual(matches["song-1"]?.reason, .isrc)
        XCTAssertEqual(matches["song-1"]?.matchedID, "isrc-song")
    }

    func testMatcherUsesMetadataSearchWhenOnlyMetadataExists() async throws {
        let matcher = AppleMusicLiveMatchClient(
            subscriptionProvider: FakeSubscriptionProvider.ready,
            songSearcher: FakeSongSearcher(
                catalogSongsByTerm: [
                    "Song Artist Album": [
                        LiveMusicSongCandidate(
                            id: "catalog-song",
                            title: "Song",
                            artistName: "Artist",
                            albumTitle: "Album",
                            durationMilliseconds: 120_000
                        )
                    ]
                ]
            )
        )

        let matches = try await matcher.matchTracks(
            for: [
                BackupSong(
                    id: "song-1",
                    title: "Song",
                    artistName: "Artist",
                    albumTitle: "Album",
                    durationMilliseconds: 121_000
                )
            ]
        )

        XCTAssertEqual(matches["song-1"]?.status, .matched)
        XCTAssertEqual(matches["song-1"]?.reason, .metadata)
        XCTAssertEqual(matches["song-1"]?.matchedID, "catalog-song")
    }

    func testMatcherDoesNotAutoMatchMetadataWhenArtistDiffers() async throws {
        let matcher = AppleMusicLiveMatchClient(
            subscriptionProvider: FakeSubscriptionProvider.ready,
            songSearcher: FakeSongSearcher(
                catalogSongsByTerm: [
                    "Song Artist Album": [
                        LiveMusicSongCandidate(
                            id: "wrong-artist",
                            title: "Song",
                            artistName: "Different Artist",
                            albumTitle: "Album",
                            durationMilliseconds: 120_000
                        )
                    ]
                ]
            )
        )

        let matches = try await matcher.matchTracks(
            for: [
                BackupSong(
                    id: "song-1",
                    title: "Song",
                    artistName: "Artist",
                    albumTitle: "Album",
                    durationMilliseconds: 120_000
                )
            ]
        )

        XCTAssertEqual(matches["song-1"]?.status, .needsReview)
        XCTAssertEqual(matches["song-1"]?.reason, .multipleCandidates)
    }

    func testMatcherDoesNotAutoMatchISRCWhenCoreIdentityDiffers() async throws {
        let matcher = AppleMusicLiveMatchClient(
            subscriptionProvider: FakeSubscriptionProvider.ready,
            songSearcher: FakeSongSearcher(
                catalogSongsByISRC: [
                    "USRC17607839": [
                        LiveMusicSongCandidate(
                            id: "wrong-artist",
                            title: "Song",
                            artistName: "Different Artist"
                        )
                    ]
                ]
            )
        )

        let matches = try await matcher.matchTracks(
            for: [
                BackupSong(
                    id: "song-1",
                    identifiers: MusicItemIdentifiers(isrc: "USRC17607839"),
                    title: "Song",
                    artistName: "Artist"
                )
            ]
        )

        XCTAssertEqual(matches["song-1"]?.status, .needsReview)
        XCTAssertEqual(matches["song-1"]?.reason, .multipleCandidates)
    }

    func testMatcherDoesNotGuessWhenSongHasNoSearchData() async throws {
        let matcher = AppleMusicLiveMatchClient(
            subscriptionProvider: FakeSubscriptionProvider.ready,
            songSearcher: FakeSongSearcher()
        )

        let matches = try await matcher.matchTracks(
            for: [
                BackupSong(
                    id: "song-1",
                    title: "",
                    artistName: ""
                )
            ]
        )

        XCTAssertEqual(matches["song-1"]?.status, .notFound)
        XCTAssertEqual(matches["song-1"]?.reason, .missingSearchData)
    }

    func testMatcherReportsNotFoundWhenMetadataSearchHasNoCandidates() async throws {
        let matcher = AppleMusicLiveMatchClient(
            subscriptionProvider: FakeSubscriptionProvider.ready,
            songSearcher: FakeSongSearcher()
        )

        let matches = try await matcher.matchTracks(
            for: [
                BackupSong(
                    id: "song-1",
                    title: "Song",
                    artistName: "Artist"
                )
            ]
        )

        XCTAssertEqual(matches["song-1"]?.status, .notFound)
        XCTAssertEqual(matches["song-1"]?.reason, .noCandidate)
    }

    func testMatcherReportsFailedWhenLookupThrows() async throws {
        let matcher = AppleMusicLiveMatchClient(
            subscriptionProvider: FakeSubscriptionProvider.ready,
            songSearcher: FakeSongSearcher(error: FakeSongSearchError.unavailable)
        )

        let matches = try await matcher.matchTracks(
            for: [
                BackupSong(
                    id: "song-1",
                    identifiers: MusicItemIdentifiers(libraryID: "library-1"),
                    title: "Song",
                    artistName: "Artist"
                )
            ]
        )

        XCTAssertEqual(matches["song-1"]?.status, .failed)
        XCTAssertEqual(matches["song-1"]?.reason, .requestFailed)
    }

    func testMatcherRequiresSyncLibraryAndSubscription() async {
        let matcher = AppleMusicLiveMatchClient(
            subscriptionProvider: FakeSubscriptionProvider(
                status: AppleMusicSubscriptionStatus(
                    canPlayCatalogContent: false,
                    canBecomeSubscriber: true,
                    hasCloudLibraryEnabled: true
                )
            ),
            songSearcher: FakeSongSearcher()
        )

        do {
            _ = try await matcher.matchTracks(for: [])
            XCTFail("Expected subscription setup to block live matching.")
        } catch {
            XCTAssertEqual(error as? PlaylistLibraryError, .subscriptionRequired)
        }
    }

    func testMatcherRequiresCloudLibrary() async {
        let matcher = AppleMusicLiveMatchClient(
            subscriptionProvider: FakeSubscriptionProvider(
                status: AppleMusicSubscriptionStatus(
                    canPlayCatalogContent: true,
                    canBecomeSubscriber: false,
                    hasCloudLibraryEnabled: false
                )
            ),
            songSearcher: FakeSongSearcher()
        )

        do {
            _ = try await matcher.matchTracks(for: [])
            XCTFail("Expected cloud library setup to block live matching.")
        } catch {
            XCTAssertEqual(error as? PlaylistLibraryError, .cloudLibraryDisabled)
        }
    }
}

private struct FakeSubscriptionProvider: AppleMusicSubscriptionProviding {
    static let ready = FakeSubscriptionProvider(
        status: AppleMusicSubscriptionStatus(
            canPlayCatalogContent: true,
            canBecomeSubscriber: false,
            hasCloudLibraryEnabled: true
        )
    )

    var status: AppleMusicSubscriptionStatus

    func currentStatus() async throws -> AppleMusicSubscriptionStatus {
        status
    }
}

private struct FakeSongSearcher: MusicSongSearching {
    var librarySongsByID: [String: LiveMusicSongCandidate] = [:]
    var catalogSongsByID: [String: LiveMusicSongCandidate] = [:]
    var catalogSongsByISRC: [String: [LiveMusicSongCandidate]] = [:]
    var catalogSongsByTerm: [String: [LiveMusicSongCandidate]] = [:]
    var error: Error?

    func librarySong(id: String) async throws -> LiveMusicSongCandidate? {
        if let error {
            throw error
        }
        return librarySongsByID[id]
    }

    func catalogSong(id: String) async throws -> LiveMusicSongCandidate? {
        if let error {
            throw error
        }
        return catalogSongsByID[id]
    }

    func catalogSongs(isrc: String) async throws -> [LiveMusicSongCandidate] {
        if let error {
            throw error
        }
        return catalogSongsByISRC[isrc, default: []]
    }

    func catalogSongs(term: String) async throws -> [LiveMusicSongCandidate] {
        if let error {
            throw error
        }
        return catalogSongsByTerm[term, default: []]
    }
}

private enum FakeSongSearchError: Error {
    case unavailable
}
