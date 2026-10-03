// GameEngine: the rules engine. Events in, situation and play log out.
//
// `ScorebookRulesEngine` is the real version of the `RulesEngine` promise in Model. Each of
// its jobs lives in its own file:
//
// - Replay.swift: works through a game's events and writes the play log.
// - Suggestions.swift: suggested runner outcomes, runs batted in, the play preview, runner
//   moves between pitches, and who runs for a designated non-runner.
// - GameEndRules.swift: when to ask "Is the game over?", and the live game clock.
// - Notation.swift: scorebook shorthand ("6-3", "1B 7", "K").
// - BaseMath.swift: counting bases.
//
// The engine records what happened; it never enforces a league rule. Every rule it applies
// can be overridden by the scorer, and the manual adjustment event is there for the rest.

import Foundation
import Model

/// The real rules engine. Plain values in, plain values out, nothing remembered between calls,
/// so it is safe to use from any thread.
public struct ScorebookRulesEngine: RulesEngine {
    public init() {}

    /// Replays every event from the start. Undo and edits need nothing special: replay the
    /// edited event list.
    public func replay(_ game: Game) -> GameReplay {
        var replay = Replay(game: game)
        return replay.run()
    }

    /// Where every runner most likely ended up on the play the scorer is entering, and the
    /// runs batted in.
    public func suggestRunners(for draft: PlayDraft, in situation: Situation) -> RunnerSuggestion {
        Suggestions.runners(for: draft, in: situation)
    }

    /// The play in progress: notation so far, outs and runs, whether it ends the half-inning
    /// or the game.
    public func preview(_ draft: PlayDraft, in situation: Situation) -> PlayPreview {
        Suggestions.preview(draft, in: situation)
    }

    /// Where the chosen runners most likely went on a steal, pickoff, wild pitch, balk and so on.
    public func suggestRunnerAction(_ reason: RunnerMoveReason, runners: [PlayerID], in situation: Situation) -> [RunnerMove] {
        Suggestions.runnerAction(reason, runners: runners, in: situation)
    }

    /// Who the league's rule says should run for a designated non-runner who just reached.
    public func suggestedRunner(for nonRunner: PlayerID, in log: PlayLog, situation: Situation) -> PlayerID? {
        Suggestions.suggestedRunner(for: nonRunner, entries: log.entries, situation: situation)
    }

    /// The game clock between events: time left, last inning, and whether to ask about time.
    public func clock(for situation: Situation, at now: Date) -> GameClock {
        GameEndRules.clock(for: situation, at: now)
    }

    /// One outfielder alone is a fly ball, a throw is a ground ball, a sacrifice fly a fly ball
    /// and a sacrifice bunt a bunt; anything else is left for the scorer.
    public func suggestedBattedBall(for draft: PlayDraft) -> BattedBallType? {
        switch draft.batterResult {
        case .sacrificeFly: return .flyBall
        case .sacrificeBunt: return .bunt
        case .homeRun, .catchersInterference, .reachedOnDroppedThirdStrike: return nil
        default: break
        }
        if draft.fielders.count >= 2 { return .groundBall }
        if let only = draft.fielders.first, only.isOutfield { return .flyBall }
        return nil
    }

    /// Scorebook notation for one event. Lineup changes name players by id here, since the
    /// situation carries no names; the play log from `replay` uses their last names.
    public func notation(for event: GameEvent, in situation: Situation) -> String {
        Notation.event(event, before: situation, name: { $0.rawValue })
    }
}
