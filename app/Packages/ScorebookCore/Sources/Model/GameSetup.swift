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

/// Everything decided before the first pitch: the teams, both batting orders and starting
/// defenses, when the game is scheduled, and the rules it is played under.
///
/// The two rosters inside it are this game's own copies. They can grow and be filled in
/// during the game (a new pitcher typed in by number, "Batter 4" given a name) without
/// recording an event: naming a hitter is true for the whole game, not from a moment on.
public struct GameSetup: Codable, Equatable, Sendable {
    /// When the game is scheduled to start: 9:00 in the morning unless changed (see
    /// `GameSetup.nineInTheMorning(on:)`). Kept to the whole second (see `Date.wholeSecond`).
    /// The time limit runs from the actual start, the first pitch, not from this.
    public var scheduledStart: Date
    /// The visiting team, who bat in the top of each inning.
    public var away: GameTeam
    /// The home team, who bat in the bottom of each inning.
    public var home: GameTeam
    /// Innings, time limit, run rule and designated non-runners: the league's rules unless changed.
    public var rules: GameRules

    public init(scheduledStart: Date, away: GameTeam, home: GameTeam, rules: GameRules = .league) {
        self.scheduledStart = scheduledStart.wholeSecond
        self.away = away
        self.home = home
        self.rules = rules
    }

    /// Innings in a full game. Nine unless changed.
    public var scheduledInnings: Int { rules.scheduledInnings }

    /// The time limit in minutes, if there is one.
    public var timeLimitMinutes: Int? { rules.timeLimitMinutes }

    /// When the time limit would run out if the game started on schedule: what the app shows
    /// before the first pitch.
    public var scheduledEnd: Date? {
        timeLimitMinutes.map { scheduledStart.addingTimeInterval(Double($0 * 60)) }
    }

    /// 9:00 in the morning on a given day, in the phone's time zone: the usual start time.
    public static func nineInTheMorning(on day: Date, calendar: Calendar = .current) -> Date {
        calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day) ?? day
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

    // Reading from JSON: `rules` may be left out and means the league's rules.
    private enum CodingKeys: String, CodingKey { case scheduledStart, away, home, rules }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        scheduledStart = try c.decode(Date.self, forKey: .scheduledStart)
        away = try c.decode(GameTeam.self, forKey: .away)
        home = try c.decode(GameTeam.self, forKey: .home)
        rules = try c.decodeIfPresent(GameRules.self, forKey: .rules) ?? .league
    }
}

/// The rules a game is played under. The San Diego Adult Baseball League's rule numbers are
/// in brackets; `notes/league-rules.md` summarizes them.
public struct GameRules: Codable, Equatable, Hashable, Sendable {
    /// Innings in a full game: nine [9.1 D]. A tie after them with time left goes to extra innings.
    public var scheduledInnings: Int
    /// Minutes from the first pitch after which no new inning may begin, set for each game:
    /// three hours by default [9.1 G], with three and a quarter offered for a championship game
    /// [9.1 J]. Missing means no time limit.
    ///
    /// The rule book disagrees with itself here: rule 8.1 C 2 says championship games have no
    /// time limit and a run rule announced before the playoffs, and 8.1 C 1 says a playoff game
    /// tied at the limit keeps going. Since the time limit only asks a question, the scorer
    /// handles either reading.
    public var timeLimitMinutes: Int?
    /// A lead this big ends the game by the run rule: 12 runs, or 15 in a championship game [9.13].
    /// Missing means no run rule.
    public var runRuleMargin: Int?
    /// The run rule applies at the end of this inning and every one after it (or after its top
    /// half if the home team leads): the seventh [9.13].
    public var runRuleInning: Int
    /// How many designated non-runners each team may declare: two in the 18-and-over division [9.11 J].
    public var maxDesignatedNonRunners: Int

