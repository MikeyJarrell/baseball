// Batting orders that change during a game: an order of eleven that grows to thirteen in
// the fifth, a hitter added after the leadoff hitter has already come up, pinch hitters,
// re-entry, and pitchers coming back.

import Foundation
import Testing
import Model
import GameEngine
import TestSupport

@Suite("Batting orders and lineup changes")
struct LineupTests {
    let engine = ScorebookRulesEngine()

    /// The standard setup with the Diamond Dogs batting eleven (Cole and Nash bat only) and a
    /// thirteenth player, Ellis (d13), on the bench.
    static func elevenHitters() throws -> GameSetup {
        var setup = try Scenarios.setup(named: "standard")
        setup.home.battingOrder = (1...11).map { PlayerID(rawValue: "d\($0)") }
        setup.home.roster.append(Player(id: "d13", name: "Morgan Ellis", number: "13"))
        return setup
    }

    @Test("An order of eleven grows to thirteen in the fifth and wraps after the thirteenth hitter")
    func elevenGrowsToThirteen() throws {
        var w = GameWriter(setup: try Self.elevenHitters())
        // Every hitter flies out. Mudcats bat 1 to 9 in a loop; the Diamond Dogs' batters are
        // written out by hand in the order they should come up.
        let mudcats = (1...9).map { PlayerID(rawValue: "m\($0)") }
        var m = 0
        func mudcatsInning(_ w: inout GameWriter) {
            for _ in 0..<3 { w.pa("", fly(mudcats[m % 9], 8)); m += 1 }
        }
        let dogsByInning: [[PlayerID]] = [
            ["d1", "d2", "d3"], ["d4", "d5", "d6"], ["d7", "d8", "d9"], ["d10", "d11", "d1"],
            // Fifth inning: Webb and Ellis are added during the top half.
            ["d2", "d3", "d4"], ["d5", "d6", "d7"], ["d8", "d9", "d10"], ["d11", "d12", "d13"],
        ]
        for (i, batters) in dogsByInning.enumerated() {
            mudcatsInning(&w)
            if i == 4 {
                w.add(.addHitter(AddHitter(team: .home, player: "d12")))
                w.add(.addHitter(AddHitter(team: .home, player: "d13")))
            }
            for batter in batters { w.pa("", fly(batter, 7)) }
        }
        mudcatsInning(&w)

        let replay = engine.replay(w.game)
        let flagged = replay.log.entries.filter(\.needsReview).map { "\($0.event.id): \($0.reviewNote ?? "")" }
        #expect(flagged == [], "every play named the batter the engine had up")
        let s = replay.situation
        #expect(s.inning == 9 && s.half == .bottom)
        #expect(s[.home].battingOrder.count == 13)
        #expect(s[.home].battingOrder.slots[11].players == ["d12"])
        #expect(s[.home].battingOrder.slots[12].players == ["d13"])
        // After the thirteenth hitter, back to the top.
        #expect(s.batter == "d1")
        #expect(s.onDeck == "d2")
    }

    @Test("A hitter added after the last hitter batted is up next, unless the leadoff hitter already came up")
    func addedHitterAfterLastHitter() throws {
        var w = GameWriter(setup: try Self.elevenHitters())
        w.add(.manualAdjustment(ManualAdjustment(inning: 1, half: .bottom, outs: 1, batterIndex: 10)))
        // Nash, the eleventh hitter, singles; Moreno comes up, takes a ball, and Nash is caught
        // stealing.
        w.pa("", hit(.single, "d11", to: 7))
        w.pitches("B")
        w.add(.runnerAction(RunnerAction(moves: [mv("d11", .first, .out, outBy: pos(2, 6), at: .second, reason: .caughtStealing)])))
        // Moreno is still up with 1-0. Adding Webb now does not jump them ahead of Moreno.
        w.add(.addHitter(AddHitter(team: .home, player: "d12")))
        var s = engine.replay(w.game).situation
        #expect(s.batter == "d1")
        #expect(s.count == Count(balls: 1, strikes: 0))

        // Separately: Nash makes the last out of the inning, so the order has just wrapped.
        var v = GameWriter(setup: try Self.elevenHitters())
        v.add(.manualAdjustment(ManualAdjustment(inning: 1, half: .bottom, outs: 2, batterIndex: 10)))
        v.pa("", fly("d11", 8))
        v.add(.addHitter(AddHitter(team: .home, player: "d12")))
        s = engine.replay(v.game).situation
        #expect(s[.home].nextBatterIndex == 11)
        #expect(s[.home].currentBatter == "d12")

        // And when Moreno has come up but the inning ended on the bases, Moreno leads off.
        var u = GameWriter(setup: try Self.elevenHitters())
        u.add(.manualAdjustment(ManualAdjustment(inning: 1, half: .bottom, outs: 2, batterIndex: 10)))
        u.pa("", hit(.single, "d11", to: 7))
        u.add(.runnerAction(RunnerAction(moves: [mv("d11", .first, .out, outBy: pos(1, 3), at: .first, reason: .pickoff)])))
        u.add(.addHitter(AddHitter(team: .home, player: "d12")))
        s = engine.replay(u.game).situation
        #expect(s.inning == 2 && s.half == .top)
        #expect(s[.home].currentBatter == "d1")
    }

