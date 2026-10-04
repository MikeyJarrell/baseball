// Step five of six: each team's starting pitcher, with throwing hand.
//
// Ours lists the roster with whoever pitched most recently first. Picking someone puts them at
// position 1; if they were fielding somewhere else, the old pitcher takes that position (the
// same swap as on the fielders list). Theirs lists anyone who has pitched against us first,
// then the rest of their lineup and roster, "Not known yet", and "Someone new" (number, name
// and throwing hand). A pitcher whose throwing hand is unknown can have it set here.

import SwiftUI
import Model
import DesignSystem

/// The fifth pregame step: starting pitchers.
struct PitchersStep: View {
    @Binding var draft: PregameDraft
    var onNext: () -> Void

    /// Whether the "Someone new" form is open, and what has been typed in it.
    @State private var newOpen = false
    @State private var newNumber = ""
    @State private var newName = ""
    @State private var newHand: Hand?

    var body: some View {
        StepPage(step: 5, title: "Starting pitchers", buttonTitle: "Next: review", onButton: onNext) {
            Section {
                ForEach(draft.ourPitcherChoices) { choice in
                    pitcherRow(choice, look: .ours,
                               line: PregameWording.ourPitcherLine(choice.lastPitched, lastGame: draft.input.lastGame?.scheduledStart),
                               isOn: draft.ourPitcher == choice.id) {
                        draft.ours.assign(choice.id, to: .pitcher)
                    }
                }
            } header: {
                SectionHeader(title: draft.input.ourTeam.name)
            }

            Section {
                ForEach(draft.theirPitcherChoices) { choice in
                    pitcherRow(choice, look: .theirs, line: PregameWording.theirPitcherLine(choice.lastPitched),
                               isOn: draft.theirs.pitcher == choice.id) {
                        draft.theirs.pitcher = choice.id
                    }
                }
                ChoiceRow(title: "Not known yet", detail: "Name them when you find out",
                          isOn: theirPitcherUnknown, action: { draft.theirs.pitcher = nil }) {
                    PlayerNumberBadge("?", look: .theirs, size: 36).accessibilityHidden(true)
                }
                .cardRow()
                AddRow(title: "Someone new", systemImage: newOpen ? "xmark" : "plus") { newOpen.toggle() }
                    .cardRow()
                if newOpen { newPitcherForm.cardRow() }
            } header: {
                SectionHeader(title: "\(draft.opponentName) · from their saved roster")
            }
        }
    }

    /// True when their pitcher is not picked, or is someone no longer in their lineup.
    private var theirPitcherUnknown: Bool {
        guard let id = draft.theirs.pitcher else { return true }
        return !draft.theirPitcherChoices.contains { $0.id == id }
    }

    /// One pitcher: number badge, name, when they last pitched and which hand they throw with,
    /// and the round mark. A chosen pitcher with no known hand gets Right and Left buttons.
    private func pitcherRow(_ choice: PitcherChoice, look: TeamLook, line: String, isOn: Bool,
                            action: @escaping () -> Void) -> some View {
        let player = draft.player(choice.id) ?? choice.player
        let detail = [line, PregameWording.throwsLine(player.throwsWith)].compactMap { $0 }.joined(separator: " · ")
        return VStack(alignment: .leading, spacing: Spacing.small) {
            ChoiceRow(title: player.displayName, detail: detail, isOn: isOn, action: action) {
                PlayerNumberBadge(PregameWording.badge(player), look: look, size: 36).accessibilityHidden(true)
            }
            if isOn, choice.player.throwsWith == nil {
                HStack(spacing: Spacing.small) {
                    Text("Throws").font(ScorebookFont.caption).foregroundStyle(ScorebookColor.textSecondary)
                    ForEach(Hand.allCases, id: \.self) { hand in
                        Button(hand == .right ? "Right" : "Left") { draft.handEdits[choice.id] = hand }
                            .buttonStyle(ChipStyle(isOn: draft.handEdits[choice.id] == hand))
                    }
                }
                .padding(.leading, 36 + Spacing.medium)
            }
        }
        .cardRow()
    }

    /// Number, name and throwing hand for a pitcher not on their roster.
    private var newPitcherForm: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            HStack(spacing: Spacing.small) {
                TextField("Number", text: $newNumber)
                    .keyboardType(.numberPad)
                    .frame(width: 90)
                TextField("Name (optional)", text: $newName)
                    .textInputAutocapitalization(.words)
            }
            .font(ScorebookFont.headline)
            .textFieldStyle(.roundedBorder)
            HStack(spacing: Spacing.small) {
                Text("Throws").font(ScorebookFont.caption).foregroundStyle(ScorebookColor.textSecondary)
                ForEach(Hand.allCases, id: \.self) { hand in
                    Button(hand == .right ? "Right" : "Left") { newHand = newHand == hand ? nil : hand }
                        .buttonStyle(ChipStyle(isOn: newHand == hand))
                }
                Spacer()
                Button("Add") {
                    draft.theirs.pitcher = draft.theirs.addNewPlayer(name: newName, number: newNumber, throwsWith: newHand)
                    newOpen = false
                    newNumber = ""
                    newName = ""
                    newHand = nil
                }
                .buttonStyle(ChipStyle(isOn: true))
            }
        }
        .padding(.vertical, Spacing.extraSmall)
    }
}
