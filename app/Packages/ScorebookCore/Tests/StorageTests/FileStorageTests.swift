// Tests of the real storage: every kind of team, game and event saved and read back with
// nothing lost, saving after every event fast enough for a whole game, a broken file never
// hiding the others, backups, and the version tag on every file.
//
// Each test gets its own empty folder. Where it matters that something reached the disk,
// the test reads it back through a second, brand-new storage on the same folder.

import Foundation
import Testing
import Model
import SampleData
@testable import Storage

@Suite("Saving and loading files")
struct FileStorageTests {

    // MARK: Teams, songs and settings

    @Test("Every sample team reads back exactly, ours first, and can be replaced or deleted")
    func teams() async throws {
        let folder = try TemporaryFolder()
        let storage = try folder.storage()
        let teams = SampleTeams.all + [SampleTeams.emptyTeam, SampleTeams.unknown()]
        for team in teams { try await storage.saveTeam(team) }

        let loaded = try await folder.storage().loadTeams()
        #expect(loaded.damaged.isEmpty)
        #expect(Set(loaded.items) == Set(teams))
        #expect(loaded.items.count == teams.count)
        #expect(loaded.items.first == SampleTeams.diamondDogs, "Our team comes first")

        // Saving a team with the same id replaces it; deleting removes it.
        var mudcats = SampleTeams.mudcats
        mudcats.roster[0].name = "Renamed"
        try await storage.saveTeam(mudcats)
        try await storage.deleteTeam(SampleTeams.bombers.id)
        try await storage.deleteTeam("never-saved")
        let after = try await folder.storage().loadTeams().items
        #expect(after.count == teams.count - 1)
        #expect(after.contains(mudcats))
        #expect(!after.contains { $0.id == SampleTeams.bombers.id })
    }

    @Test("The song library and settings read back exactly, with defaults before anything is saved")
    func songsAndSettings() async throws {
        let folder = try TemporaryFolder()
        let storage = try folder.storage()
        #expect(try await storage.loadSongLibrary() == SongLibrary())
        #expect(try await storage.loadSettings() == AppSettings())

        let settings = AppSettings(walkUpSongSeconds: 9, fadeSongOnFirstPitch: true,
                                   playIntroductions: false, keepScreenAwakeDuringGames: false)
        try await storage.saveSongLibrary(SampleSongs.library)
        try await storage.saveSettings(settings)

        let fresh = try folder.storage()
        #expect(try await fresh.loadSongLibrary() == SampleSongs.library)
        #expect(try await fresh.loadSettings() == settings)
    }

    // MARK: Games and events

    @Test("The complete sample game and every sample setup read back exactly")
    func wholeGames() async throws {
        let folder = try TemporaryFolder()
        let storage = try folder.storage()
        let setups = [SampleSetups.mudcatsAtDiamondDogs, SampleSetups.diamondDogsAtBombers, SampleSetups.unknownAtDiamondDogs]
        let games = [SampleGame.game] + setups.enumerated().map { Game(id: GameID(rawValue: "setup-\($0.offset)"), setup: $0.element) }
        for game in games { try await storage.saveGame(game) }

        let fresh = try folder.storage()
        for game in games {
            #expect(try await fresh.loadGame(game.id) == game)
        }
        #expect(try await fresh.listGames().items.count == games.count)
    }

    @Test("One of every kind of event, added one at a time, reads back exactly and in order")
    func everyEventKind() async throws {
        let folder = try TemporaryFolder()
        let storage = try folder.storage()
        // All sixteen kinds are in the list (pitch, ball in play, substitution and the rest).
        let kindNames = Set(oneOfEveryEvent.map { String(describing: $0.kind).prefix { $0 != "(" } })
        #expect(kindNames.count == 16)

        let empty = Game(id: "every-kind", setup: SampleSetups.mudcatsAtDiamondDogs)
        try await storage.saveGame(empty)
        for event in oneOfEveryEvent {
            try await storage.appendEvent(event, toGame: empty.id)
        }

        let loaded = try await folder.storage().loadGame(empty.id)
        #expect(loaded.setup == empty.setup)
        #expect(loaded.events.count == oneOfEveryEvent.count)
        for (saved, original) in zip(loaded.events, oneOfEveryEvent) {
            #expect(saved == original, "\(original.kind.label)")
        }
        // The last event was the end of the game, so the game now counts as finished.
        #expect(loaded.isFinished)
    }

