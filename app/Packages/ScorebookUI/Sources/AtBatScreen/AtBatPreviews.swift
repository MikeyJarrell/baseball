// Previews of the batting screen: every sample situation, our hitter with a song (idle, during
// the introduction, and counting down), our hitter without one, their hitter known only by
// number, the "Is the game over?" pop-up, light and dark mode, and the largest text size.
//
// The previews are also the screen's demo: tapping a button shows what it would hand back.

import SwiftUI
import Model
import SampleData
import DesignSystem

/// A sample situation on the batting screen, with the batter's sample history, the sample song
/// library, and the clock read twelve minutes into the current inning, so the time left looks
/// as it would during the game rather than months later.
struct AtBatPreview: View {
    var sample: SampleSituation
    var playback: SongPlayback = .idle
    var undoLabel: String? = "ball"
    var settings = AppSettings()
    /// Changes to the situation for one preview, such as raising the game-over question.
    var adjust: (inout Situation) -> Void = { _ in }

    /// The last thing tapped, shown at the top so the preview works as a demo.
    @State private var lastTap: String?

    var body: some View {
        var situation = sample.situation
        adjust(&situation)
        let previewNow = (situation.currentInningStartedAt ?? sample.setup.scheduledStart).addingTimeInterval(12 * 60)
        // Earlier today: the batter's plate appearances in the sample game before this inning.
        let history = situation.batter.map { id in
            (SampleGame.plateAppearances[id] ?? []).filter { $0.inning < situation.inning }
        } ?? []
        return AtBatScreen(
            setup: sample.setup,
            situation: situation,
            batterHistory: history,
            songs: SampleSongs.library,
            settings: settings,
            songPlayback: playback,
            undoLabel: undoLabel,
            clock: { [situation] _ in simpleClock(for: situation, at: previewNow) },
            onAction: { action in lastTap = describe(action) }
        )
        .overlay(alignment: .top) {
            if let lastTap {
                Text(lastTap)
                    .font(ScorebookFont.caption.weight(.bold))
                    .padding(.horizontal, Spacing.medium)
                    .padding(.vertical, Spacing.small)
                    .background(ScorebookColor.surface, in: Capsule())
                    .shadow(radius: 4)
                    .padding(.top, 60)
                    .allowsHitTesting(false)
            }
        }
    }

    /// A few words for what a tap handed back.
    private func describe(_ action: AtBatAction) -> String {
        switch action {
        case .record(let event): "Record: \(event.kind.label)"
        default: "\(action)".components(separatedBy: "(").first ?? "\(action)"
        }
    }
}

// MARK: - The situations the brief asks for

#Preview("Our hitter with a song (Quinn), bases loaded") {
    AtBatPreview(sample: SampleSituations.basesLoadedTwoOutsFullCount)
}

#Preview("Our hitter with a song, introduction playing") {
    AtBatPreview(sample: SampleSituations.basesLoadedTwoOutsFullCount, playback: .introduction)
}

#Preview("Our hitter with a song, counting down") {
    AtBatPreview(sample: SampleSituations.basesLoadedTwoOutsFullCount, playback: .song(endsAt: Date().addingTimeInterval(8)))
}

#Preview("Our hitter without a song (Fisk)") {
    AtBatPreview(sample: SampleSituations.ourHitterWithoutSong)
}

#Preview("Their hitter known only by number") {
    AtBatPreview(sample: SampleSituations.theirHitterKnownByNumber, undoLabel: nil)
}

// MARK: - Every sample situation

#Preview("Top of the 1st, nobody on") {
    AtBatPreview(sample: SampleSituations.topOfFirst, undoLabel: nil)
}

#Preview("Runner on first, one out, 2-1") {
    AtBatPreview(sample: SampleSituations.runnerOnFirstOneOut)
}

#Preview("Runners on second and third") {
    AtBatPreview(sample: SampleSituations.secondAndThirdNobodyOut)
}

#Preview("Tenth hitter, lineup extended") {
    AtBatPreview(sample: SampleSituations.tenthHitterUpAfterAddingOne)
}

#Preview("New pitcher just in") {
    AtBatPreview(sample: SampleSituations.newPitcherJustIn, undoLabel: "pitching change")
}

#Preview("Top of the 9th, home team ahead") {
    AtBatPreview(sample: SampleSituations.lastInningHomeAhead)
}

#Preview("Extra innings") {
    AtBatPreview(sample: SampleSituations.extraInnings)
}

#Preview("Changeover, middle of the 3rd") {
    AtBatPreview(sample: SampleSituations.betweenHalfInnings, undoLabel: "ball in play")
}

#Preview("Designated non-runner on first") {
    AtBatPreview(sample: SampleSituations.designatedNonRunnerOnFirst, undoLabel: "ball in play")
}

#Preview("Right after strike three") {
    AtBatPreview(sample: SampleSituations.rightAfterStrikeThree, undoLabel: "swinging strike")
}

#Preview("Time limit passed: last inning") {
    AtBatPreview(sample: SampleSituations.lastInningOnTime)
}

#Preview("Our team taking the field: warm-up song") {
    AtBatPreview(sample: SampleSituations.ourPitcherWarmingUp, undoLabel: "ball in play")
}

#Preview("Warm-up song playing") {
    AtBatPreview(sample: SampleSituations.ourPitcherWarmingUp, playback: .warmUp, undoLabel: "ball in play")
}

#Preview("Is the game over? (time limit)") {
    AtBatPreview(sample: SampleSituations.lastInningOnTime, undoLabel: "ball in play") { s in
        s.gameOverQuestion = .timeLimit
    }
}

// MARK: - Dark mode and the largest text size

#Preview("Dark: our hitter with a song") {
    AtBatPreview(sample: SampleSituations.basesLoadedTwoOutsFullCount, playback: .song(endsAt: Date().addingTimeInterval(8)))
        .preferredColorScheme(.dark)
}

#Preview("Dark: their hitter known only by number") {
    AtBatPreview(sample: SampleSituations.theirHitterKnownByNumber)
        .preferredColorScheme(.dark)
}

#Preview("Dark: changeover, warm-up song") {
    AtBatPreview(sample: SampleSituations.ourPitcherWarmingUp)
        .preferredColorScheme(.dark)
}

#Preview("Largest text: our hitter with a song") {
    AtBatPreview(sample: SampleSituations.basesLoadedTwoOutsFullCount)
        .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Largest text: their hitter, dark") {
    AtBatPreview(sample: SampleSituations.secondAndThirdNobodyOut)
        .environment(\.dynamicTypeSize, .accessibility5)
        .preferredColorScheme(.dark)
}
