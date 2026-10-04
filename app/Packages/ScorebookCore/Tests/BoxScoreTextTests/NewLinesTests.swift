// Tests of the box score lines added once the stats engine recorded more about a game:
// the winning and losing pitchers, who hit whom with a pitch, who ran for a designated
// non-runner, how long the game took, and the lettered footnotes for pinch hitters and
// pinch runners.

import Foundation
import Testing
import Model
import SampleData
@testable import BoxScoreText

@Suite("Winning and losing pitchers")
struct DecisionTests {
    @Test("The winning pitcher has a W after their name, the losing pitcher an L, everyone else nothing")
    func winAndLoss() {
        let pitching = BoxScorePrinter.layout(SampleGame.boxScore, timeZone: pacific).pitching
        #expect(pitching[0].rows.map(\.label) == ["Collins", "Reyes L"])
        #expect(pitching[1].rows.map(\.label) == ["Barros W", "Voss"])
    }

    @Test("A game with no decisions (a tie, or one still going) marks nobody")
    func noDecisions() {
        var box = SampleGame.boxScore
        box.away.pitching[1].decision = nil
        box.home.pitching[0].decision = nil
        let pitching = BoxScorePrinter.layout(box, timeZone: pacific).pitching
        #expect(pitching.flatMap { $0.rows.map(\.label) } == ["Collins", "Reyes", "Barros", "Voss"])
    }
}

@Suite("Batters hit by a pitch")
struct HitBatterTests {
    @Test("Hit batters are grouped under the pitcher who hit them, in the order the pitchers pitched")
    func groupedByPitcher() {
        var box = SampleGame.boxScore
        box.notes.hitBatters = [
            HitBatterNote(batter: "d6", batterName: "Casey Ford", team: .home, pitcher: "m12", pitcherName: "Gus Reyes", count: 1),
            HitBatterNote(batter: "d3", batterName: "Jordan Webb", team: .home, pitcher: "m9", pitcherName: "Ray Collins", count: 1),
            HitBatterNote(batter: "d2", batterName: "Chris Tate", team: .home, pitcher: "m12", pitcherName: "Gus Reyes", count: 2),
        ]
        let notes = BoxScorePrinter.layout(box, timeZone: pacific).pitchingNotes
        #expect(notes.first == "HBP—by Collins (Webb), by Reyes (Ford, Tate 2).")

        // A batter hit when nobody knew who was pitching is listed alone, at the end.
        box.notes.hitBatters.insert(
            HitBatterNote(batter: "d7", batterName: "Drew Lang", team: .home, pitcher: nil, pitcherName: nil, count: 1), at: 0)
        let withUnknown = BoxScorePrinter.layout(box, timeZone: pacific).pitchingNotes
        #expect(withUnknown.first == "HBP—by Collins (Webb), by Reyes (Ford, Tate 2), Lang.")
    }

    @Test("With nobody hit by a pitch there is no HBP note")
    func nobodyHit() {
        var box = SampleGame.boxScore
        box.notes.hitBatters = []
        box.notes.hitByPitch = []
        let notes = BoxScorePrinter.layout(box, timeZone: pacific).pitchingNotes
        #expect(!notes.contains { $0.hasPrefix("HBP") })
    }
}

@Suite("Runners for designated non-runners")
struct RanForTests {
    @Test("The sample game's runner is the last note: Webb ran for Quinn in the 3rd")
    func sampleGame() {
        let notes = BoxScorePrinter.layout(SampleGame.boxScore, timeZone: pacific).notes
        #expect(notes.last == "Webb ran for Quinn in the 3rd.")
    }

    @Test("Several innings are listed the newspaper way, and the visitors' runners come first")
    func severalInnings() {
        var box = SampleGame.boxScore
        box.notes.ranForNonRunners = [
            NonRunnerRunnerNote(runner: "d3", runnerName: "Jordan Webb", nonRunner: "d4",
                                nonRunnerName: "Pat Quinn", team: .home, innings: [3, 5, 7]),
            NonRunnerRunnerNote(runner: "m6", runnerName: "Eddie Park", nonRunner: "m3",
                                nonRunnerName: "Marcus Hale", team: .away, innings: [2, 4]),
        ]
        let notes = BoxScorePrinter.layout(box, timeZone: pacific).notes
        #expect(Array(notes.suffix(2)) == ["Park ran for Hale in the 2nd and 4th.",
                                           "Webb ran for Quinn in the 3rd, 5th and 7th."])
    }

    @Test("With nobody running for a designated non-runner there is no such note")
    func nobodyRan() {
        var box = SampleGame.boxScore
        box.notes.ranForNonRunners = []
        let notes = BoxScorePrinter.layout(box, timeZone: pacific).notes
        #expect(notes.last == "SF—Ruiz, Fisk.")
    }
}

@Suite("How long the game took")
struct GameLengthTests {
    @Test("The game's length prints as hours and whole minutes, with leftover seconds dropped")
    func hoursAndMinutes() {
        #expect(BoxScorePrinter.gameLengthText(11_552) == "3:12")
        #expect(BoxScorePrinter.gameLengthText(7_199) == "1:59")
        #expect(BoxScorePrinter.gameLengthText(3_660) == "1:01")
        #expect(BoxScorePrinter.gameLengthText(2_880) == "0:48")
        #expect(BoxScorePrinter.layout(SampleGame.boxScore, timeZone: pacific).pitchingNotes.last == "T—3:12.")
    }

