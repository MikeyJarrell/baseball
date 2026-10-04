// Starting the app for a simulator test: a fresh, empty test folder, with the teams and the
// game to score saved before the app opens (see app/Scorebook/LaunchOptions.swift). The app
// opens straight to a game in progress, so the test starts on the batting screen.

import XCTest
import Model

/// The teams and games the app saves before it opens. Matches `TestSeed` in the app.
struct TestSeed: Codable {
    var teams: [Team]
    var games: [Game]
}

extension XCUIApplication {
    /// Starts the app in test mode with these teams and games saved.
    static func launch(seed: TestSeed) throws -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launchEnvironment["SCOREBOOK_TEST_SEED"] = try ScorebookJSON.encode(seed).base64EncodedString()
        app.launch()
        return app
    }

    /// The game screen's hidden readout: event count, the last event, where the game stands,
    /// and the printed box score once the game is over.
    var readout: [String: Any] {
        let element = descendants(matching: .any)["test-readout"]
        guard element.waitForExistence(timeout: 5),
              let data = element.label.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return object
    }
}
