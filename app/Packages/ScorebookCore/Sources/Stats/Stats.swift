// Stats: play logs in, box scores and season totals out.
//
// `StatsEngine` is the real version of the `StatsCalculator` promise in Model. It never looks
// at the events on their own and never decides anything about baseball: it only adds up what
// the rules engine's play log already says (who batted, how each plate appearance ended, who
// scored and which pitcher is charged, who made each out, who was standing where). So the
// rules of the game live in one place, the rules engine.
//
// The work is split across three files:
//   - PlayLogReading.swift: small helpers that read one play log entry or one outcome.
//   - BoxScoreBuilder.swift: one game's box score.
//   - SeasonTotalsBuilder.swift: a season, from several games' box scores.
//
// Scoring follows the official rules of Major League Baseball (Official Baseball Rules,
// rule 9), plus the league's own rules in notes/league-rules.md.

import Model

/// Turns play logs into box scores, season totals and batter histories.
public struct StatsEngine: StatsCalculator {
    public init() {}

    /// The box score for one game, finished or so far.
    public func boxScore(for log: PlayLog) -> BoxScore {
        BoxScoreBuilder(log: log).build()
    }

    /// Season totals for one of our teams, with the season record and each pitcher's wins and
    /// losses. Opponents' players are left out.
    public func seasonTotals(for logs: [PlayLog], team: TeamID) -> SeasonTotals {
        SeasonTotalsBuilder(logs: logs, team: team, stats: self).build()
    }

    /// One player's plate appearances in one game, oldest first, in scorebook notation:
    /// "BB", "6-3", "1B 9". Only plate appearances that ended count; a batter who was still
    /// at the plate when the third out was made on the bases has none for that trip.
    public func plateAppearances(of player: PlayerID, in log: PlayLog) -> [PlateAppearanceSummary] {
        log.entries.compactMap { entry in
            // A pinch hitter's strikeout charged to the batter they replaced is in that
            // batter's history [9.15(b)].
            guard let result = entry.plateAppearance, result.batterCharged == player else { return nil }
            return PlateAppearanceSummary(
                inning: entry.inning,
                notation: entry.notation,
                outcome: result.outcome,
                rbi: result.rbi
            )
        }
    }
}
