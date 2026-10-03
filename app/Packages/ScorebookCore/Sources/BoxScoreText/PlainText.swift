// Turning the newspaper layout into plain text, with spaces to line up the columns.
//
// In a font where every letter is the same width (an email set in a code font, a notes
// app) the columns line up exactly. A text message uses a font where letters have
// different widths, so there the columns wander a little; the picture is the main thing
// people see, and this text is the fallback.

import Foundation

/// Prints a `NewspaperBoxScore` as plain text.
enum PlainText {
    /// The whole box score as text: sections separated by blank lines, no blank line at
    /// the end.
    static func render(_ box: NewspaperBoxScore) -> String {
        // Every left-hand label is padded to the same width, so the numbers in every table
        // and the line score start in the same place down the page. Team names are printed
        // in capitals as table headings, so measure those too.
        let labelWidth = (box.allRowLabels + (box.batting + box.pitching).map { $0.title.uppercased() })
            .map(\.count).max() ?? 0

        var sections: [[String]] = []

        var top = [box.dateLine, box.headline]
        if let status = box.status { top.append(status) }
        sections.append(top)

        // The two teams' batting tables share column widths so they line up with each other.
        let battingWidths = columnWidths(box.batting)
        for table in box.batting {
            sections.append(lines(for: table, labelWidth: labelWidth, columnWidths: battingWidths))
        }

        sections.append(lineScoreLines(box.lineScore, labelWidth: labelWidth))

        if !box.notes.isEmpty {
            sections.append([box.notes.joined(separator: " ")])
        }

        // Both pitching tables in one block, each under its own heading.
        let pitchingWidths = columnWidths(box.pitching)
        sections.append(box.pitching.flatMap { lines(for: $0, labelWidth: labelWidth, columnWidths: pitchingWidths) })

        if !box.pitchingNotes.isEmpty {
            sections.append([box.pitchingNotes.joined(separator: " ")])
        }

        return sections.map { $0.joined(separator: "\n") }.joined(separator: "\n\n")
    }

    /// One table as lines of text: the heading line, then a line per row.
    static func lines(for table: NewspaperTable, labelWidth: Int, columnWidths: [Int]) -> [String] {
        let heading = row(label: table.title.uppercased(), cells: table.columns,
                          labelWidth: labelWidth, columnWidths: columnWidths)
        let body = table.rows.map {
            row(label: $0.paddedLabel, cells: $0.cells, labelWidth: labelWidth, columnWidths: columnWidths)
        }
        return [heading] + body
    }

    /// A label padded out to the label width, then each number right-aligned in its column,
    /// with at least one space before it.
    static func row(label: String, cells: [String], labelWidth: Int, columnWidths: [Int]) -> String {
        var text = padRight(label, to: labelWidth)
        for (index, cell) in cells.enumerated() {
            let width = index < columnWidths.count ? columnWidths[index] : cell.count
            text += " " + padLeft(cell, to: width)
        }
        return text
    }

    /// How wide each column must be to hold its heading and its widest number, and never
    /// less than two characters, so one- and two-digit numbers line up.
    static func columnWidths(_ tables: [NewspaperTable]) -> [Int] {
        let count = tables.map(\.columns.count).max() ?? 0
        return (0..<count).map { index in
            let texts = tables.flatMap { table in
                (index < table.columns.count ? [table.columns[index]] : [])
                    + table.rows.compactMap { index < $0.cells.count ? $0.cells[index] : nil }
            }
            return max(2, texts.map(\.count).max() ?? 0)
        }
    }

    /// The line score: each team's name, its innings in groups of three, a dash, then runs,
    /// hits and errors. "Mudcats      011 10 —  3  7  1".
    static func lineScoreLines(_ lineScore: NewspaperLineScore, labelWidth: Int) -> [String] {
        let widths = lineScore.inningWidths
        let totals = lineScore.rows.flatMap { [$0.runs, $0.hits, $0.errors] }
        let totalWidth = max(2, totals.map { String($0).count }.max() ?? 0)
        return lineScore.rows.map { row in
            var innings = ""
            for (index, width) in widths.enumerated() {
                if index > 0 && index % 3 == 0 { innings += " " }
                innings += padLeft(index < row.innings.count ? row.innings[index] : "", to: width)
            }
            let rhe = [row.runs, row.hits, row.errors].map { " " + padLeft(String($0), to: totalWidth) }
            return padRight(row.teamName, to: labelWidth) + " " + innings + " —" + rhe.joined()
        }
    }

    /// Adds spaces after text until it is `width` characters long.
    static func padRight(_ text: String, to width: Int) -> String {
        text + String(repeating: " ", count: max(0, width - text.count))
    }

    /// Adds spaces before text until it is `width` characters long.
    static func padLeft(_ text: String, to width: Int) -> String {
        String(repeating: " ", count: max(0, width - text.count)) + text
    }
}
