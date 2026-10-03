// The app's button styles, plus the player-number badge and the team logo.
//
// Use a style as `.buttonStyle(CountButtonStyle.ball)` or
// `.buttonStyle(CountButtonStyle(color: ScorebookColor.ball))`; both give the same button.
// The looks match the approved mockups in plan/mockups/index.html.

import SwiftUI
import UIKit

/// The big Ball, Strike, Foul and In play buttons: large, high-contrast, easy to hit with
/// one thumb in the sun. Each has a darker strip along its bottom edge so it reads as a
/// button you can press, and it sinks slightly while pressed.
///
/// The button fills whatever space its parent gives it (a 2×2 grid on the batting screen),
/// but never shrinks below `Spacing.countButtonMinimumHeight`.
public struct CountButtonStyle: ButtonStyle {
    /// The button's fill color, such as `ScorebookColor.ball`.
    public var color: Color
    /// The color of the words on it: white, except black on the amber Strike button.
    public var textColor: Color

    public init(color: Color, textColor: Color = .white) {
        self.color = color
        self.textColor = textColor
    }

    /// The four count buttons, ready to use.
    public static let ball = CountButtonStyle(color: ScorebookColor.ball)
    public static let strike = CountButtonStyle(color: ScorebookColor.strike, textColor: ScorebookColor.onStrike)
    public static let foul = CountButtonStyle(color: ScorebookColor.foul)
    public static let inPlay = CountButtonStyle(color: ScorebookColor.inPlay)

    public func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: Spacing.bigButtonCornerRadius, style: .continuous)
        return configuration.label
            .font(ScorebookFont.countButton)
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .frame(minHeight: Spacing.countButtonMinimumHeight)
            // The fill, with a dark strip along the bottom drawn as an inner shadow.
            .background(shape.fill(color.shadow(.inner(color: .black.opacity(0.18), radius: 0, x: 0, y: -4))))
            .contentShape(shape)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .brightness(configuration.isPressed ? -0.08 : 0)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

/// The words on a count button: the big word, and under it a small line saying what the
/// tap will do, such as "Ball" over "makes it 2–1", or "Strike" over "strikeout".
/// Both lines shrink to fit rather than wrap, so the buttons keep their size at any text size.
public struct CountButtonLabel: View {
    public var title: String
    public var hint: String?

    public init(_ title: String, hint: String? = nil) {
        self.title = title
        self.hint = hint
    }

    public var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(ScorebookFont.countButton)
            if let hint {
                Text(hint)
                    .font(ScorebookFont.countButtonHint)
                    .opacity(0.88)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .multilineTextAlignment(.center)
        .padding(.horizontal, Spacing.small)
    }
}

/// An ordinary small button: Undo, HBP, IBB, Foul tip, Subs, menu items, sheet actions.
/// A quiet gray chip, at least a thumb's height.
public struct PlainActionButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ScorebookFont.chip)
            .foregroundStyle(ScorebookColor.textPrimary)
            .padding(.horizontal, Spacing.medium)
            .frame(minHeight: Spacing.minimumTapSize)
            .background(ScorebookColor.surfaceSecondary.opacity(configuration.isPressed ? 0.6 : 1),
                        in: RoundedRectangle(cornerRadius: Spacing.cornerRadius, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: Spacing.cornerRadius, style: .continuous))
    }
}

/// The main action at the bottom of a step or sheet: Save, Runners, Next, Confirm.
/// Deep blue with white words, full width, easy to hit.
public struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ScorebookFont.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: Spacing.primaryButtonHeight)
            .padding(.horizontal, Spacing.large)
            .background(ScorebookColor.inPlay.opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.4),
                        in: RoundedRectangle(cornerRadius: Spacing.cornerRadius + 2, style: .continuous))
    }
}

/// A big button in a team's color, such as the walk-up song button along the bottom of the
/// batting screen ("Seven Nation Army") or "Play ball". Our team's is powder blue with black
/// words; while `isActive` (a song is playing) it turns a deeper blue with a ring.
public struct TeamButtonStyle: ButtonStyle {
    public var look: TeamLook
    public var isActive: Bool

    public init(_ look: TeamLook = .ours, isActive: Bool = false) {
        self.look = look
        self.isActive = isActive
    }

    public func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: Spacing.bigButtonCornerRadius, style: .continuous)
        return configuration.label
            .font(ScorebookFont.headline)
            .foregroundStyle(look.onFill)
            .frame(maxWidth: .infinity, minHeight: Spacing.songButtonHeight)
            .background {
                if isActive && look == .ours {
                    shape.fill(ScorebookColor.ourTeamDeep)
                        .overlay(shape.strokeBorder(ScorebookColor.ourTeam, lineWidth: 3))
                } else {
                    TeamBackground(look).clipShape(shape)
                }
            }
            .contentShape(shape)
            .brightness(configuration.isPressed ? -0.06 : 0)
    }
}

