// The band across the top of the batting screen, in the batting team's color (our powder blue,
// or their striped slate): the game menu button, "Diamond Dogs batting", the time limit with
// the time left, the Box score button, and under them the scoreboard: inning, score, a big
// count and the outs in words.

import SwiftUI
import Model
import DesignSystem

/// The top band.
struct AtBatBand: View {
    var info: AtBatInfo
    var onAction: (AtBatAction) -> Void
    var openMenu: () -> Void

    var body: some View {
        let look = info.look
        VStack(spacing: Spacing.small) {
            titleRow
            Scoreboard(info: info)
        }
        .foregroundStyle(look.onFill)
        .padding(.horizontal, Spacing.screenEdge)
        .padding(.top, Spacing.extraSmall)
        .padding(.bottom, Spacing.small)
        .background(TeamBackground(look).ignoresSafeArea(edges: .top))
        // The band keeps its shape at the largest text sizes, so the buttons below stay on screen.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    /// The menu button, who is batting and the time limit, and the Box score button.
    private var titleRow: some View {
        HStack(spacing: Spacing.small) {
            Button(action: openMenu) {
                Image(systemName: "line.3.horizontal")
                    .font(.title3.weight(.bold))
                    .frame(width: Spacing.minimumTapSize, height: Spacing.minimumTapSize)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Game menu"))

            VStack(alignment: .leading, spacing: 0) {
                Text("\(info.setup[info.situation.battingSide].name) batting")
                    .font(ScorebookFont.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                if let line = AtBatWording.limitLine(info.clock) {
                    // Tapping the time limit opens it, to match the umpire's clock.
                    Button { onAction(.openTimeLimit) } label: {
                        Label(line, systemImage: "clock")
                            .font(ScorebookFont.caption.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .frame(minHeight: 24, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Time limit: \(line)"))
                    .accessibilityHint(Text("Match it to the umpire's clock"))
                }
            }
            Spacer(minLength: 0)

            Button { onAction(.openBoxScore) } label: {
                HStack(spacing: 2) {
                    Text("Box score")
                    Image(systemName: "chevron.right").font(.caption.weight(.bold))
                }
                .font(ScorebookFont.chip)
                .lineLimit(1)
                .padding(.horizontal, Spacing.medium)
                .frame(minHeight: Spacing.minimumTapSize)
                .background(info.look.onFill.opacity(0.14), in: RoundedRectangle(cornerRadius: Spacing.cornerRadius, style: .continuous))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("Opens the game so far"))
        }
    }
}

/// The scoreboard: inning, the two scores, the count, and the outs, in a tinted panel.
struct Scoreboard: View {
    var info: AtBatInfo

    var body: some View {
        let s = info.situation
        HStack(spacing: 0) {
            // The inning, with an arrow up for the top and down for the bottom.
            VStack(spacing: 0) {
                Text("\(s.half == .top ? "▲" : "▼")\(s.inning)")
                    .font(ScorebookFont.scoreboardSmall)
                Text(s.half == .top ? "top" : "bottom")
                    .font(ScorebookFont.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(minWidth: 52)
            divider
            // The score, visitors on top, with a marker by the team at bat.
            VStack(alignment: .leading, spacing: 0) {
                scoreRow(.away)
                scoreRow(.home)
            }
            .padding(.horizontal, Spacing.small)
            // The score gets the room it needs first; the count and the outs shrink to fit beside it.
            .fixedSize(horizontal: true, vertical: false)
            .layoutPriority(1)
            divider
            // The count, big.
            VStack(spacing: 0) {
                Text(AtBatWording.count(s.count))
                    .font(ScorebookFont.scoreboard)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("balls–strikes")
                    .font(ScorebookFont.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            divider
            // The outs in words, in the same heavy type as the count: "0 outs", "1 out", "2 outs".
            Text(AtBatWording.outs(s.outs))
                .font(ScorebookFont.scoreboard)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.horizontal, Spacing.extraSmall)
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, Spacing.small)
        .padding(.horizontal, Spacing.extraSmall)
        // Only as tall as its words: the dividers would otherwise stretch it to fill the screen.
        .fixedSize(horizontal: false, vertical: true)
        .background(info.look.onFill.opacity(0.10), in: RoundedRectangle(cornerRadius: Spacing.cornerRadius, style: .continuous))
        // VoiceOver reads the whole scoreboard as one sentence.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(spokenSummary))
    }

    /// One team's short name and score, with "▸" by the team at bat.
    private func scoreRow(_ side: TeamSide) -> some View {
        let batting = info.situation.battingSide == side
        return HStack(spacing: Spacing.extraSmall) {
            Text(batting ? "▸" : " ").font(ScorebookFont.caption.weight(.heavy))
            Text(info.setup[side].displayShortName)
                .font(ScorebookFont.chip)
                // Always whole ("DOGS", never "DO…"): the count beside it shrinks instead.
                .fixedSize()
                .opacity(batting ? 1 : 0.75)
            Spacer(minLength: Spacing.extraSmall)
            Text("\(info.situation.score[side])")
                .font(ScorebookFont.scoreboardSmall)
                .fixedSize()
        }
    }

    /// A thin line between the scoreboard's parts.
    private var divider: some View {
        Rectangle()
            .fill(info.look.onFill.opacity(0.25))
            .frame(width: 1)
            .padding(.vertical, Spacing.extraSmall)
    }

    /// "Bottom of the 3rd. Mudcats 2, Diamond Dogs 4. Count 1 and 1. 1 out."
    private var spokenSummary: String {
        let s = info.situation
        let half = s.half == .top ? "Top" : "Bottom"
        let score = "\(info.setup.away.name) \(s.score.away), \(info.setup.home.name) \(s.score.home)"
        let balls = s.count.balls == 1 ? "1 ball" : "\(s.count.balls) balls"
        let strikes = s.count.strikes == 1 ? "1 strike" : "\(s.count.strikes) strikes"
        let outs = AtBatWording.outs(s.outs)
        return "\(half) of the \(AtBatWording.ordinal(s.inning)). \(score). \(balls), \(strikes). \(outs)."
    }
}
