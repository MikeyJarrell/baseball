// BoxScorePicture: a box score in, a newspaper-style picture out, for texting to the team.
//
// `BoxScorePicture` draws the layout worked out by the BoxScoreText module: the date and
// headline, each team's batting lines, the line score, the notes, and the pitching lines,
// in black ink on newsprint. `BoxScoreRenderer` turns it into an image at three times
// screen resolution, and `BoxScoreShareLink` hands it to the iPhone share sheet.

import SwiftUI
import Model
import BoxScoreText

/// The newspaper box score, drawn. Always newsprint colors, whatever the phone's mode.
public struct BoxScorePicture: View {
    let layout: NewspaperBoxScore

    /// Draws an already laid-out box score.
    public init(layout: NewspaperBoxScore) {
        self.layout = layout
    }

    /// Lays out and draws a box score. `timeZone` is where the game was played, for its date.
    public init(_ box: BoxScore, timeZone: TimeZone = .current) {
        self.layout = BoxScorePrinter.layout(box, timeZone: timeZone)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            masthead
            DoubleRule().padding(.vertical, 6)

            // Visitors' batting, a little space, then the home team's.
            ForEach(Array(layout.batting.enumerated()), id: \.offset) { index, table in
                BattingTableView(table: table)
                    .padding(.top, index == 0 ? 0 : 10)
            }

            Rule().padding(.vertical, 6)
            LineScoreView(lineScore: layout.lineScore)
            Rule().padding(.vertical, 6)

            if !layout.notes.isEmpty {
                Paragraph(text: layout.notes.joined(separator: " "))
                Rule().padding(.vertical, 6)
            }

            PitchingTablesView(tables: layout.pitching)

            if !layout.pitchingNotes.isEmpty {
                Paragraph(text: layout.pitchingNotes.joined(separator: " "))
                    .padding(.top, 6)
            }
        }
        .padding(.horizontal, Newsprint.sideMargin)
        .padding(.top, 18)
        .padding(.bottom, 16)
        .frame(width: Newsprint.width, alignment: .leading)
        .foregroundStyle(Newsprint.ink)
        .background(Newsprint.paper)
        // The picture is the same size at every text-size setting.
        .environment(\.dynamicTypeSize, .large)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Box score: \(layout.headline)")
    }

    /// The date in small spaced capitals, the headline in big bold type, and "In progress"
    /// for a game that has not ended.
    private var masthead: some View {
        VStack(spacing: 3) {
            Text(layout.dateLine.uppercased())
                .font(Newsprint.font(Newsprint.dateSize))
                .tracking(2)
            Text(layout.headline)
                .font(Newsprint.font(Newsprint.headlineSize, .heavy))
                .multilineTextAlignment(.center)
            if let status = layout.status {
                Text(status)
                    .font(Newsprint.font(Newsprint.bodySize).italic())
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Tables

/// One team's batting lines: a heading row with the team name and "ab r h bi", a row per
/// batter, the totals in bold, and under them the footnotes for any pinch hitters and
/// pinch runners ("a-popped out for Collins in the 4th.").
struct BattingTableView: View {
    let table: NewspaperTable

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HeadingRow(title: table.title, columns: table.columns)
            ForEach(Array(table.rows.enumerated()), id: \.offset) { _, row in
                NumberRow(row: row)
            }
            if !table.footnotes.isEmpty {
                Paragraph(text: table.footnotes.joined(separator: " "))
                    .padding(.top, 2)
            }
        }
    }
}

/// Both teams' pitchers under one heading row, "ip h r bb so", each team under its name.
struct PitchingTablesView: View {
    let tables: [NewspaperTable]

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HeadingRow(title: "", columns: tables.first?.columns ?? [])
            ForEach(Array(tables.enumerated()), id: \.offset) { index, table in
                Text(table.title.uppercased())
                    .font(Newsprint.font(Newsprint.headingSize, .heavy))
                    .tracking(0.6)
                    .padding(.top, index == 0 ? 0 : 3)
                ForEach(Array(table.rows.enumerated()), id: \.offset) { _, row in
                    NumberRow(row: row)
                }
            }
        }
    }
}

