// Tests for the in-game changes sheets' event building (GameChanges/EventBuilding.swift):
// the reasons each runner carries on a runner action, where a pickoff out goes, and how a
// planned defense is laid over the fielders on the field.
//
// Ready for a ScorebookUI test target: move this file into it once the lead builder adds one.
// Until then it runs in a scratch package outside the repository that depends on ScorebookUI.

import XCTest
import Model
import GameChanges

final class RunnerActionBuilderTests: XCTestCase {
    /// Double steal, runners on first and second, the lead runner thrown out at third:
    /// the trail runner stole second, the lead runner was caught stealing.
    func testDoubleStealLeadRunnerOutFromCaughtStealing() throws {
        let moves = [
            RunnerMove(runner: "m5", from: .second, to: .out, outBy: [.catcher, .thirdBase], outAt: .third),
            RunnerMove(runner: "m4", from: .first, to: .second),
        ]
        let action = try XCTUnwrap(RunnerActionBuilder.action(moves: moves, picked: .caughtStealing, errors: []))
        XCTAssertEqual(action.moves.first { $0.runner == "m5" }?.reason, .caughtStealing)
        XCTAssertEqual(action.moves.first { $0.runner == "m4" }?.reason, .stolenBase)
        XCTAssertEqual(action.moves.first { $0.runner == "m5" }?.outBy, [.catcher, .thirdBase])
    }

    /// The same play entered from "Stole": the runner thrown out still gets a caught stealing.
    func testDoubleStealLeadRunnerOutFromStolenBase() throws {
        let moves = [
            RunnerMove(runner: "m5", from: .second, to: .out, outBy: [.catcher, .thirdBase], outAt: .third),
            RunnerMove(runner: "m4", from: .first, to: .second),
        ]
        let action = try XCTUnwrap(RunnerActionBuilder.action(moves: moves, picked: .stolenBase, errors: []))
        XCTAssertEqual(action.moves.first { $0.runner == "m5" }?.reason, .caughtStealing)
        XCTAssertEqual(action.moves.first { $0.runner == "m4" }?.reason, .stolenBase)
    }

    /// A runner left where they were on a steal gets no stolen base: they are not in the event.
    func testRunnerWhoStayedIsLeftOut() throws {
        let moves = [
            RunnerMove(runner: "m4", from: .third, to: .third),
            RunnerMove(runner: "m5", from: .first, to: .second),
        ]
        let action = try XCTUnwrap(RunnerActionBuilder.action(moves: moves, picked: .stolenBase, errors: []))
        XCTAssertEqual(action.moves.map(\.runner), ["m5"])
    }

    /// Nobody moved: nothing to record.
    func testNothingMovedIsNoEvent() {
        let moves = [RunnerMove(runner: "m4", from: .first, to: .first)]
        XCTAssertNil(RunnerActionBuilder.action(moves: moves, picked: .stolenBase, errors: []))
    }

    /// Steal of second, the catcher throws it away and the runner reaches third:
    /// a stolen base, helped by the error, with E2 listed once.
    func testStolenBasePlusThrowingError() throws {
        let moves = [RunnerMove(runner: "m3", from: .first, to: .third)]
        let error = ErrorCharge(fielder: .catcher, type: .throwing)
        let action = try XCTUnwrap(RunnerActionBuilder.action(moves: moves, picked: .stolenBase, errors: [error]))
        XCTAssertEqual(action.moves.first?.reason, .stolenBase)
        XCTAssertEqual(action.moves.first?.advancedOnError, true)
        XCTAssertEqual(action.errors, [error])
    }

    /// A wild pitch moves every runner; a runner thrown out trying for two is "other", not a wild pitch.
    func testWildPitchRunnerThrownOutIsOther() throws {
        let moves = [
            RunnerMove(runner: "m4", from: .third, to: .scored),
            RunnerMove(runner: "m5", from: .second, to: .out, outBy: [.catcher, .thirdBase], outAt: .third),
        ]
        let action = try XCTUnwrap(RunnerActionBuilder.action(moves: moves, picked: .wildPitch, errors: []))
        XCTAssertEqual(action.moves.first { $0.runner == "m4" }?.reason, .wildPitch)
        XCTAssertEqual(action.moves.first { $0.runner == "m5" }?.reason, .other)
    }

    /// A pickoff or an appeal puts the runner out at their own base; a caught stealing at the next one.
    func testDefaultOutBase() {
        XCTAssertEqual(RunnerActionBuilder.defaultOutBase(for: .pickoff, from: .first), .first)
        XCTAssertEqual(RunnerActionBuilder.defaultOutBase(for: .outOnAppeal, from: .second), .second)
        XCTAssertEqual(RunnerActionBuilder.defaultOutBase(for: .caughtStealing, from: .first), .second)
        XCTAssertEqual(RunnerActionBuilder.defaultOutBase(for: .caughtStealing, from: .third), .home)
    }

