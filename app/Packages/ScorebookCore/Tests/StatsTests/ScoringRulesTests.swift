// The official scoring rules the stats engine follows, each checked on a short play log
// written by hand (see LogBuilder.swift). These are the rules most often gotten wrong:
// what counts as an at-bat, who is charged with a run, a strikeout on a dropped third strike,
// a walk after a mid-count pitching change, a batting hole, runs from a manual adjustment,
// the line score, and the runner for a designated non-runner.
//
// The setups are the shared scenario setups: Mudcats (visitors, m1 to m12) at Diamond Dogs
// (home, d1 to d12). Ray Collins (m9) and Sky Barros (d9) pitch; Gus Reyes (m12) and Taylor
// Voss (d12) are relievers.

import Foundation
import Testing
import Model
import TestSupport
@testable import Stats

@Suite("Scoring rules")
struct ScoringRulesTests {
    let stats = StatsEngine()

    /// The standard setup: Mudcats at Diamond Dogs.
    func standard() throws -> GameSetup { try Scenarios.setup(named: "standard") }

    @Test("Walks, hit-by-pitches, sacrifices and catcher's interference are not at-bats; errors and fielder's choices are")
    func whatCountsAsAnAtBat() throws {
        // Ortiz comes to the plate twelve times, one of each way a plate appearance can end.
        var b = LogBuilder(try standard())
        b.pitch("m1", .ball, result: .walk, rbi: 1, scored: [], after: [b.on("m1", .first)])
        b.record(.intentionalWalk(IntentionalWalk()), batter: "m1", result: .intentionalWalk, after: [b.on("m1", .first)])
        b.pitch("m1", .hitByPitch, result: .hitByPitch, after: [b.on("m1", .first)])
        b.play("m1", .sacrificeFly, rbi: 1, outs: [b.out("m1", by: [.centerField])])
        b.play("m1", .sacrificeBunt, outs: [b.out("m1", by: [.pitcher, .firstBase])])
        b.play("m1", .catchersInterference, after: [b.on("m1", .first)])
        b.play("m1", .reachedOnError, errors: [b.error(.shortstop)], after: [b.on("m1", .first)])
        b.play("m1", .fieldersChoice, after: [b.on("m1", .first)])
        b.play("m1", .single, after: [b.on("m1", .first)])
        b.play("m1", .double, after: [b.on("m1", .second)])
        b.play("m1", .triple, after: [b.on("m1", .third)])
        b.play("m1", .homeRun, rbi: 1, scored: ["m1"], after: [])
        let box = stats.boxScore(for: b.log())
        let ortiz = try #require(box.batting("m1"))

        #expect(ortiz.plateAppearances == 12)
        // Error, fielder's choice, single, double, triple, home run.
        #expect(ortiz.atBats == 6)
        #expect(ortiz.hits == 4)
        #expect(ortiz.doubles == 1 && ortiz.triples == 1 && ortiz.homeRuns == 1)
        #expect(ortiz.walks == 2)
        #expect(ortiz.hitByPitch == 1 && ortiz.sacrificeFlies == 1 && ortiz.sacrificeBunts == 1)
        // The bases-loaded walk, the sacrifice fly and the home run: the scorer's numbers.
        #expect(ortiz.runsBattedIn == 3)

        // Worked out by hand: 4 hits in 6 at-bats is .667. On base 7 times (4 hits, 2 walks,
        // 1 hit by pitch) in 10 chances (6 at-bats, 2 walks, 1 hit by pitch, 1 sacrifice fly)
        // is .700. Total bases 1 + 2 + 3 + 4 = 10 in 6 at-bats is 1.667.
        #expect(formattedRate(ortiz.battingAverage) == ".667")
        #expect(formattedRate(ortiz.onBasePercentage) == ".700")
        #expect(formattedRate(ortiz.sluggingPercentage) == "1.667")

        // Barros: twelve batters, a hit for each of the four hits, and both walks.
        let barros = try #require(box.pitching("d9"))
        #expect(barros.battersFaced == 12 && barros.hits == 4 && barros.walks == 2 && barros.hitBatters == 1)
        #expect(barros.homeRuns == 1 && barros.runs == 1)
        // The shortstop's error.
        #expect(box.fielding("d2")?.stats.errors == 1)
        #expect(box.home.errors == 1)
        #expect(box.notes.errors.map(\.player) == ["d2"])
    }

