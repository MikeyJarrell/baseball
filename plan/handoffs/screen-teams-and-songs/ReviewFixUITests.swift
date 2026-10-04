// Checks the review's findings by tapping through the harness: a scroll that starts on a song's
// track leaves the start point alone while a tap moves it, and a warm-up song picked from a
// player's page is still there after Done.
import XCTest

final class ReviewFixUITests: XCTestCase {
    @MainActor
    func testScrollingOverTheTrackLeavesTheStartPoint() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-route", "song", "-song", "song-03"]
        app.launch()
        let track = app.otherElements["Start point"].firstMatch
        XCTAssertTrue(track.waitForExistence(timeout: 5))
        let before = track.value as? String
        XCTAssertEqual(before, "0:14.0")
        // A scroll up, then down, starting on the track.
        track.swipeUp()
        track.swipeDown()
        XCTAssertEqual(track.value as? String, before, "a vertical scroll moved the start point")
        // A tap near the right end moves it.
        track.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertNotEqual(track.value as? String, before, "a tap did not move the start point")
        print("START POINT after tap: \(track.value as? String ?? "?")")
    }

    @MainActor
    func testWarmUpSongPickedFromThePlayerPageStays() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-route", "player", "-player", "d8"]
        app.launch()
        // First, Done with nothing picked leaves the page as it was.
        app.buttons["Pick a warm-up song"].firstMatch.tap()
        app.buttons["Done"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["No warm-up song"].firstMatch.waitForExistence(timeout: 5))
        app.buttons["Pick a warm-up song"].firstMatch.tap()
        // The song is near the end of the list, so find it with the search field.
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Walk-Off")
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Walk-Off Waltz")).firstMatch.tap()
        // Picking closes the picker by itself.
        XCTAssertTrue(app.staticTexts["Walk-Off Waltz"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Change warm-up song"].firstMatch.exists)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "warmup"; shot.lifetime = .keepAlways; add(shot)
    }

    @MainActor
    func testSharedNumberStaysMarked() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-route", "team", "-team", "diamond-dogs"]
        app.launch()
        app.buttons["Quick entry"].firstMatch.tap()
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.typeText("22 Second Webb\n")
        // After Return the line is clear, and the shared number is still marked above the keyboard.
        XCTAssertTrue(app.staticTexts["Same number as Jordan Webb"].firstMatch.waitForExistence(timeout: 5))
        let mid = XCTAttachment(screenshot: app.screenshot()); mid.name = "sharednumber"; mid.lifetime = .keepAlways; add(mid)
        app.buttons["Done"].tap()
        // On the roster, the original 22 is marked too.
        XCTAssertTrue(app.staticTexts["Same number as Second Webb"].firstMatch.waitForExistence(timeout: 5))
    }

    @MainActor
    func testRecordingSheetCannotBeSwipedAway() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-route", "player", "-player", "d3"]
        app.launch()
        app.buttons["Record introduction"].firstMatch.tap()
        app.buttons["Record"].firstMatch.tap()
        // A swipe down on the sheet while recording leaves it open.
        app.navigationBars.firstMatch.swipeDown(velocity: .fast)
        XCTAssertTrue(app.buttons["Stop recording"].firstMatch.waitForExistence(timeout: 3))
        app.buttons["Stop recording"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Keep"].firstMatch.waitForExistence(timeout: 3))
        app.navigationBars.firstMatch.swipeDown(velocity: .fast)
        XCTAssertTrue(app.buttons["Keep"].firstMatch.waitForExistence(timeout: 3))
        // Cancel asks first.
        app.buttons["Cancel"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Throw it away"].firstMatch.waitForExistence(timeout: 3))
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "cancelask"; shot.lifetime = .keepAlways; add(shot)
    }
}
