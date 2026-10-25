// Step three of seven: our batting order. Who bats and in what order, the designated non-runners,
// and the bench. Where everyone fields is the next step, because hitters can skip the field and
// fielders can skip batting.
//
// - The batting order: any number of hitters, dragged into order (or moved with VoiceOver's
//   actions), a minus button to take someone out, and the non-runner switch. The league allows
//   two designated non-runners; the header says "1 of 2", and a third asks first, then is allowed.
// - "Add to batting order": chips of everyone not batting.
// - The bench: everyone who neither bats nor fields, each with a "Bat" button.

import SwiftUI
import Model
import DesignSystem

/// The third pregame step: our batting order and bench.
struct BattingOrderStep: View {
    @Binding var draft: PregameDraft
    var onNext: () -> Void

    /// Whether the "Add to batting order" chips are showing.
    @State private var addOpen = false
    /// A hitter waiting on the "past the league's limit" question.
    @State private var pendingNonRunner: PlayerID?
    @Environment(\.dynamicTypeSize) private var typeSize

    private var lineup: OurLineup { draft.ours }

    var body: some View {
        StepPage(step: .ours, title: "Batting order", buttonTitle: "Next: fielders",
                 blockedReason: lineup.battingOrder.isEmpty ? "Add at least one hitter." : nil,
                 onButton: onNext) {
            battingOrderSection
            benchSection
        }
        .confirmationDialog(pastLimitTitle, isPresented: Binding(get: { pendingNonRunner != nil },
                                                                 set: { if !$0 { pendingNonRunner = nil } }),
                            titleVisibility: .visible) {
            Button("Make them a non-runner anyway") {
                if let id = pendingNonRunner { draft.ours.setNonRunner(id, true) }
                pendingNonRunner = nil
            }
            Button("Cancel", role: .cancel) { pendingNonRunner = nil }
        } message: {
            Text("The league allows \(draft.nonRunnerLimit) designated non-runners.")
        }
    }

    /// The question asked before a third designated non-runner.
    private var pastLimitTitle: String {
        let name = pendingNonRunner.flatMap { lineup.player($0)?.displayName } ?? "This hitter"
        return "\(name) would be non-runner number \(lineup.nonRunners.count + 1)"
    }

    // MARK: The batting order

    private var battingOrderSection: some View {
        Section {
            ForEach(Array(lineup.battingOrder.enumerated()), id: \.element) { index, id in
                if let player = lineup.player(id) {
                    hitterRow(player, spot: index + 1)
                        .cardRow()
                }
            }
            .onMove { draft.ours.moveInOrder(fromOffsets: $0, toOffset: $1) }

            AddRow(title: "Add to batting order", systemImage: addOpen ? "xmark" : "plus") { addOpen.toggle() }
                .cardRow()
                .moveDisabled(true)
            if addOpen {
                Group {
                    if lineup.notBatting.isEmpty {
                        Text("Everyone is already batting.")
                            .font(ScorebookFont.body)
                            .foregroundStyle(ScorebookColor.textSecondary)
                    } else {
                        FlowLayout {
                            ForEach(lineup.notBatting) { player in
                                Button {
                                    draft.ours.addToOrder(player.id)
                                } label: {
                                    Text(player.lastName) + Text(chipPosition(player.id)).foregroundStyle(ScorebookColor.textSecondary)
                                }
                                .buttonStyle(ChipStyle())
                                .accessibilityLabel(Text("Add \(player.displayName) to the batting order"))
                            }
                        }
                    }
                }
                .cardRow()
                .moveDisabled(true)
            }
            NewPlayerRow { number, name in draft.ours.addNewPlayer(name: name, number: number) }
        } header: {
            SectionHeader(title: "Batting order · \(lineup.battingOrder.count)",
                          trailing: Text("Non-runners ") + Text("\(lineup.nonRunners.count) of \(draft.nonRunnerLimit)")
                            .bold()
                            .foregroundStyle(lineup.nonRunners.count > draft.nonRunnerLimit ? ScorebookColor.out : ScorebookColor.textPrimary))
        }
    }

