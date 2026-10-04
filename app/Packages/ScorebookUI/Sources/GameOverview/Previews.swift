// Previews for the game overview, driven by SampleData: the complete sample game (every tab),
// the game at the end of the third inning, the same game a few pitches into the fourth with
// a batter at the plate, a 400-event play-by-play for checking that scrolling stays smooth,
// dark mode, the largest accessibility text size, and the "Fix a play" sheet.

import SwiftUI
import Model
import SampleData
import DesignSystem

/// Ready-made games for previews, tests and the harness app.
public enum GameOverviewSamples {
    /// The complete sample game: Mudcats at Diamond Dogs, five innings, final.
    public static var completeGame: GameOverview.Inputs {
        GameOverview.Inputs(log: SampleGame.playLog, boxScore: SampleGame.boxScore,
                            plateAppearances: SampleGame.plateAppearances, situation: SampleGame.finalSituation)
    }

    /// The sample game at the end of the third inning, as the rules engine replays it.
    public static var thirdInning: GameOverview.Inputs {
        let cut = SampleGame.throughThreeInnings
        let situation = SampleRulesEngine().replay(cut.game).situation
        return GameOverview.Inputs(log: cut.log, boxScore: SampleGame.boxScoreThroughThree,
                                   plateAppearances: SampleGame.plateAppearancesThroughThree, situation: situation)
    }

    /// The sample game a few events into the top of the 4th, with Ortiz at the plate. The
    /// play log and situation come from the rules engine; the box score is the one after
    /// three innings, so only the first few pitches of the 4th are missing from it.
    public static func fourthInning(eventsIntoTheFourth: Int = 3) -> GameOverview.Inputs {
        let full = SampleGame.game
        let replayAll = SampleRulesEngine().replay(full)
        let firstOfFourth = replayAll.log.entries.firstIndex { $0.inning == 4 } ?? full.events.count
        var game = full
        game.events = Array(full.events.prefix(firstOfFourth + eventsIntoTheFourth))
        let replay = SampleRulesEngine().replay(game)
        return GameOverview.Inputs(log: replay.log, boxScore: SampleGame.boxScoreThroughThree,
                                   plateAppearances: SampleGame.plateAppearancesThroughThree, situation: replay.situation)
    }

    /// A play log of `count` events, made by repeating the sample game's play log with new
    /// event ids, each repeat five innings later than the one before. For checking that the
    /// play-by-play stays smooth in a long game; the score it shows is not a real game's.
    public static func longLog(events count: Int = 400) -> PlayLog {
        var log = SampleGame.playLog
        let original = log.entries
        var entries: [PlayLogEntry] = []
        var round = 0
        while entries.count < count {
            for entry in original where entries.count < count {
                // Leave out every repeat's end of game except the very last event's.
                if case .endOfGame = entry.event.kind { continue }
                var copy = entry
                copy.event.id = EventID(rawValue: "\(entry.event.id.rawValue)-\(round)")
                copy.inning += 5 * round
                entries.append(copy)
            }
            round += 1
        }
        log.entries = entries
        log.isFinal = false
        return log
    }
}

extension GameOverview {
    /// Everything the screen is handed, bundled for previews and tests.
    public struct Inputs: Sendable {
        public var log: PlayLog
        public var boxScore: BoxScore
        public var plateAppearances: [PlayerID: [PlateAppearanceSummary]]
        public var situation: Situation?

        public init(log: PlayLog, boxScore: BoxScore, plateAppearances: [PlayerID: [PlateAppearanceSummary]], situation: Situation?) {
            self.log = log
            self.boxScore = boxScore
            self.plateAppearances = plateAppearances
            self.situation = situation
        }
    }

    /// The screen from bundled inputs.
    public init(_ inputs: Inputs, startingTab: GameOverviewTab = .score, onAction: @escaping (GameOverviewAction) -> Void) {
        self.init(log: inputs.log, boxScore: inputs.boxScore, plateAppearances: inputs.plateAppearances,
                  situation: inputs.situation, startingTab: startingTab, onAction: onAction)
    }
}

// MARK: - Preview helpers

/// The screen with a strip along the bottom showing the last thing it handed back.
private struct OverviewDemo: View {
    var inputs: GameOverview.Inputs
    var tab: GameOverviewTab = .score
    @State private var last = "Nothing yet"

