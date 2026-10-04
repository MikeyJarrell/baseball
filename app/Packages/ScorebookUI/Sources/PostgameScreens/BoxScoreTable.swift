// The box score as a plain table: the line score, each team's batting and pitching lines,
// and the notes. The end-of-game screen shows it until the wiring job puts the newspaper-style
// picture (from the BoxScorePicture module) in its place. It prints only what the box score
// says; nothing here is added up or worked out.

import SwiftUI
import Model
import SampleData
import DesignSystem

/// A game's box score as plain tables, for reading on the phone.
///
/// - Parameters:
///   - box: The box score from the stats engine.
///   - ourSide: Which team is ours, so our name is drawn in our color. Leave it out for
///     neither.
public struct BoxScoreTable: View {
    public var box: BoxScore
    public var ourSide: TeamSide?

    public init(box: BoxScore, ourSide: TeamSide? = nil) {
        self.box = box
        self.ourSide = ourSide
    }

    /// The width of one number column, growing with the text size.
    @ScaledMetric(relativeTo: .body) private var numberWidth: CGFloat = 30
    @ScaledMetric(relativeTo: .body) private var inningWidth: CGFloat = 22

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.large) {
            fitsOrScrolls { lineScore }
            ForEach([TeamSide.away, .home], id: \.self) { side in
                teamSection(box[side])
            }
            notes
        }
        .padding(Spacing.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ScorebookColor.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: Line score

    /// Runs by inning, then R H E, one row per team, visitors first. A home team that did not
    /// bat in the last inning shows "x".
    private var lineScore: some View {
        let innings = max(box.lineScore.away.count, box.lineScore.home.count)
        return Grid(alignment: .trailing, horizontalSpacing: 0, verticalSpacing: Spacing.extraSmall) {
            GridRow {
                Text("").gridColumnAlignment(.leading)
                ForEach(0..<innings, id: \.self) { inning in
                    heading("\(inning + 1)").frame(width: inningWidth)
                }
                heading("R").frame(width: numberWidth)
                heading("H").frame(width: numberWidth)
                heading("E").frame(width: numberWidth)
            }
            ForEach([TeamSide.away, .home], id: \.self) { side in
                let team = box[side]
                let runs = box.lineScore[side]
                GridRow {
                    Text(ShortTeamName.make(from: team.name))
                        .font(ScorebookFont.headline)
                        .foregroundStyle(nameColor(side))
                        .padding(.trailing, Spacing.small)
                        .gridColumnAlignment(.leading)
                    ForEach(0..<innings, id: \.self) { inning in
                        let cell = inning < runs.count ? runs[inning] : nil
                        Text(cell.map(String.init) ?? "x")
                            .font(ScorebookFont.body.monospacedDigit())
                            .frame(width: inningWidth)
                    }
                    Text("\(team.runs)").font(ScorebookFont.headline.monospacedDigit()).frame(width: numberWidth)
                    Text("\(team.hits)").font(ScorebookFont.headline.monospacedDigit()).frame(width: numberWidth)
                    Text("\(team.errors)").font(ScorebookFont.headline.monospacedDigit()).frame(width: numberWidth)
                }
            }
        }
        .foregroundStyle(ScorebookColor.textPrimary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenLineScore)
    }

    /// "Line score. Mudcats: 4 runs, 9 hits, 2 errors. Diamond Dogs: ..."
    private var spokenLineScore: String {
        let teams = [TeamSide.away, .home].map { side -> String in
            let team = box[side]
            return "\(team.name): \(PostgameWording.counted(team.runs, "run", "runs")), "
                + "\(PostgameWording.counted(team.hits, "hit", "hits")), "
                + "\(PostgameWording.counted(team.errors, "error", "errors"))."
        }
        return "Line score. " + teams.joined(separator: " ")
    }

    // MARK: One team

    /// A team's name, its batting lines with a totals row, then its pitchers.
    private func teamSection(_ team: TeamBoxScore) -> some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text(team.name)
                .font(ScorebookFont.headline)
                .foregroundStyle(nameColor(team.side))
            fitsOrScrolls { battingGrid(team) }
            if !team.pitching.isEmpty {
                fitsOrScrolls { pitchingGrid(team) }
                    .padding(.top, Spacing.extraSmall)
            }
        }
    }

    /// Batting: name and positions, then AB R H RBI BB K. Substitutes are indented under the
    /// player they replaced.
    private func battingGrid(_ team: TeamBoxScore) -> some View {
        Grid(alignment: .trailing, horizontalSpacing: 0, verticalSpacing: Spacing.extraSmall) {
            GridRow {
                heading("Batting").gridColumnAlignment(.leading)
                ForEach(["AB", "R", "H", "RBI", "BB", "K"], id: \.self) { heading($0).frame(width: numberWidth) }
            }
            ForEach(team.batting.indices, id: \.self) { index in
                let line = team.batting[index]
                GridRow {
                    HStack(spacing: Spacing.extraSmall) {
                        Text(line.name).font(ScorebookFont.body)
                        Text(PostgameWording.positions(line))
                            .font(ScorebookFont.caption)
                            .foregroundStyle(ScorebookColor.textSecondary)
                    }
                    .lineLimit(1)
                    .padding(.leading, line.isSubstitute ? Spacing.medium : 0)
                    .padding(.trailing, Spacing.small)
                    .gridColumnAlignment(.leading)
                    numbers([line.stats.atBats, line.stats.runs, line.stats.hits,
                             line.stats.runsBattedIn, line.stats.walks, line.stats.strikeouts])
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(spokenBatting(line))
            }
            let totals = team.battingTotals
            GridRow {
                Text("Totals").font(ScorebookFont.headline).gridColumnAlignment(.leading)
                numbers([totals.atBats, totals.runs, totals.hits, totals.runsBattedIn, totals.walks, totals.strikeouts],
                        bold: true)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(team.name) totals: " + spokenBattingCounts(totals))
        }
        .foregroundStyle(ScorebookColor.textPrimary)
    }

    /// Pitching: name with W or L, then IP H R BB K and pitches-strikes.
    private func pitchingGrid(_ team: TeamBoxScore) -> some View {
        Grid(alignment: .trailing, horizontalSpacing: 0, verticalSpacing: Spacing.extraSmall) {
            GridRow {
                heading("Pitching").gridColumnAlignment(.leading)
                ForEach(["IP", "H", "R", "BB", "K"], id: \.self) { heading($0).frame(width: numberWidth) }
                heading("P-S").frame(width: numberWidth * 1.8)
            }
            ForEach(team.pitching.indices, id: \.self) { index in
                let line = team.pitching[index]
                let stats = line.stats
                GridRow {
                    HStack(spacing: Spacing.extraSmall) {
                        Text(line.name).font(ScorebookFont.body)
                        if let decision = line.decision {
                            Text(decision == .win ? "W" : "L")
                                .font(ScorebookFont.caption.weight(.bold))
                                .foregroundStyle(ScorebookColor.textSecondary)
                        }
                    }
                    .lineLimit(1)
                    .padding(.trailing, Spacing.small)
                    .gridColumnAlignment(.leading)
                    Text(stats.inningsPitchedText).font(ScorebookFont.body.monospacedDigit()).frame(width: numberWidth)
                    numbers([stats.hits, stats.runs, stats.walks, stats.strikeouts])
                    Text(stats.pitches > 0 ? "\(stats.pitches)-\(stats.strikes)" : "—")
                        .font(ScorebookFont.body.monospacedDigit())
                        .frame(width: numberWidth * 1.8, alignment: .trailing)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(spokenPitching(line))
            }
        }
        .foregroundStyle(ScorebookColor.textPrimary)
    }

    // MARK: Notes

    /// The notes under the box score, one per line: "2B: Webb, Ford".
    @ViewBuilder
    private var notes: some View {
        let lines = PostgameWording.notes(box.notes)
        if !lines.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.extraSmall) {
                ForEach(lines, id: \.self) { line in
                    Text(line)
                        .font(ScorebookFont.caption)
                        .foregroundStyle(ScorebookColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: Small parts

    /// A column heading: "AB".
    private func heading(_ text: String) -> some View {
        Text(text)
            .font(ScorebookFont.sectionLabel)
            .foregroundStyle(ScorebookColor.textSecondary)
            .lineLimit(1)
    }

    /// A run of number cells.
    @ViewBuilder
    private func numbers(_ values: [Int], bold: Bool = false) -> some View {
        ForEach(values.indices, id: \.self) { i in
            Text("\(values[i])")
                .font((bold ? ScorebookFont.headline : ScorebookFont.body).monospacedDigit())
                .frame(width: numberWidth, alignment: .trailing)
        }
    }

    /// Our team's name in our color; the other team's in plain text.
    private func nameColor(_ side: TeamSide) -> Color {
        side == ourSide ? ScorebookColor.ourTeamText : ScorebookColor.textPrimary
    }

    /// Shows the content at its natural width when it fits, and lets it scroll sideways when
    /// it does not (extra innings, or the largest text sizes).
    private func fitsOrScrolls<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        let built = content()
        return ViewThatFits(in: .horizontal) {
            built
            ScrollView(.horizontal) { built }
        }
    }

    // MARK: Words for VoiceOver

    private func spokenBattingCounts(_ s: BattingCounts) -> String {
        "\(s.atBats) at-bats, \(PostgameWording.counted(s.runs, "run", "runs")), "
            + "\(PostgameWording.counted(s.hits, "hit", "hits")), \(s.runsBattedIn) runs batted in, "
            + "\(PostgameWording.counted(s.walks, "walk", "walks")), "
            + "\(PostgameWording.counted(s.strikeouts, "strikeout", "strikeouts"))"
    }

    private func spokenBatting(_ line: BattingLine) -> String {
        "\(line.name), \(PostgameWording.positions(line)): " + spokenBattingCounts(line.stats)
    }

    private func spokenPitching(_ line: PitchingLine) -> String {
        let s = line.stats
        var words = line.name
        if let decision = line.decision { words += decision == .win ? ", winning pitcher" : ", losing pitcher" }
        words += ": \(s.inningsPitchedText) innings, \(PostgameWording.counted(s.hits, "hit", "hits")), "
            + "\(PostgameWording.counted(s.runs, "run", "runs")), \(PostgameWording.counted(s.walks, "walk", "walks")), "
            + "\(PostgameWording.counted(s.strikeouts, "strikeout", "strikeouts"))"
        if s.pitches > 0 { words += ", \(s.pitches) pitches, \(s.strikes) strikes" }
        return words
    }
}
