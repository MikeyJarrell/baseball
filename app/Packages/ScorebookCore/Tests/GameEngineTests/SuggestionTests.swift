// Suggested runner outcomes and runs batted in for the in-play screen, the play preview, and
// suggested runner moves between pitches. Every case in the brief's list is here.

import Foundation
import Testing
import Model
import GameEngine
import TestSupport

@Suite("Suggestions and the play preview")
struct SuggestionTests {
    let engine = ScorebookRulesEngine()

    /// The situation after one manual adjustment of the standard game: the Mudcats batting in
    /// the top of the first unless the adjustment says otherwise.
    func situation(_ adjustment: ManualAdjustment) throws -> Situation {
        var w = try GameWriter.standard()
        w.add(.manualAdjustment(adjustment))
        return engine.replay(w.game).situation
    }

    /// Where each runner ends up in a suggestion, by player.
    func ends(_ suggestion: RunnerSuggestion) -> [PlayerID: RunnerEnd] {
        Dictionary(uniqueKeysWithValues: suggestion.runners.map { ($0.runner, $0.to) })
    }

    @Test("Hits: every runner moves up as many bases as the batter; a home run scores everyone")
    func hits() throws {
        // Ortiz on first, Ruiz on second, Hale batting.
        let s = try situation(ManualAdjustment(runners: BaseOccupants(first: "m1", second: "m2"), batterIndex: 2))
        let single = engine.suggestRunners(for: PlayDraft(batterResult: .single), in: s)
        #expect(ends(single) == ["m2": .third, "m1": .second, "m3": .first])
        #expect(single.rbi == 0)
        let double = engine.suggestRunners(for: PlayDraft(batterResult: .double), in: s)
        #expect(ends(double) == ["m2": .scored, "m1": .third, "m3": .second])
        #expect(double.rbi == 1)
        let triple = engine.suggestRunners(for: PlayDraft(batterResult: .triple), in: s)
        #expect(ends(triple) == ["m2": .scored, "m1": .scored, "m3": .third])
        #expect(triple.rbi == 2)
        let homer = engine.suggestRunners(for: PlayDraft(batterResult: .homeRun), in: s)
        #expect(ends(homer) == ["m2": .scored, "m1": .scored, "m3": .scored])
        #expect(homer.rbi == 3)
    }

    @Test("Ground-ball double play: the runner from first out at second, the batter at first, no run batted in")
    func groundDoublePlay() throws {
        // Runners on first and third, nobody out.
        let s = try situation(ManualAdjustment(runners: BaseOccupants(first: "m1", third: "m2"), batterIndex: 2))
        let marked = engine.suggestRunners(for: PlayDraft(batterResult: .out, battedBall: .groundBall, fielders: pos(6, 4, 3), multiOut: .doublePlay), in: s)
        let runner = try #require(marked.runners.first { $0.runner == "m1" })
        #expect(runner.to == .out && runner.outAt == .second && runner.outBy == pos(6, 4))
        let batter = try #require(marked.runners.first { $0.isBatter })
        #expect(batter.to == .out && batter.outAt == .first && batter.outBy == pos(4, 3))
        // The runner on third is not forced and holds.
        #expect(ends(marked)["m2"] == .third)
        #expect(marked.rbi == 0)

        // Three fielders with a runner on first counts as a double play even if not marked.
        let unmarked = engine.suggestRunners(for: PlayDraft(batterResult: .out, battedBall: .groundBall, fielders: pos(5, 4, 3)), in: s)
        #expect(ends(unmarked)["m1"] == .out)
        #expect(unmarked.runners.first { $0.runner == "m1" }?.outBy == pos(5, 4))
    }

    @Test("Ground out otherwise: forced runners move up one, the rest hold, the batter is out")
    func groundOut() throws {
        let s = try situation(ManualAdjustment(runners: BaseOccupants(first: "m1", third: "m2"), batterIndex: 2))
        let out = engine.suggestRunners(for: PlayDraft(batterResult: .out, battedBall: .groundBall, fielders: pos(6, 3)), in: s)
        #expect(ends(out) == ["m2": .third, "m1": .second, "m3": .out])
        #expect(out.runners.first { $0.isBatter }?.outBy == pos(6, 3))
    }

    @Test("Fly out: runners hold. Sacrifice fly: the runner on third scores, one run batted in")
    func flyBalls() throws {
        let s = try situation(ManualAdjustment(runners: BaseOccupants(second: "m1", third: "m2"), batterIndex: 2))
        let fly = engine.suggestRunners(for: PlayDraft(batterResult: .out, battedBall: .flyBall, fielders: pos(8)), in: s)
        #expect(ends(fly) == ["m2": .third, "m1": .second, "m3": .out])
        let sacFly = engine.suggestRunners(for: PlayDraft(batterResult: .sacrificeFly, battedBall: .flyBall, fielders: pos(8)), in: s)
        #expect(ends(sacFly) == ["m2": .scored, "m1": .second, "m3": .out])
        #expect(sacFly.rbi == 1)
        // A line drive double play doubles the lead runner off their base.
        let lineDP = engine.suggestRunners(for: PlayDraft(batterResult: .out, battedBall: .lineDrive, fielders: pos(5), multiOut: .doublePlay), in: s)
        #expect(ends(lineDP) == ["m2": .out, "m1": .second, "m3": .out])
    }

