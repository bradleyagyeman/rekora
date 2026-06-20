import SwiftUI

enum StartupBrandingPolicy {
    static let hasSeenBrandingKey = "hasSeenStartupBranding"

    static func displayDuration(hasSeenStartupBranding: Bool) -> Duration {
        hasSeenStartupBranding ? .milliseconds(250) : .milliseconds(1_300)
    }
}

struct StartupBrandingContainer<Content: View>: View {
    @AppStorage(StartupBrandingPolicy.hasSeenBrandingKey)
    private var hasSeenStartupBranding = false

    @State private var isShowingBranding = true

    private let palette = AppTheme.light
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            content

            if isShowingBranding {
                StartupBrandingView(palette: palette)
            }
        }
        .task {
            await completeStartupBranding()
        }
    }

    @MainActor
    private func completeStartupBranding() async {
        let hasAlreadySeenStartupBranding = hasSeenStartupBranding
        let duration = StartupBrandingPolicy.displayDuration(
            hasSeenStartupBranding: hasAlreadySeenStartupBranding
        )

        hasSeenStartupBranding = true

        do {
            try await Task.sleep(for: duration)
        } catch {
            return
        }

        isShowingBranding = false
    }
}

struct StartupBrandingView: View {
    var palette: AppTheme.Palette

    var body: some View {
        ZStack {
            palette.background
                .ignoresSafeArea()

            Text(AppCopy.title)
                .font(.system(size: 46, weight: .semibold, design: .serif))
                .foregroundStyle(palette.accent)
                .accessibilityAddTraits(.isHeader)
        }
        .preferredColorScheme(.light)
    }
}
