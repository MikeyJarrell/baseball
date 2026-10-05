// Tests of the pieces of a newspaper box score: shortened names, long lineups, the line
// score, innings pitched and the notes.

import Foundation
import Testing
import Model
import SampleData
@testable import BoxScoreText

@Suite("Shortened names")
struct ShortNameTests {
    @Test("Last names only, unless two players in the game share one")
    func lastNamesOnly() {
        let names = ShortNames(fullNames: [
            ("a1", "Luis Ortiz"), ("h1", "Ana Ortiz"), ("h2", "Chris Tate"),
        ])
        #expect(names.name(for: "a1", fallback: "") == "L. Ortiz")
        #expect(names.name(for: "h1", fallback: "") == "A. Ortiz")
        #expect(names.name(for: "h2", fallback: "") == "Tate")
    }

    @Test("When the initials match too, both players are printed in full")
    func sameInitial() {
        let names = ShortNames(fullNames: [("a", "Luis Ortiz"), ("b", "Leo Ortiz"), ("c", "Ana Ortiz")])
        #expect(names.name(for: "a", fallback: "") == "Luis Ortiz")
        #expect(names.name(for: "b", fallback: "") == "Leo Ortiz")
        #expect(names.name(for: "c", fallback: "") == "A. Ortiz")
    }

    @Test("Numbers, stand-ins and one-word names are printed whole; Jr. stays with the last name")
    func unusualNames() {
        let names = ShortNames(fullNames: [
            ("a", "#22"), ("b", "Batter 4"), ("c", "Ichiro"), ("d", "Ken Griffey Jr."), ("e", "Unknown player"),
        ])
        #expect(names.name(for: "a", fallback: "") == "#22")
        #expect(names.name(for: "b", fallback: "") == "Batter 4")
        #expect(names.name(for: "c", fallback: "") == "Ichiro")
        #expect(names.name(for: "d", fallback: "") == "Griffey Jr.")
        #expect(names.name(for: "e", fallback: "") == "Unknown player")
    }

    @Test("A last name of more than one word is kept whole: De La Cruz, Van Buren, St. Clair")
    func multiWordLastNames() {
        let names = ShortNames(fullNames: [
            ("a", "Elly De La Cruz"), ("b", "Martin Van Buren"), ("c", "Pat St. Clair"),
            ("d", "Ana de la Cruz"), ("e", "Van Smith"),
        ])
        #expect(names.name(for: "a", fallback: "") == "E. De La Cruz")
        #expect(names.name(for: "d", fallback: "") == "A. de la Cruz")
        #expect(names.name(for: "b", fallback: "") == "Van Buren")
        #expect(names.name(for: "c", fallback: "") == "St. Clair")
        // "Van" here is a first name, so only "Smith" is the last name.
        #expect(names.name(for: "e", fallback: "") == "Smith")
    }

    @Test("A shared last name across the two teams gets initials in the batting lines and the notes")
    func sharedAcrossTeams() {
        var box = SampleGame.boxScore
        // Give the Diamond Dogs' Jamie Cole the Mudcats leadoff hitter's last name.
        rename(&box, "d10", to: "Jamie Ortiz")
        let text = BoxScorePrinter.text(box, timeZone: pacific)
        #expect(text.contains("L. Ortiz CF"))
        #expect(text.contains("J. Ortiz DH"))
        #expect(text.contains("2B—Ruiz, Webb, J. Ortiz."))
        #expect(text.contains("3B—L. Ortiz."))
    }

    /// Changes one player's name everywhere it appears in a box score.
    func rename(_ box: inout BoxScore, _ id: PlayerID, to name: String) {
        for side in TeamSide.allCases {
            var team = box[side]
            for i in team.batting.indices where team.batting[i].player == id { team.batting[i].name = name }
            for i in team.fielding.indices where team.fielding[i].player == id { team.fielding[i].name = name }
            if side == .away { box.away = team } else { box.home = team }
        }
        func fix(_ list: inout [PlayerTally]) {
            for i in list.indices where list[i].player == id { list[i].name = name }
        }
        fix(&box.notes.doubles)
        fix(&box.notes.stolenBases)
    }
}

@Suite("Long and short lineups")
struct LineupTests {
    /// The sample game with the Diamond Dogs batting fourteen, one with a very long name.
    static func fourteenHitters() -> BoxScore {
        var box = SampleGame.boxScore
        let names = ["Alex Moreno", "Chris Tate", "Jordan Webb", "Pat Quinn", "Riley Shaw", "Casey Ford",
                     "Drew Lang", "Morgan Fisk", "Sky Barros", "Jamie Cole", "Robin Nash",
                     "Christopher Montgomery-Wallace", "Taylor Voss", "Batter 14"]
        // The sample roster’s own ids, so each player is the same person everywhere in the box score.
        let ids: [PlayerID] = ["d1", "d2", "d3", "d4", "d5", "d6", "d7", "d8", "d9", "d10", "d11", "x12", "d12", "x14"]
        box.home.batting = names.enumerated().map { index, name in
            BattingLine(player: ids[index], name: name, batterIndex: index,
                        positions: index < 9 ? [BoxPosition.allCases[index]] : [],
                        stats: BattingCounts(plateAppearances: 2, atBats: 2, runs: index % 2, hits: 1,
                                             runsBattedIn: index % 3 == 0 ? 1 : 0))
        }
        return box
    }

