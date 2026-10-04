// The runner suggestion asked again after the scorer moves a runner by hand: the runners the
// scorer fixed stay put, and everyone else is placed around them. Also the play-log wording
// the game overview reads: the base a runner was put out at, the base stolen, and the name of
// the break between half-innings.

import Foundation
import Testing
import Model
import GameEngine
import TestSupport

@Suite("Runners suggested again around the scorer's own placements")
struct ResuggestionTests {
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

    /// A single with the scorer's own placements, and those runners fixed.
    func asked(_ result: BatterResult, placing placed: [RunnerMove], in s: Situation) -> RunnerSuggestion {
        let draft = PlayDraft(batterResult: result, runners: placed)
        return engine.suggestRunners(for: draft, in: s, keeping: Set(placed.map(\.runner)))
    }

    @Test("Single, runner on first: sending the batter to second sends the runner from first to third")
    func batterToSecondPushesRunnerFromFirst() throws {
        // Ortiz (m1) on first, Ruiz (m2) batting.
        let s = try situation(ManualAdjustment(runners: BaseOccupants(first: "m1"), batterIndex: 1))
        let suggestion = asked(.single, placing: [mv("m2", .home, .second)], in: s)
        #expect(ends(suggestion) == ["m1": .third, "m2": .second])
        #expect(suggestion.rbi == 0)
    }

    @Test("Single, runners on first and second: the batter to second pushes both runners, and the run is batted in")
    func pushCascadesAndRecountsRunsBattedIn() throws {
        let s = try situation(ManualAdjustment(runners: BaseOccupants(first: "m1", second: "m2"), batterIndex: 2))
        // Before the scorer touches anything: the runner from second to third, from first to second.
        let plain = engine.suggestRunners(for: PlayDraft(batterResult: .single), in: s)
        #expect(ends(plain) == ["m2": .third, "m1": .second, "m3": .first])
        #expect(plain.rbi == 0)
        let suggestion = asked(.single, placing: [mv("m3", .home, .second)], in: s)
        #expect(ends(suggestion) == ["m2": .scored, "m1": .third, "m3": .second])
        #expect(suggestion.rbi == 1)
    }

    @Test("A runner behind who scores takes the runner ahead home too")
    func trailingRunnerScoresPushesLeadHome() throws {
        let s = try situation(ManualAdjustment(runners: BaseOccupants(first: "m1", second: "m2"), batterIndex: 2))
        let suggestion = asked(.single, placing: [mv("m1", .first, .scored)], in: s)
        #expect(ends(suggestion) == ["m2": .scored, "m1": .scored, "m3": .first])
        #expect(suggestion.rbi == 2)
    }

    @Test("Holding the lead runner stops the runners behind short of them")
    func heldLeadRunnerHoldsTheOthers() throws {
        // A double with runners on first and second, and the runner from second held at third.
        let s = try situation(ManualAdjustment(runners: BaseOccupants(first: "m1", second: "m2"), batterIndex: 2))
        let suggestion = asked(.double, placing: [mv("m2", .second, .third)], in: s)
        #expect(ends(suggestion) == ["m2": .third, "m1": .second, "m3": .first])
        #expect(suggestion.rbi == 0)
    }

    @Test("A runner the scorer moved back is not pushed by anyone")
    func fixedRunnersAreNeverMoved() throws {
        // The scorer puts the batter on second and also holds the runner from first at second:
        // both stay put, sharing the base, for the runner step to point out.
        let s = try situation(ManualAdjustment(runners: BaseOccupants(first: "m1"), batterIndex: 1))
        let suggestion = asked(.single, placing: [mv("m2", .home, .second), mv("m1", .first, .second)], in: s)
        #expect(ends(suggestion) == ["m1": .second, "m2": .second])
    }

    @Test("Runners in the draft that are not fixed are suggested again, not kept")
    func unfixedDraftRunnersAreIgnored() throws {
        let s = try situation(ManualAdjustment(runners: BaseOccupants(first: "m1"), batterIndex: 1))
        let draft = PlayDraft(batterResult: .single, runners: [mv("m2", .home, .second), mv("m1", .first, .first)])
        let suggestion = engine.suggestRunners(for: draft, in: s, keeping: ["m2"])
        #expect(ends(suggestion) == ["m1": .third, "m2": .second])
    }

