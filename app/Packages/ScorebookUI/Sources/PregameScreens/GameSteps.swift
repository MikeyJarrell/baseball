// The first four steps, one question on each screen, so nothing needs scrolling to find:
//
// 1. Who we play (`OpponentStep`). Saved opponents are one tap; a new one gets a name typed in.
// 2. Home or away (`HomeOrAwayStep`).
// 3. The date and the scheduled start (`WhenStep`), the start on the iOS time wheel, to any
//    minute (1:03 PM).
// 4. How long the game runs (`LengthStep`): innings, championship rules, and the time limit as
//    a clock time on the time wheel. The limit starts three hours after the start and moves
//    with it.

import SwiftUI
import Model
import DesignSystem

/// Step one: who we play.
struct OpponentStep: View {
    @Binding var draft: PregameDraft
    var onCancel: () -> Void
    var onNext: () -> Void

    @FocusState private var nameFocused: Bool

    var body: some View {
        StepPage(step: .opponent, title: "Opponent", buttonTitle: "Next: home or away",
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
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel", action: onCancel)
            }
        }
    }
}

/// Step two: whether we are the home team.
struct HomeOrAwayStep: View {
    @Binding var draft: PregameDraft
    var onNext: () -> Void

    var body: some View {
        StepPage(step: .homeOrAway, title: "Home or away", buttonTitle: "Next: date and start", onButton: onNext) {
            Section {
                ChoiceRow(title: "Home", detail: "We bat second", isOn: draft.details.weAreHome,
                          action: { draft.details.weAreHome = true }) { EmptyView() }
                    .cardRow()
                ChoiceRow(title: "Away", detail: "We bat first", isOn: !draft.details.weAreHome,
                          action: { draft.details.weAreHome = false }) { EmptyView() }
                    .cardRow()
            }
        }
    }
}

/// Step three: the day of the game and its scheduled start.
struct WhenStep: View {
    @Binding var draft: PregameDraft
    var onNext: () -> Void

    var body: some View {
        StepPage(step: .when, title: "Date and start", buttonTitle: "Next: game length", onButton: onNext) {
            Section {
                DatePicker("Date", selection: $draft.details.day, displayedComponents: .date)
                    .font(ScorebookFont.body)
                    .frame(minHeight: 44)
                    .cardRow()
            }
            Section {
                TimeWheel(label: "Start", time: Binding(get: { draft.details.scheduledStart() },
                                                        set: { draft.details.setStart($0) }))
            } header: {
                SectionHeader(title: "Start", trailing: Text(PregameWording.clock(draft.details.scheduledStart())))
            }
        }
    }
}

/// Step four: innings, championship rules and the time limit.
struct LengthStep: View {
    @Binding var draft: PregameDraft
    var onNext: () -> Void

    var body: some View {
        StepPage(step: .length, title: "Game length", buttonTitle: "Next: batting order", onButton: onNext) {
            Section {
                ValueStepper(label: "Innings", value: "\(draft.details.innings)",
                             onMinus: { draft.details.changeInnings(by: -1) },
                             onPlus: { draft.details.changeInnings(by: 1) })
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
            }
            Section {
                TimeWheel(label: "Time limit", time: Binding(get: { draft.details.timeLimitEnd() },
                                                             set: { draft.details.setTimeLimitEnd($0) }))
            } header: {
                SectionHeader(title: "Time limit", trailing: Text(PregameWording.clock(draft.details.timeLimitEnd())))
            } footer: {
                Text("A late first pitch moves the time limit later by the same amount.")
                    .font(ScorebookFont.caption)
                    .foregroundStyle(ScorebookColor.textSecondary)
            }
        }
    }
}

/// The iOS time wheel, every minute, as a card of its own.
private struct TimeWheel: View {
    var label: String
    @Binding var time: Date

    var body: some View {
        DatePicker(label, selection: $time, displayedComponents: .hourAndMinute)
            .datePickerStyle(.wheel)
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .cardRow()
    }
}
