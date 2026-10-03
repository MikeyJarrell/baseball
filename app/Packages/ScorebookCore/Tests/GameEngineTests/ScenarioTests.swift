// Runs the rules engine against every scenario file in Tests/Scenarios/: the situation and
// notation each file expects, at every checkpoint and at the end. New scenario files are
// picked up by themselves.
//
// Box score numbers in the scenario files are the stats engine's to check; here the play log
// is checked directly where a scenario's point is about who gets credit (see PlayLogTests).

import Foundation
import Testing
import Model
import GameEngine
import TestSupport

@Suite("Scenario files")
struct ScenarioTests {
    static let engine = ScorebookRulesEngine()

    /// Expected values this engine disagrees with on purpose, by scenario name, with the reason.
    /// Each is written up in plan/handoffs/game-rules-engine.md for the test writer.
    static let knownDisagreements: [String: (mismatch: String, reason: String)] = [
        "hard-walk-off-single-bases-loaded": (
            "situation gameOverQuestion: expected regulation, got nothing",
            "Situation.gameOverQuestion is \"cleared once the game is final\" (Model/Situation.swift), so after the end-of-game event no question is open."
        ),
    ]

    @Test("Every scenario's expected situation and notation", arguments: Scenarios.names())
    func scenario(name: String) throws {
        let scenario = try Scenarios.load(name)
        let replay = Self.engine.replay(scenario.game)
        let known = Self.knownDisagreements[name]?.mismatch
        let problems = (scenario.expected.mismatches(situation: replay.situation)
            + scenario.expected.mismatches(log: replay.log)).filter { $0 != known }
        #expect(problems == [], "\(name)")
    }

    @Test("Every scenario's checkpoints", arguments: Scenarios.names())
    func checkpoints(name: String) throws {
        let scenario = try Scenarios.load(name)
        for checkpoint in scenario.checkpoints ?? [] {
            let replay = Self.engine.replay(scenario.game(upThrough: checkpoint.afterEvent))
            let problems = checkpoint.expected.mismatches(situation: replay.situation)
                + checkpoint.expected.mismatches(log: replay.log)
            #expect(problems == [], "\(name) after \(checkpoint.afterEvent)")
        }
    }

    @Test("Every scenario replays cleanly: one entry per event and nothing flagged for review", arguments: Scenarios.names())
    func cleanReplay(name: String) throws {
        let scenario = try Scenarios.load(name)
        let log = Self.engine.replay(scenario.game).log
        #expect(log.entries.map(\.event) == scenario.events)
        let flagged = log.entries.filter(\.needsReview).map { "\($0.event.id): \($0.reviewNote ?? "")" }
        #expect(flagged == [], "\(name)")
    }

    @Test("The known disagreements are still real, so they are not hiding a fixed scenario")
    func knownDisagreementsStillApply() throws {
        for (name, known) in Self.knownDisagreements {
            guard Scenarios.names().contains(name) else { continue }
            let scenario = try Scenarios.load(name)
            let replay = Self.engine.replay(scenario.game)
            let problems = scenario.expected.mismatches(situation: replay.situation)
            #expect(problems.contains(known.mismatch), "\(name) no longer disagrees; remove it from the list")
        }
    }
}
