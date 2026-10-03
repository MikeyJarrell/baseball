// What each saved file looks like on disk, and how a file is checked as it is read.
//
// Every file starts with its format version, so a later version of the app can tell an
// old file from a new one:
//
//     { "formatVersion" : 1, "team" : { ...the team... } }
//
// Game files are laid out by hand in GameFileLayout.swift; the rest are written by
// `ScorebookJSON`, Model's one agreed way of writing JSON.

import Foundation
import Model

/// `teams/<team id>.json`
struct TeamFile: Codable {
    var formatVersion: Int
    var team: Team
}

/// `songs/library.json`
struct SongLibraryFile: Codable {
    var formatVersion: Int
    var songLibrary: SongLibrary
}

/// `settings.json`
struct SettingsFile: Codable {
    var formatVersion: Int
    var settings: AppSettings
}

/// `games/<game id>.json`: the game's setup under `game`, and its events listed separately
/// under `events`, one per line, so adding an event never has to re-encode the earlier ones.
/// The `events` list inside `game` is left empty when storage writes the file. When reading,
/// the two lists are joined, so a game written by hand with its events inside `game` also reads.
struct GameFile: Codable {
    var formatVersion: Int
    var game: Game
    var events: [GameEvent]?

    /// The game with every event in order.
    var wholeGame: Game {
        var whole = game
        whole.events += events ?? []
        return whole
    }
}

/// `backups/backup-<date>.json`: everything except the audio, in one file.
struct BackupFile: Codable {
    var formatVersion: Int
    /// When the backup was made.
    var madeAt: Date
    var teams: [Team]
    var games: [Game]
    /// Missing if no song library had been saved.
    var songLibrary: SongLibrary?
    /// Missing if no settings had been saved.
    var settings: AppSettings?
    /// Files that could not be read when the backup was made, copied byte for byte so a
    /// restore puts them back as they were, for someone to rescue by hand.
    var unreadableFiles: [UnreadableFileCopy]
}

/// A saved file that could not be read, kept exactly as it was.
struct UnreadableFileCopy: Codable, Equatable {
    /// Its name inside the storage folder, such as "games/1234.json".
    var fileName: String
    /// Its bytes, written in the backup as base64 text.
    var contents: Data
}

/// Just the version tag, read before anything else in a file.
private struct VersionTag: Decodable {
    var formatVersion: Int?
}

/// Reads one saved file's bytes into its file type, checking the version tag first.
/// Throws `StorageError.damaged` with a plain-words reason if anything is wrong.
func readSavedFile<T: Decodable>(_ type: T.Type, from data: Data, named fileName: String) throws -> T {
    if data.isEmpty {
        throw StorageError.damaged(file: fileName, reason: "The file is empty.")
    }
    let tag: VersionTag
    do {
        tag = try ScorebookJSON.decode(VersionTag.self, from: data)
    } catch {
        throw StorageError.damaged(file: fileName, reason: plainReason(for: error))
    }
    guard let version = tag.formatVersion else {
        throw StorageError.damaged(file: fileName, reason: "The file has no format version, so it was not saved by this app.")
    }
    if version > ScorebookJSON.formatVersion {
        throw StorageError.damaged(
            file: fileName,
            reason: "The file was saved by a newer version of the app (format \(version)). Update the app to read it.")
    }
    if version < 1 {
        throw StorageError.damaged(file: fileName, reason: "The file has an unknown format version (\(version)).")
    }
    // Only format 1 exists so far. When the format changes, older versions are converted
    // to the current one here, before decoding.
    do {
        return try ScorebookJSON.decode(T.self, from: data)
    } catch {
        throw StorageError.damaged(file: fileName, reason: plainReason(for: error))
    }
}

/// Turns a JSON reading error into a sentence the scorer can make sense of.
func plainReason(for error: Error) -> String {
    guard let error = error as? DecodingError else {
        return "The file could not be read (\(error.localizedDescription))."
    }
    switch error {
    case .dataCorrupted(let context) where context.codingPath.isEmpty:
        return "The file is not readable JSON. It may have been cut off or garbled."
    case .dataCorrupted(let context):
        return "Something in the file is not valid, at \(place(context.codingPath)): \(context.debugDescription)"
    case .keyNotFound(let key, let context):
        return "Something the file needs is missing: \"\(key.stringValue)\" at \(place(context.codingPath))."
    case .typeMismatch(_, let context), .valueNotFound(_, let context):
        return "Something in the file has the wrong form, at \(place(context.codingPath))."
    @unknown default:
        return "The file could not be read."
    }
}

/// Where in the file a problem is, such as "events 12 pitch result".
private func place(_ path: [CodingKey]) -> String {
    if path.isEmpty { return "the top of the file" }
    return path.map { $0.intValue.map(String.init) ?? $0.stringValue }.joined(separator: " ")
}
