// Tests of scoring a game through a `GameSession`, the way the app does it: every event saved
// first, then replayed, then the box score worked out.
//
// The big checks score whole games event by event, the sample game and the three Major League
// games from Retrosheet, and compare the final box score with the one already checked by hand
// (the sample game) or with the official box score (the Major League games). Smaller checks
// cover undo and redo, the automatic out for a batting hole, the dropped third strike, the two
// prompts, and resuming a game from the files after the app closes.

import Foundation
import Testing
import Model
import SampleData
import GameEngine
import Stats
import Storage
import TestSupport
@testable import Scoring

@MainActor
@Suite("Scoring a game through the session")
struct GameSessionTests {

    /// A session for an empty copy of a game (same id and setup, no events), saved in memory.
    func emptySession(like game: Game, storage: any ScorebookStorage = InMemoryStorage()) async throws -> GameSession {
        let empty = Game(id: game.id, setup: game.setup)
        try await storage.saveGame(empty)
        return GameSession(game: empty, storage: storage)
    }

    /// Records every event of a game one at a time, leaving out the automatic outs, which the
    /// session adds itself.
    func score(_ events: [GameEvent], in session: GameSession) async {
        for event in events where !event.isAutomaticOut {
            let saved = await session.record(event)
            #expect(saved)
        }
    }

    @Test("The sample game scored event by event gives the sample box score")
    func sampleGame() async throws {
        let session = try await emptySession(like: SampleGame.game)
        await score(SampleGame.game.events, in: session)
        #expect(session.isFinished)
        #expect(session.game.events == SampleGame.game.events)
        #expect(session.boxScore == SampleGame.boxScore)
    }

    @Test("Each Major League game scored event by event matches its official box score",
          arguments: ["retrosheet/2019-04-21-royals-at-yankees", "retrosheet/2019-05-08-mets-at-padres",
                      "retrosheet/2019-06-23-astros-at-yankees"])
    func majorLeagueGame(name: String) async throws {
        let scenario = try Scenarios.load(name)
        let session = try await emptySession(like: scenario.game)
        await score(scenario.events, in: session)
        #expect(scenario.expected.mismatches(box: session.boxScore) == [])
        #expect(scenario.expected.mismatches(situation: session.situation) == [])
    }

    @Test("Saved to files, closed and reopened, the game in progress comes back exactly")
    func resumeFromFiles() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("scoring-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        let scenario = try Scenarios.load("retrosheet/2019-06-23-astros-at-yankees")
        let half = scenario.events.count / 2

        // Score the first half, then let the storage and the session go, as when the app closes.
        var firstHalf: Game
        do {
            let storage = try FileStorage(dataFolder: folder.appendingPathComponent("data"),
                                          backupsFolder: folder.appendingPathComponent("backups"))
            let session = try await emptySession(like: scenario.game, storage: storage)
            await score(Array(scenario.events.prefix(half)), in: session)
            firstHalf = session.game
        }

        // Reopen: the game in progress is the same game, and scoring the rest finishes it.
        let storage = try FileStorage(dataFolder: folder.appendingPathComponent("data"),
                                      backupsFolder: folder.appendingPathComponent("backups"))
        let resumed = try #require(try await storage.gameInProgress())
        #expect(resumed == firstHalf)
        let session = GameSession(game: resumed, storage: storage)
        await score(Array(scenario.events.dropFirst(half)), in: session)
        #expect(scenario.expected.mismatches(box: session.boxScore) == [])
        #expect(try await storage.gameInProgress() == nil)
        #expect(try await storage.finishedGames().items.map(\.id) == [scenario.game.id])
    }

