// Undo and editing: undo removes the last event, and fixing a mistake means editing one event
// in the middle of the list. Either way the whole game is replayed, so these tests check that
// the replay gives back the earlier situation, that later events follow an edit, and that an
// event that no longer makes sense is flagged instead of crashing anything. Also: replaying a
// whole game after every tap is fast enough.

import Foundation
import Testing
import Model
import GameEngine
import TestSupport

@Suite("Undo, edits, and speed")
struct EditAndUndoTests {
    let engine = ScorebookRulesEngine()

    @Test("Undo: dropping the last event gives back exactly the situation before it, all game long")
    func undoEverywhere() throws {
        let (game, _) = try NineInningGameTests.game()
        let full = engine.replay(game)
        var previous = engine.replay(Game(id: game.id, setup: game.setup, events: []))
        for k in 1...game.events.count {
            var cut = game
            cut.events = Array(game.events.prefix(k))
            let now = engine.replay(cut)
            // Earlier entries never change because of a later event.
            #expect(now.log.entries == Array(full.log.entries.prefix(k)))
            // Undoing event k gives back the situation after event k - 1.
            var undone = cut
            undone.events.removeLast()
            #expect(engine.replay(undone).situation == previous.situation, "undo of event \(k)")
            previous = now
        }
    }

    @Test("Undoing a third out puts the half-inning back: two outs, the runners, the count")
    func undoThirdOut() throws {
        let scenario = try Scenarios.load("hard-third-out-on-bases-mid-at-bat")
        var game = scenario.game(upThrough: "e6")
        #expect(engine.replay(game).situation.half == .bottom)
        game.events.removeLast()
        let s = engine.replay(game).situation
        #expect(s.inning == 1 && s.half == .top && s.outs == 2)
        #expect(s.count == Count(balls: 1, strikes: 1))
        #expect(s.runners == [BaseRunner(runner: "m3", base: .first, responsiblePitcher: "d9")])
        #expect(s.batter == "m4")
    }

    @Test("Undoing the end of the game reopens it, with the question asked again")
    func undoEndOfGame() throws {
        let scenario = try Scenarios.load("hard-walk-off-single-bases-loaded")
        var game = scenario.game
        #expect(engine.replay(game).situation.isFinal)
        game.events.removeLast()
        let s = engine.replay(game).situation
        #expect(!s.isFinal)
        #expect(s.gameOverQuestion == .regulation)
    }

    @Test("Editing an early hit into an out changes the score and flags the later steal that no longer makes sense")
    func editEarlyPlay() throws {
        let scenario = try Scenarios.load("hard-double-steal-throwing-error")
        var game = scenario.game
        // Ruiz's single becomes a fly out: Ortiz stays on first and Ruiz never reaches.
        game.events[1].kind = .ballInPlay(fly("m2", 8))
        let replay = engine.replay(game)
        let steal = try #require(replay.log.entries.last)
        #expect(steal.needsReview)
        #expect(steal.reviewNote?.contains("Ruiz is not on base") == true)
        #expect(steal.reviewNote?.contains("Ortiz was on first, not second") == true)
        // The engine carries on with what still makes sense: Ortiz still scores on the error.
        #expect(replay.situation.score == Score(away: 1, home: 0))
        #expect(replay.situation.outs == 1)
        #expect(replay.situation.runners.isEmpty)
        #expect(replay.situation.batter == "m3")
        // Only the steal is flagged.
        #expect(replay.log.entries.filter(\.needsReview).count == 1)
    }

