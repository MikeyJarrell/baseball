// The situation: everything the rules engine works out from the events about where the
// game stands right now. Inning, outs, count, score, runners, who is up, who is pitching.
//
// Screens are handed a situation to show; they never work one out themselves.

import Foundation

/// Where the game stands after the latest event.
public struct Situation: Codable, Equatable, Sendable {
    /// The inning, starting at 1. Goes past the scheduled innings in extra innings.
    public var inning: Int
    /// Top (visitors batting) or bottom (home team batting).
    public var half: HalfInning
    /// Outs in this half-inning, 0 to 2. Three outs end the half-inning, so the situation
    /// after a third out is already the next half-inning with no outs.
    public var outs: Int
    /// Balls and strikes on the current batter.
    public var count: Count
    public var score: Score
    /// Runners on base, at most one per base. Empty when the bases are empty.
    public var runners: [BaseRunner]
    /// The visiting team's batting order, fielders and who is due up.
    public var away: TeamState
    /// The home team's batting order, fielders and who is due up.
    public var home: TeamState
    /// Every pitcher who has pitched today, on both teams, with pitches and strikes.
    public var pitchers: [PitcherTally]
    /// The last play in scorebook notation, for the top of the batting screen: "6-3", "1B 7".
    public var lastPlayNotation: String?
    /// True after a third out until the next half-inning's first pitch: the changeover,
    /// when the between-innings music plays.
    public var isBetweenHalfInnings: Bool
    /// True when the fielding team is our team, a new half-inning has started, and the scorer
    /// has not yet confirmed who is at each position. The app opens the defense check.
    public var defenseCheckDue: Bool
    /// A designated non-runner who has just reached base and needs someone to run for them.
    /// The app opens the runner sheet straight away.
    public var runnerNeededFor: PlayerID?
    /// True right after a strike three that ended a plate appearance, until the next event.
    /// The batting screen offers the "dropped third strike" button.
    public var droppedThirdStrikePossible: Bool
    /// True when enough of the game has been played for it to be complete: the scheduled
    /// innings are done and the score is not tied, or the home team is ahead and does not
    /// need to bat. The scorer still decides when to end the game.
    public var isRegulationComplete: Bool
    /// True once the scorer has ended the game.
    public var isFinal: Bool
    /// When the first event was entered, for the game clock.
    public var gameStartedAt: Date?
    /// Innings in a full game, copied from the setup, so suggestions can tell when a hit
    /// in the bottom of the last inning ends the game.
    public var scheduledInnings: Int

    public init(
        inning: Int = 1,
        half: HalfInning = .top,
        outs: Int = 0,
        count: Count = .fresh,
        score: Score = Score(),
        runners: [BaseRunner] = [],
        away: TeamState,
        home: TeamState,
        pitchers: [PitcherTally] = [],
        lastPlayNotation: String? = nil,
        isBetweenHalfInnings: Bool = false,
        defenseCheckDue: Bool = false,
        runnerNeededFor: PlayerID? = nil,
        droppedThirdStrikePossible: Bool = false,
        isRegulationComplete: Bool = false,
        isFinal: Bool = false,
        gameStartedAt: Date? = nil,
        scheduledInnings: Int = 9
    ) {
        self.inning = inning
        self.half = half
        self.outs = outs
        self.count = count
        self.score = score
        self.runners = runners
        self.away = away
        self.home = home
        self.pitchers = pitchers
        self.lastPlayNotation = lastPlayNotation
        self.isBetweenHalfInnings = isBetweenHalfInnings
        self.defenseCheckDue = defenseCheckDue
        self.runnerNeededFor = runnerNeededFor
        self.droppedThirdStrikePossible = droppedThirdStrikePossible
        self.isRegulationComplete = isRegulationComplete
        self.isFinal = isFinal
        self.gameStartedAt = gameStartedAt
        self.scheduledInnings = scheduledInnings
    }

    // MARK: Handy lookups (no baseball worked out here, only reading what is stored)

    /// One team's state, by side.
    public subscript(side: TeamSide) -> TeamState {
        get { side == .away ? away : home }
        set { if side == .away { away = newValue } else { home = newValue } }
    }

    /// The team at bat.
    public var battingSide: TeamSide { half.battingSide }
    /// The team in the field.
    public var fieldingSide: TeamSide { half.fieldingSide }

    /// The batter at the plate.
    public var batter: PlayerID? { self[battingSide].currentBatter }
    /// The hitter on deck.
    public var onDeck: PlayerID? { self[battingSide].onDeckBatter }
    /// The pitcher on the mound.
    public var pitcher: PlayerID? { self[fieldingSide].pitcher }

    /// The runner on one base, if any.
    public func runner(on base: Base) -> BaseRunner? {
        runners.first { $0.base == base }
    }

    /// Which bases have a runner on them.
    public var occupiedBases: Set<Base> { Set(runners.map(\.base)) }