    @Test("Fielder's choice: the lead forced runner is out, the batter is on first")
    func fieldersChoice() throws {
        let s = try situation(ManualAdjustment(runners: BaseOccupants(first: "m1", second: "m2"), batterIndex: 2))
        let fc = engine.suggestRunners(for: PlayDraft(batterResult: .fieldersChoice, battedBall: .groundBall, fielders: pos(5)), in: s)
        #expect(ends(fc) == ["m2": .out, "m1": .second, "m3": .first])
        #expect(fc.runners.first { $0.runner == "m2" }?.outAt == .third)
    }

    @Test("Error: batter safe at first on the error, runners up one, no run batted in")
    func error() throws {
        let s = try situation(ManualAdjustment(runners: BaseOccupants(first: "m1", third: "m2"), batterIndex: 2))
        let e = engine.suggestRunners(for: PlayDraft(batterResult: .reachedOnError, fielders: pos(6), errors: [ErrorCharge(fielder: .shortstop)]), in: s)
        #expect(ends(e) == ["m2": .scored, "m1": .second, "m3": .first])
        #expect(e.runners.first { $0.isBatter }?.advancedOnError == true)
        #expect(e.rbi == 0)
    }

    @Test("Walk-like results push only forced runners; a sacrifice bunt moves the runners up")
    func forcedOnly() throws {
        let s = try situation(ManualAdjustment(runners: BaseOccupants(first: "m1", third: "m2"), batterIndex: 2))
        let ci = engine.suggestRunners(for: PlayDraft(batterResult: .catchersInterference), in: s)
        #expect(ends(ci) == ["m2": .third, "m1": .second, "m3": .first])
        let bunt = engine.suggestRunners(for: PlayDraft(batterResult: .sacrificeBunt, battedBall: .bunt, fielders: pos(1, 3)), in: s)
        #expect(ends(bunt) == ["m2": .third, "m1": .second, "m3": .out])
    }

    @Test("A play that makes the third out: nobody else moves and no run is suggested")
    func thirdOut() throws {
        let s = try situation(ManualAdjustment(outs: 2, runners: BaseOccupants(first: "m1", third: "m2"), batterIndex: 2))
        let out = engine.suggestRunners(for: PlayDraft(batterResult: .out, battedBall: .groundBall, fielders: pos(6, 3)), in: s)
        #expect(ends(out) == ["m2": .third, "m1": .first, "m3": .out])
        #expect(out.rbi == 0)
        let preview = engine.preview(PlayDraft(batterResult: .out, battedBall: .groundBall, fielders: pos(6, 3)), in: s)
        #expect(preview.endsHalfInning && preview.outsAfter == 3 && preview.runsOnPlay == 0)
    }

    @Test("A game-ending hit: only the winning run scores, and nobody moves further than that runner")
    func walkOff() throws {
        // Bottom of the ninth, tied, bases loaded: a single scores one.
        let loaded = try situation(ManualAdjustment(inning: 9, half: .bottom, score: Score(away: 3, home: 3),
                                                    runners: BaseOccupants(first: "d4", second: "d3", third: "d2"), batterIndex: 4))
        let single = engine.suggestRunners(for: PlayDraft(batterResult: .single), in: loaded)
        #expect(ends(single) == ["d2": .scored, "d3": .third, "d4": .second, "d5": .first])
        #expect(single.rbi == 1)
        let double = engine.suggestRunners(for: PlayDraft(batterResult: .double), in: loaded)
        #expect(ends(double) == ["d2": .scored, "d3": .third, "d4": .second, "d5": .first])
        // A home run still scores everyone.
        let homer = engine.suggestRunners(for: PlayDraft(batterResult: .homeRun), in: loaded)
        #expect(homer.rbi == 4)

        // Down one with the bases loaded, a triple: the winning run is the runner from second,
        // two bases, so the runner from first stops at third and the batter at second.
        let downOne = try situation(ManualAdjustment(inning: 9, half: .bottom, score: Score(away: 4, home: 3),
                                                     runners: BaseOccupants(first: "d4", second: "d3", third: "d2"), batterIndex: 4))
        let triple = engine.suggestRunners(for: PlayDraft(batterResult: .triple), in: downOne)
        #expect(ends(triple) == ["d2": .scored, "d3": .scored, "d4": .third, "d5": .second])
        #expect(triple.rbi == 2)
        #expect(engine.preview(PlayDraft(batterResult: .triple), in: downOne).endsGame)

        // Not in the last inning: the ordinary suggestion.
        let seventh = try situation(ManualAdjustment(inning: 7, half: .bottom, score: Score(away: 3, home: 3),
                                                     runners: BaseOccupants(first: "d4", second: "d3", third: "d2"), batterIndex: 4))
        let ordinary = engine.suggestRunners(for: PlayDraft(batterResult: .double), in: seventh)
        #expect(ends(ordinary) == ["d2": .scored, "d3": .scored, "d4": .third, "d5": .second])
        #expect(!engine.preview(PlayDraft(batterResult: .double), in: seventh).endsGame)
    }

