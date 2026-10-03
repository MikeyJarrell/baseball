// Tests for what the vocabulary pass added to the rules engine: the hit credited on a
// game-ending play, the strikeout charged to the batter a pinch hitter replaced, the catcher's
// error on interference, the defense suggested with fielding rotations, and count hints.

import Foundation
import Testing
import Model
import GameEngine
import TestSupport

@Suite("Vocabulary pass in the rules engine")
struct VocabularyPassEngineTests {
    let engine = ScorebookRulesEngine()

    /// Bottom of the ninth, tied 3-3, one out, Tate on third, Shaw up.
    func walkOffSituation() throws -> Situation {
        var writer = try GameWriter.standard()
        writer.add(.manualAdjustment(ManualAdjustment(inning: 9, half: .bottom, outs: 1, score: Score(away: 3, home: 3),
                                                      runners: BaseOccupants(third: "d2"), batterIndex: 4)))
        return engine.replay(writer.game).situation
    }

    @Test("A game-ending double with the winning run on third is suggested as a single")
    func walkOffSuggestion() throws {
        let situation = try walkOffSituation()
        let double = engine.suggestRunners(for: PlayDraft(batterResult: .double), in: situation)
        #expect(double.batterResult == .single)
        #expect(double.runners.contains { $0.isBatter && $0.to == .first })
        // A home run keeps its bases, and an ordinary single needs no correction.
        #expect(engine.suggestRunners(for: PlayDraft(batterResult: .homeRun), in: situation).batterResult == nil)
        #expect(engine.suggestRunners(for: PlayDraft(batterResult: .single), in: situation).batterResult == nil)
    }

    @Test("The replay credits a game-ending double as a single when the winning run needed one base")
    func walkOffReplay() throws {
        let scenario = try Scenarios.load("walk-off-double-credited-as-single")
        let log = engine.replay(scenario.game).log
        #expect(log.entries.last?.plateAppearance?.outcome == .single)
    }

    @Test("A pinch hitter's strikeout after coming in with two strikes is charged to the batter replaced")
    func chargedBatter() throws {
        let scenario = try Scenarios.load("pinch-hitter-two-strikes-strikes-out")
        let result = engine.replay(scenario.game).log.entries.last?.plateAppearance
        #expect(result?.batter == "m10" && result?.chargedBatter == "m1" && result?.batterCharged == "m1")
        let walked = try Scenarios.load("pinch-hitter-two-strikes-walks")
        #expect(engine.replay(walked.game).log.entries.last?.plateAppearance?.chargedBatter == nil)
    }

    @Test("Catcher's interference charges the catcher once, whether or not the play lists the error")
    func catchersInterference() throws {
        let scenario = try Scenarios.load("catchers-interference-error")
        let errors = engine.replay(scenario.game).log.entries.flatMap(\.errors)
        #expect(errors == [ChargedError(fielder: .catcher, player: "d8"), ChargedError(fielder: .catcher, player: "d8")])
    }

    @Test("Each half-inning our team takes the field, the suggested defense applies the rotation")
    func suggestedDefense() throws {
        let scenario = try Scenarios.load("alternating-first-base")
        let start = engine.replay(Game(id: "start", setup: scenario.setup!)).situation
        #expect(start.suggestedDefense?.first { $0.position == .firstBase }?.player == "d4")
        let firstPitch = engine.replay(scenario.game(upThrough: "e1")).situation
        #expect(firstPitch.suggestedDefense == nil)
    }

    @Test("The engine's count hints are the shared counting rules")
    func countHints() throws {
        var situation = try walkOffSituation()
        situation.count = Count(balls: 3, strikes: 2)
        #expect(engine.countAfter(.foul, in: situation).hint == "stays 3–2")
        #expect(engine.countAfter(.ball, in: situation).endsPlateAppearance == .walk)
    }

    @Test("The batted-ball guess: one outfielder a fly ball, a throw a ground ball, no guess for one infielder")
    func battedBallGuess() {
        #expect(engine.suggestedBattedBall(for: PlayDraft(batterResult: .out, fielders: [.centerField])) == .flyBall)
        #expect(engine.suggestedBattedBall(for: PlayDraft(batterResult: .out, fielders: [.shortstop, .firstBase])) == .groundBall)
        #expect(engine.suggestedBattedBall(for: PlayDraft(batterResult: .out, fielders: [.shortstop])) == nil)
        #expect(engine.suggestedBattedBall(for: PlayDraft(batterResult: .sacrificeBunt, fielders: [.pitcher])) == .bunt)
        #expect(engine.suggestedBattedBall(for: PlayDraft(batterResult: .sacrificeFly, fielders: [.rightField])) == .flyBall)
        #expect(DoNothingRulesEngine().suggestedBattedBall(for: PlayDraft(fielders: [.centerField])) == nil)
    }
}
