// Tests that moving a runner on the runner step fixes them there and has the rules engine
// suggest everyone else again around them, with the runs batted in worked out again.

import Testing
import Model
import SampleData
@testable import PlayEntry

@MainActor
@Suite("The runner step re-suggests around the scorer's moves")
struct RunnerResuggestionTests {
    /// A fresh in-play sequence for one of the demo situations, with SampleData's rules engine
    /// (the real one), after the given taps.
    private func entered(_ sample: SampleSituation, _ taps: [PlayEntryAction]) -> PlayEntryModel {
        let model = PlayEntryModel(situation: sample.situation, setup: sample.setup, start: .inPlay, rules: .standIn)
        for tap in taps { model.perform(tap) }
        return model
    }

    /// Where a runner ends up in the play as the scorer has it now.
    private func end(_ model: PlayEntryModel, _ runner: PlayerID) -> RunnerEnd? {
        model.draft.runners.first { $0.runner == runner }?.to
    }

    @Test("Single, runner on first: sending the batter to second moves the runner from first to third")
    func batterToSecondPushesRunnerFromFirst() {
        let sample = PlayEntryDemos.diamondDogs("Runner on first", outs: 0, runners: ["d3": .first])
        let batter = PlayEntryDemos.ourBatter
        let model = entered(sample, [.pickResult(.single), .goToRunners])
        #expect(end(model, "d3") == .second)
        #expect(end(model, batter) == .first)

        model.perform(.moveRunner(batter, to: .second))
        #expect(end(model, batter) == .second)
        #expect(end(model, "d3") == .third, "the engine moves the runner from first on, with no extra tap")
        #expect(model.fixedRunners == [batter], "only the batter is fixed; the runner from first is still the engine's")
        #expect(!model.asksHow("d3"), "a runner the engine moved is not asked how they got there")
        #expect(model.runnerProblem == nil)

        model.perform(.save)
        let play = model.outcome?.play
        #expect(play?.runners.first { $0.runner == "d3" }?.to == .third)
        #expect(play?.rbi == 0)
    }

    @Test("Sending the batter to second with runners on first and second scores the lead runner and counts the run batted in")
    func pushScoresLeadRunner() {
        let sample = PlayEntryDemos.singleRunnerScores.sample
        let batter = PlayEntryDemos.ourBatter
        let model = entered(sample, [.pickResult(.single), .goToRunners])
        #expect(model.rbi == 0)
        model.perform(.moveRunner(batter, to: .second))
        #expect(end(model, "d3") == .third)
        #expect(end(model, "d2") == .scored)
        #expect(model.rbi == 1)
        #expect(model.preview.runsOnPlay == 1)
    }

    @Test("Moving the batter back to first lets the engine put the runner from first back too")
    func movingBackRestoresTheSuggestion() {
        let sample = PlayEntryDemos.diamondDogs("Runner on first", outs: 0, runners: ["d3": .first])
        let batter = PlayEntryDemos.ourBatter
        let model = entered(sample, [.pickResult(.single), .goToRunners, .moveRunner(batter, to: .second),
                                     .moveRunner(batter, to: .first)])
        #expect(end(model, "d3") == .second)
    }

    @Test("Going back off the runner step un-fixes every runner")
    func backUnfixes() {
        let sample = PlayEntryDemos.diamondDogs("Runner on first", outs: 0, runners: ["d3": .first])
        let batter = PlayEntryDemos.ourBatter
        let model = entered(sample, [.pickResult(.single), .goToRunners, .moveRunner(batter, to: .second), .back])
        #expect(model.fixedRunners.isEmpty)
        model.perform(.goToRunners)
        #expect(end(model, batter) == .first)
        #expect(end(model, "d3") == .second)
    }
}
