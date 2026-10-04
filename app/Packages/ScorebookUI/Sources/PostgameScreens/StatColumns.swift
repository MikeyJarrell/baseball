// The columns of the season tables and the game logs, and how a table sorts.
//
// Each column knows its heading ("AVG"), what VoiceOver says for it ("batting average"), how
// to print a player's number in it, and the number to sort by. The numbers themselves come
// from the stats engine; averages use Model's formulas, so every screen shows the same values.

import SwiftUI
import Model

// MARK: - Batting

/// A column of the season batting table, in the mockup's order.
enum BattingColumn: String, CaseIterable, Identifiable, Sendable {
    case games, plateAppearances, atBats, runs, hits, doubles, triples, homeRuns
    case runsBattedIn, walks, strikeouts, average, onBase, slugging

    var id: String { rawValue }

    /// The heading at the top of the column.
    var title: String {
        switch self {
        case .games: "G"
        case .plateAppearances: "PA"
        case .atBats: "AB"
        case .runs: "R"
        case .hits: "H"
        case .doubles: "2B"
        case .triples: "3B"
        case .homeRuns: "HR"
        case .runsBattedIn: "RBI"
        case .walks: "BB"
        case .strikeouts: "K"
        case .average: "AVG"
        case .onBase: "OBP"
        case .slugging: "SLG"
        }
    }

    /// The heading in words, for VoiceOver.
    var spokenName: String {
        switch self {
        case .games: "games"
        case .plateAppearances: "plate appearances"
        case .atBats: "at-bats"
        case .runs: "runs"
        case .hits: "hits"
        case .doubles: "doubles"
        case .triples: "triples"
        case .homeRuns: "home runs"
        case .runsBattedIn: "runs batted in"
        case .walks: "walks"
        case .strikeouts: "strikeouts"
        case .average: "batting average"
        case .onBase: "on-base percentage"
        case .slugging: "slugging percentage"
        }
    }

    /// True for the averages, which the minimum plate appearances filter can hide.
    var isRate: Bool { self == .average || self == .onBase || self == .slugging }

    /// The columns of a game log row: one game, so no games or plate appearances column.
    static let gameLog: [BattingColumn] = [.atBats, .runs, .hits, .doubles, .triples, .homeRuns,
                                           .runsBattedIn, .walks, .strikeouts]

    /// The number this column sorts by. Averages are missing with no at-bats (or, for on-base,
    /// no times up that count); `games` is used only by the games column.
    func value(_ stats: BattingCounts, games: Int = 0) -> Double? {
        switch self {
        case .games: Double(games)
        case .plateAppearances: Double(stats.plateAppearances)
        case .atBats: Double(stats.atBats)
        case .runs: Double(stats.runs)
        case .hits: Double(stats.hits)
        case .doubles: Double(stats.doubles)
        case .triples: Double(stats.triples)
        case .homeRuns: Double(stats.homeRuns)
        case .runsBattedIn: Double(stats.runsBattedIn)
        case .walks: Double(stats.walks)
        case .strikeouts: Double(stats.strikeouts)
        case .average: stats.battingAverage
        case .onBase: stats.onBasePercentage
        case .slugging: stats.sluggingPercentage
        }
    }

    /// The number as printed: "14", ".333", "1.000", or "—" for an average with nothing to
    /// divide by.
    func text(_ stats: BattingCounts, games: Int = 0) -> String {
        let number = value(stats, games: games)
        if isRate { return formattedRate(number) }
        return number.map { String(Int($0)) } ?? "—"
    }
}

// MARK: - Pitching

/// A column of the season pitching table.
///
/// The mockup also shows wins and losses, earned runs and earned run average. Season totals
/// carry no decisions and the app keeps no earned runs, so those columns wait for a vocabulary
/// change (see the handoff note); walks and hits per inning and strikeouts per inning stand in.
enum PitchingColumn: String, CaseIterable, Identifiable, Sendable {
    case games, innings, battersFaced, hits, runs, walks, strikeouts, homeRuns, hitBatters
    case pitches, walksAndHitsPerInning, strikeoutsPerInning, walksPerInning

    var id: String { rawValue }

    /// The heading at the top of the column.
    var title: String {
        switch self {
        case .games: "G"
        case .innings: "IP"
        case .battersFaced: "BF"
        case .hits: "H"
        case .runs: "R"
        case .walks: "BB"
        case .strikeouts: "K"
        case .homeRuns: "HR"
        case .hitBatters: "HBP"
        case .pitches: "P"
        case .walksAndHitsPerInning: "WHIP"
        case .strikeoutsPerInning: "K/IP"
        case .walksPerInning: "BB/IP"
        }
    }

    /// The heading in words, for VoiceOver.
    var spokenName: String {
        switch self {
        case .games: "games"
        case .innings: "innings pitched"
        case .battersFaced: "batters faced"
        case .hits: "hits allowed"
        case .runs: "runs allowed"
        case .walks: "walks"
        case .strikeouts: "strikeouts"
        case .homeRuns: "home runs allowed"
        case .hitBatters: "hit batters"
        case .pitches: "pitches"
        case .walksAndHitsPerInning: "walks and hits per inning"
        case .strikeoutsPerInning: "strikeouts per inning"
        case .walksPerInning: "walks per inning"
        }
    }

