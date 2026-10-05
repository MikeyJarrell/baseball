// Tests of fixing a game while it is being scored: Undo passing over a confirmed defense check,
// a late lineup card (the hitter shown was really someone else), switching home and away before
// the first pitch, and changing the date, start time and innings.

import Foundation
import Testing
import Model
import SampleData
import GameEngine
import Storage
import TestSupport
@testable import Scoring

@MainActor
@Suite("Fixing a game mid-game")
struct MidGameFixTests {

    /// A session for an empty copy of the sample game, saved in memory. The Diamond Dogs are
    /// home, so they take the field first.
    func emptySampleSession() async throws -> GameSession {
        let storage = InMemoryStorage()
        let empty = Game(id: SampleGame.game.id, setup: SampleGame.game.setup)
        try await storage.saveGame(empty)
        return GameSession(game: empty, storage: storage)
    }

    /// Records the sample game's events up to (not including) the first one matching.
    func score(until stop: (GameEvent) -> Bool, in session: GameSession) async throws -> Int {
        let events = SampleGame.game.events
        let found = events.firstIndex(where: stop)
        let end = try #require(found)
        for event in events[..<end] where !event.isAutomaticOut { await session.record(event) }
        return end
    }

    @Test("Undo passes over a confirmed defense check to the last real entry, and the check comes back")
    func undoSkipsTheDefenseCheck() async throws {
        let session = try await emptySampleSession()
        // Nothing but the check at the start: nothing to undo.
        await session.record(GameEvent(kind: .defenseConfirmed(DefenseConfirmed(team: .home))))
        #expect(!session.canUndo)
        #expect(session.undoLabel == nil)

        // A ball, then the check confirmed again (as at a changeover): Undo takes the ball,
        // and the check after it goes too.
        await session.record(GameEvent(kind: .pitch(Pitch(.ball))))
        await session.record(GameEvent(kind: .defenseConfirmed(DefenseConfirmed(team: .home))))
        #expect(session.undoLabel == "ball")
        #expect(await session.undo())
        #expect(session.game.events.count == 1)
        let onlyChecks = session.game.events.allSatisfy { $0.isDefenseConfirmed }
        #expect(onlyChecks)
        // Redo puts back the ball only.
        #expect(await session.redo())
        #expect(session.game.events.count == 2)
    }

    @Test("A late lineup card: the hitter shown was really someone new, everywhere in the game")
    func hitterWasReallySomeoneNew() async throws {
        let session = try await emptySampleSession()
        // Up to the second ball in play, so the leadoff hitter has batted and may be on base.
        var plays = 0
        _ = try await score(until: { event in
            if case .ballInPlay = event.kind { plays += 1 }
            return plays == 2
        }, in: session)
        let leadoff = try #require(session.setup.away.battingOrder.first)
        let before = session.situation
        let card = Player(name: "Sam Card", number: "44")

        #expect(await session.correctLineup(.wasReally(side: .away, shown: leadoff, really: card)))

        // He takes the leadoff spot and the old player goes to the bench, still on the roster.
        #expect(session.setup.away.battingOrder.first == card.id)
        #expect(session.setup.away.player(card.id) == card)
        #expect(session.setup.away.player(leadoff) != nil)
        #expect(!session.setup.away.battingOrder.contains(leadoff))
        // Nothing in the record names the old player any more, and the game stands where it did,
        // with the new name wherever the old one was.
        let text = String(decoding: try ScorebookJSON.encode(session.game.events), as: UTF8.self)
        #expect(!text.contains(leadoff.rawValue))
        #expect(session.situation.score == before.score)
        #expect(session.situation.outs == before.outs)
        #expect(session.situation.runners.map(\.runner) == before.runners.map { $0.runner == leadoff ? card.id : $0.runner })
        // His plate appearance so far is his.
        #expect(!session.stats.plateAppearances(of: card.id, in: session.log).isEmpty)
        #expect(session.stats.plateAppearances(of: leadoff, in: session.log).isEmpty)
    }

