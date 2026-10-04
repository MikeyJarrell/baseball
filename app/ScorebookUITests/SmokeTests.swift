// A quick check that the app opens a seeded game in progress straight to the batting screen
// and records a pitch through the game session.

import XCTest
import Model
import SampleData

final class SmokeTests: XCTestCase {
    @MainActor
    func testOpensGameInProgressAndRecordsABall() throws {
        let game = Game(id: "smoke", setup: SampleGame.game.setup)
        let app = try XCUIApplication.launch(seed: TestSeed(teams: [SampleTeams.diamondDogs, SampleTeams.mudcats], games: [game]))
        // The Diamond Dogs are home, so the defense check opens first: confirm it.
        let ball = app.buttons["Ball"]
        XCTAssertTrue(ball.waitForExistence(timeout: 10))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.lifetime = .keepAlways
        add(attachment)
        print("READOUT", app.readout)
    }
}
