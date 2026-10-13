// StarterGames: the finished games that come inside a TestFlight copy of the app, so a
// teammate's phone shows the season so far (the games list, box scores and season stats)
// without ever having scored those games.
//
// tools/upload_to_testflight.sh puts a copy of the games saved on Mikey's phone into the app.
// Each time the app opens, before storage reads anything, the finished ones are put in place:
//
// - A game the phone does not have is copied in.
// - A game the phone has under the same name is left alone: the phone's own copy wins. That
//   is Mikey's own phone, where the game was scored.
// - A game deleted on the phone stays deleted. `starter-games.json` in the data folder
//   remembers which games have been offered, so one is never brought back.
// - When a later copy of the app carries a corrected version of a game it copied in before,
//   the phone's copy is replaced, but only if it is still exactly as it was copied in, so
//   nothing scored or changed on the phone is ever overwritten.
//
// Games still in progress and files that do not read are never brought.

import CryptoKit
import Foundation
import Model

public enum StarterGames {
    /// `starter-games.json`: which starter games this phone has been offered.
    struct Record: Codable, Equatable {
        var formatVersion = 1
        /// What was last offered, by game file name.
        var offered: [String: Offer] = [:]
    }

    /// One starter game as it was last offered to this phone.
    struct Offer: Codable, Equatable {
        /// A fingerprint (SHA-256) of the offered file.
        var fingerprint: String
        /// True when the phone's copy of this game was copied in from the app, false when the
        /// phone already had the game or it has since been deleted here.
        var copiedIn: Bool
    }

    static let recordName = "starter-games.json"

    /// Puts the finished games in `starterGames` (a folder of game files) into the data
    /// folder's `games`, following the rules at the top of this file. Returns the names of the
    /// game files it wrote. Does nothing when the folder is not there.
    @discardableResult
    public static func install(from starterGames: URL, into dataFolder: URL) throws -> [String] {
        let files = FileManager.default
        guard let names = try? files.contentsOfDirectory(atPath: starterGames.path) else { return [] }
        let gamesFolder = dataFolder.appendingPathComponent("games", isDirectory: true)
        try files.createDirectory(at: gamesFolder, withIntermediateDirectories: true)

        let recordFile = dataFolder.appendingPathComponent(recordName)
        var record = (try? Data(contentsOf: recordFile)).flatMap { try? JSONDecoder().decode(Record.self, from: $0) } ?? Record()
        let before = record
        var written: [String] = []

        for name in names.sorted() where name.hasSuffix(".json") && !name.hasPrefix(".") {
            // Only finished games that read.
            guard let data = try? Data(contentsOf: starterGames.appendingPathComponent(name)),
                  let game = try? readSavedFile(GameFile.self, from: data, named: "games/\(name)").wholeGame,
                  game.isFinished else { continue }
            let fingerprint = Self.fingerprint(data)
            let last = record.offered[name]
            guard last?.fingerprint != fingerprint else { continue }   // already offered, as it is now

            let target = gamesFolder.appendingPathComponent(name)
            var copiedIn = false
            if let last {
                // A corrected version of a game offered before: replace the phone's copy only
                // if it was copied in from the app and has not changed since.
                if last.copiedIn, let saved = try? Data(contentsOf: target), Self.fingerprint(saved) == last.fingerprint {
                    try SafeFileWriter.write(data, to: target)
                    copiedIn = true
                }
            } else if !files.fileExists(atPath: target.path) {
                // Never offered, and the phone does not have this game: copy it in.
                try SafeFileWriter.write(data, to: target)
                copiedIn = true
            }
            if copiedIn { written.append(name) }
            record.offered[name] = Offer(fingerprint: fingerprint, copiedIn: copiedIn)
        }

        if record != before {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try SafeFileWriter.write(try encoder.encode(record), to: recordFile)
        }
        return written
    }

    /// A file's SHA-256 fingerprint, as text.
    static func fingerprint(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