    /// True for the per-inning rates, which are missing before a pitcher records an out.
    var isRate: Bool {
        self == .walksAndHitsPerInning || self == .strikeoutsPerInning || self == .walksPerInning
    }

    /// For the rates, a smaller number is better, so the first tap puts the smallest on top.
    /// Strikeouts per inning is the exception: more is better.
    var smallerIsBetter: Bool { self == .walksAndHitsPerInning || self == .walksPerInning }

    /// The columns of a game log row: one game, so no games column and no season rates.
    static let gameLog: [PitchingColumn] = [.innings, .battersFaced, .hits, .runs, .walks, .strikeouts,
                                            .homeRuns, .pitches]

    /// The number this column sorts by. Innings sort by outs recorded, so 5.1 comes after 5.0.
    func value(_ stats: PitchingCounts, games: Int = 0) -> Double? {
        switch self {
        case .games: Double(games)
        case .innings: Double(stats.outsRecorded)
        case .battersFaced: Double(stats.battersFaced)
        case .hits: Double(stats.hits)
        case .runs: Double(stats.runs)
        case .walks: Double(stats.walks)
        case .strikeouts: Double(stats.strikeouts)
        case .homeRuns: Double(stats.homeRuns)
        case .hitBatters: Double(stats.hitBatters)
        case .pitches: Double(stats.pitches)
        case .walksAndHitsPerInning: stats.walksAndHitsPerInning
        case .strikeoutsPerInning: stats.strikeoutsPerInning
        case .walksPerInning: stats.walksPerInning
        }
    }

    /// The number as printed: "12", "5.1" for innings, "1.25" for a rate, "—" for a rate
    /// before any out.
    func text(_ stats: PitchingCounts, games: Int = 0) -> String {
        switch self {
        case .innings: return stats.inningsPitchedText
        case _ where isRate: return PostgameWording.perInning(value(stats))
        default: return value(stats, games: games).map { String(Int($0)) } ?? "—"
        }
    }
}

// MARK: - Sorting

/// Which column a table is sorted by, and which way.
struct SortChoice<Column: Hashable>: Equatable {
    var column: Column
    /// True when the biggest number is on top.
    var descending: Bool

    /// A tap on a column heading: the same column flips the direction; a new column starts
    /// with the direction `firstDescending` says (biggest on top, as the mockup does).
    mutating func choose(_ tapped: Column, firstDescending: Bool = true) {
        if tapped == column {
            descending.toggle()
        } else {
            column = tapped
            descending = firstDescending
        }
    }
}

/// Sorting the rows of a table.
enum StatSorting {
    /// The rows in order of `value`, biggest first when `descending`. Rows with no value (an
    /// average with no at-bats, or one the filter hides) always go last, whichever way the
    /// column is sorted. Rows with the same value keep the order they were handed in (the
    /// roster order), so a sort never shuffles ties.
    static func sorted<Row>(_ rows: [Row], descending: Bool, by value: (Row) -> Double?) -> [Row] {
        let keyed = rows.enumerated().map { (index: $0.offset, row: $0.element, value: value($0.element)) }
        return keyed.sorted { a, b in
            switch (a.value, b.value) {
            case let (x?, y?) where x != y:
                return descending ? x > y : x < y
            case (.some, nil):
                return true
            case (nil, .some):
                return false
            default:
                return a.index < b.index
            }
        }
        .map(\.row)
    }

    /// True when the minimum plate appearances filter hides this hitter's averages.
    static func hidesAverages(_ line: SeasonBattingLine, minimumPlateAppearances: Int) -> Bool {
        line.stats.plateAppearances < minimumPlateAppearances
    }

    /// The season batting lines sorted for the table. When sorting by an average, hitters
    /// below the minimum plate appearances count as having none and go to the bottom.
    static func batting(_ lines: [SeasonBattingLine], by choice: SortChoice<BattingColumn>,
                        minimumPlateAppearances: Int) -> [SeasonBattingLine] {
        sorted(lines, descending: choice.descending) { line in
            if choice.column.isRate && hidesAverages(line, minimumPlateAppearances: minimumPlateAppearances) {
                return nil
            }
            return choice.column.value(line.stats, games: line.games)
        }
    }

    /// The season pitching lines sorted for the table.
    static func pitching(_ lines: [SeasonPitchingLine], by choice: SortChoice<PitchingColumn>) -> [SeasonPitchingLine] {
        sorted(lines, descending: choice.descending) { choice.column.value($0.stats, games: $0.games) }
    }
}

// MARK: - The minimum plate appearances filter

/// The choices in the filter's menu: everyone, or at least this many plate appearances.
enum MinimumPlateAppearances {
    static let choices = [0, 5, 10, 20, 30]

    /// The words on the filter chip: "At least 10 plate appearances", or "Everyone" when off.
    static func label(_ minimum: Int) -> String {
        minimum <= 0 ? "Averages for everyone" : "At least \(PostgameWording.counted(minimum, "plate appearance", "plate appearances"))"
    }
}
