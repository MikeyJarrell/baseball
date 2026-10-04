// Game-end rules: when the app should ask the scorer "Is the game over?", and the live game
// clock between events.
//
// None of these rules ends a game. Each one only raises a question; the scorer answers with
// an end-of-game event or a keep-playing event. A reason the scorer has answered "keep
// playing" to is never asked again in the same game.
//
// League rules (San Diego Adult Baseball League):
// - Regulation: the scheduled innings are done and the score is not tied, or the home team
//   leads after the top of the last inning. A tie after nine with time left goes on [9.1 H 2].
// - Run rule: a 12-run lead at the end of seven innings, or after six and a half with the home
//   team ahead [9.13]. Only when a half-inning ends.
// - Time limit: no new inning begins once the limit passes [9.1 G]. The inning it passed in is
//   finished; the home team does not bat if it is already ahead. A tie stays a tie [9.1 H 1].

import Foundation
import Model

enum GameEndRules {
    /// The question to ask when a half-inning has just ended, if any. `situation` is already
    /// the next half-inning (with the score as it stands); `inning` and `half` are the one
    /// that ended. `timeIsUp` says the time limit had run out when it ended, and the scorer has
    /// not chosen to play past it.
    ///
    /// When several rules apply at once, regulation is asked first, then the run rule, then the
    /// time limit.
    static func questionAtEndOfHalf(
        inning: Int, half: HalfInning, situation s: Situation, rules: GameRules, timeIsUp: Bool
    ) -> EndOfGame.Reason? {
        let score = s.score
        let homeAhead = score.home > score.away
        let declined = Set(s.declinedEndings)

        // Regulation: after the bottom of the last scheduled inning (or any later one) with a
        // winner, or after its top half with the home team ahead.
        let regulation: Bool = {
            guard inning >= rules.scheduledInnings else { return false }
            return half == .bottom ? score.home != score.away : homeAhead
        }()
        if regulation, !declined.contains(.regulation) { return .regulation }

        // Run rule: a lead of the margin at the end of the run rule's inning or later, or after
        // its top half with the home team ahead. Never while the visitors lead after a top half,
        // since the home team still bats.
        if let margin = rules.runRuleMargin, inning >= rules.runRuleInning, !declined.contains(.runRule) {
            let lead = half == .bottom ? abs(score.home - score.away) : score.home - score.away
            if lead >= margin { return .runRule }
        }

        // Time limit: the inning ended after the limit passed, or its top half ended with the
        // home team ahead.
        if timeIsUp, half == .bottom || homeAhead { return .timeLimit }
        return nil
    }

    /// The game clock at a moment between events: carries the replay's stored decisions forward
    /// in time, so "Is the game over?" can come up between innings without a new event.
    static func clock(for s: Situation, at now: Date) -> GameClock {
        // A finished game asks nothing.
        guard !s.isFinal else {
            return GameClock(timeLimitEndsAt: nil, timeRemaining: nil, isLastInning: false, askIfOverOnTime: false)
        }
        guard let end = s.timeLimitEndsAt else {
            return GameClock(timeLimitEndsAt: nil, timeRemaining: nil, isLastInning: false,
                             askIfOverOnTime: s.gameOverQuestion == .timeLimit)
        }
        let started = s.gameStartedAt != nil
        let remaining = started ? end.timeIntervalSince(now) : nil
        let declined = s.declinedEndings.contains(.timeLimit)
        let timeIsUp = started && now >= end && !declined
        // The inning has begun once its first pitch is thrown.
        let inningBegun = s.currentInningStartedAt != nil
        let isLastInning = timeIsUp && inningBegun

        var ask = s.gameOverQuestion == .timeLimit
        if timeIsUp, s.gameOverQuestion == nil, s.isBetweenHalfInnings {
            if s.half == .top {
                // An inning has just ended and no new one may begin.
                ask = true
            } else if inningBegun, s.score.home > s.score.away {
                // The top half of the last inning is over and the home team leads.
                ask = true
            }
        }
        return GameClock(timeLimitEndsAt: end, timeRemaining: remaining, isLastInning: isLastInning, askIfOverOnTime: ask)
    }
}