    @Test("Editing a home run into a single in the nine-inning game changes the final score and nothing else breaks")
    func editHomeRun() throws {
        var (game, _) = try NineInningGameTests.game()
        let i = try #require(game.events.firstIndex { event in
            if case .ballInPlay(let play) = event.kind { return play.batterResult == .homeRun && play.batterMove?.runner == "m4" }
            return false
        })
        game.events[i].kind = .ballInPlay(hit(.single, "m4", to: 7))
        let replay = engine.replay(game)
        #expect(replay.situation.score == Score(away: 4, home: 6))
        #expect(replay.log.entries.allSatisfy { !$0.needsReview })
        #expect(replay.log.entries[i].notation == "1B 7")
        // Diaz is stranded at first when the second inning ends.
        let endOfSecond = try #require(replay.log.entries.first { $0.inning == 2 && $0.half == .top && $0.endsHalfInning })
        #expect(endOfSecond.after.runners.map(\.runner) == ["m4"])
    }

    @Test("Deleting a ball in the middle of a walk leaves the next batter's play pointing at the wrong batter, flagged")
    func deleteMidAtBat() throws {
        let scenario = try Scenarios.load("hard-bases-loaded-walk")
        var game = scenario.game
        // Remove the fourth ball to Ortiz: Ortiz is now 3-0 and the next four balls go to Ortiz.
        game.events.remove(at: 3)
        let replay = engine.replay(game)
        #expect(replay.log.entries.allSatisfy { !$0.needsReview })
        // Fifteen balls: three walks and a 3-0 count on Diaz.
        #expect(replay.situation.count == Count(balls: 3, strikes: 0))
        #expect(replay.situation.batter == "m4")
        #expect(replay.situation.score == Score())
    }

    @Test("Inserting a forgotten pitching change moves later pitches and the walk to the new pitcher")
    func insertPitchingChange() throws {
        let scenario = try Scenarios.load("pattern-6-3-groundout")
        var game = scenario.game
        game.events.insert(GameEvent(id: "pc", enteredAt: game.events[0].enteredAt, kind: .pitchingChange(PitchingChange(team: .home, newPitcher: "d12"))), at: 1)
        let s = engine.replay(game).situation
        #expect(s.tally(for: "d9") == PitcherTally(pitcher: "d9", team: .home, pitches: 1, strikes: 0, battersFaced: 0))
        #expect(s.tally(for: "d12") == PitcherTally(pitcher: "d12", team: .home, pitches: 2, strikes: 2, battersFaced: 1))
    }

    @Test("Nonsense never crashes the replay: thousands of random events, each one either applied or flagged")
    func randomEventsNeverCrash() throws {
        let setup = try Scenarios.setup(named: "standard")
        var rng = SeededRandom(seed: 2026)
        let players: [PlayerID] = (1...12).flatMap { [PlayerID(rawValue: "m\($0)"), PlayerID(rawValue: "d\($0)")] } + ["nobody"]
        func anyPlayer() -> PlayerID { players[rng.next(players.count)] }
        func anyBase() -> Base { Base.allCases[rng.next(4)] }
        func anyEnd() -> RunnerEnd { RunnerEnd.allCases[rng.next(RunnerEnd.allCases.count)] }
        func anyPosition() -> Position { Position.allCases[rng.next(9)] }
        func anyMoves() -> [RunnerMove] {
            (0..<rng.next(4)).map { _ in RunnerMove(runner: anyPlayer(), from: anyBase(), to: anyEnd(), outBy: [anyPosition()]) }
        }
        var events: [GameEvent] = []
        let start = setup.scheduledStart
        for n in 0..<3000 {
            let kind: EventKind
            switch rng.next(14) {
            case 0, 1, 2, 3: kind = .pitch(Pitch(PitchResult.allCases[rng.next(PitchResult.allCases.count)],
                                                 droppedThirdStrike: rng.next(10) == 0 ? Play(batterResult: .out, runners: anyMoves()) : nil))
            case 4, 5: kind = .ballInPlay(Play(batterResult: BatterResult.allCases[rng.next(BatterResult.allCases.count)],
                                               fielders: [anyPosition()], runners: anyMoves(), multiOut: rng.next(5) == 0 ? .doublePlay : nil))
            case 6: kind = .runnerAction(RunnerAction(moves: anyMoves(), errors: [ErrorCharge(fielder: anyPosition())]))
            case 7: kind = .substitution(Substitution(team: rng.next(2) == 0 ? .away : .home,
                                                      batting: [BattingChange(kind: .pinchRunner, incoming: anyPlayer(), replacing: anyPlayer())],
                                                      defense: [FielderAssignment(position: anyPosition(), player: anyPlayer())]))
            case 8: kind = .pitchingChange(PitchingChange(team: rng.next(2) == 0 ? .away : .home, newPitcher: anyPlayer(), takesBattingSpotOf: anyPlayer()))
            case 9: kind = .runnerForNonRunner(RunnerForNonRunner(runner: anyPlayer(), replacing: anyPlayer()))
            case 10: kind = .automaticOut(AutomaticOut(team: .away, spotIndex: rng.next(12)))
            case 11: kind = .battingHole(BattingHole(team: .home, spotIndex: rng.next(12)))
            case 12: kind = .manualAdjustment(ManualAdjustment(outs: rng.next(5), batterIndex: rng.next(12)))
            default: kind = .addHitter(AddHitter(team: .home, player: anyPlayer()))
            }
            events.append(GameEvent(id: EventID(rawValue: "r\(n)"), enteredAt: start.addingTimeInterval(Double(n * 5)), kind: kind))
        }
        let replay = engine.replay(Game(id: "random", setup: setup, events: events))
        #expect(replay.log.entries.count == events.count)
        #expect(replay.situation.outs >= 0 && replay.situation.outs < 3)
        #expect(!replay.log.entries.filter(\.needsReview).isEmpty)
    }

    @Test("Fast enough to replay after every tap: a 300-event game, replayed once per event")
    func speed() throws {
        let (game, _) = try NineInningGameTests.game()
        // Pad the nine-inning game to 300 events with fouls at the end.
        var events = game.events
        var t = events.last!.enteredAt
        while events.count < 300 {
            t = t.addingTimeInterval(20)
            events.append(GameEvent(id: EventID(rawValue: "pad\(events.count)"), enteredAt: t, kind: .pitch(Pitch(.foul))))
        }
        let long = Game(id: game.id, setup: game.setup, events: events)

        let clock = ContinuousClock()
        let one = clock.measure { _ = engine.replay(long) }
        // Every tap of a whole game: 300 replays of a growing game.
        let all = clock.measure {
            for k in 1...events.count {
                _ = engine.replay(Game(id: long.id, setup: long.setup, events: Array(events.prefix(k))))
            }
        }
        // Generous limits for an unoptimized test build; the real numbers are far smaller.
        #expect(one < .milliseconds(100), "one replay took \(one)")
        #expect(all < .seconds(10), "300 replays took \(all)")
    }
}

/// A small, repeatable random number source, so the random-events test always plays the same game.
struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    /// A number from 0 up to (not including) `upperBound`.
    mutating func next(_ upperBound: Int) -> Int {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Int((state >> 33) % UInt64(max(upperBound, 1)))
    }
}
