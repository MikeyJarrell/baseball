// The defense check after a change made at the changeover: a pitching change or a
// substitution recorded before the scorer confirms the defense goes into the check's
// suggestion, so the check never offers to put back the player just taken out.

import Foundation
import Testing
import Model
@testable import GameEngine
import TestSupport

@Suite("The defense check keeps changes made before it")
struct DefenseCheckTests {
    let engine = ScorebookRulesEngine()

    /// The alternating-first-base game cut off at the changeover into the 2nd, when the
    /// Diamond Dogs take the field with Nash due at first base, and the check is waiting.
    func changeoverIntoSecond() throws -> (scenario: Scenario, game: Game) {
        let scenario = try Scenarios.load("alternating-first-base")
        for event in scenario.events {
            let game = scenario.game(upThrough: event.id)
            let s = engine.replay(game).situation
            if s.inning == 2, s.defenseCheckDue { return (scenario, game) }
        }
        throw ScenarioError.noSetup("no changeover into the 2nd")
    }

    /// The suggested player at a position.
    func suggested(_ s: Situation, _ position: Position) -> PlayerID? {
        s.suggestedDefense?.first { $0.position == position }?.player
    }

    @Test("A new pitcher at the changeover is in the suggestion, and the turn at first base stays")
    func pitchingChangeBeforeTheCheck() throws {
        var (_, game) = try changeoverIntoSecond()
        let before = engine.replay(game).situation
        #expect(suggested(before, .firstBase) == "d11")
        let ours = before.fieldingSide
        let oldPitcher = try #require(before[ours].pitcher)
        game.events.append(GameEvent(kind: .pitchingChange(PitchingChange(team: ours, newPitcher: "d12"))))
        let after = engine.replay(game).situation
        #expect(after.defenseCheckDue)
        #expect(suggested(after, .pitcher) == "d12")
        #expect(after.suggestedDefense?.contains { $0.player == oldPitcher } == false)
        #expect(suggested(after, .firstBase) == "d11")
        // Everything else is as it was suggested before the change.
        let others = Position.allCases.filter { $0 != .pitcher }
        #expect(others.map { suggested(after, $0) } == others.map { suggested(before, $0) })
    }

    @Test("Without any change, the suggestion is the one made at the changeover")
    func noChange() throws {
        var (_, game) = try changeoverIntoSecond()
        let before = engine.replay(game).situation
        game.events.append(GameEvent(kind: .timeLimitChange(TimeLimitChange(endsAt: Date(timeIntervalSince1970: 2_000_000_000)))))
        #expect(engine.replay(game).situation.suggestedDefense == before.suggestedDefense)
    }

    @Test("Carrying changes: a position that changed hands takes its new player; someone who left goes")
    func carry() {
        let old = [FielderAssignment(position: .pitcher, player: "p1"), FielderAssignment(position: .firstBase, player: "a")]
        let new = [FielderAssignment(position: .pitcher, player: "p2"), FielderAssignment(position: .firstBase, player: "a")]
        let suggestion = [FielderAssignment(position: .pitcher, player: "p1"), FielderAssignment(position: .firstBase, player: "b")]
        let carried = Replay.carry(from: old, to: new, onto: suggestion)
        #expect(carried == [FielderAssignment(position: .pitcher, player: "p2"), FielderAssignment(position: .firstBase, player: "b")])
    }
}
