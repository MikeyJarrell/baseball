// Tests for the game overview's play-by-play: every event listed once, newest first, grouped
// by half-inning; the score after each scoring play matching the box score; the events in
// words; the batter at the plate; and a 400-event game built quickly.
//
// The sample game (SampleData/SampleGame.swift): Mudcats at Diamond Dogs, five innings,
// Diamond Dogs win 5-3; after three innings the Diamond Dogs lead 3-2.

import Foundation
import Testing
import Model
import SampleData
@testable import GameOverview

/// The play-by-play's rows and sections.
struct PlayByPlayTests {
    let log = SampleGame.playLog

    /// The first row in the sample game whose words match.
    func row(_ text: String) -> PlayRow? {
        PlayByPlay.rows(for: log).first { $0.text == text }
    }

    @Test func everyEventIsListedExactlyOnceWithPitchesShown() {
        let sections = PlayByPlay.sections(for: log, showPitches: true)
        let ids = sections.flatMap(\.rows).map(\.id)
        #expect(ids.count == log.entries.count)
        #expect(Set(ids) == Set(log.entries.map(\.event.id)))
    }

    @Test func newestHalfInningAndNewestEventComeFirst() throws {
        let sections = PlayByPlay.sections(for: log, showPitches: true)
        let first = try #require(sections.first)
        // The game ended after the bottom of the 5th; the end of the game is the newest row.
        #expect(first.inning == 5 && first.half == .bottom)
        if case .endOfGame = first.rows.first?.event.kind {} else { Issue.record("The end of the game should be the newest row") }
        let last = try #require(sections.last)
        #expect(last.inning == 1 && last.half == .top)
        // Inside every section, rows run from the newest event to the oldest.
        for section in sections {
            let order = section.rows.map(\.index)
            #expect(order == order.sorted(by: >))
        }
        // Ten half-innings, top 1st to bottom 5th.
        #expect(sections.count == 10)
    }

    @Test func hidingPitchesKeepsEveryPlateAppearance() {
        let shown = PlayByPlay.sections(for: log, showPitches: false).flatMap(\.rows)
        #expect(!shown.contains { $0.isHideablePitch })
        // Every plate appearance still has its row: ball four, strike three and every ball in play.
        let endings = log.entries.filter { $0.plateAppearance != nil }.map(\.event.id)
        let shownIDs = Set(shown.map(\.id))
        #expect(endings.allSatisfy { shownIDs.contains($0) })
        #expect(shown.count < log.entries.count)
    }

    @Test func scoreAfterTheLastRunMatchesTheBoxScore() throws {
        // Mudcats 3, Diamond Dogs 5, visitors first.
        let lastScoring = try #require(PlayByPlay.rows(for: log).last { $0.details.contains { $0.hasPrefix("Mudcats ") } })
        #expect(lastScoring.details.contains("Mudcats \(SampleGame.boxScore.away.runs), Diamond Dogs \(SampleGame.boxScore.home.runs)"))
        #expect(lastScoring.details.contains("Mudcats 3, Diamond Dogs 5"))
    }

    @Test func scoreAfterThreeInningsMatchesThatBoxScore() throws {
        let cut = SampleGame.throughThreeInnings.log
        let lastScoring = try #require(PlayByPlay.rows(for: cut).last { $0.details.contains { $0.hasPrefix("Mudcats ") } })
        #expect(lastScoring.details.contains("Mudcats 2, Diamond Dogs 3"))
    }

    @Test func firstRunOfTheGameNamesWhoScored() throws {
        // Webb's double in the bottom of the 1st scored Moreno.
        let double = try #require(row("Webb doubled to right"))
        #expect(double.notation == "2B 9")
        #expect(double.isHit)
        #expect(double.details.contains("Moreno scored"))
        #expect(double.details.contains("Mudcats 0, Diamond Dogs 1"))
    }

