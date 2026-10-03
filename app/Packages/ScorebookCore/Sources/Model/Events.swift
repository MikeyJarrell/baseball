// Events: the entries in a game's running list of everything that happened.
//
// A game is its setup plus these events, in order. Undo deletes the last one; fixing a
// mistake from three innings ago means editing that one event, and everything after it
// is worked out again. The ball-in-play event's details are in Play.swift.

import Foundation

/// One entry in a game's event list.
///
/// In JSON an event is one object with its `id`, its `enteredAt` time, and exactly one
/// more key naming its kind, whose value holds the details:
///
///     { "id": "e12", "enteredAt": "2026-05-02T18:31:07Z", "pitch": { "result": "ball" } }
///
/// When reading a hand-written file, `id` and `enteredAt` may be left out: a missing id
/// gets a fresh random one and a missing time reads as January 1, 2001.
public struct GameEvent: Identifiable, Codable, Equatable, Sendable {
    public var id: EventID
    /// When the scorer entered it, to the whole second.
    public var enteredAt: Date
    /// What happened.
    public var kind: EventKind

    public init(id: EventID = .make(), enteredAt: Date = Date(), kind: EventKind) {
        self.id = id
        self.enteredAt = enteredAt.wholeSecond
        self.kind = kind
    }

    // MARK: Reading and writing JSON