    @Test("Nine and fourteen hitters both print every batter, with every column lined up")
    func columnsLineUp() {
        let box = Self.fourteenHitters()
        let layout = BoxScorePrinter.layout(box, timeZone: pacific)
        #expect(layout.batting[0].rows.count == 11 + 1)   // Mudcats: nine starters, two subs, totals
        #expect(layout.batting[1].rows.count == 14 + 1)   // fourteen hitters and totals
        #expect(layout.batting[1].rows.last!.cells == ["28", "7", "14", "5"])

        // In plain text every batting line, heading and totals line is the same length, so
        // the numbers sit in the same columns from the first hitter to the fourteenth.
        let text = BoxScorePrinter.text(box, timeZone: pacific)
        let battingBlocks = text.components(separatedBy: "\n\n")[1...2]
        for (block, table) in zip(battingBlocks, layout.batting) {
            // The heading and the rows; the pinch hitters' footnote line under them is prose.
            let tableLines = block.split(separator: "\n").prefix(table.rows.count + 1)
            let lengths = Set(tableLines.map(\.count))
            #expect(lengths.count == 1, "lines of different lengths: \(lengths)")
        }
        #expect(text.contains("Montgomery-Wallace DH"))
        #expect(text.contains("Batter 14 DH"))
    }

    @Test("A player who played two positions shows both, joined by a dash")
    func twoPositions() {
        var box = SampleGame.boxScore
        box.away.batting[9].positions = [.ph, .secondBase]
        let mudcats = BoxScorePrinter.layout(box, timeZone: pacific).batting[0]
        #expect(mudcats.rows[9].label == "Moss PH-2B")
    }
}

@Suite("The line score")
struct LineScoreTests {
    @Test("Innings print in groups of three, a ten-run inning in brackets, and x when the home team did not bat")
    func extraInningsAndBigInnings() {
        var box = SampleGame.boxScore
        box.lineScore = LineScore(away: [0, 1, 0, 0, 0, 12, 0, 0, 0, 1],
                                  home: [2, 0, 0, 3, 0, 0, 4, 2, 2, nil])
        box.away.runs = 14
        box.home.runs = 13
        let text = BoxScorePrinter.text(box, timeZone: pacific)
        #expect(text.contains("Mudcats      010 00(12) 000 1  — 14  7  1"))
        #expect(text.contains("Diamond Dogs 200 30   0 422 x  — 13  9  1"))
        #expect(text.hasPrefix("Saturday, May 2\nMudcats 14\nDiamond Dogs 13"))
    }

    @Test("A tie puts the visitors first in the headline")
    func tie() {
        var box = SampleGame.boxScore
        box.home.runs = 3
        #expect(BoxScorePrinter.headline(box) == "Mudcats 3\nDiamond Dogs 3")
    }
}

@Suite("Innings pitched and notes")
struct NotesTests {
    @Test("Innings pitched print as whole innings and thirds")
    func inningsPitched() {
        #expect(BoxScorePrinter.inningsPitchedText(0) == "0")
        #expect(BoxScorePrinter.inningsPitchedText(1) == "⅓")
        #expect(BoxScorePrinter.inningsPitchedText(2) == "⅔")
        #expect(BoxScorePrinter.inningsPitchedText(15) == "5")
        #expect(BoxScorePrinter.inningsPitchedText(13) == "4⅓")
    }

    @Test("A player who did something twice has the count after their name, and the visitors come first")
    func countsAndOrder() {
        var box = SampleGame.boxScore
        box.notes.errors = [PlayerTally(player: "d2", name: "Chris Tate", team: .home, count: 1),
                            PlayerTally(player: "m2", name: "Danny Ruiz", team: .away, count: 2)]
        let notes = BoxScorePrinter.layout(box, timeZone: pacific).notes
        #expect(notes.first == "E—Ruiz 2, Tate.")
    }

    @Test("A note with nobody in it is left out, and so is a team with no double plays")
    func emptyNotes() {
        var box = SampleGame.boxScore
        box.notes = BoxScoreNotes(doublePlays: [TeamTally(team: .away, name: "Mudcats", count: 0)],
                                  leftOnBase: [TeamTally(team: .away, name: "Mudcats", count: 0),
                                               TeamTally(team: .home, name: "Diamond Dogs", count: 3)])
        let notes = BoxScorePrinter.layout(box, timeZone: pacific).notes
        #expect(notes == ["LOB—Mudcats 0, Diamond Dogs 3."])
    }

    @Test("A pitcher whose pitches were not counted is still listed, with a dash")
    func uncountedPitcher() {
        var box = SampleGame.boxScore
        box.home.pitching[1].stats.pitches = 0
        box.home.pitching[1].stats.strikes = 0
        let notes = BoxScorePrinter.layout(box, timeZone: pacific).pitchingNotes
        #expect(notes.contains("Pitches-strikes—Collins 47-30, Reyes 23-15, Barros 57-35, Voss —."))

        // With no pitches counted for anybody, the note is left out.
        for i in box.away.pitching.indices { box.away.pitching[i].stats.pitches = 0 }
        for i in box.home.pitching.indices { box.home.pitching[i].stats.pitches = 0 }
        #expect(BoxScorePrinter.layout(box, timeZone: pacific).pitchingNotes == ["HBP—by Reyes (Ford).", "T—3:12."])
    }

    @Test("An older box score that does not say who hit whom lists the batters without guessing")
    func hitByPitchWithTwoPitchers() {
        var box = SampleGame.boxScore
        // Box scores saved before the app recorded the pitcher for each hit batter.
        box.notes.hitBatters = []
        #expect(BoxScorePrinter.layout(box, timeZone: pacific).pitchingNotes.first == "HBP—by Reyes (Ford).")
        box.away.pitching[0].stats.hitBatters = 1
        box.notes.hitByPitch.append(PlayerTally(player: "d3", name: "Jordan Webb", team: .home, count: 1))
        let notes = BoxScorePrinter.layout(box, timeZone: pacific).pitchingNotes
        #expect(notes.first == "HBP—Ford, Webb.")
    }
}
