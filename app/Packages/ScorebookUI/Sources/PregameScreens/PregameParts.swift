// The building blocks the five pregame steps share: the page with its step dots and big
// button along the bottom, section labels, choice rows with a round mark, the − value +
// stepper, chips, the gray information box, and a layout that wraps chips onto new lines.
// They copy the approved mockup (plan/mockups/index.html, the `pg-` screens), using only the
// design system's named colors, type and spacing.

import SwiftUI
import Model
import DesignSystem

// MARK: - The page

/// One pregame step: a list of cards on the gray background, the title with five step dots
/// under it, and the big button pinned to the bottom edge.
struct StepPage<Content: View>: View {
    /// Which step this is, 1 to 5, for the dots.
    var step: Int
    var title: String
    /// The words on the big button: "Next: our lineup".
    var buttonTitle: String
    /// Why the big button cannot be tapped yet, shown above it. Missing means it can be.
    var blockedReason: String? = nil
    /// The big button's look: the blue "Next" button, or our team's "Play ball" button.
    var isPlayBall: Bool = false
    var onButton: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        List {
            content
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(Spacing.small)
        .scrollContentBackground(.hidden)
        .background(ScorebookColor.background)
        .foregroundStyle(ScorebookColor.textPrimary)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 3) {
                    Text(title)
                        .font(ScorebookFont.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    StepDots(step: step)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("\(title), step \(step) of 5"))
                .accessibilityAddTraits(.isHeader)
            }
        }
        .toolbarBackground(ScorebookColor.background, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: Spacing.small) {
                if let blockedReason {
                    Text(blockedReason)
                        .font(ScorebookFont.caption)
                        .foregroundStyle(ScorebookColor.textSecondary)
                }
                if isPlayBall {
                    Button(action: onButton) {
                        Text(buttonTitle).font(.title2.weight(.heavy))
                    }
                    .buttonStyle(TeamButtonStyle(.ours))
                    .disabled(blockedReason != nil)
                    .opacity(blockedReason == nil ? 1 : 0.4)
                } else {
                    Button(buttonTitle, action: onButton)
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(blockedReason != nil)
                }
            }
            .padding(.horizontal, Spacing.large)
            .padding(.top, Spacing.medium)
            .padding(.bottom, Spacing.small)
            .background(ScorebookColor.background)
            .overlay(alignment: .top) {
                Rectangle().fill(ScorebookColor.divider).frame(height: 1)
            }
        }
    }
}

/// Five small dots under the title, filled up to the current step.
struct StepDots: View {
    var step: Int

    var body: some View {
        HStack(spacing: 5) {
            ForEach(1...5, id: \.self) { i in
                Capsule()
                    .fill(i <= step ? ScorebookColor.highlight : ScorebookColor.divider)
                    .frame(width: i == step ? 16 : 6, height: 6)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Sections and rows

/// The small capitalized label above a card, with optional words at the right:
/// "BATTING ORDER · 10" and "Non-runners 1 of 2".
struct SectionHeader: View {
    var title: String
    var trailing: Text? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title.uppercased())
                .font(ScorebookFont.sectionLabel)
                .tracking(0.6)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: Spacing.small)
            if let trailing {
                trailing.font(ScorebookFont.caption)
            }
        }
        .foregroundStyle(ScorebookColor.textSecondary)
        .textCase(nil)
    }
}

extension View {
    /// The look of a row inside a card: white, with the mockup's padding.
    func cardRow() -> some View {
        self
            .listRowBackground(ScorebookColor.surface)
            .listRowInsets(EdgeInsets(top: Spacing.small, leading: Spacing.large - 2, bottom: Spacing.small, trailing: Spacing.large - 2))
    }
}

