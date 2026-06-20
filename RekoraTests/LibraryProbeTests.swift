import XCTest
@testable import Rekora

@MainActor
final class LibraryProbeTests: XCTestCase {
    func testInspectBlocksWithoutPermission() async {
        let model = LibraryProbeViewModel(
            probe: FakeLibraryProbe(result: .success(.sample))
        )

        await model.inspect(permissionStatus: .denied)

        XCTAssertEqual(model.state, .blockedByPermission)
    }

    func testInspectPublishesCompletedReport() async {
        let report = LibraryProbeReport(
            songCount: 10,
            albumCount: 4,
            playlistCount: 3,
            checkedPlaylistCount: 3,
            playlistTrackCount: 22,
            playlistTracksReadable: true,
            playlistOrderReadable: true,
            playlistTracksWithAddedDateCount: 20,
            missingTrackIdentifierCount: 1,
            missingTrackTitleCount: 0,
            failedPlaylistTrackCount: 0,
            duration: 1.2
        )
        let model = LibraryProbeViewModel(
            probe: FakeLibraryProbe(result: .success(report))
        )

        await model.inspect(permissionStatus: .authorized)

        XCTAssertEqual(model.state, .completed(report))
    }

    func testInspectPublishesFailure() async {
        let model = LibraryProbeViewModel(
            probe: FakeLibraryProbe(result: .failure(FakeLibraryProbeError.unavailable))
        )

        await model.inspect(permissionStatus: .authorized)

        XCTAssertEqual(model.state, .failed("Apple Music unavailable"))
    }
}

private struct FakeLibraryProbe: LibraryProbing {
    var result: Result<LibraryProbeReport, Error>

    func inspectLibrary() async throws -> LibraryProbeReport {
        try result.get()
    }
}

private enum FakeLibraryProbeError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        "Apple Music unavailable"
    }
}

private extension LibraryProbeReport {
    static let sample = LibraryProbeReport(
        songCount: 1,
        albumCount: 1,
        playlistCount: 1,
        checkedPlaylistCount: 1,
        playlistTrackCount: 1,
        playlistTracksReadable: true,
        playlistOrderReadable: true,
        playlistTracksWithAddedDateCount: 1,
        missingTrackIdentifierCount: 0,
        missingTrackTitleCount: 0,
        failedPlaylistTrackCount: 0,
        duration: 0.4
    )
}
