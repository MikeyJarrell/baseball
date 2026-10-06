// The words on the postgame and season screens: game lengths, results, dates, the season record
// and the box score notes. Plain functions, so they read the same everywhere and can be tested.
// None of them works out a stat; they only put into words what they are handed.

import Foundation
import Model

/// Words for the postgame and season screens.
enum PostgameWording {
    /// How long a game took, in hours and minutes: "3 hr 12 min", or "48 min" under an hour.
    /// Any part of a minute left over is dropped.
    static func gameLength(_ seconds: TimeInterval) -> String {
        let minutes = max(0, Int(seconds / 60))
        let hours = minutes / 60
        let rest = minutes % 60
        if hours == 0 { return "\(rest) min" }
        return "\(hours) hr \(rest) min"
    }

    /// The same length said in full, for VoiceOver: "3 hours 12 minutes".
    static func gameLengthSpoken(_ seconds: TimeInterval) -> String {
        let minutes = max(0, Int(seconds / 60))
        let hours = minutes / 60
        let rest = minutes % 60
        let minuteWords = "\(rest) \(rest == 1 ? "minute" : "minutes")"
        if hours == 0 { return minuteWords }
        return "\(hours) \(hours == 1 ? "hour" : "hours") \(minuteWords)"
    }

    /// Whether we won, lost or tied a game, as the stats engine worked it out. Nothing for a
    /// game that has not ended.
    static func outcome(of game: GameSummary) -> GameResult? {
        game.result
    }

    /// The score with our runs first, as the games list shows it: "7–5".
    static func scoreOursFirst(_ game: GameSummary) -> String? {
        scoreOursFirst(game.finalScore, weAreHome: game.weAreHome)
    }

    /// A final score with our runs first: "7–5". Nothing without a score.
    static func scoreOursFirst(_ score: Score?, weAreHome: Bool) -> String? {
        guard let score else { return nil }
        let ourSide: TeamSide = weAreHome ? .home : .away
        return "\(score[ourSide])–\(score[ourSide.opponent])"
    }

    /// "vs Mudcats" for a home game, "at Mudcats" for an away game.
    static func opponent(_ game: GameSummary) -> String {
        (game.weAreHome ? "vs " : "at ") + game.opponentName
    }

    /// The game in a player's game log: "Oct 3 at Mudcats, W 7–5", or "Oct 3 vs Bombers" for a
    /// game still going. An older log that does not say home or away gives just the opponent.
    static func logGame<Counts>(_ entry: GameLogEntry<Counts>, calendar: Calendar = .current) -> String {
        var words = shortDate(entry.date, calendar: calendar) + " "
        if let home = entry.weAreHome { words += home ? "vs " : "at " }
        words += entry.opponentName
        if let result = entry.result, let home = entry.weAreHome,
           let score = scoreOursFirst(entry.finalScore, weAreHome: home) {
            words += ", \(result.letter) \(score)"
        }
        return words
    }

