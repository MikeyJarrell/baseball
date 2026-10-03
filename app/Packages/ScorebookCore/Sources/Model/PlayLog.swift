// The play log: the rules engine's account of what every event meant in context.
//
// The events say what the scorer tapped ("ball in play, 6-3"). The play log says what that
// meant at that moment: who was batting, who was pitching, who was standing at shortstop,
// how many were out before and after, who scored and which pitcher is charged with it.
// Stats are computed from the play log, so the rules of the game live in one place: the
// rules engine. Stats never look at the events on their own.

import Foundation

/// One game's play log: one entry per event, in order.
public struct PlayLog: Codable, Equatable, Sendable {
    public var gameID: GameID
    /// The game's setup, with both rosters as they stand at the end (every player who
    /// appeared, with their latest name and number), for box score names.
    public var setup: GameSetup
    /// One entry per event, oldest first.
    public var entries: [PlayLogEntry]
    /// The visiting team's batting order at the end of the game, with everyone who batted in
    /// each spot, so a box score can list substitutes under the player they replaced.
    public var awayOrder: BattingOrder
    /// The home team's batting order at the end of the game.
    public var homeOrder: BattingOrder
    /// True once the scorer has ended the game.
    public var isFinal: Bool

    public init(
        gameID: GameID,
        setup: GameSetup,
        entries: [PlayLogEntry],
        awayOrder: BattingOrder,
        homeOrder: BattingOrder,
        isFinal: Bool
    ) {
        self.gameID = gameID
        self.setup = setup
        self.entries = entries
        self.awayOrder = awayOrder
        self.homeOrder = homeOrder
        self.isFinal = isFinal
    }

    /// One team's final batting order, by side.
    public func battingOrder(_ side: TeamSide) -> BattingOrder {
        side == .away ? awayOrder : homeOrder
    }
}

/// What one event meant at the moment it happened.
public struct PlayLogEntry: Codable, Equatable, Sendable {
    /// The event this entry explains, copied in full.
    public var event: GameEvent
    /// The inning and half the event happened in. For a manual adjustment that moves the
    /// inning, the inning and half it moved the game to.
    public var inning: Int
    public var half: HalfInning
    /// The batter at the plate when the event happened (for a steal, the batter mid-count).
    public var batter: PlayerID?
    /// The batter's spot in the order, counting from 0.
    public var batterIndex: Int?
    /// The pitcher on the mound. Any pitch in this event counts against them.
    public var pitcher: PlayerID?
    /// Who was at each fielding position for the fielding team. Every putout, assist and
    /// error is tied to a player through this.
    public var fielders: [FielderAssignment]
    /// Outs, count and runners just before the event.
    public var before: BasesAndOuts
    /// Outs, count and runners just after it. When the event made the third out, this shows
    /// three outs and the runners still on base; the switch of sides happens between entries.
    ///
    /// Runners left on base are counted from this: the `after` runners of every entry that
    /// ends a half-inning, plus the `after` runners of the end-of-game entry, which are the
    /// runners still on base when the game ended (after a walk-off, or when the time limit
    /// ran out mid-inning). A game that ends right after a third out has nobody on base by
    /// then, so nobody is counted twice.
    public var after: BasesAndOuts
    /// Pitches this event added to the pitcher's count: 1 for a pitch or ball in play, else 0.
    public var pitches: Int
    /// Strikes this event added: 1 for a strike, foul or ball in play, else 0.
    public var strikes: Int
    /// Runs that scored on this event, each with the pitcher charged.
    public var runs: [RunScored]
    /// For a manual adjustment that changed the score: how many runs it added for each team
    /// (negative when it took runs away). These count in the line score and the team's runs,
    /// in this entry's inning, but belong to no player and no pitcher. Missing otherwise.
    public var adjustedRuns: Score?
    /// Every out made on this event, with the putout and assists tied to players.
    public var outs: [OutMade]
    /// Every error charged on this event, tied to the player at that position.
    public var errors: [ChargedError]
    /// When this event ended a plate appearance: how. Missing for a pitch that left the
    /// batter still batting, a steal, a substitution, and so on.
    public var plateAppearance: PlateAppearanceResult?
    /// True when this event made the third out of the half-inning.
    public var endsHalfInning: Bool
    /// The event in scorebook notation: "6-3", "F8", "E6", "1B 7", "K", "ꓘ", "BB", "SB2".
    public var notation: String
    /// True when the event no longer makes sense after an earlier one was edited, such as a
    /// steal by a runner who is no longer on base. The engine carries on as best it can.
    public var needsReview: Bool
    /// What looks wrong, for the scorer, when `needsReview` is true.
    public var reviewNote: String?

