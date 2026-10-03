// The time limit, the run rule and regulation: when the app asks "Is the game over?", the
// live clock between events, and what happens when the scorer keeps playing. None of these
// ever ends a game by itself.

import Foundation
import Testing
import Model
import GameEngine
import TestSupport

@Suite("Is the game over? and the game clock")
struct GameEndTests {
    let engine = ScorebookRulesEngine()

    /// Three quick outs for whichever team is batting, written as fly outs by the batters named.
    func threeOuts(_ w: inout GameWriter, _ batters: [PlayerID]) {
        for b in batters { w.pa("", fly(b, 8)) }
    }

    @Test("The time limit runs three hours from the first pitch, or 3:15 for a championship game")
    func timeLimitFromFirstPitch() throws {
        var w = try GameWriter.standard()
        let before = engine.replay(w.game).situation
        #expect(before.timeLimitEndsAt == w.setup.scheduledStart.addingTimeInterval(3 * 3600))
        let firstPitch = w.clock
        w.pitches("B")
        let s = engine.replay(w.game).situation
        #expect(s.gameStartedAt == firstPitch)
        #expect(s.timeLimitEndsAt == firstPitch.addingTimeInterval(3 * 3600))

        var champ = try GameWriter.standard()
        champ.setup.rules = .championship
        champ.pitches("B")
        #expect(engine.replay(champ.game).situation.timeLimitEndsAt == firstPitch.addingTimeInterval(195 * 60))

        // The umpire's time replaces it; clearing it goes back to the first pitch plus the limit.
        let umpire = firstPitch.addingTimeInterval(2 * 3600)
        w.add(.timeLimitChange(TimeLimitChange(endsAt: umpire)))
        #expect(engine.replay(w.game).situation.timeLimitEndsAt == umpire)
        w.add(.timeLimitChange(TimeLimitChange(endsAt: nil)))
        #expect(engine.replay(w.game).situation.timeLimitEndsAt == firstPitch.addingTimeInterval(3 * 3600))
    }

    @Test("The clock between events: time left, the last inning, and asking once an inning ends past the limit")
    func clockBetweenEvents() throws {
        var w = try GameWriter.standard()
        let start = w.clock
        threeOuts(&w, ["m1", "m2", "m3"])
        // Set the umpire's limit to 10 minutes after the first pitch.
        let end = start.addingTimeInterval(600)
        w.add(.timeLimitChange(TimeLimitChange(endsAt: end)))
        threeOuts(&w, ["d1", "d2"])
        let midBottom = engine.replay(w.game).situation
        // Time left before the limit.
        let early = engine.clock(for: midBottom, at: end.addingTimeInterval(-60))
        #expect(early.timeRemaining == 60 && !early.isLastInning && !early.askIfOverOnTime)
        // The limit passes during the bottom of the first: finish the inning, nothing to ask yet.
        let late = engine.clock(for: midBottom, at: end.addingTimeInterval(60))
        #expect(late.isLastInning && !late.askIfOverOnTime)
        #expect(late.timeRemaining == -60)

        // The inning ends before the limit; the scorer waits, the limit passes between innings.
        var v = try GameWriter.standard()
        let vEnd = v.clock.addingTimeInterval(600)
        v.add(.timeLimitChange(TimeLimitChange(endsAt: vEnd)))
        threeOuts(&v, ["m1", "m2", "m3"])
        threeOuts(&v, ["d1", "d2", "d3"])
        let between = engine.replay(v.game).situation
        #expect(between.inning == 2 && between.isBetweenHalfInnings)
        #expect(!engine.clock(for: between, at: vEnd.addingTimeInterval(-1)).askIfOverOnTime)
        let ask = engine.clock(for: between, at: vEnd.addingTimeInterval(1))
        #expect(ask.askIfOverOnTime && !ask.isLastInning)

        // A finished game asks nothing.
        v.add(.endOfGame(EndOfGame(reason: .timeLimit)))
        let final = engine.clock(for: engine.replay(v.game).situation, at: vEnd.addingTimeInterval(60))
        #expect(final == GameClock(timeLimitEndsAt: nil, timeRemaining: nil, isLastInning: false, askIfOverOnTime: false))
    }