    @Test("Undo takes back the last event and Redo puts it back, with labels for both")
    func undoAndRedo() async throws {
        let session = try await emptySession(like: SampleGame.game)
        let events = SampleGame.game.events
        // Up to and including the first ball in play.
        let firstPlay = try #require(events.firstIndex { if case .ballInPlay = $0.kind { true } else { false } })
        await score(Array(events[...firstPlay]), in: session)
        let before = session.situation
        let label = try #require(session.undoLabel)
        #expect(label != "ball in play")   // the notation, such as "6-3"
        #expect(session.redoLabel == nil)

        #expect(await session.undo())
        #expect(session.game.events.count == firstPlay)
        #expect(session.redoLabel == label)
        #expect(await session.redo())
        #expect(session.situation == before)
        #expect(session.redoLabel == nil)

        // Recording something new after an undo clears Redo.
        #expect(await session.undo())
        #expect(await session.record(events[firstPlay]))
        #expect(session.redoLabel == nil)

        // Undo all the way back to the start, then nothing is left to undo.
        while session.canUndo { #expect(await session.undo()) }
        #expect(session.game.events.isEmpty)
        #expect(session.undoLabel == nil)
        #expect(await session.undo() == false)
    }

    @Test("A batting hole coming up gets its automatic out, and Undo takes it back with the play before it")
    func automaticOut() async throws {
        let scenario = try Scenarios.load("batting-hole-automatic-out")
        let session = try await emptySession(like: scenario.game)
        await score(scenario.events, in: session)
        // The session recorded the automatic out itself, so the game matches the scenario's.
        #expect(session.game.events.map(\.kind) == scenario.events.map(\.kind))
        #expect(scenario.expected.mismatches(situation: session.situation) == [])

        // Undo removes the single and the automatic out together; Redo brings both back.
        #expect(await session.undo())
        #expect(session.game.events.count == 1)
        #expect(await session.redo())
        #expect(session.game.events.map(\.kind) == scenario.events.map(\.kind))
    }

    @Test("Dropped third strike: the play goes on the strike-three pitch, which keeps its id")
    func droppedThirdStrike() async throws {
        let setup = SampleGame.game.setup
        let session = try await emptySession(like: Game(id: "dropped-k", setup: setup))
        for result in [PitchResult.swingingStrike, .swingingStrike] {
            await session.record(GameEvent(kind: .pitch(Pitch(result))))
        }
        let batter = try #require(session.situation.batter)
        let strikeThree = GameEvent(kind: .pitch(Pitch(.swingingStrike)))
        await session.record(strikeThree)
        #expect(session.situation.outs == 1)
        let before = try #require(session.situationBeforeStrikeThree)
        #expect(before.batter == batter)
        #expect(before.count.strikes == 2)

        // The catcher dropped it and the batter beat the throw to first.
        let play = Play(batterResult: .reachedOnDroppedThirdStrike, fielders: [.catcher],
                        runners: [RunnerMove(runner: batter, from: .home, to: .safe(at: .first))])
        #expect(await session.addDroppedThirdStrike(play))
        #expect(session.game.events.count == 3)
        #expect(session.game.events.last?.id == strikeThree.id)
        #expect(session.situation.outs == 0)
        #expect(session.situation.runner(on: .first)?.runner == batter)
    }

    @Test("A failed save leaves the game unchanged and says so")
    func failedSave() async throws {
        // The game was never saved, so storage cannot add an event to it.
        let session = GameSession(game: Game(id: "never-saved", setup: SampleGame.game.setup),
                                  storage: InMemoryStorage())
        let saved = await session.record(GameEvent(kind: .pitch(Pitch(.ball))))
        #expect(!saved)
        #expect(session.game.events.isEmpty)
        #expect(session.saveProblem != nil)
    }

    @Test("Later on the defense check keeps it closed until the next event")
    func defenseCheckLater() async throws {
        // The sample game: the Diamond Dogs are home, so they take the field first.
        let session = try await emptySession(like: SampleGame.game)
        #expect(session.showsDefenseCheck)
        session.postponeDefenseCheck()
        #expect(!session.showsDefenseCheck)
        // Undo cannot go back past the start, so the check stays put until something is recorded.
        await session.record(GameEvent(kind: .pitch(Pitch(.ball))))
        #expect(session.showsDefenseCheck == session.situation.defenseCheckDue)
    }

    @Test("Two Undos and two Redos tapped at once are made one after the other, nothing saved twice")
    func quickDoubleTaps() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("double-tap-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        let storage = try FileStorage(dataFolder: folder.appendingPathComponent("data"),
                                      backupsFolder: folder.appendingPathComponent("backups"))
        let session = try await emptySession(like: SampleGame.game, storage: storage)
        await score(Array(SampleGame.game.events.prefix(12)), in: session)
        let full = session.game

        async let first = session.undo()
        async let second = session.undo()
        #expect(await [first, second] == [true, true])
        #expect(session.game.events == Array(full.events.dropLast(2)))
        #expect(Set(session.redoStack.map(\.id)).count == 2)

        async let third = session.redo()
        async let fourth = session.redo()
        #expect(await [third, fourth] == [true, true])
        #expect(session.game.events == full.events)
        #expect(Set(session.game.events.map(\.id)).count == session.game.events.count)
        // The file holds exactly what the screen shows.
        #expect(try await storage.loadGame(full.id) == full)
    }

    @Test("Reopening a game saved just before its automatic out records that out first")
    func resumeRecordsAWaitingAutomaticOut() async throws {
        let scenario = try Scenarios.load("batting-hole-automatic-out")
        let storage = InMemoryStorage()
        // Saved with the single, but the phone died before the automatic out was saved.
        let saved = Game(id: scenario.game.id, setup: scenario.game.setup,
                         events: scenario.events.filter { !$0.isAutomaticOut })
        try await storage.saveGame(saved)
        #expect(GameSession(game: saved, storage: storage).situation.isBattingHoleUp)

        let session = await GameSession.resume(saved, storage: storage)
        #expect(session.game.events.map(\.kind) == scenario.events.map(\.kind))
        #expect(!session.situation.isBattingHoleUp)
        #expect(try await storage.loadGame(saved.id) == session.game)
    }

    @Test("A player edited during a game keeps the saved team's songs, introduction and usual spot")
    func savedCopyKeepsTeamDetails() {
        let saved = Player(id: "d1", name: "Alex Moreno", number: "2", walkUpSongID: "new-song",
                           warmUpSongID: "warm", introduction: AnnouncerIntroduction(source: .recorded, fileName: "new.m4a"),
                           usualPosition: .secondBase, usualRole: .batsAndFields, usuallyLeadsOff: true)
        // The game's copy, from the first pitch, with an old song and no introduction; the
        // scorer has just fixed the number and batting side.
        let fromGame = Player(id: "d1", name: "Alex Moreno", number: "12", bats: .left, walkUpSongID: "old-song")
        let updated = fromGame.savedCopy(updating: saved)
        #expect(updated.number == "12")
        #expect(updated.bats == .left)
        #expect(updated.walkUpSongID == "new-song")
        #expect(updated.warmUpSongID == "warm")
        #expect(updated.introduction == saved.introduction)
        #expect(updated.usualPosition == .secondBase)
        #expect(updated.usuallyLeadsOff)
    }
}
