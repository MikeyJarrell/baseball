// The newspaper box score, laid out but not yet drawn: every line of words and numbers
// it will show, in order, already shortened and formatted.
//
// Both the plain text (PlainText.swift) and the picture (the BoxScorePicture module) are
// drawn from this one layout, so the two always say the same thing. Only the drawing
// differs: the text pads columns with spaces, the picture lines them up on a grid.

import Foundation

/// A whole box score as a newspaper sports page printed it, top to bottom.
public struct NewspaperBoxScore: Equatable, Sendable {
    /// The small line above the headline: the game's date, "Saturday, May 2, 2026".
    public var dateLine: String
    /// The big line: the leader first, "Diamond Dogs 5, Mudcats 3".
    public var headline: String
    /// "In progress" for a box score of a game that has not ended; missing once it is final.
    public var status: String?
    /// The visitors' batting table, then the home team's.
    public var batting: [NewspaperTable]
    /// Runs by inning for both teams, with runs, hits and errors at the end.
    public var lineScore: NewspaperLineScore
    /// The notes under the line score, one per kind: "E—Kim, Tate.", "DP—Mudcats 2, ...".
    public var notes: [String]
    /// The visitors' pitchers, then the home team's.
    public var pitching: [NewspaperTable]
    /// The notes under the pitching lines: who was hit by a pitch, pitches and strikes.
    public var pitchingNotes: [String]

    public init(
        dateLine: String, headline: String, status: String?,
        batting: [NewspaperTable], lineScore: NewspaperLineScore, notes: [String],
        pitching: [NewspaperTable], pitchingNotes: [String]
    ) {
        self.dateLine = dateLine
        self.headline = headline
        self.status = status
        self.batting = batting
        self.lineScore = lineScore
        self.notes = notes
        self.pitching = pitching
        self.pitchingNotes = pitchingNotes
    }

    /// Every name and label in the left-hand column of any table, for working out how wide
    /// that column must be so the numbers line up all the way down the page.
    public var allRowLabels: [String] {
        let tables = batting + pitching
        return tables.flatMap { table in [table.title] + table.rows.map(\.paddedLabel) }
            + lineScore.rows.map(\.teamName)
    }
}

/// One table of a box score: a team's batting lines or a team's pitching lines.
public struct NewspaperTable: Equatable, Sendable {
    /// The team's name, printed as the table's heading: "Mudcats".
    public var title: String
    /// The column headings: "ab", "r", "h", "bi" for batters; "ip", "h", "r", "bb", "so"
    /// for pitchers.
    public var columns: [String]
    /// One row per player, and for batters a totals row at the end.
    public var rows: [NewspaperRow]

    public init(title: String, columns: [String], rows: [NewspaperRow]) {
        self.title = title
        self.columns = columns
        self.rows = rows
    }
}

/// One line of a table: a name on the left, numbers in columns on the right.
public struct NewspaperRow: Equatable, Sendable {
    /// What is printed on the left: "Ortiz cf", "Collins", "Totals".
    public var label: String
    /// True for a player who came into the game after it started, who is printed a little
    /// to the right, under the player they replaced.
    public var isSubstitute: Bool
    /// True for the totals row at the bottom of a team's batting lines.
    public var isTotal: Bool
    /// The numbers, one per column, already written as text ("3", "4⅓").
    public var cells: [String]

    public init(label: String, isSubstitute: Bool = false, isTotal: Bool = false, cells: [String]) {
        self.label = label
        self.isSubstitute = isSubstitute
        self.isTotal = isTotal
        self.cells = cells
    }

    /// The label with the substitute's indent in front, as plain text prints it.
    public var paddedLabel: String {
        (isSubstitute ? NewspaperRow.substituteIndent : "") + label
    }

    /// The spaces a substitute's name is pushed to the right by in plain text.
    public static let substituteIndent = "  "
}

/// The line score: each team's runs inning by inning, then runs, hits and errors.
public struct NewspaperLineScore: Equatable, Sendable {
    /// The visitors' row, then the home team's.
    public var rows: [NewspaperLineScoreRow]

    public init(rows: [NewspaperLineScoreRow]) {
        self.rows = rows
    }

    /// How many inning cells the widest row has.
    public var inningCount: Int {
        rows.map(\.innings.count).max() ?? 0
    }

    /// How wide each inning's cell is, in characters, so a ten-run inning, printed "(10)",
    /// keeps the innings after it lined up between the two teams.
    public var inningWidths: [Int] {
        (0..<inningCount).map { inning in
            rows.map { row in inning < row.innings.count ? row.innings[inning].count : 0 }.max() ?? 1
        }
    }
}

/// One team's row of the line score.
public struct NewspaperLineScoreRow: Equatable, Sendable {
    public var teamName: String
    /// Runs in each inning as printed: "0", "2", "x" for an inning the home team did not
    /// need to bat, "(10)" for ten or more.
    public var innings: [String]
    public var runs: Int
    public var hits: Int
    public var errors: Int

    public init(teamName: String, innings: [String], runs: Int, hits: Int, errors: Int) {
        self.teamName = teamName
        self.innings = innings
        self.runs = runs
        self.hits = hits
        self.errors = errors
    }
}