    public init(
        scheduledInnings: Int = 9,
        timeLimitMinutes: Int? = 180,
        runRuleMargin: Int? = 12,
        runRuleInning: Int = 7,
        maxDesignatedNonRunners: Int = 2
    ) {
        self.scheduledInnings = scheduledInnings
        self.timeLimitMinutes = timeLimitMinutes
        self.runRuleMargin = runRuleMargin
        self.runRuleInning = runRuleInning
        self.maxDesignatedNonRunners = maxDesignatedNonRunners
    }

    /// An ordinary league game: nine innings, three hours, 12-run rule after seven, two non-runners.
    public static let league = GameRules()

    /// A championship game as rules 9.1 J and 9.13 B describe it: three hours and fifteen
    /// minutes, 15-run rule. Offered as a choice; see `timeLimitMinutes` for rule 8.1 C.
    public static let championship = GameRules(timeLimitMinutes: 195, runRuleMargin: 15)

    // Reading from JSON: anything left out takes the league's value.
    private enum CodingKeys: String, CodingKey {
        case scheduledInnings, timeLimitMinutes, runRuleMargin, runRuleInning, maxDesignatedNonRunners
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = GameRules.league
        scheduledInnings = try c.decodeIfPresent(Int.self, forKey: .scheduledInnings) ?? d.scheduledInnings
        timeLimitMinutes = c.contains(.timeLimitMinutes) ? try c.decodeIfPresent(Int.self, forKey: .timeLimitMinutes) : d.timeLimitMinutes
        runRuleMargin = c.contains(.runRuleMargin) ? try c.decodeIfPresent(Int.self, forKey: .runRuleMargin) : d.runRuleMargin
        runRuleInning = try c.decodeIfPresent(Int.self, forKey: .runRuleInning) ?? d.runRuleInning
        maxDesignatedNonRunners = try c.decodeIfPresent(Int.self, forKey: .maxDesignatedNonRunners) ?? d.maxDesignatedNonRunners
    }

    // Writing JSON: a missing time limit or run rule is written as null, so it reads back as
    // "none" and not as the league's value.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(scheduledInnings, forKey: .scheduledInnings)
        try c.encode(timeLimitMinutes, forKey: .timeLimitMinutes)
        try c.encode(runRuleMargin, forKey: .runRuleMargin)
        try c.encode(runRuleInning, forKey: .runRuleInning)
        try c.encode(maxDesignatedNonRunners, forKey: .maxDesignatedNonRunners)
    }
}

/// One team as it lines up for one game: everyone at the field, the batting order, and the
/// starting defense. The batting order and the defense are separate lists [9.5 C, 3.5 B 2]:
/// a player may bat only, field only (a pitcher who does not bat), or both.
public struct GameTeam: Codable, Equatable, Sendable {
    /// The saved team this came from.
    public var teamID: TeamID
    /// "Mudcats".
    public var name: String
    /// True for our team.
    public var isOurs: Bool
    /// Everyone at the field for this game, including players added during it.
    public var roster: [Player]
    /// The starting batting order, first hitter first. Any number of hitters [9.5 A].
    public var battingOrder: [PlayerID]
    /// Who starts at each fielding position, one player per position. A position nobody is
    /// known to be playing (an opponent nobody knows, or a team playing short-handed) is left out.
    public var defense: [FielderAssignment]
    /// Players declared as designated non-runners, from the batting order or the eligible
    /// substitutes on the bench [9.4 C]. Declared before the game and never after it starts
    /// [9.11 C]; at most `GameRules.maxDesignatedNonRunners`, which the app shows but does not
    /// enforce. When one reaches base, the teammate the rule names may run for them, or they may
    /// run themselves; the scorer is asked each time [9.11 A, D]. A substitute who is declared
    /// keeps the declaration when they come into the batting order.
    public var designatedNonRunners: [PlayerID]
    /// Positions shared by turns, inning by inning: one first baseman in odd innings and another
    /// in even innings, say, often with only one of them batting. Each half-inning this team
    /// takes the field, the rules engine suggests the defense with these turns applied
    /// (`Situation.suggestedDefense`) and the defense check starts from it. Nothing changes
    /// until the scorer confirms it.
    public var fieldingRotations: [FieldingRotation]

