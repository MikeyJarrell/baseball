// Step one of six: the opponent, the date, home or away, innings, the scheduled start and
// the time limit as a clock time. Saved opponents are one tap; a new one gets a name typed in.
// The start and the time limit are set on the iOS time wheel, to any minute (1:03 PM): tapping
// either time opens its wheel under it. The limit starts three hours after the start and moves
// with it.

import SwiftUI
import Model
import DesignSystem

/// The first pregame step: who we play and when.
struct GameStep: View {
    @Binding var draft: PregameDraft
    var onCancel: () -> Void
    var onNext: () -> Void

    @FocusState private var nameFocused: Bool
    /// Which time wheel is open, if any.
    @State private var openWheel: Wheel?
    @Environment(\.dynamicTypeSize) private var typeSize

    /// The two times set on a wheel.
    private enum Wheel { case start, limit }

    var body: some View {
        StepPage(step: 1, title: "New game", buttonTitle: "Next: batting order",
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
                timeRow("Start", time: draft.details.scheduledStart(), wheel: .start)
                if openWheel == .start {
                    timeWheel("Start", Binding(get: { draft.details.scheduledStart() },
                                               set: { draft.details.setStart($0) }))
                }
                timeRow("Time limit", time: draft.details.timeLimitEnd(), wheel: .limit)
                if openWheel == .limit {
                    timeWheel("Time limit", Binding(get: { draft.details.timeLimitEnd() },
                                                    set: { draft.details.setTimeLimitEnd($0) }))
                }
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
                Text("A late first pitch moves the time limit later by the same amount.")
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

    /// "Start   9:00 AM": tapping it opens or closes its time wheel.
    private func timeRow(_ label: String, time: Date, wheel: Wheel) -> some View {
        Button {
            withAnimation { openWheel = openWheel == wheel ? nil : wheel }
        } label: {
            // At the largest text sizes the label sits above the time, so "12:00 PM" never wraps.
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.extraSmall))
                : AnyLayout(HStackLayout())
            layout {
                Text(label).font(ScorebookFont.body).foregroundStyle(ScorebookColor.textPrimary)
                if !typeSize.isAccessibilitySize { Spacer() }
                Text(PregameWording.clock(time))
                    .lineLimit(1)
                    .fixedSize()
                    .font(ScorebookFont.headline.monospacedDigit())
                    .foregroundStyle(openWheel == wheel ? ScorebookColor.highlight : ScorebookColor.textPrimary)
                    .padding(.horizontal, Spacing.medium)
                    .padding(.vertical, Spacing.small)
                    .background(ScorebookColor.surfaceSecondary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(Text(PregameWording.clock(time)))
        .accessibilityHint(Text(openWheel == wheel ? "Closes the time wheel" : "Opens the time wheel"))
        .cardRow()
    }

    /// The iOS time wheel, every minute.
    private func timeWheel(_ label: String, _ time: Binding<Date>) -> some View {
        DatePicker(label, selection: time, displayedComponents: .hourAndMinute)
            .datePickerStyle(.wheel)
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .cardRow()
    }
}