    @Test("An engine with no re-suggestion of its own keeps just the fixed runners")
    func standInEngineDefault() throws {
        let s = try situation(ManualAdjustment(runners: BaseOccupants(first: "m1"), batterIndex: 1))
        let draft = PlayDraft(batterResult: .single, runners: [mv("m2", .home, .second), mv("m1", .first, .second)])
        let suggestion = DoNothingRulesEngine().suggestRunners(for: draft, in: s, keeping: ["m2"])
        #expect(suggestion.runners.map(\.runner) == ["m2"])
    }
}

@Suite("Play-log wording for the game overview")
struct OverviewWordingLogTests {
    let engine = ScorebookRulesEngine()

    @Test("A runner caught stealing or picked off is logged as out at a base even when the scorer named none")
    func outBaseFilledIn() throws {
        var w = try GameWriter.standard()
        w.add(.manualAdjustment(ManualAdjustment(runners: BaseOccupants(first: "m1", third: "m2"), batterIndex: 2)))
        w.add(.runnerAction(RunnerAction(moves: [mv("m1", .first, .out, outBy: pos(2, 6), reason: .caughtStealing)])))
        w.add(.runnerAction(RunnerAction(moves: [mv("m2", .third, .out, outBy: pos(1, 5), reason: .pickoff)])))
        let entries = engine.replay(w.game).log.entries
        #expect(entries[1].outs.first?.at == .second)
        #expect(entries[2].outs.first?.at == .third)
    }

    @Test("A base the scorer named wins over the filled-in one")
    func namedOutBaseKept() throws {
        var w = try GameWriter.standard()
        w.add(.manualAdjustment(ManualAdjustment(runners: BaseOccupants(first: "m1"), batterIndex: 1)))
        w.add(.runnerAction(RunnerAction(moves: [mv("m1", .first, .out, outBy: pos(2, 3), at: .first, reason: .caughtStealing)])))
        #expect(engine.replay(w.game).log.entries[1].outs.first?.at == .first)
    }

    @Test("A steal of home is logged as one")
    func stealOfHome() throws {
        var w = try GameWriter.standard()
        w.add(.manualAdjustment(ManualAdjustment(runners: BaseOccupants(first: "m1", third: "m2"), batterIndex: 2)))
        w.add(.runnerAction(RunnerAction(moves: [mv("m2", .third, .scored, reason: .stolenBase),
                                                 mv("m1", .first, .second, reason: .stolenBase)])))
        let entry = engine.replay(w.game).log.entries[1]
        guard case .runnerAction(let action) = entry.event.kind else {
            Issue.record("expected a runner action")
            return
        }
        #expect(action.moves.map(\.baseStolen) == [.home, .second])
        #expect(action.moves.map(\.isStealOfHome) == [true, false])
        #expect(entry.runs.map(\.runner) == ["m2"])
    }

    @Test("The third out names the break that follows: middle after the top, end after the bottom")
    func breakAfterThirdOut() throws {
        var w = try GameWriter.standard()
        w.add(.manualAdjustment(ManualAdjustment(inning: 3, half: .top, outs: 2, batterIndex: 0)))
        w.pa("", fly("m1", 8))
        var replay = engine.replay(w.game)
        #expect(replay.log.entries.last?.breakAfter == InningBreak(kind: .middle, inning: 3))
        #expect(replay.log.entries.last?.breakAfter?.label == "Middle of the 3rd")
        #expect(replay.situation.inningBreak?.label == "Middle of the 3rd")

        w.add(.manualAdjustment(ManualAdjustment(outs: 2)))
        w.pa("", fly("d1", 8))
        replay = engine.replay(w.game)
        #expect(replay.log.entries.last?.breakAfter?.label == "End of the 3rd")
        #expect(replay.situation.inningBreak == InningBreak(kind: .end, inning: 3))
        #expect(replay.situation.inningBreak?.shortLabel == "End 3rd")
        // A play in the middle of a half-inning names no break.
        #expect(replay.log.entries.first?.breakAfter == nil)
    }
}
