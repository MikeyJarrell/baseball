// The app's named colors. Screens use these names, never raw colors, so the look can change
// in one place.
//
// The values match the approved mockups in plan/mockups/index.html. Our team's colors are
// sampled from the original Diamond Dogs logo artwork: collar blue #62B4E3, the dog's tan
// #D8B887 and its near-black outline #2C2B2A. Text on our blue is that near-black (it stays
// readable in bright sun), number badges are near-black, and tan is an accent. The other team is a
// striped slate gray with white text, so the two teams never look alike.
//
// Every color has a light-mode and a dark-mode value. Light mode is the outdoor default, so
// it uses the strongest contrast. The names are a contract other builders code against:
// add new names freely, but never rename or remove one.

import SwiftUI
import UIKit

/// Every color the app uses, by what it is for. Each one has a light-mode and a dark-mode value.
public enum ScorebookColor {
    // MARK: Surfaces and text

    /// Behind everything: the page itself.
    public static let background = adaptive(light: 0xF2F2F7, dark: 0x000000)
    /// Cards, sheets and panels sitting on the background.
    public static let surface = adaptive(light: 0xFFFFFF, dark: 0x1C1C1E)
    /// A quieter surface for small buttons and chips (Undo, HBP, IBB) and segmented controls.
    public static let surfaceSecondary = adaptive(light: 0xE9E9EF, dark: 0x2A2A2E)
    /// Main text.
    public static let textPrimary = adaptive(light: 0x0A0A0C, dark: 0xFFFFFF)
    /// Less important text: labels, captions.
    public static let textSecondary = adaptive(light: 0x5E5E66, dark: 0xA0A0A8)
    /// Thin lines between rows.
    public static let divider = adaptive(light: 0xD0D0D7, dark: 0x38383D)

    // MARK: Teams

    /// Our team, the Diamond Dogs: the powder blue of the logo's collar. Text on it is
    /// `onOurTeam` (the logo's near-black), never white.
    public static let ourTeam = adaptive(light: 0x62B4E3, dark: 0x6CBDEA)
    /// Text and icons drawn on top of `ourTeam`.
    public static let onOurTeam = adaptive(light: 0x2C2B2A, dark: 0x1A1918)
    /// A deeper blue for our team's pressed or playing state, such as the song button while
    /// a song plays. Text on it is still `onOurTeam`.
    public static let ourTeamDeep = adaptive(light: 0x3E9ACF, dark: 0x4AA6DA)
    /// A pale tint of our blue, for backgrounds such as the in-play context strip.
    public static let ourTeamSoft = adaptive(light: 0xE0F0FA, dark: 0x10283A)
    /// Our blue dark enough to read as text on a white or black surface.
    public static let ourTeamText = adaptive(light: 0x1A6694, dark: 0x8CCDF0)
    /// The logo's near-black outline: the background of our player-number badges.
    public static let ourTeamBadge = adaptive(light: 0x2C2B2A, dark: 0x2C2B2A)
    /// The logo's tan (the chihuahua): an accent, used sparingly.
    public static let ourTeamAccent = adaptive(light: 0xD8B887, dark: 0xD8B887)

    /// The other team: a neutral slate gray, drawn with diagonal stripes (see `TeamBackground`)
    /// so it differs from ours in pattern as well as color. Text on it is `onTheirTeam`.
    public static let theirTeam = adaptive(light: 0x46535F, dark: 0x5B6A79)
    /// Text and icons drawn on top of `theirTeam`.
    public static let onTheirTeam = adaptive(light: 0xFFFFFF, dark: 0xFFFFFF)
    /// A pale tint of their slate, for backgrounds.
    public static let theirTeamSoft = adaptive(light: 0xE4E8EC, dark: 0x1D242B)
    /// Their slate dark enough to read as text on a white or black surface.
    public static let theirTeamText = adaptive(light: 0x3A4652, dark: 0xB4C1CE)

    // MARK: The count buttons

    /// The Ball button: scoreboard green, white text.
    public static let ball = adaptive(light: 0x12803E, dark: 0x199A4D)
    /// The Strike button: amber, with black text (`onStrike`) for contrast in sun.
    public static let strike = adaptive(light: 0xF3A712, dark: 0xFFB625)
    /// Text on the Strike button.
    public static let onStrike = adaptive(light: 0x161616, dark: 0x161616)
    /// The Foul button: near-black, white text.
    public static let foul = adaptive(light: 0x2B2E35, dark: 0x46494F)
    /// The In play button, and the main action in the in-play sequence (Save, Runners):
    /// a deep blue, well apart from our light powder blue.
    public static let inPlay = adaptive(light: 0x0B57C9, dark: 0x2A76EC)