    @Test("A reliever is not charged with the inherited runner who scores")
    func inheritedRunner() throws {
        // Ortiz singles off Barros. Voss relieves; Ruiz doubles Ortiz home.
        var b = LogBuilder(try standard())
        b.play("m1", .single, after: [b.on("m1", .first)])
        b.lineupChange(.pitchingChange(PitchingChange(team: .home, newPitcher: "d12"))) { $0.setFielder(.home, .pitcher, "d12") }
        b.play("m2", .double, rbi: 1, scored: ["m1"], after: [b.on("m2", .second)])
        let box = stats.boxScore(for: b.log(isFinal: false))

        #expect(box.home.pitching.map(\.player) == ["d9", "d12"])
        #expect(box.pitching("d9") == PitchingCounts(battersFaced: 1, hits: 1, runs: 1, pitches: 1, strikes: 1))
        #expect(box.pitching("d12") == PitchingCounts(battersFaced: 1, hits: 1, runs: 0, pitches: 1, strikes: 1))
        #expect(box.pitching("d9")?.inningsPitchedText == "0.0")
        #expect(box.batting("m1")?.runs == 1)
        #expect(box.batting("m2")?.runsBattedIn == 1)
        // Barros pitched and Voss came in during the first.
        #expect(box.fielding("d9")?.appearances == [FieldingAppearance(position: .pitcher, innings: [1])])
        #expect(box.fielding("d12")?.appearances == [FieldingAppearance(position: .pitcher, innings: [1])])
    }

    @Test("A strikeout is a strikeout even when the batter reaches on a dropped third strike")
    func droppedThirdStrike() throws {
        var b = LogBuilder(try standard())
        // Ortiz reaches when the catcher cannot hold strike three: no out, no putout.
        let reached = Play(batterResult: .reachedOnDroppedThirdStrike, fielders: [.catcher],
                           runners: [RunnerMove(runner: "m1", from: .home, to: .first)])
        b.record(.pitch(Pitch(.swingingStrike, droppedThirdStrike: reached)), batter: "m1", pitches: 1, strikes: 1,
                 result: .strikeout, after: [b.on("m1", .first)])
        // Ruiz also swings through strike three; the catcher drops it and throws to first: K 2-3.
        let thrownOut = Play(batterResult: .out, fielders: [.catcher, .firstBase],
                             runners: [RunnerMove(runner: "m2", from: .home, to: .out, outBy: [.catcher, .firstBase], outAt: .first)])
        b.record(.pitch(Pitch(.swingingStrike, droppedThirdStrike: thrownOut)), batter: "m2", pitches: 1, strikes: 1,
                 result: .strikeout, outsMade: [b.out("m2", by: [.catcher, .firstBase], at: .first)],
                 after: [b.on("m1", .second)])
        let box = stats.boxScore(for: b.log(isFinal: false))

        #expect(box.batting("m1") == BattingCounts(plateAppearances: 1, atBats: 1, strikeouts: 1))
        #expect(box.batting("m2") == BattingCounts(plateAppearances: 1, atBats: 1, strikeouts: 1))
        // Two strikeouts for Barros, but only one out recorded.
        #expect(box.pitching("d9")?.strikeouts == 2)
        #expect(box.pitching("d9")?.outsRecorded == 1)
        // The catcher's throw is an assist; the first baseman has the putout.
        #expect(box.fielding("d8")?.stats == FieldingCounts(putouts: 0, assists: 1))
        #expect(box.fielding("d4")?.stats == FieldingCounts(putouts: 1))
    }

    @Test("A walk after a 3-1 pitching change is the first pitcher's; the pitch is the reliever's")
    func walkAfterMidCountPitchingChange() throws {
        var b = LogBuilder(try standard())
        for pitch: PitchResult in [.ball, .ball, .calledStrike, .ball] { b.takePitch("m1", pitch) }
        b.lineupChange(.pitchingChange(PitchingChange(team: .home, newPitcher: "d12"))) { $0.setFielder(.home, .pitcher, "d12") }
        // Ball four from Voss. The play log charges the batter to Barros (rule 9.16(h)).
        b.record(.pitch(Pitch(.ball)), batter: "m1", pitches: 1, strikes: 0, result: .walk, chargedTo: "d9",
                 after: [BaseRunner(runner: "m1", base: .first, responsiblePitcher: "d9")])
        let box = stats.boxScore(for: b.log(isFinal: false))

        #expect(box.pitching("d9") == PitchingCounts(battersFaced: 1, walks: 1, pitches: 4, strikes: 1))
        #expect(box.pitching("d12") == PitchingCounts(battersFaced: 0, walks: 0, pitches: 1, strikes: 0))
    }

