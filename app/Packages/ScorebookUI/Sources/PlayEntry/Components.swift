// Small pieces shared by the steps of the in-play sequence: the header with Back and Cancel,
// the strip saying who is on base, the big notation line, the bar along the bottom with
// Save, the round choice chips, the big answer buttons, and the red "Inning over" tag.
// Colors, type and spacing all come from the design system.

import SwiftUI
import Model
import DesignSystem

/// The header across the top of every step: Back on the left, the step's title with the
/// batter and inning under it, Cancel on the right.
struct FlowHeader: View {
    var title: String
    var subtitle: String
    var onBack: () -> Void
    var onCancel: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onBack) {
                HStack(spacing: 2) {
                    Image(systemName: "chevron.left").fontWeight(.semibold)
                    Text("Back")
                }
                .frame(minWidth: 76, minHeight: Spacing.minimumTapSize, alignment: .leading)
                .contentShape(Rectangle())
            }
            VStack(spacing: 0) {
                Text(title)
                    .font(ScorebookFont.headline)
                    .foregroundStyle(ScorebookColor.textPrimary)
                Text(subtitle)
                    .font(ScorebookFont.caption)
                    .foregroundStyle(ScorebookColor.textSecondary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            Button("Cancel", action: onCancel)
                .frame(minWidth: 76, minHeight: Spacing.minimumTapSize, alignment: .trailing)
                .contentShape(Rectangle())
        }
        .font(ScorebookFont.body)
        .foregroundStyle(ScorebookColor.highlight)
        .padding(.horizontal, Spacing.small)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }
}

/// The strip under the header: who is on base and the count, in the batting team's colors,
/// with three dashes showing which step this is.
struct ContextStrip: View {
    var text: String
    var look: TeamLook
    /// 1 for step one, 2 for the fielders (or where it landed, or the error), 3 for the runners.
    var stepNumber: Int

    var body: some View {
        HStack(spacing: Spacing.small) {
            Text(text)
                .font(ScorebookFont.chip)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: Spacing.small)
            HStack(spacing: Spacing.extraSmall) {
                ForEach(1...3, id: \.self) { n in
                    Capsule()
                        .frame(width: 22, height: 5)
                        .opacity(n <= stepNumber ? 1 : 0.25)
                }
            }
            .accessibilityElement()
            .accessibilityLabel(Text("Step \(stepNumber) of 3"))
        }
        .foregroundStyle(look.text)
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, Spacing.small)
        .background(look.soft, in: RoundedRectangle(cornerRadius: Spacing.cornerRadius, style: .continuous))
        .padding(.horizontal, Spacing.screenEdge)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}

/// The big notation line ("6-3"), or a gray hint before anything is tapped, with a line of
/// words under it and, when given, a take-back arrow on the right.
struct NotationBar: View {
    /// The notation from the rules engine; empty shows the hint instead.
    var notation: String
    var hint: String
    var detail: String
    var onUndo: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.medium) {
            VStack(alignment: .leading, spacing: 2) {
                if notation.isEmpty {
                    Text(hint)
                        .font(ScorebookFont.title.weight(.bold))
                        .foregroundStyle(ScorebookColor.textSecondary)
                        .frame(minHeight: 40, alignment: .leading)
                } else {
                    Text(notation)
                        .font(ScorebookFont.notationLarge)
                        .foregroundStyle(ScorebookColor.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .accessibilityLabel(Text("Notation \(notation)"))
                }
                Text(detail.isEmpty ? " " : detail)
                    .font(ScorebookFont.caption)
                    .foregroundStyle(ScorebookColor.textSecondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let onUndo {
                Button(action: onUndo) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(ScorebookFont.headline)
                        .foregroundStyle(ScorebookColor.textPrimary)
                        .frame(width: Spacing.minimumTapSize, height: Spacing.minimumTapSize)
                        .background(ScorebookColor.surfaceSecondary, in: RoundedRectangle(cornerRadius: Spacing.cornerRadius, style: .continuous))
                }
                .accessibilityLabel(Text("Take back the last fielder"))
            }
        }
        .padding(.horizontal, Spacing.large)
        .padding(.top, Spacing.small)
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }
}

/// The bar along the bottom of a step: a short summary on the left (what the play does so
/// far), the step's buttons on the right.
struct BottomBar<Buttons: View>: View {
    var title: String
    var detail: String
    var showsInningOver = false
    @ViewBuilder var buttons: Buttons

    var body: some View {
        HStack(spacing: Spacing.medium) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(ScorebookFont.headline)
                    .foregroundStyle(ScorebookColor.textPrimary)
                if showsInningOver {
                    InningOverTag()
                } else {
                    Text(detail)
                        .font(ScorebookFont.caption)
                        .foregroundStyle(ScorebookColor.textSecondary)
                }
            }
            .lineLimit(2)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            buttons
        }
        .padding(.horizontal, Spacing.screenEdge)
        .padding(.top, Spacing.medium)
        .padding(.bottom, Spacing.small)
        .background {
            ScorebookColor.surface
                .overlay(alignment: .top) { ScorebookColor.divider.frame(height: 1) }
                .ignoresSafeArea(edges: .bottom)
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }
}

