// Tests that every scenario file reads with the shared vocabulary, and that the hard plays
// the foundation job wrote say what they are meant to say.

import Foundation
import Testing
import Model
import SampleData
import TestSupport

@Suite("Scenario files")
struct ScenarioFileTests {
    /// The twenty-two hard plays the vocabulary was tested against.
    static let hardScenarios = [
        "hard-5-4-3-double-play",
        "hard-6-3-double-play-shortstop-steps-on-second",
        "hard-triple-play",
        "hard-bases-loaded-walk",
        "hard-dropped-third-strike-thrown-out",
        "hard-dropped-third-strike-batter-reaches",
        "hard-foul-tip-strike-three",
        "hard-double-steal-throwing-error",
        "hard-dropped-foul-pop-error",
        "hard-pitching-change-at-3-1-then-walk",
        "hard-inherited-runner-scores",
        "hard-runner-for-non-runner-scores",
        "hard-designated-non-runner-singles",
        "hard-pinch-runner",
        "hard-starter-re-enters",
        "hard-third-out-on-bases-mid-at-bat",
        "hard-hitter-added-while-last-hitter-bats",
        "hard-walk-off-single-bases-loaded",
        "hard-manual-adjustment",
        "hard-unknown-lineup-cycles",
        "hard-error-on-fly-ball-batter-to-second",
        "hard-sacrifice-fly-with-throwing-error",
    ]

    @Test("Every scenario file decodes, with a setup and at least one event")
    func everyScenarioDecodes() throws {
        let names = Scenarios.names()
        #expect(names.count >= Self.hardScenarios.count + 1)
        for name in names {
            let scenario = try Scenarios.load(name)
            #expect(scenario.setup != nil, "\(name) has no setup")
            #expect(!scenario.events.isEmpty, "\(name) has no events")
            #expect(!scenario.description.isEmpty, "\(name) has no description")
        }
    }

    @Test("All twenty-two hard plays and the pattern file are there", arguments: hardScenarios + ["pattern-6-3-groundout"])
    func hardScenarioExists(name: String) throws {
        _ = try Scenarios.load(name)
    }

    @Test("Every player a scenario names is on one of the two rosters")
    func scenarioPlayersAreOnRosters() throws {
        for scenario in try Scenarios.loadAll() {
            let setup = try #require(scenario.setup)
            var named: [PlayerID] = []
            for event in scenario.events {
                switch event.kind {
                case .ballInPlay(let play): named += play.runners.map(\.runner)
                case .pitch(let pitch): named += pitch.droppedThirdStrike?.runners.map(\.runner) ?? []
                case .runnerAction(let action): named += action.moves.map(\.runner)
                case .substitution(let sub): named += sub.changes.flatMap { [$0.incoming] + ($0.replacing.map { [$0] } ?? []) }
                case .runnerForNonRunner(let r): named += [r.runner, r.replacing]
                case .pitchingChange(let change): named.append(change.newPitcher)
                case .addHitter(let add): named.append(add.player)
                default: break
                }
            }
            for id in named {
                #expect(setup.player(id) != nil, "\(scenario.name): \(id) is not on either roster")
            }
        }
    }

    @Test("Every event in a scenario has a unique id")
    func eventIDsAreUnique() throws {
        for scenario in try Scenarios.loadAll() {
            let ids = scenario.events.map(\.id)
            #expect(Set(ids).count == ids.count, "\(scenario.name) repeats an event id")
            for checkpoint in scenario.checkpoints ?? [] {
                #expect(ids.contains(checkpoint.afterEvent), "\(scenario.name): checkpoint after unknown event \(checkpoint.afterEvent)")
            }
        }
    }

    @Test("A 5-4-3 double play reads back as: runner forced at second 5-4, batter out at first 4-3")
    func fiveFourThreeDoublePlay() throws {
        let scenario = try Scenarios.load("hard-5-4-3-double-play")
        guard case .ballInPlay(let play) = scenario.events[1].kind else {
            Issue.record("The second event should be a ball in play")
            return
        }
        #expect(play.batterResult == .out)
        #expect(play.fielders == [.thirdBase, .secondBase, .firstBase])
        #expect(play.multiOut == .doublePlay)
        let runner = try #require(play.runners.first { $0.runner == "c1" })
        #expect(runner.from == .first && runner.to == .out && runner.outAt == .second)
        #expect(runner.outBy == [.thirdBase, .secondBase])
        let batter = try #require(play.batterMove)
        #expect(batter.runner == "c2" && batter.to == .out && batter.outBy == [.secondBase, .firstBase])
    }

    @Test("A dropped third strike rides on the strike-three pitch")
    func droppedThirdStrike() throws {
        let scenario = try Scenarios.load("hard-dropped-third-strike-batter-reaches")
        guard case .pitch(let pitch) = scenario.events.last?.kind else {
            Issue.record("The last event should be a pitch")
            return
        }
        #expect(pitch.result == .swingingStrike)
        #expect(pitch.droppedThirdStrike?.batterResult == .reachedOnDroppedThirdStrike)
    }

    @Test("Shared setups decode, and the standard one matches the sample teams")
    func setupsDecode() throws {
        let standard = try Scenarios.setup(named: "standard")
        #expect(standard.away.lineup.count == 9 && standard.home.lineup.count == 9)
        #expect(standard.ourSide == .home)
        for player in standard.home.roster {
            #expect(SampleTeamsLookup.mudcats(player.id)?.name == player.name)
        }
        for player in standard.away.roster {
            #expect(SampleTeamsLookup.cardinals(player.id)?.name == player.name)
        }
        let dnr = try Scenarios.setup(named: "designated-non-runner")
        #expect(dnr.home.designatedNonRunners == ["m1"])
        let unknown = try Scenarios.setup(named: "unknown-opponent")
        let allUnnamed = unknown.away.roster.allSatisfy { $0.isUnnamed }
        #expect(allUnnamed)
        #expect(unknown.away.startingPitcher == "rp")
    }
}

/// Looks up players on the sample teams, for comparing with the scenario setups.
enum SampleTeamsLookup {
    static func mudcats(_ id: PlayerID) -> Player? { SampleTeams.mudcats.player(id) }
    static func cardinals(_ id: PlayerID) -> Player? { SampleTeams.cardinals.player(id) }
}
