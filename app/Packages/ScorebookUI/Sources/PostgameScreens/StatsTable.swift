// The stats table: names in a column pinned on the left, numbers in columns that scroll
// sideways, headings pinned along the top. Used for the season batting and pitching tables and
// for a player's game log.
//
// How the pinning works: the names sit outside the sideways scroll view, so they never move
// sideways. The headings sit outside the up-and-down scroll view, so they never scroll away,
// and they are shifted left by however far the numbers have been scrolled, so each heading stays
// over its column. Every row has the same height in both halves, so names and numbers line up.

import SwiftUI
import DesignSystem

/// One column of a stats table: its heading, its width, and how to print a row's value.
struct StatsTableColumn<Row>: Identifiable {
    var id: String
    /// The heading: "AVG".
    var title: String
    /// The heading in words, for VoiceOver: "batting average".
    var spokenName: String
    /// How wide the column is at the standard text size, in points. It grows with the text.
    var width: CGFloat
    /// The value as printed: ".333".
    var text: (Row) -> String
    /// True when this row's value should be grayed out (an average the filter hides).
    var isDimmed: (Row) -> Bool = { _ in false }
}

/// A table with a pinned name column and sideways-scrolling numbers.
///
/// - Parameters:
///   - rows: The rows, already in the order to show them.
///   - nameTitle: The heading over the names: "Player", "Pitcher", "Game".
///   - name: The words in the pinned column for a row.
///   - columns: The number columns, left to right.
///   - sortedColumnID: The column the rows are sorted by, if any; its heading is colored with
///     an arrow.
///   - sortedDescending: Whether that column has the biggest number on top.
///   - onSort: Called with a column's id when its heading is tapped. Leave it out for a table
///     that does not sort.
///   - onTapRow: Called when a row is tapped.
///   - rowHint: What tapping a row does, for VoiceOver: "Opens their season page".
///   - scrollsVertically: Whether the table scrolls up and down by itself.
struct StatsTable<Row>: View {
    var rows: [Row]
    var nameTitle: String
    var name: (Row) -> String
    var columns: [StatsTableColumn<Row>]
    var sortedColumnID: String? = nil
    var sortedDescending: Bool = true
    var onSort: ((String) -> Void)? = nil
    var onTapRow: ((Row) -> Void)? = nil
    var rowHint: String? = nil
    /// True when the table scrolls up and down by itself, with its headings pinned (the season
    /// tables). False for a table inside a page that scrolls (a player's game log).
    var scrollsVertically: Bool = true

    /// How far the numbers have been scrolled sideways, so the headings can follow.
    @State private var scrolledSideways: CGFloat = 0
    /// How tall all the rows are together, so a short table ends after its last row instead
    /// of filling the screen with an empty card.
    @State private var rowsHeight: CGFloat = 0

    /// Row height and column widths grow with the phone's text size.
    @ScaledMetric(relativeTo: .body) private var rowHeight: CGFloat = 44
    @ScaledMetric(relativeTo: .body) private var widthScale: CGFloat = 1
    @ScaledMetric(relativeTo: .body) private var scaledNameWidth: CGFloat = 124

    /// The pinned name column never takes more than this, so numbers always show beside it on
    /// the smallest iPhone at the largest text sizes. Long names shrink, then wrap to two lines.
    private var nameWidth: CGFloat { min(scaledNameWidth, 170) }

    var body: some View {
        VStack(spacing: 0) {
            headings
            if scrollsVertically {
                ScrollView(.vertical) { rowsBody }
                    .scrollBounceBehavior(.basedOnSize, axes: .vertical)
                    .onScrollGeometryChange(for: CGFloat.self) { geometry in
                        geometry.contentSize.height
                    } action: { _, height in
                        rowsHeight = height
                    }
                    .frame(maxHeight: rowsHeight > 0 ? rowsHeight : nil)
            } else {
                rowsBody
            }
        }
        .background(ScorebookColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 4, y: 1)
    }

