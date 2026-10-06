// Tests of the play-by-play on logs other than the hand-written sample: the one the real rules
// engine produces for the sample game, and short logs written here for the awkward cases
// (a manual adjustment that sends the game back to a half-inning already listed, the end of
// the game after the sides switch, an empty game). Also: what the fix sheet says about the
// pitch it is fixing and about deleting it, the row cache, and the swipe-back strip.

import Foundation
import SwiftUI
import Testing
import Model
import SampleData
@testable import GameOverview

/// Builds short play logs by hand, one entry at a time.
struct LogWriter {
    var log = SampleGame.throughThreeInnings.log
    private var n = 0

    init() { log.entries = [] }

    /// Adds one entry. `before` and `after` are the counts around it.
    mutating func add(_ kind: EventKind, inning: Int, half: HalfInning, batter: PlayerID? = "d3",
                      before: Count = .fresh, after: Count = .fresh, outs: Int = 0,
                      result: PlateAppearanceOutcome? = nil, notation: String = "") {
        n += 1
        let pa = result.map { PlateAppearanceResult(batter: batter ?? "d3", pitcher: "m9", outcome: $0, batterReachedBase: false) }
        log.entries.append(PlayLogEntry(
            event: GameEvent(id: EventID(rawValue: "t\(n)"), enteredAt: Date(timeIntervalSince1970: Double(n)), kind: kind),
            inning: inning, half: half, batter: batter, batterIndex: nil, pitcher: "m9", fielders: [],
            before: BasesAndOuts(outs: outs, count: before), after: BasesAndOuts(outs: outs, count: after),
            plateAppearance: pa, notation: notation))
    }
}

/// The play-by-play on the rules engine's own play log, and on hand-written short logs.
/// On the main thread, because the "Fix a play" sheet is a screen and screens live there.
@MainActor
struct MoreLogsTests {
    @Test func theRulesEnginesLogGroupsAndOrdersTheSameWay() throws {
        let log = SampleRulesEngine().replay(SampleGame.game).log
        let sections = PlayByPlay.sections(for: log, showPitches: true)
        let rows = sections.flatMap(\.rows)
        // Every event once, newest first all the way down the list.
        #expect(rows.count == log.entries.count)
        #expect(rows.map(\.index) == Array((0..<log.entries.count).reversed()))
        #expect(sections.count == 10)
        #expect(sections.first?.inning == 5 && sections.first?.half == .bottom)
        // The score after the last run matches the box score.
        let lastScoring = try #require(PlayByPlay.rows(for: log).last { $0.details.contains { $0.hasPrefix("Mudcats ") } })
        #expect(lastScoring.details.contains("Mudcats 3, Diamond Dogs 5"))
    }

    @Test func aHalfInningVisitedTwiceGetsTwoSections() {
        var w = LogWriter()
        w.add(.pitch(Pitch(.ball)), inning: 1, half: .top, batter: "m1")
        w.add(.pitch(Pitch(.ball)), inning: 1, half: .bottom)
        // A manual adjustment sends the game back to the top of the 1st.
        w.add(.manualAdjustment(ManualAdjustment(inning: 1, half: .top)), inning: 1, half: .top, batter: "m1")
        let sections = PlayByPlay.sections(for: w.log, showPitches: true)
        #expect(sections.map(\.half) == [.top, .bottom, .top])
        #expect(Set(sections.map(\.id)).count == 3)
        #expect(sections.first?.rows.first?.event.id == "t3")
    }

    @Test func theEndOfTheGameJoinsTheLastHalfInningPlayed() {
        var w = LogWriter()
        w.add(.pitch(Pitch(.swingingStrike)), inning: 5, half: .bottom, before: Count(balls: 0, strikes: 2),
              after: Count(balls: 0, strikes: 3), outs: 3, result: .strikeout, notation: "K")
        // After the third out the sides switch, so the end lands in the top of the 6th.
        w.add(.endOfGame(EndOfGame(reason: .timeLimit)), inning: 6, half: .top, batter: nil)
        let sections = PlayByPlay.sections(for: w.log, showPitches: true)
        #expect(sections.count == 1)
        #expect(sections[0].inning == 5 && sections[0].half == .bottom)
        #expect(sections[0].rows.map(\.event.id) == ["t2", "t1"])
    }

    @Test func anEmptyGameHasNoSections() {
        #expect(PlayByPlay.sections(for: LogWriter().log, showPitches: true).isEmpty)
    }

