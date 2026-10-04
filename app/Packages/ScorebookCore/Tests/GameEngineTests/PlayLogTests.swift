// The play log: checks that every out, run, error and plate appearance is credited to the
// right player and pitcher. Stats are added up from these entries, so a wrong name here
// would be a wrong box score.

import Foundation
import Testing
import Model
import GameEngine
import TestSupport

@Suite("Who gets credit in the play log")
struct PlayLogTests {
    let engine = ScorebookRulesEngine()

    /// The play log entry for one event of a scenario.
    func entry(_ scenario: String, _ event: EventID) throws -> PlayLogEntry {
        let log = engine.replay(try Scenarios.load(scenario).game).log
        return try #require(log.entries.first { $0.event.id == event })
    }

    @Test("5-4-3 double play: third baseman an assist, second baseman a putout and an assist, first baseman a putout")
    func doublePlayCredit() throws {
        let e = try entry("hard-5-4-3-double-play", "e2")
        #expect(e.outs == [
            OutMade(runner: "m1", putout: "d1", assists: ["d5"], at: .second),
            OutMade(runner: "m2", putout: "d4", assists: ["d1"], at: .first),
        ])
        #expect(e.plateAppearance?.outcome == .out)
        #expect(e.endsHalfInning == false && e.after.outs == 2)
    }

    @Test("Triple play: three outs, each with its own putout")
    func triplePlay() throws {
        let e = try entry("hard-triple-play", "e3")
        #expect(e.outs.map(\.putout) == ["d5", "d1", "d4"])
        #expect(e.endsHalfInning)
        #expect(e.after.outs == 3)
        #expect(e.notation == "5-4-3 TP")
    }

    @Test("The run scored by the runner for a designated non-runner is the non-runner's; the steal is the runner's")
    func runnerForNonRunnerCredit() throws {
        let scenario = try Scenarios.load("hard-runner-for-non-runner-scores")
        let log = engine.replay(scenario.game).log
        let sacFly = try #require(log.entries.first { $0.event.id == "e8" })
        #expect(sacFly.runs == [RunScored(runner: "d9", creditedTo: "d1", responsiblePitcher: "m9")])
        #expect(sacFly.plateAppearance == PlateAppearanceResult(batter: "d2", pitcher: "m9", outcome: .sacrificeFly, rbi: 1, batterReachedBase: false))
        let steal = try #require(log.entries.first { $0.event.id == "e7" })
        #expect(steal.notation == "SB3")
        #expect(steal.batter == "d2" && steal.plateAppearance == nil)
        let swap = try #require(log.entries.first { $0.event.id == "e5" })
        #expect(swap.notation == "R Barros for Moreno")
    }

    @Test("An inherited runner who scores is charged to the pitcher who put them on")
    func inheritedRunner() throws {
        let e = try entry("hard-inherited-runner-scores", "e3")
        #expect(e.runs == [RunScored(runner: "m1", creditedTo: "m1", responsiblePitcher: "d9")])
        #expect(e.pitcher == "d12")
        #expect(e.plateAppearance?.pitcher == "d12")
    }

    @Test("A walk after a pitching change at 3-1 is the earlier pitcher's; the pitch is the new one's (rule 9.16(h))")
    func walkAfterChangeAtThreeOne() throws {
        let e = try entry("hard-pitching-change-at-3-1-then-walk", "e6")
        #expect(e.pitcher == "d12" && e.pitches == 1 && e.strikes == 0)
        #expect(e.plateAppearance == PlateAppearanceResult(batter: "m1", pitcher: "d9", outcome: .walk, rbi: 0, batterReachedBase: true))
        #expect(e.after.runners == [BaseRunner(runner: "m1", base: .first, responsiblePitcher: "d9")])
    }

    @Test("A pitching change at 2-2 does not move the walk; any result but a walk is the new pitcher's")
    func changeAtTwoTwo() throws {
        var w = try GameWriter.standard()
        w.pitches("BBCC")
        w.add(.pitchingChange(PitchingChange(team: .home, newPitcher: "d12")))
        w.pitches("BB")
        let walk = try #require(engine.replay(w.game).log.entries.last)
        #expect(walk.plateAppearance?.pitcher == "d12")

        var v = try GameWriter.standard()
        v.pitches("BBB")
        v.add(.pitchingChange(PitchingChange(team: .home, newPitcher: "d12")))
        v.pa("C", hit(.single, "m1", to: 7))
        let single = try #require(engine.replay(v.game).log.entries.last)
        #expect(single.plateAppearance?.pitcher == "d12")
        #expect(single.after.runners.first?.responsiblePitcher == "d12")
    }

    @Test("A batter who reaches on a fielder's choice that retires an inherited runner is charged to the earlier pitcher (rule 9.16(g))")
    func fieldersChoiceInheritsPitcher() throws {
        var w = try GameWriter.standard()
        w.pa("", hit(.single, "m1", to: 7))
        w.add(.pitchingChange(PitchingChange(team: .home, newPitcher: "d12")))
        w.pa("", Play(batterResult: .fieldersChoice, battedBall: .groundBall, fielders: pos(6, 4),
                      runners: [mv("m1", .first, .out, outBy: pos(6, 4), at: .second), mv("m2", .home, .first)]))
        w.pa("", hit(.homeRun, "m3", to: 7, others: [mv("m2", .first, .scored)], rbi: 2))
        let log = engine.replay(w.game).log
        let fc = log.entries[2]
        #expect(fc.notation == "FC 6-4")
        #expect(fc.after.runners == [BaseRunner(runner: "m2", base: .first, responsiblePitcher: "d9")])
        let homer = log.entries[3]
        #expect(homer.runs == [
            RunScored(runner: "m2", creditedTo: "m2", responsiblePitcher: "d9"),
            RunScored(runner: "m3", creditedTo: "m3", responsiblePitcher: "d12"),
        ])
    }

    @Test("The automatic out at a batting hole: nobody's plate appearance, no putout, the pitcher's out")
    func automaticOut() throws {
        let e = try entry("batting-hole-automatic-out", "e3")
        #expect(e.outs == [OutMade(runner: "m2", putout: nil)])
        #expect(e.plateAppearance == nil)
        #expect(e.pitcher == "d9")
        #expect(e.pitches == 0)
        #expect(e.notation == "Auto out")
    }

    @Test("Errors are tied to the player at the position; an unknown fielder is left blank")
    func errorsTiedToPlayers() throws {
        let steal = try entry("hard-double-steal-throwing-error", "e4")
        #expect(steal.errors == [ChargedError(fielder: .catcher, player: "d8")])
        #expect(steal.runs == [RunScored(runner: "m1", creditedTo: "m1", responsiblePitcher: "d9")])
        #expect(steal.notation == "SB3, SB2, E2")

        let pop = try entry("hard-dropped-foul-pop-error", "e3")
        #expect(pop.errors == [ChargedError(fielder: .firstBase, player: "d4")])
        #expect(pop.notation == "E3")

        // The Riverhawks' shortstop is unknown.
        var w = GameWriter(setup: try Scenarios.setup(named: "unknown-opponent"))
        w.add(.manualAdjustment(ManualAdjustment(half: .bottom)))
        w.pa("", Play(batterResult: .reachedOnError, battedBall: .groundBall, fielders: pos(6),
                      runners: [mv("d1", .home, .first, onError: true)], errors: [ErrorCharge(fielder: .shortstop)]))
        let error = try #require(engine.replay(w.game).log.entries.last)
        #expect(error.errors == [ChargedError(fielder: .shortstop, player: nil)])
        #expect(error.plateAppearance?.pitcher == "rp")
    }

    @Test("Strikeouts: the catcher's putout; on a dropped third strike, the throw's putout or none if the batter reached")
    func strikeouts() throws {
        let k = try entry("hard-foul-tip-strike-three", "e5")
        #expect(k.outs == [OutMade(runner: "m1", putout: "d8")])
        #expect(k.plateAppearance?.outcome == .strikeout)

        let thrownOut = try entry("hard-dropped-third-strike-thrown-out", "e3")
        #expect(thrownOut.outs == [OutMade(runner: "m1", putout: "d4", assists: ["d8"], at: .first)])
        #expect(thrownOut.plateAppearance?.outcome == .strikeout)

        let reached = try entry("hard-dropped-third-strike-batter-reaches", "e4")
        #expect(reached.outs.isEmpty)
        #expect(reached.plateAppearance?.outcome == .strikeout)
        #expect(reached.plateAppearance?.batterReachedBase == true)
    }

    @Test("A bases-loaded walk forces in a run and a run batted in")
    func basesLoadedWalk() throws {
        let e = try entry("hard-bases-loaded-walk", "e16")
        #expect(e.runs == [RunScored(runner: "m1", creditedTo: "m1", responsiblePitcher: "d9")])
        #expect(e.plateAppearance?.rbi == 1)
        #expect(e.plateAppearance?.outcome == .walk)
    }

    @Test("A manual adjustment's runs are reported as adjusted runs, credited to nobody")
    func adjustedRuns() throws {
        let e = try entry("hard-manual-adjustment", "e2")
        #expect(e.adjustedRuns == Score(away: 2, home: 0))
        #expect(e.runs.isEmpty)
    }

    @Test("A walk-off: only the winning run, three runners left on base when the game ends")
    func walkOff() throws {
        let log = engine.replay(try Scenarios.load("hard-walk-off-single-bases-loaded").game).log
        let end = try #require(log.entries.last)
        #expect(end.after.runners.count == 3)
        #expect(end.half == .bottom && end.inning == 9)
        #expect(end.batter == nil)
        #expect(log.isFinal)
    }

    @Test("Notation the scenarios use")
    func notation() throws {
        #expect(try entry("hard-sacrifice-fly-with-throwing-error", "e3").notation == "SF 8, E8")
        #expect(try entry("hard-error-on-fly-ball-batter-to-second", "e1").notation == "E7")
        #expect(try entry("hard-6-3-double-play-shortstop-steps-on-second", "e2").notation == "6-3 DP")
        #expect(try entry("hard-bases-loaded-walk", "e1").notation == "B")
        #expect(try entry("hard-pinch-runner", "e2").notation == "PR Moss for Ortiz")
        #expect(try entry("hard-starter-re-enters", "e1").notation == "PH Moss for Ortiz")
        #expect(try entry("hard-starter-re-enters", "e5").notation == "Ortiz for Moss")
        #expect(try entry("hard-unknown-lineup-cycles", "e1").notation == "IBB")
        #expect(try entry("hard-third-out-on-bases-mid-at-bat", "e6").notation == "CS2 2-6")
        #expect(try entry("hard-pitching-change-at-3-1-then-walk", "e5").notation == "P Voss")
    }
}
