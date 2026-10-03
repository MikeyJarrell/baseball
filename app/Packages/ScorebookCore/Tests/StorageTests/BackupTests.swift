// Tests of backups: everything except audio goes into one dated file, and restoring it
// brings back exactly what was there, even after games were deleted and teams changed.

import Foundation
import Testing
import Model
import SampleData
@testable import Storage

@Suite("Backups")
struct BackupTests {

    /// Fills a storage with teams, a finished game, a game in progress, songs and settings.
    private func fill(_ storage: FileStorage) async throws -> (teams: [Team], games: [Game], settings: AppSettings) {
        let teams = SampleTeams.all + [SampleTeams.unknown()]
        for team in teams { try await storage.saveTeam(team) }
        let inProgress = copy(of: SampleGame.game, id: "in-progress",
                              startingAt: SampleGame.game.setup.scheduledStart.addingTimeInterval(86_400), eventCount: 25)
        let games = [inProgress, SampleGame.game].sorted { $0.id < $1.id }
        for game in games { try await storage.saveGame(game) }
        let settings = AppSettings(fadeSongOnFirstPitch: true)
        try await storage.saveSongLibrary(SampleSongs.library)
        try await storage.saveSettings(settings)
        return (teams, games, settings)
    }

    @Test("A backup restored after changes brings back exactly what was saved")
    func roundTrip() async throws {
        let folder = try TemporaryFolder()
        let storage = try folder.storage()
        let original = try await fill(storage)
        let backup = try await storage.makeBackup()

        // The backup is one dated file in backups/.
        #expect(backup.deletingLastPathComponent().lastPathComponent == "backups")
        #expect(backup.lastPathComponent.hasPrefix("backup-20"))
        #expect(backup.pathExtension == "json")

        // Change everything after the backup was made.
        try await storage.deleteGame(SampleGame.id)
        try await storage.appendEvent(GameEvent(kind: .pitch(Pitch(.ball))), toGame: "in-progress")
        try await storage.saveGame(Game(id: "made-later", setup: SampleSetups.diamondDogsAtBombers))
        try await storage.deleteTeam(SampleTeams.mudcats.id)
        try await storage.saveTeam(SampleTeams.emptyTeam)
        try await storage.saveSongLibrary(SongLibrary())
        try await storage.saveSettings(AppSettings())

        try await storage.restoreBackup(from: backup)

        // Read back through a brand-new storage, so the check is of what is on disk.
        let fresh = try folder.storage()
        let teams = try await fresh.loadTeams()
        #expect(Set(teams.items) == Set(original.teams))
        #expect(teams.items.count == original.teams.count)
        #expect(teams.damaged.isEmpty)
        for game in original.games {
            #expect(try await fresh.loadGame(game.id) == game)
        }
        #expect(try await fresh.listGames().items.count == original.games.count)
        #expect(try await fresh.loadSongLibrary() == SampleSongs.library)
        #expect(try await fresh.loadSettings() == original.settings)
        // The storage that did the restore has forgotten the old open game too.
        #expect(try await storage.loadGame("in-progress") == original.games.first { $0.id == "in-progress" })
    }

    @Test("Restoring first saves what was there, so a restore can be undone")
    func restoreKeepsWhatWasThere() async throws {
        let folder = try TemporaryFolder()
        let storage = try folder.storage()
        _ = try await fill(storage)
        let backup = try await storage.makeBackup()
        try await storage.saveGame(Game(id: "made-later", setup: SampleSetups.diamondDogsAtBombers))

        try await storage.restoreBackup(from: backup)
        #expect(try await storage.listGames().items.contains { $0.id == "made-later" } == false)

        let safety = try #require(try await storage.listBackups().first { $0.lastPathComponent.hasPrefix("before-restore-") })
        try await storage.restoreBackup(from: safety)
        #expect(try await storage.listGames().items.contains { $0.id == "made-later" })
    }