/// The blue Save button with a check mark.
struct SaveButton: View {
    var enabled: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Save", systemImage: "checkmark").fontWeight(.bold)
        }
        .buttonStyle(PrimaryButtonStyle())
        .frame(width: 140)
        .disabled(!enabled)
    }
}

/// The blue Runners button with an arrow, which opens the runner step.
struct RunnersButton: View {
    var enabled: Bool
    /// True when Save sits beside it and this is only the way to check the runners.
    var isSecondary = false
    var action: () -> Void

    var body: some View {
        if isSecondary {
            Button("Runners", action: action)
                .font(ScorebookFont.headline)
                .foregroundStyle(ScorebookColor.highlight)
                .padding(.horizontal, Spacing.medium)
                .frame(minHeight: Spacing.primaryButtonHeight)
                .overlay(RoundedRectangle(cornerRadius: Spacing.cornerRadius + 2, style: .continuous)
                    .stroke(ScorebookColor.divider, lineWidth: 1.5))
                .disabled(!enabled)
        } else {
            Button(action: action) {
                HStack(spacing: Spacing.extraSmall) {
                    Text("Runners").fontWeight(.bold)
                    Image(systemName: "chevron.right")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .frame(width: 150)
            .disabled(!enabled)
        }
    }
}

/// How a choice chip looks.
enum ChipState {
    /// Not picked.
    case off
    /// The screen's own guess, not yet confirmed: a dashed outline.
    case guess
    /// Picked by the scorer: filled in.
    case on
}

/// A round chip for a small choice: Ground, Fly, Double play, Fielding.
struct ChoiceChip: View {
    var title: String
    var state: ChipState
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(ScorebookFont.chip)
                .lineLimit(1)
                .foregroundStyle(state == .on ? ScorebookColor.background : ScorebookColor.textPrimary)
                .padding(.horizontal, Spacing.medium)
                .frame(minHeight: Spacing.minimumTapSize - 4)
                .background {
                    switch state {
                    case .on: Capsule().fill(ScorebookColor.textPrimary)
                    case .guess: Capsule().strokeBorder(ScorebookColor.textSecondary, style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
                    case .off: Capsule().fill(ScorebookColor.surfaceSecondary)
                    }
                }
                .frame(minHeight: Spacing.minimumTapSize)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(state == .on ? .isSelected : [])
        .accessibilityValue(Text(state == .guess ? "guessed" : ""))
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}

/// The red tag that says the play makes the third out.
struct InningOverTag: View {
    var body: some View {
        Text("INNING OVER")
            .font(ScorebookFont.caption.weight(.heavy))
            .foregroundStyle(Color.white)
            .padding(.horizontal, Spacing.small)
            .padding(.vertical, 2)
            .background(ScorebookColor.out, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .accessibilityLabel(Text("Inning over"))
    }
}

/// How a big answer button on step one looks.
enum BigChoiceKind {
    /// "Batter out": near-black.
    case dark
    /// The hits: deep blue.
    case blue
    /// The less common answers: white with a gray edge.
    case light
    /// "More": the gray of a plain chip.
    case quiet
}

/// The big answer buttons on step one and the dropped-third-strike step: a title, an optional
/// line under it, filling the space they are given.
struct BigChoiceButtonStyle: ButtonStyle {
    var kind: BigChoiceKind

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: Spacing.bigButtonCornerRadius, style: .continuous)
        configuration.label
            .multilineTextAlignment(.center)
            .foregroundStyle(kind == .light || kind == .quiet ? ScorebookColor.textPrimary : Color.white)
            .padding(Spacing.small)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .frame(minHeight: Spacing.countButtonMinimumHeight)
            .background {
                switch kind {
                case .dark: shape.fill(ScorebookColor.foul)
                case .blue: shape.fill(ScorebookColor.inPlay)
                case .light: shape.fill(ScorebookColor.surface).overlay(shape.strokeBorder(ScorebookColor.divider, lineWidth: 2))
                case .quiet: shape.fill(ScorebookColor.surfaceSecondary)
                }
            }
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .contentShape(shape)
    }
}

/// The words inside a big answer button: the answer, and an optional line under it.
struct BigChoiceLabel: View {
    var title: String
    var detail: String? = nil
    var large = false

    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(large ? ScorebookFont.largeTitle : (detail == nil ? ScorebookFont.title.weight(.heavy) : ScorebookFont.headline.weight(.heavy)))
                .lineLimit(2)
                .minimumScaleFactor(0.6)
            if let detail {
                Text(detail)
                    .font(ScorebookFont.caption.weight(.semibold))
                    .opacity(0.85)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(detail.map { "\(title): \($0)" } ?? title))
    }
}
