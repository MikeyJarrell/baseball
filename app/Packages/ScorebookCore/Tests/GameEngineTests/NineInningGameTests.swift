// A complete nine-inning game, written pitch by pitch, whose final score, line score,
// runners left on base and pitch counts were worked out by hand (the pitch counts also by a
// separate counting script, not this engine).
//
// Mudcats at Diamond Dogs. Barros (d9) pitches until Voss (d12) relieves in the fifth;
// Collins (m9) pitches the whole game for the Mudcats. The sixth inning ends on a caught
// stealing. The Diamond Dogs lead 6-5 after the top of the ninth, so the bottom half is not
// needed and the app asks whether the game is over.

import Foundation
import Testing
import Model
import GameEngine

@Suite("A complete nine-inning game")
struct NineInningGameTests {
    /// The game, and the id of the caught stealing that ends the sixth.
    static func game() throws -> (game: Game, caughtStealing: EventID) {
        var w = try GameWriter.standard()

        // Top 1: three up, three down.
        w.pa("BC", ground("m1", 6, 3))
        w.pa("CS", last: "S")
        w.pa("", fly("m3", 8))
        // Bottom 1: walk, single, double (1 run), sacrifice fly (1 run), ground out, called strike three.
        w.pa("BBB", last: "B")
        w.pa("C", hit(.single, "d2", to: 7, others: [mv("d1", .first, .second)]))
        w.pa("BS", hit(.double, "d3", to: 9, others: [mv("d1", .second, .scored), mv("d2", .first, .third)], rbi: 1))
        w.pa("F", Play(batterResult: .sacrificeFly, battedBall: .flyBall, fielders: pos(8),
                       runners: [mv("d4", .home, .out, outBy: pos(8)), mv("d2", .third, .scored)], rbi: 1))
        w.pa("BB", ground("d5", 6, 3, others: [mv("d3", .second, .third)]))
        w.pa("CC", last: "C")

        // Top 2: home run, ground out, strikeout, pop-up.
        w.pa("", hit(.homeRun, "m4", to: 7, rbi: 1))
        w.pa("BCF", ground("m5", 4, 3))
        w.pa("SSF", last: "S")
        w.pa("B", Play(batterResult: .out, battedBall: .popUp, fielders: pos(6), runners: [mv("m7", .home, .out, outBy: pos(6))]))
        // Bottom 2: ground out, line out, strikeout.
        w.pa("", ground("d7", 5, 3))
        w.pa("BB", Play(batterResult: .out, battedBall: .lineDrive, fielders: pos(6), runners: [mv("d8", .home, .out, outBy: pos(6))]))
        w.pa("CF", last: "S")

        // Top 3: single, sacrifice bunt, single (1 run), 6-4-3 double play.
        w.pa("B", hit(.single, "m8", to: 8))
        w.pa("S", Play(batterResult: .sacrificeBunt, battedBall: .bunt, fielders: pos(1, 3),
                       runners: [mv("m8", .first, .second), mv("m9", .home, .out, outBy: pos(1, 3), at: .first)]))
        w.pa("BBF", hit(.single, "m1", to: 7, others: [mv("m8", .second, .scored)], rbi: 1))
        w.pa("", Play(batterResult: .out, battedBall: .groundBall, fielders: pos(6, 4, 3),
                      runners: [mv("m1", .first, .out, outBy: pos(6, 4), at: .second), mv("m2", .home, .out, outBy: pos(4, 3), at: .first)],
                      multiOut: .doublePlay))
        // Bottom 3: fly out, walk, fielder's choice, double (1 run), fly out.
        w.pa("", fly("d1", 9))
        w.pa("BCBB", last: "B")
        w.pa("", Play(batterResult: .fieldersChoice, battedBall: .groundBall, fielders: pos(6, 4),
                      runners: [mv("d2", .first, .out, outBy: pos(6, 4), at: .second), mv("d3", .home, .first)]))
        w.pa("S", hit(.double, "d4", to: 8, others: [mv("d3", .first, .scored)], rbi: 1))
        w.pa("", fly("d5", 7))

        // Top 4: fly out, ground out, called strike three.
        w.pa("", fly("m3", 8))
        w.pa("CB", ground("m4", 6, 3))
        w.pa("SS", last: "C")
        // Bottom 4: fly out, pop-up, unassisted ground out.
        w.pa("", fly("d6", 7))
        w.pa("B", Play(batterResult: .out, battedBall: .popUp, fielders: pos(4), runners: [mv("d7", .home, .out, outBy: pos(4))]))
        w.pa("", ground("d8", 3))

        // Top 5: error, single, sacrifice fly (1 run), walk, then Voss relieves; fly out, ground out.
        w.pa("", Play(batterResult: .reachedOnError, battedBall: .groundBall, fielders: pos(5),
                      runners: [mv("m6", .home, .first, onError: true)], errors: [ErrorCharge(fielder: .thirdBase)]))
        w.pa("B", hit(.single, "m7", to: 9, others: [mv("m6", .first, .third)]))
        w.pa("", Play(batterResult: .sacrificeFly, battedBall: .flyBall, fielders: pos(9),
                      runners: [mv("m8", .home, .out, outBy: pos(9)), mv("m6", .third, .scored)], rbi: 1))
        w.pa("BBB", last: "B")
        w.add(.pitchingChange(PitchingChange(team: .home, newPitcher: "d12")))
        w.pa("", fly("m1", 8))
        w.pa("", ground("m2", 6, 3))
        // Bottom 5: single, two-run home run, ground out, strikeout, fly out.
        w.pa("", hit(.single, "d9", to: 7))
        w.pa("S", hit(.homeRun, "d1", to: 9, others: [mv("d9", .first, .scored)], rbi: 2))
        w.pa("", ground("d2", 4, 3))
        w.pa("BSS", last: "S")
        w.pa("", fly("d4", 9))

        // Top 6: ground out, single, fly out, then Diaz is caught stealing with Park up 1-0.
        w.pa("", ground("m3", 6, 3))
        w.pa("B", hit(.single, "m4", to: 7))
        w.pa("", fly("m5", 8))
        w.pitches("B")
        let caught = w.add(.runnerAction(RunnerAction(moves: [
            mv("m4", .first, .out, outBy: pos(2, 6), at: .second, reason: .caughtStealing),
        ])))
        // Bottom 6: line out, single, 6-4-3 double play.
        w.pa("", Play(batterResult: .out, battedBall: .lineDrive, fielders: pos(5), runners: [mv("d5", .home, .out, outBy: pos(5))]))
        w.pa("BBC", hit(.single, "d6", to: 8))
        w.pa("", Play(batterResult: .out, battedBall: .groundBall, fielders: pos(6, 4, 3),
                      runners: [mv("d6", .first, .out, outBy: pos(6, 4), at: .second), mv("d7", .home, .out, outBy: pos(4, 3), at: .first)],
                      multiOut: .doublePlay))

        // Top 7: Park leads off with a fresh count and doubles; ground out; single (1 run); double play.
        w.pa("C", hit(.double, "m6", to: 7))
        w.pa("", ground("m7", 5, 3, others: [mv("m6", .second, .third)]))
        w.pa("F", hit(.single, "m8", to: 8, others: [mv("m6", .third, .scored)], rbi: 1))
        w.pa("BB", Play(batterResult: .out, battedBall: .groundBall, fielders: pos(6, 4, 3),
                        runners: [mv("m8", .first, .out, outBy: pos(6, 4), at: .second), mv("m9", .home, .out, outBy: pos(4, 3), at: .first)],
                        multiOut: .doublePlay))
        // Bottom 7: fly out, pop-up, fly out. Barros still bats ninth.
        w.pa("", fly("d8", 8))
        w.pa("", Play(batterResult: .out, battedBall: .popUp, fielders: pos(2), runners: [mv("d9", .home, .out, outBy: pos(2))]))
        w.pa("B", fly("d1", 9))

        // Top 8: strikeout, ground out, walk, fly out.
        w.pa("SS", last: "S")
        w.pa("", ground("m2", 4, 3))
        w.pa("BBB", last: "B")
        w.pa("", fly("m4", 7))
        // Bottom 8: single, fly out, double (1 run), two ground outs.
        w.pa("", hit(.single, "d2", to: 7))
        w.pa("", fly("d3", 8))
        w.pa("", hit(.double, "d4", to: 7, others: [mv("d2", .first, .scored)], rbi: 1))
        w.pa("", ground("d5", 5, 3))
        w.pa("", ground("d6", 4, 3))

        // Top 9: home run (1 run), ground out, fly out, strikeout.
        w.pa("", hit(.homeRun, "m5", to: 8, rbi: 1))
        w.pa("", ground("m6", 6, 3))
        w.pa("", fly("m7", 9))
        w.pa("CS", last: "S")
        return (w.game, caught)
    }

