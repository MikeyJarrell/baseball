// The rules engine for screens to use in previews and demos until wiring.
//
// It is the real rules engine (ScorebookRulesEngine in GameEngine) under the name screens
// already use, so previews show real notation ("1B 7", "FC 6-4", "K 2-3"), real runner
// suggestions and runs batted in that follow the runners the scorer moves. Screens never
// import GameEngine themselves: SampleData uses it on their behalf, and the app shell hands
// the same engine to the screens once they are wired in.

import Foundation
import Model
import GameEngine

/// The real rules engine, for screens' previews and demos.
public struct SampleRulesEngine: RulesEngine {
    /// The engine every answer comes from. It remembers nothing between calls.
    private let engine = ScorebookRulesEngine()

    public init() {}

    public func replay(_ game: Game) -> GameReplay { engine.replay(game) }

    public func suggestRunners(for draft: PlayDraft, in situation: Situation) -> RunnerSuggestion {
        engine.suggestRunners(for: draft, in: situation)
    }

    public func preview(_ draft: PlayDraft, in situation: Situation) -> PlayPreview {
        engine.preview(draft, in: situation)
    }

    public func suggestRunnerAction(_ reason: RunnerMoveReason, runners: [PlayerID], in situation: Situation) -> [RunnerMove] {
        engine.suggestRunnerAction(reason, runners: runners, in: situation)
    }

    public func suggestedRunner(for nonRunner: PlayerID, in log: PlayLog, situation: Situation) -> PlayerID? {
        engine.suggestedRunner(for: nonRunner, in: log, situation: situation)
    }

    public func clock(for situation: Situation, at now: Date) -> GameClock {
        engine.clock(for: situation, at: now)
    }

    public func countAfter(_ pitch: PitchResult, in situation: Situation) -> CountChange {
        engine.countAfter(pitch, in: situation)
    }

    public func suggestedBattedBall(for draft: PlayDraft) -> BattedBallType? {
        engine.suggestedBattedBall(for: draft)
    }

    public func notation(for event: GameEvent, in situation: Situation) -> String {
        engine.notation(for: event, in: situation)
    }
}
