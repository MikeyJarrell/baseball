// Tests of the words on the postgame screens: results and the season record from the games
// list, game lengths, the order of games and game logs, and the box score notes.

import Foundation
import Testing
import Model
import SampleData
@testable import PostgameScreens

@Suite("Results and the season record")
struct ResultWordingTests {
    let games = PreviewSeason.games

    @Test("Wins, losses and a tie are read from our side of the score, home or away")
    func outcomes() {
        // g1: at River Rats, we scored 11 as visitors. g2: vs Hammerheads at home, 2–3.
        let g1 = games.first { $0.id == "g1" }!
        let g2 = games.first { $0.id == "g2" }!
        let g7 = games.first { $0.id == "g7" }!  // 4–4 with the Bombers
        #expect(PostgameWording.outcome(of: g1) == .win)
        #expect(PostgameWording.scoreOursFirst(g1) == "11–6")
        #expect(PostgameWording.opponent(g1) == "at River Rats")
        #expect(PostgameWording.outcome(of: g2) == .loss)
        #expect(PostgameWording.scoreOursFirst(g2) == "2–3")
        #expect(PostgameWording.opponent(g2) == "vs Hammerheads")
        #expect(PostgameWording.outcome(of: g7) == .tie)
    }

    @Test("A game still going has no result and does not count in the record")
    func unfinished() {
        let g15 = games.first { $0.id == "g15" }!
        #expect(PostgameWording.outcome(of: g15) == nil)
        #expect(PostgameWording.record(games) == "9 wins, 4 losses, 1 tie")
        #expect(PostgameWording.record([g15]) == nil)
    }

    @Test("The sample game is a 5–3 Diamond Dogs win at home")
    func sampleGame() {
        #expect(PostgameWording.record(SampleSeason.games) == "1 win, 0 losses")
        #expect(PostgameWording.scoreOursFirst(SampleSeason.games[0]) == "5–3")
    }

    @Test("The games list shows the newest game first")
    func newestFirst() {
        let ordered = StatSorting.newestFirst(games)
        #expect(ordered.map(\.id.rawValue) == (1...15).reversed().map { "g\($0)" })
    }

    @Test("A game log shows the newest game first")
    func gameLogNewestFirst() {
        let ordered = StatSorting.newestFirst(PreviewSeason.morenoLog)
        #expect(ordered.map(\.opponentName) == ["Mudcats", "Bombers", "Mudcats"])
        #expect(ordered.first?.gameID == "preview-mudcats-2")
    }
}

@Suite("Game length")
struct GameLengthTests {
    @Test("The sample game's 11,552 seconds is 3 hours 12 minutes")
    func sample() {
        #expect(PostgameWording.gameLength(11_552) == "3 hr 12 min")
        #expect(PostgameWording.gameLengthSpoken(11_552) == "3 hours 12 minutes")
    }

    @Test("Under an hour shows minutes only")
    func short() {
        #expect(PostgameWording.gameLength(48 * 60 + 30) == "48 min")
        #expect(PostgameWording.gameLengthSpoken(60 * 60 + 60) == "1 hour 1 minute")
    }
}

@Suite("The plain box score's words")
struct BoxScoreWordingTests {
    let notes = PostgameWording.notes(SampleGame.boxScore.notes)

    @Test("Notes come in the newspaper's order, errors first")
    func order() {
        #expect(notes.first == "E: Sam Kim, Chris Tate")
        #expect(notes.contains("DP: Mudcats 2, Diamond Dogs 2"))
        #expect(notes.contains("LOB: Mudcats 6, Diamond Dogs 4"))
        #expect(notes.contains("2B: Danny Ruiz, Jordan Webb, Jamie Cole"))
        // No triple plays in the sample game, so no TP note.
        #expect(!notes.contains { $0.hasPrefix("TP") })
    }

    @Test("The hit batter names the pitcher, and the runner for the non-runner gets a sentence")
    func extras() {
        #expect(notes.contains("HBP: Casey Ford (by Gus Reyes)"))
        #expect(notes.last == "Jordan Webb ran for Pat Quinn in the 3rd.")
    }

    @Test("Positions: a starter who only batted is dh, a pinch hitter who stayed in is ph-2b")
    func positions() {
        let home = SampleGame.boxScore.home.batting
        let cole = home.first { $0.player == "d10" }!
        let voss = home.first { $0.player == "d12" }!
        #expect(PostgameWording.positions(cole) == "dh")
        #expect(PostgameWording.positions(voss) == "p")
        let pinch = BattingLine(player: "x", name: "X", batterIndex: 0, positions: [.ph, .secondBase],
                                isSubstitute: true, stats: BattingCounts())
        #expect(PostgameWording.positions(pinch) == "ph-2b")
    }

    @Test("Ordinals and lists of innings")
    func ordinals() {
        #expect([1, 2, 3, 4, 11, 12, 13, 21, 22].map(PostgameWording.ordinal)
                == ["1st", "2nd", "3rd", "4th", "11th", "12th", "13th", "21st", "22nd"])
        #expect(PostgameWording.innings([3, 5, 7]) == "the 3rd, 5th and 7th")
    }
}