    /// An out with no fielders tapped is flagged, so the button says "Save without fielders".
    func testOutWithoutFieldersIsFlagged() {
        XCTAssertTrue(RunnerActionBuilder.outsMissingFielders([RunnerMove(runner: "m3", from: .first, to: .out)]))
        XCTAssertFalse(RunnerActionBuilder.outsMissingFielders([RunnerMove(runner: "m3", from: .first, to: .out, outBy: [.pitcher, .firstBase])]))
    }
}

final class DefenseBuilderTests: XCTestCase {
    /// The Diamond Dogs' usual nine.
    let field: [FielderAssignment] = [
        .init(position: .pitcher, player: "d9"), .init(position: .catcher, player: "d8"),
        .init(position: .firstBase, player: "d4"), .init(position: .secondBase, player: "d1"),
        .init(position: .thirdBase, player: "d5"), .init(position: .shortstop, player: "d2"),
        .init(position: .leftField, player: "d6"), .init(position: .centerField, player: "d3"),
        .init(position: .rightField, player: "d7"),
    ]

    /// First base alternates: the plan names only first base. Nash comes in, Quinn goes off,
    /// and every other fielder stays where they are.
    func testPlanForOnePositionKeepsTheRest() throws {
        let plan = DefenseSuggestion(team: .home, fielders: [.init(position: .firstBase, player: "d11")], reasons: [.firstBase: "alternating"])
        let draft = DefenseBuilder.startingDraft(current: field, plan: plan, side: .home, isCheck: true)
        XCTAssertEqual(draft[.firstBase], "d11")
        XCTAssertEqual(draft.count, 9)
        XCTAssertEqual(draft[.shortstop], "d2")
        let change = try XCTUnwrap(DefenseBuilder.substitution(team: .home, current: DefenseBuilder.lineup(field), draft: draft))
        XCTAssertEqual(change.defense, [.init(position: .firstBase, player: "d11")])
        XCTAssertEqual(change.leavesField, [])
    }

    /// A plan that swaps two fielders gives both positions, and nobody is lost.
    func testPlanSwappingTwoFielders() throws {
        let plan = DefenseSuggestion(team: .home, fielders: [.init(position: .centerField, player: "d7"), .init(position: .rightField, player: "d3")])
        let draft = DefenseBuilder.startingDraft(current: field, plan: plan, side: .home, isCheck: true)
        XCTAssertEqual(draft[.centerField], "d7")
        XCTAssertEqual(draft[.rightField], "d3")
        let change = try XCTUnwrap(DefenseBuilder.substitution(team: .home, current: DefenseBuilder.lineup(field), draft: draft))
        XCTAssertEqual(Set(change.defense.map(\.position)), [.centerField, .rightField])
    }

    /// A plan for our team is never laid over the other team's fielders.
    func testPlanForTheOtherTeamIsIgnored() {
        let plan = DefenseSuggestion(team: .away, fielders: [.init(position: .firstBase, player: "m10")])
        let draft = DefenseBuilder.startingDraft(current: field, plan: plan, side: .home, isCheck: true)
        XCTAssertEqual(draft, DefenseBuilder.lineup(field))
    }

    /// The fielders sheet from the changes menu never uses the plan, even for the right team.
    func testPlanIgnoredOutsideTheCheck() {
        let plan = DefenseSuggestion(team: .home, fielders: [.init(position: .firstBase, player: "d11")])
        let draft = DefenseBuilder.startingDraft(current: field, plan: plan, side: .home, isCheck: false)
        XCTAssertEqual(draft, DefenseBuilder.lineup(field))
    }

    /// No changes: no substitution.
    func testNoChangesNoSubstitution() {
        let lineup = DefenseBuilder.lineup(field)
        XCTAssertNil(DefenseBuilder.substitution(team: .home, current: lineup, draft: lineup))
    }

    /// Leaving a position empty sends that player off the field.
    func testEmptyPositionLeavesField() throws {
        var draft = DefenseBuilder.lineup(field)
        DefenseBuilder.put(nil, at: .leftField, in: &draft)
        let change = try XCTUnwrap(DefenseBuilder.substitution(team: .home, current: DefenseBuilder.lineup(field), draft: draft))
        XCTAssertEqual(change.leavesField, ["d6"])
        XCTAssertEqual(change.defense, [])
    }
}
