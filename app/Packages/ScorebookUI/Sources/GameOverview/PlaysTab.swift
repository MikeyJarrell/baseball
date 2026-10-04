// PlaysTab: the play-by-play. Every event, newest first, grouped by half-inning under
// headings that stay pinned while scrolling ("▼ 3rd · 6 events"). The batter at the plate now
// is the highlighted "At bat" row at the top. Pitches in the middle of a plate appearance are
// hidden until the scorer switches on "Show every pitch", so a long game stays readable;
// the pitch that ends a plate appearance always shows as that plate appearance.
//
// Tapping a row opens "Fix a play" (FixPlaySheet). A row the rules engine flagged after an
// earlier edit shows a warning with what looks wrong.
//
// The list stays smooth with hundreds of events: the rows are built once per play log, and
// only the rows on screen are drawn.

import SwiftUI
import Model
import DesignSystem

/// The Plays tab.
struct PlaysTab: View {
    var log: PlayLog
    var situation: Situation?
    var onAction: (GameOverviewAction) -> Void

    /// Every event as a row, oldest first, built once for this play log.
    private let rows: [PlayRow]
    @State private var showPitches = false
    @State private var fixing: PlayRow?

    init(log: PlayLog, situation: Situation?, onAction: @escaping (GameOverviewAction) -> Void) {
        self.log = log
        self.situation = situation
        self.onAction = onAction
        self.rows = PlayByPlay.rows(for: log)
    }

    var body: some View {
        let sections = PlayByPlay.sections(from: rows, showPitches: showPitches)
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                Toggle("Show every pitch", isOn: $showPitches)
                    .font(ScorebookFont.body)
                    .tint(ScorebookColor.highlight)
                    .padding(.horizontal, Spacing.medium)
                    .frame(minHeight: Spacing.minimumTapSize)
                    .overviewCard()

                if let atBat = PlayByPlay.currentAtBat(log: log, situation: situation) {
                    SectionLabel(title: OverviewWording.halfInning(situation!.half, situation!.inning), trailing: "now")
                    CurrentAtBatRow(atBat: atBat).overviewCard()
                }

                if sections.isEmpty {
                    Text("No plays yet.")
                        .font(ScorebookFont.body)
                        .foregroundStyle(ScorebookColor.textSecondary)
                        .padding(.top, Spacing.large)
                }

                ForEach(sections) { section in
                    Section {
                        VStack(spacing: 0) {
                            ForEach(section.rows) { row in
                                PlayRowView(row: row) { fixing = row }
                                if row.id != section.rows.last?.id {
                                    Divider().overlay(ScorebookColor.divider)
                                }
                            }
                        }
                        .overviewCard()
                    } header: {
                        SectionLabel(title: section.heading, trailing: OverviewWording.plural(section.rows.count, "event"))
                            .accessibilityLabel("\(section.spokenHeading), \(OverviewWording.plural(section.rows.count, "event"))")
                            .background(ScorebookColor.background)
                    }
                }

                Text("Newest first. Tap any play to fix it; everything after it recalculates.")
                    .font(ScorebookFont.caption)
                    .foregroundStyle(ScorebookColor.textSecondary)
                    .padding(.horizontal, Spacing.extraSmall)
                    .padding(.top, Spacing.medium)
            }
            .padding(.horizontal, Spacing.screenEdge)
            .padding(.bottom, Spacing.large)
        }
        .sheet(item: $fixing) { row in
            FixPlaySheet(row: row, onAction: onAction)
                .presentationDetents([.medium, .large])
        }
    }
}

/// One event in the play-by-play: the notation chip, the event in words, what it led to,
/// and a chevron. The whole row is one button.
struct PlayRowView: View {
    var row: PlayRow
    var onTap: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        // At the accessibility text sizes the chip sits above the words instead of beside them.
        let big = typeSize.isAccessibilitySize
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 10) {
                if !big {
                    Group {
                        if row.notation.isEmpty {
                            Color.clear.frame(width: 58, height: 1)
                        } else {
                            NotationChip(text: row.notation, isHit: row.isHit, isMinor: row.isMinor)
                        }
                    }
                    .frame(minWidth: 58)
                }

                VStack(alignment: .leading, spacing: 2) {
                    if big && !row.notation.isEmpty {
                        NotationChip(text: row.notation, isHit: row.isHit, isMinor: row.isMinor)
                    }
                    Text(row.text)
                        .font(row.isMinor ? ScorebookFont.caption : ScorebookFont.body)
                        .foregroundStyle(row.isMinor ? ScorebookColor.textSecondary : ScorebookColor.textPrimary)
                    if !row.details.isEmpty {
                        Text(row.details.joined(separator: " · "))
                            .font(ScorebookFont.caption)
                            .foregroundStyle(ScorebookColor.textSecondary)
                    }
                    if let note = row.reviewNote {
                        Label(note, systemImage: "exclamationmark.triangle.fill")
                            .font(ScorebookFont.caption.weight(.semibold))
                            .foregroundStyle(ScorebookColor.out)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(ScorebookFont.caption.weight(.semibold))
                    .foregroundStyle(ScorebookColor.textSecondary)
                    .padding(.top, 3)
            }
            .padding(.horizontal, Spacing.medium)
            .padding(.vertical, row.isMinor ? 6 : 10)
            .frame(minHeight: Spacing.minimumTapSize)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
        .accessibilityHint("Opens Fix a play")
        .accessibilityAddTraits(.isButton)
    }

    /// The row for VoiceOver: "6-3. Moreno grounded out to short. 1 out."
    private var spoken: String {
        var parts = [row.text] + row.details
        if !row.notation.isEmpty { parts.insert(row.notation, at: 0) }
        if let note = row.reviewNote { parts.append("Check this: \(note)") }
        return parts.joined(separator: ". ")
    }
}

/// The highlighted row for the batter at the plate now: "At bat · Kowalski · Ball, strike ·
/// count 1–1". It is not an event, so there is nothing to tap.
struct CurrentAtBatRow: View {
    var atBat: CurrentAtBat

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("At bat")
                .font(ScorebookFont.chip)
                .foregroundStyle(ScorebookColor.onOurTeam)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(ScorebookColor.ourTeam, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .fixedSize()
                .frame(minWidth: 58)
            VStack(alignment: .leading, spacing: 2) {
                Text(atBat.batter).font(ScorebookFont.body.weight(.semibold))
                Text(atBat.summary)
                    .font(ScorebookFont.caption)
                    .foregroundStyle(ScorebookColor.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, 10)
        .background(ScorebookColor.ourTeamSoft)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("At bat: \(atBat.batter). \(atBat.summary)")
    }
}