    var body: some View {
        GameOverview(inputs, startingTab: tab) { action in
            switch action {
            case .backToBatting: last = "Back to the batting screen"
            case .edit(.delete(let id)): last = "Delete \(id)"
            case .edit(.replace(let event)): last = "Replace \(event.id) with \(event.kind.label)"
            case .edit(.insert(let event, _)): last = "Insert \(event.kind.label)"
            case .openEditor(let event): last = "Open the steps for \(event.id) (\(event.kind.label))"
            }
        }
        .safeAreaInset(edge: .bottom) {
            Text("Handed back: \(last)")
                .font(ScorebookFont.caption)
                .padding(Spacing.small)
                .frame(maxWidth: .infinity)
                .background(ScorebookColor.surfaceSecondary)
        }
    }
}

// MARK: - The complete game

#Preview("Complete game: score") {
    OverviewDemo(inputs: GameOverviewSamples.completeGame, tab: .score)
}

#Preview("Complete game: box") {
    OverviewDemo(inputs: GameOverviewSamples.completeGame, tab: .box)
}

#Preview("Complete game: pitchers") {
    OverviewDemo(inputs: GameOverviewSamples.completeGame, tab: .pitchers)
}

#Preview("Complete game: plays") {
    OverviewDemo(inputs: GameOverviewSamples.completeGame, tab: .plays)
}

// MARK: - A game in progress

#Preview("Third inning: score") {
    OverviewDemo(inputs: GameOverviewSamples.thirdInning, tab: .score)
}

#Preview("Third inning: box") {
    OverviewDemo(inputs: GameOverviewSamples.thirdInning, tab: .box)
}

#Preview("Third inning: plays") {
    OverviewDemo(inputs: GameOverviewSamples.thirdInning, tab: .plays)
}

#Preview("Batter at the plate: score") {
    OverviewDemo(inputs: GameOverviewSamples.fourthInning(), tab: .score)
}

#Preview("Batter at the plate: plays") {
    OverviewDemo(inputs: GameOverviewSamples.fourthInning(), tab: .plays)
}

// MARK: - A long game

#Preview("400 events") {
    OverviewDemo(inputs: GameOverview.Inputs(log: GameOverviewSamples.longLog(events: 400),
                                             boxScore: SampleGame.boxScore,
                                             plateAppearances: SampleGame.plateAppearances,
                                             situation: nil),
                 tab: .plays)
}

// MARK: - Dark mode and the largest text

#Preview("Dark: score") {
    OverviewDemo(inputs: GameOverviewSamples.fourthInning(), tab: .score)
        .preferredColorScheme(.dark)
}

#Preview("Dark: box") {
    OverviewDemo(inputs: GameOverviewSamples.completeGame, tab: .box)
        .preferredColorScheme(.dark)
}

#Preview("Dark: plays") {
    OverviewDemo(inputs: GameOverviewSamples.completeGame, tab: .plays)
        .preferredColorScheme(.dark)
}

#Preview("Largest text: score") {
    OverviewDemo(inputs: GameOverviewSamples.thirdInning, tab: .score)
        .dynamicTypeSize(.accessibility5)
}

#Preview("Largest text: box") {
    OverviewDemo(inputs: GameOverviewSamples.completeGame, tab: .box)
        .dynamicTypeSize(.accessibility5)
}

#Preview("Largest text: pitchers") {
    OverviewDemo(inputs: GameOverviewSamples.completeGame, tab: .pitchers)
        .dynamicTypeSize(.accessibility5)
}

#Preview("Largest text: plays") {
    OverviewDemo(inputs: GameOverviewSamples.completeGame, tab: .plays)
        .dynamicTypeSize(.accessibility5)
}

// MARK: - Fix a play

/// The sheet for one row of the sample game, picked by what kind of event it is.
private func sampleRow(_ matches: (PlayRow) -> Bool) -> PlayRow {
    PlayByPlay.rows(for: SampleGame.playLog).first(where: matches)!
}

#Preview("Fix a play: ball in play") {
    FixPlaySheet(row: sampleRow { if case .ballInPlay = $0.event.kind { return true }; return false }) { _ in }
}

#Preview("Fix a play: a pitch") {
    FixPlaySheet(row: sampleRow { $0.isHideablePitch }) { _ in }
}

#Preview("Fix a play: dark") {
    FixPlaySheet(row: sampleRow { if case .runnerAction = $0.event.kind { return true }; return false }) { _ in }
        .preferredColorScheme(.dark)
}