    private enum CodingKeys: String, CodingKey {
        case id, enteredAt
        case pitch, intentionalWalk, ballInPlay, runnerAction, errorWithNoAdvance
        case substitution, defenseConfirmed, runnerForNonRunner, pitchingChange, addHitter
        case battingHole, automaticOut, timeLimitChange, keepPlaying, manualAdjustment, endOfGame
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(EventID.self, forKey: .id) ?? .make()
        enteredAt = try c.decodeIfPresent(Date.self, forKey: .enteredAt)
            ?? Date(timeIntervalSinceReferenceDate: 0)
        // Exactly one kind key should be present; take the first one found.
        if let v = try c.decodeIfPresent(Pitch.self, forKey: .pitch) {
            kind = .pitch(v)
        } else if let v = try c.decodeIfPresent(IntentionalWalk.self, forKey: .intentionalWalk) {
            kind = .intentionalWalk(v)
        } else if let v = try c.decodeIfPresent(Play.self, forKey: .ballInPlay) {
            kind = .ballInPlay(v)
        } else if let v = try c.decodeIfPresent(RunnerAction.self, forKey: .runnerAction) {
            kind = .runnerAction(v)
        } else if let v = try c.decodeIfPresent(ErrorCharge.self, forKey: .errorWithNoAdvance) {
            kind = .errorWithNoAdvance(v)
        } else if let v = try c.decodeIfPresent(Substitution.self, forKey: .substitution) {
            kind = .substitution(v)
        } else if let v = try c.decodeIfPresent(DefenseConfirmed.self, forKey: .defenseConfirmed) {
            kind = .defenseConfirmed(v)
        } else if let v = try c.decodeIfPresent(RunnerForNonRunner.self, forKey: .runnerForNonRunner) {
            kind = .runnerForNonRunner(v)
        } else if let v = try c.decodeIfPresent(PitchingChange.self, forKey: .pitchingChange) {
            kind = .pitchingChange(v)
        } else if let v = try c.decodeIfPresent(AddHitter.self, forKey: .addHitter) {
            kind = .addHitter(v)
        } else if let v = try c.decodeIfPresent(BattingHole.self, forKey: .battingHole) {
            kind = .battingHole(v)
        } else if let v = try c.decodeIfPresent(AutomaticOut.self, forKey: .automaticOut) {
            kind = .automaticOut(v)
        } else if let v = try c.decodeIfPresent(TimeLimitChange.self, forKey: .timeLimitChange) {
            kind = .timeLimitChange(v)
        } else if let v = try c.decodeIfPresent(KeepPlaying.self, forKey: .keepPlaying) {
            kind = .keepPlaying(v)
        } else if let v = try c.decodeIfPresent(ManualAdjustment.self, forKey: .manualAdjustment) {
            kind = .manualAdjustment(v)
        } else if let v = try c.decodeIfPresent(EndOfGame.self, forKey: .endOfGame) {
            kind = .endOfGame(v)
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: .pitch, in: c,
                debugDescription: "An event needs one kind key, such as \"pitch\" or \"ballInPlay\"."
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(enteredAt, forKey: .enteredAt)
        switch kind {
        case .pitch(let v): try c.encode(v, forKey: .pitch)
        case .intentionalWalk(let v): try c.encode(v, forKey: .intentionalWalk)
        case .ballInPlay(let v): try c.encode(v, forKey: .ballInPlay)
        case .runnerAction(let v): try c.encode(v, forKey: .runnerAction)
        case .errorWithNoAdvance(let v): try c.encode(v, forKey: .errorWithNoAdvance)
        case .substitution(let v): try c.encode(v, forKey: .substitution)
        case .defenseConfirmed(let v): try c.encode(v, forKey: .defenseConfirmed)
        case .runnerForNonRunner(let v): try c.encode(v, forKey: .runnerForNonRunner)
        case .pitchingChange(let v): try c.encode(v, forKey: .pitchingChange)
        case .addHitter(let v): try c.encode(v, forKey: .addHitter)
        case .battingHole(let v): try c.encode(v, forKey: .battingHole)
        case .automaticOut(let v): try c.encode(v, forKey: .automaticOut)
        case .timeLimitChange(let v): try c.encode(v, forKey: .timeLimitChange)
        case .keepPlaying(let v): try c.encode(v, forKey: .keepPlaying)
        case .manualAdjustment(let v): try c.encode(v, forKey: .manualAdjustment)
        case .endOfGame(let v): try c.encode(v, forKey: .endOfGame)
        }
    }
}

/// The kinds of event, each with its details.
public enum EventKind: Equatable, Sendable {
    /// One pitch that did not put the ball in play.
    case pitch(Pitch)
    /// The batter is awarded first base with no pitches thrown.
    case intentionalWalk(IntentionalWalk)
    /// The ball was put in play: one complete play, from contact until the ball is dead.
    /// Counts as a pitch.
    case ballInPlay(Play)
    /// Between pitches, one or more runners moved or were put out (a steal, a pickoff,
    /// a wild pitch). A double steal is one event.
    case runnerAction(RunnerAction)
    /// An error with nobody moving, such as a dropped foul pop-up.
    case errorWithNoAdvance(ErrorCharge)
    /// Changes to the batting order, the defense, or both: pinch hitter, pinch runner,
    /// defensive replacement, position switch, re-entry. Several changes made at once are one event.
    case substitution(Substitution)
    /// The scorer checked a team's fielders at the start of a half-inning and nothing had changed.
    case defenseConfirmed(DefenseConfirmed)
    /// Someone runs for a designated non-runner who has just reached base, without changing
    /// the batting order. Nothing is recorded when the designated non-runner runs themselves.
    case runnerForNonRunner(RunnerForNonRunner)
    /// A new pitcher for the fielding team.
    case pitchingChange(PitchingChange)
    /// A hitter added to the bottom of a team's batting order.
    case addHitter(AddHitter)
    /// A batting spot whose player is lost with nobody to replace them: an automatic out each
    /// time it comes up.
    case battingHole(BattingHole)
    /// The automatic out at a batting hole, recorded by the app when the hole comes up.
    case automaticOut(AutomaticOut)
    /// The umpire's time limit: a new end time.
    case timeLimitChange(TimeLimitChange)
    /// Asked whether the game is over, the scorer said to keep playing.
    case keepPlaying(KeepPlaying)
    /// Sets outs, count, score, runners or the batter directly, when the field and the book disagree.
    case manualAdjustment(ManualAdjustment)
    /// The scorer ended the game.
    case endOfGame(EndOfGame)

    /// A short name for the kind, for undo labels and debugging: "pitch", "ball in play".
    public var label: String {
        switch self {
        case .pitch(let p): p.result.label
        case .intentionalWalk: "intentional walk"
        case .ballInPlay: "ball in play"
        case .runnerAction: "runner move"
        case .errorWithNoAdvance: "error"
        case .substitution: "substitution"
        case .defenseConfirmed: "defense check"
        case .runnerForNonRunner: "runner for designated non-runner"
        case .pitchingChange: "pitching change"
        case .addHitter: "added hitter"
        case .battingHole: "batting hole"
        case .automaticOut: "automatic out"
        case .timeLimitChange: "time limit"
        case .keepPlaying: "keep playing"
        case .manualAdjustment: "manual adjustment"
        case .endOfGame: "end of game"
        }
    }
}

/// What the scorer entered, plus any players they created on the spot to do it
/// (a new pitcher known only by number). This is what an in-game sheet hands back:
/// the app adds the new players to the game's rosters, then records the event.
public struct EnteredEvent: Equatable, Sendable {
    public var event: GameEvent
    public var newPlayers: [RosterAddition]

