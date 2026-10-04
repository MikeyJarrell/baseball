// Storage's promise: what the Storage module provides to the rest of the app.
//
// Every function is asynchronous (marked `async`): it does its work in the background and
// the caller waits for it with `await`, so the screen never freezes while a file is written.
// The stand-in at the bottom keeps everything in memory, for previews and tests.

import Foundation

/// Saves and loads teams, games and the song library.
public protocol ScorebookStorage: Sendable {
    // Teams

    /// Every saved team, ours first, plus any team file that could not be read.
    func loadTeams() async throws -> LoadedList<Team>
    /// Saves a new team or replaces a saved one with the same id.
    func saveTeam(_ team: Team) async throws
    func deleteTeam(_ id: TeamID) async throws

    // Games

    /// Every saved game, newest first, with date, opponent and final score, plus any game
    /// file that could not be read.
    func listGames() async throws -> LoadedList<GameSummary>
    func loadGame(_ id: GameID) async throws -> Game
    /// Saves a whole game: its setup and every event. Used for a new game, an edit or an undo.
    func saveGame(_ game: Game) async throws
    /// Adds one new event to the end of a saved game. On disk before this returns.
    func appendEvent(_ event: GameEvent, toGame id: GameID) async throws
    func deleteGame(_ id: GameID) async throws
    /// The most recent game that has not ended, so the app can offer to resume it.
    func gameInProgress() async throws -> Game?
    /// Every game that has ended, for season totals, plus any game file that could not be read.
    func finishedGames() async throws -> LoadedList<Game>

    // Songs

    func loadSongLibrary() async throws -> SongLibrary
    func saveSongLibrary(_ library: SongLibrary) async throws

    // Settings

    /// The app's settings, or the defaults if none have been saved. Saved as `settings.json`.
    func loadSettings() async throws -> AppSettings
    func saveSettings(_ settings: AppSettings) async throws

    // Backups

    /// Writes everything except audio into one dated backup file and returns where it is.
    func makeBackup() async throws -> URL
    /// Replaces everything except audio with the contents of a backup file.
    func restoreBackup(from file: URL) async throws
    /// Every backup file, newest first, for a restore screen.
    func listBackups() async throws -> [URL]
}


/// A list read from several files: everything that read cleanly, and every file that did
/// not. One damaged game file shows up in `damaged` and the other games still load.
public struct LoadedList<Item: Codable & Equatable & Sendable>: Codable, Equatable, Sendable {
    public var items: [Item]
    public var damaged: [DamagedFile]

    public init(items: [Item], damaged: [DamagedFile] = []) {
        self.items = items
        self.damaged = damaged
    }
}

/// A saved file that could not be read, for telling the scorer which one is broken.
public struct DamagedFile: Codable, Equatable, Hashable, Sendable {
    /// The file's name inside the app's folder, such as "games/1234.json".
    public var fileName: String
    /// What went wrong, in plain words.
    public var reason: String

    public init(fileName: String, reason: String) {
        self.fileName = fileName
        self.reason = reason
    }
}

/// What can go wrong when saving or loading.
public enum StorageError: Error, Equatable, Sendable {
    /// Nothing saved under that id.
    case notFound(String)
    /// A file exists but cannot be read: a half-written or corrupted file.
    case damaged(file: String, reason: String)
    /// Saving or loading is not possible here (the stand-in has no backup files).
    case unsupported(String)
}

/// Storage that keeps everything in memory and forgets it when the app closes.
/// For previews and tests; the real storage writes files.
public actor InMemoryStorage: ScorebookStorage {
    private var teams: [TeamID: Team] = [:]
    private var games: [GameID: Game] = [:]
    private var library = SongLibrary()
    private var settings = AppSettings()
    /// The order games were last saved in, standing in for a saved file's time.
    private var lastSaved: [GameID: Int] = [:]
    private var saves = 0

    public init(teams: [Team] = [], games: [Game] = [], library: SongLibrary = SongLibrary()) {
        for team in teams { self.teams[team.id] = team }
        for (i, game) in games.enumerated() {
            self.games[game.id] = game
            lastSaved[game.id] = i + 1
        }
        saves = games.count
        self.library = library
    }

    public func loadTeams() async throws -> LoadedList<Team> {
        LoadedList(items: teams.values.sorted { ($0.isOurs ? 0 : 1, $0.name) < ($1.isOurs ? 0 : 1, $1.name) })
    }

    public func saveTeam(_ team: Team) async throws { teams[team.id] = team }

    public func deleteTeam(_ id: TeamID) async throws { teams[id] = nil }

    public func listGames() async throws -> LoadedList<GameSummary> {
        LoadedList(items: games.values.map(GameSummary.init(game:)).sorted { $0.date > $1.date })
    }

    public func loadGame(_ id: GameID) async throws -> Game {
        guard let game = games[id] else { throw StorageError.notFound(id.rawValue) }
        return game
    }

    public func saveGame(_ game: Game) async throws {
        games[game.id] = game
        noteSaved(game.id)
    }

    /// Remembers that a game was just saved.
    private func noteSaved(_ id: GameID) {
        saves += 1
        lastSaved[id] = saves
    }

    public func appendEvent(_ event: GameEvent, toGame id: GameID) async throws {
        guard games[id] != nil else { throw StorageError.notFound(id.rawValue) }
        games[id]?.events.append(event)
        noteSaved(id)
    }

    public func deleteGame(_ id: GameID) async throws { games[id] = nil }

    /// The same choice the real storage makes: among unfinished games, the one with the latest
    /// event; if none has started, the one saved most recently.
    public func gameInProgress() async throws -> Game? {
        let unfinished = games.values.filter { !$0.isFinished }
        if let started = unfinished.filter({ !$0.events.isEmpty })
            .max(by: { ($0.events.last!.enteredAt, $0.id.rawValue) < ($1.events.last!.enteredAt, $1.id.rawValue) }) {
            return started
        }
        return unfinished.max { (lastSaved[$0.id] ?? 0, $0.id.rawValue) < (lastSaved[$1.id] ?? 0, $1.id.rawValue) }
    }

    public func finishedGames() async throws -> LoadedList<Game> {
        LoadedList(items: games.values.filter(\.isFinished).sorted { $0.setup.scheduledStart < $1.setup.scheduledStart })
    }

    public func loadSongLibrary() async throws -> SongLibrary { library }

    public func saveSongLibrary(_ library: SongLibrary) async throws { self.library = library }

    public func loadSettings() async throws -> AppSettings { settings }

    public func saveSettings(_ settings: AppSettings) async throws { self.settings = settings }

    public func makeBackup() async throws -> URL {
        throw StorageError.unsupported("The in-memory stand-in does not write backup files.")
    }

    public func restoreBackup(from file: URL) async throws {
        throw StorageError.unsupported("The in-memory stand-in does not read backup files.")
    }

    /// The stand-in keeps no backups.
    public func listBackups() async throws -> [URL] { [] }
}
