// Replays the complete sample game (five innings, written out by hand in SampleData along
// with its play log) and checks the engine reaches the same account, event by event.
//
// The hand-written play log was worked out separately from this engine, so agreement here
// checks the counts, outs, runs, responsible pitchers, putouts and notation of a whole game.

import Foundation
import Testing
import Model
import SampleData
import GameEngine

@Suite("The sample game, replayed")
struct SampleGameReplayTests {
    let replay = ScorebookRulesEngine().replay(SampleGame.game)
    let handWritten = SampleGame.playLog

    @Test("Every entry matches the hand-written play log")
    func entriesMatch() {
        #expect(replay.log.entries.count == handWritten.entries.count)
        for (mine, theirs) in zip(replay.log.entries, handWritten.entries) {
            let id = mine.event.id
            #expect(mine.inning == theirs.inning && mine.half == theirs.half, "\(id) inning")
            #expect(mine.batter == theirs.batter, "\(id) batter")
            #expect(mine.pitcher == theirs.pitcher, "\(id) pitcher")
            #expect(mine.fielders == theirs.fielders, "\(id) fielders")
            #expect(mine.before == theirs.before, "\(id) before")
            #expect(mine.after == theirs.after, "\(id) after")
            #expect(mine.pitches == theirs.pitches && mine.strikes == theirs.strikes, "\(id) pitches")
            #expect(mine.runs == theirs.runs, "\(id) runs")
            #expect(mine.outs == theirs.outs, "\(id) outs")
            #expect(mine.errors == theirs.errors, "\(id) errors")
            #expect(mine.plateAppearance == theirs.plateAppearance, "\(id) plate appearance")
            #expect(mine.endsHalfInning == theirs.endsHalfInning, "\(id) ends half-inning")
            #expect(mine.notation == theirs.notation, "\(id) notation")
            #expect(!mine.needsReview, "\(id) flagged: \(mine.reviewNote ?? "")")
        }
    }

    @Test("The final situation matches the hand-written one")
    func finalSituation() {
        let mine = replay.situation
        let theirs = SampleGame.finalSituation
        #expect(mine.inning == theirs.inning && mine.half == theirs.half)
        #expect(mine.score == theirs.score)
        #expect(mine.away == theirs.away)
        #expect(mine.home == theirs.home)
        #expect(mine.pitchers == theirs.pitchers)
        #expect(mine.lastPlayNotation == theirs.lastPlayNotation)
        #expect(mine.isRegulationComplete == theirs.isRegulationComplete)
        #expect(mine.isFinal && mine.gameOverQuestion == nil)
        #expect(mine.gameStartedAt == theirs.gameStartedAt)
        #expect(mine.timeLimitEndsAt == theirs.timeLimitEndsAt)
        #expect(mine == theirs)
        #expect(replay.log.awayOrder == handWritten.awayOrder)
        #expect(replay.log.homeOrder == handWritten.homeOrder)
    }

    @Test("When the fifth inning ended past the time limit, the app asked whether the game was over")
    func timeLimitQuestion() {
        // Cut the game just before the scorer ended it.
        var game = SampleGame.game
        game.events.removeLast()
        let s = ScorebookRulesEngine().replay(game).situation
        #expect(s.gameOverQuestion == .timeLimit)
        #expect(!s.isFinal)
        #expect(s.inning == 6 && s.half == .top)
    }
}