    @Test("A pinch hitter bats in the same spot, mid-count, and the count carries on")
    func pinchHitterMidCount() throws {
        var w = try GameWriter.standard()
        w.pitches("BC")
        w.add(.substitution(Substitution(team: .away, batting: [BattingChange(kind: .pinchHitter, incoming: "m10", replacing: "m1")])))
        let s = engine.replay(w.game).situation
        #expect(s.batter == "m10")
        #expect(s.count == Count(balls: 1, strikes: 1))
        #expect(s[.away].battingOrder.slots[0].players == ["m1", "m10"])
        // Ortiz still plays center: the pinch hitter changed only the batting order.
        #expect(s[.away].fielder(at: .centerField) == "m1")
    }

    @Test("Fielding changes: a position switch, a replacement, and a fielder leaving with nobody in their place")
    func fieldingChanges() throws {
        var w = try GameWriter.standard()
        // Diamond Dogs: Tate (ss) and Moreno (2b) switch; Cole (d10) replaces Webb in center
        // without batting; Lang leaves right field empty.
        w.add(.substitution(Substitution(team: .home, defense: [
            FielderAssignment(position: .secondBase, player: "d2"),
            FielderAssignment(position: .shortstop, player: "d1"),
            FielderAssignment(position: .centerField, player: "d10"),
        ], leavesField: ["d7"])))
        let s = engine.replay(w.game).situation
        #expect(s[.home].fielder(at: .secondBase) == "d2")
        #expect(s[.home].fielder(at: .shortstop) == "d1")
        #expect(s[.home].fielder(at: .centerField) == "d10")
        #expect(s[.home].fielder(at: .rightField) == nil)
        // Webb is off the field but still bats third; Cole fields without batting.
        #expect(s[.home].position(of: "d3") == nil)
        #expect(s[.home].battingOrder.slots[2].current == "d3")
        #expect(s[.home].battingOrder.index(of: "d10") == nil)
        // The scorer did the defense check by making the changes.
        #expect(!s.defenseCheckDue)
    }

    @Test("A starter may re-enter only after the substitute has batted, any number of times")
    func reentryCycle() throws {
        var w = try GameWriter.standard()
        // Moss pinch-hits for Ortiz and flies out: Ortiz may come back.
        w.add(.substitution(Substitution(team: .away, batting: [BattingChange(kind: .pinchHitter, incoming: "m10", replacing: "m1")])))
        w.pa("", fly("m10", 8))
        var s = engine.replay(w.game).situation
        #expect(s[.away].eligibleToReenter == [ReentryOption(player: "m1", spotIndex: 0)])
        // Ortiz comes back; then Ash (m11) pinch-hits for Ortiz. Not eligible until Ash bats.
        w.add(.substitution(Substitution(team: .away, batting: [BattingChange(kind: .replacement, incoming: "m1", replacing: "m10")])))
        w.add(.manualAdjustment(ManualAdjustment(batterIndex: 0)))
        w.add(.substitution(Substitution(team: .away, batting: [BattingChange(kind: .pinchHitter, incoming: "m11", replacing: "m1")])))
        s = engine.replay(w.game).situation
        #expect(s[.away].eligibleToReenter == [])
        w.pa("", fly("m11", 9))
        s = engine.replay(w.game).situation
        #expect(s[.away].eligibleToReenter == [ReentryOption(player: "m1", spotIndex: 0)])
        #expect(s[.away].battingOrder.slots[0].players == ["m1", "m10", "m1", "m11"])
    }

    @Test("A batting hole filled again by a substitute stops being a hole")
    func holeFilled() throws {
        var w = try GameWriter.standard()
        w.add(.battingHole(BattingHole(team: .away, spotIndex: 1)))
        w.add(.substitution(Substitution(team: .away, batting: [BattingChange(kind: .replacement, incoming: "m11", replacing: "m2")])))
        let s = engine.replay(w.game).situation
        #expect(!s[.away].battingOrder.slots[1].isHole)
        #expect(s[.away].battingOrder.slots[1].current == "m11")
    }

    @Test("A pitcher who moves to another position stays in the field; a new pitcher can take a batting spot")
    func pitcherMovesAndTakesSpot() throws {
        var w = try GameWriter.standard()
        // Voss relieves Barros, who moves to left field in place of Ford; Voss bats in Ford's spot.
        w.add(.pitchingChange(PitchingChange(team: .home, newPitcher: "d12", previousPitcherMovesTo: .leftField, takesBattingSpotOf: "d6")))
        let s = engine.replay(w.game).situation
        #expect(s[.home].pitcher == "d12")
        #expect(s[.home].fielder(at: .leftField) == "d9")
        #expect(s[.home].position(of: "d6") == nil)
        #expect(s[.home].battingOrder.slots[5].players == ["d6", "d12"])
        #expect(s[.home].battingOrder.slots[8].current == "d9")
        #expect(s[.home].eligibleToPitchAgain == ["d9"])
    }
}
