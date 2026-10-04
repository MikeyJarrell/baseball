// Two complete games scored tap by tap through the app's real screens, checked after every
// event and at the end against the box score worked out from the book (see GameDriver.swift):
//   - the made-up sample game, Mudcats at Diamond Dogs (SampleData's `SampleGame`), which has
//     a bit of everything: errors, a fielder's choice, sacrifices, a hit batter, an intentional
//     walk, steals, a runner for a designated non-runner, a pinch hitter, two pitching changes,
//     and our team's defense check every time it takes the field;
//   - a real Major League game, Houston Astros at New York Yankees, June 23, 2019, from
//     Retrosheet (Games/2019-06-23-astros-at-yankees.json).
//
// A full game takes several minutes. To try out only the start of a game, run with the
// environment variable TEST_RUNNER_SCORING_EVENTS set to how many events to enter; the box
// score is then not checked.

import XCTest
import Model
import SampleData

final class ScoringWalkthroughTests: XCTestCase {
    override func setUp() {
        // Keep going after a recorded failure (an event the screens cannot enter exactly), so
        // the rest of the game is still checked. A real disagreement stops the game anyway.
        continueAfterFailure = true
    }

    /// The sample game, Mudcats at Diamond Dogs: 154 events, our team at home.
    @MainActor
    func testSampleGame() throws {
        let book = SampleGame.game
        let game = Game(id: "sample-walkthrough", setup: book.setup)
        let app = try XCUIApplication.launch(seed: TestSeed(teams: [SampleTeams.diamondDogs, SampleTeams.mudcats],
                                                            games: [game]))
        try score(Game(id: game.id, setup: book.setup, events: book.events), in: app)
    }

    /// Houston Astros at New York Yankees, 2019: 291 events, two teams that are not ours.
    @MainActor
    func testAstrosAtYankees() throws {
        let book = try Self.loadGame(named: "2019-06-23-astros-at-yankees")
        let app = try XCUIApplication.launch(seed: TestSeed(teams: [], games: [Game(id: book.id, setup: book.setup)]))
        try score(book, in: app)
    }

    // MARK: - Shared steps

    /// Scores the game event by event, then compares the box scores.
    @MainActor
    private func score(_ book: Game, in app: XCUIApplication) throws {
        XCTAssertTrue(app.buttons["Ball"].waitForExistence(timeout: 15), "The batting screen did not open")
        let driver = GameDriver(app: app, expected: book)
        let limit = ProcessInfo.processInfo.environment["SCORING_EVENTS"].flatMap(Int.init)

        let box: String?
        do {
            box = try driver.scoreGame(firstEvents: limit)
        } catch {
            report(driver)
            throw error
        }
        report(driver)
        guard let box else {
            if limit == nil { XCTFail("The game is over, but the app shows no box score") }
            return
        }
        driver.attachScreenshot(named: "Final box score")
        attachText(box, named: "Box score from the app")
        attachText(driver.expectedBox, named: "Box score from the book")

        // The game's length is the one line that cannot match: the app times the test's taps.
        let fromApp = GameDriver.withoutGameLength(box)
        let fromBook = GameDriver.withoutGameLength(driver.expectedBox)
        if fromApp != fromBook {
            XCTFail("The box scores differ:\n\(Self.differences(fromApp, fromBook))")
        }
    }

    /// Adds the driver's notes (details that differ, events the screens cannot enter) to the results.
    @MainActor
    private func report(_ driver: GameDriver) {
        if !driver.detailNotes.isEmpty {
            attachText(driver.detailNotes.joined(separator: "\n\n"), named: "Details that differ, not in the box score")
            print("DETAIL NOTES\n" + driver.detailNotes.joined(separator: "\n"))
        }
        if !driver.gaps.isEmpty { print("GAPS\n" + driver.gaps.joined(separator: "\n")) }
    }

    /// Adds some text to the test results.
    private func attachText(_ text: String, named name: String) {
        let attachment = XCTAttachment(string: text)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// The lines that differ between two box scores, app first.
    static func differences(_ app: String, _ book: String) -> String {
        let a = app.components(separatedBy: "\n"), b = book.components(separatedBy: "\n")
        var lines: [String] = []
        for i in 0..<max(a.count, b.count) {
            let left = i < a.count ? a[i] : "(none)", right = i < b.count ? b[i] : "(none)"
            if left != right { lines.append("line \(i + 1)\n  app:  \(left)\n  book: \(right)") }
        }
        return lines.joined(separator: "\n")
    }

    /// A game file from the Games folder: its setup and every event.
    static func loadGame(named name: String) throws -> Game {
        // The file travels in the test bundle; when running from the source tree it is also beside this file.
        let bundled = Bundle(for: ScoringWalkthroughTests.self).url(forResource: name, withExtension: "json")
        let beside = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appending(path: "Games/\(name).json")
        let data = try Data(contentsOf: bundled ?? beside)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let setup = object["setup"], let events = object["events"] else {
            throw DriverStop(description: "\(name).json has no setup or events")
        }
        return Game(id: GameID(rawValue: name),
                    setup: try ScorebookJSON.decode(GameSetup.self, from: JSONSerialization.data(withJSONObject: setup)),
                    events: try ScorebookJSON.decode([GameEvent].self, from: JSONSerialization.data(withJSONObject: events)))
    }
}
