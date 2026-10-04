// Step one of five: the opponent, the date, home or away, innings, the scheduled start and
// the time limit as a clock time. Saved opponents are one tap; a new one gets a name typed in.

import SwiftUI
import Model
import DesignSystem

/// The first pregame step: who we play and when.
struct GameStep: View {
    @Binding var draft: PregameDraft
    var onCancel: () -> Void
    var onNext: () -> Void

    @FocusState private var nameFocused: Bool

    var body: some View {
        StepPage(step: 1, title: "New game", buttonTitle: "Next: our lineup",
                 blockedReason: draft.opponentChoice == nil ? "Pick an opponent first." : nil,
                 onButton: onNext) {
            Section {
                ForEach(draft.input.opponents) { team in
                    ChoiceRow(title: team.name, detail: PregameWording.rosterSummary(team),
                              isOn: draft.opponentChoice == .saved(team.id),
                              action: { draft.chooseOpponent(.saved(team.id)) }) {
                        PlayerNumberBadge(String(team.name.prefix(1)), look: .theirs, size: 36)
                            .accessibilityHidden(true)
                    }
                    .cardRow()
                }
                ChoiceRow(title: "New team", detail: nil, isOn: draft.opponentChoice == .new,
                          action: {
                              draft.chooseOpponent(.new)
                              nameFocused = true
                          }) {
                    IconBadge(systemName: "plus")
                }
                .cardRow()
                if draft.opponentChoice == .new {
                    TextField("Team name", text: $draft.newOpponentName)
                        .font(ScorebookFont.headline)
                        .textInputAutocapitalization(.words)
                        .focused($nameFocused)
                        .frame(minHeight: 44)
                        .cardRow()
                }
            } header: {
                SectionHeader(title: "Opponent")
            }

            Section {
                DatePicker("Date", selection: $draft.details.day, displayedComponents: .date)
                    .font(ScorebookFont.body)
                    .frame(minHeight: 44)
                    .cardRow()
                HStack {
                    Text("We are").font(ScorebookFont.body)
                    Spacer()
                    Picker("We are", selection: $draft.details.weAreHome) {
                        Text("Home").tag(true)
                        Text("Away").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 190)
                }
                .frame(minHeight: 44)
                .cardRow()
                ValueStepper(label: "Innings", value: "\(draft.details.innings)",
                             onMinus: { draft.details.changeInnings(by: -1) },
                             onPlus: { draft.details.changeInnings(by: 1) })
                    .cardRow()
                ValueStepper(label: "Start", value: PregameWording.clock(draft.details.scheduledStart()),
                             minusLabel: "Earlier", plusLabel: "Later",
                             onMinus: { draft.details.moveStart(by: -15) },
                             onPlus: { draft.details.moveStart(by: 15) })
                    .cardRow()
                ValueStepper(label: "Time limit", value: PregameWording.clock(draft.details.timeLimitEnd()),
                             minusLabel: "Earlier", plusLabel: "Later",
                             onMinus: { draft.details.moveTimeLimit(by: -5) },
                             onPlus: { draft.details.moveTimeLimit(by: 5) })
                    .cardRow()
                Toggle(isOn: Binding(get: { draft.details.isChampionship },
                                     set: { draft.details.setChampionship($0) })) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Championship game").font(ScorebookFont.body)
                        Text("3 hours 15 minutes, 15-run rule").font(ScorebookFont.caption)
                            .foregroundStyle(ScorebookColor.textSecondary)
                    }
                }
                .tint(ScorebookColor.highlight)
                .frame(minHeight: 44)
                .cardRow()
            } header: {
                SectionHeader(title: "Game")
            } footer: {
                Text("No new inning starts after the time limit. It starts three hours after the scheduled start and moves to three hours after the first pitch. The plate umpire keeps the official time, so it stays editable during the game. The app keeps the time from the start to the limit, so a late first pitch moves the limit later by the same amount (league rule 9.1 G).")
                    .font(ScorebookFont.caption)
                    .foregroundStyle(ScorebookColor.textSecondary)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel", action: onCancel)
            }
        }
    }
}
