// Where the app keeps its files, and the one way automated tests can start it with
// teams and a game already set up.
//
// On Mikey's phone the app always uses its own two folders: the private Application Support
// folder for the live files, and `backups` inside Documents, the one folder the iPhone Files
// app shows. Nothing else is ever written to Documents.
//
// The simulator tests (app/ScorebookUITests) start the app with "-uiTesting" and, optionally,
// a seed: teams and games to save before the app opens. The app then uses a separate,
// emptied test folder, so a test never touches real games.

import Foundation
import Model

/// How the app was started.
struct LaunchOptions {
    /// True when a simulator test started the app.
    var isUITest: Bool
    /// Teams and games a test asked to have saved before the app opens.
    var seed: TestSeed?

    /// The options the app was actually started with.
    static var fromProcess: LaunchOptions {
        let info = ProcessInfo.processInfo
        let isUITest = info.arguments.contains("-uiTesting")
        var seed: TestSeed?
        if isUITest, let text = info.environment[TestSeed.environmentKey],
           let data = Data(base64Encoded: text) {
            seed = try? ScorebookJSON.decode(TestSeed.self, from: data)
        }
        return LaunchOptions(isUITest: isUITest, seed: seed)
    }

    /// The folder for the live files and the folder for backups.
    func folders() throws -> (data: URL, backups: URL) {
        if isUITest {
            // A fresh, empty folder for every test run, away from the real files.
            let root = URL.temporaryDirectory.appending(path: "ScorebookUITest", directoryHint: .isDirectory)
            try? FileManager.default.removeItem(at: root)
            return (root.appending(path: "data", directoryHint: .isDirectory),
                    root.appending(path: "backups", directoryHint: .isDirectory))
        }
        return (URL.applicationSupportDirectory.appending(path: "Scorebook", directoryHint: .isDirectory),
                URL.documentsDirectory.appending(path: "backups", directoryHint: .isDirectory))
    }
}

/// Teams and games for a simulator test to start from. The test writes it as JSON, in
/// base 64, into the launch environment under `SCOREBOOK_TEST_SEED`.
struct TestSeed: Codable {
    /// The launch environment's name for the seed.
    static let environmentKey = "SCOREBOOK_TEST_SEED"

    /// Teams to save.
    var teams: [Team]
    /// Games to save. A game with no end is the game in progress, which the app opens.
    var games: [Game]

    /// Saves the teams and games.
    func install(in storage: some ScorebookStorage) async throws {
        for team in teams { try await storage.saveTeam(team) }
        for game in games { try await storage.saveGame(game) }
    }
}
