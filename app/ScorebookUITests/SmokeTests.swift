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
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Everyone’s")).firstMatch.exists, "the defense check itself")
        keepScreenshot(app, named: "defense check after a strikeout")

        link.tap()
        // The big answer button "Thrown out at first".
        let thrownOut = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Thrown out at first")).firstMatch
        XCTAssertTrue(thrownOut.waitForExistence(timeout: 5), "the dropped-third-strike steps")
        keepScreenshot(app, named: "dropped third strike steps")
        app.buttons["Cancel"].tap()

        // Backed out: the inning still ends, so the check comes back.
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Everyone’s")).firstMatch.waitForExistence(timeout: 5), "the check back again")
    }

    /// Deleting the game in progress from the games list: Edit, Delete, the question naming
    /// the game, then the list holds only the other game and home offers nothing to resume.
    @MainActor
    func testDeleteAGameFromTheGamesList() throws {
        let finished = SampleGame.game
        var started = Game(id: "test-game", setup: SampleGame.game.setup)
        started.setup.scheduledStart = finished.setup.scheduledStart.addingTimeInterval(86_400)
        started.events = [GameEvent(kind: .defenseConfirmed(DefenseConfirmed(team: .home))),
                          GameEvent(kind: .pitch(Pitch(.ball)))]
        let app = try XCUIApplication.launch(seed: TestSeed(teams: [SampleTeams.diamondDogs, SampleTeams.mudcats],
                                                            games: [finished, started]))
        // The game in progress opens first; the game menu's Home screen goes back home.
        XCTAssertTrue(app.buttons["Ball"].waitForExistence(timeout: 10))
        // The batting screen slides up over the home screen when the app opens; a tap while it
        // is still sliding is lost, so tap the menu again until it opens.
        let firstRow = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Date, start")).firstMatch
        for _ in 0..<3 where !firstRow.exists {
            app.buttons["Game menu"].tap()
            _ = firstRow.waitForExistence(timeout: 2)
        }
        // The menu fills the screen, with Pause near the bottom of its list.
        let home = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Pause and go")).firstMatch
        for _ in 0..<4 where !home.isHittable { firstRow.swipeUp() }
        XCTAssertTrue(home.exists, "Home screen in the game menu")
        home.tap()

        XCTAssertTrue(app.buttons["Games"].waitForExistence(timeout: 5))
        app.buttons["Games"].tap()
        app.buttons["Edit"].tap()
        let deleteButtons = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Delete vs"))
        XCTAssertEqual(deleteButtons.count, 2)
        // Newest first: the game in progress is on top.
        deleteButtons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["Delete Diamond Dogs vs Mudcats, \(Self.shortDate(started.setup.scheduledStart))?"].waitForExistence(timeout: 3))
        keepScreenshot(app, named: "delete question")
        app.buttons["Delete game"].tap()

        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Delete vs")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Delete vs")).count, 1)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["New game"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Resume scoring")).firstMatch.exists)
    }

    /// "Oct 4", as the app writes a date in the question.
    static func shortDate(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .omitted, locale: Locale(identifier: "en_US")).month(.abbreviated).day())
    }
}
