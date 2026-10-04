// The season record, pitchers' wins and losses, and each game's result in the game logs,
// over the same three games as the season totals tests (see SeasonTotalsTests.swift):
//
// Game 1 (May 2): Mudcats at Diamond Dogs, a 5–3 Diamond Dogs win. Sky Barros gets the win.
// Game 2 (May 9): Diamond Dogs at the Bombers, called after one inning with the Diamond Dogs
//   ahead 3–0. Barros, the only pitcher, keeps the win: nobody relieved them.
// Game 3 (May 16): Mudcats at Diamond Dogs, called after one inning at 0–0: a tie, with no
//   winning or losing pitcher.
//
// So the record is 2 wins, 0 losses and 1 tie, and Barros is 2-0.

import Foundation
import Testing
import Model
import SampleData
import TestSupport
@testable import Stats

@Suite("Season record and pitching decisions")
struct SeasonRecordTests {
    let stats = StatsEngine()

    /// The three games, out of order, as the season totals tests hand them over.
    func threeGames() throws -> [PlayLog] {
        [try SeasonTotalsTests.secondMudcatsGame(), SampleGame.playLog, SeasonTotalsTests.gameAtBombers()]
    }

    /// A fourth game still going: Diamond Dogs at the Bombers again, Moreno singled, no end yet.
    static func gameStillGoing() -> PlayLog {
        var setup = SampleSetups.diamondDogsAtBombers
        setup.scheduledStart = SampleSetups.gameDay.addingTimeInterval(21 * 24 * 3600)
        var b = LogBuilder(setup, gameID: "game-4")
        b.play("d1", .single, after: [b.on("d1", .first)])
        return b.log(isFinal: false)
    }

    @Test("The record counts two wins and a tie over the three games")
    func record() throws {
        let season = stats.seasonTotals(for: try threeGames(), team: "diamond-dogs")
        #expect(season.games == 3)
        #expect(season.wins == 2)
        #expect(season.losses == 0)
        #expect(season.ties == 1)
    }

    @Test("A game still going counts as a game but not in the record")
    func unfinishedGame() throws {
        let season = stats.seasonTotals(for: try threeGames() + [Self.gameStillGoing()], team: "diamond-dogs")
        #expect(season.games == 4)
        #expect(season.wins + season.losses + season.ties == 3)
        let moreno = try #require(season.batting.first { $0.player == "d1" })
        let last = try #require(moreno.gameLog.last)
        #expect(last.gameID == "game-4")
        #expect(last.result == nil)
        #expect(last.finalScore == nil)
        #expect(last.weAreHome == false)
    }

    @Test("The Mudcats' season has the same games the other way round: 0 wins, 1 loss, 1 tie")
    func otherTeam() throws {
        let season = stats.seasonTotals(for: try threeGames(), team: "mudcats")
        #expect(season.games == 2)
        #expect(season.wins == 0)
        #expect(season.losses == 1)
        #expect(season.ties == 1)
        // Gus Reyes was charged with the go-ahead run in game 1.
        let reyes = try #require(season.pitching.first { $0.player == "m12" })
        #expect(reyes.wins == 0)
        #expect(reyes.losses == 1)
    }

    @Test("Pitchers' wins and losses are counted from each game's decision")
    func pitcherDecisions() throws {
        let season = stats.seasonTotals(for: try threeGames(), team: "diamond-dogs")
        let barros = try #require(season.pitching.first { $0.player == "d9" })
        #expect(barros.games == 3)
        #expect(barros.wins == 2)
        #expect(barros.losses == 0)
        // Voss pitched one inning of game 1 and got no decision.
        let voss = try #require(season.pitching.first { $0.player == "d12" })
        #expect(voss.wins == 0)
        #expect(voss.losses == 0)
    }

    @Test("Each game log entry says home or away, the final score and our result")
    func gameLogResults() throws {
        let season = stats.seasonTotals(for: try threeGames(), team: "diamond-dogs")
        let moreno = try #require(season.batting.first { $0.player == "d1" })
        // Oldest first: the sample game at home, at the Bombers, then the Mudcats at home again.
        #expect(moreno.gameLog.map(\.weAreHome) == [true, false, true])
        #expect(moreno.gameLog.map(\.result) == [.win, .win, .tie])
        #expect(moreno.gameLog.map(\.finalScore) == [Score(away: 3, home: 5), Score(away: 3, home: 0),
                                                     Score(away: 0, home: 0)])
        let barros = try #require(season.pitching.first { $0.player == "d9" })
        #expect(barros.gameLog.map(\.result) == [.win, .win, .tie])
    }

    @Test("The games list reads each result from our side of the score")
    func gameSummaryResult() throws {
        // The sample game: a 5–3 home win.
        #expect(GameSummary(game: SampleGame.game).result == .win)
        #expect(SampleSeason.games.first?.result == .win)

        // A game with no end has no result.
        var going = SampleGame.game
        going.events.removeAll { if case .endOfGame = $0.kind { true } else { false } }
        #expect(GameSummary(game: going).result == nil)

        // The same game seen by the Mudcats, if they were the team marked ours, is a loss.
        var mudcatsView = SampleGame.game
        mudcatsView.setup.home.isOurs = false
        mudcatsView.setup.away.isOurs = true
        #expect(GameSummary(game: mudcatsView).result == .loss)

        // A game between two other teams (a televised game) has no result for us.
        var neither = SampleGame.game
        neither.setup.home.isOurs = false
        #expect(GameSummary(game: neither).result == nil)
    }

    @Test("A result reads the same from runs or from a score and our side")
    func resultFromScore() {
        #expect(GameResult(ourRuns: 7, theirRuns: 5) == .win)
        #expect(GameResult(ourRuns: 2, theirRuns: 3) == .loss)
        #expect(GameResult(ourRuns: 4, theirRuns: 4) == .tie)
        #expect(GameResult(score: Score(away: 11, home: 6), ourSide: .away) == .win)
        #expect(GameResult(score: Score(away: 11, home: 6), ourSide: .home) == .loss)
    }
}
