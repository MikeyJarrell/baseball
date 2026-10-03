// Box scores: one game's batting lines, pitching lines, fielding, line score by inning,
// and the notes underneath ("E—Ruiz 2. DP—Mudcats 1. LOB—Mudcats 6, Cardinals 4.").
//
// The stats engine fills these in from the play log. The counting-stat bundles
// (BattingCounts, PitchingCounts, FieldingCounts) are shared with season totals, and
// carry the standard formulas for batting average, on-base and slugging, so every
// screen shows the same numbers.

import Foundation

/// The box score for one game.
public struct BoxScore: Codable, Equatable, Sendable {
    public var gameID: GameID
    public var date: Date
    public var away: TeamBoxScore
    public var home: TeamBoxScore
    public var lineScore: LineScore
    public var notes: BoxScoreNotes
    /// True once the game has ended; a box score so far is not final.
    public var isFinal: Bool

    public init(
        gameID: GameID,
        date: Date,
        away: TeamBoxScore,
        home: TeamBoxScore,
        lineScore: LineScore,
        notes: BoxScoreNotes,
        isFinal: Bool
    ) {
        self.gameID = gameID
        self.date = date
        self.away = away
        self.home = home
        self.lineScore = lineScore
        self.notes = notes
        self.isFinal = isFinal
    }

    /// One team's half of the box score, by side.
    public subscript(side: TeamSide) -> TeamBoxScore {
        side == .away ? away : home
    }
}

/// One team's half of a box score.
public struct TeamBoxScore: Codable, Equatable, Sendable {
    public var side: TeamSide
    public var teamID: TeamID
    public var name: String
    /// A line for every player who batted, in batting order, with substitutes listed
    /// right under the player they replaced.
    public var batting: [BattingLine]
    /// A line for every pitcher, in the order they pitched.
    public var pitching: [PitchingLine]
    /// Putouts, assists and errors for every player who fielded.
    public var fielding: [FieldingLine]
    /// Runs, hits and errors for the line score's R H E columns.
    public var runs: Int
    public var hits: Int
    public var errors: Int
    /// Runners left on base when the third out was made, added up over the game.
    public var leftOnBase: Int

    public init(
        side: TeamSide,
        teamID: TeamID,
        name: String,
        batting: [BattingLine],
        pitching: [PitchingLine],
        fielding: [FieldingLine],
        runs: Int,
        hits: Int,
        errors: Int,
        leftOnBase: Int
    ) {
        self.side = side
        self.teamID = teamID
        self.name = name
        self.batting = batting
        self.pitching = pitching
        self.fielding = fielding
        self.runs = runs
        self.hits = hits
        self.errors = errors
        self.leftOnBase = leftOnBase
    }

    /// The team's batting totals: every batting line added up.
    public var battingTotals: BattingCounts {
        batting.reduce(BattingCounts()) { $0 + $1.stats }
    }

    /// The team's pitching totals.
    public var pitchingTotals: PitchingCounts {
        pitching.reduce(PitchingCounts()) { $0 + $1.stats }
    }
}

/// One batter's line in a box score.
public struct BattingLine: Codable, Equatable, Sendable {
    public var player: PlayerID
    /// The name to print: "Derek Jeter", "#22", "Batter 4".
    public var name: String
    public var number: String?
    /// The spot in the order they batted in, counting from 0.
    public var batterIndex: Int
    /// Every position they played today, in order: "ss", or "ph" then "2b".
    public var positions: [BoxPosition]
    /// True for a player who came into the game after it started.
    public var isSubstitute: Bool
    public var stats: BattingCounts

    public init(
        player: PlayerID,
        name: String,
        number: String? = nil,
        batterIndex: Int,
        positions: [BoxPosition],
        isSubstitute: Bool = false,
        stats: BattingCounts
    ) {
        self.player = player
        self.name = name
        self.number = number
        self.batterIndex = batterIndex
        self.positions = positions
        self.isSubstitute = isSubstitute
        self.stats = stats
    }
}