    @Test("Audio files are left out of a backup and untouched by a restore")
    func audioLeftAlone() async throws {
        let folder = try TemporaryFolder()
        let storage = try folder.storage()
        _ = try await fill(storage)
        let song = storage.audioFolder.appendingPathComponent("walk-up.m4a")
        let sound = Data(repeating: 0xAB, count: 50_000)
        try sound.write(to: song)

        let backup = try await storage.makeBackup()
        // The backup holds no audio: the song file is not mentioned in it, let alone copied in.
        let backupText = String(decoding: try Data(contentsOf: backup), as: UTF8.self)
        #expect(!backupText.contains("walk-up.m4a"))

        try FileManager.default.removeItem(at: song)
        try sound.prefix(10).write(to: song)
        try await storage.restoreBackup(from: backup)
        #expect(try Data(contentsOf: song) == sound.prefix(10), "Restore leaves the audio folder as it is")
    }

    @Test("A damaged file is copied into the backup byte for byte and put back by a restore")
    func damagedFileSurvivesBackup() async throws {
        let folder = try TemporaryFolder()
        let storage = try folder.storage()
        try await storage.saveGame(SampleGame.game)
        let broken = Data(#"{"formatVersion":1,"game":{"id":"half"#.utf8)
        try folder.overwrite("games/half.json", with: broken)

        let backup = try await storage.makeBackup()
        try await storage.deleteGame(SampleGame.id)
        try FileManager.default.removeItem(at: folder.url.appendingPathComponent("games/half.json"))
        try await storage.restoreBackup(from: backup)

        let list = try await storage.listGames()
        #expect(list.items.map(\.id) == [SampleGame.id])
        #expect(list.damaged.map(\.fileName) == ["games/half.json"])
        #expect(try folder.contents(of: "games/half.json") == broken)
    }

    @Test("A damaged backup is refused and changes nothing")
    func damagedBackupRefused() async throws {
        let folder = try TemporaryFolder()
        let storage = try folder.storage()
        let original = try await fill(storage)
        let backup = try await storage.makeBackup()
        let whole = try Data(contentsOf: backup)
        try whole.prefix(whole.count / 3).write(to: backup)

        await #expect(throws: StorageError.self) { try await storage.restoreBackup(from: backup) }
        for game in original.games {
            #expect(try await folder.storage().loadGame(game.id) == game)
        }
        #expect(try await storage.loadTeams().items.count == original.teams.count)
    }

    @Test("Backups are listed newest first by when they were made, whatever their names")
    func backupOrder() async throws {
        let folder = try TemporaryFolder()
        let storage = try folder.storage()
        _ = try await fill(storage)
        // A backup, then a restore (which makes a "before-restore" backup), then two more
        // backups in quick succession, usually within the same second.
        let first = try await storage.makeBackup()
        try await storage.restoreBackup(from: first)
        let safety = try #require(try await storage.listBackups().first)
        let third = try await storage.makeBackup()
        let fourth = try await storage.makeBackup()

        #expect(safety.lastPathComponent.hasPrefix("before-restore-"))
        #expect(third != fourth)
        // Sorting by name would put "before-restore-..." on top, and "backup-<time>-2.json"
        // below "backup-<time>.json"; the list must follow the order the backups were made.
        #expect(try await storage.listBackups() == [fourth, third, safety, first])
    }

    @Test("A leftover scrap from a backup cut off mid-write is cleared on the next start")
    func leftoverInBackups() async throws {
        let folder = try TemporaryFolder()
        let storage = try folder.storage()
        let backup = try await storage.makeBackup()
        try folder.overwrite("backups/.backup-x.json.1234\(SafeFileWriter.temporarySuffix)", with: Data("{".utf8))
        #expect(try await storage.listBackups() == [backup])
        _ = try folder.storage()
        #expect(try folder.names(in: "backups") == [backup.lastPathComponent])
    }

    @Test("Live files and backups go in the two separate folders the app gives")
    func twoFolders() async throws {
        let folder = try TemporaryFolder()
        let live = folder.url.appendingPathComponent("Application Support", isDirectory: true)
        let shown = folder.url.appendingPathComponent("Documents/backups", isDirectory: true)
        let storage = try FileStorage(dataFolder: live, backupsFolder: shown)
        _ = try await fill(storage)
        let backup = try await storage.makeBackup()

        #expect(backup.deletingLastPathComponent().standardizedFileURL == shown.standardizedFileURL)
        #expect(try folder.names(in: "Documents/backups") == [backup.lastPathComponent])
        #expect(try folder.names(in: "Application Support") == ["games", "settings.json", "songs", "teams"])
        #expect(storage.audioFolder.standardizedFileURL == live.appendingPathComponent("songs/audio").standardizedFileURL)
    }
}