    @Test func outsAreCountedOnTheRowThatMadeThem() throws {
        let doublePlay = try #require(row("Ruiz grounded into a double play"))
        #expect(doublePlay.notation == "6-4-3 DP")
        #expect(doublePlay.details.contains("2 outs"))
        let flyOut = try #require(row("Hale flied out to center"))
        #expect(flyOut.details.contains("3 outs"))
    }

    @Test func eventsInWords() {
        #expect(row("Diaz homered to left")?.notation == "HR 7")
        #expect(row("Ford struck out swinging")?.notation == "K")
        #expect(row("Moreno walked")?.notation == "BB")
        #expect(row("Diaz lined into a double play")?.notation == "L4-3 DP")
        #expect(row("Tate laid down a sacrifice bunt") != nil)
        #expect(row("Webb ran for Quinn") != nil)
        #expect(row("Webb was caught stealing second") != nil)
        #expect(row("Diamond Dogs fielders checked, no changes")?.isMinor == true)
    }

    @Test func runnerMovesInWords() {
        let name: (PlayerID) -> String = { $0.rawValue }
        #expect(OverviewWording.describe(RunnerMove(runner: "Park", from: .first, to: .second, reason: .stolenBase), name: name)
                == "Park stole second")
        #expect(OverviewWording.describe(RunnerMove(runner: "Bell", from: .third, to: .scored, reason: .stolenBase), name: name)
                == "Bell stole home")
        #expect(OverviewWording.describe(RunnerMove(runner: "Kim", from: .second, to: .third, reason: .wildPitch), name: name)
                == "Kim to third on a wild pitch")
        #expect(OverviewWording.describe(RunnerMove(runner: "Hale", from: .first, to: .out, reason: .pickoff, outAt: .first), name: name)
                == "Hale was picked off first")
    }

    @Test func batterAtThePlateShowsThePitchesSoFar() throws {
        // Three events into the top of the 4th: the fielder check, then a ball and a foul to Kim.
        let inputs = GameOverviewSamples.fourthInning(eventsIntoTheFourth: 3)
        let atBat = try #require(PlayByPlay.currentAtBat(log: inputs.log, situation: inputs.situation))
        #expect(atBat.batter == "Kim")
        #expect(atBat.pitches == ["Ball", "Foul"])
        #expect(atBat.summary == "Ball, foul · count 1–1")
    }

    @Test func noBatterAtThePlateBetweenHalfInningsOrAtTheEnd() {
        let third = GameOverviewSamples.thirdInning
        #expect(PlayByPlay.currentAtBat(log: third.log, situation: third.situation) == nil)
        let complete = GameOverviewSamples.completeGame
        #expect(PlayByPlay.currentAtBat(log: complete.log, situation: complete.situation) == nil)
    }

    @Test func aFlaggedEventCarriesItsWarning() throws {
        var flagged = log
        flagged.entries[5].needsReview = true
        flagged.entries[5].reviewNote = "Ortiz is no longer on first."
        let row = try #require(PlayByPlay.rows(for: flagged).first { $0.index == 5 })
        #expect(row.reviewNote == "Ortiz is no longer on first.")
        // A flagged pitch is never hidden.
        #expect(!row.isHideablePitch)
    }

    @Test func fourHundredEventsBuildQuickly() {
        let long = GameOverviewSamples.longLog(events: 400)
        #expect(long.entries.count == 400)
        #expect(Set(long.entries.map(\.event.id)).count == 400)
        let start = Date()
        let rows = PlayByPlay.rows(for: long)
        let shown = PlayByPlay.sections(from: rows, showPitches: true)
        let hidden = PlayByPlay.sections(from: rows, showPitches: false)
        let seconds = Date().timeIntervalSince(start)
        #expect(shown.flatMap(\.rows).count == 400)
        #expect(hidden.flatMap(\.rows).count < 400)
        // Well under a frame's worth of work per scroll is not needed (rows are built once),
        // but building them must not make opening the tab feel slow.
        #expect(seconds < 0.25, "Building 400 rows took \(seconds) seconds")
    }
}
