// The team that comes inside the app, for a phone that gets the Scorebook through TestFlight
// and is never plugged into Mikey's Mac.
//
// tools/upload_to_testflight.sh puts a copy of Mikey's saved files (every team, the song list,
// the song files and the announcer recordings, and the settings; no games) into the app as a
// `StarterTeam` folder. The first time the app opens with no teams saved, those files are
// copied into its data folder, exactly as tools/load_team.sh would have put them there.
//
// Copying the saved files themselves keeps every player's identity the same as on Mikey's
// phone. Builds made any other way carry no starter team, and a phone that already has a team
// is never touched.

import Foundation

enum StarterTeam {
    /// Copies the starter team into `dataFolder` if the app carries one and no team is saved yet.
    static func installIfNeeded(into dataFolder: URL, bundle: Bundle = .main) throws {
        guard let starter = bundle.url(forResource: "StarterTeam", withExtension: nil) else { return }
        let files = FileManager.default
        let teamsFolder = dataFolder.appending(path: "teams", directoryHint: .isDirectory)
        let savedTeams = (try? files.contentsOfDirectory(atPath: teamsFolder.path)) ?? []
        guard !savedTeams.contains(where: { $0.hasSuffix(".json") }) else { return }
        try copyMissing(from: starter, to: dataFolder)
    }

    /// Copies everything in `source` into `destination`, folder by folder, leaving any file
    /// already there as it is.
    private static func copyMissing(from source: URL, to destination: URL) throws {
        let files = FileManager.default
        try files.createDirectory(at: destination, withIntermediateDirectories: true)
        for name in try files.contentsOfDirectory(atPath: source.path) {
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
