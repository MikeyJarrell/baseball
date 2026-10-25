// Walks the game setup from "New game" to "Play ball", one screen at a time: opponent, game
// details, batting order, fielders, their lineup, starting pitchers, review. Each screen keeps
// a screenshot in the test results.

import XCTest
import Model
import SampleData

final class GameSetupWalkthroughTests: XCTestCase {
    /// Keeps a screenshot in the test results, and as a file when the test run names a folder
    /// for them in `SCREENSHOT_DIR`.
    @MainActor
    private func keepScreenshot(_ app: XCUIApplication, named name: String) {
        let shot = app.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let folder = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] {
            try? shot.pngRepresentation.write(to: URL(fileURLWithPath: folder).appending(path: "\(name).png"))
        }
    }

    @MainActor
    func testSetupFromNewGameToPlayBall() throws {
        let app = try XCUIApplication.launch(seed: TestSeed(teams: [SampleTeams.diamondDogs, SampleTeams.mudcats], games: []))
        XCTAssertTrue(app.buttons["New game"].waitForExistence(timeout: 10))
        app.buttons["New game"].tap()

        // The opponent screen holds the opponents and nothing about the date or time.
        XCTAssertTrue(app.buttons["Next: game details"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Innings"].exists)
        app.buttons.containing(NSPredicate(format: "label BEGINSWITH 'Mudcats'")).firstMatch.tap()
        keepScreenshot(app, named: "01 opponent")

        // Each screen's big button names the next one; the last one starts the game.
        let screens = [
            ("Next: game details", "02 game details"),
            ("Next: batting order", "03 batting order"),
            ("Next: fielders", "04 fielders"),
            // Our sample players have no recorded names, so the announcer step comes next.
            ("Next: Mudcats lineup", "05 announcer"),
            ("Next: Mudcats lineup", "06 their lineup"),
            ("Next: Mudcats fielders", "07 their fielders"),
            ("Next: review", "08 review"),
        ]
        for (button, name) in screens {
            XCTAssertTrue(app.buttons[button].waitForExistence(timeout: 5), button)
            app.buttons[button].tap()
            // Give the next screen a moment to slide in before the picture.
            _ = app.buttons["no such button"].waitForExistence(timeout: 0.7)
            keepScreenshot(app, named: name)
            // The details screen with a time wheel open, the tallest it gets.
            if name == "02 game details" {
                app.buttons.containing(NSPredicate(format: "label BEGINSWITH 'Start'")).firstMatch.tap()
                _ = app.buttons["no such button"].waitForExistence(timeout: 0.7)
                keepScreenshot(app, named: "02 game details, start wheel open")
            }
        }
        XCTAssertTrue(app.buttons["Play ball"].waitForExistence(timeout: 5))
        app.buttons["Play ball"].tap()
        XCTAssertTrue(app.buttons["Ball"].waitForExistence(timeout: 10))
    }
}
