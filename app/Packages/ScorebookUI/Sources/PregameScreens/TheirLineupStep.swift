// Step three of five: their lineup, three ways in.
//
// - Names and numbers, from their saved roster: the batting order from the last game against
//   them (or their whole roster), dragged into order, with a minus to take someone out.
// - Numbers only: jersey numbers typed in batting order. A number that matches their saved
//   roster is that player, so names carry over.
// - Unknown: how many hitters they bat (nine by default), each a placeholder ("Batter 1") the
//   scorer names when that hitter comes up, so the order knows when to go back to the top.

import SwiftUI
import Model
import DesignSystem

/// The third pregame step: their batting order.
struct TheirLineupStep: View {
    @Binding var draft: PregameDraft
    var onNext: () -> Void

    /// Whether the "Add to batting order" chips are showing.
    @State private var addOpen = false
    /// The number field being typed in.
    @FocusState private var focusedNumber: PlayerID?

    private var team: Team { draft.opponent ?? Team(id: draft.newOpponentID, name: "Opponent") }
    private var theirs: TheirLineup { draft.theirs }
    private var hasNames: Bool { team.roster.contains { !($0.name ?? "").isEmpty } }

    var body: some View {
        StepPage(step: 3, title: "\(team.name) lineup", buttonTitle: "Next: starting pitchers",
                 blockedReason: theirs.battingOrder(for: team).isEmpty ? "Add at least one hitter." : nil,
                 onButton: onNext) {
            Section {
                modeRow(.names, "Names and numbers",
                        hasNames ? "From the saved \(team.name) roster" : "No saved names yet")
                    .disabled(!hasNames)
                    .opacity(hasNames ? 1 : 0.5)
                modeRow(.numbers, "Numbers only", "Type the numbers in batting order")
                modeRow(.unknown, "Unknown", "Fill them in as they come up")
            }
            switch theirs.mode {
            case .names: namesSection
            case .numbers: numbersSection
            case .unknown: unknownSection
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedNumber = nil }
            }
        }
    }

    /// One of the three ways in, as a choice row.
    private func modeRow(_ mode: TheirLineupMode, _ title: String, _ detail: String) -> some View {
        ChoiceRow(title: title, detail: detail, isOn: theirs.mode == mode,
                  action: { draft.theirs.mode = mode }) { EmptyView() }
            .cardRow()
    }

    // MARK: Names and numbers

    private var namesSection: some View {
        Section {
            ForEach(Array(theirs.namedOrder.enumerated()), id: \.element) { index, id in
                if let player = team.player(id) {
                    HStack(spacing: Spacing.small) {
                        OrderNumber(spot: index + 1)
                        Grip()
                        PlayerNumberBadge(PregameWording.badge(player), look: .theirs, size: 34)
                        Group {
                            if let name = player.name, !name.isEmpty {
                                Text(name)
                            } else {
                                Text("Name unknown").foregroundStyle(ScorebookColor.textSecondary)
                            }
                        }
                        .font(ScorebookFont.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        RemoveButton(label: "Take \(player.displayName) out of their batting order") {
                            draft.theirs.namedOrder.removeAll { $0 == id }
                        }
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityAction(named: Text("Move up")) { move(id, by: -1) }
                    .accessibilityAction(named: Text("Move down")) { move(id, by: 1) }
                    .cardRow()
                }
            }
            .onMove { draft.theirs.namedOrder.move(fromOffsets: $0, toOffset: $1) }

            let notBatting = team.roster.filter { !theirs.namedOrder.contains($0.id) }
            if !notBatting.isEmpty {
                AddRow(title: "Add to batting order", systemImage: addOpen ? "xmark" : "plus") { addOpen.toggle() }
                    .cardRow()
                    .moveDisabled(true)
                if addOpen {
                    FlowLayout {
                        ForEach(notBatting) { player in
                            Button(PregameWording.theirHitter(player)) { draft.theirs.addToNamedOrder(player.id) }
                                .buttonStyle(ChipStyle())
                        }
                    }
                    .cardRow()
                    .moveDisabled(true)
                }
            }
        } header: {
            SectionHeader(title: "Batting order · \(theirs.battingOrder(for: team).count)")
        }
    }

    /// Moves one of their named hitters up or down a spot, for VoiceOver.
    private func move(_ id: PlayerID, by step: Int) {
        guard let from = draft.theirs.namedOrder.firstIndex(of: id),
              draft.theirs.namedOrder.indices.contains(from + step) else { return }
        draft.theirs.namedOrder.swapAt(from, from + step)
    }

    // MARK: Numbers only

    private var numbersSection: some View {
        Section {
            ForEach(Array(theirs.numbers.enumerated()), id: \.element.id) { index, entry in
                HStack(spacing: Spacing.small) {
                    OrderNumber(spot: index + 1)
                    Grip()
                    Text("#").font(ScorebookFont.headline).foregroundStyle(ScorebookColor.textSecondary)
                    TextField("Number", text: numberBinding(entry.id))
                        .font(ScorebookFont.headline.monospacedDigit())
                        .keyboardType(.numberPad)
                        .focused($focusedNumber, equals: entry.id)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityLabel(Text("Number for hitter \(index + 1)"))
                    if let saved = matchedName(entry) {
                        Text(saved)
                            .font(ScorebookFont.caption)
                            .foregroundStyle(ScorebookColor.textSecondary)
                            .lineLimit(1)
                    }
                    RemoveButton(label: "Take hitter \(index + 1) out of their batting order") {
                        draft.theirs.numbers.removeAll { $0.id == entry.id }
                    }
                }
                .frame(minHeight: 44)
                .cardRow()
            }
            .onMove { draft.theirs.numbers.move(fromOffsets: $0, toOffset: $1) }

            AddRow(title: "Add a hitter") {
                draft.theirs.addNumber()
                focusedNumber = draft.theirs.numbers.last?.id
            }
            .cardRow()
            .moveDisabled(true)
        } header: {
            SectionHeader(title: "Batting order · \(theirs.numbers.count)")
        } footer: {
            Text("A blank number becomes “Batter 4” until you name them.")
                .font(ScorebookFont.caption)
                .foregroundStyle(ScorebookColor.textSecondary)
        }
    }

    /// The text of one number field.
    private func numberBinding(_ id: PlayerID) -> Binding<String> {
        Binding(
            get: { draft.theirs.numbers.first { $0.id == id }?.number ?? "" },
            set: { text in
                guard let i = draft.theirs.numbers.firstIndex(where: { $0.id == id }) else { return }
                draft.theirs.numbers[i].number = String(text.filter(\.isNumber).prefix(3))
            }
        )
    }

    /// The saved player a typed number matches, if any: "Marcus Hale".
    private func matchedName(_ entry: NumberEntry) -> String? {
        guard !entry.number.isEmpty else { return nil }
        return team.roster.first { $0.number == entry.number }?.name
    }

    // MARK: Unknown

    private var unknownSection: some View {
        Section {
            ValueStepper(label: "How many hitters?", value: "\(theirs.unknownCount)",
                         onMinus: { draft.theirs.setUnknownCount(theirs.unknownCount - 1) },
                         onPlus: { draft.theirs.setUnknownCount(theirs.unknownCount + 1) })
                .cardRow()
            FlowLayout {
                ForEach(1...theirs.unknownCount, id: \.self) { n in
                    Text("Batter \(n)")
                        .font(ScorebookFont.chip)
                        .padding(.horizontal, Spacing.medium)
                        .frame(minHeight: 32)
                        .background(TeamBackground(.theirs).clipShape(Capsule()))
                        .foregroundStyle(TeamLook.theirs.onFill)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Batter 1 to Batter \(theirs.unknownCount)"))
            .cardRow()
        } header: {
            SectionHeader(title: "Batting order")
        } footer: {
            Text("Each one gets a name or number when they come up, so the order knows when to go back to the top.")
                .font(ScorebookFont.caption)
                .foregroundStyle(ScorebookColor.textSecondary)
        }
    }
}
