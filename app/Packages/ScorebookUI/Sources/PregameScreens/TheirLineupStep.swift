// Step four of six: their lineup, two ways in.
//
// - Names and numbers, from their saved roster: the batting order from the last game against
//   them (or their whole roster), dragged into order, with a minus to take someone out. Each
//   row has the player's jersey number as a box to type in; tapping the name types in it too.
// - Numbers only: jersey numbers typed in batting order. A number that matches their saved
//   roster is that player, so names carry over; a blank is "Batter 4" until named.
//
// Numbers typed here are saved back to that opponent's roster after "Play ball".

import SwiftUI
import Model
import DesignSystem

/// The fourth pregame step: their batting order.
struct TheirLineupStep: View {
    @Binding var draft: PregameDraft
    var onNext: () -> Void

    /// Whether the "Add to batting order" chips are showing.
    @State private var addOpen = false
    /// The number box being typed in: a saved player's id, or a numbers-only entry's id.
    @FocusState private var focusedNumber: PlayerID?
    @Environment(\.dynamicTypeSize) private var typeSize

    private var team: Team { draft.opponent ?? Team(id: draft.newOpponentID, name: "Opponent") }
    private var theirs: TheirLineup { draft.theirs }
    private var hasNames: Bool { team.roster.contains { !($0.name ?? "").isEmpty } }

    var body: some View {
        StepPage(step: 4, title: "\(team.name) lineup", buttonTitle: "Next: starting pitchers",
                 blockedReason: theirs.battingOrder(for: team).isEmpty ? "Add at least one hitter." : nil,
                 hidesButton: focusedNumber != nil,
                 onButton: onNext) {
            Section {
                modeRow(.names, "Names and numbers",
                        hasNames ? "From the saved \(team.name) roster" : "No saved names yet")
                    .disabled(!hasNames)
                    .opacity(hasNames ? 1 : 0.5)
                modeRow(.numbers, "Numbers only", nil)
            }
            switch theirs.mode {
            case .names: namesSection
            case .numbers: numbersSection
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedNumber = nil }
            }
        }
    }

    /// One of the two ways in, as a choice row.
    private func modeRow(_ mode: TheirLineupMode, _ title: String, _ detail: String?) -> some View {
        ChoiceRow(title: title, detail: detail, isOn: theirs.mode == mode,
                  action: { draft.theirs.mode = mode }) { EmptyView() }
            .cardRow()
    }

    /// A box for a jersey number: digits only, with the number pad.
    private func numberBox(_ text: Binding<String>, focus id: PlayerID, label: String) -> some View {
        HStack(spacing: 2) {
            Text("#").foregroundStyle(ScorebookColor.textSecondary)
            TextField("No.", text: text)
                .keyboardType(.numberPad)
                .focused($focusedNumber, equals: id)
                .accessibilityLabel(Text(label))
        }
        .font(ScorebookFont.headline.monospacedDigit())
        .padding(.horizontal, Spacing.small)
        // Wider at the largest text sizes, where the box has a line of its own.
        .frame(width: typeSize.isAccessibilitySize ? 150 : 76)
        .frame(minHeight: 40)
        .background(ScorebookColor.surfaceSecondary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: Names and numbers

    private var namesSection: some View {
        Section {
            ForEach(Array(theirs.namedOrder.enumerated()), id: \.element) { index, id in
                if let player = team.player(id) {
                    let box = numberBox(Binding(get: { theirs.numberEdits[id] ?? player.number ?? "" },
                                                set: { draft.theirs.setNumber($0, for: id) }),
                                        focus: id, label: "Number for \(player.displayName)")
                    let remove = RemoveButton(label: "Take \(player.displayName) out of their batting order") {
                        draft.theirs.namedOrder.removeAll { $0 == id }
                    }
                    // Tapping the name types in the number box too.
                    let name = Button { focusedNumber = id } label: {
                        Group {
                            if let name = player.name, !name.isEmpty {
                                Text(name)
                            } else {
                                Text("Name unknown").foregroundStyle(ScorebookColor.textSecondary)
                            }
                        }
                        .font(ScorebookFont.headline)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(Text("Type their number"))
                    HStack(spacing: Spacing.small) {
                        OrderNumber(spot: index + 1)
                        // At the largest text sizes the name gets its own line, with the number
                        // box and the minus button under it; the drag handle gives up its room.
                        if typeSize.isAccessibilitySize {
                            VStack(alignment: .leading, spacing: Spacing.extraSmall) {
                                name
                                HStack(spacing: Spacing.small) { box; remove }
                            }
                        } else {
                            Grip()
                            box
                            name
                            remove
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
        } footer: {
            Text("Hold a row and drag to reorder.")
                .font(ScorebookFont.caption)
                .foregroundStyle(ScorebookColor.textSecondary)
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
                let box = numberBox(Binding(get: { draft.theirs.numbers.first { $0.id == entry.id }?.number ?? "" },
                                            set: { draft.theirs.setNumber($0, forEntry: entry.id) }),
                                    focus: entry.id, label: "Number for hitter \(index + 1)")
                let remove = RemoveButton(label: "Take hitter \(index + 1) out of their batting order") {
                    draft.theirs.numbers.removeAll { $0.id == entry.id }
                }
                let name = Button { focusedNumber = entry.id } label: {
                    Text(matchedName(entry) ?? (entry.number.isEmpty ? "Batter \(index + 1)" : ""))
                        .font(ScorebookFont.body)
                        .foregroundStyle(ScorebookColor.textSecondary)
                        .lineLimit(typeSize.isAccessibilitySize ? nil : 1)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                HStack(spacing: Spacing.small) {
                    OrderNumber(spot: index + 1)
                    // At the largest text sizes the number box and minus button get a line of
                    // their own, with the matched name under them.
                    if typeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: Spacing.extraSmall) {
                            HStack(spacing: Spacing.small) { box; remove }
                            name
                        }
                    } else {
                        Grip()
                        box
                        name
                        remove
                    }
                }
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
            Text("Hold a row and drag to reorder.")
                .font(ScorebookFont.caption)
                .foregroundStyle(ScorebookColor.textSecondary)
        }
    }

    /// The saved player a typed number matches, if any: "Marcus Hale".
    private func matchedName(_ entry: NumberEntry) -> String? {
        guard !entry.number.isEmpty else { return nil }
        return team.roster.first { $0.number == entry.number }?.name
    }
}
