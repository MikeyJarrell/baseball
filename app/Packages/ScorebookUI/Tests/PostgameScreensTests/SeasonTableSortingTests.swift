// Tests of how the season tables sort and filter. The screens never add anything up; these
// check that sorting puts the right hitters on top, that hitters with no average always sink
// to the bottom, and that the minimum plate appearances filter hides the averages it should.
//
// The one-game season is SampleData's (the sample game, twelve Diamond Dogs). Its batting
// averages, worked out by hand from the sample box score:
//   Cole 2 for 2 (1.000); Moreno, Tate, Shaw, Lang and Barros 1 for 2 (.500);
//   Webb and Quinn 1 for 3 (.333); Ford and Fisk 0 for 1 (.000);
//   Nash did not play and Voss only pitched, so neither has an average.

import Testing
import Model
import SampleData
@testable import PostgameScreens

/// The last names of a list of season lines, in order, to compare with what a test expects.
private func lastNames(_ lines: [SeasonBattingLine]) -> [String] {
    lines.map { String($0.name.split(separator: " ").last ?? "") }
}

private func lastNames(_ lines: [SeasonPitchingLine]) -> [String] {
    lines.map { String($0.name.split(separator: " ").last ?? "") }
}

@Suite("Sorting the season batting table")
struct BattingSortTests {
    let oneGame = SampleSeason.totals.batting

    @Test("Best batting average first, ties in roster order, no average last")
    func averageHighestFirst() {
        let sorted = StatSorting.batting(oneGame, by: SortChoice(column: .average, descending: true),
                                         minimumPlateAppearances: 0)
        #expect(lastNames(sorted) == ["Cole", "Moreno", "Tate", "Shaw", "Lang", "Barros",
                                      "Webb", "Quinn", "Ford", "Fisk", "Nash", "Voss"])
    }

    @Test("Lowest average first still puts players with no average last")
    func averageLowestFirst() {
        let sorted = StatSorting.batting(oneGame, by: SortChoice(column: .average, descending: false),
                                         minimumPlateAppearances: 0)
        #expect(lastNames(sorted) == ["Ford", "Fisk", "Webb", "Quinn", "Moreno", "Tate", "Shaw", "Lang",
                                      "Barros", "Cole", "Nash", "Voss"])
    }

    @Test("In a one-game season the 10 plate appearance filter hides every average, so the order stays the roster's")
    func filterHidesEveryoneInOneGame() {
        let sorted = StatSorting.batting(oneGame, by: SortChoice(column: .average, descending: true),
                                         minimumPlateAppearances: 10)
        #expect(sorted.map(\.player) == oneGame.map(\.player))
        #expect(oneGame.allSatisfy { StatSorting.hidesAverages($0, minimumPlateAppearances: 10) })
    }

    @Test("A hitter under the minimum sinks below everyone with enough plate appearances, even with a better average")
    func filterSinksShortSeasons() {
        let fourteen = PreviewSeason.fourteenGames.batting
        // Nash is 1 for 2 (.500) in 3 plate appearances; Moreno leads the rest at 19 for 52 (.365).
        let filtered = StatSorting.batting(fourteen, by: SortChoice(column: .average, descending: true),
                                           minimumPlateAppearances: 10)
        #expect(lastNames(filtered).prefix(2) == ["Moreno", "Webb"])
        #expect(lastNames(filtered).suffix(2) == ["Nash", "Voss"])

        let everyone = StatSorting.batting(fourteen, by: SortChoice(column: .average, descending: true),
                                           minimumPlateAppearances: 0)
        #expect(lastNames(everyone).first == "Nash")
        #expect(lastNames(everyone).last == "Voss")
    }

    @Test("The filter hides averages below the minimum, not at it")
    func filterBoundary() {
        var line = oneGame[0]
        line.stats.plateAppearances = 10
        #expect(!StatSorting.hidesAverages(line, minimumPlateAppearances: 10))
        line.stats.plateAppearances = 9
        #expect(StatSorting.hidesAverages(line, minimumPlateAppearances: 10))
    }

    @Test("The filter never touches counting columns: home runs sort the same with it on")
    func filterLeavesCountsAlone() {
        let fourteen = PreviewSeason.fourteenGames.batting
        let sorted = StatSorting.batting(fourteen, by: SortChoice(column: .homeRuns, descending: true),
                                         minimumPlateAppearances: 10)
        // Shaw 4, Webb 3, then Quinn and Cole with 2 each in roster order.
        #expect(lastNames(sorted).prefix(4) == ["Shaw", "Webb", "Quinn", "Cole"])
    }

    @Test("Averages print the baseball way, and a dash with no at-bats")
    func averageText() {
        let cole = oneGame.first { $0.player == "d10" }!
        let ford = oneGame.first { $0.player == "d6" }!
        let voss = oneGame.first { $0.player == "d12" }!
        #expect(BattingColumn.average.text(cole.stats) == "1.000")
        #expect(BattingColumn.average.text(ford.stats) == ".000")
        // Ford: hit by a pitch in two plate appearances, so on base 1 of 2.
        #expect(BattingColumn.onBase.text(ford.stats) == ".500")
        #expect(BattingColumn.average.text(voss.stats) == "—")
        #expect(BattingColumn.games.text(cole.stats, games: cole.games) == "1")
    }
}

