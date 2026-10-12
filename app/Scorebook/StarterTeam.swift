// The team that comes inside the app, for a phone that gets the Scorebook through TestFlight
// and is never plugged into Mikey's Mac.
//
// tools/upload_to_testflight.sh puts a copy of Mikey's saved files (every team, the song list,
// the song files and the announcer recordings, the settings, and the games) into the app as a
// `StarterTeam` folder. The first time the app opens with no teams saved, the teams, songs and
// settings are copied into its data folder, exactly as tools/load_team.sh would have put them
// there. A phone that already has a team keeps its own.
//
// The finished games are handled apart, every time the app opens, so a phone that got its team
// from an earlier copy of the app still gets the season so far: a game the phone does not have
// is copied in once, and one deleted there stays deleted (see `StarterGames` in Storage).
//
// Copying the saved files themselves keeps every player's identity the same as on Mikey's
// phone, so the games' stats line up with the roster. Builds made any other way carry no
// starter team.

import Foundation
import Storage

enum StarterTeam {
    /// Copies the starter team into `dataFolder` if the app carries one and no team is saved
    /// yet, and brings in any finished game the app carries that this phone has not been
    /// offered before.
    static func installIfNeeded(into dataFolder: URL, bundle: Bundle = .main) throws {
        guard let starter = bundle.url(forResource: "StarterTeam", withExtension: nil) else { return }
        let files = FileManager.default
        let teamsFolder = dataFolder.appending(path: "teams", directoryHint: .isDirectory)
        let savedTeams = (try? files.contentsOfDirectory(atPath: teamsFolder.path)) ?? []
        if !savedTeams.contains(where: { $0.hasSuffix(".json") }) {
            try copyMissing(from: starter, to: dataFolder, skipping: ["games"])
        }
        // A game that cannot be brought in must not stop the app from opening.
        _ = try? StarterGames.install(from: starter.appending(path: "games", directoryHint: .isDirectory), into: dataFolder)
    }

    /// Copies everything in `source` into `destination`, folder by folder, leaving any file
    /// already there as it is. The top-level names in `skipping` are left out.
    private static func copyMissing(from source: URL, to destination: URL, skipping: Set<String> = []) throws {
        let files = FileManager.default
        try files.createDirectory(at: destination, withIntermediateDirectories: true)
        for name in try files.contentsOfDirectory(atPath: source.path) where !skipping.contains(name) {
            let from = source.appending(path: name)
            let to = destination.appending(path: name)
            var isFolder: ObjCBool = false
            files.fileExists(atPath: from.path, isDirectory: &isFolder)
            if isFolder.boolValue {
                try copyMissing(from: from, to: to)
            } else if !files.fileExists(atPath: to.path) {
                try files.copyItem(at: from, to: to)
            }
        }
    }
}