    @Test("Two hitters swapped by the card trade spots, plate appearances and all")
    func twoHittersSwapped() async throws {
        let session = try await emptySampleSession()
        _ = try await score(until: { if case .ballInPlay = $0.kind { true } else { false } }, in: session)
        let order = session.setup.away.battingOrder
        let first = order[0], third = order[2]
        let thirdPlayer = try #require(session.setup.player(third))
        let firstBefore = session.stats.plateAppearances(of: first, in: session.log).count

        #expect(await session.correctLineup(.wasReally(side: .away, shown: first, really: thirdPlayer)))
        #expect(session.setup.away.battingOrder[0] == third)
        #expect(session.setup.away.battingOrder[2] == first)
        #expect(session.setup.away.roster.count == SampleGame.game.setup.away.roster.count)
        #expect(session.stats.plateAppearances(of: third, in: session.log).count == firstBefore)
    }

    @Test("Before the first pitch a hitter can come out of the order; after it, not")
    func removeFromOrder() async throws {
        let session = try await emptySampleSession()
        let last = try #require(session.setup.away.battingOrder.last)
        #expect(await session.correctLineup(.removeFromOrder(side: .away, player: last)))
        #expect(!session.setup.away.battingOrder.contains(last))

        await session.record(GameEvent(kind: .pitch(Pitch(.ball))))
        let next = try #require(session.setup.away.battingOrder.last)
        #expect(await session.correctLineup(.removeFromOrder(side: .away, player: next)) == false)
        #expect(session.setup.away.battingOrder.contains(next))
    }

    @Test("Home and away switch before the first pitch, and not after it")
    func switchHomeAndAway() async throws {
        let session = try await emptySampleSession()
        await session.record(GameEvent(kind: .defenseConfirmed(DefenseConfirmed(team: .home))))
        let wasHome = session.setup.home
        #expect(session.canSwitchHomeAndAway)
        #expect(await session.switchHomeAndAway())
        #expect(session.setup.away == wasHome)
        #expect(session.setup.weAreHome == false)
        // The check for the team that was fielding first is gone; the new home team's comes up.
        #expect(session.game.events.isEmpty)
        #expect(session.situation.battingSide == .away)
        #expect(session.situation.batter == session.setup.away.battingOrder.first)

        await session.record(GameEvent(kind: .pitch(Pitch(.ball))))
        #expect(!session.canSwitchHomeAndAway)
        #expect(await session.switchHomeAndAway() == false)
        #expect(session.setup.away == wasHome)
    }

    @Test("A substitution before the first pitch moves with its team when home and away switch")
    func switchAfterPregameSubstitution() async throws {
        let session = try await emptySampleSession()
        let bench = try #require(session.setup.home.bench.first)
        let change = Substitution(team: .home, defense: [FielderAssignment(position: .shortstop, player: bench.id)])
        await session.record(GameEvent(kind: .substitution(change)))
        #expect(session.canSwitchHomeAndAway)
        #expect(await session.switchHomeAndAway())
        guard case .substitution(let moved) = session.game.events.first?.kind else { Issue.record("no substitution"); return }
        #expect(moved.team == .away)
        #expect(session.situation.away.fielders.contains { $0.player == bench.id && $0.position == .shortstop })
    }

    @Test("Date, start time and innings change mid-game, and the game is replayed under them")
    func changeDetails() async throws {
        let session = try await emptySampleSession()
        _ = try await score(until: { if case .ballInPlay = $0.kind { true } else { false } }, in: session)
        let newStart = Date(timeIntervalSince1970: 1_800_000_000.7)
        #expect(await session.changeDetails { setup in
            setup.scheduledStart = newStart
            setup.rules.scheduledInnings = 7
        })
        #expect(session.setup.scheduledStart == newStart.wholeSecond)
        #expect(session.setup.scheduledInnings == 7)
        // Innings can never go below one.
        #expect(await session.changeDetails { $0.rules.scheduledInnings = 0 })
        #expect(session.setup.scheduledInnings == 1)
    }

    @Test("The first initial and last name tell teammates with one last name apart")
    func initialAndLastName() {
        #expect(Player(name: "Jake Webb").initialAndLastName == "J. Webb")
        #expect(Player(name: "Mary Ann Webb").initialAndLastName == "M. Webb")
        #expect(Player(name: "Ichiro").initialAndLastName == "Ichiro")
        #expect(Player(number: "22").initialAndLastName == "#22")
    }
}
