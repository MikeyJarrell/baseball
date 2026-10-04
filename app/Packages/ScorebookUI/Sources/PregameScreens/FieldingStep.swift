// Step three of six: where our players field.
//
// The field drawing shows each position with who plays it. Tapping a position on the diamond
// (or its row in the list under it) opens a list of our whole roster: pick who plays there.
// Picking someone already fielding swaps the two. Anyone can field, whether or not they bat,
// so a pitcher who does not hit is just a fielder who is not in the batting order. Under the
// players, "Alternate with…" shares the position by turns: the starter plays odd innings and
// the player picked plays even ones.

import SwiftUI
import Model
import DesignSystem

/// The third pregame step: our fielders, on the field drawing.
struct FieldingStep: View {
    @Binding var draft: PregameDraft
    var onNext: () -> Void

    /// The position whose player list is open.
    @State private var picking: PickedPosition?

    private var lineup: OurLineup { draft.ours }

    var body: some View {
        StepPage(step: 3, title: "Fielders", buttonTitle: "Next: \(draft.opponentName) lineup", onButton: onNext) {
            Section {
                FieldDrawing(highlightedPositions: picking.map { [$0.position] } ?? [], onTap: { tap in
                    if case .position(let position) = tap { picking = PickedPosition(position: position) }
                })
                .fielderNames(fielderNames)
                .frame(height: 330)
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)   // VoiceOver uses the list of positions below instead
                .bareRow()
                Text("Tap a position to pick who plays it. Anyone can field, whether or not they bat.")
                    .font(ScorebookFont.caption)
                    .foregroundStyle(ScorebookColor.textSecondary)
                    .bareRow()
            }
            Section {
                ForEach(Position.allCases, id: \.self) { position in
                    positionRow(position).cardRow()
                }
            } header: {
                SectionHeader(title: "Fielders")
            }
        }
        .sheet(item: $picking) { picked in
            FielderPicker(draft: $draft, position: picked.position) { picking = nil }
                .presentationDetents([.medium, .large])
        }
    }

    /// The short name written under each position on the drawing: "Quinn", or "Quinn/Nash" for
    /// a position shared by turns.
    private var fielderNames: [Position: String] {
        var names: [Position: String] = [:]
        for (position, id) in lineup.defense {
            guard let starter = lineup.player(id) else { continue }
            let second = lineup.alternates[position].flatMap(lineup.player)
            names[position] = second.map { "\(starter.lastName)/\($0.lastName)" } ?? starter.lastName
        }
        return names
    }

    /// One position in the list under the drawing: its number, who plays it, whether they bat.
    private func positionRow(_ position: Position) -> some View {
        let starter = lineup.defense[position].flatMap(lineup.player)
        let second = lineup.alternates[position].flatMap(lineup.player)
        var detail = PregameWording.positionName(position)
        if let starter, !lineup.isBatting(starter.id) { detail += " · doesn’t bat" }
        if let second { detail += " · \(second.lastName) in even innings" }
        return Button {
            picking = PickedPosition(position: position)
        } label: {
            HStack(spacing: Spacing.medium) {
                PositionCircle(position: position)
                VStack(alignment: .leading, spacing: 2) {
                    if let starter {
                        Text(second == nil ? starter.displayName : "\(starter.lastName) / \(second?.lastName ?? "")")
                            .font(ScorebookFont.headline)
                    } else {
                        Text("Nobody").font(ScorebookFont.headline).foregroundStyle(ScorebookColor.out)
                    }
                    Text(detail).font(ScorebookFont.caption).foregroundStyle(ScorebookColor.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .foregroundStyle(ScorebookColor.textSecondary)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("Pick who plays \(position.name)"))
    }
}

/// A position picked on the drawing, so the player list can open as a sheet.
struct PickedPosition: Identifiable, Equatable {
    var position: Position
    var id: Int { position.rawValue }
}

/// The list that slides up when a position is tapped: who plays it, and who alternates with
/// them by inning. Each pick closes the list.
struct FielderPicker: View {
    @Binding var draft: PregameDraft
    var position: Position
    var onDone: () -> Void

    private var lineup: OurLineup { draft.ours }

    var body: some View {
        let starter = lineup.defense[position]
        NavigationStack {
            List {
                Section {
                    ForEach(lineup.roster) { player in
                        playerRow(player, isOn: starter == player.id) {
                            draft.ours.assign(player.id, to: position)
                        }
                    }
                    if starter != nil {
                        ChoiceRow(title: "Nobody", detail: nil, isOn: false,
                                  action: { draft.ours.assign(nil, to: position); onDone() }) {
                            IconBadge(systemName: "xmark", tint: ScorebookColor.out)
                        }
                        .cardRow()
                    }
                } header: {
                    SectionHeader(title: "Who plays \(position.name)?")
                }

                if let starter, let starterPlayer = lineup.player(starter) {
                    Section {
                        ChoiceRow(title: "Nobody else", detail: "\(starterPlayer.lastName) plays every inning",
                                  isOn: lineup.alternates[position] == nil,
                                  action: { draft.ours.setAlternate(nil, at: position); onDone() }) { EmptyView() }
                            .cardRow()
                        ForEach(lineup.roster.filter { $0.id != starter }) { player in
                            playerRow(player, isOn: lineup.alternates[position] == player.id) {
                                draft.ours.setAlternate(player.id, at: position)
                            }
                        }
                    } header: {
                        SectionHeader(title: "Alternate with…")
                    } footer: {
                        Text("\(starterPlayer.lastName) plays \(position.name) in odd innings and the player you pick plays it in even innings. The defense check offers the right one each time we take the field.")
                            .font(ScorebookFont.caption)
                            .foregroundStyle(ScorebookColor.textSecondary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(ScorebookColor.background)
            .navigationTitle(PregameWording.positionName(position))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done", action: onDone) }
            }
        }
    }

    /// One of our players: number badge, name, where they are now, and the round mark.
    private func playerRow(_ player: Player, isOn: Bool, pick: @escaping () -> Void) -> some View {
        ChoiceRow(title: player.displayName, detail: PregameWording.status(of: player.id, in: lineup), isOn: isOn,
                  action: { pick(); onDone() }) {
            PlayerNumberBadge(PregameWording.badge(player), look: .ours, size: 36).accessibilityHidden(true)
        }
        .cardRow()
    }
}
