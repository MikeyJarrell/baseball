// BoxTab: the box score so far, team by team (visitors first, as everywhere on the screen). Each batter has
// a row with their number, name, "2 for 3 · 1 run · cf", and today's plate appearances as
// scorebook notation chips, hits in green. Substitutes sit indented under the player they
// replaced, in the order the box score lists them. Anyone who fielded without batting is
// listed under the team, so they show they took part.

import SwiftUI
import Model
import DesignSystem

/// The Box tab.
struct BoxTab: View {
    var setup: GameSetup
    var boxScore: BoxScore
    var plateAppearances: [PlayerID: [PlateAppearanceSummary]]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                // Visitors first, as everywhere on this screen.
                ForEach([TeamSide.away, .home], id: \.self) { side in
                    teamBlock(boxScore[side], look: setup[side].isOurs ? .ours : .theirs)
                }
            }
            .padding(.horizontal, Spacing.screenEdge)
            .padding(.bottom, Spacing.large)
        }
    }

    @ViewBuilder
    private func teamBlock(_ team: TeamBoxScore, look: TeamLook) -> some View {
        SectionLabel(title: team.name, trailing: "today")
        VStack(spacing: 0) {
            ForEach(Array(team.batting.enumerated()), id: \.offset) { i, line in
                BatterRow(line: line, look: look, plateAppearances: plateAppearances[line.player] ?? [])
                if i < team.batting.count - 1 {
                    Divider().overlay(ScorebookColor.divider)
                }
            }
            if team.batting.isEmpty {
                Text("Nobody has batted yet")
                    .font(ScorebookFont.body)
                    .foregroundStyle(ScorebookColor.textSecondary)
                    .padding(Spacing.medium)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .overviewCard()

        let fieldersOnly = fieldedWithoutBatting(team)
        if !fieldersOnly.isEmpty {
            Text("Fielded without batting: " + fieldersOnly.joined(separator: ", "))
                .font(ScorebookFont.caption)
                .foregroundStyle(ScorebookColor.textSecondary)
                .padding(.horizontal, Spacing.extraSmall)
                .padding(.top, 6)
        }
    }

    /// Players with a fielding line and no batting line: "Voss (p)".
    private func fieldedWithoutBatting(_ team: TeamBoxScore) -> [String] {
        let batters = Set(team.batting.map(\.player))
        return team.fielding.filter { !batters.contains($0.player) }.map { line in
            let positions = line.appearances.map(\.position.abbreviation).joined(separator: "-")
            return positions.isEmpty ? line.name : "\(line.name) (\(positions))"
        }
    }
}

/// One batter in the box so far.
struct BatterRow: View {
    var line: BattingLine
    var look: TeamLook
    var plateAppearances: [PlateAppearanceSummary]

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        // At the accessibility text sizes the chips go under the name instead of beside it.
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.small))
            : AnyLayout(HStackLayout(alignment: .center, spacing: Spacing.small))
        layout {
            HStack(spacing: 10) {
                PlayerNumberBadge(line.number ?? "?", look: look, size: 34)
                VStack(alignment: .leading, spacing: 1) {
                    Text(line.name)
                        .font(ScorebookFont.headline)
                        .lineLimit(1)
                    Text(OverviewWording.battingSummary(line))
                        .font(ScorebookFont.caption)
                        .foregroundStyle(ScorebookColor.textSecondary)
                }
            }
            .layoutPriority(1)
            Spacer(minLength: 0)
            chips
        }
        .padding(.vertical, 9)
        .padding(.trailing, Spacing.medium)
        // Substitutes are indented under the player they replaced.
        .padding(.leading, line.isSubstitute ? Spacing.medium + Spacing.extraLarge : Spacing.medium)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
    }

    @ViewBuilder private var chips: some View {
        if plateAppearances.isEmpty {
            Text("—")
                .font(ScorebookFont.caption)
                .foregroundStyle(ScorebookColor.textSecondary)
        } else {
            FlowLayout(spacing: 4, lineSpacing: 4) {
                ForEach(Array(plateAppearances.enumerated()), id: \.offset) { _, pa in
                    NotationChip(text: pa.notation, isHit: OverviewWording.isHit(pa.outcome))
                }
            }
        }
    }

    /// The row for VoiceOver: "Luis Ortiz, 2 for 2, center field. Today: 1B 7, 3B 9."
    private var spoken: String {
        let today = plateAppearances.isEmpty ? "No plate appearances yet" : "Today: " + plateAppearances.map(\.notation).joined(separator: ", ")
        let sub = line.isSubstitute ? "Substitute. " : ""
        return "\(sub)\(line.name), \(OverviewWording.battingSummary(line)). \(today)."
    }
}