/// A tappable row with something on the left, a title, a smaller line under it, and a round
/// mark on the right that fills when chosen. Like the mockup's `.opt` rows.
struct ChoiceRow<Leading: View>: View {
    var title: String
    var detail: String?
    var isOn: Bool
    var action: () -> Void
    @ViewBuilder var leading: Leading

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.medium) {
                leading
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(ScorebookFont.headline)
                        .foregroundStyle(ScorebookColor.textPrimary)
                    if let detail {
                        Text(detail)
                            .font(ScorebookFont.caption)
                            .foregroundStyle(ScorebookColor.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
                RadioMark(isOn: isOn)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// The round mark on a choice row: an empty ring, or filled blue with a tick when chosen.
struct RadioMark: View {
    var isOn: Bool

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(isOn ? ScorebookColor.highlight : ScorebookColor.divider, lineWidth: 2)
                .background(Circle().fill(isOn ? ScorebookColor.highlight : Color.clear))
            if isOn {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(ScorebookColor.surface)
            }
        }
        .frame(width: 24, height: 24)
        .accessibilityHidden(true)
    }
}

/// A gray rounded square with an icon in it, on the left of a row: the plus on "New team".
struct IconBadge: View {
    var systemName: String
    var tint: Color = ScorebookColor.inPlay

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 36, height: 36)
            .background(ScorebookColor.surfaceSecondary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// A fielding position's number in a ring, as on a scorecard: "6".
struct PositionCircle: View {
    var position: Position

    var body: some View {
        Text("\(position.number)")
            .font(.system(size: 16, weight: .heavy).monospacedDigit())
            .frame(width: 36, height: 36)
            .overlay(Circle().strokeBorder(ScorebookColor.textPrimary, lineWidth: 2.5))
            .accessibilityHidden(true)
    }
}

/// A batting-order spot number at the left of a row: "1".
struct OrderNumber: View {
    var spot: Int

    var body: some View {
        Text("\(spot)")
            .font(ScorebookFont.headline.monospacedDigit())
            .foregroundStyle(ScorebookColor.textSecondary)
            .frame(minWidth: 22, alignment: .trailing)
            .accessibilityHidden(true)
    }
}

/// The drag handle drawn on a row that can be dragged into a new place.
struct Grip: View {
    var body: some View {
        Image(systemName: "line.3.horizontal")
            .foregroundStyle(ScorebookColor.textSecondary)
            .accessibilityHidden(true)
    }
}

/// The round minus button that takes a hitter out of a batting order.
struct RemoveButton: View {
    var label: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "minus.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(ScorebookColor.out)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }
}

/// A row that opens or closes something, in the action color: "+ Add to batting order".
struct AddRow: View {
    var title: String
    var systemImage: String = "plus"
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(ScorebookFont.headline)
                .foregroundStyle(ScorebookColor.inPlay)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Small controls

/// The mockup's "− 9 +" stepper beside a label, for innings, start, time limit and hitters.
/// At the largest text sizes the label sits above the stepper.
struct ValueStepper: View {
    var label: String
    var value: String
    /// What the minus and plus buttons say to VoiceOver: "Earlier", "Later".
    var minusLabel: String = "Fewer"
    var plusLabel: String = "More"
    var onMinus: () -> Void
    var onPlus: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.small))
            : AnyLayout(HStackLayout(spacing: Spacing.medium))
        layout {
            Text(label).font(ScorebookFont.body)
            if !typeSize.isAccessibilitySize { Spacer(minLength: 0) }
            HStack(spacing: 0) {
                stepButton("minus", minusLabel, onMinus)
                Text(value)
                    .font(ScorebookFont.headline.monospacedDigit())
                    .frame(minWidth: 60)
                    .padding(.horizontal, Spacing.small)
                stepButton("plus", plusLabel, onPlus)
            }
            .background(ScorebookColor.surfaceSecondary, in: RoundedRectangle(cornerRadius: Spacing.cornerRadius, style: .continuous))
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(label))
        .accessibilityValue(Text(value))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: onPlus()
            case .decrement: onMinus()
            @unknown default: break
            }
        }
    }

    private func stepButton(_ symbol: String, _ label: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .bold))
                .frame(width: 44, height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }
}

/// A rounded chip that can be on or off, like the mockup's `.chipbtn`: "Webb cf", "Non-runner".
struct ChipStyle: ButtonStyle {
    var isOn: Bool = false
    /// The color when on: the highlight blue, or the amber of the non-runner tag.
    var onColor: Color = ScorebookColor.highlight
    var onText: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ScorebookFont.chip)
            .foregroundStyle(isOn ? onText : ScorebookColor.textPrimary)
            .padding(.horizontal, Spacing.medium)
            .frame(minHeight: 36)
            .background(isOn ? onColor : ScorebookColor.surfaceSecondary,
                        in: Capsule(style: .continuous))
            .opacity(configuration.isPressed ? 0.6 : 1)
            .contentShape(Capsule(style: .continuous))
    }
}

/// A gray box of explanation, like the mockup's `.info`.
struct InfoBox: View {
    var text: String

    var body: some View {
        Text(text)
            .font(ScorebookFont.caption)
            .foregroundStyle(ScorebookColor.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.medium)
            .background(ScorebookColor.surfaceSecondary, in: RoundedRectangle(cornerRadius: Spacing.cornerRadius, style: .continuous))
    }
}

/// An amber box for something the scorer may want to fix, which never blocks the game.
struct NoteBox: View {
    var text: String

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.small) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(ScorebookColor.warning)
                .accessibilityHidden(true)
            Text(text)
                .font(ScorebookFont.body)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Spacing.medium)
        .background(ScorebookColor.warning.opacity(0.18), in: RoundedRectangle(cornerRadius: Spacing.cornerRadius, style: .continuous))
    }
}

/// A list row with no card behind it, for information boxes and footnotes between cards.
extension View {
    func bareRow() -> some View {
        self
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: Spacing.extraSmall, leading: 0, bottom: Spacing.extraSmall, trailing: 0))
            .listRowSeparator(.hidden)
    }
}

// MARK: - Chips that wrap

/// Lays chips out left to right, starting a new line when one does not fit.
struct FlowLayout: Layout {
    var spacing: CGFloat = Spacing.small

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let rows = arrange(subviews, width: width)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        let usedWidth = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? usedWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrange(subviews, width: bounds.width)
        for row in rows {
            var x = bounds.minX
            for index in row.items {
                let size = subviews[index].sizeThatFits(.init(width: bounds.width, height: nil))
                subviews[index].place(at: CGPoint(x: x, y: bounds.minY + row.y), proposal: .init(size))
                x += size.width + spacing
            }
        }
    }

    /// One line of chips: which ones, how far down it starts, and its size.
    private struct Row {
        var items: [Int] = []
        var y: CGFloat = 0
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    /// Works out which chips go on which line.
    private func arrange(_ subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.init(width: width, height: nil))
            let needed = current.items.isEmpty ? size.width : current.width + spacing + size.width
            if needed > width, !current.items.isEmpty {
                rows.append(current)
                current = Row(y: current.y + current.height + spacing)
            }
            current.width = current.items.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.items.append(index)
        }
        if !current.items.isEmpty { rows.append(current) }
        return rows
    }
}
