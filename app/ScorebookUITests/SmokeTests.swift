// Quick checks of the app shell: a seeded game in progress opens straight onto the batting
// screen, and with no game in progress the home screen and the teams pages open. Each keeps a
// screenshot in the test results.

import XCTest
import Model
import SampleData

final class SmokeTests: XCTestCase {
    /// Keeps a screenshot of the app in the test results.
    @MainActor
    private func keepScreenshot(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testOpensGameInProgressOnTheBattingScreen() throws {
        let game = Game(id: "smoke", setup: SampleGame.game.setup)
        let app = try XCUIApplication.launch(seed: TestSeed(teams: [SampleTeams.diamondDogs, SampleTeams.mudcats], games: [game]))
        // The Diamond Dogs are home, so the defense check opens first, over the batting screen.
        XCTAssertTrue(app.buttons["Ball"].waitForExistence(timeout: 10))
        keepScreenshot(app, named: "defense check on resume")
        XCTAssertEqual(app.readout["count"] as? Int, 0)
    }

    @MainActor
    func testHomeScreenAndTeams() throws {
        let app = try XCUIApplication.launch(seed: TestSeed(teams: [SampleTeams.diamondDogs, SampleTeams.mudcats], games: []))
        XCTAssertTrue(app.staticTexts["Scorebook"].waitForExistence(timeout: 10))
        for tile in ["New game", "Teams", "Songs", "Season stats", "Games", "Last box score"] {
            XCTAssertTrue(app.buttons[tile].exists, "\(tile) tile")
        }
        keepScreenshot(app, named: "home")
        app.buttons["Teams"].tap()
        XCTAssertTrue(app.staticTexts["Diamond Dogs"].waitForExistence(timeout: 5))
        keepScreenshot(app, named: "teams")
    }
}
