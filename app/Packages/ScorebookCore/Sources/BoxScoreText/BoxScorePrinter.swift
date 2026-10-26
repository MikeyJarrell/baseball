// BoxScoreText: a box score in, a newspaper-style box score out.
//
// `BoxScorePrinter.layout` works out every line a newspaper sports page would print for a
// game: the headline with the score (one team to a line), each team's batting lines (ab r h
// bi) and totals, the line score by inning, the notes, one kind to a line ("2B—Ruiz, Webb.",
// "DP—Mudcats 2."), the pitching lines (ip h r bb so) with the winning and losing pitchers
// marked "W" and "L", and the notes under them, ending with the game's length ("T—3:12."). `BoxScorePrinter.text` turns that layout into plain text
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

    /// The score with the team ahead first, one team to a line, so a long team name never
    /// breaks across two: "Diamond Dogs 5" over "Mudcats 3". A tie puts the visitors first, as
    /// the line score does.
    static func headline(_ box: BoxScore) -> String {
        let (first, second) = box.home.runs > box.away.runs ? (box.home, box.away) : (box.away, box.home)
        return "\(first.name) \(first.runs)\n\(second.name) \(second.runs)"
    }

    // MARK: - Batting

    /// One team's batting lines, with substitutes under the player they replaced (the stats
    /// engine already lists them that way, pushed in, marked "PH" or "PR") and a totals row
    /// at the bottom.
    static func battingTable(_ team: TeamBoxScore, _ names: ShortNames) -> NewspaperTable {
        var rows: [NewspaperRow] = []
        for line in team.batting {
            let label = "\(names.name(for: line.player, fallback: line.name)) \(positionText(line))"
            rows.append(NewspaperRow(label: label, isSubstitute: line.isSubstitute, cells: battingCells(line.stats)))
        }
        rows.append(NewspaperRow(label: "Totals", isTotal: true, cells: battingCells(team.battingTotals)))
        return NewspaperTable(title: team.name, columns: battingColumns, rows: rows)
    }

    /// The positions a batter played, in capitals and joined by dashes: "SS", "PH-2B". A
    /// starter who only batted is printed "DH"; a substitute who only batted, "PH".
    ///
    /// "DH" is used for every hitter who bats without fielding, even when the pitcher bats
    /// too (strictly an extra hitter): readers know "DH", and the league makes no difference
    /// between the two.
    static func positionText(_ line: BattingLine) -> String {
        if line.positions.isEmpty {
            return line.isSubstitute ? BoxPosition.ph.rawValue.uppercased() : "DH"
        }
        return line.positions.map { $0.rawValue.uppercased() }.joined(separator: "-")
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

    /// The notes under the line score, in the newspaper's usual order: double plays, triple plays, runners left on base, doubles, triples, home runs, stolen bases, caught
    /// stealing, sacrifice bunts ("S"), sacrifice flies. A note with nobody in it is left out.
    /// Who ran for a designated non-runner is not printed: it happens most innings and tells
    /// the reader little. Nor is who made the errors (the team's count is in the line score):
    /// in a casual league nobody needs that in print.
    static func notes(_ box: BoxScore, _ names: ShortNames) -> [String] {
        let n = box.notes
        let entries: [(String, String?)] = [
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

    /// One team's pitchers, in the order they pitched. The winning pitcher has a "W" after
    /// their name and the losing pitcher an "L" ("Barros W"), as newspapers print it. A
    /// newspaper adds the pitcher's season record ("W, 4-1"), but records are not kept.
    static func pitchingTable(_ team: TeamBoxScore, _ names: ShortNames) -> NewspaperTable {
        let rows = team.pitching.map { line in
            NewspaperRow(
                label: names.name(for: line.player, fallback: line.name) + decisionText(line.decision),
                cells: [
                    inningsPitchedText(line.stats.outsRecorded),
                    String(line.stats.hits), String(line.stats.runs),
                    String(line.stats.walks), String(line.stats.strikeouts),
                ]
            )
        }
        return NewspaperTable(title: team.name, columns: pitchingColumns, rows: rows)
    }

    /// The mark after a pitcher's name for the game's decision: " W" for the winning
    /// pitcher, " L" for the losing pitcher, and nothing for everyone else.
    static func decisionText(_ decision: PitchingDecision?) -> String {
        switch decision {
        case .win: return " W"
        case .loss: return " L"
        case nil: return ""
        }
    }

    /// Innings pitched the way an old-time newspaper printed them: "5", "4⅓", "⅔", "0",
    /// rather than today's "4.1" (Mikey's choice, for the old-school look). Three outs make
    /// an inning.
    public static func inningsPitchedText(_ outs: Int) -> String {
        let whole = outs / 3
        let thirds = ["", "⅓", "⅔"][outs % 3]
        if whole == 0 && !thirds.isEmpty { return thirds }
        return "\(whole)\(thirds)"
    }

    /// The notes under the pitching lines: batters hit by a pitch, then each pitcher's
    /// pitches and strikes, then how long the game took. A pitcher whose pitches were not
    /// counted still appears, with a dash, so nobody reads them as not having pitched; if no
    /// pitches were counted for anybody, the note is left out.
    static func pitchingNotes(_ box: BoxScore, _ names: ShortNames) -> [String] {
        var result: [String] = []
        if let hitByPitch = hitByPitchNote(box, names) {
            result.append("HBP—\(hitByPitch).")
        }
        let pitchers = box.away.pitching + box.home.pitching
        if pitchers.contains(where: { $0.stats.pitches > 0 }) {
            let list = pitchers.map { line in
                let name = names.name(for: line.player, fallback: line.name)
                let count = line.stats.pitches > 0 ? "\(line.stats.pitches)-\(line.stats.strikes)" : "—"
                return "\(name) \(count)"
            }
            result.append("Pitches-strikes—\(list.joined(separator: ", ")).")
        }
        if let length = gameLengthText(box.gameLength) {
            result.append("T—\(length).")
        }
        return result
    }

    /// How long the game took, as hours and minutes the newspaper way: 11,552 seconds is
    /// "3:12" (any leftover seconds are dropped, not rounded up). Missing when the length
    /// is not known, as before the game ends.
    static func gameLengthText(_ seconds: TimeInterval?) -> String? {
        guard let seconds, seconds.isFinite, seconds >= 0 else { return nil }
        let minutes = Int(seconds) / 60
        return "\(minutes / 60):" + String(format: "%02d", minutes % 60)
    }

    /// Batters hit by a pitch, grouped under the pitcher who hit them, the newspaper way:
    /// "by Reyes (Ford)", or "by Collins (Webb), by Reyes (Ford, Tate 2)" when two pitchers
    /// hit batters. Pitchers come in the order they pitched, visitors' pitchers first. A
    /// batter hit when nobody knew who was pitching is listed on their own at the end.
    ///
    /// Box scores saved before the app recorded who hit whom fall back to the older note
    /// (see `olderHitByPitchNote`).
    static func hitByPitchNote(_ box: BoxScore, _ names: ShortNames) -> String? {
        let hit = box.notes.hitBatters.filter { $0.count > 0 }
        guard !hit.isEmpty else { return olderHitByPitchNote(box, names) }

        // Group the hit batters by pitcher, keeping each pitcher's batters in the order given.
        var pitchers: [PlayerID?] = []
        var battersByPitcher: [PlayerID?: [HitBatterNote]] = [:]
        for note in hit {
            if battersByPitcher[note.pitcher] == nil { pitchers.append(note.pitcher) }
            battersByPitcher[note.pitcher, default: []].append(note)
        }
        // Pitchers in the order they appear in the pitching lines; an unknown pitcher last.
        let pitchingOrder = (box.away.pitching + box.home.pitching).map(\.player)
        func place(_ pitcher: PlayerID?) -> Int {
            guard let pitcher else { return Int.max }
            return pitchingOrder.firstIndex(of: pitcher) ?? pitchingOrder.count
        }
        let ordered = pitchers.enumerated()
            .sorted { (place($0.element), $0.offset) < (place($1.element), $1.offset) }
            .map(\.element)

        let parts = ordered.map { pitcher -> String in
            let notes = battersByPitcher[pitcher]!
            let batters = notes.map { note in
                let name = names.name(for: note.batter, fallback: note.batterName)
                return note.count > 1 ? "\(name) \(note.count)" : name
            }.joined(separator: ", ")
            guard let pitcher, let first = notes.first else { return batters }
            return "by \(names.name(for: pitcher, fallback: first.pitcherName ?? "")) (\(batters))"
        }
        return parts.joined(separator: ", ")
    }

    /// The hit-by-pitch note for a box score that names only the batters hit, not who hit
    /// them. When only one pitcher on the other team hit anybody, it names them the
    /// newspaper way, "by Reyes (Ford)"; otherwise it lists the batters.
    static func olderHitByPitchNote(_ box: BoxScore, _ names: ShortNames) -> String? {
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
