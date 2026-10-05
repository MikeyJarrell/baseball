// FixPlaySheet: the "Fix a play" sheet that opens when the scorer taps a row of the
// play-by-play (SHEETS.playedit in the approved mockup).
//
// It offers what fits the event:
//   - a plain pitch can be changed on the spot to another kind of pitch (a ball that was
//     really a foul), which hands back the same event with the new pitch;
//   - anything with more to it (a ball in play, a runner move, a substitution) asks the app
//     to open that event's own steps filled in;
//   - anything can be deleted, after one "Are you sure?".
// The sheet never changes the game itself: it hands back the request, the app applies it,
// and the rules engine works out everything after it again.

import SwiftUI
import Model
import DesignSystem

// MARK: - What each event can do

/// The choices the "Fix a play" sheet offers for one event. Plain functions, so tests can
/// check them.
public enum FixPlay {
    /// The other pitches a pitch can be changed to, in button order. Empty for anything
    /// that is not a plain pitch (a dropped third strike goes to its own steps instead).
    public static func pitchAlternatives(for event: GameEvent) -> [PitchResult] {
        guard case .pitch(let pitch) = event.kind, pitch.droppedThirdStrike == nil else { return [] }
        return PitchResult.allCases.filter { $0 != pitch.result }
    }

    /// The same event with a different pitch: same id and same time, so it takes the old
    /// one's place in the list.
    public static func replacing(_ event: GameEvent, with result: PitchResult) -> GameEvent {
        GameEvent(id: event.id, enteredAt: event.enteredAt, kind: .pitch(Pitch(result)))
    }

    /// What "Change this play" opens, in words for the line under it, or nothing when the
    /// event has nothing to change beyond deleting it (a fielder check, an intentional walk).
    public static func editorDescription(for event: GameEvent) -> String? {
        switch event.kind {
        case .pitch(let pitch):
            return pitch.droppedThirdStrike == nil ? nil : "Dropped third strike steps"
        case .ballInPlay: return "In-play steps"
        case .runnerAction: return "Runner moves"
        case .errorWithNoAdvance: return "Error"
        case .substitution, .runnerForNonRunner, .pitchingChange, .addHitter:
            return "The change"
        case .timeLimitChange: return "Time limit"
        case .manualAdjustment: return "Manual adjustment"
        case .intentionalWalk, .defenseConfirmed, .battingHole, .automaticOut, .keepPlaying, .endOfGame:
            return nil
        }
    }
}

extension String {
    /// The same words with the first letter in capitals.
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}

// MARK: - The sheet

/// The "Fix a play" sheet for one row of the play-by-play. Public so the app can also open it
/// for a play shown somewhere else; make the row with `PlayByPlay.rows(for:)`.
public struct FixPlaySheet: View {
    public var row: PlayRow
    /// Called with the scorer's choice; the sheet closes itself afterward.
    public var onAction: (GameOverviewAction) -> Void

    public init(row: PlayRow, onAction: @escaping (GameOverviewAction) -> Void) {
        self.row = row
        self.onAction = onAction
    }