    public init(event: GameEvent, newPlayers: [RosterAddition] = []) {
        self.event = event
        self.newPlayers = newPlayers
    }
}

/// A change to an event already in the list, handed back by the play-by-play screen.
/// Everything after the changed event is worked out again.
public enum EventEdit: Codable, Equatable, Sendable {
    /// Put this event in place of the one with the same id.
    case replace(GameEvent)
    /// Remove the event with this id.
    case delete(EventID)
    /// Put a forgotten event in after the one with this id (or at the very start when missing).
    case insert(GameEvent, after: EventID?)
}

// MARK: - Pitches

/// One pitch that did not put the ball in play.
public struct Pitch: Codable, Equatable, Hashable, Sendable {
    public var result: PitchResult
    /// Only on a third strike the catcher did not catch cleanly: what the batter did next,
    /// either thrown out (`batterResult` `.out`, fielders `[2, 3]` for "K 2-3") or safe
    /// (`.reachedOnDroppedThirdStrike`), and where every runner ended up.
    /// It is still a strikeout for the batter and the pitcher either way.
    public var droppedThirdStrike: Play?

    public init(_ result: PitchResult, droppedThirdStrike: Play? = nil) {
        self.result = result
        self.droppedThirdStrike = droppedThirdStrike
    }
}

/// What one pitch was.
public enum PitchResult: String, Codable, Sendable, CaseIterable {
    case ball
    /// Strike, batter did not swing.
    case calledStrike
    /// Strike, batter swung and missed.
    case swingingStrike
    /// Foul ball. A strike unless the batter already has two.
    case foul
    /// Foul tip caught by the catcher: always a strike, and strike three with two strikes.
    case foulTip
    /// Bunted foul: always a strike, and strike three with two strikes.
    case foulBunt
    /// Hit by the pitch: the batter is awarded first. A pitch, not a strike.
    case hitByPitch

    /// A word for undo labels: "ball", "called strike".
    public var label: String {
        switch self {
        case .ball: "ball"
        case .calledStrike: "called strike"
        case .swingingStrike: "swinging strike"
        case .foul: "foul"
        case .foulTip: "foul tip"
        case .foulBunt: "foul bunt"
        case .hitByPitch: "hit by pitch"
        }
    }
}

/// The batter is awarded first base with no pitches thrown. No details needed.
public struct IntentionalWalk: Codable, Equatable, Hashable, Sendable {
    public init() {}
}

// MARK: - Runners and errors

/// Between pitches, one or more runners moved or were put out.
/// Each runner carries their own reason, so a double steal is one event with two moves.
public struct RunnerAction: Codable, Equatable, Hashable, Sendable {
    /// Every runner who moved or was put out.
    public var moves: [RunnerMove]
    /// Errors charged on this action, such as a catcher's wild throw on a steal.
    public var errors: [ErrorCharge]
    /// True when a runner was put out on the same pitch as the strikeout just before ("strike
    /// him out, throw him out": a runner caught stealing or picked off on strike three). The
    /// strike-three pitch and this action stay two events, and official scoring counts them as
    /// one double play by the fielding team.
    public var completesStrikeoutDoublePlay: Bool

    public init(moves: [RunnerMove], errors: [ErrorCharge] = [], completesStrikeoutDoublePlay: Bool = false) {
        self.moves = moves
        self.errors = errors
        self.completesStrikeoutDoublePlay = completesStrikeoutDoublePlay
    }

    // Reading from JSON: `errors` and `completesStrikeoutDoublePlay` may be left out.
    private enum CodingKeys: String, CodingKey { case moves, errors, completesStrikeoutDoublePlay }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        moves = try c.decode([RunnerMove].self, forKey: .moves)
        errors = try c.decodeIfPresent([ErrorCharge].self, forKey: .errors) ?? []
        completesStrikeoutDoublePlay = try c.decodeIfPresent(Bool.self, forKey: .completesStrikeoutDoublePlay) ?? false
    }
}

