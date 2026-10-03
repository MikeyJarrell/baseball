// The app's named text styles and spacing values.
//
// Everything uses fonts that come with iOS: San Francisco (the system font) for the app, and
// New York (the system serif) for the newspaper box score. Every style is tied to one of
// Apple's text styles, so it grows with the phone's text size setting. Numbers that change
// in place (the count, the score, pitch counts) use same-width digits so they do not jiggle.
// The names are a contract other builders code against: add new names freely, but keep these.

import SwiftUI

/// Every text style the app uses, by what it is for.
public enum ScorebookFont {
    /// Big numbers on the scoreboard: the score, the count, the inning.
    public static let scoreboard = Font.system(.largeTitle, design: .default, weight: .heavy).monospacedDigit()
    /// Smaller scoreboard numbers, such as the score beside the big count.
    public static let scoreboardSmall = Font.system(.title2, design: .default, weight: .heavy).monospacedDigit()
    /// Large screen titles, such as "Songs" or "Season".
    public static let largeTitle = Font.system(.largeTitle, design: .default, weight: .heavy)
    /// Screen titles.
    public static let title = Font.title2.weight(.semibold)
    /// The batter's name on the batting screen.
    public static let batterName = Font.system(.title2, design: .default, weight: .heavy)
    /// The batter's name and other headings.
    public static let headline = Font.headline
    /// Ordinary text.
    public static let body = Font.body
    /// Words on small buttons and chips: Undo, HBP, IBB, Foul tip, Subs.
    public static let chip = Font.system(.subheadline, design: .default, weight: .bold)
    /// Small labels.
    public static let caption = Font.caption
    /// Section labels above lists ("BATTING ORDER"), shown in capitals.
    public static let sectionLabel = Font.system(.footnote, design: .default, weight: .bold)
    /// The words on the big count buttons.
    public static let countButton = Font.system(.title, design: .default, weight: .heavy)
    /// The small line under a count button's word, saying what it will do ("makes it 2–1").
    public static let countButtonHint = Font.system(.footnote, design: .default, weight: .semibold)
    /// Scorebook notation ("6-3", "1B 7") in chips and lists. Only the digits are the same
    /// width; letters are not, so "BB" and "F8" do not line up in columns. For columns, use
    /// `notationColumns`.
    public static let notation = Font.system(.body, design: .default, weight: .bold).monospacedDigit()
    /// Scorebook notation where every character is the same width, for lining up in columns
    /// (the box score so far, the play-by-play).
    public static let notationColumns = Font.system(.body, design: .monospaced, weight: .bold)
    /// The notation building up on the in-play screens, big enough to read at arm's length.
    public static let notationLarge = Font.system(.largeTitle, design: .default, weight: .heavy).monospacedDigit()

    // MARK: The newspaper box score

    /// The headline: "Diamond Dogs 7, Mudcats 5".
    public static let newspaperHeadline = Font.system(.title2, design: .serif, weight: .bold)
    /// Team names over each table, set in small capitals.
    public static let newspaperHeading = Font.system(.caption, design: .serif, weight: .bold).smallCaps()
    /// The rows of the box score, with same-width digits so the columns line up.
    public static let newspaperBody = Font.system(.caption, design: .serif).monospacedDigit()
}

/// Standard gaps and sizes, in points.
public enum Spacing {
    public static let extraSmall: CGFloat = 4
    public static let small: CGFloat = 8
    public static let medium: CGFloat = 12
    public static let large: CGFloat = 16
    public static let extraLarge: CGFloat = 24
    public static let huge: CGFloat = 32

    /// The smallest thing a thumb can reliably hit, per Apple's guidance.
    public static let minimumTapSize: CGFloat = 44
    /// Rounded corners on cards, chips and small buttons.
    public static let cornerRadius: CGFloat = 12
    /// Rounded corners on the big buttons: the count buttons and the song button.
    public static let bigButtonCornerRadius: CGFloat = 18
    /// The gap between the screen's edge and its content, and between the big buttons.
    public static let screenEdge: CGFloat = 12

    /// How tall a count button is on a full-size phone.
    public static let countButtonHeight: CGFloat = 84
    /// A smaller count button height, for a compact layout a screen builds itself.
    /// `CountButtonStyle` never goes below `countButtonHeight`.
    public static let countButtonMinimumHeight: CGFloat = 64
    /// The song button along the bottom edge of the batting screen.
    public static let songButtonHeight: CGFloat = 64
    /// The main action button at the bottom of a sheet or step (Save, Next).
    public static let primaryButtonHeight: CGFloat = 56
}

// MARK: - Previews

/// Every text style, for checking sizes in light and dark mode and at the largest text size.
private struct TypeSamples: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.small) {
                Text("1–2").font(ScorebookFont.scoreboard)
                Text("Diamond Dogs 4").font(ScorebookFont.scoreboardSmall)
                Text("Songs").font(ScorebookFont.largeTitle)
                Text("Our lineup").font(ScorebookFont.title)
                Text("Jake Kowalski").font(ScorebookFont.batterName)
                Text("Who handled it?").font(ScorebookFont.headline)
                Text("Bats L · Today: 6-3, BB").font(ScorebookFont.body)
                Text("Undo: ball").font(ScorebookFont.chip)
                Text("54 pitches, 33 strikes").font(ScorebookFont.caption)
                Text("BATTING ORDER").font(ScorebookFont.sectionLabel)
                Text("Strike").font(ScorebookFont.countButton)
                Text("makes it 1–2").font(ScorebookFont.countButtonHint)
                Text("5-4-3 DP").font(ScorebookFont.notation)
                Text("1B 7, E7").font(ScorebookFont.notationLarge)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Diamond Dogs 7, Mudcats 5").font(ScorebookFont.newspaperHeadline)
                    Text("Diamond Dogs").font(ScorebookFont.newspaperHeading)
                    Text("Kowalski 1b    4  1  2  2").font(ScorebookFont.newspaperBody)
                }
                .foregroundStyle(ScorebookColor.newspaperInk)
                .padding(Spacing.medium)
                .background(ScorebookColor.newspaperPaper)
            }
            .foregroundStyle(ScorebookColor.textPrimary)
            .padding()
        }
        .background(ScorebookColor.background)
    }
}

#Preview("Type, light") {
    TypeSamples()
}

#Preview("Type, dark") {
    TypeSamples().preferredColorScheme(.dark)
}

#Preview("Type, largest text size") {
    TypeSamples().environment(\.dynamicTypeSize, .accessibility5)
}
