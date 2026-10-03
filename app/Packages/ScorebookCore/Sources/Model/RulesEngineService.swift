// The rules engine's promise: what the GameEngine module provides to the rest of the app.
//
// Declared here so screens and tests can use a stand-in while the real engine is built.
// The real one lives in GameEngine; the stand-in with canned answers for screens lives in
// SampleData; the do-nothing one is at the bottom of this file.

import Foundation

/// Works out the game from its events. Everything here runs straight through (no waiting),
/// and may be called from any thread.
public protocol RulesEngine: Sendable {
    /// Replays a game's events from the start: the situation after the last one, and the
    /// play log with one entry per event. Fast enough to run after every tap.
    func replay(_ game: Game) -> GameReplay

    /// For the in-play sequence's runner step: where every runner (batter included) most
    /// likely ended up, and the runs batted in, given what the scorer has picked so far.
    func suggestRunners(for draft: PlayDraft, in situation: Situation) -> RunnerSuggestion

    /// For a play the scorer is still entering: its notation so far, and the outs and runs
    /// it would produce.
    func preview(_ draft: PlayDraft, in situation: Situation) -> PlayPreview

    /// Scorebook notation for one event, given the situation just before it:
    /// "6-3", "F8", "E6", "1B 7", "K", "ꓘ", "BB".
    func notation(for event: GameEvent, in situation: Situation) -> String
}

/// What a replay produces.
public struct GameReplay: Codable, Equatable, Sendable {
    /// Where the game stands after the last event.
    public var situation: Situation
    /// One entry per event.
    public var log: PlayLog

    public init(situation: Situation, log: PlayLog) {
        self.situation = situation
        self.log = log
    }
}

/// A ball in play the scorer is part way through entering. Everything is optional or empty
/// until the scorer picks it.
public struct PlayDraft: Codable, Equatable, Hashable, Sendable {
    /// How the sequence was started.
    public enum Context: String, Codable, Sendable {
        /// The "in play" button.
        case ballInPlay
        /// The "dropped third strike" button after strike three: the batter either was
        /// thrown out (`batterResult` `.out`) or reached (`.reachedOnDroppedThirdStrike`).
        case droppedThirdStrike
    }

    public var context: Context
    public var batterResult: BatterResult?
    public var battedBall: BattedBallType?
    /// Fielders tapped so far, in order.
    public var fielders: [Position]
    public var hitLocation: Position?
    public var hitSpot: FieldPoint?
    public var multiOut: MultiOutPlay?
    public var errors: [ErrorCharge]
    /// The runner outcomes as the scorer has them now. Empty until the runner step.
    public var runners: [RunnerMove]
    /// The scorer's runs batted in, if they changed the suggested number.
    public var rbi: Int?

    public init(
        context: Context = .ballInPlay,
        batterResult: BatterResult? = nil,
        battedBall: BattedBallType? = nil,
        fielders: [Position] = [],
        hitLocation: Position? = nil,
        hitSpot: FieldPoint? = nil,
        multiOut: MultiOutPlay? = nil,
        errors: [ErrorCharge] = [],
        runners: [RunnerMove] = [],
        rbi: Int? = nil
    ) {
        self.context = context
        self.batterResult = batterResult
        self.battedBall = battedBall
        self.fielders = fielders
        self.hitLocation = hitLocation
        self.hitSpot = hitSpot
        self.multiOut = multiOut
        self.errors = errors
        self.runners = runners
        self.rbi = rbi
    }

    /// The finished play, once the scorer has picked what happened to the batter.
    /// `suggestedRBI` fills in runs batted in if the scorer did not change them.
    public func finishedPlay(suggestedRBI: Int = 0) -> Play? {
        guard let batterResult else { return nil }
        return Play(
            batterResult: batterResult,
            battedBall: battedBall,
            fielders: fielders,
            hitLocation: hitLocation,
            hitSpot: hitSpot,
            runners: runners,
            errors: errors,
            multiOut: multiOut,
            rbi: rbi ?? suggestedRBI
        )
    }
}

/// The rules engine's best guess at where the runners ended up.
public struct RunnerSuggestion: Codable, Equatable, Hashable, Sendable {
    /// Every runner, batter included, with where they most likely ended up.
    public var runners: [RunnerMove]
    /// Runs batted in under the official scoring rules, for the scorer to confirm.
    public var rbi: Int

    public init(runners: [RunnerMove], rbi: Int) {
        self.runners = runners
        self.rbi = rbi
    }
}

/// What a play in progress would do, for the top of the in-play screen.
public struct PlayPreview: Codable, Equatable, Hashable, Sendable {
    /// Notation so far: "6", then "6-3".
    public var notation: String
    /// Outs this play makes.
    public var outsOnPlay: Int
    /// Runs that score on this play.
    public var runsOnPlay: Int
    /// Outs in the inning after the play, up to 3.
    public var outsAfter: Int
    /// True when the play makes the third out.
    public var endsHalfInning: Bool
    /// True when the play wins the game for the home team in its last at-bat.
    public var endsGame: Bool

    public init(notation: String, outsOnPlay: Int = 0, runsOnPlay: Int = 0, outsAfter: Int = 0, endsHalfInning: Bool = false, endsGame: Bool = false) {
        self.notation = notation
        self.outsOnPlay = outsOnPlay
        self.runsOnPlay = runsOnPlay
        self.outsAfter = outsAfter
        self.endsHalfInning = endsHalfInning
        self.endsGame = endsGame
    }
}

extension Situation {
    /// The situation before the first pitch: top of the first, nobody out, both teams'
    /// starting orders and fielders from the setup, leadoff hitters due up.
    public init(startOf setup: GameSetup) {
        func state(for team: GameTeam) -> TeamState {
            let slots = team.lineup.map {
                BattingSlot(players: [$0.player], position: $0.position, isDesignatedNonRunner: $0.isDesignatedNonRunner)
            }
            return TeamState(battingOrder: BattingOrder(slots: slots), nextBatterIndex: 0, fielders: team.startingFielders)
        }
        self.init(
            away: state(for: setup.away),
            home: state(for: setup.home),
            defenseCheckDue: setup.home.isOurs,
            scheduledInnings: setup.scheduledInnings
        )
    }
}

/// A rules engine that does nothing: every replay is the start of the game, every
/// suggestion leaves the runners where they are. For tests that need a `RulesEngine`
/// but not its answers. Screens use the canned one in SampleData instead.
public struct DoNothingRulesEngine: RulesEngine {
    public init() {}

    public func replay(_ game: Game) -> GameReplay {
        let start = Situation(startOf: game.setup)
        let log = PlayLog(
            gameID: game.id,
            setup: game.setup,
            entries: [],
            awayOrder: start.away.battingOrder,
            homeOrder: start.home.battingOrder,
            isFinal: false
        )
        return GameReplay(situation: start, log: log)
    }

    public func suggestRunners(for draft: PlayDraft, in situation: Situation) -> RunnerSuggestion {
        RunnerSuggestion(runners: draft.runners, rbi: draft.rbi ?? 0)
    }

    public func preview(_ draft: PlayDraft, in situation: Situation) -> PlayPreview {
        PlayPreview(notation: draft.fielders.map(\.description).joined(separator: "-"), outsAfter: situation.outs)
    }

    public func notation(for event: GameEvent, in situation: Situation) -> String {
        event.kind.label
    }
}
