// Tests of Rosters during a game: fixing a team's starting batting order after some of the
// game has been scored. Everything recorded follows the batting spots.

import Foundation
import Testing
import Model
import SampleData
import Storage
@testable import Scoring

@MainActor
@Suite("Fixing the starting lineup during a game")
struct StartingLineupEditTests {

    /// The sample game scored up to its second ball in play, so the visitors' first hitters have batted.
    func sessionAfterTwoPlays(_ count: Int = 2) async throws -> GameSession {
        let storage = InMemoryStorage()
        let empty = Game(id: SampleGame.game.id, setup: SampleGame.game.setup)
        try await storage.saveGame(empty)
        let session = GameSession(game: empty, storage: storage)
        var plays = 0
        for event in SampleGame.game.events where !event.isAutomaticOut {
            if case .ballInPlay = event.kind { plays += 1 }
            if plays == count { break }
            await session.record(event)
        }
        return session
    }

    @Test("Swapping the first two hitters swaps everything they did, and the situation stays the same")
    func swapFirstTwo() async throws {
        let session = try await sessionAfterTwoPlays()
        var team = session.setup.away
        let first = team.battingOrder[0], second = team.battingOrder[1]
        let before = session.situation
        let firstLine = session.boxScore.away.batting.first { $0.player == first }
        team.battingOrder.swapAt(0, 1)

        #expect(await session.editStartingLineup(team, on: .away))

        #expect(session.setup.away.battingOrder.prefix(2) == [second, first])
        #expect(session.situation.outs == before.outs)
        #expect(session.situation.score == before.score)
        // The first spot's line now belongs to the player listed first.
        let secondLine = session.boxScore.away.batting.first { $0.player == second }
        #expect(secondLine?.stats == firstLine?.stats)
        #expect(!session.log.entries.contains { $0.needsReview })
    }

    @Test("Adding a hitter after the order has come around is refused")
    func noLengthChangeAfterTheOrderTurns() async throws {
        let session = try await sessionAfterTwoPlays(30)
        var team = session.setup.away
        team.battingOrder = Array(team.battingOrder.prefix(2))
        #expect(!(await session.editStartingLineup(team, on: .away)))
        #expect(session.saveProblem != nil)
    }
}