/// Where one runner (or the batter) went: used inside plays and runner actions.
///
/// Runners are named by player id, so the move still means the same thing if an
/// earlier event is edited. `from` records where the scorer saw them start; the rules
/// engine flags the event for review if the runner is no longer there.
public struct RunnerMove: Codable, Equatable, Hashable, Sendable {
    /// Who ran. For the runner for a designated non-runner, the runner themself.
    public var runner: PlayerID
    /// Where they started. `.home` means this is the batter.
    public var from: Base
    /// Where they ended up: a base, scored, or out.
    public var to: RunnerEnd
    /// Why they moved. Always given for moves between pitches (stolen base, wild pitch).
    /// On a ball in play it is usually left out, meaning they moved on the play; it can be
    /// given when something else moved them, such as a wild pitch or passed ball that let the
    /// batter reach first on a dropped third strike.
    ///
    /// A stolen base is always one base. Any bases past it came from an error, marked with
    /// `advancedOnError`: a runner who steals third and scores when the throw gets away is
    /// `from: second, to: scored, reason: stolenBase, advancedOnError: true`, a steal of third
    /// and an error. A steal of home is `from: third, to: scored, reason: stolenBase`.
    public var reason: RunnerMoveReason?
    /// For a runner put out: the fielders who handled the ball, in order. The last one
    /// made the putout; each one before gets an assist. A force at second on a 5-4-3 is `[5, 4]`.
    public var outBy: [Position]
    /// For a runner put out: the base they were put out at, if the scorer says.
    public var outAt: Base?
    /// True when an error let this runner reach or move up. The error itself is listed once
    /// on the play or runner action, even when it helped several runners.
    public var advancedOnError: Bool
    /// For a pickoff: the runner was picked off while trying to steal, which official scoring
    /// counts as caught stealing (Official Baseball Rules 9.07(h)).
    public var wasStealing: Bool

    public init(
        runner: PlayerID,
        from: Base,
        to: RunnerEnd,
        reason: RunnerMoveReason? = nil,
        outBy: [Position] = [],
        outAt: Base? = nil,
        advancedOnError: Bool = false,
        wasStealing: Bool = false
    ) {
        self.runner = runner
        self.from = from
        self.to = to
        self.reason = reason
        self.outBy = outBy
        self.outAt = outAt
        self.advancedOnError = advancedOnError
        self.wasStealing = wasStealing
    }

    /// True when this move counts as caught stealing in the box score: marked caught stealing,
    /// or a pickoff of a runner who was trying to steal and was put out.
    public var countsAsCaughtStealing: Bool {
        reason == .caughtStealing || (reason == .pickoff && wasStealing && to == .out)
    }

    /// True when this move is the batter's.
    public var isBatter: Bool { from == .home }

    // Reading from JSON: `outBy`, `advancedOnError` and `wasStealing` may be left out.
    private enum CodingKeys: String, CodingKey { case runner, from, to, reason, outBy, outAt, advancedOnError, wasStealing }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        runner = try c.decode(PlayerID.self, forKey: .runner)
        from = try c.decode(Base.self, forKey: .from)
        to = try c.decode(RunnerEnd.self, forKey: .to)
        reason = try c.decodeIfPresent(RunnerMoveReason.self, forKey: .reason)
        outBy = try c.decodeIfPresent([Position].self, forKey: .outBy) ?? []
        outAt = try c.decodeIfPresent(Base.self, forKey: .outAt)
        advancedOnError = try c.decodeIfPresent(Bool.self, forKey: .advancedOnError) ?? false
        wasStealing = try c.decodeIfPresent(Bool.self, forKey: .wasStealing) ?? false
    }
}

/// Why a runner moved or was put out between pitches.
public enum RunnerMoveReason: String, Codable, Sendable, CaseIterable {
    case stolenBase
    case caughtStealing
    /// Picked off. Mark the move `wasStealing` when the runner was trying to steal: official
    /// scoring counts that as caught stealing.
    case pickoff
    case wildPitch
    case passedBall
    case balk
    /// Moved up on an error, such as a pickoff throw that got away.
    case advanceOnError
    /// Allowed to take the base with no throw; not a stolen base.
    case defensiveIndifference
    /// Called out on appeal, such as for missing a base.
    case outOnAppeal
    /// Anything else, such as moving up on a throw to another base.
    case other
}

