// PlayEntry: the in-play sequence and runner confirmation.
//
// The sequence opens when the scorer taps "In play" on the batting screen (or "Dropped 3rd
// strike" after strike three). It asks what happened to the batter, has the scorer tap the
// fielders (or where a hit landed, or who made the error) on the field drawing, then shows
// where every runner most likely ended up for a glance and a save. It ends in one ball-in-play
// event, the dropped-third-strike play, or a cancel that records nothing.
//
// The screen does no baseball arithmetic. Notation, outs, runs, runs batted in, "inning over"
// and where the runners went all come from the rules-engine functions it is handed in
// `PlayEntryRules`. Until wiring, previews and demos use SampleData's rules engine.
//
// This file holds what the rest of the app sees: the view to show, what it is handed, and
// what it hands back. The steps themselves are in the other files of this folder.

import SwiftUI
import Model
import SampleData
import DesignSystem

/// The rules-engine functions the in-play sequence needs while the scorer is tapping.
/// The app hands in the real rules engine's; previews hand in SampleData's.
public struct PlayEntryRules: Sendable {
    /// Where every runner, batter included, most likely ended up, and the runs batted in,
    /// given what the scorer has picked so far. `draft.runners` holds only the runners the
    /// scorer has placed themselves, so the engine is free to move everyone else.
    public var suggestRunners: @Sendable (PlayDraft, Situation) -> RunnerSuggestion
    /// The play so far: its notation ("6", then "6-3"), the outs and runs it would produce,
    /// and whether it ends the half-inning or the game.
    public var preview: @Sendable (PlayDraft, Situation) -> PlayPreview
    /// A guess at the kind of batted ball from the fielders tapped so far, for the dashed chip.
    public var suggestBattedBall: @Sendable (PlayDraft) -> BattedBallType?

    public init(
        suggestRunners: @escaping @Sendable (PlayDraft, Situation) -> RunnerSuggestion,
        preview: @escaping @Sendable (PlayDraft, Situation) -> PlayPreview,
        suggestBattedBall: @escaping @Sendable (PlayDraft) -> BattedBallType?
    ) {
        self.suggestRunners = suggestRunners
        self.preview = preview
        self.suggestBattedBall = suggestBattedBall
    }

    /// Takes the functions from a rules engine, such as the real one from GameEngine.
    public init(engine: some RulesEngine) {
        self.init(
            suggestRunners: { draft, situation in engine.suggestRunners(for: draft, in: situation) },
            preview: { draft, situation in engine.preview(draft, in: situation) },
            suggestBattedBall: { draft in engine.suggestedBattedBall(for: draft) }
        )
    }

    /// SampleData's rules engine, for previews and simulator demos.
    public static var standIn: PlayEntryRules { PlayEntryRules(engine: SampleRulesEngine()) }
}

/// How the sequence was opened.
public enum PlayEntryStart: Sendable, Equatable {
    /// The "In play" button: starts at "What happened to the batter?".
    case inPlay
    /// The "Dropped 3rd strike" button after strike three: starts at "thrown out, or safe?".
    /// Hand the sequence the situation from just before the strike-three pitch, so the batter
    /// is the one who struck out.
    case droppedThirdStrike
}

/// What the sequence hands back when it closes.
public enum PlayEntryOutcome: Equatable, Sendable {
    /// One ball-in-play event, ready to record.
    case ballInPlay(GameEvent)
    /// A dropped third strike: the play to put on the strike-three pitch
    /// (`Pitch.droppedThirdStrike`). The wiring replaces the strike-three event with the same
    /// pitch carrying this play. Only the "Dropped 3rd strike" button opens this path.
    case droppedThirdStrike(Play)
    /// The scorer backed out. Nothing is recorded.
    case cancelled
}

/// The in-play sequence: the screen the app shows, full screen, when the scorer taps "In play".
///
///     PlayEntryView(situation: situation, setup: setup, rules: PlayEntryRules(engine: engine)) { outcome in
///         // record the event, or do nothing on .cancelled
///     }
public struct PlayEntryView: View {
    @State private var model: PlayEntryModel

    /// - Parameters:
    ///   - situation: where the game stands as the ball is put in play (for a dropped third
    ///     strike, just before the strike-three pitch).
    ///   - setup: the game's setup, for player names.
    ///   - start: which button opened the sequence.
    ///   - rules: the rules engine's functions.
    ///   - onFinish: called once, with the event to record or a cancel.
    public init(
        situation: Situation,
        setup: GameSetup,
        start: PlayEntryStart = .inPlay,
        rules: PlayEntryRules,
        onFinish: @escaping (PlayEntryOutcome) -> Void
    ) {
        _model = State(initialValue: PlayEntryModel(situation: situation, setup: setup, start: start,
                                                    rules: rules, onFinish: onFinish))
    }

    /// Shows a sequence that is already part way through, for previews and simulator demos.
    init(model: PlayEntryModel) {
        _model = State(initialValue: model)
    }

    public var body: some View {
        PlayEntryScreen(model: model)
    }
}
