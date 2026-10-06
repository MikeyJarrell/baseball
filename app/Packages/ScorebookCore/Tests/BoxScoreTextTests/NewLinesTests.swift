// Tests of the box score lines added once the stats engine recorded more about a game:
// the winning and losing pitchers, who hit whom with a pitch, how long the game took, and
// the lines left out on purpose (who ran for a designated non-runner, and footnotes for
// pinch hitters and pinch runners).

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
    @Test("Who ran for a designated non-runner is left out of the notes")
    func leftOut() {
        let notes = BoxScorePrinter.layout(SampleGame.boxScore, timeZone: pacific).notes
        #expect(!SampleGame.boxScore.notes.ranForNonRunners.isEmpty)
        #expect(!notes.contains { $0.contains("ran for") })
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

@Suite("Pinch hitters and pinch runners")
struct SubstituteLineTests {
    @Test("A pinch hitter is pushed in under the player he batted for, with no letter and no footnote")
    func noFootnotes() {
        let layout = BoxScorePrinter.layout(SampleGame.boxScore, timeZone: pacific)
        #expect(layout.batting[0].rows[9].paddedLabel == "  Moss PH")
        #expect(layout.batting[1].rows[9].paddedLabel == "  Voss P")
        let text = BoxScorePrinter.text(SampleGame.boxScore, timeZone: pacific)
        #expect(!text.contains("a-"))
        #expect(!text.contains("popped out for"))
    }
}