/// One pitcher's line in a box score.
public struct PitchingLine: Codable, Equatable, Sendable {
    public var player: PlayerID
    public var name: String
    public var number: String?
    public var stats: PitchingCounts

    public init(player: PlayerID, name: String, number: String? = nil, stats: PitchingCounts) {
        self.player = player
        self.name = name
        self.number = number
        self.stats = stats
    }
}

/// One fielder's putouts, assists and errors in a box score.
public struct FieldingLine: Codable, Equatable, Sendable {
    public var player: PlayerID
    public var name: String
    public var stats: FieldingCounts

    public init(player: PlayerID, name: String, stats: FieldingCounts) {
        self.player = player
        self.name = name
        self.stats = stats
    }
}

/// A position as printed in a box score lineup, including the batting-only roles.
public enum BoxPosition: String, Codable, Sendable, CaseIterable {
    case p, c
    case firstBase = "1b"
    case secondBase = "2b"
    case thirdBase = "3b"
    case ss, lf, cf, rf
    /// Extra hitter: bats, does not field.
    case eh
    /// Pinch hitter.
    case ph
    /// Pinch runner.
    case pr

    /// The box score label for a fielding position: shortstop is "ss".
    public init(_ position: Position) {
        self = BoxPosition(rawValue: position.abbreviation) ?? .eh
    }
}

/// Runs by inning for both teams, for the line score.
public struct LineScore: Codable, Equatable, Sendable {
    /// The visitors' runs in each inning, first inning first.
    public var away: [Int?]
    /// The home team's runs in each inning. A missing value means they did not bat that
    /// inning (printed "x"), as when the home team leads after the top of the last inning.
    public var home: [Int?]

    public init(away: [Int?], home: [Int?]) {
        self.away = away
        self.home = home
    }

    /// Runs by inning for one team.
    public subscript(side: TeamSide) -> [Int?] {
        side == .away ? away : home
    }
}

/// The notes paragraph under a box score, for both teams together.
public struct BoxScoreNotes: Codable, Equatable, Sendable {
    public var errors: [PlayerTally]
    public var doubles: [PlayerTally]
    public var triples: [PlayerTally]
    public var homeRuns: [PlayerTally]
    public var runsBattedIn: [PlayerTally]
    public var stolenBases: [PlayerTally]
    public var caughtStealing: [PlayerTally]
    public var sacrificeFlies: [PlayerTally]
    public var sacrificeBunts: [PlayerTally]
    public var hitByPitch: [PlayerTally]
    /// Double plays turned, by team.
    public var doublePlays: [TeamTally]
    /// Triple plays turned, by team.
    public var triplePlays: [TeamTally]
    /// Runners left on base, by team.
    public var leftOnBase: [TeamTally]

    public init(
        errors: [PlayerTally] = [],
        doubles: [PlayerTally] = [],
        triples: [PlayerTally] = [],
        homeRuns: [PlayerTally] = [],
        runsBattedIn: [PlayerTally] = [],
        stolenBases: [PlayerTally] = [],
        caughtStealing: [PlayerTally] = [],
        sacrificeFlies: [PlayerTally] = [],
        sacrificeBunts: [PlayerTally] = [],
        hitByPitch: [PlayerTally] = [],
        doublePlays: [TeamTally] = [],
        triplePlays: [TeamTally] = [],
        leftOnBase: [TeamTally] = []
    ) {
        self.errors = errors
        self.doubles = doubles
        self.triples = triples
        self.homeRuns = homeRuns
        self.runsBattedIn = runsBattedIn
        self.stolenBases = stolenBases
        self.caughtStealing = caughtStealing
        self.sacrificeFlies = sacrificeFlies
        self.sacrificeBunts = sacrificeBunts
        self.hitByPitch = hitByPitch
        self.doublePlays = doublePlays
        self.triplePlays = triplePlays
        self.leftOnBase = leftOnBase
    }
}

/// One player's count for a note: "Ruiz 2" in "E—Ruiz 2".
public struct PlayerTally: Codable, Equatable, Hashable, Sendable {
    public var player: PlayerID
    public var name: String
    public var team: TeamSide
    public var count: Int