    /// A game's date for a list: "Sat, Oct 3", with the year added when it is not `thisYear`'s.
    static func listDate(_ date: Date, thisYear: Date = Date(), calendar: Calendar = .current) -> String {
        let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: thisYear)
        var style = Date.FormatStyle(date: .omitted, time: .omitted, locale: Locale(identifier: "en_US"),
                                     calendar: calendar, timeZone: calendar.timeZone)
            .weekday(.abbreviated).month(.abbreviated).day()
        if !sameYear { style = style.year() }
        return date.formatted(style)
    }

    /// The question before deleting a game: "Delete Diamond Dogs vs Mudcats, Oct 4?". Without
    /// our team's name, "Delete the game vs Mudcats, Oct 4?".
    static func deleteQuestion(_ game: GameSummary, ourTeamName: String?, calendar: Calendar = .current) -> String {
        "Delete \(ourTeamName ?? "the game") \(opponent(game)), \(shortDate(game.date, calendar: calendar))?"
    }

    /// The question before deleting a game from its box score: "Delete Diamond Dogs vs
    /// Mudcats, Oct 4?" with our team's name first, or "Delete Mudcats at Bombers, Oct 4?" when
    /// neither team is ours.
    static func deleteQuestion(_ box: BoxScore, ourSide: TeamSide?, calendar: Calendar = .current) -> String {
        let date = shortDate(box.date, calendar: calendar)
        guard let ours = ourSide else { return "Delete \(box.away.name) at \(box.home.name), \(date)?" }
        let words = ours == .home ? "vs" : "at"
        return "Delete \(box[ours].name) \(words) \(box[ours.opponent].name), \(date)?"
    }

    /// Under the delete question.
    static let deleteWarning = "This can’t be undone in the app. A backup is made first."

    /// A short date for a game log row: "Oct 3".
    static func shortDate(_ date: Date, calendar: Calendar = .current) -> String {
        let style = Date.FormatStyle(date: .omitted, time: .omitted, locale: Locale(identifier: "en_US"),
                                     calendar: calendar, timeZone: calendar.timeZone)
            .month(.abbreviated).day()
        return date.formatted(style)
    }

    /// The season record from the season totals: "9 wins, 5 losses", with ties added when
    /// there are any ("1 tie"). Nothing when no game has finished.
    static func record(_ totals: SeasonTotals) -> String? {
        guard totals.wins + totals.losses + totals.ties > 0 else { return nil }
        var parts = [counted(totals.wins, "win", "wins"), counted(totals.losses, "loss", "losses")]
        if totals.ties > 0 { parts.append(counted(totals.ties, "tie", "ties")) }
        return parts.joined(separator: ", ")
    }

    /// A pitcher's wins and losses as the season table prints them: "6-2".
    static func winsAndLosses(_ line: SeasonPitchingLine) -> String {
        "\(line.wins)-\(line.losses)"
    }

    /// A number with the right word after it: "1 game", "14 games".
    static func counted(_ count: Int, _ one: String, _ many: String) -> String {
        "\(count) \(count == 1 ? one : many)"
    }

    /// A box score position list as printed: "ss", "ph-2b". A starter who only batted shows
    /// "dh", as the newspaper box does.
    static func positions(_ line: BattingLine) -> String {
        if line.positions.isEmpty { return line.isSubstitute ? "ph" : "dh" }
        return line.positions.map(\.rawValue).joined(separator: "-")
    }

    /// One note under the box score: "2B: Webb 2, Ford". A count shows only when more than one.
    /// Nothing when nobody is in it.
    static func note(_ label: String, _ tallies: [PlayerTally]) -> String? {
        guard !tallies.isEmpty else { return nil }
        let names = tallies.map { $0.count > 1 ? "\($0.name) \($0.count)" : $0.name }
        return "\(label): " + names.joined(separator: ", ")
    }

    /// A team note under the box score: "LOB: Mudcats 6, Diamond Dogs 4".
    static func teamNote(_ label: String, _ tallies: [TeamTally]) -> String? {
        guard !tallies.isEmpty else { return nil }
        return "\(label): " + tallies.map { "\($0.name) \($0.count)" }.joined(separator: ", ")
    }

    /// "1st", "2nd", "3rd", "4th", "11th", "21st".
    static func ordinal(_ n: Int) -> String {
        let tens = (n / 10) % 10
        let suffix: String
        if tens == 1 {
            suffix = "th"
        } else {
            switch n % 10 {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(n)\(suffix)"
    }

    /// A list of innings in words: "the 5th", "the 3rd and 5th", "the 3rd, 5th and 7th".
    static func innings(_ innings: [Int]) -> String {
        let words = innings.map(ordinal)
        switch words.count {
        case 0: return ""
        case 1: return "the \(words[0])"
        default: return "the " + words.dropLast().joined(separator: ", ") + " and " + words.last!
        }
    }

    /// Every note under the box score, in the newspaper's order, as separate lines. Empty notes
    /// are left out.
    static func notes(_ notes: BoxScoreNotes) -> [String] {
        var lines: [String?] = [
            note("E", notes.errors),
            teamNote("DP", notes.doublePlays),
            teamNote("TP", notes.triplePlays),
            teamNote("LOB", notes.leftOnBase),
            note("2B", notes.doubles),
            note("3B", notes.triples),
            note("HR", notes.homeRuns),
            note("SB", notes.stolenBases),
            note("CS", notes.caughtStealing),
            note("S", notes.sacrificeBunts),
            note("SF", notes.sacrificeFlies),
        ]
        if !notes.hitBatters.isEmpty {
            let each = notes.hitBatters.map { hit -> String in
                let times = hit.count > 1 ? " \(hit.count)" : ""
                if let pitcher = hit.pitcherName { return "\(hit.batterName)\(times) (by \(pitcher))" }
                return hit.batterName + times
            }
            lines.append("HBP: " + each.joined(separator: ", "))
        }
        for ran in notes.ranForNonRunners {
            lines.append("\(ran.runnerName) ran for \(ran.nonRunnerName) in \(innings(ran.innings)).")
        }
        return lines.compactMap { $0 }
    }

    /// A rate per inning to two places: "1.25". A dash when there is none (no outs recorded).
    static func perInning(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "—" }
        return String(format: "%.2f", value)
    }
}

extension GameResult {
    /// The letter in the games list and game logs: "W", "L" or "T".
    var letter: String {
        switch self {
        case .win: "W"
        case .loss: "L"
        case .tie: "T"
        }
    }

    /// The word, for VoiceOver: "Won", "Lost" or "Tied".
    var word: String {
        switch self {
        case .win: "Won"
        case .loss: "Lost"
        case .tie: "Tied"
        }
    }
}