    @Test("The scorer's own runner moves win; a batter who takes an extra base on an error keeps the hit")
    func scorerMoves() throws {
        let s = try situation(ManualAdjustment(runners: BaseOccupants(second: "m1"), batterIndex: 1))
        // The scorer sends Ortiz home from second on the single.
        var draft = PlayDraft(batterResult: .single, hitLocation: .leftField, runners: [mv("m1", .second, .scored)])
        let suggestion = engine.suggestRunners(for: draft, in: s)
        #expect(ends(suggestion) == ["m1": .scored, "m2": .first])
        #expect(suggestion.rbi == 1)
        // Then the batter takes second on the left fielder's throwing error.
        draft.runners.append(mv("m2", .home, .second, onError: true))
        draft.errors = [ErrorCharge(fielder: .leftField, type: .throwing)]
        let preview = engine.preview(draft, in: s)
        #expect(preview.notation == "1B 7, E7")
        #expect(preview.runsOnPlay == 1 && preview.outsOnPlay == 0)
        let play = try #require(draft.finishedPlay(suggestedRBI: engine.suggestRunners(for: draft, in: s).rbi))
        #expect(play.batterResult == .single && play.rbi == 1)
    }

    @Test("Preview: the notation builds up as fielders are tapped")
    func previewNotation() throws {
        let s = try situation(ManualAdjustment(outs: 1, runners: BaseOccupants(first: "m1"), batterIndex: 2))
        #expect(engine.preview(PlayDraft(fielders: pos(6)), in: s).notation == "6")
        #expect(engine.preview(PlayDraft(fielders: pos(6, 4)), in: s).notation == "6-4")
        let dp = engine.preview(PlayDraft(batterResult: .out, battedBall: .groundBall, fielders: pos(6, 4, 3), multiOut: .doublePlay), in: s)
        #expect(dp.notation == "6-4-3 DP")
        #expect(dp.outsOnPlay == 2 && dp.outsAfter == 3 && dp.endsHalfInning && !dp.endsGame)
        let fly = engine.preview(PlayDraft(batterResult: .out, battedBall: .flyBall, fielders: pos(8)), in: s)
        #expect(fly.notation == "F8" && fly.outsAfter == 2 && !fly.endsHalfInning)
        let k = engine.preview(PlayDraft(context: .droppedThirdStrike, batterResult: .out, fielders: pos(2, 3)), in: s)
        #expect(k.notation == "K 2-3")
    }

    @Test("Runner moves between pitches: steals, caught stealing, pickoffs, and a wild pitch that moves everyone")
    func runnerActions() throws {
        let s = try situation(ManualAdjustment(runners: BaseOccupants(first: "m1", second: "m2"), batterIndex: 2))
        let doubleSteal = engine.suggestRunnerAction(.stolenBase, runners: ["m1", "m2"], in: s)
        #expect(doubleSteal == [
            RunnerMove(runner: "m2", from: .second, to: .third, reason: .stolenBase),
            RunnerMove(runner: "m1", from: .first, to: .second, reason: .stolenBase),
        ])
        #expect(engine.suggestRunnerAction(.caughtStealing, runners: ["m1"], in: s)
            == [RunnerMove(runner: "m1", from: .first, to: .out, reason: .caughtStealing, outAt: .second)])
        #expect(engine.suggestRunnerAction(.pickoff, runners: ["m2"], in: s)
            == [RunnerMove(runner: "m2", from: .second, to: .out, reason: .pickoff, outAt: .second)])
        // A wild pitch moves every runner, whoever the sheet passed.
        let wild = engine.suggestRunnerAction(.wildPitch, runners: [], in: s)
        #expect(wild.map(\.to) == [.third, .second])
        let balk = engine.suggestRunnerAction(.balk, runners: ["m1"], in: s)
        #expect(balk.count == 2)
    }

    @Test("Who runs for a designated non-runner, asked of the engine directly")
    func suggestedRunner() throws {
        let scenario = try Scenarios.load("designated-non-runner-last-out-now-batting")
        let replay = engine.replay(scenario.game(upThrough: "e9"))
        #expect(engine.suggestedRunner(for: "d1", in: replay.log, situation: replay.situation) == "d3")
        #expect(replay.situation.runnerChoice == RunnerChoice(nonRunner: "d1", suggestedRunner: "d3"))
    }
}