    // MARK: Signals

    /// Outs, runners put out, errors, and anything that needs a warning in red,
    /// such as "Time's up — finish this inning".
    public static let out = adaptive(light: 0xC62828, dark: 0xFF5A52)
    /// Warnings and attention, such as the manual adjustment screen and the
    /// "Dropped 3rd strike" chip. Text on it is black.
    public static let warning = adaptive(light: 0xF3A712, dark: 0xFFB625)
    /// Something the scorer has picked, such as a tapped fielder or the chosen base for a runner.
    public static let highlight = adaptive(light: 0x0B57C9, dark: 0x2A76EC)
    /// The order badges on tapped fielders ("1", "2"), and the designated non-runner tag.
    public static let sequenceBadge = adaptive(light: 0xF3A712, dark: 0xFFB625)
    /// Good news, such as a hit chip in the box score.
    public static let success = adaptive(light: 0x12803E, dark: 0x2FBF65)
    /// The pitcher's warm-up song button at the changeover.
    public static let warmUpMusic = adaptive(light: 0x5A3BC2, dark: 0x7656E2)

    // MARK: The field drawing

    /// Outfield grass.
    public static let fieldGrass = adaptive(light: 0xC3E3B8, dark: 0x1C3820)
    /// The infield grass inside the base paths, a shade darker than the outfield.
    public static let fieldGrassInfield = adaptive(light: 0xB1D8A3, dark: 0x224428)
    /// The infield dirt, the mound and the circle around home plate.
    public static let fieldDirt = adaptive(light: 0xE4C99C, dark: 0x4C3B27)
    /// Foul lines.
    public static let fieldChalk = adaptive(light: 0xFFFFFF, dark: 0xE8E8E8)
    /// The thin outline around home plate and the mound.
    public static let fieldOutline = adaptive(light: 0x6B5638, dark: 0xCDB892)
    /// The outline of an empty base, drawn with no fill: 5.5 to 1 against the dirt in light
    /// mode and 6.5 to 1 in dark mode.
    public static let baseEmptyOutline = adaptive(light: 0x5C4630, dark: 0xD9C7A3)
    /// The thick outline around an occupied base, which is filled in the batting team's color:
    /// 8.8 to 1 against the dirt in light mode, 10.7 to 1 in dark mode.
    public static let baseOccupiedOutline = adaptive(light: 0x2C2B2A, dark: 0xFFFFFF)
    /// Home plate's fill. The three bases are outlines when empty (`baseEmptyOutline`).
    public static let baseEmpty = adaptive(light: 0xFFFFFF, dark: 0xE8E8E8)
    /// A base with a runner on it when the drawing does not know whose runner it is.
    /// With `FieldDrawing.battingTeam(_:)`, occupied bases take the batting team's color instead.
    public static let baseOccupied = adaptive(light: 0xF3A712, dark: 0xFFB625)

    // MARK: The newspaper box score

    /// Newsprint, for the box score picture. The same in dark mode: it is a picture to text.
    public static let newspaperPaper = adaptive(light: 0xF3EEE1, dark: 0xF3EEE1)
    /// Ink on the newspaper box score.
    public static let newspaperInk = adaptive(light: 0x1A1712, dark: 0x1A1712)

    // MARK: Helpers

    /// A color that switches between a light-mode and a dark-mode value by itself.
    static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in traits.userInterfaceStyle == .dark ? dark : light })
    }

    /// The same, from hex values written the way web colors are (0x62B4E3 is the logo's powder blue).
    static func adaptive(light: UInt32, dark: UInt32) -> Color {
        adaptive(light: UIColor(hex: light), dark: UIColor(hex: dark))
    }
}

/// Which team something belongs to, so screens can color it without deciding colors themselves.
/// Our hitters, runners and song buttons use `.ours`; the other team uses `.theirs`.
public enum TeamLook: Sendable, Equatable {
    case ours
    case theirs

    /// The team's main color, for bands, batter cards and runner tags.
    public var fill: Color { self == .ours ? ScorebookColor.ourTeam : ScorebookColor.theirTeam }
    /// Text drawn on `fill`: black on our blue, white on their slate.
    public var onFill: Color { self == .ours ? ScorebookColor.onOurTeam : ScorebookColor.onTheirTeam }
    /// A pale tint for backgrounds.
    public var soft: Color { self == .ours ? ScorebookColor.ourTeamSoft : ScorebookColor.theirTeamSoft }
    /// The team's color as readable text on an ordinary surface.
    public var text: Color { self == .ours ? ScorebookColor.ourTeamText : ScorebookColor.theirTeamText }
    /// Whether the team's backgrounds carry diagonal stripes (theirs do), so the teams
    /// differ in pattern too, for anyone who has trouble telling the colors apart.
    public var isStriped: Bool { self == .theirs }
}