    public init(
        teamID: TeamID,
        name: String,
        isOurs: Bool,
        roster: [Player],
        battingOrder: [PlayerID],
        defense: [FielderAssignment],
        designatedNonRunners: [PlayerID] = [],
        fieldingRotations: [FieldingRotation] = []
    ) {
        self.teamID = teamID
        self.name = name
        self.isOurs = isOurs
        self.roster = roster
        self.battingOrder = battingOrder
        self.defense = defense
        self.designatedNonRunners = designatedNonRunners
        self.fieldingRotations = fieldingRotations
    }

    // Reading from JSON: `designatedNonRunners` may be left out and means none.
    private enum CodingKeys: String, CodingKey {
        case teamID, name, isOurs, roster, battingOrder, defense, designatedNonRunners, fieldingRotations
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        teamID = try c.decode(TeamID.self, forKey: .teamID)
        name = try c.decode(String.self, forKey: .name)
        isOurs = try c.decode(Bool.self, forKey: .isOurs)
        roster = try c.decode([Player].self, forKey: .roster)
        battingOrder = try c.decode([PlayerID].self, forKey: .battingOrder)
        defense = try c.decode([FielderAssignment].self, forKey: .defense)
        designatedNonRunners = try c.decodeIfPresent([PlayerID].self, forKey: .designatedNonRunners) ?? []
        fieldingRotations = try c.decodeIfPresent([FieldingRotation].self, forKey: .fieldingRotations) ?? []
    }

    /// Finds a player on this team by id.
    public func player(_ id: PlayerID) -> Player? {
        roster.first { $0.id == id }
    }

    /// The bench: everyone at the field who neither bats nor fields at the start.
    public var bench: [Player] {
        let starters = Set(battingOrder + defense.map(\.player))
        return roster.filter { !starters.contains($0.id) }
    }

    /// Where a player starts in the field, if they field.
    public func startingPosition(of player: PlayerID) -> Position? {
        defense.first { $0.player == player }?.position
    }

    /// A defense with this team's fielding rotations applied for an inning: each rotated
    /// position goes to the player whose turn it is, who leaves any other position they had.
    /// Everyone else stays where they are in `fielders`.
    public func defense(forInning inning: Int, from fielders: [FielderAssignment]) -> [FielderAssignment] {
        var result = fielders
        for rotation in fieldingRotations {
            guard let player = rotation.player(inInning: inning) else { continue }
            result.removeAll { $0.position == rotation.position || $0.player == player }
            result.append(FielderAssignment(position: rotation.position, player: player))
        }
        return result.sorted { $0.position < $1.position }
    }

    /// The starting pitcher: whoever starts at position 1.
    public var startingPitcher: PlayerID? {
        defense.first { $0.position == .pitcher }?.player
    }

    /// True when a player is declared as a designated non-runner.
    public func isDesignatedNonRunner(_ player: PlayerID) -> Bool {
        designatedNonRunners.contains(player)
    }
}

/// A fielding position that players take turns at, by inning.
public struct FieldingRotation: Codable, Equatable, Hashable, Sendable {
    public var position: Position
    /// The players in turn: the first plays the first inning, the second the second, and so on,
    /// starting over after the last. `[a, b]` is a in odd innings and b in even ones. The first
    /// should be the player at this position in the starting defense.
    public var players: [PlayerID]

    public init(position: Position, players: [PlayerID]) {
        self.position = position
        self.players = players
    }

    /// The player whose turn it is in an inning (counting from 1).
    public func player(inInning inning: Int) -> PlayerID? {
        players.isEmpty ? nil : players[(max(inning, 1) - 1) % players.count]
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
