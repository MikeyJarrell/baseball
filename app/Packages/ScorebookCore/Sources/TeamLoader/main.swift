// The team loader: puts the Diamond Dogs, every opponent and every song from the repository's
// `team/` folder into a copy of the app's saved files, written exactly as the app writes them
// (through the app's own Storage module).
//
// tools/load_team.sh runs it on files copied off the phone (or the simulator), then copies the
// result back. It can also be run by hand:
//
//   swift run TeamLoader load  <app data folder> <team folder> <songs folder>
//   swift run TeamLoader check <app data folder>
//
// - The app data folder is the app's `Library/Application Support/Scorebook`.
// - `load` merges `roster.csv`, `warmup_extras.csv` (if there is one) and `opponents.csv` into it and copies each song file into its
//   `songs/audio` folder. Games and settings are never touched.
// - `check` lists what is there: teams, our players, songs, and whether every song's file is
//   present and plays. It ends with an error if anything is missing.

import Foundation
import AVFoundation
import Model
import Storage
import TeamImport

/// Stops with a message.
func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("Error: \(message)\n".utf8))
    exit(1)
}

/// A song file's length in seconds, or nothing if it will not play.
func playableLength(_ file: URL) async -> TimeInterval? {
    guard FileManager.default.fileExists(atPath: file.path) else { return nil }
    let asset = AVURLAsset(url: file)
    guard let playable = try? await asset.load(.isPlayable), playable,
          let duration = try? await asset.load(.duration), duration.seconds > 0 else { return nil }
    // Reading the start of the sound proves it can be decoded, not only opened.
    guard let audio = try? AVAudioFile(forReading: file), audio.length > 0 else { return nil }
    return duration.seconds
}

/// Opens the app's saved files in a folder, as the app does. Backups (which the loader never
/// makes) would go to a scratch folder.
func openStorage(_ dataFolder: URL) throws -> FileStorage {
    let scratch = FileManager.default.temporaryDirectory.appendingPathComponent("team-loader-backups-\(UUID().uuidString)")
    return try FileStorage(dataFolder: dataFolder, backupsFolder: scratch)
}

/// `load`: merges the CSV files into the saved files and copies the songs in.
func load(dataFolder: URL, teamFolder: URL, songsFolder: URL) async throws {
    let rosterText = try String(contentsOf: teamFolder.appendingPathComponent("roster.csv"), encoding: .utf8)
    let opponentsText = try String(contentsOf: teamFolder.appendingPathComponent("opponents.csv"), encoding: .utf8)
    let roster = RosterRow.read(rosterText)
    let opponents = OpponentRow.read(opponentsText)
    // Extra warm-up songs are optional: no file means none. A file that is there but cannot
    // be read stops the load, rather than wiping every pitcher's extra songs.
    let extrasFile = teamFolder.appendingPathComponent("warmup_extras.csv")
    var extraWarmUps: [ExtraWarmUpRow] = []
    if FileManager.default.fileExists(atPath: extrasFile.path) {
        guard let text = try? String(contentsOf: extrasFile, encoding: .utf8) else { fail("warmup_extras.csv could not be read") }
        extraWarmUps = ExtraWarmUpRow.read(text)
    }
    guard !roster.isEmpty else { fail("roster.csv has no players") }

    // Every song file the roster names must be there and play.
    var durations: [String: TimeInterval] = [:]
    let files = Set((roster.flatMap { [$0.clipFile, $0.warmUpFile] } + extraWarmUps.map(\.file)).filter { !$0.isEmpty })
    for file in files.sorted() {
        guard let length = await playableLength(songsFolder.appendingPathComponent(file)) else {
            fail("\(file) is missing from \(songsFolder.path) or will not play")
        }
        durations[file] = length
    }

    let storage = try openStorage(dataFolder)
    let saved = try await storage.loadTeams()
    if !saved.damaged.isEmpty { fail("some saved team files could not be read: \(saved.damaged.map(\.fileName))") }
    let library = try await storage.loadSongLibrary()
    let result = TeamImport.merge(teams: saved.items, library: library, roster: roster, opponents: opponents,
                                  extraWarmUps: extraWarmUps, durations: durations)

    // Song files first, then the library that names them, then the teams that use them.
    for file in Set(result.audioFiles).sorted() {
        let source = songsFolder.appendingPathComponent(file)
        let target = storage.audioFolder.appendingPathComponent(file)
        let same = FileManager.default.contentsEqual(atPath: source.path, andPath: target.path)
        if !same {
            try? FileManager.default.removeItem(at: target)
            try FileManager.default.copyItem(at: source, to: target)
            print("Copied \(file)")
        }
    }
    if result.library != library { try await storage.saveSongLibrary(result.library) }
    for team in result.teamsToSave { try await storage.saveTeam(team) }

    for note in result.notes { print(note) }
    if result.notes.isEmpty { print("Nothing changed: the saved files already match the roster.") }
}

