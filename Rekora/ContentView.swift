import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var musicPermissionModel = MusicPermissionViewModel()
    @StateObject private var playlistLibraryModel = PlaylistLibraryViewModel()
    @StateObject private var libraryProbeModel = LibraryProbeViewModel()
    @State private var snapshotStatus = SnapshotSaveStatus.ready
    @State private var backupImportStatus = BackupImportStatus.idle
    @State private var isImportPresented = false

    private let snapshotStore = SnapshotStore()
    private let backupProvider = AppleMusicBackupClient()
    private let palette = AppTheme.light

    var body: some View {
        NavigationStack {
            ZStack {
                palette.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 30) {
                            IdentityBlock(palette: palette)

                            StatusSection(title: AppCopy.sectionPermission, palette: palette) {
                                PermissionContent(
                                    palette: palette,
                                    status: musicPermissionModel.status,
                                    isRequesting: musicPermissionModel.isRequesting,
                                    requestAccess: requestAccessTask
                                )
                            }

                            StatusSection(title: AppCopy.sectionBackup, palette: palette) {
                                SnapshotContent(
                                    palette: palette,
                                    status: snapshotStatus,
                                    permissionStatus: musicPermissionModel.status
                                )
                            }

                            StatusSection(title: AppCopy.sectionImport, palette: palette) {
                                BackupImportContent(
                                    palette: palette,
                                    status: backupImportStatus,
                                    chooseFile: presentImportPicker
                                )
                            }

                            if Self.showsDeveloperValidation {
                                StatusSection(title: AppCopy.sectionPlaylists, palette: palette) {
                                    PlaylistContent(
                                        palette: palette,
                                        state: playlistLibraryModel.state,
                                        permissionStatus: musicPermissionModel.status,
                                        loadPlaylists: loadPlaylistsTask
                                    )
                                }

                                StatusSection(title: AppCopy.libraryProbeTitle, palette: palette) {
                                    LibraryProbeContent(
                                        palette: palette,
                                        state: libraryProbeModel.state,
                                        permissionStatus: musicPermissionModel.status,
                                        inspectLibrary: inspectLibraryTask
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        .padding(.bottom, 20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .scrollIndicators(.hidden)

                    PrimaryActionBar(
                        palette: palette,
                        isWorking: snapshotStatus.isSaving,
                        action: createBackupAction
                    )
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .tint(palette.accent)
        .preferredColorScheme(.light)
        .task {
            musicPermissionModel.refreshStatus()
            loadLatestManifest()
        }
        .fileImporter(
            isPresented: $isImportPresented,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false,
            onCompletion: handleImportSelection
        )
    }

    private func requestAccessTask() async {
        await musicPermissionModel.requestAccess()
    }

    private func loadPlaylistsTask() async {
        await playlistLibraryModel.loadPlaylists(
            permissionStatus: musicPermissionModel.status
        )
    }

    private func inspectLibraryTask() async {
        guard Self.showsDeveloperValidation else {
            return
        }

        await libraryProbeModel.inspect(
            permissionStatus: musicPermissionModel.status
        )
    }

    private func createBackupAction() {
        Task { await createBackup() }
    }

    private func presentImportPicker() {
        isImportPresented = true
    }

    private func handleImportSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                backupImportStatus = .failed(AppCopy.backupImportNoSelectionMessage)
                return
            }

            validateImport(at: url)
        case .failure:
            backupImportStatus = .failed(AppCopy.backupImportFailedMessage)
        }
    }

    private func validateImport(at url: URL) {
        backupImportStatus = .checking

        Task {
            do {
                let summary = try await Task.detached(priority: .userInitiated) {
                    try BackupImportValidator.validate(fileURL: url)
                }.value

                await MainActor.run {
                    backupImportStatus = .valid(summary)
                }
            } catch let error as BackupImportValidationError {
                await MainActor.run {
                    backupImportStatus = .failed(error.userMessage)
                }
            } catch {
                await MainActor.run {
                    backupImportStatus = .failed(AppCopy.backupImportFailedMessage)
                }
            }
        }
    }

    private func createBackup() async {
        guard musicPermissionModel.status == .authorized else {
            snapshotStatus = .failed(AppCopy.snapshotNeedsPermissionMessage)
            return
        }

        snapshotStatus = .saving

        do {
            let snapshot = try await backupProvider.createSnapshot()
            let savedSnapshot = try snapshotStore.save(snapshot)
            playlistLibraryModel.recordLoadedPlaylists(
                snapshot.playlists.map { playlist in
                    MusicPlaylistSummary(id: playlist.id, name: playlist.name)
                }
            )
            snapshotStatus = .saved(savedSnapshot.manifest)
        } catch {
            snapshotStatus = .failed(PlaylistLibraryErrorMessage.make(from: error))
        }
    }

    private func loadLatestManifest() {
        do {
            if let manifest = try snapshotStore.loadLatestManifest() {
                snapshotStatus = .saved(manifest)
            }
        } catch {
            snapshotStatus = .failed(error.localizedDescription)
        }
    }

    private static var showsDeveloperValidation: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-RekoraDeveloperValidation")
        #else
        false
        #endif
    }
}

// MARK: - Identity

private struct IdentityBlock: View {
    var palette: AppTheme.Palette

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(AppCopy.title)
                .font(.title.weight(.semibold))
                .tracking(-0.3)
                .foregroundStyle(palette.textPrimary)
                .accessibilityAddTraits(.isHeader)

            Text(AppCopy.tagline)
                .font(.callout)
                .foregroundStyle(palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "lock.shield")
                    .imageScale(.small)
                    .accessibilityHidden(true)

                Text(AppCopy.privacyNote)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.footnote)
            .foregroundStyle(palette.textMuted)
            .padding(.top, 2)
        }
    }
}