@Suite("Sorting the season pitching table")
struct PitchingSortTests {
    let fourteen = PreviewSeason.fourteenGames.pitching

    @Test("Most innings first; innings sort by outs and print as innings and outs")
    func innings() {
        let sorted = StatSorting.pitching(fourteen, by: SortChoice(column: .innings, descending: true), minimumInnings: 0)
        #expect(lastNames(sorted) == ["Barros", "Voss", "Quinn"])
        #expect(sorted.map { PitchingColumn.innings.text($0.stats) } == ["58.1", "21.0", "0.0"])
    }

    @Test("A pitcher with no outs has no rates, prints a dash, and sorts last both ways")
    func ratesWithNoOuts() {
        let up = StatSorting.pitching(fourteen, by: SortChoice(column: .walksAndHitsPerInning, descending: false), minimumInnings: 0)
        let down = StatSorting.pitching(fourteen, by: SortChoice(column: .walksAndHitsPerInning, descending: true), minimumInnings: 0)
        #expect(lastNames(up).last == "Quinn")
        #expect(lastNames(down).last == "Quinn")
        let quinn = fourteen.first { $0.player == "d4" }!
        #expect(PitchingColumn.walksAndHitsPerInning.text(quinn.stats) == "—")
        // Barros: 51 hits and 14 walks in 175 outs (58⅓ innings) is 1.11 an inning.
        let barros = fourteen.first { $0.player == "d9" }!
        #expect(PitchingColumn.walksAndHitsPerInning.text(barros.stats) == "1.11")
    }
}

@Suite("The pitchers' minimum innings")
struct PitchingMinimumTests {
    /// The one-game season's pitchers: Barros, 12 outs (4 innings), 6 hits and 2 walks;
    /// Voss, 3 outs (1 inning), 1 hit and 1 walk. Plus a made-up reliever with one out and
    /// nobody on, whose walks and hits per inning is 0.00.
    let pitchers: [SeasonPitchingLine] = SampleSeason.totals.pitching + [
        SeasonPitchingLine(player: "x1", name: "One Out", games: 1,
                           stats: PitchingCounts(outsRecorded: 1, battersFaced: 1), gameLog: [])
    ]

    @Test("With no minimum, one out and nobody on tops the walks and hits table")
    func noMinimum() {
        let sorted = StatSorting.pitching(pitchers, by: SortChoice(column: .walksAndHitsPerInning, descending: false),
                                          minimumInnings: 0)
        // One Out 0.00, Barros 8 in 4 innings is 2.00, Voss 2 in 1 inning is 2.00 (roster order).
        #expect(lastNames(sorted) == ["Out", "Barros", "Voss"])
    }

    @Test("At 3 innings, only Barros keeps his rates; the others sink, whichever way the column sorts")
    func threeInnings() {
        for descending in [false, true] {
            let sorted = StatSorting.pitching(pitchers, by: SortChoice(column: .walksAndHitsPerInning, descending: descending),
                                              minimumInnings: 3)
            #expect(lastNames(sorted) == ["Barros", "Voss", "Out"])
        }
        #expect(StatSorting.hidesRates(pitchers[1], minimumInnings: 3))
        #expect(!StatSorting.hidesRates(pitchers[0], minimumInnings: 3))
    }

    @Test("Exactly the minimum keeps the rates: 1 inning is 3 outs")
    func boundary() {
        let voss = pitchers[1]
        #expect(voss.stats.outsRecorded == 3)
        #expect(!StatSorting.hidesRates(voss, minimumInnings: 1))
        #expect(StatSorting.hidesRates(voss, minimumInnings: 2))
    }

    @Test("The minimum never touches counting columns: innings sort the same with it on")
    func countsUntouched() {
        let sorted = StatSorting.pitching(pitchers, by: SortChoice(column: .innings, descending: true), minimumInnings: 20)
        #expect(lastNames(sorted) == ["Barros", "Voss", "Out"])
    }

    @Test("The chips' words")
    func chipWords() {
        #expect(MinimumInnings.label(3) == "At least 3 innings")
        #expect(MinimumInnings.label(1) == "At least 1 inning")
        #expect(MinimumInnings.label(0) == "Rates for everyone")
        #expect(MinimumPlateAppearances.label(0) == "Averages for everyone")
        #expect(MinimumPlateAppearances.choiceLabel(0) == "Everyone")
    }
}

@Suite("Tapping a column heading")
struct SortChoiceTests {
    @Test("A new column starts biggest first; tapping it again flips it")
    func tapping() {
        var choice = SortChoice(column: BattingColumn.average, descending: true)
        choice.choose(.homeRuns)
        #expect(choice == SortChoice(column: .homeRuns, descending: true))
        choice.choose(.homeRuns)
        #expect(choice == SortChoice(column: .homeRuns, descending: false))
        choice.choose(.average)
        #expect(choice == SortChoice(column: .average, descending: true))
    }

    @Test("Walks and hits per inning starts lowest first, since lower is better")
    func lowerIsBetterColumns() {
        var choice = SortChoice(column: PitchingColumn.innings, descending: true)
        for column in PitchingColumn.allCases where column != .innings {
            choice.choose(column, firstDescending: !column.smallerIsBetter)
            #expect(choice.descending == !(column == .walksAndHitsPerInning || column == .walksPerInning))
        }
    }
}