    public init(player: PlayerID, name: String, team: TeamSide, count: Int) {
        self.player = player
        self.name = name
        self.team = team
        self.count = count
    }
}

/// One team's count for a note: "Mudcats 6" in "LOB—Mudcats 6".
public struct TeamTally: Codable, Equatable, Hashable, Sendable {
    public var team: TeamSide
    public var name: String
    public var count: Int

    public init(team: TeamSide, name: String, count: Int) {
        self.team = team
        self.name = name
        self.count = count
    }
}

// MARK: - Counting stats

/// A batter's counting stats, for one game or a season.
public struct BattingCounts: Codable, Equatable, Hashable, Sendable {
    public var plateAppearances = 0
    public var atBats = 0
    public var runs = 0
    public var hits = 0
    public var doubles = 0
    public var triples = 0
    public var homeRuns = 0
    public var runsBattedIn = 0
    /// Walks, intentional ones included.
    public var walks = 0
    public var strikeouts = 0
    public var hitByPitch = 0
    public var sacrificeFlies = 0
    public var sacrificeBunts = 0
    public var stolenBases = 0
    public var caughtStealing = 0

    public init(
        plateAppearances: Int = 0, atBats: Int = 0, runs: Int = 0, hits: Int = 0,
        doubles: Int = 0, triples: Int = 0, homeRuns: Int = 0, runsBattedIn: Int = 0,
        walks: Int = 0, strikeouts: Int = 0, hitByPitch: Int = 0,
        sacrificeFlies: Int = 0, sacrificeBunts: Int = 0,
        stolenBases: Int = 0, caughtStealing: Int = 0
    ) {
        self.plateAppearances = plateAppearances
        self.atBats = atBats
        self.runs = runs
        self.hits = hits
        self.doubles = doubles
        self.triples = triples
        self.homeRuns = homeRuns
        self.runsBattedIn = runsBattedIn
        self.walks = walks
        self.strikeouts = strikeouts
        self.hitByPitch = hitByPitch
        self.sacrificeFlies = sacrificeFlies
        self.sacrificeBunts = sacrificeBunts
        self.stolenBases = stolenBases
        self.caughtStealing = caughtStealing
    }

    /// Hits that were singles.
    public var singles: Int { hits - doubles - triples - homeRuns }

    /// Bases from hits: one per single, two per double, three per triple, four per home run.
    public var totalBases: Int { singles + 2 * doubles + 3 * triples + 4 * homeRuns }

    /// Hits divided by at-bats. Missing when there are no at-bats (shown as a dash).
    public var battingAverage: Double? {
        atBats > 0 ? Double(hits) / Double(atBats) : nil
    }

    /// Times on base (hits, walks, hit by pitch) divided by (at-bats, walks, hit by pitch,
    /// sacrifice flies). Missing when that is zero.
    public var onBasePercentage: Double? {
        let chances = atBats + walks + hitByPitch + sacrificeFlies
        return chances > 0 ? Double(hits + walks + hitByPitch) / Double(chances) : nil
    }

    /// Total bases divided by at-bats. Missing when there are no at-bats.
    public var sluggingPercentage: Double? {
        atBats > 0 ? Double(totalBases) / Double(atBats) : nil
    }

    /// Adds two sets of counting stats, for team totals and season totals.
    public static func + (a: BattingCounts, b: BattingCounts) -> BattingCounts {
        BattingCounts(
            plateAppearances: a.plateAppearances + b.plateAppearances,
            atBats: a.atBats + b.atBats,
            runs: a.runs + b.runs,
            hits: a.hits + b.hits,
            doubles: a.doubles + b.doubles,
            triples: a.triples + b.triples,
            homeRuns: a.homeRuns + b.homeRuns,
            runsBattedIn: a.runsBattedIn + b.runsBattedIn,
            walks: a.walks + b.walks,
            strikeouts: a.strikeouts + b.strikeouts,
            hitByPitch: a.hitByPitch + b.hitByPitch,
            sacrificeFlies: a.sacrificeFlies + b.sacrificeFlies,
            sacrificeBunts: a.sacrificeBunts + b.sacrificeBunts,
            stolenBases: a.stolenBases + b.stolenBases,
            caughtStealing: a.caughtStealing + b.caughtStealing
        )
    }
}

