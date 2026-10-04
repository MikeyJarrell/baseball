// Season totals over three games, checked against numbers worked out by hand.
//
// Game 1 (May 2): the complete sample game, Mudcats at Diamond Dogs.
// Game 2 (May 9): Diamond Dogs at the Bombers, who are known only by number. One inning:
//   Moreno singles, Tate walks, Webb homers (3 runs), Quinn strikes out, Shaw grounds out,
//   Ford doubles, Lang flies out. Barros sets down three Bombers. The game is called.
// Game 3 (May 16): Mudcats at Diamond Dogs again. Barros sets down three Mudcats. Moreno
//   walks, Tate singles, Webb strikes out, Quinn forces Tate at second, Nash pinch-hits for
//   Ford and walks, Lang flies out. The game is called.

import Foundation
import Testing
import Model
import SampleData
import TestSupport
@testable import Stats

@Suite("Season totals")
struct SeasonTotalsTests {
    let stats = StatsEngine()

    /// Game 2: Diamond Dogs at the Bombers.
    static func gameAtBombers() -> PlayLog {
        var b = LogBuilder(SampleSetups.diamondDogsAtBombers, gameID: "game-2")
        b.play("d1", .single, after: [b.on("d1", .first)])
        b.pitch("d2", .ball, result: .walk, after: [b.on("d2", .first), b.on("d1", .second)])
        b.play("d3", .homeRun, rbi: 3, scored: ["d1", "d2", "d3"], after: [])
        b.pitch("d4", .swingingStrike, result: .strikeout, outs: [b.out("d4", by: [.catcher])])
        b.quickOut("d5", [.shortstop, .firstBase])
        b.play("d6", .double, after: [b.on("d6", .second)])
        b.quickOut("d7", [.centerField])
        b.pitch("b1", .swingingStrike, result: .strikeout, outs: [b.out("b1", by: [.catcher])])
        b.quickOut("b2", [.shortstop, .firstBase])
        b.quickOut("b3", [.centerField])
        b.endGame(.called)
        return b.log()
    }

    /// Game 3: Mudcats at Diamond Dogs, a week after game 2.
    static func secondMudcatsGame() throws -> PlayLog {
        var setup = try Scenarios.setup(named: "standard")
        setup.scheduledStart = SampleSetups.gameDay.addingTimeInterval(14 * 24 * 3600)
        var b = LogBuilder(setup, gameID: "game-3")
        b.quickOut("m1", [.shortstop, .firstBase])
        b.quickOut("m2", [.leftField])
        b.quickOut("m3", [.centerField])
        b.pitch("d1", .ball, result: .walk, after: [b.on("d1", .first)])
        b.play("d2", .single, after: [b.on("d2", .first), b.on("d1", .second)])
        b.pitch("d3", .swingingStrike, result: .strikeout, outs: [b.out("d3", by: [.catcher])])
        b.play("d4", .fieldersChoice, outs: [b.out("d2", by: [.shortstop, .secondBase], at: .second)],
               after: [b.on("d4", .first), b.on("d1", .third)])
        b.lineupChange(.substitution(Substitution(team: .home, batting: [
            BattingChange(kind: .pinchHitter, incoming: "d11", replacing: "d6"),
        ]))) { $0.putInSlot(.home, 5, "d11") }
        b.pitch("d11", .ball, result: .walk, after: [b.on("d11", .first), b.on("d4", .second), b.on("d1", .third)])
        b.quickOut("d7", [.rightField])
        b.endGame(.called)
        return b.log()
    }

    /// The three games, handed over out of order: the season puts them oldest first.
    func threeGames() throws -> [PlayLog] {
        [try Self.secondMudcatsGame(), SampleGame.playLog, Self.gameAtBombers()]
    }

    @Test("Batting average, on-base and slugging match hand calculations")
    func rates() throws {
        let season = stats.seasonTotals(for: try threeGames(), team: "diamond-dogs")
        #expect(season.games == 3)
        #expect(season.teamName == "Diamond Dogs")
        func line(_ player: PlayerID) throws -> SeasonBattingLine {
            try #require(season.batting.first { $0.player == player })
        }

        // Moreno: game 1 walk, groundout, single; game 2 single; game 3 walk.
        // 2 hits in 3 at-bats = .667; on base 4 times in 5 chances = .800; 2 total bases = .667.
        let moreno = try line("d1")
        #expect(moreno.stats == BattingCounts(plateAppearances: 5, atBats: 3, runs: 2, hits: 2, runsBattedIn: 1, walks: 2))
        #expect(formattedRate(moreno.stats.battingAverage) == ".667")
        #expect(formattedRate(moreno.stats.onBasePercentage) == ".800")
        #expect(formattedRate(moreno.stats.sluggingPercentage) == ".667")

        // Webb: game 1 double, strikeout, error; game 2 home run; game 3 strikeout.
        // 2 hits in 5 at-bats = .400; on base 2 times in 5 = .400; 2 + 4 = 6 total bases = 1.200.
        let webb = try line("d3")
        #expect(webb.stats.atBats == 5 && webb.stats.hits == 2 && webb.stats.strikeouts == 2 && webb.stats.runsBattedIn == 4)
        #expect(formattedRate(webb.stats.battingAverage) == ".400")
        #expect(formattedRate(webb.stats.onBasePercentage) == ".400")
        #expect(formattedRate(webb.stats.sluggingPercentage) == "1.200")

        // Ford: game 1 strikeout, hit by pitch; game 2 double; game 3 lifted for a pinch hitter
        // before batting, but still in the order, so it is a game played.
        // 1 hit in 2 at-bats = .500; on base 2 times in 3 = .667; 2 total bases = 1.000.
        let ford = try line("d6")
        #expect(ford.games == 3)
        #expect(ford.stats == BattingCounts(plateAppearances: 3, atBats: 2, runs: 1, hits: 1, doubles: 1, strikeouts: 1, hitByPitch: 1))
        #expect(formattedRate(ford.stats.battingAverage) == ".500")
        #expect(formattedRate(ford.stats.onBasePercentage) == ".667")
        #expect(formattedRate(ford.stats.sluggingPercentage) == "1.000")

        // Nash: one pinch-hit walk and no at-bats. A dash for average and slugging, 1.000 on base.
        let nash = try line("d11")
        #expect(nash.games == 1 && nash.stats.plateAppearances == 1 && nash.stats.atBats == 0)
        #expect(formattedRate(nash.stats.battingAverage) == "—")
        #expect(formattedRate(nash.stats.onBasePercentage) == "1.000")
        #expect(formattedRate(nash.stats.sluggingPercentage) == "—")

        // Voss held a batting spot in game 1 but never came to the plate: dashes everywhere.
        let voss = try line("d12")
        #expect(voss.games == 1 && voss.stats == BattingCounts())
        #expect(formattedRate(voss.stats.battingAverage) == "—")
        #expect(formattedRate(voss.stats.onBasePercentage) == "—")
        #expect(formattedRate(voss.stats.sluggingPercentage) == "—")
    }