    @Test("With no length known, as before the game ends, there is no T note")
    func noLength() {
        var box = SampleGame.boxScore
        box.gameLength = nil
        let notes = BoxScorePrinter.layout(box, timeZone: pacific).pitchingNotes
        #expect(!notes.contains { $0.hasPrefix("T—") })
    }
}

@Suite("Pinch hitters' and pinch runners' footnotes")
struct FootnoteTests {
    @Test("Two pinch hitters are lettered a and b in batting order, and a pinch runner on the other team starts again at a")
    func twoPinchHitters() {
        var box = SampleGame.boxScore
        // Make Reyes a second pinch hitter, who singled batting for Moss in the 5th.
        box.away.batting[10].entered = SubstituteEntry(inning: 5, kind: .pinchHitter, replaced: "m10",
                                                       replacedName: "Kyle Moss", outcome: .single, notation: "1B 7")
        // And Voss a pinch runner for Barros in the 7th.
        box.home.batting[9].entered = SubstituteEntry(inning: 7, kind: .pinchRunner, replaced: "d9",
                                                      replacedName: "Sky Barros")
        let layout = BoxScorePrinter.layout(box, timeZone: pacific)
        #expect(Array(layout.batting[0].rows.map(\.paddedLabel)[9...10]) == ["  a-Moss ph", "  b-Reyes p"])
        #expect(layout.batting[0].footnotes == ["a-popped out for Collins in the 4th.", "b-singled for Moss in the 5th."])
        #expect(layout.batting[1].rows[9].paddedLabel == "  a-Voss p")
        #expect(layout.batting[1].footnotes == ["a-ran for Barros in the 7th."])

        // In plain text the footnotes sit on one line right under the team's totals.
        let text = BoxScorePrinter.text(box, timeZone: pacific)
        #expect(text.contains("Totals              20  3  7  3\na-popped out for Collins in the 4th. b-singled for Moss in the 5th.\n\n"))
    }

    @Test("A player who only took over a spot, like a new pitcher, gets no letter and no footnote")
    func noFootnotes() {
        var box = SampleGame.boxScore
        for i in box.away.batting.indices { box.away.batting[i].entered = nil }
        let layout = BoxScorePrinter.layout(box, timeZone: pacific)
        #expect(layout.batting.allSatisfy { $0.footnotes.isEmpty })
        #expect(layout.batting[0].rows[9].paddedLabel == "  Moss ph")
        #expect(layout.batting[1].rows[9].paddedLabel == "  Voss p")
        #expect(!BoxScorePrinter.text(box, timeZone: pacific).contains("a-"))
    }

    @Test("A pinch hitter whose turn at bat did not end batted for the player")
    func noOutcome() {
        let entry = SubstituteEntry(inning: 6, kind: .pinchHitter, replaced: "m9", replacedName: "Ray Collins")
        let names = ShortNames(SampleGame.boxScore)
        #expect(BoxScorePrinter.substituteWording(entry, names) == "batted for Collins in the 6th")
    }

    @Test("Each way a turn at bat ends is worded in plain baseball English")
    func outcomeWording() {
        let cases: [(PlateAppearanceOutcome, String?, String)] = [
            (.out, "F8", "flied out"),
            (.out, "P6", "popped out"),
            (.out, "L6", "lined out"),
            (.out, "6-3", "grounded out"),
            (.out, "3U", "grounded out"),
            (.out, "6-4-3 DP", "grounded into a double play"),
            (.out, "L4-3 DP", "lined into a double play"),
            (.out, "F8 DP", "hit into a double play"),
            (.out, "5-4-3 TP", "grounded into a triple play"),
            (.out, "4", "made an out"),
            (.out, nil, "made an out"),
            (.strikeout, "K", "struck out"),
            (.strikeout, "ꓘ", "struck out"),
            (.walk, "BB", "walked"),
            (.intentionalWalk, "IBB", "was intentionally walked"),
            (.hitByPitch, "HBP", "was hit by a pitch"),
            (.single, "1B 7", "singled"),
            (.double, "2B 7", "doubled"),
            (.triple, "3B 8", "tripled"),
            (.homeRun, "HR 7", "homered"),
            (.sacrificeFly, "SF 8", "hit a sacrifice fly"),
            (.sacrificeBunt, "SH 1-3", "sacrificed"),
            (.reachedOnError, "E6", "reached on an error"),
            (.fieldersChoice, "FC 4-6", "hit into a fielder's choice"),
            (.catchersInterference, "CI", "reached on catcher's interference"),
        ]
        for (outcome, notation, words) in cases {
            #expect(BoxScorePrinter.outcomeWords(outcome, notation: notation) == words, "\(outcome) \(notation ?? "nil")")
        }
    }

    @Test("Innings are written 1st, 2nd, 3rd, 4th, 11th, 12th, 13th, 21st")
    func ordinals() {
        #expect([1, 2, 3, 4, 11, 12, 13, 21, 22].map(BoxScorePrinter.ordinal)
                == ["1st", "2nd", "3rd", "4th", "11th", "12th", "13th", "21st", "22nd"])
    }
}
