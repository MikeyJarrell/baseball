// Tests of the words on the postgame screens: results and the season record as the stats
// engine supplies them, game log lines, game lengths, the order of games and game logs, and
// the box score notes.

import Foundation
import Testing
import Model
import SampleData
@testable import PostgameScreens

@Suite("Results and the season record")
struct ResultWordingTests {
    let games = PreviewSeason.games

    @Test("Wins, losses and a tie are read from each game's result, with our score first, home or away")
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

    @Test("The result shown is the one handed over, not worked out again from the score")
    func resultIsRead() {
        // A summary whose result disagrees with its score shows the result it was handed.
        let odd = GameSummary(id: "odd", date: PreviewSeason.day(0), opponentName: "Mudcats", weAreHome: true,
                              finalScore: Score(away: 1, home: 2), isFinished: true, result: .tie)
        #expect(PostgameWording.outcome(of: odd) == .tie)
    }

    @Test("A game still going has no result, and the record comes from the season totals")
    func unfinished() {
        let g15 = games.first { $0.id == "g15" }!
        #expect(PostgameWording.outcome(of: g15) == nil)
        #expect(PostgameWording.record(PreviewSeason.fourteenGames) == "9 wins, 4 losses, 1 tie")
        #expect(PostgameWording.record(PreviewSeason.morenoThreeGames) == "2 wins, 1 loss")
        // No game finished yet: no record.
        let none = SeasonTotals(teamID: "diamond-dogs", teamName: "Diamond Dogs", games: 1,
                                batting: [], pitching: [], fielding: [])
        #expect(PostgameWording.record(none) == nil)
    }

    @Test("The sample game is a 5–3 Diamond Dogs win at home")
    func sampleGame() {
        #expect(PostgameWording.record(SampleSeason.totals) == "1 win, 0 losses")
        #expect(PostgameWording.outcome(of: SampleSeason.games[0]) == .win)
        #expect(PostgameWording.scoreOursFirst(SampleSeason.games[0]) == "5–3")
    }

    @Test("A game log line says home or away and how it came out")
    func gameLogLines() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let log = PreviewSeason.morenoLog
        let date = PostgameWording.shortDate(log[1].date, calendar: calendar)
        #expect(PostgameWording.logGame(log[1], calendar: calendar) == "\(date) at Bombers, W 8–1")
        #expect(PostgameWording.logGame(log[2], calendar: calendar).hasSuffix(" vs Mudcats, L 5–6"))
        // The sample season's log, from the shared sample data.
        let moreno = SampleSeason.totals.batting.first { $0.player == "d1" }!.gameLog[0]
        #expect(PostgameWording.logGame(moreno, calendar: calendar).hasSuffix(" vs Mudcats, W 5–3"))
        // A game still going, and an older log that does not say home or away.
        let going = GameLogEntry(gameID: "g", date: log[0].date, opponentName: "Bombers", weAreHome: false,
                                 stats: BattingCounts())
        #expect(PostgameWording.logGame(going, calendar: calendar).hasSuffix(" at Bombers"))
        let older = GameLogEntry(gameID: "g", date: log[0].date, opponentName: "Bombers", stats: BattingCounts())
        #expect(PostgameWording.logGame(older, calendar: calendar) == PostgameWording.shortDate(log[0].date, calendar: calendar) + " Bombers")
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

@Suite("The question before deleting a game")
struct DeleteQuestionTests {
    let pacific: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return c
    }()

    @Test("From the games list: our name, home or away, the opponent and the date")
    func fromTheList() {
        let date = pacific.date(from: DateComponents(year: 2026, month: 10, day: 4, hour: 9))!
        let home = GameSummary(id: "g", date: date, opponentName: "Mudcats", weAreHome: true, finalScore: nil, isFinished: false)
        #expect(PostgameWording.deleteQuestion(home, ourTeamName: "Diamond Dogs", calendar: pacific)
                == "Delete Diamond Dogs vs Mudcats, Oct 4?")
        var away = home
        away.weAreHome = false
        #expect(PostgameWording.deleteQuestion(away, ourTeamName: nil, calendar: pacific)
                == "Delete the game at Mudcats, Oct 4?")
    }

    @Test("From a box score: our team first, or the visitors at the home team when neither is ours")
    func fromTheBoxScore() {
        let box = SampleGame.boxScore
        let ours = PostgameWording.deleteQuestion(box, ourSide: .home, calendar: pacific)
        #expect(ours.hasPrefix("Delete \(box.home.name) vs \(box.away.name), "))
        let neither = PostgameWording.deleteQuestion(box, ourSide: nil, calendar: pacific)
        #expect(neither.hasPrefix("Delete \(box.away.name) at \(box.home.name), "))
    }
}
