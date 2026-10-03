// A demo rules engine for this screen's previews and simulator demos, built on the stand-in
// from SampleData. Never used in a real game: the app hands the screen the real rules engine.
//
// The stand-in in SampleData is deliberately rough. Two of its gaps would make the demos look
// broken, so this fills them in:
// - Its notation is only the fielders joined by dashes: a single shows nothing, an error by the
//   shortstop shows "6". Here the notation follows the sample game's ("1B 7", "E6", "FC 6-4",
//   "SF 8", "5-4-3 DP", "1B 7, E7").
// - Its runner suggestion ignores runners the scorer has moved, so its runs batted in never
//   change. Here the scorer's moves are kept, and runs batted in count the runners who scored,
//   except on an error, a double or triple play, or a dropped third strike, and except a runner
//   who scored on an error.
// Everything else is the stand-in's own answer. The handoff note asks the lead builder to fold
// these into SampleData's stand-in, after which this file can go.

import Foundation
import Model
import SampleData

/// The stand-in rules engine with notation and runs batted in filled in, for demos.
struct DemoRulesEngine: RulesEngine {
    private let standIn = SampleRulesEngine()

    func replay(_ game: Game) -> GameReplay { standIn.replay(game) }

    func suggestRunners(for draft: PlayDraft, in situation: Situation) -> RunnerSuggestion {
        // The stand-in's canned answer for the play, with the scorer's own moves laid over it.
        var withoutPicks = draft
        withoutPicks.runners = []
        let canned = standIn.suggestRunners(for: withoutPicks, in: situation).runners
        let runners = canned.map { move in draft.runners.first { $0.runner == move.runner } ?? move }
        return RunnerSuggestion(runners: runners, rbi: runsBattedIn(draft, runners: runners))
    }

    func preview(_ draft: PlayDraft, in situation: Situation) -> PlayPreview {
        var preview = standIn.preview(draft, in: situation)
        preview.notation = Self.notation(for: draft)
        return preview
    }

    func suggestRunnerAction(_ reason: RunnerMoveReason, runners: [PlayerID], in situation: Situation) -> [RunnerMove] {
        standIn.suggestRunnerAction(reason, runners: runners, in: situation)
    }

    func suggestedRunner(for nonRunner: PlayerID, in log: PlayLog, situation: Situation) -> PlayerID? {
        standIn.suggestedRunner(for: nonRunner, in: log, situation: situation)
    }

    func clock(for situation: Situation, at now: Date) -> GameClock {
        standIn.clock(for: situation, at: now)
    }

    func notation(for event: GameEvent, in situation: Situation) -> String {
        standIn.notation(for: event, in: situation)
    }

    /// Runs batted in, roughly: every runner who scored, except on an error, a double or triple
    /// play, or a dropped third strike, and except a runner who scored on an error.
    private func runsBattedIn(_ draft: PlayDraft, runners: [RunnerMove]) -> Int {
        if draft.context == .droppedThirdStrike || draft.multiOut != nil { return 0 }
        if draft.batterResult == .reachedOnError { return 0 }
        return runners.filter { $0.to == .scored && !$0.advancedOnError }.count
    }

    /// Scorebook notation for a play part way through, in the sample game's style.
    static func notation(for draft: PlayDraft) -> String {
        guard let result = draft.batterResult else { return "" }
        let path = draft.fielders.map(\.description).joined(separator: "-")
        let multiOut = draft.multiOut == .doublePlay ? " DP" : (draft.multiOut == .triplePlay ? " TP" : "")
        if draft.context == .droppedThirdStrike {
            return result == .out && !path.isEmpty ? "K \(path)" : "K"
        }
        switch result {
        case .out:
            guard let first = draft.fielders.first else { return "" }
            let prefix: String
            switch draft.battedBall {
            case .flyBall: prefix = "F"
            case .lineDrive: prefix = "L"
            case .popUp: prefix = "P"
            case .bunt: prefix = "B"
            case .groundBall, nil: prefix = ""
            }
            // One fielder on a ground ball is an unassisted out: "3U".
            let unassisted = draft.fielders.count == 1 && prefix.isEmpty ? "\(first)U" : nil
            return (unassisted ?? prefix + path) + multiOut
        case .single, .double, .triple, .homeRun:
            let code = [BatterResult.single: "1B", .double: "2B", .triple: "3B", .homeRun: "HR"][result] ?? ""
            let location = draft.hitLocation.map { " \($0.number)" } ?? ""
            // On a hit every error listed let a runner take an extra base: "1B 7, E7".
            let errors = draft.errors.map { ", E\($0.fielder.number)" }.joined()
            return code + location + errors
        case .reachedOnError:
            return draft.errors.first.map { "E\($0.fielder.number)" } ?? ""
        case .fieldersChoice:
            return path.isEmpty ? "" : "FC \(path)"
        case .sacrificeFly:
            return path.isEmpty ? "" : "SF \(path)"
        case .sacrificeBunt:
            return path.isEmpty ? "" : "SH \(path)"
        case .catchersInterference:
            return "CI"
        case .reachedOnDroppedThirdStrike:
            return "K"
        }
    }
}