// MARK: - Section scaffold

private struct StatusSection<Content: View>: View {
    var title: String
    var palette: AppTheme.Palette
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .textCase(.uppercase)
                    .tracking(1.6)
                    .foregroundStyle(palette.textMuted)
                    .fixedSize()

                Rectangle()
                    .fill(palette.divider)
                    .frame(height: 0.5)
            }

            content()
        }
    }
}

// MARK: - Status tone + row

private enum StatusTone: Equatable {
    case idle, working, ok, alert

    var symbolName: String {
        switch self {
        case .idle:    "circle"
        case .working: "circle.dotted"
        case .ok:      "checkmark"
        case .alert:   "exclamationmark"
        }
    }

    func color(palette: AppTheme.Palette) -> Color {
        switch self {
        case .idle:    palette.textMuted
        case .working: palette.textSecondary
        case .ok:      palette.accent
        case .alert:   palette.textPrimary
        }
    }
}

private struct StatusRow<Trailing: View>: View {
    var palette: AppTheme.Palette
    var tone: StatusTone
    var title: String
    var detail: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: tone.symbolName)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(tone.color(palette: palette))
                .frame(width: 16, height: 18, alignment: .center)
                .padding(.top, 3)
                .contentTransition(.symbolEffect(.replace))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                trailing()
            }
        }
    }
}

private struct InlineWarningNote: View {
    var palette: AppTheme.Palette
    var text: String

    private let background = Color(.sRGB, red: 0.98, green: 0.93, blue: 0.82, opacity: 1.0)
    private let border = Color(.sRGB, red: 0.84, green: 0.66, blue: 0.34, opacity: 1.0)
    private let icon = Color(.sRGB, red: 0.56, green: 0.38, blue: 0.08, opacity: 1.0)

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(icon)
                .frame(width: 16, height: 16)
                .accessibilityHidden(true)

            Text(text)
                .font(.footnote.weight(.medium))
                .foregroundStyle(palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(background, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(border.opacity(0.65), lineWidth: 1)
        }
        .padding(.top, 4)
        .accessibilityElement(children: .combine)
    }
}

extension StatusRow where Trailing == EmptyView {
    init(palette: AppTheme.Palette, tone: StatusTone, title: String, detail: String) {
        self.init(palette: palette, tone: tone, title: title, detail: detail) {
            EmptyView()
        }
    }
}

