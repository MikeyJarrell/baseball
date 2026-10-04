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
    /// The season record over the same games: how many we won, lost and tied. A game still
    /// going counts in `games` but in none of these, so they can add up to fewer than `games`.
    public var wins: Int
    public var losses: Int
    public var ties: Int
    public var batting: [SeasonBattingLine]
    public var pitching: [SeasonPitchingLine]
    public var fielding: [SeasonFieldingLine]

    public init(
        teamID: TeamID,
        teamName: String,
        games: Int,
        wins: Int = 0,
        losses: Int = 0,
        ties: Int = 0,
        batting: [SeasonBattingLine],
        pitching: [SeasonPitchingLine],
        fielding: [SeasonFieldingLine]
    ) {
        self.teamID = teamID
        self.teamName = teamName
        self.games = games
        self.wins = wins
        self.losses = losses
        self.ties = ties
        self.batting = batting
        self.pitching = pitching
        self.fielding = fielding
    }

    // Reading from JSON: totals saved before the record was added read as no wins, losses or ties.
    private enum CodingKeys: String, CodingKey {
        case teamID, teamName, games, wins, losses, ties, batting, pitching, fielding
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        teamID = try c.decode(TeamID.self, forKey: .teamID)
        teamName = try c.decode(String.self, forKey: .teamName)
        games = try c.decode(Int.self, forKey: .games)
        wins = try c.decodeIfPresent(Int.self, forKey: .wins) ?? 0
        losses = try c.decodeIfPresent(Int.self, forKey: .losses) ?? 0
        ties = try c.decodeIfPresent(Int.self, forKey: .ties) ?? 0
        batting = try c.decode([SeasonBattingLine].self, forKey: .batting)
        pitching = try c.decode([SeasonPitchingLine].self, forKey: .pitching)
        fielding = try c.decode([SeasonFieldingLine].self, forKey: .fielding)
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
    /// Games in which they were the winning pitcher, and the losing pitcher: the "W-L" column.
    /// Counted from each box score's decisions (see `PitchingDecision`). Saves are not kept.
    public var wins: Int
    public var losses: Int
    public var stats: PitchingCounts
    /// One entry per game they pitched in, oldest first.
    public var gameLog: [GameLogEntry<PitchingCounts>]

    public init(player: PlayerID, name: String, number: String? = nil, games: Int, wins: Int = 0, losses: Int = 0,
                stats: PitchingCounts, gameLog: [GameLogEntry<PitchingCounts>]) {
        self.player = player
        self.name = name
        self.number = number
        self.games = games
        self.wins = wins
        self.losses = losses
        self.stats = stats
        self.gameLog = gameLog
    }

    // Reading from JSON: a line saved before wins and losses were added reads as 0-0.
    private enum CodingKeys: String, CodingKey { case player, name, number, games, wins, losses, stats, gameLog }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        player = try c.decode(PlayerID.self, forKey: .player)
        name = try c.decode(String.self, forKey: .name)
        number = try c.decodeIfPresent(String.self, forKey: .number)
        games = try c.decode(Int.self, forKey: .games)
        wins = try c.decodeIfPresent(Int.self, forKey: .wins) ?? 0
        losses = try c.decodeIfPresent(Int.self, forKey: .losses) ?? 0
        stats = try c.decode(PitchingCounts.self, forKey: .stats)
        gameLog = try c.decode([GameLogEntry<PitchingCounts>].self, forKey: .gameLog)
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

/// One game in a player's game-by-game log: which game, how it came out for us, and their
/// stats in it. `Counts` is BattingCounts for a hitter's log and PitchingCounts for a pitcher's.
public struct GameLogEntry<Counts: Codable & Equatable & Sendable>: Codable, Equatable, Sendable {
    public var gameID: GameID
    public var date: Date
    public var opponentName: String
    /// True when we were the home team, false when we were the visitors: "vs Mudcats" or
    /// "at Mudcats". Missing in a log saved before this was kept.
    public var weAreHome: Bool?
    /// The final score, once the game has ended. Missing for a game still going.
    public var finalScore: Score?
    /// Whether we won, lost or tied. Missing until the game is final.
    public var result: GameResult?
    public var stats: Counts

    public init(gameID: GameID, date: Date, opponentName: String, weAreHome: Bool? = nil,
                finalScore: Score? = nil, result: GameResult? = nil, stats: Counts) {
        self.gameID = gameID
        self.date = date
        self.opponentName = opponentName
        self.weAreHome = weAreHome
        self.finalScore = finalScore
        self.result = result
        self.stats = stats
    }
}

/// How a finished game came out for our team.
public enum GameResult: String, Codable, Sendable, CaseIterable {
    /// We scored more runs than the other team.
    case win
    /// The other team scored more runs than we did.
    case loss
    /// Both teams scored the same number of runs, as when the time limit ends a game tied.
    case tie

    /// The result from our runs and theirs.
    public init(ourRuns: Int, theirRuns: Int) {
        if ourRuns > theirRuns {
            self = .win
        } else if ourRuns < theirRuns {
            self = .loss
        } else {
            self = .tie
        }
    }

    /// The result from a final score, given which side we were on.
    public init(score: Score, ourSide: TeamSide) {
        self.init(ourRuns: score[ourSide], theirRuns: score[ourSide.opponent])
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
    /// Whether our team won, lost or tied. Missing until the game is final, and when neither
    /// team is ours. Screens read this rather than comparing the score themselves.
    public var result: GameResult?

    public init(id: GameID, date: Date, opponentName: String, weAreHome: Bool, finalScore: Score?, isFinished: Bool,
                result: GameResult? = nil) {
        self.id = id
        self.date = date
        self.opponentName = opponentName
        self.weAreHome = weAreHome
        self.finalScore = finalScore
        self.isFinished = isFinished
        self.result = result
    }

    /// Builds the summary for a game from its setup and end-of-game event.
    public init(game: Game) {
        let ourSide = game.setup.ourSide ?? .home
        // The result needs a final score and a team of ours to read it for.
        var result: GameResult?
        if game.isFinished, let score = game.ending?.finalScore, let side = game.setup.ourSide {
            result = GameResult(score: score, ourSide: side)
        }
        self.init(
            id: game.id,
            date: game.setup.scheduledStart,
            opponentName: game.setup[ourSide.opponent].name,
            weAreHome: ourSide == .home,
            finalScore: game.ending?.finalScore,
            isFinished: game.isFinished,
            result: result
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
