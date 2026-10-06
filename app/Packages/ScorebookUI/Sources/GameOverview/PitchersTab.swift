// PitchersTab: every pitcher who has thrown today, visitors first, in the order they
// pitched: innings pitched, pitches and strikes, batters faced, and their line so far
// (hits, runs, walks, strikeouts). Our pitchers' names are in our blue; the pitcher on the
// mound now says so, and a finished game shows the win and the loss.
//
// The mockup's ER (earned runs) column is left out: the box score does not keep earned runs.

import SwiftUI
import Model
import DesignSystem

/// The Pitchers tab.
struct PitchersTab: View {
    var setup: GameSetup
    var boxScore: BoxScore
    var situation: Situation?

    /// The column headings after the name, in order.
    private static let columns = ["IP", "P-S", "BF", "H", "R", "BB", "K"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.small) {
                // Scrolls sideways only when the table is wider than the screen (large text).
                ScrollView(.horizontal, showsIndicators: false) { table }
                    .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                .padding(.vertical, Spacing.extraSmall)
                .overviewCard()

                Text("P-S is pitches and strikes. BF is batters faced.")
                    .font(ScorebookFont.caption)
                    .foregroundStyle(ScorebookColor.textSecondary)
                    .padding(.horizontal, Spacing.extraSmall)
            }
            .padding(.horizontal, Spacing.screenEdge)
            .padding(.top, Spacing.small)
            .padding(.bottom, Spacing.large)
        }
    }

    /// Every pitcher, visitors first.
    private var pitchers: [(line: PitchingLine, side: TeamSide)] {
        boxScore.away.pitching.map { ($0, TeamSide.away) } + boxScore.home.pitching.map { ($0, TeamSide.home) }
    }

    private var table: some View {
        Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow {
                Text("Pitcher")
                    .font(ScorebookFont.caption.weight(.bold))
                    .foregroundStyle(ScorebookColor.textSecondary)
                    .padding(.leading, Spacing.medium)
                    .gridColumnAlignment(.leading)
                ForEach(Self.columns, id: \.self) { title in
                    Text(title)
                        .font(ScorebookFont.caption.weight(.bold))
                        .foregroundStyle(ScorebookColor.textSecondary)
                        .frame(minWidth: 30)
                        .padding(.vertical, 6)
                }
            }
            if pitchers.isEmpty {
                GridRow {
                    Text("Nobody has pitched yet")
                        .font(ScorebookFont.body)
                        .foregroundStyle(ScorebookColor.textSecondary)
                        .padding(Spacing.medium)
                        .gridCellColumns(Self.columns.count + 1)
                }
            }
            ForEach(Array(pitchers.enumerated()), id: \.offset) { _, pitcher in
                Divider().overlay(ScorebookColor.divider)
                row(pitcher.line, side: pitcher.side)
            }
        }
        .padding(.trailing, Spacing.small)
        .fixedSize(horizontal: true, vertical: false)
    }

    private func row(_ line: PitchingLine, side: TeamSide) -> some View {
        let s = line.stats
        let values = [
            OverviewWording.inningsPitched(outs: s.outsRecorded),
            "\(s.pitches)-\(s.strikes)",
            "\(s.battersFaced)", "\(s.hits)", "\(s.runs)", "\(s.walks)", "\(s.strikeouts)",
        ]
        let isOurs = setup[side].isOurs
        let isPitchingNow = situation.map { !$0.isFinal && $0[side].pitcher == line.player } ?? false
        return GridRow {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 4) {
                    Text(lastName(line))
                        .font(ScorebookFont.body.weight(.bold))
                        .foregroundStyle(isOurs ? ScorebookColor.ourTeamText : ScorebookColor.textPrimary)
                    if let hand = setup.player(line.player)?.throwsWith {
                        Text(hand == .left ? "L" : "R")
                            .font(ScorebookFont.caption.weight(.semibold))
                            .foregroundStyle(ScorebookColor.textSecondary)
                    }
                    if let decision = line.decision {
                        Text(decision == .win ? "W" : "L")
                            .font(ScorebookFont.caption.weight(.heavy))
                            .padding(.horizontal, 5)
                            .background(ScorebookColor.surfaceSecondary, in: Capsule())
                    }
                }
                if isPitchingNow {
                    Text("pitching now")
                        .font(ScorebookFont.caption)
                        .foregroundStyle(ScorebookColor.textSecondary)
                }
            }
            .lineLimit(1)
            .padding(.leading, Spacing.medium)
            .padding(.trailing, Spacing.small)
            .padding(.vertical, 7)
            ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                Text(value)
                    .font(ScorebookFont.body)
                    .monospacedDigit()
                    .frame(minWidth: 30)
                    .padding(.horizontal, 2)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken(line, values: values, isPitchingNow: isPitchingNow))
    }

    /// "Collins", from "Ray Collins".
    private func lastName(_ line: PitchingLine) -> String {
        setup.player(line.player)?.lastName ?? line.name.split(separator: " ").last.map(String.init) ?? line.name
    }

    /// The row for VoiceOver.
    private func spoken(_ line: PitchingLine, values: [String], isPitchingNow: Bool) -> String {
        let s = line.stats
        var text = "\(line.name)"
        if let decision = line.decision { text += ", \(decision == .win ? "winning" : "losing") pitcher" }
        if isPitchingNow { text += ", pitching now" }
        text += ". \(values[0]) innings, \(s.pitches) pitches, \(s.strikes) strikes, \(s.battersFaced) batters faced, "
        text += "\(s.hits) hits, \(s.runs) runs, \(s.walks) walks, \(s.strikeouts) strikeouts."
        return text
    }
}