    @Test("Final score, line score, runners left on base and pitch counts")
    func finalNumbers() throws {
        let (game, _) = try Self.game()
        let replay = ScorebookRulesEngine().replay(game)
        let s = replay.situation
        let log = replay.log

        #expect(log.entries.allSatisfy { !$0.needsReview })
        #expect(s.score == Score(away: 5, home: 6))

        // Runs by inning, from the play log.
        func lineScore(_ half: HalfInning, innings: Int) -> [Int] {
            (1...innings).map { inning in
                log.entries.filter { $0.inning == inning && $0.half == half }.reduce(0) { $0 + $1.runs.count }
            }
        }
        #expect(lineScore(.top, innings: 9) == [0, 1, 1, 0, 1, 0, 1, 0, 1])
        #expect(lineScore(.bottom, innings: 8) == [2, 0, 1, 0, 2, 0, 0, 1])

        // Runners left on base: the runners still on when each half-inning ended.
        func leftOnBase(_ half: HalfInning) -> Int {
            log.entries.filter { $0.half == half && $0.endsHalfInning }.reduce(0) { $0 + $1.after.runners.count }
        }
        #expect(leftOnBase(.top) == 3)
        #expect(leftOnBase(.bottom) == 3)

        // Pitch counts, counted by hand and by a separate script.
        #expect(s.tally(for: "d9") == PitcherTally(pitcher: "d9", team: .home, pitches: 42, strikes: 30, battersFaced: 18))
        #expect(s.tally(for: "d12") == PitcherTally(pitcher: "d12", team: .home, pitches: 30, strikes: 22, battersFaced: 17))
        #expect(s.tally(for: "m9") == PitcherTally(pitcher: "m9", team: .away, pitches: 62, strikes: 44, battersFaced: 33))

        // The three runs off Barros's runners: the walk in the fifth was Barros's, and the
        // runners Voss inherited were stranded.
        let runsCharged = log.entries.flatMap(\.runs).filter { $0.responsiblePitcher == "d9" }.count
        #expect(runsCharged == 3)
        #expect(log.entries.flatMap(\.runs).filter { $0.responsiblePitcher == "d12" }.count == 2)
    }

