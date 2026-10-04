// OverviewParts: small building blocks the game overview's tabs share: the scorebook
// notation chip, white cards, section labels, and a layout that wraps chips onto new lines.
// They copy the approved mockup's look (.nchip, .card, .ph) using only the design system's
// named colors, type and spacing.

import SwiftUI
import DesignSystem

/// Scorebook notation in a small rounded chip: "6-3", "BB", and hits ("1B 7") in green.
struct NotationChip: View {
    var text: String
    var isHit: Bool = false
    /// Quieter, for a pitch in the middle of a plate appearance.
    var isMinor: Bool = false

    var body: some View {
        Text(text)
            .font(isMinor ? ScorebookFont.caption.weight(.bold) : ScorebookFont.chip)
            .monospacedDigit()
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(isHit ? ScorebookColor.success : (isMinor ? ScorebookColor.textSecondary : ScorebookColor.textPrimary))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(isHit ? ScorebookColor.success.opacity(0.16) : ScorebookColor.surfaceSecondary,
                        in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .accessibilityLabel(Text(isHit ? "\(text), a hit" : text))
    }
}

/// A section label over a card, in capitals, with an optional note on the right:
/// "DIAMOND DOGS          TODAY".
struct SectionLabel: View {
    var title: String
    var trailing: String? = nil

    var body: some View {
        HStack {
            Text(title.uppercased())
            Spacer()
            if let trailing { Text(trailing.uppercased()) }
        }
        .font(ScorebookFont.sectionLabel)
        .foregroundStyle(ScorebookColor.textSecondary)
        .padding(.horizontal, Spacing.extraSmall)
        .padding(.top, Spacing.large)
        .padding(.bottom, 6)
        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
        .accessibilityAddTraits(.isHeader)
    }
}

extension View {
    /// The white card the overview's tables and lists sit in.
    func overviewCard() -> some View {
        self
            .background(ScorebookColor.surface, in: RoundedRectangle(cornerRadius: Spacing.cornerRadius + 2, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: Spacing.cornerRadius + 2, style: .continuous))
    }
}

/// Lays chips out left to right, wrapping onto a new line when the row is full, with every
/// line pushed to the right edge (the box so far's plate appearances, as in the mockup).
struct FlowLayout: Layout {
    var spacing: CGFloat = 4
    var lineSpacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let lines = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let width = lines.map(\.width).max() ?? 0
        let height = lines.map(\.height).reduce(0, +) + lineSpacing * CGFloat(max(0, lines.count - 1))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let lines = arrange(width: bounds.width, subviews: subviews)
        var y = bounds.minY
        for line in lines {
            // Right-aligned: start each line where it ends at the right edge.
            var x = bounds.maxX - line.width
            for index in line.items {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += line.height + lineSpacing
        }
    }

    /// One line of chips: which ones, and how wide and tall the line is.
    private struct Line {
        var items: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    /// Splits the chips into lines no wider than `width`.
    private func arrange(width: CGFloat, subviews: Subviews) -> [Line] {
        var lines: [Line] = [Line()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = lines[lines.count - 1].items.isEmpty ? size.width : lines[lines.count - 1].width + spacing + size.width
            if needed > width && !lines[lines.count - 1].items.isEmpty {
                lines.append(Line())
            }
            var line = lines[lines.count - 1]
            line.width = line.items.isEmpty ? size.width : line.width + spacing + size.width
            line.height = max(line.height, size.height)
            line.items.append(index)
            lines[lines.count - 1] = line
        }
        return lines.filter { !$0.items.isEmpty }
    }
}
