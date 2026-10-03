// Season totals for a season of one game: the sample game. Every one of our twelve
// players is listed. Robin Nash only ran for a designated non-runner and Taylor Voss only
// pitched, so neither has an at-bat and their rate stats show as dashes. The numbers are
// copied from the sample box score.

import Foundation
import Model

public enum SampleSeason {
    /// The Mudcats' season so far: the one sample game.
    public static let totals: SeasonTotals = {
        let box = SampleGame.boxScore
        let date = SampleSetups.gameDay
        let opponent = "Cardinals"

        let batting = SampleTeams.mudcats.roster.map { player -> SeasonBattingLine in
            let lines = box.home.batting.filter { $0.player == player.id }
            let stats = lines.reduce(BattingCounts()) { $0 + $1.stats }
            let played = !lines.isEmpty
            return SeasonBattingLine(
                player: player.id, name: player.displayName, number: player.number,
                games: played ? 1 : 0, stats: stats,
                gameLog: played ? [GameLogEntry(gameID: SampleGame.id, date: date, opponentName: opponent, stats: stats)] : []
            )
        }

        let pitching = box.home.pitching.map { line in
            SeasonPitchingLine(
                player: line.player, name: line.name, number: line.number, games: 1, stats: line.stats,
                gameLog: [GameLogEntry(gameID: SampleGame.id, date: date, opponentName: opponent, stats: line.stats)]
            )
        }

        let fielding = box.home.fielding.map { SeasonFieldingLine(player: $0.player, name: $0.name, stats: $0.stats) }

        return SeasonTotals(teamID: "mudcats", teamName: "Mudcats", games: 1,
                            batting: batting, pitching: pitching, fielding: fielding)
    }()

    /// The games list: the sample game, finished.
    public static let games: [GameSummary] = [GameSummary(game: SampleGame.game)]
}
