// The middle of the batting screen: the infield drawing with the runners on base, a banner
// across its top (the changeover score, or "Time's up — finish this inning"), the on-deck
// hitter in the bottom-left corner and the pitcher, with pitches and strikes, in the
// bottom-right. Tapping a runner opens the runner actions; tapping the pitcher opens the
// pitching change.

import SwiftUI
import Model
import DesignSystem

/// The field drawing and what sits on it.
struct AtBatFieldArea: View {
    var info: AtBatInfo
    var onAction: (AtBatAction) -> Void

    var body: some View {
        // The banner sits above the drawing, not on it, so it never hides a runner on second.
        VStack(spacing: 0) {
            banner
            FieldDrawing(occupiedBases: info.situation.occupiedBases, onTap: handleTap)
                .zoom(.infield)
                .battingTeam(info.look)
                .baseRunners(runnerTags)
                .padding(.top, Spacing.small)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // Grass behind everything, so the field fills the width whatever its height.
        .background(ScorebookColor.fieldGrass)
        .overlay(alignment: .bottomLeading) { onDeckCard }
        .overlay(alignment: .bottomTrailing) { pitcherCard }
        .clipped()
    }

    /// A name tag for every runner standing on base: last names, or numbers for unnamed opponents.
    private var runnerTags: [Base: FieldBaseRunner] {
        var tags: [Base: FieldBaseRunner] = [:]
        for runner in info.situation.runners where runner.base != .home {
            tags[runner.base] = FieldBaseRunner(runner: runner.runner,
                                                label: AtBatWording.shortName(info.setup.player(runner.runner)))
        }
        return tags
    }

    /// A tap on a runner's tag, or on a base with a runner on it, opens that runner's actions.
    private func handleTap(_ tap: FieldTap) {
        switch tap {
        case .runner(let id):
            onAction(.openRunnerActions(id))
        case .base(let base):
            if let runner = info.situation.runner(on: base) { onAction(.openRunnerActions(runner.runner)) }
        case .position, .spot:
            break
        }
    }

    // MARK: Banners

    /// The banner across the top of the field: the time-limit warning comes first, then the
    /// changeover score.
    @ViewBuilder private var banner: some View {
        if info.clock.isLastInning {
            BannerCard(
                title: "Time’s up — finish this inning",
                detail: nil,
                fill: ScorebookColor.out,
                text: .white
            ) { defenseButton }
        } else if info.situation.isBetweenHalfInnings {
            BannerCard(
                title: AtBatWording.changeoverTitle(info.situation),
                detail: AtBatWording.scoreLine(info.setup, info.situation.score),
                fill: ScorebookColor.foul,
                text: .white
            ) { defenseButton }
        }
    }

    /// The Defense button, on whichever banner shows, when our defense check is due at a
    /// changeover.
    @ViewBuilder private var defenseButton: some View {
        if info.situation.isBetweenHalfInnings && info.situation.defenseCheckDue {
            Button { onAction(.openDefenseCheck) } label: {
                Label("Defense", systemImage: "shield")
                    .font(ScorebookFont.chip)
                    .foregroundStyle(ScorebookColor.textPrimary)
                    .padding(.horizontal, Spacing.medium)
                    .frame(minHeight: Spacing.minimumTapSize)
                    .background(ScorebookColor.surface, in: RoundedRectangle(cornerRadius: Spacing.cornerRadius - 2, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("Check who is at each position"))
        }
    }

    // MARK: Corner cards

    /// "On deck · Tate" in the bottom-left corner.
    private var onDeckCard: some View {
        CornerCard(alignment: .leading) {
            Text("On deck").font(ScorebookFont.caption)
            Text(AtBatWording.onDeckName(info.onDeck, ours: info.weAreBatting))
                .font(ScorebookFont.chip)
        }
        .padding(Spacing.small)
        .accessibilityElement(children: .combine)
    }

    /// "Pitching: Barros (R) · 41 pitches, 25 strikes" in the bottom-right corner. A button:
    /// it opens the pitching change.
    private var pitcherCard: some View {
        let name = AtBatWording.shortName(info.pitcher)
        let hand = AtBatWording.hand(info.pitcher?.throwsWith)
        let pitches = info.pitcherTally?.pitches ?? 0, strikes = info.pitcherTally?.strikes ?? 0
        return Button { onAction(.openPitchingChange) } label: {
            CornerCard(alignment: .trailing) {
                Text("Pitching: \(name) (\(hand))").font(ScorebookFont.caption)
                Text("\(pitches) pitches, \(strikes) strikes").font(ScorebookFont.chip.monospacedDigit())
            }
        }
        .buttonStyle(.plain)
        .padding(Spacing.small)
        .accessibilityLabel(Text("Pitching: \(name), throws \(hand == "L" ? "left" : hand == "R" ? "right" : "unknown"). \(pitches) pitches, \(strikes) strikes"))
        .accessibilityHint(Text("Opens the pitching change"))
    }
}

/// A small white card in a corner of the field, with two lines of text.
struct CornerCard<Content: View>: View {
    var alignment: HorizontalAlignment
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: alignment, spacing: 0) { content }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(ScorebookColor.textPrimary)
            .padding(.horizontal, Spacing.small)
            .padding(.vertical, Spacing.extraSmall + 1)
            .frame(minHeight: Spacing.minimumTapSize)
            .background(ScorebookColor.surface, in: RoundedRectangle(cornerRadius: Spacing.cornerRadius - 2, style: .continuous))
            .shadow(color: ScorebookColor.textPrimary.opacity(0.12), radius: 3, y: 1)
            // The cards sit on the drawing, so their words stop growing early.
            .dynamicTypeSize(...DynamicTypeSize.xLarge)
    }
}

/// A banner across the top of the field: a bold line, a smaller line, and an optional button.
struct BannerCard<Trailing: View>: View {
    var title: String
    var detail: String?
    var fill: Color
    var text: Color
    @ViewBuilder var trailing: Trailing

    init(title: String, detail: String?, fill: Color, text: Color, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.title = title
        self.detail = detail
        self.fill = fill
        self.text = text
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: Spacing.small) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(ScorebookFont.headline)
                if let detail { Text(detail).font(ScorebookFont.caption) }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .accessibilityElement(children: .combine)
            Spacer(minLength: 0)
            trailing
        }
        .foregroundStyle(text)
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, Spacing.small)
        .background(fill, in: RoundedRectangle(cornerRadius: Spacing.cornerRadius, style: .continuous))
        .shadow(color: ScorebookColor.textPrimary.opacity(0.2), radius: 4, y: 2)
        .padding(.horizontal, Spacing.small)
        .padding(.top, Spacing.small)
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
    }
}
