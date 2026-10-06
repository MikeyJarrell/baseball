// The Record name button in its three places: the batter sheet (from the game menu's Edit this
// batter), the add-a-hitter sheet (a new player, Jackson Cleary, added and then recorded), and
// a player's page under Teams. Each opens the recorder showing the player's name to say. The
// microphone itself is not used here: the simulator has no voice to record.

import XCTest
import Model
import SampleData

final class NameRecordingSmokeTests: XCTestCase {
    /// The sample game with the Mudcats struck out in the top of the 1st, so the Diamond Dogs
    /// are batting.
    @MainActor
    private func launchWithOurTeamBatting() throws -> XCUIApplication {
        var events = [GameEvent(kind: .defenseConfirmed(DefenseConfirmed(team: .home)))]
        for _ in 0..<9 { events.append(GameEvent(kind: .pitch(Pitch(.swingingStrike)))) }
        let game = Game(id: "names", setup: SampleGame.game.setup, events: events)
        return try XCUIApplication.launch(seed: TestSeed(teams: [SampleTeams.diamondDogs, SampleTeams.mudcats], games: [game]))
    }

    /// Keeps a screenshot in the test results.
    @MainActor
    private func keep(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// A button whose words start with these.
    @MainActor
    private func button(_ app: XCUIApplication, startingWith words: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", words)).firstMatch
    }

    @MainActor
    func testRecordNameFromTheBatterSheet() throws {
        let app = try launchWithOurTeamBatting()
        XCTAssertTrue(app.buttons["Game menu"].waitForExistence(timeout: 10))
        // A tap while the batting screen is still sliding up is lost: tap until the menu opens.
        let editBatter = button(app, startingWith: "Edit this batter")
        for _ in 0..<3 where !editBatter.exists {
            app.buttons["Game menu"].tap()
            _ = editBatter.waitForExistence(timeout: 2)
        }
        editBatter.tap()
        let record = button(app, startingWith: "Record name")
        XCTAssertTrue(record.waitForExistence(timeout: 5), "Record name on the batter sheet")
        record.tap()
        let prompt = app.staticTexts["name-prompt"]
        XCTAssertTrue(prompt.waitForExistence(timeout: 5))
        XCTAssertEqual(prompt.label, "Alex Moreno")   // the Diamond Dogs' leadoff hitter
        XCTAssertTrue(app.buttons["Record name"].exists, "the big record button")
        keep(app, "recorder from the batter sheet")
        app.buttons["Cancel"].tap()
    }

    @MainActor
    func testAddAHitterAndRecordTheirName() throws {
        let app = try launchWithOurTeamBatting()
        XCTAssertTrue(app.buttons["Substitutions"].waitForExistence(timeout: 10))
        app.buttons["Substitutions"].tap()
        button(app, startingWith: "Add a hitter").tap()
        button(app, startingWith: "New player").tap()
        let name = app.textFields["Name (optional)"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Jackson Cleary")
        let addAndRecord = app.buttons["Add and record name"]
        XCTAssertTrue(addAndRecord.waitForExistence(timeout: 5))
        addAndRecord.tap()
        let prompt = app.staticTexts["name-prompt"]
        XCTAssertTrue(prompt.waitForExistence(timeout: 5))
        XCTAssertEqual(prompt.label, "Jackson Cleary")
        // No number: the introduction is "Now batting, Jackson Cleary."
        XCTAssertTrue(app.staticTexts["“Now batting, Jackson Cleary.”"].exists)
        keep(app, "recorder for a new hitter")
        app.buttons["Cancel"].tap()
        // He was added to the batting order all the same.
        XCTAssertEqual((app.readout["last"] as? [String: Any])?.keys.contains("addHitter"), true)
    }

    @MainActor
    func testRecordNameFromAPlayersPage() throws {
        let app = try XCUIApplication.launch(seed: TestSeed(teams: [SampleTeams.diamondDogs, SampleTeams.mudcats], games: []))
        XCTAssertTrue(app.buttons["Teams"].waitForExistence(timeout: 10))
        app.buttons["Teams"].tap()
        app.staticTexts["Diamond Dogs"].tap()
        let moreno = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Alex Moreno")).firstMatch
        XCTAssertTrue(moreno.waitForExistence(timeout: 5))
        moreno.tap()
        let record = button(app, startingWith: "Record name")
        for _ in 0..<4 where !record.isHittable { app.swipeUp() }
        record.tap()
        let prompt = app.staticTexts["name-prompt"]
        XCTAssertTrue(prompt.waitForExistence(timeout: 5))
        XCTAssertEqual(prompt.label, "Alex Moreno")
        keep(app, "recorder from the player page")
        app.buttons["Cancel"].tap()
    }
}
