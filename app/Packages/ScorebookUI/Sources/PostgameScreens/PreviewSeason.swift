// Made-up seasons and games lists for the previews, beside the one-game season in SampleData.
//
// SampleData's season has one game, so its numbers are small. The previews also need a longer
// season, to check that bigger numbers fit their columns and that sorting reads well. The
// numbers below are typed in by hand from the approved mockup's season table, given to the
// Diamond Dogs' twelve players. Nothing here is worked out from plays; it is only for looking at.

import Foundation
import Model
import SampleData

enum PreviewSeason {
    /// A day in the sample season, `days` after the sample game.
    static func day(_ days: Int) -> Date {
        SampleSetups.gameDay.addingTimeInterval(Double(days) * 24 * 3600)
    }

    /// A batting line typed in from the mockup: games, at-bats, runs, hits, doubles, triples,
    /// home runs, runs batted in, walks, strikeouts, hit by pitch and sacrifice flies.
    /// Plate appearances are the at-bats, walks, hit by pitch and sacrifice flies.
    private static func hitter(_ player: Player, _ g: Int, _ ab: Int, _ r: Int, _ h: Int, _ d: Int, _ t: Int,
                               _ hr: Int, _ rbi: Int, _ bb: Int, _ k: Int, _ hbp: Int, _ sf: Int) -> SeasonBattingLine {
        let stats = BattingCounts(plateAppearances: ab + bb + hbp + sf, atBats: ab, runs: r, hits: h,
                                  doubles: d, triples: t, homeRuns: hr, runsBattedIn: rbi, walks: bb,
                                  strikeouts: k, hitByPitch: hbp, sacrificeFlies: sf)
        return SeasonBattingLine(player: player.id, name: player.displayName, number: player.number,
                                 games: g, stats: stats, gameLog: [])
    }

    /// A pitching line typed in from the mockup.
    private static func pitcher(_ player: Player, _ g: Int, outs: Int, bf: Int, h: Int, r: Int, bb: Int, k: Int,
                                hr: Int, hbp: Int, pitches: Int, strikes: Int) -> SeasonPitchingLine {
        SeasonPitchingLine(player: player.id, name: player.displayName, number: player.number, games: g,
                           stats: PitchingCounts(outsRecorded: outs, battersFaced: bf, hits: h, runs: r, walks: bb,
                                                 strikeouts: k, homeRuns: hr, hitBatters: hbp,
                                                 pitches: pitches, strikes: strikes),
                           gameLog: [])
    }

    /// Our twelve players, by id.
    private static func dog(_ id: String) -> Player {
        SampleTeams.diamondDogs.roster.first { $0.id.rawValue == id }!
    }

