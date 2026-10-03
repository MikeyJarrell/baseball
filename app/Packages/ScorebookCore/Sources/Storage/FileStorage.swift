// FileStorage: the real storage, saving everything as JSON files.
//
// It is given two folders. The data folder holds the live files, and the app passes its
// private Application Support folder, which the iPhone Files app cannot see, so nobody can
// delete or edit a game by mistake:
//
//     teams/<team id>.json      one file per team, ours and every opponent
//     games/<game id>.json      a game's setup and every event (see GameFileLayout.swift)
//     songs/library.json        song names, start points and file names
//     songs/audio/              the audio files themselves (written by the walk-up audio import)
//     settings.json             the app's settings
//
// The backups folder holds dated backup files, and the app passes `Documents/backups`, so
// the Files app shows them and a backup can be copied off the phone. Tests pass temporary
// folders for both.
//
// Every write goes through SafeFileWriter, so a crash mid-write never leaves a half-written
// file. Use one FileStorage per data folder: it remembers the open game's file between events.

import Foundation
import Model

/// Saves and loads teams, games, the song library and the settings as JSON files.
public actor FileStorage: ScorebookStorage {
    /// The private folder the live files are saved in.
    public nonisolated let dataFolder: URL
    /// Where imported song files are kept, inside the data folder. Storage creates it; the
    /// walk-up audio import fills it.
    public nonisolated let audioFolder: URL
    /// Where backup files are written: the one folder the scorer sees in the Files app.
    public nonisolated let backupsFolder: URL

    private let teamsFolder: URL
    private let gamesFolder: URL
    private let songsFolder: URL
    private let libraryFile: URL
    private let settingsFile: URL

    /// The game most recently saved or added to, kept ready to write so recording the
    /// next event is quick. Forgotten whenever that game's file is replaced some other way.
    private var openGame: GameFileLayout?

    /// Sets up storage, creating the folders it needs if they are not there yet and clearing
    /// away any temporary file left by a write that never finished.
    /// - Parameters:
    ///   - dataFolder: where the live files go. The app passes its Application Support folder.
    ///   - backupsFolder: where backups go. The app passes `backups` inside its Documents folder.
    public init(dataFolder: URL, backupsFolder: URL) throws {
        self.dataFolder = dataFolder
        self.backupsFolder = backupsFolder
        teamsFolder = dataFolder.appendingPathComponent("teams", isDirectory: true)
        gamesFolder = dataFolder.appendingPathComponent("games", isDirectory: true)
        songsFolder = dataFolder.appendingPathComponent("songs", isDirectory: true)
        audioFolder = songsFolder.appendingPathComponent("audio", isDirectory: true)
        libraryFile = songsFolder.appendingPathComponent("library.json")
        settingsFile = dataFolder.appendingPathComponent("settings.json")

        for subfolder in [teamsFolder, gamesFolder, songsFolder, audioFolder, backupsFolder] {
            try FileManager.default.createDirectory(at: subfolder, withIntermediateDirectories: true)
        }
        for subfolder in [dataFolder, teamsFolder, gamesFolder, songsFolder, backupsFolder] {
            SafeFileWriter.clearLeftovers(in: subfolder)
        }
    }

    // MARK: Teams

    /// Every saved team, ours first and then by name, plus any team file that could not be read.
    public func loadTeams() async throws -> LoadedList<Team> {
        let read = try readEvery(TeamFile.self, in: teamsFolder)
        let teams = read.items.map(\.team).sorted {
            ($0.isOurs ? 0 : 1, $0.name, $0.id.rawValue) < ($1.isOurs ? 0 : 1, $1.name, $1.id.rawValue)
        }
        return LoadedList(items: teams, damaged: read.damaged)
    }

    /// Saves a new team or replaces the saved one with the same id.
    public func saveTeam(_ team: Team) async throws {
        let file = TeamFile(formatVersion: ScorebookJSON.formatVersion, team: team)
        try SafeFileWriter.write(ScorebookJSON.encode(file), to: teamFile(team.id))
    }

    /// Deletes a team's file. Deleting a team that is not saved does nothing.
    public func deleteTeam(_ id: TeamID) async throws {
        try removeIfPresent(teamFile(id))
    }

    // MARK: Games

    /// Every saved game, newest first, with its date, opponent and final score, plus any game
    /// file that could not be read.
    public func listGames() async throws -> LoadedList<GameSummary> {
        let read = try readEveryGame()
        let summaries = read.items.map(GameSummary.init(game:)).sorted {
            ($0.date, $0.id.rawValue) > ($1.date, $1.id.rawValue)
        }
        return LoadedList(items: summaries, damaged: read.damaged)
    }

    /// One whole game: its setup and every event.
    public func loadGame(_ id: GameID) async throws -> Game {
        if let openGame, openGame.game.id == id { return openGame.game }
        let file = gameFile(id)
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw StorageError.notFound(id.rawValue)
        }
        return try readGame(at: file)
    }

    /// Saves a whole game, replacing any saved copy: for a new game, an edit or an undo.
    public func saveGame(_ game: Game) async throws {
        let layout = try GameFileLayout(game: game)
        try SafeFileWriter.write(layout.fileContents, to: gameFile(game.id))
        openGame = layout
    }

    /// Adds one new event to the end of a saved game. The game's file has been safely
    /// rewritten on disk before this returns.
    public func appendEvent(_ event: GameEvent, toGame id: GameID) async throws {
        // Reuse the open game if it is this one; otherwise read the game in from its file.
        var layout: GameFileLayout
        if let openGame, openGame.game.id == id {
            layout = openGame
        } else {
            layout = try GameFileLayout(game: try await loadGame(id))
        }
        try layout.append(event)
        try SafeFileWriter.write(layout.fileContents, to: gameFile(id))
        openGame = layout
    }

    /// Deletes a game's file. Deleting a game that is not saved does nothing.
    public func deleteGame(_ id: GameID) async throws {
        if openGame?.game.id == id { openGame = nil }
        try removeIfPresent(gameFile(id))
    }

    /// The game that has not ended and was worked on most recently, so the app can offer to
    /// resume it. A game with at least one event always beats a game not yet started, and
    /// started games are ranked by when their last event was entered. Only if no game has
    /// been started is an unstarted one offered: the one set up most recently, going by when
    /// its file was saved, never by a start time that may still be in the future (a game set
    /// up for next Saturday). Damaged game files are skipped.
    public func gameInProgress() async throws -> Game? {
        let unfinished = try readEveryGame().items.filter { !$0.isFinished }
        if let started = unfinished
            .filter({ !$0.events.isEmpty })
            .max(by: { ($0.events.last!.enteredAt, $0.id.rawValue) < ($1.events.last!.enteredAt, $1.id.rawValue) }) {
            return started
        }
        return unfinished.max { (savedAt($0.id), $0.id.rawValue) < (savedAt($1.id), $1.id.rawValue) }
    }

    /// When a game's file was last written, or the distant past if that cannot be told.
    private func savedAt(_ id: GameID) -> Date {
        let attributes = try? FileManager.default.attributesOfItem(atPath: gameFile(id).path)
        return attributes?[.modificationDate] as? Date ?? .distantPast
    }

    /// Every game that has ended, oldest first, for the season totals, plus any game file
    /// that could not be read.
    public func finishedGames() async throws -> LoadedList<Game> {
        let read = try readEveryGame()
        let finished = read.items.filter(\.isFinished).sorted {
            ($0.setup.scheduledStart, $0.id.rawValue) < ($1.setup.scheduledStart, $1.id.rawValue)
        }
        return LoadedList(items: finished, damaged: read.damaged)
    }

    // MARK: Songs

    /// The song library, or an empty one if none has been saved.
    public func loadSongLibrary() async throws -> SongLibrary {
        guard let data = try readIfPresent(libraryFile) else { return SongLibrary() }
        return try readSavedFile(SongLibraryFile.self, from: data, named: "songs/library.json").songLibrary
    }

    public func saveSongLibrary(_ library: SongLibrary) async throws {
        let file = SongLibraryFile(formatVersion: ScorebookJSON.formatVersion, songLibrary: library)
        try SafeFileWriter.write(ScorebookJSON.encode(file), to: libraryFile)
    }

    // MARK: Settings

    /// The app's settings, or the defaults if none have been saved. A damaged settings file
    /// is reported as `StorageError.damaged`; the app may fall back to the defaults.
    public func loadSettings() async throws -> AppSettings {
        guard let data = try readIfPresent(settingsFile) else { return AppSettings() }
        return try readSavedFile(SettingsFile.self, from: data, named: "settings.json").settings
    }

    public func saveSettings(_ settings: AppSettings) async throws {
        let file = SettingsFile(formatVersion: ScorebookJSON.formatVersion, settings: settings)
        try SafeFileWriter.write(ScorebookJSON.encode(file), to: settingsFile)
    }

    // MARK: Backups

    /// Writes every team, game, the song library and the settings into one dated file in
    /// `backups/`, and returns where it is. Audio files are left out. A file that cannot be
    /// read is copied in byte for byte, so nothing is lost even then.
    public func makeBackup() async throws -> URL {
        try writeBackup(namedFrom: "backup")
    }

    /// Replaces every team, game, the song library and the settings with a backup's contents.
    /// Audio files are left alone. The backup is checked in full before anything is touched,
    /// and what was there before is first saved as a "before-restore" backup, so a restore
    /// can itself be undone.
    ///
    /// The backup's files are written first, each one safely replacing the file of the same
    /// name, and only then are the files the backup does not have removed. A restore cut off
    /// partway, by a crash or a full phone, leaves every game in place, plus perhaps some extras.
    public func restoreBackup(from file: URL) async throws {
        // 1. Read and check the whole backup. A damaged backup changes nothing.
        let data: Data
        do {
            data = try Data(contentsOf: file)
        } catch {
            throw StorageError.notFound(file.lastPathComponent)
        }
        let backup = try readSavedFile(BackupFile.self, from: data, named: file.lastPathComponent)

        // 2. Keep a copy of what is there now.
        _ = try writeBackup(namedFrom: "before-restore")
        openGame = nil

        // 3. Write the backup's contents over the current files, noting each file written.
        var kept: Set<String> = []
        for team in backup.teams {
            try await saveTeam(team)
            kept.insert(relativeName(teamFile(team.id)))
        }
        for game in backup.games {
            try await saveGame(game)
            kept.insert(relativeName(gameFile(game.id)))
        }
        if let library = backup.songLibrary {
            try await saveSongLibrary(library)
            kept.insert(relativeName(libraryFile))
        }
        if let settings = backup.settings {
            try await saveSettings(settings)
            kept.insert(relativeName(settingsFile))
        }
        for copy in backup.unreadableFiles {
            // Put an unreadable file back exactly as it was, but only inside the data folder.
            let target = dataFolder.appendingPathComponent(copy.fileName)
            guard target.standardizedFileURL.path.hasPrefix(dataFolder.standardizedFileURL.path + "/") else { continue }
            try SafeFileWriter.write(copy.contents, to: target)
            kept.insert(copy.fileName)
        }
        openGame = nil

        // 4. Only now remove the teams, games, song library and settings the backup did not have.
        for subfolder in [teamsFolder, gamesFolder] {
            for name in try FileManager.default.contentsOfDirectory(atPath: subfolder.path)
            where name.hasSuffix(".json") && !name.hasPrefix(".") && !kept.contains("\(subfolder.lastPathComponent)/\(name)") {
                try FileManager.default.removeItem(at: subfolder.appendingPathComponent(name))
            }
        }
        for single in [libraryFile, settingsFile] where !kept.contains(relativeName(single)) {
            try removeIfPresent(single)
        }
    }

    /// A file's name inside the data folder, such as "games/1234.json" or "settings.json".
    private func relativeName(_ file: URL) -> String {
        String(file.standardizedFileURL.path.dropFirst(dataFolder.standardizedFileURL.path.count + 1))
    }

    /// Every backup file, newest first, for a restore screen to offer. "Newest" goes by when
    /// each file was made, not by its name, so "before-restore" backups and two backups made
    /// in the same second fall in their true order.
    public func listBackups() throws -> [URL] {
        let files = try FileManager.default.contentsOfDirectory(atPath: backupsFolder.path)
            .filter { $0.hasSuffix(".json") && !$0.hasPrefix(".") }
            .map { backupsFolder.appendingPathComponent($0) }
        // When each file was made, to the fraction of a second the disk records.
        func madeAt(_ file: URL) -> Date {
            let attributes = try? FileManager.default.attributesOfItem(atPath: file.path)
            return attributes?[.creationDate] as? Date ?? .distantPast
        }
        return files
            .map { (file: $0, madeAt: madeAt($0)) }
            .sorted { ($0.madeAt, $0.file.lastPathComponent) > ($1.madeAt, $1.file.lastPathComponent) }
            .map(\.file)
    }

    /// Gathers everything except audio into one backup file named `<prefix>-<date and time>.json`.
    private func writeBackup(namedFrom prefix: String) throws -> URL {
        let teams = try readEvery(TeamFile.self, in: teamsFolder)
        let games = try readEveryGame()
        var unreadable = (teams.damaged + games.damaged).map {
            UnreadableFileCopy(fileName: $0.fileName,
                               contents: (try? Data(contentsOf: dataFolder.appendingPathComponent($0.fileName))) ?? Data())
        }
        // The song library and settings: kept as values if they read, copied byte for byte if not.
        var library: SongLibrary?
        if let data = try readIfPresent(libraryFile) {
            do { library = try readSavedFile(SongLibraryFile.self, from: data, named: "songs/library.json").songLibrary }
            catch { unreadable.append(UnreadableFileCopy(fileName: "songs/library.json", contents: data)) }
        }
        var settings: AppSettings?
        if let data = try readIfPresent(settingsFile) {
            do { settings = try readSavedFile(SettingsFile.self, from: data, named: "settings.json").settings }
            catch { unreadable.append(UnreadableFileCopy(fileName: "settings.json", contents: data)) }
        }

        let now = Date()
        let backup = BackupFile(
            formatVersion: ScorebookJSON.formatVersion, madeAt: now,
            teams: teams.items.map(\.team).sorted { $0.id < $1.id },
            games: games.items.sorted { $0.id < $1.id },
            songLibrary: library, settings: settings, unreadableFiles: unreadable)

        // A name such as "backup-2026-10-03-143005.json", in the phone's time zone. Two backups
        // in the same second get "-2", "-3" on the end rather than overwriting each other.
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let stamp = "\(prefix)-\(formatter.string(from: now))"
        var target = backupsFolder.appendingPathComponent("\(stamp).json")
        var count = 1
        while FileManager.default.fileExists(atPath: target.path) {
            count += 1
            target = backupsFolder.appendingPathComponent("\(stamp)-\(count).json")
        }
        try SafeFileWriter.write(ScorebookJSON.encode(backup), to: target)
        return target
    }

    // MARK: Reading files

    /// Reads one game file, joining its setup and events.
    private func readGame(at file: URL) throws -> Game {
        let data = try Data(contentsOf: file)
        return try readSavedFile(GameFile.self, from: data, named: "games/\(file.lastPathComponent)").wholeGame
    }

    /// Reads every game file, sorting them into games that read and files that did not.
    private func readEveryGame() throws -> (items: [Game], damaged: [DamagedFile]) {
        let read = try readEvery(GameFile.self, in: gamesFolder)
        return (read.items.map(\.wholeGame), read.damaged)
    }

    /// Reads every saved file in one folder. A file that cannot be read goes in `damaged`
    /// and never stops the others from loading.
    private func readEvery<T: Decodable>(_ type: T.Type, in subfolder: URL) throws -> (items: [T], damaged: [DamagedFile]) {
        let names = try FileManager.default.contentsOfDirectory(atPath: subfolder.path)
            .filter { $0.hasSuffix(".json") && !$0.hasPrefix(".") }
            .sorted()
        var items: [T] = []
        var damaged: [DamagedFile] = []
        for name in names {
            let fileName = "\(subfolder.lastPathComponent)/\(name)"
            do {
                let data = try Data(contentsOf: subfolder.appendingPathComponent(name))
                items.append(try readSavedFile(T.self, from: data, named: fileName))
            } catch StorageError.damaged(let file, let reason) {
                damaged.append(DamagedFile(fileName: file, reason: reason))
            } catch {
                damaged.append(DamagedFile(fileName: fileName, reason: plainReason(for: error)))
            }
        }
        return (items, damaged)
    }

    /// A file's bytes, or nothing if the file does not exist.
    private func readIfPresent(_ file: URL) throws -> Data? {
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        return try Data(contentsOf: file)
    }

    /// Deletes a file if it is there.
    private func removeIfPresent(_ file: URL) throws {
        if FileManager.default.fileExists(atPath: file.path) {
            try FileManager.default.removeItem(at: file)
        }
    }

    // MARK: File names

    private func teamFile(_ id: TeamID) -> URL {
        teamsFolder.appendingPathComponent("\(Self.safeName(id.rawValue)).json")
    }

    private func gameFile(_ id: GameID) -> URL {
        gamesFolder.appendingPathComponent("\(Self.safeName(id.rawValue)).json")
    }

    /// Turns an id into a safe file name. Letters, digits, "-" and "_" stay as they are
    /// ("d1", or the long random ids made in the app); anything else, such as "/", is written
    /// as a % code so an id can never point outside its folder.
    static func safeName(_ id: String) -> String {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")
        let name = id.addingPercentEncoding(withAllowedCharacters: allowed) ?? id
        // An empty id still needs a visible name; "%00" can never come from a real id,
        // because a real "%" is always written as "%25".
        return name.isEmpty ? "%00" : name
    }
}
