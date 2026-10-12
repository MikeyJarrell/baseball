// Tests of the games that come inside a TestFlight copy of the app: a teammate's phone gets
// the season's finished games once, and nothing scored, changed or deleted on a phone is
// ever overwritten or brought back.

import Foundation
import Testing
import Model
import SampleData
@testable import Storage

@Suite("Games that come inside the app")
struct StarterGamesTests {

    /// A folder standing in for the games inside the app, holding the games given.
    private func starterFolder(_ games: [Game]) async throws -> TemporaryFolder {
        let folder = try TemporaryFolder()
        let storage = try folder.storage()
        for game in games { try await storage.saveGame(game) }
        return folder
    }

    /// The games folder inside a starter folder.
    private func games(in folder: TemporaryFolder) -> URL {
        folder.url.appendingPathComponent("games", isDirectory: true)
    }

    /// The sample game with its start moved a minute, as a correction made later would leave it.
    private var correctedSampleGame: Game {
        var game = SampleGame.game
        game.setup.scheduledStart += 60
        return game
    }

    @Test("A phone with a team but no games gets the finished game, and shows it in its games list")
    func bringsTheGame() async throws {
        let starter = try await starterFolder([SampleGame.game])
        let phone = try TemporaryFolder()
        try await phone.storage().saveTeam(SampleTeams.diamondDogs)

        let written = try StarterGames.install(from: games(in: starter), into: phone.url)

        #expect(written == ["sample-game.json"])
        #expect(try phone.contents(of: "games/sample-game.json") == starter.contents(of: "games/sample-game.json"))
        let finished = try await phone.storage().finishedGames()
        #expect(finished.items == [SampleGame.game])
        #expect(finished.damaged.isEmpty)
    }

    @Test("A game in progress and a file that does not read are never brought")
    func onlyFinishedGames() async throws {
        let inProgress = copy(of: SampleGame.game, id: "in-progress",
                              startingAt: SampleGame.game.setup.scheduledStart, eventCount: 25)
        let starter = try await starterFolder([inProgress])
        try starter.overwrite("games/garbled.json", with: Data("not a game".utf8))
        let phone = try TemporaryFolder()

        #expect(try StarterGames.install(from: games(in: starter), into: phone.url).isEmpty)
        #expect(try phone.names(in: "games").isEmpty)
        #expect(try await phone.storage().gameInProgress() == nil)
    }

    @Test("The phone's own copy of a game is left exactly as it is")
    func ownCopyWins() async throws {
        let starter = try await starterFolder([correctedSampleGame])
        let phone = try TemporaryFolder()
        try await phone.storage().saveGame(SampleGame.game)
        let own = try phone.contents(of: "games/sample-game.json")

        #expect(try StarterGames.install(from: games(in: starter), into: phone.url).isEmpty)
        #expect(try phone.contents(of: "games/sample-game.json") == own)
    }

    @Test("A game deleted on the phone is not brought back the next time the app opens")
    func deletedStaysDeleted() async throws {
        let starter = try await starterFolder([SampleGame.game])
        let phone = try TemporaryFolder()
        try StarterGames.install(from: games(in: starter), into: phone.url)
        try await phone.storage().deleteGame(SampleGame.id)

        #expect(try StarterGames.install(from: games(in: starter), into: phone.url).isEmpty)
        #expect(try phone.names(in: "games").isEmpty)
        // Not even when a later copy of the app carries a corrected version.
        let later = try await starterFolder([correctedSampleGame])
        #expect(try StarterGames.install(from: games(in: later), into: phone.url).isEmpty)
        #expect(try phone.names(in: "games").isEmpty)
    }

    @Test("A corrected game in a later copy of the app replaces the one brought before")
    func correctionArrives() async throws {
        let starter = try await starterFolder([SampleGame.game])
        let phone = try TemporaryFolder()
        try StarterGames.install(from: games(in: starter), into: phone.url)

        let later = try await starterFolder([correctedSampleGame])
        #expect(try StarterGames.install(from: games(in: later), into: phone.url) == ["sample-game.json"])
        #expect(try await phone.storage().finishedGames().items == [correctedSampleGame])
        // Opening again changes nothing.
        #expect(try StarterGames.install(from: games(in: later), into: phone.url).isEmpty)
    }

    @Test("A corrected game does not replace one that was changed on the phone, or the phone's own")
    func correctionNeverOverwritesLocalChanges() async throws {
        let starter = try await starterFolder([SampleGame.game])
        let later = try await starterFolder([correctedSampleGame])

        // Brought in, then changed on the phone.
        let changed = try TemporaryFolder()
        try StarterGames.install(from: games(in: starter), into: changed.url)
        var edited = SampleGame.game
        edited.setup.scheduledStart -= 60
        try await changed.storage().saveGame(edited)
        #expect(try StarterGames.install(from: games(in: later), into: changed.url).isEmpty)
        #expect(try await changed.storage().finishedGames().items == [edited])

        // The phone the game was scored on: its file is the same as the first copy of the
        // app carried, and it still is never replaced.
        let scorer = try TemporaryFolder()
        try await scorer.storage().saveGame(SampleGame.game)
        try StarterGames.install(from: games(in: starter), into: scorer.url)
        #expect(try StarterGames.install(from: games(in: later), into: scorer.url).isEmpty)
        #expect(try await scorer.storage().finishedGames().items == [SampleGame.game])
    }

    @Test("An app with no games inside changes nothing")
    func noStarterGames() throws {
        let phone = try TemporaryFolder()
        let missing = phone.url.appendingPathComponent("nowhere", isDirectory: true)
        #expect(try StarterGames.install(from: missing, into: phone.url).isEmpty)
        #expect((try? phone.contents(of: StarterGames.recordName)) == nil)
    }
}
