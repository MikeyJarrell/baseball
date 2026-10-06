// Times entering a twelve-player roster with quick entry, typing each line and pressing Return
// without touching the typing field again (so the keyboard must stay up between players), and
// choosing Left for the left-handed batters and throwers.
import XCTest

final class QuickEntryTimingTests: XCTestCase {
    @MainActor
    func testTwelvePlayerRoster() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-route", "team", "-team", "new-team"]
        app.launch()

        // (line typed, bats left?, throws left?)
        let players: [(String, Bool, Bool)] = [
            ("3 Alex Moreno", false, false), ("6 Chris Tate", true, false), ("22 Jordan Webb", false, false),
            ("33 Pat Quinn", true, true), ("12 Riley Shaw", false, false), ("9 Casey Ford", false, false),
            ("17 Drew Lang", true, false), ("10 Morgan Fisk", false, false), ("21 Sky Barros", false, false),
            ("14 Jamie Cole", true, true), ("27 Robin Nash", false, false), ("44 Taylor Voss", true, true),
        ]
        var taps = 0
        let start = Date()
        app.buttons["Quick entry"].firstMatch.tap(); taps += 1
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        for (line, batsLeft, throwsLeft) in players {
            // The left-handed choices come before typing the line, since Return adds the player.
            if batsLeft { app.buttons.matching(identifier: "Left").element(boundBy: 0).tap(); taps += 1 }
            if throwsLeft { app.buttons.matching(identifier: "Left").element(boundBy: 1).tap(); taps += 1 }
            field.typeText(line + "\n")
            taps += line.count + 1
            if line.hasPrefix("33 ") {
                // Partway through: the sheet with the keyboard still up, ready for the next player.
                let mid = XCTAttachment(screenshot: app.screenshot()); mid.name = "midway"; mid.lifetime = .keepAlways; add(mid)
            }
        }
        app.buttons["Done"].tap(); taps += 1
        let seconds = Date().timeIntervalSince(start)
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", "12 players, names and numbers")).firstMatch.waitForExistence(timeout: 5))
        print("QUICK ENTRY TIMING: 12 players in \(String(format: "%.1f", seconds)) seconds, \(taps) taps and keystrokes")
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.lifetime = .keepAlways; add(shot)
    }
}
