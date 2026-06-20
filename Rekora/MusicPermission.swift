import Combine
import Foundation
import MusicKit

enum AppleMusicPermissionStatus: Equatable {
    case notDetermined
    case authorized
    case denied
    case restricted
    case unknown

    init(musicAuthorizationStatus: MusicAuthorization.Status) {
        switch musicAuthorizationStatus {
        case .notDetermined:
            self = .notDetermined
        case .authorized:
            self = .authorized
        case .denied:
            self = .denied
        case .restricted:
            self = .restricted
        @unknown default:
            self = .unknown
        }
    }
}

protocol MusicAuthorizationProviding {
    func currentStatus() -> AppleMusicPermissionStatus
    func requestAuthorization() async -> AppleMusicPermissionStatus
}

struct MusicAuthorizationClient: MusicAuthorizationProviding {
    func currentStatus() -> AppleMusicPermissionStatus {
        AppleMusicPermissionStatus(musicAuthorizationStatus: MusicAuthorization.currentStatus)
    }

    func requestAuthorization() async -> AppleMusicPermissionStatus {
        let status = await MusicAuthorization.request()
        return AppleMusicPermissionStatus(musicAuthorizationStatus: status)
    }
}

@MainActor
final class MusicPermissionViewModel: ObservableObject {
    @Published private(set) var status: AppleMusicPermissionStatus = .notDetermined
    @Published private(set) var isRequesting = false

    private let authorizationProvider: MusicAuthorizationProviding

    init(authorizationProvider: MusicAuthorizationProviding = MusicAuthorizationClient()) {
        self.authorizationProvider = authorizationProvider
    }

    func refreshStatus() {
        status = authorizationProvider.currentStatus()
    }

    func requestAccess() async {
        isRequesting = true
        status = await authorizationProvider.requestAuthorization()
        isRequesting = false
    }
}