/// A player's jersey number in a rounded square. Ours: black with the number in powder blue,
/// like the logo. Theirs: slate with a white number.
public struct PlayerNumberBadge: View {
    public var number: String
    public var look: TeamLook
    public var size: CGFloat

    /// - Parameters:
    ///   - number: The jersey number as text, such as "24"; "?" when unknown.
    ///   - size: The badge's width and height in points; 44 on the batting screen, 36 in lists.
    public init(_ number: String, look: TeamLook, size: CGFloat = 40) {
        self.number = number
        self.look = look
        self.size = size
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
        Text(number)
            .font(.system(size: size * 0.46, weight: .heavy).monospacedDigit())
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .foregroundStyle(look == .ours ? ScorebookColor.ourTeam : ScorebookColor.onTheirTeam)
            .frame(width: size, height: size)
            .background(look == .ours ? ScorebookColor.ourTeamBadge : ScorebookColor.theirTeam, in: shape)
            .overlay {
                if look == .ours { shape.strokeBorder(ScorebookColor.ourTeam, lineWidth: max(1.5, size * 0.05)) }
            }
            .accessibilityLabel(Text("Number \(number)"))
    }
}

/// The Diamond Dogs logo (the chihuahua on black), bundled in this module's Resources folder.
/// Used on the home screen, the team page and the end-of-game box score.
public struct TeamLogo: View {
    public var size: CGFloat

    public init(size: CGFloat = 56) {
        self.size = size
    }

    /// The logo as a picture, for screens that need it outside a `TeamLogo` view
    /// (the box score printer draws it into the newspaper picture). Empty if the file is missing.
    public static var image: UIImage {
        UIImage(named: "diamond-dogs-logo-150.jpg", in: .module, with: nil) ?? UIImage()
    }

    public var body: some View {
        Image(uiImage: Self.image)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.25, style: .continuous))
            .accessibilityLabel(Text("Diamond Dogs"))
    }
}

// MARK: - Previews

/// The batting screen's lower half: chip row, the 2×2 count buttons and the song button.
private struct ButtonSamples: View {
    var body: some View {
        VStack(spacing: Spacing.screenEdge) {
            HStack(spacing: Spacing.small) {
                PlayerNumberBadge("24", look: .ours, size: 50)
                VStack(alignment: .leading) {
                    Text("Jake Kowalski").font(ScorebookFont.batterName)
                    Text("Bats L · Today: 6-3, BB").font(ScorebookFont.caption).foregroundStyle(ScorebookColor.textSecondary)
                }
                Spacer()
                PlayerNumberBadge("23", look: .theirs, size: 50)
            }
            .foregroundStyle(ScorebookColor.textPrimary)
            HStack(spacing: Spacing.small) {
                Button { } label: { Label("Undo: ball", systemImage: "arrow.uturn.backward").frame(maxWidth: .infinity) }
                Button("HBP") {}
                Button("IBB") {}
                Button("Foul tip") {}
            }
            .buttonStyle(PlainActionButtonStyle())
            Grid(horizontalSpacing: Spacing.screenEdge, verticalSpacing: Spacing.screenEdge) {
                GridRow {
                    Button {} label: { CountButtonLabel("Ball", hint: "makes it 2–1") }.buttonStyle(CountButtonStyle.ball)
                    Button {} label: { CountButtonLabel("Strike", hint: "makes it 1–2") }.buttonStyle(CountButtonStyle.strike)
                }
                GridRow {
                    Button {} label: { CountButtonLabel("Foul", hint: "makes it 1–2") }.buttonStyle(CountButtonStyle.foul)
                    Button {} label: { CountButtonLabel("In play", hint: "out, hit, error…") }.buttonStyle(CountButtonStyle(color: ScorebookColor.inPlay))
                }
            }
            .frame(height: Spacing.countButtonHeight * 2 + Spacing.screenEdge)
            Button {} label: {
                HStack { Image(systemName: "play.circle.fill").font(.largeTitle); VStack(alignment: .leading) { Text("Seven Nation Army"); Text("Introduction, then 12 seconds of song").font(ScorebookFont.caption) }; Spacer() }
                    .padding(.horizontal, Spacing.medium)
            }
            .buttonStyle(TeamButtonStyle(.ours))
            Button {} label: { Text("No walk-up song for their hitters").font(ScorebookFont.caption) }
                .buttonStyle(TeamButtonStyle(.theirs))
            Button("Save") {}.buttonStyle(PrimaryButtonStyle())
            HStack { TeamLogo(size: 56); Text("Diamond Dogs").font(ScorebookFont.largeTitle).foregroundStyle(ScorebookColor.textPrimary); Spacer() }
        }
        .padding(Spacing.screenEdge)
        .background(ScorebookColor.background)
    }
}

#Preview("Buttons, light") {
    ButtonSamples()
}

#Preview("Buttons, dark") {
    ButtonSamples().preferredColorScheme(.dark)
}

#Preview("Buttons, largest text size") {
    ButtonSamples().environment(\.dynamicTypeSize, .accessibility5)
}