    /// A fourteen-game season for the twelve Diamond Dogs. Nash has
    /// three plate appearances (under the averages filter) and Voss none (only pitched).
    /// The game logs are left empty; the player page previews use the logs below.
    static let fourteenGames = SeasonTotals(
        teamID: "diamond-dogs", teamName: "Diamond Dogs", games: 14,
        batting: [
            hitter(dog("d1"), 14, 52, 14, 19, 4, 1, 1, 8, 9, 6, 1, 0),
            hitter(dog("d2"), 14, 55, 10, 16, 3, 0, 0, 5, 4, 9, 0, 1),
            hitter(dog("d3"), 14, 50, 11, 18, 6, 0, 3, 17, 8, 7, 1, 1),
            hitter(dog("d4"), 13, 47, 8, 13, 3, 1, 2, 11, 5, 12, 0, 0),
            hitter(dog("d5"), 14, 49, 9, 15, 2, 0, 4, 14, 6, 10, 2, 1),
            hitter(dog("d6"), 12, 40, 4, 9, 2, 0, 0, 6, 3, 8, 0, 2),
            hitter(dog("d7"), 14, 46, 7, 12, 1, 1, 0, 4, 7, 6, 1, 0),
            hitter(dog("d8"), 13, 41, 6, 11, 2, 0, 1, 7, 6, 9, 0, 0),
            hitter(dog("d9"), 10, 30, 2, 5, 1, 0, 0, 2, 1, 11, 0, 0),
            hitter(dog("d10"), 14, 44, 5, 14, 3, 0, 2, 12, 5, 7, 0, 1),
            hitter(dog("d11"), 2, 2, 1, 1, 0, 0, 0, 0, 1, 0, 0, 0),
            hitter(dog("d12"), 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
        ],
        pitching: [
            pitcher(dog("d9"), 10, outs: 175, bf: 251, h: 51, r: 27, bb: 14, k: 47, hr: 3, hbp: 2,
                    pitches: 912, strikes: 571),
            pitcher(dog("d12"), 8, outs: 63, bf: 96, h: 19, r: 10, bb: 9, k: 18, hr: 1, hbp: 1,
                    pitches: 340, strikes: 205),
            pitcher(dog("d4"), 1, outs: 0, bf: 4, h: 3, r: 2, bb: 1, k: 0, hr: 0, hbp: 0,
                    pitches: 17, strikes: 8),
        ],
        fielding: []
    )

    /// Alex Moreno's three games, oldest first, for the player page's game log.
    static let morenoLog: [GameLogEntry<BattingCounts>] = [
        GameLogEntry(gameID: SampleGame.id, date: day(0), opponentName: "Mudcats",
                     stats: BattingCounts(plateAppearances: 3, atBats: 2, runs: 1, hits: 1, runsBattedIn: 1, walks: 1)),
        GameLogEntry(gameID: "preview-bombers", date: day(7), opponentName: "Bombers",
                     stats: BattingCounts(plateAppearances: 5, atBats: 5, runs: 2, hits: 3, doubles: 1, homeRuns: 1,
                                          runsBattedIn: 3, strikeouts: 1)),
        GameLogEntry(gameID: "preview-mudcats-2", date: day(14), opponentName: "Mudcats",
                     stats: BattingCounts(plateAppearances: 4, atBats: 4, strikeouts: 2)),
    ]

    /// A three-game season with only Moreno in it, his season line the sum of his three games,
    /// for the player page with a game log of more than one game.
    static let morenoThreeGames: SeasonTotals = {
        let stats = morenoLog.reduce(BattingCounts()) { $0 + $1.stats }
        let player = dog("d1")
        return SeasonTotals(
            teamID: "diamond-dogs", teamName: "Diamond Dogs", games: 3,
            batting: [SeasonBattingLine(player: player.id, name: player.displayName, number: player.number,
                                        games: 3, stats: stats, gameLog: morenoLog)],
            pitching: [],
            fielding: [SeasonFieldingLine(player: player.id, name: player.displayName,
                                          stats: FieldingCounts(putouts: 7, assists: 11, errors: 1))])
    }()

    /// The fourteen-game season's games list: nine wins, four losses and a tie, a week apart,
    /// plus a fifteenth game still going. Handed over oldest first, so the screen has to put the
    /// newest on top.
    static let games: [GameSummary] = {
        // Opponent, whether we were home, our runs, their runs.
        let results: [(String, Bool, Int, Int)] = [
            ("River Rats", false, 11, 6), ("Hammerheads", true, 2, 3), ("Mudcats", false, 9, 2),
            ("River Rats", true, 3, 5), ("Hammerheads", false, 6, 4), ("Mudcats", true, 7, 5),
            ("Bombers", true, 4, 4), ("Bombers", false, 8, 1), ("Mudcats", true, 5, 6),
            ("River Rats", false, 10, 3), ("Hammerheads", true, 6, 2), ("Bombers", true, 1, 4),
            ("Mudcats", false, 12, 7), ("River Rats", true, 4, 3),
        ]
        var games = results.enumerated().map { index, game in
            summary("g\(index + 1)", day: index * 7, game.0, home: game.1, us: game.2, them: game.3)
        }
        games.append(GameSummary(id: "g15", date: day(14 * 7), opponentName: "Mudcats", weAreHome: false,
                                 finalScore: nil, isFinished: false))
        return games
    }()

    /// One finished game for the games list.
    private static func summary(_ id: String, day days: Int, _ opponent: String, home: Bool,
                                us: Int, them: Int) -> GameSummary {
        let score = home ? Score(away: them, home: us) : Score(away: us, home: them)
        return GameSummary(id: GameID(rawValue: id), date: day(days), opponentName: opponent,
                           weAreHome: home, finalScore: score, isFinished: true)
    }
}
