// The play-log wording helpers the game overview reads: the base a runner was put out at
// (and older saved logs without it), the base stolen, and the name of the break between
// half-innings.

import Foundation
import Testing
import Model

@Suite("Play-log wording helpers")
struct PlayLogWordingTests {
    @Test("An out saved before the base was recorded still reads, with no base")
    func olderOutWithoutBaseReads() throws {
        let old = Data(#"{"runner":"m1","putout":"d6","assists":["d4"]}"#.utf8)
        let out = try ScorebookJSON.decode(OutMade.self, from: old)
        #expect(out == OutMade(runner: "m1", putout: "d6", assists: ["d4"]))
        #expect(out.at == nil)
    }

    @Test("An out with its base reads back exactly")
    func outWithBaseRoundTrips() throws {
        let out = OutMade(runner: "m1", putout: "d6", assists: ["d2"], at: .second)
        #expect(try ScorebookJSON.decode(OutMade.self, from: ScorebookJSON.encode(out)) == out)
    }

    @Test("The base stolen is the next one along; a steal from third is a steal of home")
    func baseStolen() {
        #expect(RunnerMove(runner: "m1", from: .first, to: .second, reason: .stolenBase).baseStolen == .second)
        #expect(RunnerMove(runner: "m1", from: .second, to: .third, reason: .stolenBase).baseStolen == .third)
        let home = RunnerMove(runner: "m1", from: .third, to: .scored, reason: .stolenBase)
        #expect(home.baseStolen == .home)
        #expect(home.isStealOfHome)
        // A steal of third that scores on the throw is still a steal of third.
        let thirdAndError = RunnerMove(runner: "m1", from: .second, to: .scored, reason: .stolenBase, advancedOnError: true)
        #expect(thirdAndError.baseStolen == .third)
        #expect(!thirdAndError.isStealOfHome)
        // Anything else stole nothing.
        #expect(RunnerMove(runner: "m1", from: .third, to: .scored, reason: .wildPitch).baseStolen == nil)
    }

    @Test("Breaks are named the way people say them")
    func breakLabels() {
        #expect(InningBreak(after: .top, of: 3).label == "Middle of the 3rd")
        #expect(InningBreak(after: .bottom, of: 1).label == "End of the 1st")
        #expect(InningBreak(after: .top, of: 2).shortLabel == "Middle 2nd")
        #expect(InningBreak(after: .bottom, of: 11).label == "End of the 11th")
        #expect(InningBreak(after: .bottom, of: 21).label == "End of the 21st")
    }

    @Test("The situation names its break only between half-innings, and not once the game is over")
    func situationBreak() {
        var s = Situation(away: TeamState(battingOrder: BattingOrder(slots: [])),
                          home: TeamState(battingOrder: BattingOrder(slots: [])))
        s.inning = 4
        s.half = .top
        #expect(s.inningBreak == nil)
        s.isBetweenHalfInnings = true
        #expect(s.inningBreak == InningBreak(kind: .end, inning: 3))
        s.half = .bottom
        #expect(s.inningBreak == InningBreak(kind: .middle, inning: 4))
        s.isFinal = true
        #expect(s.inningBreak == nil)
    }
}
