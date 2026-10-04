// Tests for what the vocabulary pass added to the rules engine: the hit credited on a
// game-ending play, the strikeout charged to the batter a pinch hitter replaced, the catcher's
// error on interference, the defense suggested with fielding rotations, and count hints.

import Foundation
import Testing
import Model
import GameEngine
import Stats
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
        // The notation is written from the credited hit, so the batter's history agrees.
        #expect(log.entries.last?.notation == "1B 8")
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

    @Test("A double play with the strikeout counts only right after a strikeout in the same half-inning")
    func strikeoutDoublePlayCheck() throws {
        let scenario = try Scenarios.load("strikeout-caught-stealing-double-play")
        #expect(engine.replay(scenario.game).log.entries.allSatisfy { !$0.needsReview })

        // The same mark on a steal after a ball, not a strikeout: flagged, and no double play.
        var writer = try GameWriter.standard()
        writer.add(.ballInPlay(Play(batterResult: .single, runners: [RunnerMove(runner: "m1", from: .home, to: .first)])))
        writer.add(.pitch(Pitch(.ball)))
        writer.add(.runnerAction(RunnerAction(moves: [RunnerMove(runner: "m1", from: .first, to: .out, reason: .caughtStealing,
                                                                 outBy: [.catcher, .shortstop], outAt: .second)],
                                              completesStrikeoutDoublePlay: true)))
        let log = engine.replay(writer.game).log
        #expect(log.entries.last?.needsReview == true)
        #expect(StatsEngine().boxScore(for: log).notes.doublePlays.isEmpty)
    }

    @Test("In a short game nobody relieved, the starter of record gets the win")
    func shortGameWin() throws {
        var writer = try GameWriter.standard()
        func out(_ batter: PlayerID) {
            writer.add(.ballInPlay(Play(batterResult: .out, fielders: [.centerField],
                                        runners: [RunnerMove(runner: batter, from: .home, to: .out, outBy: [.centerField])])))
        }
        for batter in ["m1", "m2", "m3"] as [PlayerID] { out(batter) }
        writer.add(.ballInPlay(Play(batterResult: .homeRun, runners: [RunnerMove(runner: "d1", from: .home, to: .scored)], rbi: 1)))
        for batter in ["d2", "d3", "d4"] as [PlayerID] { out(batter) }
        for batter in ["m4", "m5", "m6"] as [PlayerID] { out(batter) }
        writer.add(.endOfGame(EndOfGame(reason: .called, finalScore: Score(away: 0, home: 1))))
        let box = StatsEngine().boxScore(for: engine.replay(writer.game).log)
        #expect(box.home.pitching.first { $0.player == "d9" }?.decision == .win)
        #expect(box.away.pitching.first { $0.player == "m9" }?.decision == .loss)
    }
}
