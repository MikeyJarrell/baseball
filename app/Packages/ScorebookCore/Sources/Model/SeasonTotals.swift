// Season totals, game summaries and batter histories: the stats that span more than one
// moment of one game.

import Foundation

/// Our team's season: batting, pitching and fielding totals for every player, with each
/// player's game-by-game log. Opponents are left out.
public struct SeasonTotals: Codable, Equatable, Sendable {
    public var teamID: TeamID
    public var teamName: String
    /// Games included.
    public var games: Int
    public var batting: [SeasonBattingLine]
    public var pitching: [SeasonPitchingLine]
    public var fielding: [SeasonFieldingLine]

    public init(
        teamID: TeamID,
        teamName: String,
        games: Int,
        batting: [SeasonBattingLine],
        pitching: [SeasonPitchingLine],
        fielding: [SeasonFieldingLine]
    ) {
        self.teamID = teamID
        self.teamName = teamName
        self.games = games
        self.batting = batting
        self.pitching = pitching
        self.fielding = fielding
    }
}

/// One player's season at the plate.
public struct SeasonBattingLine: Codable, Equatable, Sendable {
    public var player: PlayerID
    public var name: String
    public var number: String?
    /// Games in which they batted.
    public var games: Int
    public var stats: BattingCounts
    /// One entry per game they batted in, oldest first.
    public var gameLog: [GameLogEntry<BattingCounts>]

    public init(player: PlayerID, name: String, number: String? = nil, games: Int, stats: BattingCounts, gameLog: [GameLogEntry<BattingCounts>]) {
        self.player = player
        self.name = name
        self.number = number
        self.games = games
        self.stats = stats
        self.gameLog = gameLog
    }
}

/// One player's season on the mound.
public struct SeasonPitchingLine: Codable, Equatable, Sendable {
    public var player: PlayerID
    public var name: String
    public var number: String?
    /// Games in which they pitched.
    public var games: Int
    public var stats: PitchingCounts
    /// One entry per game they pitched in, oldest first.
    public var gameLog: [GameLogEntry<PitchingCounts>]

    public init(player: PlayerID, name: String, number: String? = nil, games: Int, stats: PitchingCounts, gameLog: [GameLogEntry<PitchingCounts>]) {
        self.player = player
        self.name = name
        self.number = number
        self.games = games
        self.stats = stats
        self.gameLog = gameLog
    }
}

/// One player's season in the field.
public struct SeasonFieldingLine: Codable, Equatable, Sendable {
    public var player: PlayerID
    public var name: String
    public var stats: FieldingCounts

    public init(player: PlayerID, name: String, stats: FieldingCounts) {
        self.player = player
        self.name = name
        self.stats = stats
    }
}

/// One game in a player's game-by-game log: which game, and their stats in it.
/// `Counts` is BattingCounts for a hitter's log and PitchingCounts for a pitcher's.
public struct GameLogEntry<Counts: Codable & Equatable & Sendable>: Codable, Equatable, Sendable {
    public var gameID: GameID
    public var date: Date
    public var opponentName: String
    public var stats: Counts

    public init(gameID: GameID, date: Date, opponentName: String, stats: Counts) {
        self.gameID = gameID
        self.date = date
        self.opponentName = opponentName
        self.stats = stats
    }
}

/// One line in the games list: date, opponent and result, without loading the whole game.
public struct GameSummary: Identifiable, Codable, Equatable, Sendable {
    public var id: GameID
    public var date: Date
    public var opponentName: String
    public var weAreHome: Bool
    /// The final score, once the game has ended.
    public var finalScore: Score?
    public var isFinished: Bool

    public init(id: GameID, date: Date, opponentName: String, weAreHome: Bool, finalScore: Score?, isFinished: Bool) {
        self.id = id
        self.date = date
        self.opponentName = opponentName
        self.weAreHome = weAreHome
        self.finalScore = finalScore
        self.isFinished = isFinished
    }

    /// Builds the summary for a game from its setup and end-of-game event.
    public init(game: Game) {
        let ourSide = game.setup.ourSide ?? .home
        self.init(
            id: game.id,
            date: game.setup.scheduledStart,
            opponentName: game.setup[ourSide.opponent].name,
            weAreHome: ourSide == .home,
            finalScore: game.ending?.finalScore,
            isFinished: game.isFinished
        )
    }
}

/// One of a batter's plate appearances in a game, for the batter history on the batting
/// screen: "6-3", "BB", "1B 7".
public struct PlateAppearanceSummary: Codable, Equatable, Hashable, Sendable {
    public var inning: Int
    /// Scorebook notation for how it ended.
    public var notation: String
    public var outcome: PlateAppearanceOutcome
    public var rbi: Int

    public init(inning: Int, notation: String, outcome: PlateAppearanceOutcome, rbi: Int = 0) {
        self.inning = inning
        self.notation = notation
        self.outcome = outcome
        self.rbi = rbi
    }
}
