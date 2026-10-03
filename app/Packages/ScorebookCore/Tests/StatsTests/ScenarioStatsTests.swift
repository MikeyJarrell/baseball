// The stats engine against every scenario file that has stats expectations.
//
// Each scenario is a short game with the right answers worked out by hand. The rules engine
// replays its events into a play log, the stats engine turns the play log into a box score,
// and the box score is checked against the scenario's expected batting, pitching, fielding
// and team numbers, at the end and at any checkpoint along the way.
//
// These tests need the rules engine. Until it lands they are skipped, not failed; see
// ScenarioEngine.swift for the one line that switches them on.

import Foundation
import Testing
import Model
import SampleData
import TestSupport
@testable import Stats

@Suite("Scenario stats")
struct ScenarioStatsTests {
    let stats = StatsEngine()

    /// The scenarios with something for the stats engine to check: batting, pitching,
    /// fielding or team numbers, at the end or at a checkpoint.
    static let statsScenarioNames: [String] = {
        let all = (try? Scenarios.loadAll()) ?? []
        return all.filter { scenario in
            ([scenario.expected] + (scenario.checkpoints ?? []).map(\.expected)).contains { $0.checksStats }
        }.map(\.name)
    }()

    @Test("The scenarios with stats expectations are all found")
    func scenariosFound() {
        // Twenty-seven files had stats expectations when this test was written. Finding none
        // would mean the scenario tests below pass without checking anything.
        #expect(Self.statsScenarioNames.count >= 27)
        #expect(Self.statsScenarioNames.contains("hard-inherited-runner-scores"))
        #expect(Self.statsScenarioNames.contains("hard-runner-for-non-runner-scores"))
    }

    @Test("Each scenario's box score matches its expected stats",
          .enabled(if: ScenarioEngine.isReady, ScenarioEngine.notReadyReason),
          arguments: statsScenarioNames)
    func scenario(_ name: String) throws {
        let engine = try #require(ScenarioEngine.engine)
        let scenario = try Scenarios.load(name)

        let box = stats.boxScore(for: engine.replay(scenario.game).log)
        #expect(scenario.expected.mismatches(box: box) == [], "\(name), after the last event")

        for checkpoint in scenario.checkpoints ?? [] where checkpoint.expected.checksStats {
            let soFar = stats.boxScore(for: engine.replay(scenario.game(upThrough: checkpoint.afterEvent)).log)
            #expect(checkpoint.expected.mismatches(box: soFar) == [], "\(name), after \(checkpoint.afterEvent)")
        }
    }

    @Test("Each scenario's batter histories agree with its box score",
          .enabled(if: ScenarioEngine.isReady, ScenarioEngine.notReadyReason),
          arguments: statsScenarioNames)
    func histories(_ name: String) throws {
        let engine = try #require(ScenarioEngine.engine)
        let log = engine.replay(try Scenarios.load(name).game).log
        let box = stats.boxScore(for: log)
        // Every batting line's plate appearances are the ones in that batter's history.
        for line in box.away.batting + box.home.batting {
            let history = stats.plateAppearances(of: line.player, in: log)
            #expect(history.count == line.stats.plateAppearances, "\(name): \(line.name)")
            #expect(history.reduce(0) { $0 + $1.rbi } == line.stats.runsBattedIn, "\(name): \(line.name)")
        }
    }

    @Test("The sample game replayed by the rules engine gives the hand-written box score",
          .enabled(if: ScenarioEngine.isReady, ScenarioEngine.notReadyReason))
    func sampleGameThroughTheEngine() throws {
        let engine = try #require(ScenarioEngine.engine)
        let box = stats.boxScore(for: engine.replay(SampleGame.game).log)
        #expect(boxScoreDifferences(box, SampleGame.boxScore) == [])
    }
}

extension ScenarioExpectation {
    /// True when the expectation has anything for the stats engine to check.
    var checksStats: Bool {
        batting != nil || pitching != nil || fielding != nil || teams != nil
    }
}