    /// Who is on each base, as player ids.
    public var baseOccupants: BaseOccupants {
        BaseOccupants(
            first: runner(on: .first)?.runner,
            second: runner(on: .second)?.runner,
            third: runner(on: .third)?.runner
        )
    }

    /// Today's pitches and strikes for one pitcher.
    public func tally(for pitcher: PlayerID) -> PitcherTally? {
        pitchers.first { $0.pitcher == pitcher }
    }
}

/// A runner standing on a base.
public struct BaseRunner: Codable, Equatable, Hashable, Sendable {
    /// Who is standing there. For a designated non-runner's runner, the runner.
    public var runner: PlayerID
    public var base: Base
    /// The pitcher charged if this runner scores: the one who put them on base.
    public var responsiblePitcher: PlayerID?
    /// For the runner for a designated non-runner: the designated non-runner they are
    /// running for, who stays in the batting order and is credited with the run.
    public var standingInFor: PlayerID?

    public init(runner: PlayerID, base: Base, responsiblePitcher: PlayerID? = nil, standingInFor: PlayerID? = nil) {
        self.runner = runner
        self.base = base
        self.responsiblePitcher = responsiblePitcher
        self.standingInFor = standingInFor
    }

    /// The player credited with the run if this runner scores.
    public var runCreditedTo: PlayerID { standingInFor ?? runner }
}

/// One team's side of the situation: its batting order, who is due up, and who is where in the field.
public struct TeamState: Codable, Equatable, Sendable {
    public var battingOrder: BattingOrder
    /// The spot in the order that is up (when batting) or will lead off next (when fielding),
    /// counting from 0 for the leadoff spot.
    public var nextBatterIndex: Int
    /// Who is at each fielding position now. A position nobody is known to be playing is left out.
    public var fielders: [FielderAssignment]

    public init(battingOrder: BattingOrder, nextBatterIndex: Int = 0, fielders: [FielderAssignment] = []) {
        self.battingOrder = battingOrder
        self.nextBatterIndex = nextBatterIndex
        self.fielders = fielders
    }

    /// The hitter in the spot that is up.
    public var currentBatter: PlayerID? {
        battingOrder.slots.indices.contains(nextBatterIndex) ? battingOrder.slots[nextBatterIndex].current : nil
    }

    /// The hitter after that, wrapping from the last spot back to the first.
    public var onDeckBatter: PlayerID? {
        guard !battingOrder.slots.isEmpty else { return nil }
        return battingOrder.slots[(nextBatterIndex + 1) % battingOrder.slots.count].current
    }

    /// Who is playing a position.
    public func fielder(at position: Position) -> PlayerID? {
        fielders.first { $0.position == position }?.player
    }

    /// The pitcher on the mound for this team.
    public var pitcher: PlayerID? { fielder(at: .pitcher) }
}

/// A team's batting order: a list of spots, always of known length. It can grow during the
/// game when a hitter is added, and it wraps from the last spot back to the first.
public struct BattingOrder: Codable, Equatable, Sendable {
    public var slots: [BattingSlot]

    public init(slots: [BattingSlot]) {
        self.slots = slots
    }

    /// Number of spots in the order.
    public var count: Int { slots.count }

    /// The spot a player is in now, counting from 0, if they are in the order.
    public func index(of player: PlayerID) -> Int? {
        slots.firstIndex { $0.current == player }
    }
}

/// One spot in the batting order, with everyone who has batted there.
public struct BattingSlot: Codable, Equatable, Sendable {
    /// Everyone who has held this spot, in order; the last one holds it now. A player can
    /// appear more than once, for a starter who left and came back.
    public var players: [PlayerID]
    /// Where the current player is fielding. Missing means extra hitter, or not yet in the field.
    public var position: Position?
    /// True when the current player is a designated non-runner.
    public var isDesignatedNonRunner: Bool

    public init(players: [PlayerID], position: Position? = nil, isDesignatedNonRunner: Bool = false) {
        self.players = players
        self.position = position
        self.isDesignatedNonRunner = isDesignatedNonRunner
    }

    /// The player who holds this spot now.
    public var current: PlayerID? { players.last }
}

/// Today's work for one pitcher.
public struct PitcherTally: Codable, Equatable, Hashable, Sendable {
    public var pitcher: PlayerID
    /// The team they pitch for.
    public var team: TeamSide
    /// Every pitch thrown, balls in play included. Intentional walks add none.
    public var pitches: Int
    /// Strikes, counting fouls and balls in play.
    public var strikes: Int
    /// Batters who have come to the plate against them.
    public var battersFaced: Int

    public init(pitcher: PlayerID, team: TeamSide, pitches: Int = 0, strikes: Int = 0, battersFaced: Int = 0) {
        self.pitcher = pitcher
        self.team = team
        self.pitches = pitches
        self.strikes = strikes
        self.battersFaced = battersFaced
    }
}
