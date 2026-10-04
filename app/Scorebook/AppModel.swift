// The app's one shared model: everything saved (teams, games, settings, songs) and the two
// long-lived helpers, storage and the audio player, made once when the app opens.
//
// Screens never talk to storage or the audio player themselves. The views in this folder
// read this model, hand its data to the screens, and turn each screen's requests ("save this
// team", "start a game with this setup") into calls on it.

import Foundation
import Observation
import Model
import GameEngine
import Stats
import Storage
import Scoring
import WalkUpAudio
import PregameScreens

/// Everything the app keeps while it is open.
@MainActor
@Observable
final class AppModel {
    /// Where the app is in opening up.
    enum Phase: Equatable {
        /// Reading the saved files.
        case loading
        /// Ready to use.
        case ready
        /// The saved files could not be opened at all; the message says why.
        case failed(String)
    }

    /// Where the app is in opening up.
    private(set) var phase: Phase = .loading
    /// Where everything is saved. Made once, at launch.
    private(set) var storage: FileStorage?
    /// The walk-up song player. Made once, at launch.
    private(set) var audio: StadiumAudioPlayer?

    /// Every saved team: ours first, then the opponents by name.
    private(set) var teams: [Team] = []
    /// The app settings: walk-up song length, introductions, stats minimums.
    private(set) var settings = AppSettings()
    /// Every saved game, newest first, for the games list.
    private(set) var gameSummaries: [GameSummary] = []
    /// Every finished game, oldest first, for the season stats.
    private(set) var finishedGames: [Game] = []
    /// Saved files that could not be read (a damaged team or game), to mention on screen.
    private(set) var damagedFiles: [DamagedFile] = []

    /// The game being scored, if one is open or waiting to be resumed.
    private(set) var session: GameSession?
    /// A message for the scorer when something could not be saved or read.
    var problem: String?

    /// The league's rules, shared by every game.
    let engine = ScorebookRulesEngine()
    /// The box score and season stats calculator.
    let stats = StatsEngine()

    // MARK: Opening the app

    /// Opens storage and the audio player, reads everything saved, and finds a game in
    /// progress to resume. Called once, when the app starts.
    func load(using launch: LaunchOptions = .fromProcess) async {
        do {
            let folders = try launch.folders()
            let storage = try FileStorage(dataFolder: folders.data, backupsFolder: folders.backups)
            self.storage = storage

            // A UI test hands in teams and a game setup to start from.
            if let seed = launch.seed { try await seed.install(in: storage) }

            settings = try await storage.loadSettings()
            let library = try await storage.loadSongLibrary()
            let audio = StadiumAudioPlayer(audioFolder: storage.audioFolder, library: library)
            audio.walkUpLength = settings.walkUpSongSeconds
            // Whenever the song library changes (a song added, renamed, a new start point),
            // save it.
            audio.onLibraryChanged = { [weak self] library in
                Task { await self?.saveSongLibrary(library) }
            }
            self.audio = audio

            await reloadTeams()
            await reloadGames()
            if let game = try await storage.gameInProgress() {
                session = GameSession(game: game, storage: storage, engine: engine, stats: stats)
            }
            phase = .ready
        } catch {
            phase = .failed("The scorebook’s saved files could not be opened. (\(error.localizedDescription))")
        }
    }

    // MARK: Teams

    /// Our team, if one has been set up.
    var ourTeam: Team? { teams.first { $0.isOurs } }

    /// Every opponent, the ones played most recently first, then the rest by name.
    var opponents: [Team] {
        let others = teams.filter { !$0.isOurs }
        var lastPlayed: [TeamID: Date] = [:]
        for game in finishedGames {
            for side in TeamSide.allCases where !game.setup[side].isOurs {
                let id = game.setup[side].teamID
                lastPlayed[id] = max(lastPlayed[id] ?? .distantPast, game.setup.scheduledStart)
            }
        }
        return others.sorted {
            let a = lastPlayed[$0.id] ?? .distantPast, b = lastPlayed[$1.id] ?? .distantPast
            return a != b ? a > b : $0.name < $1.name
        }
    }

    /// Saves one team (new or changed) and reads the list again.
    func saveTeam(_ team: Team) async {
        guard let storage else { return }
        do {
            try await storage.saveTeam(team)
        } catch {
            problem = "\(team.name) could not be saved. (\(error.localizedDescription))"
        }
        await reloadTeams()
    }

    /// Deletes one team and reads the list again.
    func deleteTeam(_ id: TeamID) async {
        guard let storage else { return }
        do { try await storage.deleteTeam(id) } catch { problem = "The team could not be deleted. (\(error.localizedDescription))" }
        await reloadTeams()
    }

    /// Reads every saved team again.
    private func reloadTeams() async {
        guard let storage else { return }
        do {
            let loaded = try await storage.loadTeams()
            teams = loaded.items
            damagedFiles = loaded.damaged
        } catch {
            problem = "The teams could not be read. (\(error.localizedDescription))"
        }
    }

    // MARK: Games

    /// Reads the games list and every finished game again.
    func reloadGames() async {
        guard let storage else { return }
        do {
            let list = try await storage.listGames()
            gameSummaries = list.items
            let finished = try await storage.finishedGames()
            finishedGames = finished.items
            damagedFiles = (damagedFiles.filter { !$0.fileName.hasPrefix("games") }) + list.damaged
        } catch {
            problem = "The saved games could not be read. (\(error.localizedDescription))"
        }
    }

    /// What the pregame screens start from: our team, the opponents, our recent games
    /// newest first, and who pitched in them.
    func pregameInput(today: Date = Date()) -> PregameInput? {
        guard let ourTeam else { return nil }
        let recent = finishedGames.reversed().map(\.setup)
        return PregameInput(ourTeam: ourTeam, opponents: opponents, recentGames: Array(recent),
                            pitchingHistory: pitchingHistory, today: today)
    }