/// An error charged to the fielder at a position. The rules engine works out which
/// player that was from who was standing there at the moment.
public struct ErrorCharge: Codable, Equatable, Hashable, Sendable {
    public var fielder: Position
    /// Fielding (a bobble or a drop) or throwing, if the scorer says.
    public var type: ErrorType?

    public init(fielder: Position, type: ErrorType? = nil) {
        self.fielder = fielder
        self.type = type
    }
}

/// The two kinds of error.
public enum ErrorType: String, Codable, Sendable, CaseIterable {
    /// Booted, bobbled or dropped the ball.
    case fielding
    /// Threw the ball away.
    case throwing
}

// MARK: - Lineup changes

/// Changes to a team's batting order, its defense, or both, entered at once. The batting order
/// and the defense are separate lists, so a substitution can touch one without the other:
/// moving the shortstop to second is a defense change only, and a pinch hitter is a batting
/// change only until they take the field.
public struct Substitution: Codable, Equatable, Hashable, Sendable {
    /// The team making the changes.
    public var team: TeamSide
    /// Changes to the batting order: who now holds a spot.
    public var batting: [BattingChange]
    /// Changes to the defense: who plays each listed position from now on. A player listed at a
    /// new position leaves their old one. A player whose position goes to someone else and who
    /// is not listed anywhere leaves the field, and keeps their batting spot if they have one.
    /// Positions not listed stay as they were.
    public var defense: [FielderAssignment]
    /// Players who leave the field with nobody taking their position, which stays empty: a
    /// team playing short-handed after losing a fielder. They keep their batting spot if they
    /// have one.
    public var leavesField: [PlayerID]

    public init(team: TeamSide, batting: [BattingChange] = [], defense: [FielderAssignment] = [], leavesField: [PlayerID] = []) {
        self.team = team
        self.batting = batting
        self.defense = defense
        self.leavesField = leavesField
    }

    // Reading from JSON: any of the lists may be left out.
    private enum CodingKeys: String, CodingKey { case team, batting, defense, leavesField }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        team = try c.decode(TeamSide.self, forKey: .team)
        batting = try c.decodeIfPresent([BattingChange].self, forKey: .batting) ?? []
        defense = try c.decodeIfPresent([FielderAssignment].self, forKey: .defense) ?? []
        leavesField = try c.decodeIfPresent([PlayerID].self, forKey: .leavesField) ?? []
    }
}

/// One player taking over a spot in the batting order from another, who leaves the batting order.
///
/// - Pinch hitter: `incoming` bats now in `replacing`'s spot.
/// - Pinch runner: `incoming` also takes `replacing`'s place on base. A pinch runner for a
///   designated non-runner takes the non-runner out of the batting order [9.11 M]. A pinch runner
///   for the runner who is running for a designated non-runner takes that runner's own batting
///   spot and keeps running for the non-runner, who stays in the order [9.11 N].
/// - Replacement: `incoming` takes the spot without batting or running right now, such as a
///   player coming in to field, or a starter re-entering in their original spot.
///
/// The league's re-entry rules (only starters, always to their original spot, only after their
/// substitute has batted [9.6 B, 9.9]) are not enforced: the situation lists who is eligible
/// (`TeamState.eligibleToReenter`), and the scorer records what happened.
public struct BattingChange: Codable, Equatable, Hashable, Sendable {
    public var kind: BattingChangeKind
    /// The player coming into the batting order.
    public var incoming: PlayerID
    /// The player whose spot they take.
    public var replacing: PlayerID

    public init(kind: BattingChangeKind, incoming: PlayerID, replacing: PlayerID) {
        self.kind = kind
        self.incoming = incoming
        self.replacing = replacing
    }
}

/// The kinds of batting order change. The kind is what the box score prints ("ph", "pr").
public enum BattingChangeKind: String, Codable, Sendable, CaseIterable {
    case pinchHitter
    case pinchRunner
    case replacement
}

