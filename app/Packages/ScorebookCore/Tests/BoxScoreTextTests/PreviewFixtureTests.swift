// The box score picture's previews cannot use SampleData (the BoxScorePicture module is not
// allowed to), so they read copies of the sample box scores saved as JSON in
// ScorebookUI/Sources/BoxScorePicture/Resources. This test checks the copies still match
// SampleData, so the previews never quietly drift from the real sample game.
//
// To rewrite the copies after SampleData changes, run:
//     WRITE_PREVIEW_BOX_SCORES=1 swift test --filter PreviewFixtureTests

import Foundation
import Testing
import Model
import SampleData

@Suite("The picture's preview box scores")
struct PreviewFixtureTests {
    /// The folder holding the copies, found from this file's own location.
    static let folder = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()      // BoxScoreTextTests
        .deletingLastPathComponent()      // Tests
        .deletingLastPathComponent()      // ScorebookCore
        .deletingLastPathComponent()      // Packages
        .appendingPathComponent("ScorebookUI/Sources/BoxScorePicture/Resources")

    /// Each saved copy and the sample box score it must match.
    static let copies: [(file: String, box: BoxScore)] = [
        ("sample-game-box-score.json", SampleGame.boxScore),
        ("sample-game-through-three-box-score.json", SampleGame.boxScoreThroughThree),
    ]

    @Test("The saved copies match the sample game's box scores")
    func copiesMatch() throws {
        let rewrite = ProcessInfo.processInfo.environment["WRITE_PREVIEW_BOX_SCORES"] == "1"
        for (file, box) in Self.copies {
            let url = Self.folder.appendingPathComponent(file)
            if rewrite {
                // Saved without indenting, to keep the copies small inside the app.
                let encoder = ScorebookJSON.encoder()
                encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
                try encoder.encode(box).write(to: url)
            }
            let saved = try ScorebookJSON.decode(BoxScore.self, from: Data(contentsOf: url))
            #expect(saved == box, "\(file) is out of date; see the comment at the top of this file")
        }
    }
}