    @Environment(\.dismiss) private var dismiss
    @State private var askingToDelete = false

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.medium) {
                    summary
                    pitchChoices
                    actions
                }
                .padding(Spacing.large)
            }
            .background(ScorebookColor.background)
            .navigationTitle("Fix a play")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    /// The question before deleting, naming the play and its half-inning: "Delete “Cole stole
    /// second” (Bottom 5th)?"
    var deleteQuestion: String {
        "Delete “\(row.text)” (\(OverviewWording.halfInning(row.half, row.inning)))?"
    }

    /// The play being fixed, as it appears in the list, with its half-inning.
    private var summary: some View {
        HStack(alignment: .top, spacing: Spacing.medium) {
            if !row.notation.isEmpty {
                NotationChip(text: row.notation, isHit: row.isHit)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(row.text).font(ScorebookFont.headline)
                Text(where_)
                    .font(ScorebookFont.caption)
                    .foregroundStyle(ScorebookColor.textSecondary)
                if !row.earlierPitches.isEmpty {
                    // The pitches before this one in the same plate appearance. Each can be
                    // fixed on its own row once "Show every pitch" is on.
                    Text("Earlier pitches to \(row.batter ?? "this batter"): \(row.earlierPitches.joined(separator: ", ").lowercased().capitalizedFirst)")
                        .font(ScorebookFont.caption)
                        .foregroundStyle(ScorebookColor.textSecondary)
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    /// Where the play happened: "Bottom 5th", and for a pitch the batter and the count:
    /// "Bottom 5th · to Webb · count 1–0 before it, 2–0 after".
    private var where_: String {
        var parts = [OverviewWording.halfInning(row.half, row.inning)]
        if row.isPitch {
            if let batter = row.batter { parts.append("to \(batter)") }
            // A pitch that ended the plate appearance has no count after it worth showing.
            parts.append(row.endedPlateAppearance
                ? "count \(OverviewWording.count(row.countBefore)) before it, ended the plate appearance"
                : "count \(OverviewWording.count(row.countBefore)) before it, \(OverviewWording.count(row.countAfter)) after")
        }
        return parts.joined(separator: " · ")
    }

    /// For a plain pitch: a button for every other kind of pitch.
    @ViewBuilder private var pitchChoices: some View {
        let choices = FixPlay.pitchAlternatives(for: row.event)
        if !choices.isEmpty {
            Text("IT WAS REALLY")
                .font(ScorebookFont.sectionLabel)
                .foregroundStyle(ScorebookColor.textSecondary)
                .padding(.top, Spacing.small)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: Spacing.small)], spacing: Spacing.small) {
                ForEach(choices, id: \.self) { choice in
                    Button {
                        finish(.edit(.replace(FixPlay.replacing(row.event, with: choice))))
                    } label: {
                        Text(choice.label.prefix(1).uppercased() + choice.label.dropFirst())
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PlainActionButtonStyle())
                }
            }
        }
    }

    /// "Change this play" (when there is something to change) and "Delete it".
    private var actions: some View {
        VStack(spacing: 0) {
            if let opens = FixPlay.editorDescription(for: row.event) {
                Button {
                    finish(.openEditor(row.event))
                } label: {
                    actionRow(icon: "pencil", title: "Change this play", subtitle: opens, color: ScorebookColor.textPrimary)
                }
                Divider().overlay(ScorebookColor.divider)
            }
            Button {
                askingToDelete = true
            } label: {
                actionRow(icon: "trash", title: "Delete it", subtitle: row.deleteEffect, color: ScorebookColor.out)
            }
            // The question hangs off the Delete button itself. "Keep it" has no cancel role,
            // so it shows as a button even where iOS hides cancel buttons in a pop-over.
            .confirmationDialog(deleteQuestion, isPresented: $askingToDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { finish(.edit(.delete(row.event.id))) }
                Button("Keep it") { askingToDelete = false }
            } message: {
                Text(row.deleteEffect)
            }
        }
        .buttonStyle(.plain)
        .background(ScorebookColor.surface, in: RoundedRectangle(cornerRadius: Spacing.cornerRadius, style: .continuous))
    }

    /// One tappable row in the actions card.
    private func actionRow(icon: String, title: String, subtitle: String?, color: Color) -> some View {
        HStack(spacing: Spacing.medium) {
            Image(systemName: icon).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(ScorebookFont.headline)
                if let subtitle {
                    Text(subtitle).font(ScorebookFont.caption).foregroundStyle(ScorebookColor.textSecondary)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").foregroundStyle(ScorebookColor.textSecondary)
        }
        .foregroundStyle(color)
        .padding(.horizontal, Spacing.medium)
        .frame(minHeight: Spacing.minimumTapSize + 12)
        .contentShape(Rectangle())
    }

    /// Hands back the choice and closes the sheet.
    private func finish(_ action: GameOverviewAction) {
        onAction(action)
        dismiss()
    }
}