/// A spot in the batting order whose player is lost (injured, ejected, gone home) with nobody
/// eligible to take it. The order is not shortened: each time the spot comes up, it is an
/// automatic out [9.2 B, 9.5 C]. The situation says when (`Situation.isBattingHoleUp`) and the
/// app records an `automaticOut` event straight away. A later batting change into the spot
/// fills it again.
public struct BattingHole: Codable, Equatable, Hashable, Sendable {
    public var team: TeamSide
    /// The spot, counting from 0 for the leadoff spot.
    public var spotIndex: Int

    public init(team: TeamSide, spotIndex: Int) {
        self.team = team
        self.spotIndex = spotIndex
    }
}

/// The out recorded when a batting hole comes up. The app records it as soon as the situation
/// says the hole is up, without the scorer tapping anything, and from then on it is an ordinary
/// event: saved with the game, undone and edited like any other.
///
/// In the play log it is one out for the batting team:
/// - nobody's plate appearance and nobody's at-bat;
/// - no putout or assist for any fielder (the play log's `OutMade` names the player who last
///   held the spot, with no putout);
/// - counted toward the pitcher's outs and innings pitched;
/// - not a "recorded out" for the designated non-runner rule [9.11 D]: that player has left
///   the game, so the suggestion looks past it.
public struct AutomaticOut: Codable, Equatable, Hashable, Sendable {
    public var team: TeamSide
    /// The batting hole's spot, counting from 0.
    public var spotIndex: Int

    public init(team: TeamSide, spotIndex: Int) {
        self.team = team
        self.spotIndex = spotIndex
    }
}

/// The scorer was asked whether the game is over (`Situation.gameOverQuestion`) and the teams
/// kept playing. Recorded as an event so that undo and replay remember the answer: the same
/// reason is not asked again in this game, and innings after it are ordinary innings.
public struct KeepPlaying: Codable, Equatable, Hashable, Sendable {
    /// The question that was answered.
    public var reason: EndOfGame.Reason

    public init(reason: EndOfGame.Reason) {
        self.reason = reason
    }
}

/// The umpire keeps the official time [9.1 B] and can extend the limit [9.1 I]. This sets the
/// moment after which no new inning may begin, replacing the one worked out from the first
/// pitch and the setup's time limit.
public struct TimeLimitChange: Codable, Equatable, Hashable, Sendable {
    /// The new end of the time limit. Missing goes back to the first pitch plus the setup's limit.
    public var endsAt: Date?
    /// Why, if the scorer says ("911 call, umpire added 20 minutes").
    public var note: String?

    public init(endsAt: Date?, note: String? = nil) {
        self.endsAt = endsAt
        self.note = note
    }
}

/// The scorer checked a team's fielders at the start of a half-inning and nothing had changed.
/// Changes found during the check are recorded as a substitution.
public struct DefenseConfirmed: Codable, Equatable, Hashable, Sendable {
    public var team: TeamSide
    public init(team: TeamSide) { self.team = team }
}

/// Someone running for a designated non-runner who has just reached base. Our league has
/// designated non-runners: players declared before the game who bat, and who may have
/// someone else run for them when they reach. By league rule the runner is the teammate who
/// made the team's most recent out; the app suggests that player (see
/// `Situation.runnerChoice`). The runner takes the base without changing the batting order;
/// the designated non-runner stays in their spot and is credited with the run if the runner
/// scores. Stolen bases and caught stealing go to the runner, who actually ran.
///
/// A designated non-runner who chooses to run themselves needs no event at all: the scorer
/// simply carries on, and they stay on base like any other runner.
///
/// An ordinary pinch runner, who replaces a player for good, is a `Substitution` instead.
public struct RunnerForNonRunner: Codable, Equatable, Hashable, Sendable {
    /// Who runs.
    public var runner: PlayerID
    /// The designated non-runner on base now, who comes off the bases but stays in the order.
    public var replacing: PlayerID

    public init(runner: PlayerID, replacing: PlayerID) {
        self.runner = runner
        self.replacing = replacing
    }
}

/// A new pitcher for the fielding team. The new pitcher plays position 1 and leaves any other
/// position they were playing. It changes the defense only: the old pitcher keeps their batting
/// spot, if they had one, unless `takesBattingSpotOf` says the new pitcher takes it, or someone
/// else's (the pinch hitter who just batted for the old pitcher, say). If the old pitcher stays
/// in the field, `previousPitcherMovesTo` says where.
///
/// A pitcher once removed may come back to pitch once per game [9.12 B]; the situation lists who
/// may (`TeamState.eligibleToPitchAgain`).
public struct PitchingChange: Codable, Equatable, Hashable, Sendable {
    public var team: TeamSide
    public var newPitcher: PlayerID
    public var previousPitcherMovesTo: Position?
    /// Whose batting spot the new pitcher takes, if any. That player leaves the batting order.
    public var takesBattingSpotOf: PlayerID?

