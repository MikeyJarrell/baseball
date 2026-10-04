// Tests of the in-play sequence's play building: the taps a scorer makes, run through the
// same handler the buttons use, with SampleData's rules engine (the real one). Each test
// checks the play that would be saved, in baseball terms: who made each out, which errors
// are charged, where every runner ended up.

import XCTest
import Model
import SampleData
@testable import PlayEntry

@MainActor
final class PlayEntryTests: XCTestCase {
    /// Runs taps through a fresh sequence and returns it, with the saved play if Save went through.
    private func enter(_ demo: PlayEntryDemo, _ taps: [PlayEntryAction]) -> (model: PlayEntryModel, play: Play?) {
        var outcome: PlayEntryOutcome?
        let model = PlayEntryModel(situation: demo.sample.situation, setup: demo.sample.setup, start: demo.start,
                                   rules: .standIn, onFinish: { outcome = $0 })
        for tap in taps { model.perform(tap) }
        return (model, outcome?.play)
    }

    private func move(_ play: Play?, _ runner: PlayerID) -> RunnerMove? {
        play?.runners.first { $0.runner == runner }
    }

    /// Every scripted demo play saves with its expected notation, outs, runs and runs batted in.
    func testEveryDemoPlayComesOutAsExpected() {
        for demo in PlayEntryDemos.all {
            let check = demo.check()
            XCTAssertTrue(check.passed, "\(demo.title): got \(check.summary)")
            XCTAssertEqual(check.taps, demo.taps.count, demo.title)
        }
    }

    // 1. A runner the scorer puts out asks who made the out, and Save waits for it.

    func testRunnerDoubledOffNeedsWhoMadeTheOut() {
        let demo = PlayEntryDemos.flyOut  // F8, runner on second
        let (model, play) = enter(demo, [.pickResult(.out), .tapFielder(.centerField), .goToRunners,
                                         .moveRunner("m2", to: .out), .save])
        XCTAssertNil(play, "Save must wait for who made the out")
        XCTAssertTrue(model.needsOutFielders("m2"))
        XCTAssertFalse(model.canSave)
        XCTAssertNotNil(model.runnerProblem)

        model.perform(.tapOutFielder("m2", .centerField))
        model.perform(.tapOutFielder("m2", .secondBase))
        XCTAssertTrue(model.canSave)
        var saved: Play?
        let finishing = PlayEntryModel(situation: demo.sample.situation, setup: demo.sample.setup, start: .inPlay,
                                       rules: .standIn, onFinish: { saved = $0.play })
        for tap in PlayEntryDemos.flyOutDoubledOff.taps { finishing.perform(tap) }
        XCTAssertEqual(move(saved, "m2")?.to, .out)
        XCTAssertEqual(move(saved, "m2")?.outBy, [.centerField, .secondBase], "the center fielder gets the assist, the second baseman the putout")
    }

    func testTappingTheLastOutFielderAgainTakesItBack() {
        let (model, _) = enter(PlayEntryDemos.flyOut, [.pickResult(.out), .tapFielder(.centerField), .goToRunners,
                                                      .moveRunner("m2", to: .out), .tapOutFielder("m2", .centerField),
                                                      .tapOutFielder("m2", .centerField)])
        XCTAssertEqual(model.outFielders["m2"], [])
        XCTAssertFalse(model.canSave)
    }

    // 2. Only the scorer's own changes go to the engine, and two runners can't end on one base.

    func testTwoRunnersOnOneBaseCannotBeSaved() {
        // Single with a runner on first; the batter takes second, so the runner from first must move on.
        let sample = PlayEntryDemos.diamondDogs("Runner on first", outs: 0, runners: ["d3": .first])
        let demo = PlayEntryDemo(id: "t", title: "t", sample: sample, taps: [], expected: ("", 0, 0, 0))
        let batter = PlayEntryDemos.ourBatter
        let (model, play) = enter(demo, [.pickResult(.single), .goToRunners, .moveRunner(batter, to: .second),
                                         .answerExtraBase(batter, onError: false)])
        XCTAssertNil(play)
        let runnerFromFirst = model.draft.runners.first { $0.runner == "d3" }
        if runnerFromFirst?.to == .second {
            // The engine left the runner from first at second: Save must refuse, with a reason.
            XCTAssertFalse(model.canSave)
            XCTAssertEqual(model.runnerProblem, "Webb and Quinn can’t both end on 2nd")
        }
        model.perform(.moveRunner("d3", to: .third))
        XCTAssertTrue(model.canSave)
        model.perform(.save)
        XCTAssertNotNil(model.outcome?.play)
    }

    func testARunnerCannotPassTheRunnerAhead() {
        // The scorer holds the runner from second at third, then sends the runner from first
        // home. Both are fixed where the scorer put them, so the engine moves neither.
        let (model, _) = enter(PlayEntryDemos.singleRunnerScores,
                               [.pickResult(.single), .goToRunners, .moveRunner("d2", to: .third),
                                .moveRunner("d3", to: .scored)])
        // The runner from first scored but the runner from second is still on third.
        XCTAssertEqual(model.runnerProblem, "Webb can’t pass Tate")
        XCTAssertFalse(model.canSave)
    }

