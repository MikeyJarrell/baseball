// The app's named text styles and spacing values.
//
// Placeholder values written by the foundation job; the designer fills in the real ones.
// All type uses fonts that come with iOS and grows with the phone's text size setting.

import SwiftUI

/// Every text style the app uses, by what it is for.
public enum ScorebookFont {
    /// Big numbers on the scoreboard: the score, the count, the inning.
    public static let scoreboard = Font.system(.largeTitle, design: .rounded).weight(.bold)
    /// Screen titles.
    public static let title = Font.title2.weight(.semibold)
    /// The batter's name and other headings.
    public static let headline = Font.headline
    /// Ordinary text.
    public static let body = Font.body
    /// Small labels.
    public static let caption = Font.caption
    /// The words on the big count buttons.
    public static let countButton = Font.system(.title, design: .rounded).weight(.heavy)
    /// Scorebook notation ("6-3", "1B 7"), in a font where every character is the same width.
    public static let notation = Font.system(.body, design: .monospaced)
}

/// Standard gaps between things, smallest to largest, in points.
public enum Spacing {
    public static let extraSmall: CGFloat = 4
    public static let small: CGFloat = 8
    public static let medium: CGFloat = 12
    public static let large: CGFloat = 16
    public static let extraLarge: CGFloat = 24
    public static let huge: CGFloat = 32

    /// The smallest thing a thumb can reliably hit, per Apple's guidance.
    public static let minimumTapSize: CGFloat = 44
    /// Rounded corners on buttons and cards.
    public static let cornerRadius: CGFloat = 12
}
