// The app's starting point: what iOS runs when the scorebook opens.
//
// For now it opens to a placeholder home screen. The wiring job (plan/briefs/
// wiring-and-dress-rehearsal.md) replaces it with the real navigation: resume a game,
// new game, teams, songs, season stats.

import SwiftUI

@main
struct ScorebookApp: App {
    var body: some Scene {
        WindowGroup {
            HomePlaceholderView()
        }
    }
}
