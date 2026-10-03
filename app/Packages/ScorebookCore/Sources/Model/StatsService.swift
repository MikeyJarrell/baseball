// The stats engine's promise: what the Stats module provides to the rest of the app.
//
// Stats are computed only from play logs, which the rules engine produces, so the rules
// of the game live in one place. The do-nothing stand-in is at the bottom of this file.

import Foundation

/// Turns play logs into box scores and season totals. Runs straight through (no waiting),
/// and may be called from any thread.
public protocol StatsCalculator: Sendable {
    /// The box score for one game, finished or so far.
    func boxScore(for log: PlayLog) -> BoxScore

    /// Season totals for one of our teams, from the play logs of its games.
    /// Opponents' players are left out.
    func seasonTotals(for logs: [PlayLog], team: TeamID) -> SeasonTotals

    /// One player's plate appearances in one game, oldest first, in scorebook notation:
    /// the "earlier today" line on the batting screen.
    func plateAppearances(of player: PlayerID, in log: PlayLog) -> [PlateAppearanceSummary]
}

/// A stats calculator that does nothing: empty box scores with the right team names,
/// empty season totals, no plate appearances.
public struct DoNothingStatsCalculator: StatsCalculator {
    public init() {}

    public func boxScore(for log: PlayLog) -> BoxScore {
        func team(_ side: TeamSide) -> TeamBoxScore {
            let t = log.setup[side]
            return TeamBoxScore(
                side: side, teamID: t.teamID, name: t.name,
                batting: [], pitching: [], fielding: [],
                runs: 0, hits: 0, errors: 0, leftOnBase: 0
            )
        }
        return BoxScore(
            gameID: log.gameID,
            date: log.setup.scheduledStart,
            away: team(.away),
            home: team(.home),
            lineScore: LineScore(away: [], home: []),
            notes: BoxScoreNotes(),
            isFinal: log.isFinal
        )
    }

    public func seasonTotals(for logs: [PlayLog], team: TeamID) -> SeasonTotals {
        SeasonTotals(teamID: team, teamName: "", games: logs.count, batting: [], pitching: [], fielding: [])
    }

    public func plateAppearances(of player: PlayerID, in log: PlayLog) -> [PlateAppearanceSummary] {
        []
    }
}