    @Test("A batting hole's automatic out is nobody's plate appearance and no fielder's putout")
    func battingHole() throws {
        var b = LogBuilder(try standard())
        b.play("m1", .single, after: [b.on("m1", .first)])
        b.record(.battingHole(BattingHole(team: .away, spotIndex: 1)))
        b.record(.automaticOut(AutomaticOut(team: .away, spotIndex: 1)),
                 outsMade: [OutMade(runner: "m2", putout: nil)])
        let box = stats.boxScore(for: b.log(isFinal: false))

        // Ruiz still has a line in the second spot, with nothing on it.
        #expect(box.batting("m2") == BattingCounts())
        #expect(box.away.batting.first { $0.player == "m2" }?.batterIndex == 1)
        // The out counts toward Barros's innings; Barros faced only Ortiz.
        #expect(box.pitching("d9")?.outsRecorded == 1)
        #expect(box.pitching("d9")?.battersFaced == 1)
        // Nobody on the field is credited with it.
        #expect((box.home.fielding).allSatisfy { $0.stats == FieldingCounts() })
        #expect(box.notes.doublePlays.isEmpty)
    }

    @Test("Runs from a manual adjustment count for the team and the line score, but for no player or pitcher")
    func manualAdjustmentRuns() throws {
        var b = LogBuilder(try standard())
        b.play("m1", .single, after: [b.on("m1", .first)])
        // The scorer sets one out, the Mudcats up 2-0, and Ortiz on second.
        b.adjust(toInning: 1, .top, outs: 1, runners: [BaseRunner(runner: "m1", base: .second)], addingRuns: Score(away: 2))
        b.takePitch("m2", .ball)
        let box = stats.boxScore(for: b.log(isFinal: false))

        #expect(box.away.runs == 2)
        #expect(box.away.hits == 1)
        #expect(box.batting("m1")?.runs == 0)
        #expect(box.pitching("d9")?.runs == 0)
        // The Diamond Dogs have not batted in the first yet: an empty cell ("x").
        #expect(box.lineScore == LineScore(away: [2], home: [nil]))
    }

