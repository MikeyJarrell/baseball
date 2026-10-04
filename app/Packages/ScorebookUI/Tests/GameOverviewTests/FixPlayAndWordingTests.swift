// Tests for "Fix a play" (what each event can be changed to, and what goes back to the app)
// and for the overview's small words: innings, innings pitched, runners, batting summaries.

import Foundation
import Testing
import Model
import SampleData
@testable import GameOverview

/// What the "Fix a play" sheet offers and hands back.
struct FixPlayTests {
    let ball = GameEvent(id: "e1", enteredAt: Date(timeIntervalSince1970: 1_000), kind: .pitch(Pitch(.ball)))

    @Test func aPitchCanBecomeAnyOtherPitch() {
        let choices = FixPlay.pitchAlternatives(for: ball)
        #expect(!choices.contains(.ball))
        #expect(choices.count == PitchResult.allCases.count - 1)
        #expect(FixPlay.editorDescription(for: ball) == nil)
    }

    @Test func changingAPitchKeepsItsPlaceInTheList() {
        let foul = FixPlay.replacing(ball, with: .foul)
        #expect(foul.id == ball.id)
        #expect(foul.enteredAt == ball.enteredAt)
        #expect(foul.kind == .pitch(Pitch(.foul)))
        // What the app is handed: put the foul where the ball was.
        let action = GameOverviewAction.edit(.replace(foul))
        #expect(action == .edit(.replace(GameEvent(id: "e1", enteredAt: ball.enteredAt, kind: .pitch(Pitch(.foul))))))
    }

    @Test func aDroppedThirdStrikeGoesToItsOwnSteps() {
        let dropped = GameEvent(id: "e2", kind: .pitch(Pitch(.swingingStrike, droppedThirdStrike: Play(batterResult: .reachedOnDroppedThirdStrike))))
        #expect(FixPlay.pitchAlternatives(for: dropped).isEmpty)
        #expect(FixPlay.editorDescription(for: dropped) != nil)
    }

    @Test func aBallInPlayOpensTheInPlaySteps() {
        let play = GameEvent(id: "e3", kind: .ballInPlay(Play(batterResult: .out, fielders: [.shortstop, .firstBase])))
        #expect(FixPlay.pitchAlternatives(for: play).isEmpty)
        #expect(FixPlay.editorDescription(for: play) == "Opens the in-play steps with it filled in")
    }

    @Test func somethingWithNothingToChangeCanOnlyBeDeleted() {
        let walk = GameEvent(id: "e4", kind: .intentionalWalk(IntentionalWalk()))
        let check = GameEvent(id: "e5", kind: .defenseConfirmed(DefenseConfirmed(team: .home)))
        #expect(FixPlay.editorDescription(for: walk) == nil)
        #expect(FixPlay.editorDescription(for: check) == nil)
        #expect(FixPlay.pitchAlternatives(for: walk).isEmpty)
    }

    @Test func everySampleEventOffersSomethingBesidesDelete() {
        // Not required, but a good sign: most events in a real game can be changed in place.
        let rows = PlayByPlay.rows(for: SampleGame.playLog)
        let changeable = rows.filter { !FixPlay.pitchAlternatives(for: $0.event).isEmpty || FixPlay.editorDescription(for: $0.event) != nil }
        #expect(changeable.count > rows.count / 2)
    }
}

/// The overview's small words.
struct OverviewWordingTests {
    @Test func ordinals() {
        let expected = [1: "1st", 2: "2nd", 3: "3rd", 4: "4th", 11: "11th", 12: "12th", 13: "13th",
                        21: "21st", 22: "22nd", 23: "23rd", 101: "101st", 111: "111th"]
        for (n, text) in expected { #expect(OverviewWording.ordinal(n) == text) }
        #expect(OverviewWording.halfInningHeading(.bottom, 3) == "▼ 3rd")
        #expect(OverviewWording.halfInning(.top, 10) == "Top 10th")
    }

    @Test func inningsPitchedTheNewspaperWay() {
        #expect(OverviewWording.inningsPitched(outs: 0) == "0")
        #expect(OverviewWording.inningsPitched(outs: 1) == "⅓")
        #expect(OverviewWording.inningsPitched(outs: 2) == "⅔")
        #expect(OverviewWording.inningsPitched(outs: 9) == "3")
        #expect(OverviewWording.inningsPitched(outs: 7) == "2⅓")
        #expect(OverviewWording.inningsPitched(outs: 17) == "5⅔")
    }

    @Test func runnersOnBase() {
        #expect(OverviewWording.runners([]) == "nobody on")
        #expect(OverviewWording.runners([.second]) == "runner on 2nd")
        #expect(OverviewWording.runners([.third, .first]) == "runners on 1st and 3rd")
        #expect(OverviewWording.runners([.first, .second, .third]) == "bases loaded")
    }

    @Test func whereTheGameStands() throws {
        // After three innings the situation is already the top of the 4th, between half-innings.
        let third = try #require(GameOverviewSamples.thirdInning.situation)
        #expect(OverviewWording.rightNow(third) == "End 3rd")
        let fourth = try #require(GameOverviewSamples.fourthInning(eventsIntoTheFourth: 3).situation)
        #expect(OverviewWording.rightNow(fourth) == "Top 4th, 0 outs, nobody on")
        #expect(OverviewWording.rightNow(SampleGame.finalSituation) == "Final")
    }

    @Test func battingSummaries() throws {
        let mudcats = SampleGame.boxScore.away.batting
        let ortiz = try #require(mudcats.first { $0.player == "m1" })
        #expect(OverviewWording.battingSummary(ortiz) == "2 for 3 · 1 run · cf")
        let moss = try #require(mudcats.first { $0.player == "m10" })
        #expect(OverviewWording.battingSummary(moss) == "0 for 1 · ph")
        let reyes = try #require(mudcats.first { $0.player == "m12" })
        #expect(OverviewWording.battingSummary(reyes) == "has not batted · p")
    }

    @Test func scoreLeadsWithOurTeam() {
        let setup = SampleGame.playLog.setup
        #expect(OverviewWording.score(Score(away: 3, home: 5), setup: setup) == "Diamond Dogs 5, Mudcats 3")
    }

    @Test func hitsAreGreen() {
        #expect(OverviewWording.isHit(.double))
        #expect(!OverviewWording.isHit(.walk))
        #expect(OverviewWording.isHitNotation("1B 7"))
        #expect(!OverviewWording.isHitNotation("BB"))
    }
}