    @Test func aPitchNamesTheBatterAndTheCount() throws {
        var w = LogWriter()
        w.add(.pitch(Pitch(.ball)), inning: 2, half: .bottom, before: .fresh, after: Count(balls: 1, strikes: 0))
        let row = try #require(PlayByPlay.rows(for: w.log).first)
        #expect(row.text == "Ball to Webb")
        #expect(row.batter == "Webb")
        #expect(row.countBefore == .fresh && row.countAfter == Count(balls: 1, strikes: 0))
        #expect(row.deleteEffect.hasPrefix("Deletes this ball only. The count before it was 0–0"))
    }

    @Test func deletingStrikeThreeSaysOnlyStrikeThreeGoesAndListsTheEarlierPitches() throws {
        var w = LogWriter()
        w.add(.pitch(Pitch(.ball)), inning: 2, half: .bottom, before: .fresh, after: Count(balls: 1, strikes: 0))
        w.add(.pitch(Pitch(.calledStrike)), inning: 2, half: .bottom, before: Count(balls: 1, strikes: 0), after: Count(balls: 1, strikes: 1))
        w.add(.pitch(Pitch(.foul)), inning: 2, half: .bottom, before: Count(balls: 1, strikes: 1), after: Count(balls: 1, strikes: 2))
        w.add(.pitch(Pitch(.swingingStrike)), inning: 2, half: .bottom, before: Count(balls: 1, strikes: 2),
              after: Count(balls: 1, strikes: 3), outs: 1, result: .strikeout, notation: "K")
        // The next batter's first pitch starts a new list.
        w.add(.pitch(Pitch(.ball)), inning: 2, half: .bottom, batter: "d4", after: Count(balls: 1, strikes: 0))
        let rows = PlayByPlay.rows(for: w.log)
        let strikeout = rows[3]
        #expect(strikeout.text == "Webb struck out swinging")
        #expect(strikeout.earlierPitches == ["Ball", "Called strike", "Foul"])
        #expect(strikeout.deleteEffect.hasPrefix("Deletes strike three only. Webb is back up at 1–2"))
        #expect(rows[4].earlierPitches.isEmpty)
        // The fix sheet asks about the play by name and half-inning.
        #expect(FixPlaySheet(row: strikeout) { _ in }.deleteQuestion == "Delete “Webb struck out swinging” (Bottom 2nd)?")
    }

    @Test func aSampleRunnerMoveIsNamedInTheDeleteQuestion() throws {
        let row = try #require(PlayByPlay.rows(for: SampleGame.playLog).first { $0.text == "Cole stole second" })
        #expect(FixPlaySheet(row: row) { _ in }.deleteQuestion == "Delete “Cole stole second” (Bottom 5th)?")
        #expect(row.deleteEffect.hasPrefix("Deletes this runner move."))
    }

    @Test func caughtStealingUsesTheBaseThePlayLogGives() {
        let move = RunnerMove(runner: "Webb", from: .first, to: .out, reason: .caughtStealing)
        #expect(OverviewWording.describe(move, name: { $0.rawValue }, loggedOutAt: .third) == "Webb was caught stealing third")
    }

    @Test func rowsAreBuiltAgainOnlyForANewPlayLog() {
        let cache = RowCache()
        let log = SampleGame.playLog
        _ = cache.rows(for: log)
        _ = cache.rows(for: log)
        #expect(cache.builds == 1)
        var changed = log
        changed.entries.removeLast()
        #expect(cache.rows(for: changed).count == log.entries.count - 1)
        #expect(cache.builds == 2)
    }
}

/// The swipe back to the batting screen. A swipe has to start on the strip along the left
/// edge, which is narrower than the margin before any row's chip or words, so it cannot also
/// tap a row. (Checked by hand too: see the handoff.) On the main thread, like the strip itself.
@MainActor
struct BackSwipeTests {
    @Test func theStripIsNarrowerThanTheRowsInset() {
        // Rows start at the page margin (12) plus the row's own padding (12).
        #expect(BackSwipeStrip.width < 24)
    }

    @Test func onlyARightwardSwipeGoesBack() {
        #expect(BackSwipeStrip.isBackSwipe(CGSize(width: 120, height: 10)))
        #expect(!BackSwipeStrip.isBackSwipe(CGSize(width: -120, height: 0)))
        #expect(!BackSwipeStrip.isBackSwipe(CGSize(width: 40, height: 0)))
        #expect(!BackSwipeStrip.isBackSwipe(CGSize(width: 100, height: 90)))
    }
}