// MARK: - Inline action button

private struct InlineActionButton: View {
    var title: String
    var isDisabled: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .disabled(isDisabled)
        .padding(.top, 8)
    }
}

// MARK: - Permission content

private struct PermissionContent: View {
    var palette: AppTheme.Palette
    var status: AppleMusicPermissionStatus
    var isRequesting: Bool
    var requestAccess: () async -> Void

    var body: some View {
        StatusRow(palette: palette, tone: tone, title: title, detail: detail) {
            if showAction {
                InlineActionButton(
                    title: AppCopy.musicPermissionActionTitle,
                    isDisabled: isRequesting
                ) {
                    Task { await requestAccess() }
                }
            }
        }
    }

    private var tone: StatusTone {
        if isRequesting { return .working }
        switch status {
        case .notDetermined, .unknown: return .idle
        case .authorized:              return .ok
        case .denied, .restricted:     return .alert
        }
    }

    private var title: String {
        if isRequesting { return AppCopy.musicPermissionLoadingTitle }
        switch status {
        case .notDetermined: return "Apple Music access needed"
        case .authorized:    return "Apple Music access allowed"
        case .denied:        return "Apple Music access denied"
        case .restricted:    return "Apple Music access unavailable"
        case .unknown:       return "Apple Music access unknown"
        }
    }

    private var detail: String {
        if isRequesting { return AppCopy.musicPermissionRequestingMessage }
        switch status {
        case .notDetermined: return "Allow access before Rekora can make real Apple Music backups."
        case .authorized:    return "Rekora can ask Apple Music for library data when playlist backup is added."
        case .denied:        return "Rekora cannot make real backups until Apple Music access is allowed in Settings."
        case .restricted:    return "Apple Music access is restricted on this device or account."
        case .unknown:       return "Rekora cannot confirm Apple Music access on this device yet."
        }
    }

    private var showAction: Bool { status == .notDetermined }
}

// MARK: - Playlist content

private struct PlaylistContent: View {
    var palette: AppTheme.Palette
    var state: PlaylistLibraryState
    var permissionStatus: AppleMusicPermissionStatus
    var loadPlaylists: () async -> Void

    var body: some View {
        StatusRow(palette: palette, tone: tone, title: title, detail: detail) {
            if canLoad {
                InlineActionButton(
                    title: AppCopy.playlistActionTitle,
                    isDisabled: state.isLoading
                ) {
                    Task { await loadPlaylists() }
                }
            }
        }
    }

    private var tone: StatusTone {
        switch state {
        case .idle, .blockedByPermission: return .idle
        case .loading:                    return .working
        case .loaded:                     return .ok
        case .failed:                     return .alert
        }
    }

    private var title: String {
        switch state {
        case .idle, .blockedByPermission, .loading:
            return AppCopy.playlistReadyTitle
        case .loaded(let summary):
            return "\(summary.count) \(summary.count == 1 ? "playlist" : "playlists") found"
        case .failed:
            return AppCopy.playlistFailedTitle
        }
    }

    private var detail: String {
        switch state {
        case .idle:
            if permissionStatus == .authorized {
                return AppCopy.playlistAuthorizedMessage
            }
            return AppCopy.playlistReadyMessage
        case .loading:
            return AppCopy.playlistLoadingMessage
        case .loaded(let summary):
            if summary.count == 0 {
                return "No Apple Music playlists were found."
            }
            return "Rekora can read playlist metadata. Track backup comes next."
        case .blockedByPermission:
            return AppCopy.playlistBlockedMessage
        case .failed(let errorMessage):
            return errorMessage
        }
    }

    private var canLoad: Bool {
        permissionStatus == .authorized && state.isLoading == false
    }
}

// MARK: - Snapshot section content

private enum SnapshotSaveStatus: Equatable {
    case ready
    case saving
    case saved(SnapshotManifest)
    case failed(String)

    var isSaving: Bool {
        if case .saving = self {
            return true
        }
        return false
    }
}

private enum BackupImportStatus: Equatable {
    case idle
    case checking
    case valid(BackupImportSummary)
    case failed(String)

