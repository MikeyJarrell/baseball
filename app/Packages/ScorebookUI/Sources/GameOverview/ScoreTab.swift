// ScoreTab: the game overview's first tab. The line score by inning with runs, hits and
// errors (the inning being played in amber), where the game stands right now, runners left
// on base, and the box score notes so far ("2B: Webb, Cole").
//
// Every number comes from the box score so far and the situation as they are handed in.

import SwiftUI
import Model
import DesignSystem

/// The Score tab.
struct ScoreTab: View {
    var setup: GameSetup
    var boxScore: BoxScore
    var situation: Situation?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                LineScoreTable(setup: setup, boxScore: boxScore, situation: situation)
                    .padding(.vertical, Spacing.extraSmall)
                    .overviewCard()

                if let situation, !situation.isFinal {
                    card(title: "Right now") {
                        Text(OverviewWording.rightNow(situation))
                            .font(ScorebookFont.headline)
                        if let line = atBatLine(situation) {
                            Text(line)
                                .font(ScorebookFont.body)
                                .foregroundStyle(ScorebookColor.textSecondary)
                        }
                    }
                }

                card(title: "Left on base") {
                    Text("\(boxScore.away.name) \(boxScore.away.leftOnBase) · \(boxScore.home.name) \(boxScore.home.leftOnBase)")
                        .font(ScorebookFont.body)
                        .monospacedDigit()
                }

                let notes = noteLines
                if !notes.isEmpty {
                    card(title: "Notes") {
                        ForEach(notes, id: \.self) { line in
                            Text(line).font(ScorebookFont.body)
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.screenEdge)
            .padding(.bottom, Spacing.large)
        }
    }

    /// A white card with a small heading, as in the mockup's "Right now" card.
    private func card<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.extraSmall) {
            Text(title)
                .font(ScorebookFont.sectionLabel)
                .foregroundStyle(ScorebookColor.textSecondary)
                .accessibilityAddTraits(.isHeader)
            content()
        }
        .padding(Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overviewCard()
    }

    /// "Ortiz batting, count 1–1", or who leads off after the break.
    private func atBatLine(_ situation: Situation) -> String? {
        guard let batter = situation.batter else { return nil }
        let name = setup.player(batter)?.displayName ?? batter.rawValue
        if situation.isBetweenHalfInnings { return "\(name) leads off the \(OverviewWording.halfInning(situation.half, situation.inning).lowercased())" }
        return "\(name) batting, count \(OverviewWording.count(situation.count))"
    }

    /// The box score notes so far, one line each, skipping empty ones:
    /// "2B: Webb, Cole", "DP: Diamond Dogs 2".
    private var noteLines: [String] {
        let n = boxScore.notes
        func players(_ label: String, _ tallies: [PlayerTally]) -> String? {
            guard !tallies.isEmpty else { return nil }
            let names = tallies.map { tally in
                let last = tally.name.split(separator: " ").last.map(String.init) ?? tally.name
                return tally.count > 1 ? "\(last) \(tally.count)" : last
            }
            return "\(label): \(names.joined(separator: ", "))"
        }
        func teams(_ label: String, _ tallies: [TeamTally]) -> String? {
            guard !tallies.isEmpty else { return nil }
            return "\(label): " + tallies.map { "\($0.name) \($0.count)" }.joined(separator: ", ")
        }
        return [
            players("E", n.errors), teams("DP", n.doublePlays), teams("TP", n.triplePlays),
            players("2B", n.doubles), players("3B", n.triples), players("HR", n.homeRuns),
            players("SB", n.stolenBases), players("CS", n.caughtStealing),
            players("S", n.sacrificeBunts), players("SF", n.sacrificeFlies),
            players("HBP", n.hitByPitch),
        ].compactMap { $0 }
    }
}

/// The line score: innings across, the visitors on top and the home team below, then R H E.
struct LineScoreTable: View {
    var setup: GameSetup
    var boxScore: BoxScore
    var situation: Situation?

