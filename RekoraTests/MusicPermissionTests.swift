import XCTest
@testable import Rekora

@MainActor
final class MusicPermissionTests: XCTestCase {
    func testRefreshStatusUsesCurrentAuthorizationStatus() {
        let model = MusicPermissionViewModel(
            authorizationProvider: FakeMusicAuthorizationProvider(
                currentAuthorizationStatus: .authorized,
                requestedAuthorizationStatus: .denied
            )
        )

        model.refreshStatus()

        XCTAssertEqual(model.status, .authorized)
        XCTAssertFalse(model.isRequesting)
    }

    func testRequestAccessUpdatesStatus() async {
        let model = MusicPermissionViewModel(
            authorizationProvider: FakeMusicAuthorizationProvider(
                currentAuthorizationStatus: .notDetermined,
                requestedAuthorizationStatus: .denied
            )
        )

        await model.requestAccess()

        XCTAssertEqual(model.status, .denied)
        XCTAssertFalse(model.isRequesting)
    }

    func testRequestAccessCanBecomeAuthorized() async {
        let model = MusicPermissionViewModel(
            authorizationProvider: FakeMusicAuthorizationProvider(
                currentAuthorizationStatus: .notDetermined,
                requestedAuthorizationStatus: .authorized
            )
        )

        await model.requestAccess()

        XCTAssertEqual(model.status, .authorized)
    }
}

private struct FakeMusicAuthorizationProvider: MusicAuthorizationProviding {
    var currentAuthorizationStatus: AppleMusicPermissionStatus
    var requestedAuthorizationStatus: AppleMusicPermissionStatus

    func currentStatus() -> AppleMusicPermissionStatus {
        currentAuthorizationStatus
    }

    func requestAuthorization() async -> AppleMusicPermissionStatus {
        requestedAuthorizationStatus
    }
}