/// A heading row: the team name in bold capitals on the left, the column names on the right.
struct HeadingRow: View {
    let title: String
    let columns: [String]

    var body: some View {
        HStack(spacing: 0) {
            Text(title.uppercased())
                .font(Newsprint.font(Newsprint.headingSize, .heavy))
                .tracking(0.6)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(Array(columns.enumerated()), id: \.offset) { _, column in
                Text(column)
                    .font(Newsprint.font(Newsprint.headingSize, .bold))
                    .frame(width: Newsprint.columnWidth, alignment: .trailing)
            }
        }
    }
}

/// One player's line, or the totals: the name on the left (pushed in for a substitute),
/// the numbers right-aligned in fixed columns so they line up down the page.
struct NumberRow: View {
    let row: NewspaperRow

    var body: some View {
        HStack(spacing: 0) {
            FittedName(text: row.label)
                .padding(.leading, row.isSubstitute ? 10 : 0)
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(Array(row.cells.enumerated()), id: \.offset) { _, cell in
                Text(cell)
                    .frame(width: Newsprint.columnWidth, alignment: .trailing)
            }
        }
        .font(Newsprint.font(Newsprint.bodySize, row.isTotal ? .bold : .regular))
    }
}

// MARK: - Line score

/// Runs by inning in groups of three, a dash, then runs, hits and errors.
struct LineScoreView: View {
    let lineScore: NewspaperLineScore

    var body: some View {
        let widths = lineScore.inningWidths
        VStack(alignment: .leading, spacing: 1) {
            ForEach(Array(lineScore.rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 0) {
                    FittedName(text: row.teamName)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    // Each inning gets a cell as wide as that inning needs in either row,
                    // with a gap after every third inning.
                    ForEach(Array(widths.enumerated()), id: \.offset) { inning, width in
                        Text(inning < row.innings.count ? row.innings[inning] : "")
                            .frame(width: CGFloat(width) * Newsprint.inningCharacterWidth, alignment: .center)
                            .padding(.leading, inning > 0 && inning % 3 == 0 ? 6 : 0)
                    }
                    // The dash and the totals use the batting columns' width, so the dash
                    // sits under "ab" and runs, hits and errors under "r", "h" and "bi".
                    Text("—").frame(width: Newsprint.columnWidth, alignment: .trailing)
                    // Runs, hits, errors. Counted by place, since two can be the same number.
                    ForEach(Array([row.runs, row.hits, row.errors].enumerated()), id: \.offset) { _, number in
                        Text("\(number)").frame(width: Newsprint.columnWidth, alignment: .trailing)
                    }
                }
                .font(Newsprint.font(Newsprint.bodySize))
            }
        }
    }
}

/// A name on one line at full size, or, only if it is too long for the space, in smaller
/// type, so the numbers beside it never get pushed out of their columns.
struct FittedName: View {
    let text: String

    var body: some View {
        ViewThatFits(in: .horizontal) {
            Text(text).lineLimit(1)
            Text(text).lineLimit(1).font(Newsprint.font(Newsprint.bodySize * 0.85))
            Text(text).lineLimit(1).font(Newsprint.font(Newsprint.bodySize * 0.7))
        }
    }
}

// MARK: - Rules and paragraphs

/// A thin black line across the page.
struct Rule: View {
    var body: some View {
        Rectangle().fill(Newsprint.ink).frame(height: 1)
    }
}

/// Two thin lines close together, under the headline.
struct DoubleRule: View {
    var body: some View {
        VStack(spacing: 1.5) {
            Rule()
            Rule()
        }
    }
}

/// A notes paragraph, wrapping onto as many lines as it needs.
struct Paragraph: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Newsprint.font(Newsprint.bodySize))
            .lineSpacing(1.5)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