    var isChecking: Bool {
        if case .checking = self {
            return true
        }
        return false
    }
}

private struct SnapshotContent: View {
    var palette: AppTheme.Palette
    var status: SnapshotSaveStatus
    var permissionStatus: AppleMusicPermissionStatus

    var body: some View {
        StatusRow(palette: palette, tone: tone, title: title, detail: detail) {
            if case .saved(let manifest) = status {
                if let warningText = SnapshotStatusCopy.playlistOrderSummaryText(for: manifest) {
                    InlineWarningNote(palette: palette, text: warningText)
                }

                NavigationLink {
                    BackupDetailView(
                        palette: palette,
                        manifest: manifest,
                        permissionStatus: permissionStatus
                    )
                } label: {
                    HStack(spacing: 4) {
                        Text(AppCopy.snapshotViewDetailsTitle)
                        Image(systemName: "chevron.right")
                            .imageScale(.small)
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(palette.accent)
                    .padding(.top, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var tone: StatusTone {
        switch status {
        case .ready:  .idle
        case .saving: .working
        case .saved:  .ok
        case .failed: .alert
        }
    }

    private var title: String {
        switch status {
        case .ready, .saving: AppCopy.snapshotReadyTitle
        case .saved:          AppCopy.snapshotSavedTitle
        case .failed:         AppCopy.snapshotFailedTitle
        }
    }

    private var detail: String {
        switch status {
        case .ready:
            AppCopy.snapshotReadyMessage
        case .saving:
            AppCopy.snapshotSavingMessage
        case .saved(let manifest):
            SnapshotStatusCopy.savedDetailText(for: manifest)
        case .failed(let errorMessage):
            errorMessage
        }
    }
}

// MARK: - Backup import content

private struct BackupImportContent: View {
    var palette: AppTheme.Palette
    var status: BackupImportStatus
    var chooseFile: () -> Void

    var body: some View {
        StatusRow(palette: palette, tone: tone, title: title, detail: detail) {
            if case .valid(let summary) = status {
                BackupImportReadout(palette: palette, summary: summary)
                    .padding(.top, 12)
            }

            InlineActionButton(
                title: actionTitle,
                isDisabled: status.isChecking,
                action: chooseFile
            )
        }
    }

    private var tone: StatusTone {
        switch status {
        case .idle:     .idle
        case .checking: .working
        case .valid:    .ok
        case .failed:   .alert
        }
    }

    private var title: String {
        switch status {
        case .idle:     AppCopy.backupImportReadyTitle
        case .checking: AppCopy.backupImportCheckingTitle
        case .valid:    AppCopy.backupImportValidTitle
        case .failed:   AppCopy.backupImportFailedTitle
        }
    }

    private var detail: String {
        switch status {
        case .idle:
            AppCopy.backupImportReadyMessage
        case .checking:
            AppCopy.backupImportCheckingMessage
        case .valid(let summary):
            BackupImportStatusCopy.validDetailText(for: summary)
        case .failed(let message):
            message
        }
    }

    private var actionTitle: String {
        switch status {
        case .idle, .checking:
            AppCopy.backupImportActionTitle
        case .valid, .failed:
            AppCopy.backupImportAnotherActionTitle
        }
    }
}

private struct BackupImportReadout: View {
    var palette: AppTheme.Palette
    var summary: BackupImportSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(BackupImportStatusCopy.countSummaryText(for: summary))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text("\(summary.playlistTrackCount) playlist tracks")
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
                .monospacedDigit()

            Text(BackupImportStatusCopy.metadataText(for: summary))
                .font(.footnote)
                .foregroundStyle(palette.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Snapshot changes

private enum SnapshotDiffStatus: Equatable, Sendable {
    case loading
    case unavailable
    case ready(SnapshotDiffSummary)
    case failed(String)
}

private struct SnapshotChangesContent: View {
    var palette: AppTheme.Palette
    var status: SnapshotDiffStatus

    var body: some View {
        StatusRow(palette: palette, tone: tone, title: title, detail: detail) {
            if case .ready(let diff) = status, diff.hasChanges {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(SnapshotDiffStatusCopy.rows(for: diff), id: \.self) { row in
                        Text(row)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(palette.textPrimary)
                            .monospacedDigit()
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.top, 8)
            }
        }
    }

    private var tone: StatusTone {
        switch status {
        case .loading:     .working
        case .unavailable: .idle
        case .ready:       .ok
        case .failed:      .alert
        }
    }

    private var title: String {
        switch status {
        case .loading:
            AppCopy.snapshotChangesLoadingTitle
        case .unavailable:
            AppCopy.snapshotChangesUnavailableTitle
        case .ready(let diff):
            diff.hasChanges ? AppCopy.snapshotChangesChangedTitle : AppCopy.snapshotChangesUnchangedTitle
        case .failed:
            AppCopy.snapshotChangesFailedTitle
        }
    }

    private var detail: String {
        switch status {
        case .loading:
            AppCopy.snapshotChangesLoadingMessage
        case .unavailable:
            AppCopy.snapshotChangesUnavailableMessage
        case .ready(let diff):
            SnapshotDiffStatusCopy.detailText(for: diff)
        case .failed(let message):
            message
        }
    }
}

// MARK: - Restore preview

private struct RebuildPlanContent: View {
    var palette: AppTheme.Palette
    var state: RestorePreviewState
    var rebuildState: PlaylistRebuildState
    var checkMatches: () -> Void
    var requestRebuild: (String) -> Void
    var confirmRebuild: () -> Void
    var cancelRebuild: () -> Void

    var body: some View {
        StatusRow(palette: palette, tone: tone, title: title, detail: detail) {
            if let plan {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(RebuildPlanStatusCopy.rows(for: plan), id: \.self) { row in
                        Text(row)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(palette.textPrimary)
                            .monospacedDigit()
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    RebuildPlaylistActions(
                        palette: palette,
                        plan: plan,
                        rebuildState: rebuildState,
                        requestRebuild: requestRebuild
                    )

                    if canCheckMatches {
                        Button(action: checkMatches) {
                            Text(AppCopy.rebuildPlanCheckMatchesTitle)
                                .font(.subheadline.weight(.medium))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                        .disabled(isChecking)
                        .padding(.top, 6)
                    }
                }
                .padding(.top, 8)
            }
        }
        .alert(AppCopy.rebuildPlanCreateTitle, isPresented: confirmationBinding) {
            Button(AppCopy.rebuildPlanCancelTitle, role: .cancel, action: cancelRebuild)
            Button(AppCopy.rebuildPlanConfirmTitle, action: confirmRebuild)
        } message: {
            Text(confirmationMessage)
        }
    }

    private var tone: StatusTone {
        switch state {
        case .loading:
            .working
        case .checking:
            .working
        case .blockedByPermission:
            .alert
        case .ready(let plan):
            plan.missingSongRecordCount > 0 || plan.liveNeedsReviewCount > 0 ? .alert : .ok
        case .failed:
            .alert
        }
    }

    private var title: String {
        switch state {
        case .loading:
            AppCopy.rebuildPlanLoadingTitle
        case .checking:
            AppCopy.rebuildPlanCheckingTitle
        case .blockedByPermission:
            AppCopy.rebuildPlanPermissionTitle
        case .ready(let plan):
            plan.playlistCount > 0 ? AppCopy.rebuildPlanReadyTitle : AppCopy.rebuildPlanEmptyTitle
        case .failed:
            AppCopy.rebuildPlanFailedTitle
        }
    }

    private var detail: String {
        switch state {
        case .loading:
            AppCopy.rebuildPlanLoadingMessage
        case .checking(let plan):
            RebuildPlanStatusCopy.checkingText(for: plan)
        case .blockedByPermission(let plan):
            RebuildPlanStatusCopy.permissionText(for: plan)
        case .ready(let plan):
            RebuildPlanStatusCopy.detailText(for: plan)
        case .failed(let message):
            message
        }
    }

    private var plan: RebuildPlanSummary? {
        switch state {
        case .loading, .failed:
            nil
        case .ready(let plan), .checking(let plan), .blockedByPermission(let plan):
            plan
        }
    }

    private var isChecking: Bool {
        if case .checking = state {
            return true
        }
        return false
    }

    private var canCheckMatches: Bool {
        guard let plan else {
            return false
        }
        return plan.trackCount > 0 && !isChecking && !isRebuilding
    }

    private var isRebuilding: Bool {
        if case .rebuilding = rebuildState {
            return true
        }
        return false
    }

    private var confirmationBinding: Binding<Bool> {
        Binding(
            get: {
                if case .confirming = rebuildState {
                    return true
                }
                return false
            },
            set: { _ in }
        )
    }

    private var confirmationMessage: String {
        if case .confirming(let request) = rebuildState {
            return PlaylistRebuildStatusCopy.confirmationText(for: request.preview)
        }
        return ""
    }
}

private struct RebuildPlaylistActions: View {
    var palette: AppTheme.Palette
    var plan: RebuildPlanSummary
    var rebuildState: PlaylistRebuildState
    var requestRebuild: (String) -> Void

    var body: some View {
        let previews = PlaylistRebuildRequest.previews(in: plan)

        if !previews.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(previews) { preview in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(PlaylistRebuildStatusCopy.previewText(for: preview))
                            .font(.footnote)
                            .foregroundStyle(palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Button(action: { requestRebuild(preview.playlistID) }) {
                            Text(PlaylistRebuildStatusCopy.actionTitle(for: preview))
                                .font(.subheadline.weight(.medium))
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                        .disabled(isBusy)
                    }
                }
            }
            .padding(.top, 8)
        }

        switch rebuildState {
        case .idle, .confirming:
            EmptyView()
        case .rebuilding(let preview):
            Text(PlaylistRebuildStatusCopy.rebuildingText(for: preview))
                .font(.footnote.weight(.medium))
                .foregroundStyle(palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
        case .completed(let result):
            Text(PlaylistRebuildStatusCopy.completedText(for: result))
                .font(.footnote.weight(.medium))
                .foregroundStyle(palette.accent)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
        case .failed(let message):
            InlineWarningNote(palette: palette, text: message)
        }
    }

    private var isBusy: Bool {
        switch rebuildState {
        case .confirming, .rebuilding:
            true
        case .idle, .completed, .failed:
            false
        }
    }
}

// MARK: - Backup detail

private struct BackupDetailView: View {
    var palette: AppTheme.Palette
    var manifest: SnapshotManifest
    var permissionStatus: AppleMusicPermissionStatus

    @State private var snapshotDiffStatus = SnapshotDiffStatus.loading
    @StateObject private var restorePreviewModel = RestorePreviewViewModel()
    @StateObject private var playlistRebuildModel = PlaylistRebuildViewModel()
    @State private var exportDocument: RekoraBackupDocument?
    @State private var exportFileName = ""
    @State private var isExportPresented = false
    @State private var exportMessage: String?

    private let snapshotStore = SnapshotStore()

    var body: some View {
        ZStack {
            palette.background
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    BackupOverview(palette: palette, manifest: manifest)

                    StatusSection(title: AppCopy.snapshotDetailIncludedTitle, palette: palette) {
                        IncludedRows(palette: palette, manifest: manifest)
                    }

                    StatusSection(title: AppCopy.snapshotDetailChangesTitle, palette: palette) {
                        SnapshotChangesContent(palette: palette, status: snapshotDiffStatus)
                    }

                    StatusSection(title: AppCopy.snapshotDetailRebuildPlanTitle, palette: palette) {
                        RebuildPlanContent(
                            palette: palette,
                            state: restorePreviewModel.state,
                            rebuildState: playlistRebuildModel.state,
                            checkMatches: checkAppleMusicMatches,
                            requestRebuild: requestPlaylistRebuild,
                            confirmRebuild: confirmPlaylistRebuild,
                            cancelRebuild: playlistRebuildModel.cancelConfirmation
                        )
                    }

                    StatusSection(title: AppCopy.snapshotDetailLocationTitle, palette: palette) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(AppCopy.snapshotDetailLocationMessage)
                                .font(.subheadline)
                                .foregroundStyle(palette.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)

                            Text(AppCopy.snapshotExportMessage)
                                .font(.subheadline)
                                .foregroundStyle(palette.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)

                            Button(action: prepareExport) {
                                Text(AppCopy.snapshotExportTitle)
                                    .font(.subheadline.weight(.medium))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                            .padding(.top, 4)

                            if let exportMessage {
                                Text(exportMessage)
                                    .font(.footnote)
                                    .foregroundStyle(palette.textMuted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 36)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(AppCopy.snapshotDetailTitle)
        .toolbarTitleDisplayMode(.inline)
        .fileExporter(
            isPresented: $isExportPresented,
            document: exportDocument,
            contentType: .json,
            defaultFilename: exportFileName,
            onCompletion: handleExportResult
        )
        .task {
            await loadSnapshotDiff()
            await restorePreviewModel.load(fileName: manifest.latestSnapshotFileName)
        }
    }

    private func loadSnapshotDiff() async {
        snapshotDiffStatus = .loading

        do {
            let current = try snapshotStore.loadSnapshot(fileName: manifest.latestSnapshotFileName)

            guard let previous = try snapshotStore.loadPreviousSnapshot(before: manifest) else {
                snapshotDiffStatus = .unavailable
                return
            }

            let diff = SnapshotDiff.compare(
                older: previous.snapshot,
                newer: current.snapshot
            )

            snapshotDiffStatus = .ready(diff)
        } catch {
            snapshotDiffStatus = .failed(error.localizedDescription)
        }
    }

    private func handleExportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success:
            exportMessage = AppCopy.snapshotExportSuccessMessage
        case .failure:
            exportMessage = AppCopy.snapshotExportFailedMessage
        }
    }

    private func prepareExport() {
        do {
            guard let export = try snapshotStore.loadLatestSnapshotExport() else {
                exportMessage = AppCopy.snapshotExportMissingMessage
                return
            }

            exportDocument = RekoraBackupDocument(data: export.data)
            exportFileName = export.fileName
            exportMessage = nil
            isExportPresented = true
        } catch {
            exportMessage = AppCopy.snapshotExportFailedMessage
        }
    }

    private func checkAppleMusicMatches() {
        Task {
            await restorePreviewModel.checkMatches(
                fileName: manifest.latestSnapshotFileName,
                permissionStatus: permissionStatus
            )
        }
    }

    private func requestPlaylistRebuild(playlistID: String) {
        guard case .ready(let plan) = restorePreviewModel.state else {
            return
        }

        playlistRebuildModel.prepareConfirmation(
            playlistID: playlistID,
            plan: plan,
            permissionStatus: permissionStatus
        )
    }

    private func confirmPlaylistRebuild() {
        Task {
            await playlistRebuildModel.confirmRebuild()
        }
    }
}

private struct BackupOverview: View {
    var palette: AppTheme.Palette
    var manifest: SnapshotManifest

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(SnapshotStatusCopy.savedSummaryText(for: manifest))
                .font(.title3.weight(.semibold))
                .foregroundStyle(palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Created \(Self.formatter.string(from: manifest.createdAt))")
                .font(.callout)
                .foregroundStyle(palette.textSecondary)
        }
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

private struct IncludedRows: View {
    var palette: AppTheme.Palette
    var manifest: SnapshotManifest

    var body: some View {
        VStack(spacing: 0) {
            row(
                title: "Songs",
                count: manifest.songCount,
                detail: "Songs Rekora can recognize from your Apple Music library and playlists."
            )
            divider
            row(
                title: "Albums",
                count: manifest.albumCount,
                detail: "Album names and artist names available from Apple Music."
            )
            divider
            row(
                title: "Playlists",
                count: manifest.playlistCount,
                detail: "Playlist names and Apple Music library identifiers."
            )
            divider
            row(
                title: "Playlist tracks",
                count: manifest.playlistTrackCount,
                detail: "The song order inside each playlist."
            )
        }
    }

    private func row(title: String, count: Int, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(palette.textPrimary)

                Spacer(minLength: 12)

                Text("\(count)")
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(palette.textPrimary)
            }

            Text(detail)
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 12)
    }

    private var divider: some View {
        Rectangle()
            .fill(palette.divider)
            .frame(height: 0.5)
    }
}

// MARK: - Library probe content

private struct LibraryProbeContent: View {
    var palette: AppTheme.Palette
    var state: LibraryProbeState
    var permissionStatus: AppleMusicPermissionStatus
    var inspectLibrary: () async -> Void

    var body: some View {
        StatusRow(palette: palette, tone: tone, title: title, detail: detail) {
            if case .completed(let report) = state {
                LibraryProbeReadout(palette: palette, report: report)
                    .padding(.top, 14)
            }

            if canInspect {
                InlineActionButton(
                    title: AppCopy.libraryProbeActionTitle,
                    isDisabled: state.isRunning
                ) {
                    Task { await inspectLibrary() }
                }
            }
        }
    }

    private var tone: StatusTone {
        switch state {
        case .idle, .blockedByPermission: .idle
        case .running:                    .working
        case .completed:                  .ok
        case .failed:                     .alert
        }
    }

    private var title: String {
        switch state {
        case .idle, .blockedByPermission: AppCopy.libraryProbeActionTitle
        case .running:                    "Inspecting library"
        case .completed:                  "Library data readable"
        case .failed:                     AppCopy.libraryProbeFailedTitle
        }
    }

    private var detail: String {
        switch state {
        case .idle:
            if permissionStatus == .authorized {
                return AppCopy.libraryProbeReadyMessage
            }
            return AppCopy.libraryProbeBlockedMessage
        case .running:
            return AppCopy.libraryProbeRunningMessage
        case .completed:
            return "Use these counts to decide what Rekora can include in the next real backup."
        case .blockedByPermission:
            return AppCopy.libraryProbeBlockedMessage
        case .failed(let errorMessage):
            return errorMessage
        }
    }

    private var canInspect: Bool {
        permissionStatus == .authorized && state.isRunning == false
    }
}

private struct LibraryProbeReadout: View {
    var palette: AppTheme.Palette
    var report: LibraryProbeReport

    var body: some View {
        VStack(spacing: 0) {
            row("Songs readable", "\(report.songCount)")
            divider
            row("Albums readable", "\(report.albumCount)")
            divider
            row("Playlists checked", "\(report.checkedPlaylistCount) of \(report.playlistCount)")
            divider
            row("Playlist tracks readable", "\(report.playlistTrackCount)")
            divider
            row("Playlist order", report.playlistOrderReadable ? "Available" : "Not confirmed")
            divider
            row("Track added dates", "\(report.playlistTracksWithAddedDateCount)")
            divider
            row("Missing track IDs", "\(report.missingTrackIdentifierCount)")
            divider
            row("Missing track titles", "\(report.missingTrackTitleCount)")
            divider
            row("Playlist track failures", "\(report.failedPlaylistTrackCount)")
            divider
            row(
                "Duration",
                Self.durationFormatter.string(from: report.duration) ?? "\(Int(report.duration)) sec"
            )
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        LabeledContent {
            Text(value)
                .monospacedDigit()
                .foregroundStyle(palette.textPrimary)
        } label: {
            Text(label)
                .foregroundStyle(palette.textSecondary)
        }
        .font(.footnote)
        .padding(.vertical, 9)
    }

    private var divider: some View {
        Rectangle()
            .fill(palette.divider)
            .frame(height: 0.5)
    }

    private static let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
}

// MARK: - Bottom primary action

private struct PrimaryActionBar: View {
    var palette: AppTheme.Palette
    var isWorking: Bool
    var action: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(palette.divider)
                .frame(height: 0.5)

            Button(action: action) {
                HStack(spacing: 10) {
                    if isWorking {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    }
                    Text(AppCopy.primaryActionTitle)
                        .font(.body.weight(.semibold))
                }
                .frame(maxWidth: .infinity, minHeight: 24)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .tint(palette.accent)
            .disabled(isWorking)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
        .background(palette.background)
    }
}
