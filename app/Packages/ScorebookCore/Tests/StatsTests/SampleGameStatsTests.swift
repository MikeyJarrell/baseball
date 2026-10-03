// The stats engine against the hand-written sample game in SampleData: its box score, its
// box score after three innings, every batter's history, and a one-game season. Each was
// worked out by hand from the game's account, so the stats engine must match them exactly.

import Foundation
import Testing
import Model
import SampleData
@testable import Stats

@Suite("The sample game's stats")
struct SampleGameStatsTests {
    let stats = StatsEngine()

    @Test("The final box score matches the hand-written one exactly")
    func finalBoxScore() {
        let box = stats.boxScore(for: SampleGame.playLog)
        #expect(boxScoreDifferences(box, SampleGame.boxScore) == [])
        #expect(box == SampleGame.boxScore)
    }

    @Test("The box score after three innings matches the hand-written one exactly")
    func boxScoreSoFar() {
        let box = stats.boxScore(for: SampleGame.throughThreeInnings.log)
        #expect(boxScoreDifferences(box, SampleGame.boxScoreThroughThree) == [])
        #expect(box == SampleGame.boxScoreThroughThree)
        #expect(!box.isFinal)
    }

    @Test("Every batter's plate appearances match the hand-written history")
    func batterHistories() {
        let log = SampleGame.playLog
        for (player, history) in SampleGame.plateAppearances {
            #expect(stats.plateAppearances(of: player, in: log) == history, "history for \(player)")
        }
        // Reyes came in to pitch and never batted; Nash never played.
        #expect(stats.plateAppearances(of: "m12", in: log) == [])
        #expect(stats.plateAppearances(of: "d11", in: log) == [])
        // Part way through the game, only the plate appearances so far.
        let soFar = SampleGame.throughThreeInnings.log
        for (player, history) in SampleGame.plateAppearancesThroughThree {
            #expect(stats.plateAppearances(of: player, in: soFar) == history, "history so far for \(player)")
        }
    }

    @Test("A one-game season matches the hand-written season totals")
    func oneGameSeason() {
        let season = stats.seasonTotals(for: [SampleGame.playLog], team: "diamond-dogs")
        #expect(season == SampleSeason.totals)
        // Opponents are left out.
        #expect(!season.batting.contains { $0.player.rawValue.hasPrefix("m") })
    }

    @Test("Runs are charged to the pitcher who put the runner on base")
    func relieverIsNotChargedForInheritedRunners() {
        // Reyes relieved Collins in the bottom of the fourth with nobody on: every run after
        // that was Reyes's own. Ford, hit by Reyes, scored on Fisk's sacrifice fly.
        let box = stats.boxScore(for: SampleGame.playLog)
        #expect(box.pitching("m9")?.runs == 3)
        #expect(box.pitching("m12")?.runs == 2)
        #expect(box.pitching("m9")?.inningsPitchedText == "3.0")
        #expect(box.pitching("d9")?.inningsPitchedText == "4.0")
    }

    @Test("The runner for a designated non-runner keeps their caught stealing on their own line")
    func runnerForNonRunnerInSampleGame() {
        // Webb ran for Quinn and was caught stealing. Webb has a batting spot, so there is no
        // "pr" line under Quinn.
        let box = stats.boxScore(for: SampleGame.playLog)
        #expect(box.batting("d3")?.caughtStealing == 1)
        #expect(box.batting("d4")?.caughtStealing == 0)
        #expect(box.home.batting.filter { $0.positions.contains(.pr) }.isEmpty)
    }
}

/// Lists, in plain words, where two box scores differ: team totals, line score, notes, and
/// each batting, pitching and fielding line. Empty when they are the same. Makes a failing
/// test say what is wrong instead of printing two whole box scores.
func boxScoreDifferences(_ got: BoxScore, _ want: BoxScore) -> [String] {
    var problems: [String] = []
    func compare<T: Equatable>(_ what: String, _ a: T, _ b: T) {
        if a != b { problems.append("\(what): got \(a), expected \(b)") }
    }
    compare("game id", got.gameID, want.gameID)
    compare("date", got.date, want.date)
    compare("final", got.isFinal, want.isFinal)
    compare("line score", got.lineScore, want.lineScore)
    for side in TeamSide.allCases {
        let a = got[side], b = want[side]
        let team = b.name
        compare("\(team) name", a.name, b.name)
        compare("\(team) team id", a.teamID, b.teamID)
        compare("\(team) runs, hits, errors, left on base",
                [a.runs, a.hits, a.errors, a.leftOnBase], [b.runs, b.hits, b.errors, b.leftOnBase])
        compare("\(team) batting order", a.batting.map(\.player), b.batting.map(\.player))
        for (x, y) in zip(a.batting, b.batting) { compare("\(team) batting line \(y.name)", x, y) }
        compare("\(team) pitchers", a.pitching.map(\.player), b.pitching.map(\.player))
        for (x, y) in zip(a.pitching, b.pitching) { compare("\(team) pitching line \(y.name)", x, y) }
        compare("\(team) fielders", a.fielding.map(\.player), b.fielding.map(\.player))
        for (x, y) in zip(a.fielding, b.fielding) { compare("\(team) fielding line \(y.name)", x, y) }
    }
    let n = got.notes, m = want.notes
    compare("errors note", n.errors, m.errors)
    compare("doubles note", n.doubles, m.doubles)
    compare("triples note", n.triples, m.triples)
    compare("home runs note", n.homeRuns, m.homeRuns)
    compare("runs batted in note", n.runsBattedIn, m.runsBattedIn)
    compare("stolen bases note", n.stolenBases, m.stolenBases)
    compare("caught stealing note", n.caughtStealing, m.caughtStealing)
    compare("sacrifice flies note", n.sacrificeFlies, m.sacrificeFlies)
    compare("sacrifice bunts note", n.sacrificeBunts, m.sacrificeBunts)
    compare("hit by pitch note", n.hitByPitch, m.hitByPitch)
    compare("double plays note", n.doublePlays, m.doublePlays)
    compare("triple plays note", n.triplePlays, m.triplePlays)
    compare("left on base note", n.leftOnBase, m.leftOnBase)
    return problems
}
