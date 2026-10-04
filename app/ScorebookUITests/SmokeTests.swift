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

    /// After a strikeout for the third out, the defense check still opens by itself, with a
    /// "Dropped third strike instead" link that opens those steps and brings the check back
    /// if the scorer backs out.
    @MainActor
    func testDefenseCheckAfterAStrikeoutOffersTheDroppedThirdStrike() throws {
        // The Diamond Dogs are home. Six strikeouts in a row: the Mudcats go down in the top of
        // the 1st, then the Diamond Dogs in the bottom, so the last out is a strikeout and the
        // Diamond Dogs take the field.
        var events = [GameEvent(kind: .defenseConfirmed(DefenseConfirmed(team: .home)))]
        events += Array(repeating: GameEvent(kind: .pitch(Pitch(.swingingStrike))), count: 18).map {
            GameEvent(kind: $0.kind)
        }
        let game = Game(id: "strikeouts", setup: SampleGame.game.setup, events: events)
        let app = try XCUIApplication.launch(seed: TestSeed(teams: [SampleTeams.diamondDogs, SampleTeams.mudcats], games: [game]))

        let link = app.buttons["Dropped third strike instead"]
        XCTAssertTrue(link.waitForExistence(timeout: 10), "the link on the defense check")
        XCTAssertTrue(app.buttons["Everyone’s where they were"].exists, "the defense check itself")
        keepScreenshot(app, named: "defense check after a strikeout")

        link.tap()
        XCTAssertTrue(app.buttons["Thrown out at first"].waitForExistence(timeout: 5), "the dropped-third-strike steps")
        keepScreenshot(app, named: "dropped third strike steps")
        app.buttons["Cancel"].tap()

        // Backed out: the inning still ends, so the check comes back.
        XCTAssertTrue(app.buttons["Everyone’s where they were"].waitForExistence(timeout: 5), "the check back again")
    }
}
