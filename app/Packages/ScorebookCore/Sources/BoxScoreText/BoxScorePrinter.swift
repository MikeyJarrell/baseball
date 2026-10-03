// BoxScoreText: a box score in, a newspaper-style box score out.
//
// `BoxScorePrinter.layout` works out every line a newspaper sports page would print for a
// game: the headline with the score, each team's batting lines (ab r h bi) and totals,
// the line score by inning, the notes paragraph ("E—Kim, Tate. DP—Mudcats 2."), and the
// pitching lines (ip h r bb so). `BoxScorePrinter.text` turns that layout into plain text
// for the share sheet; the BoxScorePicture module draws the same layout as a picture.

import Foundation
import Model

/// Lays out and prints box scores the way a newspaper sports page did.
public enum BoxScorePrinter {
    /// The batting columns: at-bats, runs, hits, runs batted in.
    public static let battingColumns = ["ab", "r", "h", "bi"]
    /// The pitching columns: innings pitched, hits, runs, walks, strikeouts.
    public static let pitchingColumns = ["ip", "h", "r", "bb", "so"]

    /// The plain-text box score, ready to paste into a message or an email. The columns
    /// line up in a font where every letter is the same width.
    ///
    /// `timeZone` is where the game was played, for printing its date; the phone's own
    /// time zone unless a test says otherwise.
    public static func text(_ box: BoxScore, timeZone: TimeZone = .current) -> String {
        PlainText.render(layout(box, timeZone: timeZone))
    }

    /// Every line of the newspaper box score, worked out but not yet drawn.
    public static func layout(_ box: BoxScore, timeZone: TimeZone = .current) -> NewspaperBoxScore {
        let names = ShortNames(box)
        return NewspaperBoxScore(
            dateLine: dateLine(box.date, timeZone: timeZone),
            headline: headline(box),
            status: box.isFinal ? nil : "In progress",
            batting: [battingTable(box.away, names), battingTable(box.home, names)],
            lineScore: lineScore(box),
            notes: notes(box, names),
            pitching: [pitchingTable(box.away, names), pitchingTable(box.home, names)],
            pitchingNotes: pitchingNotes(box, names)
        )
    }

    // MARK: - Top of the page