    @Test("Each event is on disk the moment it is added, even with a new storage between events")
    func eventOnDiskBeforeReturn() async throws {
        let folder = try TemporaryFolder()
        let game = Game(id: "pitch-by-pitch", setup: SampleSetups.mudcatsAtDiamondDogs)
        try await folder.storage().saveGame(game)
        let pitches = SampleGame.game.events.prefix(5)
        for (index, event) in pitches.enumerated() {
            // A brand-new storage each time, as if the app had been closed and reopened.
            try await folder.storage().appendEvent(event, toGame: game.id)
            let onDisk = try await folder.storage().loadGame(game.id)
            #expect(onDisk.events == Array(pitches.prefix(index + 1)))
        }
    }

    @Test("A 400-event game saved one event at a time takes under a second in total")
    func fourHundredEvents() async throws {
        let folder = try TemporaryFolder()
        let storage = try folder.storage()
        let game = Game(id: "long-game", setup: SampleSetups.mudcatsAtDiamondDogs)
        try await storage.saveGame(game)
        // 400 real events from the sample game, repeated, each with its own id.
        let source = SampleGame.game.events
        let events = (0..<400).map { index in
            GameEvent(id: EventID(rawValue: "long-\(index)"),
                      enteredAt: Date(timeIntervalSince1970: 1_777_741_000 + Double(index) * 20),
                      kind: source[index % source.count].kind)
        }

        let clock = ContinuousClock()
        let elapsed = try await clock.measure {
            for event in events {
                try await storage.appendEvent(event, toGame: game.id)
            }
        }
        print("Saving 400 events one at a time took \(elapsed).")
        #expect(elapsed < .seconds(1), "Took \(elapsed)")

        let loaded = try await folder.storage().loadGame(game.id)
        #expect(loaded.events == events)
    }

    @Test("Undo and edits save the whole game, and the next event goes after them")
    func undoThenAppend() async throws {
        let folder = try TemporaryFolder()
        let storage = try folder.storage()
        var game = Game(id: "undo", setup: SampleSetups.mudcatsAtDiamondDogs)
        try await storage.saveGame(game)
        let events = Array(SampleGame.game.events.prefix(6))
        for event in events.prefix(4) { try await storage.appendEvent(event, toGame: game.id) }

        // Undo the last two events by saving the game without them.
        game.events = Array(events.prefix(2))
        try await storage.saveGame(game)
        try await storage.appendEvent(events[5], toGame: game.id)

        let expected = [events[0], events[1], events[5]]
        #expect(try await storage.loadGame(game.id).events == expected)
        #expect(try await folder.storage().loadGame(game.id).events == expected)
    }