    func testOnlyTheScorersPlacementsGoToTheEngine() {
        // A stand-in engine that records what it was asked.
        final class Asked: @unchecked Sendable { var runners: [[RunnerMove]] = [] }
        let asked = Asked()
        let real = SampleRulesEngine()
        let rules = PlayEntryRules(
            suggestRunners: { draft, situation in asked.runners.append(draft.runners); return real.suggestRunners(for: draft, in: situation) },
            preview: { real.preview($0, in: $1) },
            suggestBattedBall: { real.suggestedBattedBall(for: $0) })
        let sample = PlayEntryDemos.singleRunnerScores.sample
        let model = PlayEntryModel(situation: sample.situation, setup: sample.setup, start: .inPlay, rules: rules)
        for tap: PlayEntryAction in [.pickResult(.single), .goToRunners, .moveRunner("d2", to: .scored)] { model.perform(tap) }
        XCTAssertEqual(asked.runners.last?.map(\.runner), ["d2"], "only the runner the scorer moved")
        XCTAssertEqual(asked.runners.last?.first?.to, .scored)
    }

    // 3. "On an error" needs a fielder before Save.

    func testOnAnErrorNeedsWhoseError() {
        let batter = PlayEntryDemos.ourBatter
        let (model, play) = enter(PlayEntryDemos.singlePlusError,
                                  [.pickResult(.single), .goToRunners, .moveRunner(batter, to: .second),
                                   .answerExtraBase(batter, onError: true), .save])
        XCTAssertNil(play, "Save must wait for whose error")
        XCTAssertFalse(model.canSave)
        model.perform(.chargeExtraBaseError(batter, fielder: .leftField))
        model.perform(.save)
        let saved = model.outcome?.play
        XCTAssertEqual(saved?.errors, [ErrorCharge(fielder: .leftField)])
        XCTAssertEqual(move(saved, batter)?.to, .second)
        XCTAssertEqual(move(saved, batter)?.advancedOnError, true)
    }

    // 4. On a batter out, the batter's row offers only Out.

    func testBatterOutOffersOnlyOut() {
        let (model, _) = enter(PlayEntryDemos.flyOut, [.pickResult(.out), .tapFielder(.centerField), .goToRunners])
        let batterMove = model.draft.runners.first { $0.isBatter }!
        XCTAssertEqual(model.choices(for: batterMove), [.out])
        let runner = model.draft.runners.first { !$0.isBatter }!
        XCTAssertEqual(model.choices(for: runner), [.second, .third, .scored, .out])
    }

    func testSacrificeFlyBatterOffersOnlyOut() {
        let (model, _) = enter(PlayEntryDemos.sacrificeFly, [.showMore, .pickResult(.sacrificeFly), .tapFielder(.centerField), .goToRunners])
        XCTAssertEqual(model.choices(for: model.draft.runners.first { $0.isBatter }!), [.out])
    }

    // 5. Moving a runner keeps the engine's other details and changes only the base.

    func testMovingTheErrorBatterKeepsTheErrorMark() {
        let batter = PlayEntryDemos.mudcatsBatter
        let (model, play) = enter(PlayEntryDemos.errorBatterToSecond, PlayEntryDemos.errorBatterToSecond.taps)
        let suggested = model.firstMoves[batter]
        XCTAssertNotNil(play)
        XCTAssertEqual(move(play, batter)?.to, .second)
        XCTAssertEqual(move(play, batter)?.advancedOnError, suggested?.advancedOnError,
                       "the engine's mark that the batter reached on an error survives the move")
        XCTAssertEqual(play?.errors.map(\.fielder), [.shortstop])
    }

    func testTakingARunnerOffOutClearsWhoPutThemOut() {
        // Double play suggested; the scorer says the runner from first was safe at second after all.
        let (model, _) = enter(PlayEntryDemos.doublePlay,
                               [.pickResult(.out), .toggleMultiOut(.doublePlay), .tapFielder(.thirdBase), .tapFielder(.secondBase),
                                .tapFielder(.firstBase), .goToRunners, .moveRunner("m3", to: .second)])
        let runner = model.draft.runners.first { $0.runner == "m3" }
        XCTAssertEqual(runner?.to, .second)
        XCTAssertEqual(runner?.outBy, [])
        XCTAssertNil(runner?.outAt)
    }

    // 6. "How did they get there?" on any kind of play, not just hits.

    func testFlyOutWithThrowingErrorAsksAndChargesTheError() {
        let (model, play) = enter(PlayEntryDemos.flyOutThrowingError, PlayEntryDemos.flyOutThrowingError.taps)
        XCTAssertTrue(model.asksHow("m2"))
        XCTAssertEqual(play?.errors, [ErrorCharge(fielder: .rightField)])
        XCTAssertEqual(move(play, "m2")?.to, .scored)
        XCTAssertEqual(move(play, "m2")?.advancedOnError, true)
        XCTAssertEqual(play?.rbi, 0, "a run that scores on an error is not batted in")
    }

    func testRunnerAlreadyOnBaseStartsAtOnThePlay() {
        let (model, _) = enter(PlayEntryDemos.flyOut, [.pickResult(.out), .tapFielder(.rightField), .goToRunners,
                                                      .moveRunner("m2", to: .third)])
        XCTAssertTrue(model.asksHow("m2"))
        XCTAssertEqual(model.extraBaseAnswer(for: "m2"), .onThePlay)
        XCTAssertTrue(model.canSave)
    }

    // 7. Dropped third strike is no longer under More.

    func testMoreHasNoDroppedThirdStrike() {
        let (model, _) = enter(PlayEntryDemos.groundOut, [.showMore])
        XCTAssertTrue(model.showsMore)
        XCTAssertEqual(model.draft.context, .ballInPlay)
    }
}
