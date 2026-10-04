// The newsprint look: the paper and ink colors, and the type sizes, of the box score
// picture.
//
// These colors are fixed on purpose and are the one place the app uses raw colors: the
// picture is sent to other people's phones as an image, so it must look like newsprint
// whether the scorer's phone is in light or dark mode. The values come from the approved
// mockup (plan/mockups/index.html, `--paper` and `--paper-ink`).
//
// The type is the iPhone's built-in serif face (New York), at fixed sizes that do not grow
// with the phone's text-size setting, so the picture always lays out the same way.

import SwiftUI

/// The paper, ink and type of the newspaper box score picture.
enum Newsprint {
    /// Warm off-white paper, #F3EEE1.
    static let paper = Color(red: 0xF3 / 255, green: 0xEE / 255, blue: 0xE1 / 255)
    /// Near-black ink, #1A1712.
    static let ink = Color(red: 0x1A / 255, green: 0x17 / 255, blue: 0x12 / 255)

    /// How wide the picture is, in points: the width of the narrowest current iPhone
    /// screen, so it fills a phone without being shrunk.
    static let width: CGFloat = 375
    /// Space between the edge of the paper and the type.
    static let sideMargin: CGFloat = 16

    /// Ordinary lines: batters, pitchers, notes.
    static let bodySize: CGFloat = 14
    /// Column headings and team headings.
    static let headingSize: CGFloat = 12
    /// The date above the headline.
    static let dateSize: CGFloat = 11.5
    /// The headline.
    static let headlineSize: CGFloat = 23

    /// Width of each number column in the batting and pitching tables.
    static let columnWidth: CGFloat = 30
    /// Width of one character in an inning cell of the line score.
    static let inningCharacterWidth: CGFloat = 8.5

    /// The serif type at a size and weight, with digits all the same width so columns of
    /// numbers line up.
    static func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        Font.system(size: size, weight: weight, design: .serif).monospacedDigit()
    }
}
