// The app's button styles.
//
// Placeholder looks written by the foundation job; the designer fills in the real ones.
// Use them as `.buttonStyle(CountButtonStyle(color: ScorebookColor.ball))`.

import SwiftUI

/// The big ball, strike, foul and in-play buttons: large, high-contrast, easy to hit
/// with one thumb in the sun.
public struct CountButtonStyle: ButtonStyle {
    /// The button's fill color, such as `ScorebookColor.ball`.
    public var color: Color

    public init(color: Color) {
        self.color = color
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ScorebookFont.countButton)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: Spacing.minimumTapSize * 2)
            .background(color.opacity(configuration.isPressed ? 0.7 : 1),
                        in: RoundedRectangle(cornerRadius: Spacing.cornerRadius))
    }
}

/// An ordinary button: undo, menu items, sheet actions.
public struct PlainActionButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ScorebookFont.headline)
            .foregroundStyle(ScorebookColor.textPrimary)
            .padding(.horizontal, Spacing.large)
            .frame(minHeight: Spacing.minimumTapSize)
            .background(ScorebookColor.surface.opacity(configuration.isPressed ? 0.6 : 1),
                        in: RoundedRectangle(cornerRadius: Spacing.cornerRadius))
    }
}

#Preview("Count buttons") {
    VStack(spacing: Spacing.medium) {
        Button("Ball") {}.buttonStyle(CountButtonStyle(color: ScorebookColor.ball))
        Button("Strike") {}.buttonStyle(CountButtonStyle(color: ScorebookColor.strike))
        Button("Foul") {}.buttonStyle(CountButtonStyle(color: ScorebookColor.foul))
        Button("In play") {}.buttonStyle(CountButtonStyle(color: ScorebookColor.inPlay))
        Button("Undo: ball") {}.buttonStyle(PlainActionButtonStyle())
    }
    .padding()
    .background(ScorebookColor.background)
}
