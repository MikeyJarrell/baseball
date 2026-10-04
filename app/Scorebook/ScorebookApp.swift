// The app's starting point: what iOS runs when the scorebook opens.
//
// It makes the one shared `AppModel` (storage, the audio player, everything saved), reads the
// saved files, and shows the home screen, or goes straight back to a game left in progress.

import SwiftUI
import DesignSystem

@main
struct ScorebookApp: App {
    /// Everything the app keeps while it is open, made once.
    @State private var app = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
                .task { await app.load() }
        }
    }
}

/// Shows a moment of "Opening…" while the saved files are read, then the app, or a plain
/// message if the files could not be opened at all.
struct RootView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        switch app.phase {
        case .loading:
            ProgressView("Opening…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(ScorebookColor.background)
        case .failed(let message):
            Text(message)
                .font(ScorebookFont.body)
                .multilineTextAlignment(.center)
                .padding(Spacing.extraLarge)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(ScorebookColor.background)
        case .ready:
            HomeView()
        }
    }
}
