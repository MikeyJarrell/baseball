// Tests that the sample game prints exactly as a newspaper would have printed it.
//
// The expected text below was worked out by hand from the sample game's box score
// (SampleData/SampleBoxScore.swift), adding up every column and checking every note,
// then compared with the printer's output character for character. The spacing was
// widened after review so the line score's runs, hits and errors sit under r, h and bi.
// The newer lines were worked out the same way: Moss is the Mudcats' only pinch hitter,
// so they are "a" and popped out ("P6") for Collins in the 4th; Voss and Reyes only took
// over a spot, so they get no letter; Barros won and Reyes lost; Reyes hit Ford; Webb ran
// for Quinn in the 3rd; and 11,552 seconds is 192 whole minutes, 3 hours 12 minutes.

import Foundation
import Testing
import Model
import SampleData
@testable import BoxScoreText

/// The sample game was played in San Diego, so its date prints in Pacific time.
let pacific = TimeZone(identifier: "America/Los_Angeles")!

@Suite("The sample game's box score text")
struct SampleGameTextTests {
    @Test("The finished sample game matches the hand-checked box score, character for character")
    func finishedGame() {
        let expected = """
        Saturday, May 2
        Diamond Dogs 5, Mudcats 3

        MUDCATS             ab  r  h bi
        Ortiz cf             3  1  2  0
        Ruiz ss              2  0  1  1
        Hale 1b              3  0  1  0
        Diaz lf              2  1  1  1
        Kim 3b               2  1  1  0
        Park rf              3  0  0  0
        Varga c              1  0  0  0
        Bell 2b              2  0  1  1
        Collins p            1  0  0  0
          a-Moss ph          1  0  0  0
          Reyes p            0  0  0  0
        Totals              20  3  7  3
        a-popped out for Collins in the 4th.

        DIAMOND DOGS        ab  r  h bi
        Moreno 2b            2  1  1  1
        Tate ss              2  1  1  1
        Webb cf              3  1  1  1
        Quinn 1b             3  0  1  0
        Shaw 3b              2  0  1  1
        Ford lf              1  1  0  0
        Lang rf              2  0  1  0
        Fisk c               1  0  0  1
        Barros p             2  0  1  0
          Voss p             0  0  0  0
        Cole dh              2  1  2  0
        Totals              20  5  9  5

        Mudcats      011 10  —  3  7  1
        Diamond Dogs 201 11  —  5  9  1

        E—Kim, Tate. DP—Mudcats 2, Diamond Dogs 2. LOB—Mudcats 6, Diamond Dogs 4. 2B—Ruiz, Webb, Cole. 3B—Ortiz. HR—Diaz, Tate. SB—Park, Cole. CS—Webb. S—Tate. SF—Ruiz, Fisk. Webb ran for Quinn in the 3rd.

        MUDCATS             ip  h  r bb so
        Collins              3  6  3  1  2
        Reyes L              2  3  2  0  0
        DIAMOND DOGS        ip  h  r bb so
        Barros W             4  6  3  2  1
        Voss                 1  1  0  1  1

        HBP—by Reyes (Ford). Pitches-strikes—Collins 47-30, Reyes 23-15, Barros 57-35, Voss 13-9. T—3:12.
        """
        let printed = BoxScorePrinter.text(SampleGame.boxScore, timeZone: pacific)
        #expect(printed == expected)
        // If they differ, show the first line that does, so the mistake is easy to find.
        for (got, want) in zip(printed.split(separator: "\n", omittingEmptySubsequences: false),
                               expected.split(separator: "\n", omittingEmptySubsequences: false)) where got != want {
            Issue.record("First different line:\n got: \(got)\nwant: \(want)")
            break
        }
    }

    @Test("A game still going says so under the headline, with the leader first")
    func gameInProgress() {
        let layout = BoxScorePrinter.layout(SampleGame.boxScoreThroughThree, timeZone: pacific)
        #expect(layout.headline == "Diamond Dogs 3, Mudcats 2")
        #expect(layout.status == "In progress")
        #expect(layout.lineScore.rows.map(\.innings) == [["0", "1", "1"], ["2", "0", "1"]])
        // The finished game has no status line at all.
        #expect(BoxScorePrinter.layout(SampleGame.boxScore, timeZone: pacific).status == nil)
    }

    @Test("Each team's totals row adds up its batters' at-bats, runs, hits and runs batted in")
    func totalsAddUp() {
        let layout = BoxScorePrinter.layout(SampleGame.boxScore, timeZone: pacific)
        for (table, team) in zip(layout.batting, [SampleGame.boxScore.away, SampleGame.boxScore.home]) {
            let totals = table.rows.last!
            #expect(totals.isTotal)
            #expect(totals.cells == ["\(team.battingTotals.atBats)", "\(team.runs)", "\(team.hits)",
                                     "\(team.battingTotals.runsBattedIn)"])
        }
    }

    @Test("Substitutes are printed under the player they replaced, pushed in")
    func substitutes() {
        let mudcats = BoxScorePrinter.layout(SampleGame.boxScore, timeZone: pacific).batting[0]
        let labels = mudcats.rows.map(\.paddedLabel)
        #expect(Array(labels[8...10]) == ["Collins p", "  a-Moss ph", "  Reyes p"])
    }
}