    @Test("After the top of the ninth the home team leads, so the app asks; the scorer ends it")
    func endOfGame() throws {
        var (game, _) = try Self.game()
        var s = ScorebookRulesEngine().replay(game).situation
        #expect(s.inning == 9 && s.half == .bottom && s.outs == 0)
        #expect(s.gameOverQuestion == .regulation)
        #expect(!s.isFinal && s.isRegulationComplete)
        #expect(s[.away].nextBatterIndex == 8)
        #expect(s[.home].nextBatterIndex == 6)

        game.events.append(GameEvent(id: "end", enteredAt: game.events.last!.enteredAt.addingTimeInterval(20),
                                     kind: .endOfGame(EndOfGame(reason: .regulation, finalScore: Score(away: 5, home: 6)))))
        s = ScorebookRulesEngine().replay(game).situation
        #expect(s.isFinal && s.gameOverQuestion == nil)
        #expect(s.score == Score(away: 5, home: 6))
    }

    @Test("The sixth inning ends on a caught stealing; Park leads off the seventh with a fresh count")
    func inningEndsOnCaughtStealing() throws {
        let (game, caught) = try Self.game()
        let log = ScorebookRulesEngine().replay(game).log
        let i = try #require(log.entries.firstIndex { $0.event.id == caught })
        let entry = log.entries[i]
        #expect(entry.endsHalfInning)
        #expect(entry.before.count == Count(balls: 1, strikes: 0))
        #expect(entry.batter == "m6")
        #expect(entry.plateAppearance == nil)
        #expect(entry.notation == "CS2 2-6")
        #expect(entry.outs == [OutMade(runner: "m4", putout: "d2", assists: ["d8"], at: .second)])
        #expect(entry.after.runners.isEmpty)

        // The next time the Mudcats bat, Park is up with no balls and no strikes.
        let topSeven = try #require(log.entries.first { $0.inning == 7 && $0.half == .top })
        #expect(topSeven.batter == "m6")
        #expect(topSeven.before.count == .fresh)
    }
}