/// `check`: lists what is saved and checks every song file. Returns false if anything is wrong.
func check(dataFolder: URL) async throws -> Bool {
    let storage = try openStorage(dataFolder)
    var ok = true
    let teams = try await storage.loadTeams()
    for damaged in teams.damaged { print("DAMAGED team file \(damaged.fileName): \(damaged.reason)"); ok = false }
    let library = try await storage.loadSongLibrary()
    let songsByID = Dictionary(library.songs.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })

    for team in teams.items {
        print("\(team.isOurs ? "OUR TEAM" : "Opponent"): \(team.name) (\(team.displayShortName)), \(team.roster.count) players")
        guard team.isOurs else { continue }
        for p in team.roster {
            let walkUp = p.walkUpSongID.flatMap { songsByID[$0] }
            let warmUp = p.warmUpSongID.flatMap { songsByID[$0] }
            var line = "  \(p.displayName)"
            line += p.number.map { " #\($0)" } ?? ""
            line += " · \(p.usualPosition?.abbreviation.uppercased() ?? "no position")"
            line += p.usualRole.map { " · \($0.rawValue)" } ?? ""
            line += p.usuallyLeadsOff ? " · leads off" : ""
            line += " · walk-up: \(walkUp.map { "\($0.title) from \(Int($0.startTime))s" } ?? "none")"
            if let warmUp { line += " · warm-up: \(warmUp.title)" }
            let extras = p.extraWarmUpSongIDs.compactMap { songsByID[$0] }
            if !extras.isEmpty { line += " · extra warm-ups: \(extras.map(\.title).joined(separator: ", "))" }
            print(line)
            if p.walkUpSongID != nil && walkUp == nil { print("  MISSING walk-up song in the library"); ok = false }
            if p.warmUpSongID != nil && warmUp == nil { print("  MISSING warm-up song in the library"); ok = false }
            if extras.count != p.extraWarmUpSongIDs.count { print("  MISSING extra warm-up song in the library"); ok = false }
        }
    }
    print("Songs: \(library.songs.count)")
    for song in library.songs {
        let file = storage.audioFolder.appendingPathComponent(song.fileName)
        if let length = await playableLength(file) {
            print("  OK \(song.fileName): \(song.title)\(song.artist.map { " — \($0)" } ?? ""), \(Int(length))s")
        } else {
            print("  NOT PLAYABLE \(song.fileName)")
            ok = false
        }
    }
    let games = try await storage.listGames()
    print("Games: \(games.items.count)\(games.damaged.isEmpty ? "" : ", \(games.damaged.count) damaged")")
    return ok
}

let args = CommandLine.arguments
switch (args.count > 1 ? args[1] : "", args.count) {
case ("load", 5):
    try await load(dataFolder: URL(fileURLWithPath: args[2]), teamFolder: URL(fileURLWithPath: args[3]),
                   songsFolder: URL(fileURLWithPath: args[4]))
case ("check", 3):
    if try await !check(dataFolder: URL(fileURLWithPath: args[2])) { fail("the check found problems (above)") }
default:
    fail("usage: TeamLoader load <app data folder> <team folder> <songs folder> | TeamLoader check <app data folder>")
}
