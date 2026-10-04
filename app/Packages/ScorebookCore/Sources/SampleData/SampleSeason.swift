// Season totals for a season of one game: the sample game. Every one of our twelve
// players is listed. Robin Nash did not play and Taylor Voss only pitched, so neither has
// an at-bat and their rate stats show as dashes. The numbers are copied from the sample
// box score: a 5–3 win at home, so the record is one win and the winning pitcher is 1-0.

import Foundation
import Model

public enum SampleSeason {
    /// The Diamond Dogs' season so far: the one sample game.
    public static let totals: SeasonTotals = {
        let box = SampleGame.boxScore
        let date = SampleSetups.gameDay
        let opponent = "Mudcats"
        // The one game as the games list has it: at home, 5–3, a win.
        let game = GameSummary(game: SampleGame.game)

        /// One player's entry in a game log for the sample game.
        func logEntry<Counts>(_ stats: Counts) -> GameLogEntry<Counts> {
            GameLogEntry(gameID: SampleGame.id, date: date, opponentName: opponent, weAreHome: game.weAreHome,
                         finalScore: game.finalScore, result: game.result, stats: stats)
        }

        let batting = SampleTeams.diamondDogs.roster.map { player -> SeasonBattingLine in
            let lines = box.home.batting.filter { $0.player == player.id }
            let stats = lines.reduce(BattingCounts()) { $0 + $1.stats }
            let played = !lines.isEmpty
            return SeasonBattingLine(
                player: player.id, name: player.displayName, number: player.number,
                games: played ? 1 : 0, stats: stats,
                gameLog: played ? [logEntry(stats)] : []
            )
        }

        let pitching = box.home.pitching.map { line in
            SeasonPitchingLine(
                player: line.player, name: line.name, number: line.number, games: 1,
                wins: line.decision == .win ? 1 : 0, losses: line.decision == .loss ? 1 : 0,
                stats: line.stats, gameLog: [logEntry(line.stats)]
            )
        }

        let fielding = box.home.fielding.map { SeasonFieldingLine(player: $0.player, name: $0.name, stats: $0.stats) }

        return SeasonTotals(teamID: "diamond-dogs", teamName: "Diamond Dogs", games: 1,
                            wins: game.result == .win ? 1 : 0, losses: game.result == .loss ? 1 : 0,
                            ties: game.result == .tie ? 1 : 0,
                            batting: batting, pitching: pitching, fielding: fielding)
    }()

    /// The games list: the sample game, finished.
    public static let games: [GameSummary] = [GameSummary(game: SampleGame.game)]
}
