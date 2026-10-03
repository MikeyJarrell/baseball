// A placeholder home screen that proves the app shell can see both packages: it shows the
// sample game's teams and final score, and the field drawing from the design system.
// The wiring job replaces it.

import SwiftUI
import Model
import SampleData
import GameEngine
import Stats
import BoxScoreText
import Storage
import DesignSystem
import WalkUpAudio
import BoxScorePicture
import TeamScreens
import PregameScreens
import AtBatScreen
import PlayEntry
import GameChanges
import GameOverview
import PostgameScreens

/// The placeholder home screen.
struct HomePlaceholderView: View {
    /// The sample game's box score, from SampleData.
    private let box = SampleGame.boxScore

    var body: some View {
        VStack(spacing: Spacing.large) {
            Text("Scorebook")
                .font(ScorebookFont.scoreboard)
                .foregroundStyle(ScorebookColor.textPrimary)
            Text("\(box.away.name) \(box.away.runs), \(box.home.name) \(box.home.runs)")
                .font(ScorebookFont.headline)
                .foregroundStyle(ScorebookColor.textSecondary)
            FieldDrawing(occupiedBases: [.first, .third])
                .frame(maxWidth: 320)
            Text("Placeholder screen. The real app is built job by job.")
                .font(ScorebookFont.caption)
                .foregroundStyle(ScorebookColor.textSecondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ScorebookColor.background)
    }
}

#Preview {
    HomePlaceholderView()
}