    /// The game's date as the line above the headline: "Saturday, May 2".
    static func dateLine(_ date: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: date)
    }

    /// The score with the team ahead first: "Diamond Dogs 5, Mudcats 3". A tie puts the
    /// visitors first, as the line score does.
    static func headline(_ box: BoxScore) -> String {
        let (first, second) = box.home.runs > box.away.runs ? (box.home, box.away) : (box.away, box.home)
        return "\(first.name) \(first.runs), \(second.name) \(second.runs)"
    }

    // MARK: - Batting

    /// One team's batting lines, with substitutes under the player they replaced (the stats
    /// engine already lists them that way) and a totals row at the bottom.
    static func battingTable(_ team: TeamBoxScore, _ names: ShortNames) -> NewspaperTable {
        var rows = team.batting.map { line in
            NewspaperRow(
                label: "\(names.name(for: line.player, fallback: line.name)) \(positionText(line))",
                isSubstitute: line.isSubstitute,
                cells: battingCells(line.stats)
            )
        }
        rows.append(NewspaperRow(label: "Totals", isTotal: true, cells: battingCells(team.battingTotals)))
        return NewspaperTable(title: team.name, columns: battingColumns, rows: rows)
    }

    /// The positions a batter played, joined by dashes: "ss", "ph-2b". A starter who only
    /// batted is printed "dh"; a substitute who only batted, "ph".
    static func positionText(_ line: BattingLine) -> String {
        if line.positions.isEmpty {
            return line.isSubstitute ? BoxPosition.ph.rawValue : "dh"
        }
        return line.positions.map(\.rawValue).joined(separator: "-")
    }

    /// At-bats, runs, hits and runs batted in, as text.
    static func battingCells(_ stats: BattingCounts) -> [String] {
        [stats.atBats, stats.runs, stats.hits, stats.runsBattedIn].map(String.init)
    }

    // MARK: - Line score

    /// Both teams' runs by inning, with runs, hits and errors.
    static func lineScore(_ box: BoxScore) -> NewspaperLineScore {
        func row(_ team: TeamBoxScore) -> NewspaperLineScoreRow {
            NewspaperLineScoreRow(
                teamName: team.name,
                innings: box.lineScore[team.side].map(inningText),
                runs: team.runs, hits: team.hits, errors: team.errors
            )
        }
        return NewspaperLineScore(rows: [row(box.away), row(box.home)])
    }

    /// One inning's runs as printed: "x" when the team did not bat, "(10)" for ten or more,
    /// so every single-digit inning takes one character.
    static func inningText(_ runs: Int?) -> String {
        guard let runs else { return "x" }
        return runs >= 10 ? "(\(runs))" : "\(runs)"
    }

    // MARK: - Notes

    /// The notes under the line score, in the newspaper's usual order: errors, double plays,
    /// triple plays, runners left on base, doubles, triples, home runs, stolen bases, caught
    /// stealing, sacrifice bunts ("S"), sacrifice flies. A note with nobody in it is left out.
    static func notes(_ box: BoxScore, _ names: ShortNames) -> [String] {
        let n = box.notes
        let entries: [(String, String?)] = [
            ("E", playerList(n.errors, names)),
            ("DP", teamList(n.doublePlays, keepZeros: false)),
            ("TP", teamList(n.triplePlays, keepZeros: false)),
            ("LOB", teamList(n.leftOnBase, keepZeros: true)),
            ("2B", playerList(n.doubles, names)),
            ("3B", playerList(n.triples, names)),
            ("HR", playerList(n.homeRuns, names)),
            ("SB", playerList(n.stolenBases, names)),
            ("CS", playerList(n.caughtStealing, names)),
            ("S", playerList(n.sacrificeBunts, names)),
            ("SF", playerList(n.sacrificeFlies, names)),
        ]
        return entries.compactMap { label, list in list.map { "\(label)—\($0)." } }
    }

    /// Players for one note, visitors first: "Ruiz 2, Webb, Cole". The count is printed only
    /// when it is more than one. Missing when nobody did it.
    static func playerList(_ tallies: [PlayerTally], _ names: ShortNames) -> String? {
        let kept = visitorsFirst(tallies.filter { $0.count > 0 })
        guard !kept.isEmpty else { return nil }
        return kept.map { tally in
            let name = names.name(for: tally.player, fallback: tally.name)
            return tally.count > 1 ? "\(name) \(tally.count)" : name
        }.joined(separator: ", ")
    }

    /// Teams for one note, visitors first: "Mudcats 6, Diamond Dogs 4". Double and triple
    /// plays leave out a team that turned none; runners left on base keep a zero.
    static func teamList(_ tallies: [TeamTally], keepZeros: Bool) -> String? {
        let wanted = tallies.filter { keepZeros || $0.count > 0 }
        let kept = wanted.filter { $0.team == .away } + wanted.filter { $0.team == .home }
        guard !kept.isEmpty else { return nil }
        return kept.map { "\($0.name) \($0.count)" }.joined(separator: ", ")
    }

    /// The same list with the visitors' players before the home team's, each team's players
    /// staying in the order they were given.
    static func visitorsFirst(_ tallies: [PlayerTally]) -> [PlayerTally] {
        tallies.filter { $0.team == .away } + tallies.filter { $0.team == .home }
    }

    // MARK: - Pitching

    /// One team's pitchers, in the order they pitched.
    static func pitchingTable(_ team: TeamBoxScore, _ names: ShortNames) -> NewspaperTable {
        let rows = team.pitching.map { line in
            NewspaperRow(
                label: names.name(for: line.player, fallback: line.name),
                cells: [
                    inningsPitchedText(line.stats.outsRecorded),
                    String(line.stats.hits), String(line.stats.runs),
                    String(line.stats.walks), String(line.stats.strikeouts),
                ]
            )
        }
        return NewspaperTable(title: team.name, columns: pitchingColumns, rows: rows)
    }

    /// Innings pitched the way a newspaper prints them: "5", "4⅓", "⅔", "0". Three outs
    /// make an inning.
    public static func inningsPitchedText(_ outs: Int) -> String {
        let whole = outs / 3
        let thirds = ["", "⅓", "⅔"][outs % 3]
        if whole == 0 && !thirds.isEmpty { return thirds }
        return "\(whole)\(thirds)"
    }

    /// The notes under the pitching lines: batters hit by a pitch, then each pitcher's
    /// pitches and strikes.
    static func pitchingNotes(_ box: BoxScore, _ names: ShortNames) -> [String] {
        var result: [String] = []
        if let hitByPitch = hitByPitchNote(box, names) {
            result.append("HBP—\(hitByPitch).")
        }
        let pitchers = (box.away.pitching + box.home.pitching).filter { $0.stats.pitches > 0 }
        if !pitchers.isEmpty {
            let list = pitchers.map { line in
                "\(names.name(for: line.player, fallback: line.name)) \(line.stats.pitches)-\(line.stats.strikes)"
            }
            result.append("Pitches-strikes—\(list.joined(separator: ", ")).")
        }
        return result
    }

    /// Batters hit by a pitch. When only one pitcher on the other team hit anybody, it
    /// names them the newspaper way, "by Reyes (Ford)"; otherwise it lists the batters.
    static func hitByPitchNote(_ box: BoxScore, _ names: ShortNames) -> String? {
        var parts: [String] = []
        for side in TeamSide.allCases {
            let batters = box.notes.hitByPitch.filter { $0.team == side }
            guard let list = playerList(batters, names) else { continue }
            let pitchersWhoHit = box[side.opponent].pitching.filter { $0.stats.hitBatters > 0 }
            if pitchersWhoHit.count == 1, let pitcher = pitchersWhoHit.first {
                parts.append("by \(names.name(for: pitcher.player, fallback: pitcher.name)) (\(list))")
            } else {
                parts.append(list)
            }
        }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }
}
