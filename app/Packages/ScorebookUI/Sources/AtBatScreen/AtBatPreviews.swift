// Previews of the batting screen: every sample situation, our hitter with a song (idle, during
// the introduction, counting down, and kept playing), our hitter without one, their hitter
// known only by number, the "Is the game over?" pop-up, light and dark mode, and the largest
// text size.
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
    /// What Redo would put back, for the preview right after an undo.
    var redoLabel: String?
    /// The batter's earlier plate appearances, when a preview wants its own (a long day).
    var history: [PlateAppearanceSummary]?
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
        let history = self.history ?? situation.batter.map { id in
            (SampleGame.plateAppearances[id] ?? []).filter { $0.inning < situation.inning }
        } ?? []
        return AtBatScreen(
            setup: sample.setup,
            situation: situation,
            batterHistory: history,
            songs: SampleSongs.library,
            settings: settings,
            songPlayback: playback,
            undoLabel: AtBatPreview.undoLabels[sample.title] ?? nil,
            redoLabel: redoLabel,
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

    /// What Undo would take back in each sample situation: the event that most likely led to it,
    /// as the app's undo label would name it.
    static let undoLabels: [String: String?] = [
        SampleSituations.topOfFirst.title: nil,
        SampleSituations.runnerOnFirstOneOut.title: "ball",
        SampleSituations.basesLoadedTwoOutsFullCount.title: "ball",
        SampleSituations.secondAndThirdNobodyOut.title: "2B 7",
        SampleSituations.tenthHitterUpAfterAddingOne.title: "added hitter",
        SampleSituations.newPitcherJustIn.title: "pitching change",
        SampleSituations.lastInningHomeAhead.title: "called strike",
        SampleSituations.extraInnings.title: "F8",
        SampleSituations.betweenHalfInnings.title: "L4-3 DP",
        SampleSituations.designatedNonRunnerOnFirst.title: "1B 9",
        SampleSituations.ourHitterWithoutSong.title: "swinging strike",
        SampleSituations.theirHitterKnownByNumber.title: "K",
        SampleSituations.rightAfterStrikeThree.title: "strikeout",
        SampleSituations.lastInningOnTime.title: "ball",
        SampleSituations.ourPitcherWarmingUp.title: "F9",
    ]

    /// A long day: six plate appearances, more than fit on the batter's line.
    static let longDay: [PlateAppearanceSummary] = [
        PlateAppearanceSummary(inning: 1, notation: "1B 7", outcome: .single),
        PlateAppearanceSummary(inning: 2, notation: "F8", outcome: .out),
        PlateAppearanceSummary(inning: 4, notation: "6-4-3 DP", outcome: .out),
        PlateAppearanceSummary(inning: 5, notation: "BB", outcome: .walk),
        PlateAppearanceSummary(inning: 7, notation: "HR 9", outcome: .homeRun, rbi: 3),
        PlateAppearanceSummary(inning: 8, notation: "K", outcome: .strikeout),
    ]

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

#Preview("Our hitter with a song, kept playing") {
    AtBatPreview(sample: SampleSituations.basesLoadedTwoOutsFullCount, playback: .keptPlaying)
}

#Preview("Our hitter without a song (Fisk)") {
    AtBatPreview(sample: SampleSituations.ourHitterWithoutSong)
}

#Preview("Their hitter known only by number") {
    AtBatPreview(sample: SampleSituations.theirHitterKnownByNumber)
}

// MARK: - Every sample situation

#Preview("Top of the 1st, nobody on") {
    AtBatPreview(sample: SampleSituations.topOfFirst)
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
    AtBatPreview(sample: SampleSituations.newPitcherJustIn)
}

#Preview("Top of the 9th, home team ahead") {
    AtBatPreview(sample: SampleSituations.lastInningHomeAhead)
}

#Preview("Extra innings") {
    AtBatPreview(sample: SampleSituations.extraInnings)
}

#Preview("Changeover, middle of the 3rd") {
    AtBatPreview(sample: SampleSituations.betweenHalfInnings)
}

#Preview("Designated non-runner on first") {
    AtBatPreview(sample: SampleSituations.designatedNonRunnerOnFirst)
}

#Preview("Right after strike three") {
    AtBatPreview(sample: SampleSituations.rightAfterStrikeThree)
}

#Preview("Time limit passed: last inning") {
    AtBatPreview(sample: SampleSituations.lastInningOnTime)
}

#Preview("Our team taking the field: warm-up song") {
    AtBatPreview(sample: SampleSituations.ourPitcherWarmingUp)
}

#Preview("Warm-up song playing") {
    AtBatPreview(sample: SampleSituations.ourPitcherWarmingUp, playback: .warmUp)
}

#Preview("Is the game over? (time limit)") {
    AtBatPreview(sample: SampleSituations.lastInningOnTime) { s in
        s.gameOverQuestion = .timeLimit
    }
}

#Preview("Long day: six plate appearances") {
    AtBatPreview(sample: SampleSituations.basesLoadedTwoOutsFullCount, history: AtBatPreview.longDay)
}

#Preview("Right after an undo: Redo showing") {
    AtBatPreview(sample: SampleSituations.secondAndThirdNobodyOut, redoLabel: "6-3")
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