    @Test("A walk-off: only the winning run, runners left on base, and runs from the adjustment in the ninth")
    func walkOff() throws {
        var b = LogBuilder(try standard())
        // Bottom of the ninth, tied 3-3 by a manual adjustment, one out, bases loaded.
        b.adjust(toInning: 9, .bottom, outs: 1,
                 runners: [BaseRunner(runner: "d4", base: .first), BaseRunner(runner: "d3", base: .second),
                           BaseRunner(runner: "d2", base: .third)],
                 addingRuns: Score(away: 3, home: 3))
        b.takePitch("d5", .ball)
        b.play("d5", .single, rbi: 1, scored: ["d2"],
               after: [b.on("d5", .first), b.on("d4", .second), b.on("d3", .third)])
        b.endGame()
        let box = stats.boxScore(for: b.log())

        #expect(box.lineScore.away == [0, 0, 0, 0, 0, 0, 0, 0, 3])
        #expect(box.lineScore.home == [0, 0, 0, 0, 0, 0, 0, 0, 4])
        #expect(box.away.runs == 3 && box.home.runs == 4)
        #expect(box.batting("d5") == BattingCounts(plateAppearances: 1, atBats: 1, hits: 1, runsBattedIn: 1))
        #expect(box.batting("d2")?.runs == 1)
        // The runs from the adjustment belong to nobody: Collins is charged only with Tate's.
        #expect(box.pitching("m9")?.runs == 1)
        // The three runners still on base when the game ended were left on base.
        #expect(box.home.leftOnBase == 3)
        #expect(box.notes.leftOnBase == [TeamTally(team: .away, name: "Mudcats", count: 0),
                                         TeamTally(team: .home, name: "Diamond Dogs", count: 3)])
    }

    @Test("The home team that leads after the top of the last inning does not bat: an empty cell")
    func homeTeamDoesNotBat() throws {
        var b = LogBuilder(try standard())
        for batter: PlayerID in ["m1", "m2", "m3"] { b.quickOut(batter, [.shortstop, .firstBase]) }
        b.play("d1", .homeRun, rbi: 1, scored: ["d1"], after: [])
        for batter: PlayerID in ["d2", "d3", "d4"] { b.quickOut(batter, [.leftField]) }
        for batter: PlayerID in ["m4", "m5", "m6"] { b.quickOut(batter, [.centerField]) }
        // After the third out of the top of the second, the game is called.
        b.endGame(.called)
        let box = stats.boxScore(for: b.log())

        #expect(box.lineScore == LineScore(away: [0, 0], home: [1, nil]))
        #expect(box.home.leftOnBase == 0 && box.away.leftOnBase == 0)
        // Nobody fielded in an inning that was never played: the game ended in the bottom of
        // the second before a pitch, so the Mudcats' fielders played only the first.
        #expect(box.fielding("m1")?.appearances == [FieldingAppearance(position: .centerField, innings: [1])])
        #expect(box.fielding("d1")?.appearances == [FieldingAppearance(position: .secondBase, innings: [1, 2])])
    }

    @Test("A triple play is one triple play and no double play, with each fielder's part")
    func triplePlay() throws {
        var b = LogBuilder(try standard())
        b.play("m1", .single, after: [b.on("m1", .first)])
        b.play("m2", .single, after: [b.on("m2", .first), b.on("m1", .second)])
        // Hale grounds to third: third base steps on the bag, throws to second, on to first.
        b.play("m3", .out, outs: [b.out("m1", by: [.thirdBase], at: .third),
                                  b.out("m2", by: [.thirdBase, .secondBase], at: .second),
                                  b.out("m3", by: [.secondBase, .firstBase], at: .first)],
               after: [], multiOut: .triplePlay)
        let box = stats.boxScore(for: b.log(isFinal: false))

        #expect(box.notes.triplePlays == [TeamTally(team: .home, name: "Diamond Dogs", count: 1)])
        #expect(box.notes.doublePlays.isEmpty)
        #expect(box.fielding("d5")?.stats == FieldingCounts(putouts: 1, assists: 1))
        #expect(box.fielding("d1")?.stats == FieldingCounts(putouts: 1, assists: 1))
        #expect(box.fielding("d4")?.stats == FieldingCounts(putouts: 1))
        #expect(box.pitching("d9")?.outsRecorded == 3)
        #expect(box.away.leftOnBase == 0)
        // A ground-ball triple play is no run batted in and no hit.
        #expect(box.batting("m3") == BattingCounts(plateAppearances: 1, atBats: 1))
    }

    @Test("A fielder gets one assist per out, even after handling the ball twice in a rundown")
    func rundownAssists() throws {
        var b = LogBuilder(try standard())
        b.play("m1", .single, after: [b.on("m1", .first)])
        // Ortiz is caught off first: pitcher to first, back to the pitcher, to second for the tag.
        b.runnerAction([RunnerMove(runner: "m1", from: .first, to: .out, reason: .pickoff,
                                   outBy: [.pitcher, .firstBase, .pitcher, .secondBase], outAt: .second)],
                       batter: "m2", outs: [b.out("m1", by: [.pitcher, .firstBase, .pitcher, .secondBase], at: .second)],
                       after: [])
        let box = stats.boxScore(for: b.log(isFinal: false))
        #expect(box.fielding("d9")?.stats == FieldingCounts(assists: 1))
        #expect(box.fielding("d4")?.stats == FieldingCounts(assists: 1))
        #expect(box.fielding("d1")?.stats == FieldingCounts(putouts: 1))
        // A pickoff is not caught stealing.
        #expect(box.batting("m1")?.caughtStealing == 0)
    }

    @Test("A pitcher who comes back keeps one line, in the order they first pitched")
    func pitcherReturns() throws {
        var b = LogBuilder(try standard())
        b.quickOut("m1", [.shortstop, .firstBase])
        b.lineupChange(.pitchingChange(PitchingChange(team: .home, newPitcher: "d12"))) { $0.setFielder(.home, .pitcher, "d12") }
        b.quickOut("m2", [.leftField])
        b.lineupChange(.pitchingChange(PitchingChange(team: .home, newPitcher: "d9"))) { $0.setFielder(.home, .pitcher, "d9") }
        b.quickOut("m3", [.centerField])
        let box = stats.boxScore(for: b.log(isFinal: false))

        #expect(box.home.pitching.map(\.player) == ["d9", "d12"])
        #expect(box.pitching("d9")?.outsRecorded == 2)
        #expect(box.pitching("d12")?.outsRecorded == 1)
        #expect(box.pitching("d9")?.inningsPitchedText == "0.2")
    }

    @Test("A pinch hitter is listed under the player they replaced, as \"ph\" and then where they fielded")
    func pinchHitterPositions() throws {
        var b = LogBuilder(try standard())
        for batter: PlayerID in ["m1", "m2", "m3"] { b.quickOut(batter, [.shortstop, .firstBase]) }
        for batter: PlayerID in ["d1", "d2", "d3"] { b.quickOut(batter, [.leftField]) }
        // Top of the second: Moss bats for Diaz, then takes left field in the bottom half.
        b.lineupChange(.substitution(Substitution(team: .away, batting: [
            BattingChange(kind: .pinchHitter, incoming: "m10", replacing: "m4"),
        ]))) { $0.putInSlot(.away, 3, "m10") }
        b.quickOut("m10", [.secondBase, .firstBase])
        b.quickOut("m5", [.rightField])
        b.quickOut("m6", [.rightField])
        b.lineupChange(.substitution(Substitution(team: .away, defense: [FielderAssignment(position: .leftField, player: "m10")]))) {
            $0.setFielder(.away, .leftField, "m10")
        }
        b.quickOut("d4", [.leftField])
        let box = stats.boxScore(for: b.log(isFinal: false))

        let order = box.away.batting.map(\.player)
        #expect(order.firstIndex(of: "m10") == order.firstIndex(of: "m4")! + 1)
        let moss = try #require(box.away.batting.first { $0.player == "m10" })
        #expect(moss.positions == [.ph, .lf])
        #expect(moss.isSubstitute && moss.batterIndex == 3)
        #expect(box.away.batting.first { $0.player == "m4" }?.positions == [.lf])
        #expect(box.away.batting.first { $0.player == "m4" }?.isSubstitute == false)
        #expect(box.fielding("m4")?.appearances == [FieldingAppearance(position: .leftField, innings: [1])])
        #expect(box.fielding("m10")?.appearances == [FieldingAppearance(position: .leftField, innings: [2])])
        // Moss's putout is his; Diaz's is Diaz's.
        #expect(box.fielding("m4")?.stats.putouts == 3)
        #expect(box.fielding("m10")?.stats.putouts == 1)
    }

    @Test("Someone with no batting spot who runs for a designated non-runner gets a \"pr\" line; the run is the non-runner's")
    func runnerForNonRunnerWithoutBattingSpot() throws {
        // Moreno (d1) is a designated non-runner. The scorer picks Nash (d11), who is on the
        // bench, to run. Nash steals second and scores on Tate's single.
        var b = LogBuilder(try Scenarios.setup(named: "designated-non-runner"))
        for batter: PlayerID in ["m1", "m2", "m3"] { b.quickOut(batter, [.centerField]) }
        b.play("d1", .single, after: [b.on("d1", .first)])
        b.runnerForNonRunner("d11", replacing: "d1")
        b.takePitch("d2", .ball)
        b.runnerAction([RunnerMove(runner: "d11", from: .first, to: .second, reason: .stolenBase)],
                       batter: "d2", after: [b.on("d11", .second)])
        b.play("d2", .single, rbi: 1, scored: ["d11"], after: [b.on("d2", .first)])
        let box = stats.boxScore(for: b.log(isFinal: false))

        let lines = box.home.batting
        #expect(lines.map(\.player).prefix(3) == ["d1", "d11", "d2"])
        let nash = lines[1]
        #expect(nash.positions == [.pr])
        #expect(nash.batterIndex == 0 && nash.isSubstitute)
        #expect(nash.stats == BattingCounts(stolenBases: 1))
        #expect(lines[0].stats == BattingCounts(plateAppearances: 1, atBats: 1, runs: 1, hits: 1))
        #expect(box.notes.stolenBases.map(\.name) == ["Robin Nash"])
        // The run is still charged to Collins, who put Moreno on base.
        #expect(box.pitching("m9")?.runs == 1)
    }

    @Test("An empty play log gives an empty box score with the right team names")
    func emptyGame() throws {
        let box = stats.boxScore(for: LogBuilder(try standard()).log(isFinal: false))
        #expect(box.lineScore == LineScore(away: [], home: []))
        #expect(box.away.name == "Mudcats" && box.home.name == "Diamond Dogs")
        // Every starter still has a batting line with nothing on it.
        #expect(box.home.batting.count == 9 && box.home.battingTotals == BattingCounts())
        #expect(box.home.pitching.isEmpty && box.home.fielding.isEmpty)
    }
}
