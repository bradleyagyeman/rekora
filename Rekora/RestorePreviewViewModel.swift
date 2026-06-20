import Foundation

enum RestorePreviewState: Equatable, Sendable {
    case loading
    case ready(RebuildPlanSummary)
    case checking(RebuildPlanSummary)
    case blockedByPermission(RebuildPlanSummary)
    case failed(String)
}

protocol SnapshotLoading {
    func loadSnapshot(fileName: String) throws -> SavedSnapshot
}

extension SnapshotStore: SnapshotLoading {}

@MainActor
final class RestorePreviewViewModel: ObservableObject {
    @Published private(set) var state: RestorePreviewState = .loading

    private let snapshotStore: SnapshotLoading
    private let matcher: LiveMusicTrackMatching

    init(
        snapshotStore: SnapshotLoading = SnapshotStore(),
        matcher: LiveMusicTrackMatching = AppleMusicLiveMatchClient()
    ) {
        self.snapshotStore = snapshotStore
        self.matcher = matcher
    }

    func load(fileName: String) async {
        state = .loading

        do {
            let savedSnapshot = try snapshotStore.loadSnapshot(fileName: fileName)
            state = .ready(RebuildPlan.make(from: savedSnapshot.snapshot))
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func checkMatches(
        fileName: String,
        permissionStatus: AppleMusicPermissionStatus
    ) async {
        do {
            let savedSnapshot = try snapshotStore.loadSnapshot(fileName: fileName)
            let localPlan = RebuildPlan.make(from: savedSnapshot.snapshot)

            guard permissionStatus == .authorized else {
                state = .blockedByPermission(localPlan)
                return
            }

            state = .checking(localPlan)

            let matches = try await matcher.matchTracks(
                for: playlistSongs(in: savedSnapshot.snapshot)
            )
            state = .ready(
                RebuildPlan.make(
                    from: savedSnapshot.snapshot,
                    liveMatches: matches
                )
            )
        } catch {
            state = .failed(PlaylistLibraryErrorMessage.make(from: error))
        }
    }

    private func playlistSongs(in snapshot: BackupSnapshot) -> [BackupSong] {
        let playlistSongIDs = Set(
            snapshot.playlists.flatMap { playlist in
                playlist.tracks.map(\.songID)
            }
        )

        return snapshot.songs.filter { playlistSongIDs.contains($0.id) }
    }
}