    @Test("Loading or adding to a game that was never saved says it is not found")
    func missingGame() async throws {
        let folder = try TemporaryFolder()
        let storage = try folder.storage()
        await #expect(throws: StorageError.notFound("nowhere")) {
            try await storage.loadGame("nowhere")
        }
        await #expect(throws: StorageError.notFound("nowhere")) {
            try await storage.appendEvent(GameEvent(kind: .pitch(Pitch(.ball))), toGame: "nowhere")
        }
        // Deleting a saved game removes it; deleting one never saved does nothing.
        try await storage.saveGame(SampleGame.game)
        try await storage.deleteGame(SampleGame.id)
        try await storage.deleteGame("nowhere")
        #expect(try await storage.listGames().items.isEmpty)
        await #expect(throws: StorageError.notFound(SampleGame.id.rawValue)) {
            try await storage.loadGame(SampleGame.id)
        }
    }

    // MARK: Lists

    @Test("The games list is newest first, with date, opponent and final score")
    func gamesList() async throws {
        let folder = try TemporaryFolder()
        let storage = try folder.storage()
        let day: TimeInterval = 86_400
        let start = SampleGame.game.setup.scheduledStart
        let finishedEarly = copy(of: SampleGame.game, id: "week-1", startingAt: start)
        let finishedLate = copy(of: SampleGame.game, id: "week-3", startingAt: start.addingTimeInterval(14 * day))
        let unfinished = copy(of: SampleGame.game, id: "week-2", startingAt: start.addingTimeInterval(7 * day), eventCount: 30)
        for game in [finishedEarly, unfinished, finishedLate] { try await storage.saveGame(game) }

        let list = try await folder.storage().listGames()
        #expect(list.damaged.isEmpty)
        #expect(list.items.map(\.id) == ["week-3", "week-2", "week-1"])
        let newest = try #require(list.items.first)
        #expect(newest.date == finishedLate.setup.scheduledStart)
        #expect(newest.opponentName == "Mudcats")
        #expect(newest.weAreHome)
        #expect(newest.isFinished)
        #expect(newest.finalScore == SampleGame.game.ending?.finalScore)
        #expect(newest.finalScore != nil)
        #expect(list.items[1].isFinished == false)
        #expect(list.items[1].finalScore == nil)

        // Finished games, for the season totals, oldest first, without the unfinished one.
        let finished = try await storage.finishedGames()
        #expect(finished.items.map(\.id) == ["week-1", "week-3"])
        #expect(finished.items[0].events == SampleGame.game.events)
    }

    @Test("The game in progress is the unfinished game worked on most recently")
    func gameInProgress() async throws {
        let folder = try TemporaryFolder()
        let storage = try folder.storage()
        #expect(try await storage.gameInProgress() == nil)

        let start = SampleGame.game.setup.scheduledStart
        let week: TimeInterval = 7 * 86_400
        // Finished: never offered for resuming.
        try await storage.saveGame(copy(of: SampleGame.game, id: "finished", startingAt: start.addingTimeInterval(2 * week)))
        #expect(try await storage.gameInProgress() == nil)

        // A game set up but not started is offered when nothing else has been started.
        let setUpEarly = Game(id: "set-up-early", setup: SampleSetups.diamondDogsAtBombers)
        try await storage.saveGame(setUpEarly)
        #expect(try await storage.gameInProgress() == setUpEarly)

        // An unfinished game from a week ago, abandoned in the third inning, has been started,
        // so it beats any game not yet started.
        let abandoned = copy(of: SampleGame.game, id: "abandoned", startingAt: start, eventCount: 40)
        try await storage.saveGame(abandoned)
        #expect(try await storage.gameInProgress()?.id == "abandoned")

        // Today's game, 30 events in, is newer than the abandoned one.
        let today = copy(of: SampleGame.game, id: "today", startingAt: start.addingTimeInterval(3 * week), eventCount: 30)
        try await storage.saveGame(today)
        #expect(try await folder.storage().gameInProgress() == today)

        // Once today's game is over, the abandoned one is the game left to resume.
        try await storage.appendEvent(GameEvent(enteredAt: start.addingTimeInterval(3 * week + 9_000),
                                                kind: .endOfGame(EndOfGame(reason: .called))), toGame: "today")
        #expect(try await storage.gameInProgress()?.id == "abandoned")
    }

    @Test("A game set up in advance for next week never takes over from today's game in progress")
    func gameSetUpInAdvance() async throws {
        let folder = try TemporaryFolder()
        let storage = try folder.storage()
        // Today's game, 30 events in, entered just now.
        let now = Date().wholeSecond
        var today = Game(id: "today", setup: SampleSetups.mudcatsAtDiamondDogs)
        today.setup.scheduledStart = now.addingTimeInterval(-3_600)
        today.events = SampleGame.game.events.prefix(30).enumerated().map { index, event in
            GameEvent(id: event.id, enteredAt: now.addingTimeInterval(Double(index - 30) * 60), kind: event.kind)
        }
        try await storage.saveGame(today)

        // Then, between innings, the coach sets up next Saturday's game.
        var nextWeek = Game(id: "next-week", setup: SampleSetups.diamondDogsAtBombers)
        nextWeek.setup.scheduledStart = now.addingTimeInterval(7 * 86_400)
        try await storage.saveGame(nextWeek)

        #expect(try await folder.storage().gameInProgress()?.id == "today")

        // And with two unstarted games, the one saved last is offered, whatever its date.
        try await storage.deleteGame("today")
        var tomorrow = Game(id: "tomorrow", setup: SampleSetups.mudcatsAtDiamondDogs)
        tomorrow.setup.scheduledStart = now.addingTimeInterval(86_400)
        try await storage.saveGame(tomorrow)
        #expect(try await folder.storage().gameInProgress()?.id == "tomorrow")
    }

    // MARK: Damaged files

    @Test("A corrupted game file is reported as damaged and every other game still loads")
    func corruptedGame() async throws {
        let folder = try TemporaryFolder()
        let storage = try folder.storage()
        let start = SampleGame.game.setup.scheduledStart
        let good = copy(of: SampleGame.game, id: "good", startingAt: start)
        let inProgress = copy(of: SampleGame.game, id: "in-progress", startingAt: start.addingTimeInterval(86_400), eventCount: 20)
        let broken = copy(of: SampleGame.game, id: "broken", startingAt: start.addingTimeInterval(2 * 86_400))
        for game in [good, inProgress, broken] { try await storage.saveGame(game) }

        // Cut the broken game's file off halfway, as a crash in the middle of a careless write would.
        let whole = try folder.contents(of: "games/broken.json")
        try folder.overwrite("games/broken.json", with: whole.prefix(whole.count / 2))

        let fresh = try folder.storage()
        let list = try await fresh.listGames()
        #expect(list.items.map(\.id) == ["in-progress", "good"])
        #expect(list.damaged.map(\.fileName) == ["games/broken.json"])
        #expect(list.damaged.first?.reason.contains("cut off") == true)

        let finished = try await fresh.finishedGames()
        #expect(finished.items == [good])
        #expect(finished.damaged.map(\.fileName) == ["games/broken.json"])
        #expect(try await fresh.gameInProgress() == inProgress)
        #expect(try await fresh.loadGame("good") == good)

        do {
            _ = try await fresh.loadGame("broken")
            Issue.record("A cut-off game file should not load")
        } catch StorageError.damaged(let file, _) {
            #expect(file == "games/broken.json")
        }

        // Saving the game again over the damaged file mends it.
        try await fresh.saveGame(broken)
        #expect(try await fresh.listGames().damaged.isEmpty)
    }

    @Test("Garbled, empty, unversioned and newer-version files each get a plain reason")
    func kindsOfDamage() async throws {
        let folder = try TemporaryFolder()
        let storage = try folder.storage()
        try await storage.saveTeam(SampleTeams.diamondDogs)
        try await storage.saveGame(SampleGame.game)

        // A team file whose roster has the wrong shape.
        try folder.overwrite("teams/bad-roster.json", with: Data(#"{"formatVersion":1,"team":{"id":"x","name":"X","isOurs":false,"roster":"nobody"}}"#.utf8))
        // Game files: empty, random bytes, no version tag, and from a newer app.
        try folder.overwrite("games/empty.json", with: Data())
        try folder.overwrite("games/noise.json", with: Data([0xFF, 0x00, 0x13, 0x37]))
        try folder.overwrite("games/no-version.json", with: ScorebookJSON.encode(SampleGame.game))
        let newer = try folder.contents(of: "games/sample-game.json")
        try folder.overwrite("games/from-the-future.json",
                             with: Data(String(decoding: newer, as: UTF8.self)
                                .replacingOccurrences(of: "\"formatVersion\" : 1", with: "\"formatVersion\" : 2").utf8))

        let teams = try await storage.loadTeams()
        #expect(teams.items == [SampleTeams.diamondDogs])
        #expect(teams.damaged.map(\.fileName) == ["teams/bad-roster.json"])
        #expect(teams.damaged.first?.reason.contains("wrong form") == true)

        let games = try await storage.listGames()
        #expect(games.items.map(\.id) == [SampleGame.id])
        let reasons = Dictionary(uniqueKeysWithValues: games.damaged.map { ($0.fileName, $0.reason) })
        #expect(reasons.keys.sorted() == ["games/empty.json", "games/from-the-future.json", "games/no-version.json", "games/noise.json"])
        #expect(reasons["games/empty.json"]?.contains("empty") == true)
        #expect(reasons["games/noise.json"]?.contains("not readable") == true)
        #expect(reasons["games/no-version.json"]?.contains("no format version") == true)
        #expect(reasons["games/from-the-future.json"]?.contains("newer version") == true)

        // A damaged song library or settings file is reported, not quietly replaced.
        try folder.overwrite("settings.json", with: Data("{".utf8))
        await #expect(throws: StorageError.self) { try await storage.loadSettings() }
        try folder.overwrite("songs/library.json", with: Data("[]".utf8))
        await #expect(throws: StorageError.self) { try await storage.loadSongLibrary() }
    }

    @Test("A write cut off before its swap leaves the saved game whole, and the leftover is cleared")
    func leftoverTemporaryFile() async throws {
        let folder = try TemporaryFolder()
        let storage = try folder.storage()
        try await storage.saveGame(SampleGame.game)

        // What a crash halfway through writing would leave: a half-written hidden temporary
        // file beside the real one, which was never swapped in.
        let whole = try folder.contents(of: "games/sample-game.json")
        try folder.overwrite("games/.sample-game.json.1234\(SafeFileWriter.temporarySuffix)", with: whole.prefix(100))

        let list = try await storage.listGames()
        #expect(list.items.count == 1)
        #expect(list.damaged.isEmpty)
        #expect(try await storage.loadGame(SampleGame.id) == SampleGame.game)

        // The next time the app starts, the leftover is cleared away.
        _ = try folder.storage()
        #expect(try folder.names(in: "games") == ["sample-game.json"])
    }

    @Test("Normal saving leaves no temporary files behind")
    func noTemporaryFiles() async throws {
        let folder = try TemporaryFolder()
        let storage = try folder.storage()
        try await storage.saveGame(Game(id: "g", setup: SampleSetups.mudcatsAtDiamondDogs))
        for event in SampleGame.game.events.prefix(10) { try await storage.appendEvent(event, toGame: "g") }
        try await storage.saveTeam(SampleTeams.mudcats)
        try await storage.saveSettings(AppSettings())
        try await storage.saveSongLibrary(SampleSongs.library)
        #expect(try folder.names(in: "games") == ["g.json"])
        #expect(try folder.names(in: "teams") == ["mudcats.json"])
        #expect(try folder.names(in: "songs") == ["audio", "library.json"])
    }

    @Test("An id with odd characters stays inside its folder")
    func oddIDs() async throws {
        let folder = try TemporaryFolder()
        let storage = try folder.storage()
        let sneaky = copy(of: SampleGame.game, id: "../../escape", startingAt: SampleGame.game.setup.scheduledStart)
        try await storage.saveGame(sneaky)
        #expect(try await folder.storage().loadGame(sneaky.id) == sneaky)
        // Dots and slashes are written as % codes, so the file sits plainly inside games/.
        #expect(try folder.names(in: "games") == ["%2E%2E%2F%2E%2E%2Fescape.json"])
        #expect(try folder.names(in: "").contains("escape.json") == false)
    }

    // MARK: Version tag

    @Test("Every file storage writes records the format version")
    func versionTag() async throws {
        let folder = try TemporaryFolder()
        let storage = try folder.storage()
        try await storage.saveTeam(SampleTeams.diamondDogs)
        try await storage.saveGame(Game(id: "g", setup: SampleSetups.mudcatsAtDiamondDogs))
        try await storage.appendEvent(GameEvent(kind: .pitch(Pitch(.ball))), toGame: "g")
        try await storage.saveSongLibrary(SampleSongs.library)
        try await storage.saveSettings(AppSettings())
        let backup = try await storage.makeBackup()

        let files = ["teams/diamond-dogs.json", "games/g.json", "songs/library.json", "settings.json",
                     "backups/\(backup.lastPathComponent)"]
        for file in files {
            let json = try JSONSerialization.jsonObject(with: folder.contents(of: file)) as? [String: Any]
            #expect(json?["formatVersion"] as? Int == ScorebookJSON.formatVersion, "\(file)")
        }
    }
}
