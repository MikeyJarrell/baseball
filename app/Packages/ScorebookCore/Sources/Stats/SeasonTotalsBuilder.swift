// A season: our team's games added up, player by player.
//
// Each game's box score is worked out first, then our team's half of each box score is added
// up. Our players are matched across games by player id, so a player keeps one season line
// however their name or number was written in a particular game. Opponents are left out.
//
// Batting average, on-base percentage, slugging percentage and the per-inning pitching rates
// are formulas in Model (`BattingCounts`, `PitchingCounts`); they are worked out from the
// counts here, and come back missing (printed "—") for a player with no at-bats or a pitcher
// with no outs, rather than dividing by zero.

import Model

/// Builds one team's season totals from the play logs of its games.
struct SeasonTotalsBuilder {
    let logs: [PlayLog]
    let team: TeamID
    let stats: StatsEngine

    /// One of our games: its play log, our side in it, and its box score.
    private struct OurGame {
        var log: PlayLog
        var side: TeamSide
        var box: BoxScore

        /// Our half of the box score.
        var ours: TeamBoxScore { box[side] }
        /// The other team's name, for the game-by-game log.
        var opponentName: String { log.setup[side.opponent].name }
        /// Our team as it lined up for this game, with its roster.
        var team: GameTeam { log.setup[side] }
    }

    /// Adds up the season.
    func build() -> SeasonTotals {
        // Only the games our team played, oldest first.
        let games: [OurGame] = logs
            .compactMap { log -> OurGame? in
                guard let side = TeamSide.allCases.first(where: { log.setup[$0].teamID == team }) else { return nil }
                return OurGame(log: log, side: side, box: stats.boxScore(for: log))
            }
            .enumerated()
            .sorted { ($0.element.log.setup.scheduledStart, $0.offset) < ($1.element.log.setup.scheduledStart, $1.offset) }
            .map(\.element)

        return SeasonTotals(
            teamID: team,
            teamName: games.last?.team.name ?? "",
            games: games.count,
            batting: battingLines(games),
            pitching: pitchingLines(games),
            fielding: fieldingLines(games)
        )
    }

    /// A season batting line for every player on our roster in any game, even one who never
    /// batted (games 0, rates shown as dashes), in roster order. Anyone who batted without
    /// being on the roster is added after.
    private func battingLines(_ games: [OurGame]) -> [SeasonBattingLine] {
        var players = OrderedSet<PlayerID>()
        for game in games {
            for player in game.team.roster { players.add(player.id) }
        }
        for game in games {
            for line in game.ours.batting { players.add(line.player) }
        }

        return players.items.map { player in
            var total = BattingCounts()
            var gameLog: [GameLogEntry<BattingCounts>] = []
            for game in games {
                // A player can have more than one line in a game; add them up.
                let lines = game.ours.batting.filter { $0.player == player }
                guard !lines.isEmpty else { continue }
                let stats = lines.reduce(BattingCounts()) { $0 + $1.stats }
                total = total + stats
                gameLog.append(logEntry(game, stats))
            }
            let (name, number) = nameAndNumber(of: player, in: games,
                                               fallback: games.flatMap(\.ours.batting).first { $0.player == player }?.name)
            return SeasonBattingLine(player: player, name: name, number: number,
                                     games: gameLog.count, stats: total, gameLog: gameLog)
        }
    }

    /// A season pitching line for everyone who pitched for us, in the order they first pitched.
    private func pitchingLines(_ games: [OurGame]) -> [SeasonPitchingLine] {
        var players = OrderedSet<PlayerID>()
        for game in games {
            for line in game.ours.pitching { players.add(line.player) }
        }

        return players.items.map { player in
            var total = PitchingCounts()
            var gameLog: [GameLogEntry<PitchingCounts>] = []
            for game in games {
                let lines = game.ours.pitching.filter { $0.player == player }
                guard !lines.isEmpty else { continue }
                let stats = lines.reduce(PitchingCounts()) { $0 + $1.stats }
                total = total + stats
                gameLog.append(logEntry(game, stats))
            }
            let (name, number) = nameAndNumber(of: player, in: games,
                                               fallback: games.flatMap(\.ours.pitching).first { $0.player == player }?.name)
            return SeasonPitchingLine(player: player, name: name, number: number,
                                      games: gameLog.count, stats: total, gameLog: gameLog)
        }
    }

    /// A season fielding line for everyone who took a position for us, in the order they
    /// first appeared in a box score.
    private func fieldingLines(_ games: [OurGame]) -> [SeasonFieldingLine] {
        var players = OrderedSet<PlayerID>()
        for game in games {
            for line in game.ours.fielding { players.add(line.player) }
        }

        return players.items.map { player in
            let total = games
                .flatMap { $0.ours.fielding.filter { $0.player == player } }
                .reduce(FieldingCounts()) { $0 + $1.stats }
            let (name, _) = nameAndNumber(of: player, in: games,
                                          fallback: games.flatMap(\.ours.fielding).first { $0.player == player }?.name)
            return SeasonFieldingLine(player: player, name: name, stats: total)
        }
    }

    /// One game in a player's game-by-game log.
    private func logEntry<Counts>(_ game: OurGame, _ stats: Counts) -> GameLogEntry<Counts> {
        GameLogEntry(gameID: game.log.gameID, date: game.log.setup.scheduledStart,
                     opponentName: game.opponentName, stats: stats)
    }

    /// A player's name and number as written in the most recent game that has them on the
    /// roster, so a name filled in later shows everywhere.
    private func nameAndNumber(of player: PlayerID, in games: [OurGame], fallback: String?) -> (String, String?) {
        for game in games.reversed() {
            if let person = game.team.player(player) {
                return (person.displayName, person.number)
            }
        }
        return (fallback ?? player.rawValue, nil)
    }
}