/// The background for anything in a team's color, such as the batting screen's top band:
/// our powder blue, or their slate with faint diagonal stripes.
public struct TeamBackground: View {
    public var look: TeamLook

    public init(_ look: TeamLook) {
        self.look = look
    }

    public var body: some View {
        ZStack {
            look.fill
            if look.isStriped {
                DiagonalStripes(spacing: 20)
                    .fill(Color.white.opacity(0.07))
            }
        }
    }
}

/// Diagonal stripes, each half the spacing wide, running from bottom-left to top-right.
struct DiagonalStripes: Shape {
    var spacing: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = spacing / 2
        // Start far enough left that the stripes cover the bottom-left corner too.
        var x = rect.minX - rect.height
        while x < rect.maxX {
            path.move(to: CGPoint(x: x, y: rect.maxY))
            path.addLine(to: CGPoint(x: x + width, y: rect.maxY))
            path.addLine(to: CGPoint(x: x + width + rect.height, y: rect.minY))
            path.addLine(to: CGPoint(x: x + rect.height, y: rect.minY))
            path.closeSubpath()
            x += spacing
        }
        return path
    }
}

extension UIColor {
    /// Makes a color from a hex value such as 0x62B4E3.
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}

// MARK: - Previews

/// One labeled swatch, for the palette preview.
private struct Swatch: View {
    var name: String
    var color: Color
    var textColor: Color = ScorebookColor.textPrimary

    var body: some View {
        HStack(spacing: Spacing.medium) {
            RoundedRectangle(cornerRadius: 8).fill(color)
                .frame(width: 44, height: 32)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(ScorebookColor.divider))
            Text(name).font(ScorebookFont.body).foregroundStyle(textColor)
            Spacer()
        }
    }
}

/// Every named color, for checking light and dark mode side by side.
private struct Palette: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.small) {
                HStack(spacing: Spacing.medium) {
                    Text("Diamond Dogs").font(ScorebookFont.headline).foregroundStyle(TeamLook.ours.onFill)
                        .padding().frame(maxWidth: .infinity).background(TeamBackground(.ours))
                    Text("Mudcats").font(ScorebookFont.headline).foregroundStyle(TeamLook.theirs.onFill)
                        .padding().frame(maxWidth: .infinity).background(TeamBackground(.theirs))
                }
                .clipShape(RoundedRectangle(cornerRadius: Spacing.cornerRadius))
                Group {
                    Swatch(name: "background", color: ScorebookColor.background)
                    Swatch(name: "surface", color: ScorebookColor.surface)
                    Swatch(name: "surfaceSecondary", color: ScorebookColor.surfaceSecondary)
                    Swatch(name: "ourTeam", color: ScorebookColor.ourTeam)
                    Swatch(name: "ourTeamDeep", color: ScorebookColor.ourTeamDeep)
                    Swatch(name: "ourTeamSoft", color: ScorebookColor.ourTeamSoft)
                    Swatch(name: "ourTeamText", color: ScorebookColor.ourTeamText, textColor: ScorebookColor.ourTeamText)
                    Swatch(name: "ourTeamAccent", color: ScorebookColor.ourTeamAccent)
                    Swatch(name: "theirTeam", color: ScorebookColor.theirTeam)
                    Swatch(name: "theirTeamText", color: ScorebookColor.theirTeamText, textColor: ScorebookColor.theirTeamText)
                }
                Group {
                    Swatch(name: "ball", color: ScorebookColor.ball)
                    Swatch(name: "strike", color: ScorebookColor.strike)
                    Swatch(name: "foul", color: ScorebookColor.foul)
                    Swatch(name: "inPlay", color: ScorebookColor.inPlay)
                    Swatch(name: "out", color: ScorebookColor.out)
                    Swatch(name: "warning", color: ScorebookColor.warning)
                    Swatch(name: "warmUpMusic", color: ScorebookColor.warmUpMusic)
                    Swatch(name: "fieldGrass", color: ScorebookColor.fieldGrass)
                    Swatch(name: "fieldDirt", color: ScorebookColor.fieldDirt)
                    Swatch(name: "newspaperPaper", color: ScorebookColor.newspaperPaper)
                }
            }
            .padding()
        }
        .background(ScorebookColor.background)
    }
}

#Preview("Colors, light") {
    Palette()
}

#Preview("Colors, dark") {
    Palette().preferredColorScheme(.dark)
}
