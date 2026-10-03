// Storage's promise: what the Storage module provides to the rest of the app.
//
// Every function is asynchronous (marked `async`): it does its work in the background and
// the caller waits for it with `await`, so the screen never freezes while a file is written.
// The stand-in at the bottom keeps everything in memory, for previews and tests.

import Foundation

/// Saves and loads teams, games and the song library.
public protocol ScorebookStorage: Sendable {
    // Teams

    /// Every saved team, ours first.
    func loadTeams() async throws -> [Team]
    /// Saves a new team or replaces a saved one with the same id.
    func saveTeam(_ team: Team) async throws
    func deleteTeam(_ id: TeamID) async throws

    // Games

    /// Every saved game, newest first, with date, opponent and final score.
    func listGames() async throws -> [GameSummary]
    func loadGame(_ id: GameID) async throws -> Game
    /// Saves a whole game: its setup and every event. Used for a new game, an edit or an undo.
    func saveGame(_ game: Game) async throws
    /// Adds one new event to the end of a saved game. On disk before this returns.
    func appendEvent(_ event: GameEvent, toGame id: GameID) async throws
    func deleteGame(_ id: GameID) async throws
    /// The most recent game that has not ended, so the app can offer to resume it.
    func gameInProgress() async throws -> Game?
    /// Every game that has ended, for season totals.
    func finishedGames() async throws -> [Game]

    // Songs

    func loadSongLibrary() async throws -> SongLibrary
    func saveSongLibrary(_ library: SongLibrary) async throws

    // Backups

    /// Writes everything except audio into one dated backup file and returns where it is.
    func makeBackup() async throws -> URL
    /// Replaces everything except audio with the contents of a backup file.
    func restoreBackup(from file: URL) async throws
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

    public init(teams: [Team] = [], games: [Game] = [], library: SongLibrary = SongLibrary()) {
        for team in teams { self.teams[team.id] = team }
        for game in games { self.games[game.id] = game }
        self.library = library
    }

    public func loadTeams() async throws -> [Team] {
        teams.values.sorted { ($0.isOurs ? 0 : 1, $0.name) < ($1.isOurs ? 0 : 1, $1.name) }
    }

    public func saveTeam(_ team: Team) async throws { teams[team.id] = team }

    public func deleteTeam(_ id: TeamID) async throws { teams[id] = nil }

    public func listGames() async throws -> [GameSummary] {
        games.values.map(GameSummary.init(game:)).sorted { $0.date > $1.date }
    }

    public func loadGame(_ id: GameID) async throws -> Game {
        guard let game = games[id] else { throw StorageError.notFound(id.rawValue) }
        return game
    }

    public func saveGame(_ game: Game) async throws { games[game.id] = game }

    public func appendEvent(_ event: GameEvent, toGame id: GameID) async throws {
        guard games[id] != nil else { throw StorageError.notFound(id.rawValue) }
        games[id]?.events.append(event)
    }

    public func deleteGame(_ id: GameID) async throws { games[id] = nil }

    public func gameInProgress() async throws -> Game? {
        games.values.filter { !$0.isFinished }.max { $0.setup.date < $1.setup.date }
    }

    public func finishedGames() async throws -> [Game] {
        games.values.filter(\.isFinished).sorted { $0.setup.date < $1.setup.date }
    }

    public func loadSongLibrary() async throws -> SongLibrary { library }

    public func saveSongLibrary(_ library: SongLibrary) async throws { self.library = library }

    public func makeBackup() async throws -> URL {
        throw StorageError.unsupported("The in-memory stand-in does not write backup files.")
    }

    public func restoreBackup(from file: URL) async throws {
        throw StorageError.unsupported("The in-memory stand-in does not read backup files.")
    }
}