    /// Every pitcher who appeared in a finished game, starters and relievers, from the box
    /// scores, so the pregame screens can list whoever pitched most recently first.
    private var pitchingHistory: [PitchingAppearance] {
        finishedGames.flatMap { game -> [PitchingAppearance] in
            let box = boxScore(for: game)
            return [box.away, box.home].flatMap { team in
                team.pitching.enumerated().map { index, line in
                    PitchingAppearance(player: line.player, date: game.setup.scheduledStart, started: index == 0)
                }
            }
        }
    }

    /// Starts a new game from the pregame screens' setup. Saves any players typed in for
    /// either team (a new pitcher, numbers for their hitters) to the saved teams first, so
    /// they are there next time, then saves the new game and opens it.
    func startGame(_ setup: GameSetup) async -> Bool {
        guard let storage else { return false }
        for side in TeamSide.allCases {
            let gameTeam = setup[side]
            let saved = teams.first { $0.id == gameTeam.teamID }
                ?? Team(id: gameTeam.teamID, name: gameTeam.name, isOurs: gameTeam.isOurs, shortName: gameTeam.shortName)
            let updated = PregameBuilder.updatedTeam(saved: saved, from: gameTeam)
            if updated != saved || !teams.contains(where: { $0.id == saved.id }) {
                await saveTeam(updated)
            }
        }
        do {
            session = try await GameSession.start(setup: setup, storage: storage, engine: engine, stats: stats)
            await reloadGames()
            return true
        } catch {
            problem = "The new game could not be saved. (\(error.localizedDescription))"
            return false
        }
    }

    /// After the scorer ends the game: reads the games again, so the season includes it, and
    /// writes a backup of everything into the folder the Files app shows.
    func gameEnded() async {
        await reloadGames()
        if let storage { _ = try? await storage.makeBackup() }
    }

    /// Closes the finished game, so the home screen no longer offers to resume it.
    func closeFinishedGame() {
        if session?.isFinished == true { session = nil }
    }

    /// One finished game's box score.
    func boxScore(for game: Game) -> BoxScore {
        stats.boxScore(for: engine.replay(game).log)
    }

    /// The box score of the saved game with this id, finished or in progress.
    func boxScore(for id: GameID) async -> BoxScore? {
        if let game = finishedGames.first(where: { $0.id == id }) { return boxScore(for: game) }
        if let session, session.game.id == id { return session.boxScore }
        guard let storage, let game = try? await storage.loadGame(id) else { return nil }
        return boxScore(for: game)
    }

    /// The newest finished game, for the "Last box score" tile.
    var lastFinishedGame: Game? {
        finishedGames.max { $0.setup.scheduledStart < $1.setup.scheduledStart }
    }

    /// The season so far for our team, from every finished game.
    func seasonTotals() -> SeasonTotals? {
        guard let ourTeam else { return nil }
        let logs = finishedGames.map { engine.replay($0).log }
        return stats.seasonTotals(for: logs, team: ourTeam.id)
    }

    // MARK: Players changed during a game

    /// Puts a changed player (a name, number, batting side or song filled in during a game)
    /// on the saved team too, so the change is there next game.
    func updateSavedPlayer(_ player: Player, teamID: TeamID) async {
        guard var team = teams.first(where: { $0.id == teamID }) else { return }
        if let i = team.roster.firstIndex(where: { $0.id == player.id }) {
            // Keep what only the saved team knows (the usual position and role).
            var merged = player
            merged.usualPosition = team.roster[i].usualPosition
            merged.usualRole = team.roster[i].usualRole
            merged.usuallyLeadsOff = team.roster[i].usuallyLeadsOff
            team.roster[i] = merged
        } else {
            team.roster.append(player)
        }
        await saveTeam(team)
    }

    // MARK: Settings and songs

    /// Changes the settings, saves them, and passes the walk-up length to the audio player.
    func updateSettings(_ change: (inout AppSettings) -> Void) async {
        var changed = settings
        change(&changed)
        guard changed != settings else { return }
        settings = changed
        audio?.walkUpLength = changed.walkUpSongSeconds
        guard let storage else { return }
        do { try await storage.saveSettings(changed) } catch {
            problem = "The settings could not be saved. (\(error.localizedDescription))"
        }
    }

    /// Saves the song library after any change to it.
    private func saveSongLibrary(_ library: SongLibrary) async {
        guard let storage else { return }
        do { try await storage.saveSongLibrary(library) } catch {
            problem = "The song list could not be saved. (\(error.localizedDescription))"
        }
    }

    // MARK: Backups

    /// Every backup file, newest first.
    func backups() async -> [URL] {
        guard let storage else { return [] }
        return (try? await storage.listBackups()) ?? []
    }

    /// Writes a backup now.
    func makeBackup() async -> Bool {
        guard let storage else { return false }
        do { _ = try await storage.makeBackup(); return true } catch {
            problem = "The backup could not be written. (\(error.localizedDescription))"
            return false
        }
    }

    /// Puts everything back as it was in a backup file, then reads it all again.
    func restore(from file: URL) async {
        guard let storage else { return }
        do {
            try await storage.restoreBackup(from: file)
            session = nil
            settings = try await storage.loadSettings()
            audio?.load(try await storage.loadSongLibrary())
            await reloadTeams()
            await reloadGames()
            if let game = try await storage.gameInProgress() {
                session = GameSession(game: game, storage: storage, engine: engine, stats: stats)
            }
        } catch {
            problem = "That backup could not be restored, and nothing was changed. (\(error.localizedDescription))"
        }
    }
}
