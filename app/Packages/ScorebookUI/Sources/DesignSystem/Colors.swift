// The app's named colors. Screens use these names, never raw colors, so the designer can
// change the look in one place.
//
// Placeholder values written by the foundation job; the designer fills in the real ones.
// The names are the contract: add new names freely, but keep these.

import SwiftUI
import UIKit

/// Every color the app uses, by what it is for. Each one has a light-mode and a dark-mode value.
public enum ScorebookColor {
    // MARK: Surfaces and text

    /// Behind everything.
    public static let background = adaptive(light: .white, dark: .black)
    /// Cards, sheets and panels sitting on the background.
    public static let surface = adaptive(light: UIColor(white: 0.95, alpha: 1), dark: UIColor(white: 0.12, alpha: 1))
    /// Main text.
    public static let textPrimary = adaptive(light: .black, dark: .white)
    /// Less important text: labels, captions.
    public static let textSecondary = adaptive(light: .darkGray, dark: .lightGray)
    /// Thin lines between rows.
    public static let divider = adaptive(light: UIColor(white: 0.8, alpha: 1), dark: UIColor(white: 0.3, alpha: 1))

    // MARK: Teams

    /// Our team, so our hitters look different from theirs at a glance.
    public static let ourTeam = adaptive(light: .systemBlue, dark: .systemBlue)
    /// The other team: a neutral color.
    public static let theirTeam = adaptive(light: .systemGray, dark: .systemGray2)

    // MARK: The count buttons

    public static let ball = adaptive(light: .systemGreen, dark: .systemGreen)
    public static let strike = adaptive(light: .systemRed, dark: .systemRed)
    public static let foul = adaptive(light: .systemOrange, dark: .systemOrange)
    public static let inPlay = adaptive(light: .systemIndigo, dark: .systemIndigo)

    // MARK: Signals

    /// Outs on the scoreboard.
    public static let out = adaptive(light: .systemRed, dark: .systemRed)
    /// Warnings, such as the manual adjustment screen.
    public static let warning = adaptive(light: .systemYellow, dark: .systemYellow)
    /// Something the scorer has picked, such as a tapped fielder.
    public static let highlight = adaptive(light: .systemTeal, dark: .systemTeal)

    // MARK: The field drawing

    public static let fieldGrass = adaptive(light: UIColor(red: 0.30, green: 0.60, blue: 0.30, alpha: 1),
                                            dark: UIColor(red: 0.15, green: 0.35, blue: 0.15, alpha: 1))
    public static let fieldDirt = adaptive(light: UIColor(red: 0.75, green: 0.60, blue: 0.42, alpha: 1),
                                           dark: UIColor(red: 0.45, green: 0.35, blue: 0.25, alpha: 1))
    /// An empty base.
    public static let baseEmpty = adaptive(light: .white, dark: UIColor(white: 0.85, alpha: 1))
    /// A base with a runner on it.
    public static let baseOccupied = adaptive(light: .systemYellow, dark: .systemYellow)

    /// A color that switches between a light-mode and a dark-mode value by itself.
    static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in traits.userInterfaceStyle == .dark ? dark : light })
    }
}
