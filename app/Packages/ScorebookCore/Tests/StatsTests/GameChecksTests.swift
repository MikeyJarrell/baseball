// Tests of the after-game check for unlikely scoring.

import Foundation
import Testing
import Model
import SampleData
import GameEngine
@testable import Stats

@Suite("Unlikely scoring")
struct GameChecksTests {
    @Test("The sample game, scored cleanly, has nothing to ask about")
    func cleanGame() {
        let game = SampleGame.game
        let log = ScorebookRulesEngine().replay(game).log
        let findings = GameChecks.findings(in: game, log: log)
        #expect(!findings.contains { $0.contains("own") })
    }

    @Test("A batter who scores on his own single is flagged")
    func scoringOnOwnSingle() throws {
        var game = SampleGame.game
        let index = try #require(game.events.firstIndex { event in
            if case .ballInPlay(let play) = event.kind { return play.batterResult == .single }
            return false
        })
        guard case .ballInPlay(var play) = game.events[index].kind else { return }
        play.runners = play.runners.map { move in
            var move = move
            if move.isBatter { move.to = .scored }
            return move
        }
        game.events[index].kind = .ballInPlay(play)
        let log = ScorebookRulesEngine().replay(game).log
        #expect(GameChecks.findings(in: game, log: log).contains { $0.contains("scored on his own single") })
    }
}
