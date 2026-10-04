// Tests that the season record, game results, pitchers' wins and losses and the remembered
// filter minimums read back exactly, and that JSON written before they existed still reads,
// with each missing value taking its default.

import Foundation
import Testing
import Model
import SampleData

@Suite("Season record and filter minimums: saving and reading back")
struct SeasonRecordDecodingTests {
    /// The JSON for a value with some keys taken out, as a file written before they existed.
    func without<T: Encodable>(_ keys: [String], in value: T) throws -> Data {
        var json = try JSONSerialization.jsonObject(with: ScorebookJSON.encode(value)) as! [String: Any]
        for key in keys { json[key] = nil }
        return try JSONSerialization.data(withJSONObject: json)
    }

    @Test("Season totals with a record read back exactly; older totals read as no wins, losses or ties")
    func seasonTotals() throws {
        let totals = SampleSeason.totals
        #expect(totals.wins == 1 && totals.losses == 0 && totals.ties == 0)
        #expect(try roundTrip(totals) == totals)

        let old = try without(["wins", "losses", "ties"], in: totals)
        let read = try ScorebookJSON.decode(SeasonTotals.self, from: old)
        #expect(read.wins == 0 && read.losses == 0 && read.ties == 0)
        #expect(read.batting == totals.batting)
    }

    @Test("A pitching line with wins and losses reads back; an older one reads as 0-0")
    func pitchingLine() throws {
        let barros = try #require(SampleSeason.totals.pitching.first { $0.player == "d9" })
        #expect(barros.wins == 1 && barros.losses == 0)
        #expect(try roundTrip(barros) == barros)

        let old = try without(["wins", "losses"], in: barros)
        let read = try ScorebookJSON.decode(SeasonPitchingLine.self, from: old)
        #expect(read.wins == 0 && read.losses == 0)
        #expect(read.stats == barros.stats)
    }

    @Test("A game log entry with home or away and the result reads back; an older one has none")
    func gameLogEntry() throws {
        let entry = try #require(SampleSeason.totals.batting.first { $0.player == "d1" }?.gameLog.first)
        #expect(entry.weAreHome == true)
        #expect(entry.result == .win)
        #expect(entry.finalScore == Score(away: 3, home: 5))
        #expect(try roundTrip(entry) == entry)

        let old = try without(["weAreHome", "finalScore", "result"], in: entry)
        let read = try ScorebookJSON.decode(GameLogEntry<BattingCounts>.self, from: old)
        #expect(read.weAreHome == nil && read.finalScore == nil && read.result == nil)
        #expect(read.stats == entry.stats)
    }

    @Test("A game summary with a result reads back; an older one has no result")
    func gameSummary() throws {
        let game = try #require(SampleSeason.games.first)
        #expect(game.result == .win)
        #expect(try roundTrip(game) == game)

        let old = try without(["result"], in: game)
        let read = try ScorebookJSON.decode(GameSummary.self, from: old)
        #expect(read.result == nil)
        #expect(read.finalScore == game.finalScore)
    }

    @Test("The filter minimums default to 10 plate appearances and 3 innings, and are remembered")
    func filterMinimums() throws {
        #expect(AppSettings().minimumPlateAppearances == 10)
        #expect(AppSettings().minimumInnings == 3)
        let settings = AppSettings(minimumPlateAppearances: 0, minimumInnings: 5)
        #expect(try roundTrip(settings) == settings)

        // A settings file from before the minimums keeps its other choices and takes the defaults.
        let old = try without(["minimumPlateAppearances", "minimumInnings"], in: AppSettings(fadeSongOnFirstPitch: true))
        let read = try ScorebookJSON.decode(AppSettings.self, from: old)
        #expect(read == AppSettings(fadeSongOnFirstPitch: true))
    }
}