/// A pitcher's counting stats, for one game or a season.
public struct PitchingCounts: Codable, Equatable, Hashable, Sendable {
    /// Outs recorded while this pitcher was on the mound. Three outs make one inning.
    public var outsRecorded = 0
    public var battersFaced = 0
    public var hits = 0
    /// Runs charged: runs scored by runners this pitcher put on base.
    public var runs = 0
    public var walks = 0
    public var strikeouts = 0
    public var homeRuns = 0
    public var hitBatters = 0
    public var pitches = 0
    public var strikes = 0

    public init(
        outsRecorded: Int = 0, battersFaced: Int = 0, hits: Int = 0, runs: Int = 0,
        walks: Int = 0, strikeouts: Int = 0, homeRuns: Int = 0, hitBatters: Int = 0,
        pitches: Int = 0, strikes: Int = 0
    ) {
        self.outsRecorded = outsRecorded
        self.battersFaced = battersFaced
        self.hits = hits
        self.runs = runs
        self.walks = walks
        self.strikeouts = strikeouts
        self.homeRuns = homeRuns
        self.hitBatters = hitBatters
        self.pitches = pitches
        self.strikes = strikes
    }

    /// Innings pitched the way a box score prints it: "5.1" is five innings and one out.
    public var inningsPitchedText: String {
        "\(outsRecorded / 3).\(outsRecorded % 3)"
    }

    /// Innings pitched as a true number (five and a third is 5.333...), for per-inning rates.
    public var inningsPitched: Double { Double(outsRecorded) / 3 }

    /// Strikeouts per inning. Missing before the pitcher records an out.
    public var strikeoutsPerInning: Double? {
        outsRecorded > 0 ? Double(strikeouts) / inningsPitched : nil
    }

    /// Walks per inning. Missing before the pitcher records an out.
    public var walksPerInning: Double? {
        outsRecorded > 0 ? Double(walks) / inningsPitched : nil
    }

    /// Walks and hits per inning. Missing before the pitcher records an out.
    public var walksAndHitsPerInning: Double? {
        outsRecorded > 0 ? Double(walks + hits) / inningsPitched : nil
    }

    /// Adds two sets of counting stats, for team totals and season totals.
    public static func + (a: PitchingCounts, b: PitchingCounts) -> PitchingCounts {
        PitchingCounts(
            outsRecorded: a.outsRecorded + b.outsRecorded,
            battersFaced: a.battersFaced + b.battersFaced,
            hits: a.hits + b.hits,
            runs: a.runs + b.runs,
            walks: a.walks + b.walks,
            strikeouts: a.strikeouts + b.strikeouts,
            homeRuns: a.homeRuns + b.homeRuns,
            hitBatters: a.hitBatters + b.hitBatters,
            pitches: a.pitches + b.pitches,
            strikes: a.strikes + b.strikes
        )
    }
}

/// A fielder's putouts, assists and errors, for one game or a season.
public struct FieldingCounts: Codable, Equatable, Hashable, Sendable {
    public var putouts = 0
    public var assists = 0
    public var errors = 0

    public init(putouts: Int = 0, assists: Int = 0, errors: Int = 0) {
        self.putouts = putouts
        self.assists = assists
        self.errors = errors
    }

    /// Adds two sets of counting stats.
    public static func + (a: FieldingCounts, b: FieldingCounts) -> FieldingCounts {
        FieldingCounts(putouts: a.putouts + b.putouts, assists: a.assists + b.assists, errors: a.errors + b.errors)
    }
}

/// Formats a rate stat the baseball way: ".333", "1.000", or "—" when there is no value
/// (a player with no at-bats).
public func formattedRate(_ value: Double?) -> String {
    guard let value, value.isFinite else { return "—" }
    let text = String(format: "%.3f", value)
    return text.hasPrefix("0.") ? String(text.dropFirst()) : text
}