    @Test("Playing on past the limit without answering: that inning is a last inning, and the question comes back at its end")
    func playOnWithoutAnswering() throws {
        var w = try GameWriter.standard()
        let end = w.clock.addingTimeInterval(130)
        w.add(.timeLimitChange(TimeLimitChange(endsAt: end)))
        threeOuts(&w, ["m1", "m2", "m3"])
        threeOuts(&w, ["d1", "d2", "d3"])
        // The second inning starts after the limit with no answer from the scorer.
        w.pa("", fly("m4", 8))
        let s = engine.replay(w.game).situation
        #expect(s.isLastInning)
        #expect(s.gameOverQuestion == nil)
        threeOuts(&w, ["m5", "m6"])
        threeOuts(&w, ["d4", "d5", "d6"])
        #expect(engine.replay(w.game).situation.gameOverQuestion == .timeLimit)
    }

    @Test("Keep playing past the run rule: not asked again, even with a bigger lead later")
    func keepPlayingRunRule() throws {
        var w = try GameWriter.standard()
        w.add(.manualAdjustment(ManualAdjustment(inning: 7, half: .bottom, score: Score(away: 14, home: 2))))
        threeOuts(&w, ["d1", "d2", "d3"])
        #expect(engine.replay(w.game).situation.gameOverQuestion == .runRule)
        w.add(.keepPlaying(KeepPlaying(reason: .runRule)))
        var s = engine.replay(w.game).situation
        #expect(s.gameOverQuestion == nil && s.declinedEndings == [.runRule])
        w.pa("", hit(.homeRun, "m1", to: 7, rbi: 1))
        threeOuts(&w, ["m2", "m3", "m4"])
        threeOuts(&w, ["d4", "d5", "d6"])
        s = engine.replay(w.game).situation
        #expect(s.inning == 9 && s.gameOverQuestion == nil)
        // Regulation is a separate reason and is still asked at the end of nine.
        threeOuts(&w, ["m5", "m6", "m7"])
        threeOuts(&w, ["d7", "d8", "d9"])
        #expect(engine.replay(w.game).situation.gameOverQuestion == .regulation)
    }

    @Test("An unanswered question lapses once play goes on; nothing ends by itself")
    func unansweredQuestionLapses() throws {
        var w = try GameWriter.standard()
        w.add(.manualAdjustment(ManualAdjustment(inning: 7, half: .top, score: Score(away: 1, home: 13))))
        threeOuts(&w, ["m1", "m2", "m3"])
        #expect(engine.replay(w.game).situation.gameOverQuestion == .runRule)
        // A lineup change does not answer it.
        w.add(.defenseConfirmed(DefenseConfirmed(team: .away)))
        #expect(engine.replay(w.game).situation.gameOverQuestion == .runRule)
        // A pitch means the teams played on.
        w.pitches("B")
        let s = engine.replay(w.game).situation
        #expect(s.gameOverQuestion == nil && !s.isFinal)
        #expect(s.declinedEndings.isEmpty)
    }

    @Test("Official if rain stops it: five innings, or four and a half with the home team ahead")
    func officialGame() throws {
        var w = try GameWriter.standard()
        w.add(.manualAdjustment(ManualAdjustment(inning: 5, half: .top, score: Score(away: 1, home: 2))))
        #expect(!engine.replay(w.game).situation.isRegulationComplete)
        threeOuts(&w, ["m1", "m2", "m3"])
        #expect(engine.replay(w.game).situation.isRegulationComplete)

        var v = try GameWriter.standard()
        v.add(.manualAdjustment(ManualAdjustment(inning: 5, half: .top, score: Score(away: 2, home: 1))))
        threeOuts(&v, ["m1", "m2", "m3"])
        #expect(!engine.replay(v.game).situation.isRegulationComplete)
        threeOuts(&v, ["d1", "d2", "d3"])
        #expect(engine.replay(v.game).situation.isRegulationComplete)
    }

    @Test("A walk-off in extra innings asks at once; the visitors scoring in the top of the tenth asks nothing until the inning ends")
    func extraInnings() throws {
        var w = try GameWriter.standard()
        w.add(.manualAdjustment(ManualAdjustment(inning: 10, half: .top, score: Score(away: 3, home: 3))))
        w.pa("", hit(.homeRun, "m1", to: 7, rbi: 1))
        #expect(engine.replay(w.game).situation.gameOverQuestion == nil)
        threeOuts(&w, ["m2", "m3", "m4"])
        #expect(engine.replay(w.game).situation.gameOverQuestion == nil)
        w.pa("", hit(.homeRun, "d1", to: 9, rbi: 1))
        #expect(engine.replay(w.game).situation.gameOverQuestion == nil)
        w.pa("", hit(.homeRun, "d2", to: 9, rbi: 1))
        let s = engine.replay(w.game).situation
        #expect(s.gameOverQuestion == .regulation)
        #expect(s.score == Score(away: 4, home: 5))
    }
}
