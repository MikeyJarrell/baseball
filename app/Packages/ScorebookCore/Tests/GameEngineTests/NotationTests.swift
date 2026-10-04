// Scorebook notation for every kind of event, through the engine's `notation(for:in:)`.

import Foundation
import Testing
import Model
import GameEngine
import TestSupport

@Suite("Scorebook notation")
struct NotationTests {
    let engine = ScorebookRulesEngine()

    /// A situation with a given count, for pitch notation.
    func counted(_ balls: Int, _ strikes: Int) throws -> Situation {
        var s = Situation(startOf: try Scenarios.setup(named: "standard"))
        s.count = Count(balls: balls, strikes: strikes)
        return s
    }

    /// Notation for one event kind.
    func text(_ kind: EventKind, balls: Int = 0, strikes: Int = 0) throws -> String {
        engine.notation(for: GameEvent(kind: kind), in: try counted(balls, strikes))
    }

    @Test("Pitches: one letter mid-count; BB, K, ꓘ and HBP when they end it")
    func pitches() throws {
        #expect(try text(.pitch(Pitch(.ball))) == "B")
        #expect(try text(.pitch(Pitch(.ball)), balls: 3) == "BB")
        #expect(try text(.pitch(Pitch(.calledStrike))) == "C")
        #expect(try text(.pitch(Pitch(.calledStrike)), strikes: 2) == "ꓘ")
        #expect(try text(.pitch(Pitch(.swingingStrike))) == "S")
        #expect(try text(.pitch(Pitch(.swingingStrike)), strikes: 2) == "K")
        #expect(try text(.pitch(Pitch(.foul)), strikes: 2) == "F")
        #expect(try text(.pitch(Pitch(.foulTip))) == "T")
        #expect(try text(.pitch(Pitch(.foulTip)), strikes: 2) == "K")
        #expect(try text(.pitch(Pitch(.foulBunt))) == "L")
        #expect(try text(.pitch(Pitch(.foulBunt)), strikes: 2) == "K")
        #expect(try text(.pitch(Pitch(.hitByPitch))) == "HBP")
        #expect(try text(.intentionalWalk(IntentionalWalk())) == "IBB")
    }

    @Test("Dropped third strikes: thrown out, or how the batter reached")
    func droppedThirdStrikes() throws {
        func dropped(_ play: Play, called: Bool = false) throws -> String {
            try text(.pitch(Pitch(called ? .calledStrike : .swingingStrike, droppedThirdStrike: play)), strikes: 2)
        }
        #expect(try dropped(Play(batterResult: .out, fielders: pos(2, 3))) == "K 2-3")
        #expect(try dropped(Play(batterResult: .out, fielders: pos(2, 3)), called: true) == "ꓘ 2-3")
        #expect(try dropped(Play(batterResult: .reachedOnDroppedThirdStrike, runners: [mv("m1", .home, .first, reason: .wildPitch)])) == "K WP")
        #expect(try dropped(Play(batterResult: .reachedOnDroppedThirdStrike, runners: [mv("m1", .home, .first, reason: .passedBall)])) == "K PB")
        #expect(try dropped(Play(batterResult: .reachedOnDroppedThirdStrike, errors: [ErrorCharge(fielder: .catcher)])) == "K E2")
    }

    @Test("Balls in play")
    func plays() throws {
        func play(_ p: Play) throws -> String { try text(.ballInPlay(p)) }
        #expect(try play(Play(batterResult: .out, battedBall: .groundBall, fielders: pos(6, 3))) == "6-3")
        #expect(try play(Play(batterResult: .out, battedBall: .groundBall, fielders: pos(3))) == "3U")
        #expect(try play(Play(batterResult: .out, battedBall: .flyBall, fielders: pos(8))) == "F8")
        #expect(try play(Play(batterResult: .out, battedBall: .lineDrive, fielders: pos(6))) == "L6")
        #expect(try play(Play(batterResult: .out, battedBall: .popUp, fielders: pos(6))) == "P6")
        #expect(try play(Play(batterResult: .out, battedBall: .lineDrive, fielders: pos(4, 3), multiOut: .doublePlay)) == "L4-3 DP")
        #expect(try play(Play(batterResult: .out, fielders: pos(8))) == "8")
        #expect(try play(Play(batterResult: .single, hitLocation: .leftField)) == "1B 7")
        #expect(try play(Play(batterResult: .single)) == "1B")
        #expect(try play(Play(batterResult: .double, hitLocation: .rightField)) == "2B 9")
        #expect(try play(Play(batterResult: .triple, hitLocation: .centerField)) == "3B 8")
        #expect(try play(Play(batterResult: .homeRun, hitLocation: .leftField)) == "HR 7")
        #expect(try play(Play(batterResult: .single, hitLocation: .leftField, errors: [ErrorCharge(fielder: .leftField)])) == "1B 7, E7")
        #expect(try play(Play(batterResult: .reachedOnError, fielders: pos(6), errors: [ErrorCharge(fielder: .shortstop)])) == "E6")
        #expect(try play(Play(batterResult: .fieldersChoice, fielders: pos(4, 6))) == "FC 4-6")
        #expect(try play(Play(batterResult: .sacrificeFly, fielders: pos(8))) == "SF 8")
        #expect(try play(Play(batterResult: .sacrificeBunt, fielders: pos(1, 3))) == "SH 1-3")
        #expect(try play(Play(batterResult: .catchersInterference)) == "CI")
    }

    @Test("Runner moves between pitches")
    func runnerMoves() throws {
        func action(_ moves: [RunnerMove], errors: [ErrorCharge] = []) throws -> String {
            try text(.runnerAction(RunnerAction(moves: moves, errors: errors)))
        }
        #expect(try action([mv("m1", .first, .second, reason: .stolenBase)]) == "SB2")
        #expect(try action([mv("m1", .third, .scored, reason: .stolenBase)]) == "SBH")
        #expect(try action([mv("m1", .first, .out, outBy: pos(2, 6), at: .second, reason: .caughtStealing)]) == "CS2 2-6")
        #expect(try action([mv("m1", .first, .out, outBy: pos(1, 3), at: .first, reason: .pickoff)]) == "PO1 1-3")
        #expect(try action([mv("m1", .second, .third, reason: .wildPitch), mv("m2", .first, .second, reason: .wildPitch)]) == "WP")
        #expect(try action([mv("m1", .first, .second, reason: .passedBall)]) == "PB")
        #expect(try action([mv("m1", .first, .second, reason: .balk)]) == "BK")
        #expect(try action([mv("m1", .first, .second, reason: .defensiveIndifference)]) == "DI")
        #expect(try action([mv("m1", .first, .third, reason: .advanceOnError, onError: true)], errors: [ErrorCharge(fielder: .pitcher)]) == "E1")
    }

    @Test("Lineup changes and bookkeeping events")
    func otherEvents() throws {
        #expect(try text(.pitchingChange(PitchingChange(team: .home, newPitcher: "d12"))) == "P d12")
        #expect(try text(.defenseConfirmed(DefenseConfirmed(team: .home))) == "")
        #expect(try text(.errorWithNoAdvance(ErrorCharge(fielder: .firstBase))) == "E3")
        #expect(try text(.endOfGame(EndOfGame(reason: .regulation))) == "Final")
        #expect(try text(.battingHole(BattingHole(team: .away, spotIndex: 1))) == "Hole in spot 2")
    }
}