    /// Every row: the pinned names beside the numbers, which scroll sideways.
    private var rowsBody: some View {
        HStack(alignment: .top, spacing: 0) {
            nameColumn
            ScrollView(.horizontal) {
                VStack(spacing: 0) {
                    ForEach(rows.indices, id: \.self) { index in
                        numberRow(rows[index])
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            // Keep the headings over their columns as the numbers scroll.
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.x + geometry.contentInsets.leading
            } action: { _, offset in
                scrolledSideways = offset
            }
        }
    }

    // MARK: Headings

    /// The heading row: the pinned name heading, then the column headings, which shift with
    /// the numbers below them.
    private var headings: some View {
        HStack(spacing: 0) {
            Text(nameTitle)
                .font(ScorebookFont.sectionLabel)
                .foregroundStyle(ScorebookColor.textSecondary)
                .padding(.leading, Spacing.medium)
                .frame(width: nameWidth, height: rowHeight, alignment: .leading)
                .overlay(alignment: .trailing) { verticalLine }
                .accessibilityHidden(true)
            Color.clear
                .frame(height: rowHeight)
                .frame(maxWidth: .infinity)
                .overlay(alignment: .leading) {
                    HStack(spacing: 0) {
                        ForEach(columns) { column in
                            heading(column)
                        }
                    }
                    .fixedSize()
                    .offset(x: -scrolledSideways)
                }
                .clipped()
        }
        .background(ScorebookColor.surface)
        .overlay(alignment: .bottom) { horizontalLine }
        .zIndex(1)
    }

    /// One column heading: a button that sorts by it, when the table sorts.
    @ViewBuilder
    private func heading(_ column: StatsTableColumn<Row>) -> some View {
        let isSorted = column.id == sortedColumnID
        let label = Text(column.title + (isSorted ? (sortedDescending ? " ↓" : " ↑") : ""))
            .font(ScorebookFont.sectionLabel)
            .lineLimit(1)
            .foregroundStyle(isSorted ? ScorebookColor.inPlay : ScorebookColor.textSecondary)
            .frame(width: column.width * widthScale, height: rowHeight, alignment: .trailing)
            .padding(.trailing, 2)
        if let onSort {
            Button { onSort(column.id) } label: { label.contentShape(Rectangle()) }
                .buttonStyle(.plain)
                .accessibilityLabel("Sort by \(column.spokenName)")
                .accessibilityValue(isSorted ? (sortedDescending ? "sorted, highest first" : "sorted, lowest first") : "")
                .accessibilityAddTraits(isSorted ? .isSelected : [])
        } else {
            label.accessibilityHidden(true)
        }
    }

    // MARK: Rows

    /// The pinned names, one per row. Each name is the row's button for VoiceOver, and reads
    /// the whole row aloud.
    private var nameColumn: some View {
        VStack(spacing: 0) {
            ForEach(rows.indices, id: \.self) { index in
                let row = rows[index]
                Button { onTapRow?(row) } label: {
                    Text(name(row))
                        .font(ScorebookFont.body.weight(.semibold))
                        .foregroundStyle(ScorebookColor.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .multilineTextAlignment(.leading)
                        .padding(.leading, Spacing.medium)
                        .padding(.trailing, Spacing.extraSmall)
                        .frame(width: nameWidth, height: rowHeight, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(onTapRow == nil)
                .overlay(alignment: .bottom) { horizontalLine }
                .accessibilityLabel(spokenRow(row))
                .accessibilityHint(rowHint ?? "")
            }
        }
        .frame(width: nameWidth)
        .overlay(alignment: .trailing) { verticalLine }
    }

    /// One row of numbers. Tapping anywhere on it does what tapping the name does.
    private func numberRow(_ row: Row) -> some View {
        HStack(spacing: 0) {
            ForEach(columns) { column in
                let dimmed = column.isDimmed(row)
                Text(column.text(row))
                    .font(ScorebookFont.body.monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(dimmed ? ScorebookColor.textSecondary : ScorebookColor.textPrimary)
                    .frame(width: column.width * widthScale, height: rowHeight, alignment: .trailing)
                    .padding(.trailing, 2)
            }
        }
        .padding(.trailing, Spacing.medium)
        .overlay(alignment: .bottom) { horizontalLine }
        .contentShape(Rectangle())
        .onTapGesture { onTapRow?(row) }
        .accessibilityHidden(true)
    }

    /// The whole row in words: "Alex Moreno: games 1, plate appearances 3, ... batting
    /// average .333".
    private func spokenRow(_ row: Row) -> String {
        let values = columns.map { "\($0.spokenName) \($0.text(row))" }
        return name(row) + ": " + values.joined(separator: ", ")
    }

    // MARK: Lines

    private var horizontalLine: some View {
        Rectangle().fill(ScorebookColor.divider).frame(height: 0.5)
    }

    private var verticalLine: some View {
        Rectangle().fill(ScorebookColor.divider).frame(width: 0.5)
    }
}