    public init(
        event: GameEvent,
        inning: Int,
        half: HalfInning,
        batter: PlayerID?,
        batterIndex: Int?,
        pitcher: PlayerID?,
        fielders: [FielderAssignment],
        before: BasesAndOuts,
        after: BasesAndOuts,
        pitches: Int = 0,
        strikes: Int = 0,
        runs: [RunScored] = [],
        adjustedRuns: Score? = nil,
        outs: [OutMade] = [],
        errors: [ChargedError] = [],
        plateAppearance: PlateAppearanceResult? = nil,
        endsHalfInning: Bool = false,
        notation: String,
        needsReview: Bool = false,
        reviewNote: String? = nil
    ) {
        self.event = event
        self.inning = inning
        self.half = half
        self.batter = batter
        self.batterIndex = batterIndex
        self.pitcher = pitcher
        self.fielders = fielders
        self.before = before
        self.after = after
        self.pitches = pitches
        self.strikes = strikes
        self.runs = runs
        self.adjustedRuns = adjustedRuns
        self.outs = outs
        self.errors = errors
        self.plateAppearance = plateAppearance
        self.endsHalfInning = endsHalfInning
        self.notation = notation
        self.needsReview = needsReview
        self.reviewNote = reviewNote
    }

    /// The team at bat during this event.
    public var battingSide: TeamSide { half.battingSide }
    /// The team in the field during this event.
    public var fieldingSide: TeamSide { half.fieldingSide }
}

/// Outs, count and runners at one moment.
public struct BasesAndOuts: Codable, Equatable, Hashable, Sendable {
    public var outs: Int
    public var count: Count
    public var runners: [BaseRunner]

    public init(outs: Int = 0, count: Count = .fresh, runners: [BaseRunner] = []) {
        self.outs = outs
        self.count = count
        self.runners = runners
    }
}

/// One run that scored.
public struct RunScored: Codable, Equatable, Hashable, Sendable {
    /// Who crossed the plate.
    public var runner: PlayerID
    /// Who gets credit for the run in the box score: the runner, or the designated non-runner a
    /// runner was running for.
    public var creditedTo: PlayerID
    /// The pitcher charged with the run: the one who put this runner on base.
    public var responsiblePitcher: PlayerID?

    public init(runner: PlayerID, creditedTo: PlayerID, responsiblePitcher: PlayerID?) {
        self.runner = runner
        self.creditedTo = creditedTo
        self.responsiblePitcher = responsiblePitcher
    }
}

/// One out, with fielding credit tied to players.
public struct OutMade: Codable, Equatable, Hashable, Sendable {
    /// Who was put out.
    public var runner: PlayerID
    /// The fielder credited with the putout (on a strikeout, the catcher).
    /// Missing when nobody is known to be playing that position.
    public var putout: PlayerID?
    /// The fielders credited with assists.
    public var assists: [PlayerID]
    /// The base where the out was made, if known.
    public var at: Base?

    public init(runner: PlayerID, putout: PlayerID?, assists: [PlayerID] = [], at: Base? = nil) {
        self.runner = runner
        self.putout = putout
        self.assists = assists
        self.at = at
    }
}

/// One error, tied to the player who was at that position.
public struct ChargedError: Codable, Equatable, Hashable, Sendable {
    public var fielder: Position
    /// The player at that position at the moment. Missing when unknown (an opponent's fielder
    /// nobody named).
    public var player: PlayerID?

    public init(fielder: Position, player: PlayerID?) {
        self.fielder = fielder
        self.player = player
    }
}

/// How a plate appearance ended.
public struct PlateAppearanceResult: Codable, Equatable, Hashable, Sendable {
    public var batter: PlayerID
    /// The pitcher charged with this batter. Usually the one on the mound, but a batter who
    /// walks after a pitching change made with the count at 2-0, 2-1, 3-0, 3-1 or 3-2 belongs
    /// to the earlier pitcher (Official Baseball Rules 9.16(h)).
    public var pitcher: PlayerID?
    public var outcome: PlateAppearanceOutcome
    /// Runs batted in. For a ball in play, the number the scorer confirmed on the play.
    public var rbi: Int
    /// True when the batter ended up safe on base or scored (a hit, a walk, an error,
    /// a dropped third strike).
    public var batterReachedBase: Bool

    public init(batter: PlayerID, pitcher: PlayerID?, outcome: PlateAppearanceOutcome, rbi: Int = 0, batterReachedBase: Bool) {
        self.batter = batter
        self.pitcher = pitcher
        self.outcome = outcome
        self.rbi = rbi
        self.batterReachedBase = batterReachedBase
    }
}

/// The ways a plate appearance can end.
public enum PlateAppearanceOutcome: String, Codable, Sendable, CaseIterable {
    case single
    case double
    case triple
    case homeRun
    case walk
    case intentionalWalk
    case hitByPitch
    /// Struck out, including on a dropped third strike (whether or not the batter reached).
    case strikeout
    /// Put out on a ball in play, including a double or triple play.
    case out
    case sacrificeFly
    case sacrificeBunt
    case reachedOnError
    case fieldersChoice
    case catchersInterference
}