    var body: some View {
        // Short names ("MUD", "DOGS") keep nine innings and R H E on the screen at the usual
        // text size; extra innings and large text scroll sideways, keeping the inning being
        // played in view.
        ScrollViewReader { reader in
            ScrollView(.horizontal, showsIndicators: false) {
                table
            }
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            .onAppear {
                if let current = currentCell { reader.scrollTo("inning-\(current.inning)", anchor: .center) }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenSummary)
    }

    /// Innings to show: at least the scheduled ones, more in extra innings.
    private var innings: Int {
        max(setup.scheduledInnings, boxScore.lineScore.away.count, boxScore.lineScore.home.count)
    }

    /// The inning and team now batting, drawn in amber. None between half-innings or at the end.
    private var currentCell: (inning: Int, side: TeamSide)? {
        guard let situation, !situation.isFinal, !boxScore.isFinal, !situation.isBetweenHalfInnings else { return nil }
        return (situation.inning, situation.battingSide)
    }

    private var table: some View {
        Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow {
                Color.clear.frame(width: 1, height: 1)
                ForEach(1...innings, id: \.self) { inning in
                    header("\(inning)").id("inning-\(inning)")
                }
                header("R")
                header("H")
                header("E")
            }
            Divider().overlay(ScorebookColor.divider)
            teamRow(.away)
            Divider().overlay(ScorebookColor.divider)
            teamRow(.home)
        }
        .padding(.trailing, Spacing.small)
        .fixedSize(horizontal: true, vertical: false)
    }

    private func header(_ text: String) -> some View {
        Text(text)
            .font(ScorebookFont.caption.weight(.bold))
            .foregroundStyle(ScorebookColor.textSecondary)
            .frame(minWidth: 24)
            .padding(.vertical, 6)
    }

    private func teamRow(_ side: TeamSide) -> some View {
        let team = boxScore[side]
        let runs = boxScore.lineScore[side]
        let isOurs = setup[side].isOurs
        return GridRow {
            Text(setup[side].displayShortName)
                .font(ScorebookFont.body.weight(.bold))
                .foregroundStyle(isOurs ? ScorebookColor.ourTeamText : ScorebookColor.textPrimary)
                .lineLimit(1)
                .padding(.leading, Spacing.medium)
                .padding(.trailing, Spacing.small)
                .gridColumnAlignment(.leading)
            ForEach(1...innings, id: \.self) { inning in
                let isCurrent = currentCell?.inning == inning && currentCell?.side == side
                cell(text(runs, inning), isCurrent: isCurrent)
            }
            cell("\(team.runs)", bold: true)
            cell("\(team.hits)", bold: true)
            cell("\(team.errors)", bold: true)
        }
        .accessibilityLabel(team.name)
    }

    /// What one inning's cell says: the runs, "x" when the home team did not need to bat in
    /// the last inning of a finished game, or blank for an inning not yet played.
    private func text(_ runs: [Int?], _ inning: Int) -> String {
        guard inning <= runs.count else { return "" }
        if let value = runs[inning - 1] { return "\(value)" }
        return boxScore.isFinal ? "x" : ""
    }

    private func cell(_ text: String, isCurrent: Bool = false, bold: Bool = false) -> some View {
        Text(text)
            .font(bold || isCurrent ? ScorebookFont.body.weight(.heavy) : ScorebookFont.body)
            .monospacedDigit()
            .foregroundStyle(isCurrent ? ScorebookColor.onStrike : ScorebookColor.textPrimary)
            .frame(minWidth: 24, minHeight: 34)
            .padding(.horizontal, 1)
            .background {
                if isCurrent {
                    RoundedRectangle(cornerRadius: 6, style: .continuous).fill(ScorebookColor.warning)
                }
            }
    }

    /// The whole line score for VoiceOver: "Mudcats: 0, 1, 1. 2 runs, 4 hits, 0 errors. ..."
    private var spokenSummary: String {
        TeamSide.allCases.map { side in
            let team = boxScore[side]
            let innings = boxScore.lineScore[side].map { $0.map(String.init) ?? "x" }.joined(separator: ", ")
            return "\(team.name) by inning: \(innings). \(team.runs) runs, \(team.hits) hits, \(team.errors) errors."
        }.joined(separator: " ")
    }
}