    @Test("Pitching totals and per-inning rates match hand calculations")
    func pitching() throws {
        let season = stats.seasonTotals(for: try threeGames(), team: "diamond-dogs")
        #expect(season.pitching.map(\.player) == ["d9", "d12"])
        let barros = try #require(season.pitching.first { $0.player == "d9" })
        // Game 1: 12 outs, 6 hits, 2 walks, 1 strikeout. Games 2 and 3: 3 outs each, one more
        // strikeout in game 2. 18 outs is 6 innings.
        #expect(barros.games == 3)
        #expect(barros.stats.outsRecorded == 18 && barros.stats.inningsPitchedText == "6.0")
        #expect(barros.stats.hits == 6 && barros.stats.walks == 2 && barros.stats.strikeouts == 2)
        // 2 strikeouts in 6 innings = .333 an inning; 2 walks = .333; 8 walks and hits = 1.333.
        #expect(formattedRate(barros.stats.strikeoutsPerInning) == ".333")
        #expect(formattedRate(barros.stats.walksPerInning) == ".333")
        #expect(formattedRate(barros.stats.walksAndHitsPerInning) == "1.333")
        let voss = try #require(season.pitching.first { $0.player == "d12" })
        #expect(voss.games == 1 && voss.stats.inningsPitchedText == "1.0")
    }

    @Test("Each player's game-by-game log runs oldest first, with the opponent")
    func gameLogs() throws {
        let season = stats.seasonTotals(for: try threeGames(), team: "diamond-dogs")
        let webb = try #require(season.batting.first { $0.player == "d3" })
        #expect(webb.gameLog.map(\.gameID) == [SampleGame.id, "game-2", "game-3"])
        #expect(webb.gameLog.map(\.opponentName) == ["Mudcats", "Bombers", "Mudcats"])
        #expect(webb.gameLog.map(\.stats.homeRuns) == [0, 1, 0])
        #expect(webb.gameLog.map(\.date) == webb.gameLog.map(\.date).sorted())
        // The season line is the game log added up.
        #expect(webb.gameLog.reduce(BattingCounts()) { $0 + $1.stats } == webb.stats)
        let nash = try #require(season.batting.first { $0.player == "d11" })
        #expect(nash.gameLog.map(\.gameID) == ["game-3"])
    }

    @Test("Opponents are left out, and every one of our players is listed once")
    func onlyOurPlayers() throws {
        let season = stats.seasonTotals(for: try threeGames(), team: "diamond-dogs")
        #expect(season.batting.map(\.player) == (1...12).map { PlayerID(rawValue: "d\($0)") })
        #expect(season.pitching.allSatisfy { $0.player.rawValue.hasPrefix("d") })
        #expect(season.fielding.allSatisfy { $0.player.rawValue.hasPrefix("d") })
        // Quinn at first base: 5 putouts in game 1, and one 6-3 groundout in each of games 2
        // and 3. Tate at shortstop: 3 putouts, 1 assist and 1 error in game 1, plus the throw
        // on each of those groundouts.
        #expect(season.fielding.first { $0.player == "d4" }?.stats == FieldingCounts(putouts: 7))
        #expect(season.fielding.first { $0.player == "d2" }?.stats == FieldingCounts(putouts: 3, assists: 3, errors: 1))
    }

    @Test("A season with no games, or none of ours, is empty, not a crash")
    func noGames() throws {
        let empty = stats.seasonTotals(for: [], team: "diamond-dogs")
        #expect(empty.games == 0 && empty.batting.isEmpty && empty.pitching.isEmpty)
        let notOurs = stats.seasonTotals(for: [SampleGame.playLog], team: "someone-else")
        #expect(notOurs.games == 0 && notOurs.batting.isEmpty)
    }
}
