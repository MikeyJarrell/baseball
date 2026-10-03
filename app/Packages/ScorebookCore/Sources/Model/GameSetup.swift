// A game and how it was set up before the first pitch.
//
// A game is its setup plus the ordered list of everything that happened (the events,
// in Events.swift). Nothing else about a game is saved: the score, the count and every
// stat are worked out fresh from the events by the rules engine.

import Foundation

/// One game: how it was set up, and every event in the order it was entered.
/// Saved as `games/<game id>.json`.
public struct Game: Identifiable, Codable, Equatable, Sendable {
    public var id: GameID
    public var setup: GameSetup
    /// Everything that happened, oldest first. Undo removes the last one.
    public var events: [GameEvent]

    public init(id: GameID = .make(), setup: GameSetup, events: [GameEvent] = []) {
        self.id = id
        self.setup = setup
        self.events = events
    }

    /// The end-of-game event, if the scorer has ended the game.
    public var ending: EndOfGame? {
        for event in events.reversed() {
            if case .endOfGame(let ending) = event.kind { return ending }
        }
        return nil
    }

    /// True once the scorer has ended the game.
    public var isFinished: Bool { ending != nil }
}

/// Everything decided before the first pitch: the teams, both lineups, the number of
/// innings and the time limit.
///
/// The two rosters inside it are this game's own copies. They can grow and be filled in
/// during the game (a new pitcher typed in by number, "Batter 4" given a name) without
/// recording an event: naming a hitter is true for the whole game, not from a moment on.
public struct GameSetup: Codable, Equatable, Sendable {
    /// When the game is played. Kept to the whole second (see `Date.wholeSecond`).
    public var date: Date
    /// The visiting team, who bat in the top of each inning.
    public var away: GameTeam
    /// The home team, who bat in the bottom of each inning.
    public var home: GameTeam
    /// Innings in a full game. Nine unless changed.
    public var scheduledInnings: Int
    /// The league's time limit in minutes, if there is one. The clock starts at the first event.
    public var timeLimitMinutes: Int?

    public init(
        date: Date,
        away: GameTeam,
        home: GameTeam,
        scheduledInnings: Int = 9,
        timeLimitMinutes: Int? = nil
    ) {
        self.date = date.wholeSecond
        self.away = away
        self.home = home
        self.scheduledInnings = scheduledInnings
        self.timeLimitMinutes = timeLimitMinutes
    }

    /// One team, by side.
    public subscript(side: TeamSide) -> GameTeam {
        get { side == .away ? away : home }
        set { if side == .away { away = newValue } else { home = newValue } }
    }

    /// Which side our team is on, or nothing if neither team is ours
    /// (scoring a televised game, for example).
    public var ourSide: TeamSide? {
        if home.isOurs { return .home }
        if away.isOurs { return .away }
        return nil
    }

    /// True when our team is the home team.
    public var weAreHome: Bool { home.isOurs }

    /// Finds a player on either team by id.
    public func player(_ id: PlayerID) -> Player? {
        away.player(id) ?? home.player(id)
    }

    /// Which team a player belongs to in this game.
    public func side(of id: PlayerID) -> TeamSide? {
        if away.player(id) != nil { return .away }
        if home.player(id) != nil { return .home }
        return nil
    }
}

/// One team as it lines up for one game: its roster for the day, its starting batting
/// order with fielding positions, and any fielders who do not bat.
public struct GameTeam: Codable, Equatable, Sendable {
    /// The saved team this came from.
    public var teamID: TeamID
    /// "Cardinals".
    public var name: String
    /// True for our team.
    public var isOurs: Bool
    /// Everyone available for this game, including players added during it.
    public var roster: [Player]
    /// The starting batting order, first hitter first. Any number of hitters.
    public var lineup: [LineupEntry]
    /// Starting fielders who are not in the batting order, such as a pitcher in a
    /// league with a designated hitter. Usually empty.
    public var fieldersNotBatting: [FielderAssignment]

    public init(
        teamID: TeamID,
        name: String,
        isOurs: Bool,
        roster: [Player],
        lineup: [LineupEntry],
        fieldersNotBatting: [FielderAssignment] = []
    ) {
        self.teamID = teamID
        self.name = name
        self.isOurs = isOurs
        self.roster = roster
        self.lineup = lineup
        self.fieldersNotBatting = fieldersNotBatting
    }

    /// Finds a player on this team by id.
    public func player(_ id: PlayerID) -> Player? {
        roster.first { $0.id == id }
    }

    /// Who starts at each fielding position: hitters with a position, plus fielders who do not bat.
    public var startingFielders: [FielderAssignment] {
        let batting = lineup.compactMap { entry in
            entry.position.map { FielderAssignment(position: $0, player: entry.player) }
        }
        return (batting + fieldersNotBatting).sorted { $0.position < $1.position }
    }

    /// The starting pitcher: whoever starts at position 1.
    public var startingPitcher: PlayerID? {
        startingFielders.first { $0.position == .pitcher }?.player
    }

    /// The designated non-runners in the starting lineup.
    public var designatedNonRunners: [PlayerID] {
        lineup.filter(\.isDesignatedNonRunner).map(\.player)
    }
}

/// One hitter in a starting batting order.
public struct LineupEntry: Codable, Equatable, Hashable, Sendable {
    public var player: PlayerID
    /// Where they play in the field. Missing means extra hitter: in the order, not in the field.
    /// For an opponent whose fielders are unknown, it may also simply be missing.
    public var position: Position?
    /// A designated non-runner bats, but someone else runs for them every time they reach base.
    public var isDesignatedNonRunner: Bool

    public init(player: PlayerID, position: Position? = nil, isDesignatedNonRunner: Bool = false) {
        self.player = player
        self.position = position
        self.isDesignatedNonRunner = isDesignatedNonRunner
    }

    // Reading from JSON: `isDesignatedNonRunner` may be left out and means false.
    private enum CodingKeys: String, CodingKey { case player, position, isDesignatedNonRunner }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        player = try c.decode(PlayerID.self, forKey: .player)
        position = try c.decodeIfPresent(Position.self, forKey: .position)
        isDesignatedNonRunner = try c.decodeIfPresent(Bool.self, forKey: .isDesignatedNonRunner) ?? false
    }
}

/// Who is playing one fielding position.
public struct FielderAssignment: Codable, Equatable, Hashable, Sendable {
    public var position: Position
    public var player: PlayerID

    public init(position: Position, player: PlayerID) {
        self.position = position
        self.player = player
    }
}

/// A player the scorer created on the spot during a game (a new pitcher typed in by number,
/// a pinch hitter not on the saved roster). The app adds them to that team's game roster.
public struct RosterAddition: Codable, Equatable, Hashable, Sendable {
    public var side: TeamSide
    public var player: Player

    public init(side: TeamSide, player: Player) {
        self.side = side
        self.player = player
    }
}

extension Date {
    /// This moment with the fraction of a second dropped. Event times and game dates are
    /// kept to the whole second so they read back from a saved file exactly as written.
    public var wholeSecond: Date {
        Date(timeIntervalSinceReferenceDate: timeIntervalSinceReferenceDate.rounded(.down))
    }
}