    public init(team: TeamSide, newPitcher: PlayerID, previousPitcherMovesTo: Position? = nil, takesBattingSpotOf: PlayerID? = nil) {
        self.team = team
        self.newPitcher = newPitcher
        self.previousPitcherMovesTo = previousPitcherMovesTo
        self.takesBattingSpotOf = takesBattingSpotOf
    }
}

/// A hitter added to the bottom of a team's batting order, at any time [9.5 B]. The order
/// includes them from now on; if the old last hitter has just batted, the new hitter is up
/// next. Putting them in the field is a separate substitution.
public struct AddHitter: Codable, Equatable, Hashable, Sendable {
    public var team: TeamSide
    public var player: PlayerID

    public init(team: TeamSide, player: PlayerID) {
        self.team = team
        self.player = player
    }
}

// MARK: - Overrides and the end

/// Sets parts of the situation directly, for when the field and the book disagree and
/// nobody can say why. Whatever is filled in replaces what the rules engine had worked
/// out; whatever is left out stays as it was.
///
/// Runs added or taken away by changing the score belong to that team in the inning the
/// adjustment leaves the game in (the inning it was entered in, unless the adjustment also
/// moves the inning). Stats put them in that team's cell of the line score and in its runs,
/// so the box score always adds up to the final score. No player is credited with them and
/// no pitcher is charged with them.
public struct ManualAdjustment: Codable, Equatable, Hashable, Sendable {
    public var inning: Int?
    public var half: HalfInning?
    public var outs: Int?
    public var count: Count?
    public var score: Score?
    /// Who is on each base. When filled in, it replaces all three bases at once.
    /// Runners placed this way are charged to the pitcher on the mound.
    public var runners: BaseOccupants?
    /// Which spot in the batting team's order is up, counting from 0 for the leadoff spot.
    public var batterIndex: Int?
    /// Why the scorer made the change, if they say.
    public var note: String?

    public init(
        inning: Int? = nil,
        half: HalfInning? = nil,
        outs: Int? = nil,
        count: Count? = nil,
        score: Score? = nil,
        runners: BaseOccupants? = nil,
        batterIndex: Int? = nil,
        note: String? = nil
    ) {
        self.inning = inning
        self.half = half
        self.outs = outs
        self.count = count
        self.score = score
        self.runners = runners
        self.batterIndex = batterIndex
        self.note = note
    }
}

/// Who is standing on each base. Empty bases are left out.
public struct BaseOccupants: Codable, Equatable, Hashable, Sendable {
    public var first: PlayerID?
    public var second: PlayerID?
    public var third: PlayerID?

    public init(first: PlayerID? = nil, second: PlayerID? = nil, third: PlayerID? = nil) {
        self.first = first
        self.second = second
        self.third = third
    }

    /// Nobody on.
    public static let empty = BaseOccupants()

    /// The runner on one base.
    public subscript(base: Base) -> PlayerID? {
        switch base {
        case .first: first
        case .second: second
        case .third: third
        case .home: nil
        }
    }
}

/// The scorer ended the game.
public struct EndOfGame: Codable, Equatable, Hashable, Sendable {
    /// Why the game ended.
    public enum Reason: String, Codable, Sendable, CaseIterable {
        /// The scheduled innings were played, or the home team won in its last at-bat.
        case regulation
        /// The time limit ran out [9.1 G]. A tie at the time limit stays a tie.
        case timeLimit
        /// One team led by the run rule's margin [9.13].
        case runRule
        /// Rain, darkness, or anything else that stopped play.
        case called
    }

    public var reason: Reason
    /// The final score as the rules engine had it when the game ended. A copy kept so the
    /// games list can show results without replaying every game; the events stay the truth.
    public var finalScore: Score?

    public init(reason: Reason, finalScore: Score? = nil) {
        self.reason = reason
        self.finalScore = finalScore
    }
}