    /// One hitter: spot, drag handle, name and number, where they field, the non-runner switch, minus.
    private func hitterRow(_ player: Player, spot: Int) -> some View {
        let isNonRunner = lineup.isNonRunner(player.id)
        // The name and where they field.
        let name = VStack(alignment: .leading, spacing: 2) {
            (Text(player.displayName) + Text(player.number.map { "  #\($0)" } ?? "").foregroundStyle(ScorebookColor.textSecondary))
                .font(ScorebookFont.headline)
            Text(PregameWording.fieldingLine(for: player.id, in: lineup))
                .font(ScorebookFont.caption)
                .foregroundStyle(ScorebookColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // The non-runner switch and the minus button.
        let buttons = HStack(spacing: Spacing.small) {
            Button(isNonRunner ? "Non-runner" : "Runs") { tapNonRunner(player.id) }
                .buttonStyle(ChipStyle(isOn: isNonRunner, onColor: ScorebookColor.sequenceBadge, onText: ScorebookColor.onStrike))
                .fixedSize()
                .accessibilityLabel(Text("Designated non-runner"))
                .accessibilityValue(Text(isNonRunner ? "On" : "Off"))
            RemoveButton(label: "Take \(player.displayName) out of the batting order") {
                draft.ours.removeFromOrder(player.id)
            }
        }
        return HStack(spacing: Spacing.small) {
            OrderNumber(spot: spot)
            // The drag handle gives its room to the name at the largest text sizes; rows still drag.
            if !typeSize.isAccessibilitySize { Grip() }
            // At the largest text sizes the name gets its own line, with the buttons under it.
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Spacing.extraSmall) {
                    name
                    buttons
                }
            } else {
                name
                buttons
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: Text("Move up")) { draft.ours.moveHitter(player.id, by: -1) }
        .accessibilityAction(named: Text("Move down")) { draft.ours.moveHitter(player.id, by: 1) }
    }

    /// Declares or undeclares a non-runner, asking first if it would pass the league's limit.
    private func tapNonRunner(_ id: PlayerID) {
        switch lineup.nonRunnerTap(for: id, limit: draft.nonRunnerLimit) {
        case .declare: draft.ours.setNonRunner(id, true)
        case .undeclare: draft.ours.setNonRunner(id, false)
        case .pastLimit: pendingNonRunner = id
        }
    }

    /// Where a player is now, after their name on a chip: " ss", " DH", " 1b even" (a
    /// turn in even innings only), or " bench" for someone who neither bats nor fields.
    private func chipPosition(_ id: PlayerID) -> String {
        if let position = lineup.position(of: id) { return " " + position.abbreviation }
        if let position = lineup.alternatePosition(of: id) { return " \(position.abbreviation) even" }
        if lineup.isBatting(id) { return " DH" }
        return " bench"
    }

    // MARK: The bench

    private var benchSection: some View {
        Section {
            if lineup.bench.isEmpty {
                Text("Everyone is batting or fielding.")
                    .font(ScorebookFont.body)
                    .foregroundStyle(ScorebookColor.textSecondary)
                    .cardRow()
            }
            ForEach(lineup.bench) { player in
                HStack(spacing: Spacing.medium) {
                    PlayerNumberBadge(PregameWording.badge(player), look: .ours, size: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(player.displayName).font(ScorebookFont.headline)
                        if let position = lineup.alternatePosition(of: player.id) {
                            Text("\(PregameWording.positionName(position)), even innings")
                                .font(ScorebookFont.caption)
                                .foregroundStyle(ScorebookColor.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Button {
                        draft.ours.addToOrder(player.id)
                    } label: {
                        Label("Bat", systemImage: "plus")
                    }
                    .buttonStyle(ChipStyle())
                    .accessibilityLabel(Text("Add \(player.displayName) to the batting order"))
                }
                .frame(minHeight: 44)
                .cardRow()
            }
        } header: {
            SectionHeader(title: "Bench")
        }
    }
}
