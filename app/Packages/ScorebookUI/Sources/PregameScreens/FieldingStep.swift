// Where each team fields: ours (step four) and theirs, after their lineup. Both teams get the
// same screen; only ours has positions shared by turns.
//
// The field drawing shows each position with who plays it. Tapping a position on the diamond
// opens every player's name: pick who plays there.
// Picking someone already fielding swaps the two. Anyone can field, whether or not they bat,
// so a pitcher who does not hit is just a fielder who is not in the batting order. Under the
// players, "Alternate with…" shares the position by turns: the starter plays odd innings and
// the player picked plays even ones.

import SwiftUI
import Model
import DesignSystem

/// A fielders step, on the field drawing: ours, or theirs (`ours: false`).
struct FieldingStep: View {
    @Binding var draft: PregameDraft
    var ours: Bool = true
    var onNext: () -> Void

    /// The position whose player list is open.
    @State private var picking: PickedPosition?

    private var lineup: OurLineup { draft.ours }
    /// Who plays each position for this team.
    private var defense: [Position: PlayerID] { draft.fieldingDefense(ours: ours) }
    /// Looks up one of this team's players.
    private func player(_ id: PlayerID) -> Player? { draft.fieldingPlayers(ours: ours).first { $0.id == id } }

    var body: some View {
        StepPage(step: ours ? .fielding : .theirFielding,
                 title: ours ? "Fielders" : "\(draft.opponentName) fielders",
                 buttonTitle: ours ? "Next: \(draft.opponentName) lineup" : "Next: review", onButton: onNext) {
            Section {
                FieldDrawing(highlightedPositions: picking.map { [$0.position] } ?? [], onTap: { tap in
                    if case .position(let position) = tap { picking = PickedPosition(position: position) }
                })
                .fieldersAsNames(fielderTags)
                .frame(height: 330)
                .frame(maxWidth: .infinity)
                .bareRow()
                if let pitcher = defense[.pitcher].flatMap(player), pitcher.throwsWith == nil || draft.handEdits[pitcher.id] != nil {
                    HStack(spacing: Spacing.small) {
                        Text("\(pitcher.lastName) throws").font(ScorebookFont.body)
                        Spacer()
                        ForEach(Hand.allCases, id: \.self) { hand in
                            Button(hand == .right ? "Right" : "Left") { draft.handEdits[pitcher.id] = hand }
                                .buttonStyle(ChipStyle(isOn: draft.handEdits[pitcher.id] == hand))
                        }
                    }
                    .cardRow()
                }
            }
        }
        .sheet(item: $picking) { picked in
            FielderPicker(draft: $draft, position: picked.position, ours: ours) { picking = nil }
                .presentationDetents([.large])
        }
    }

    /// The name written at each position on the drawing: first name over last name, or both
    /// last names for a position shared by turns.
    private var fielderTags: [Position: FielderNameTag] {
        var tags: [Position: FielderNameTag] = [:]
        for (position, id) in defense {
            guard let starter = player(id) else { continue }
            let second = ours ? lineup.alternates[position].flatMap(lineup.player) : nil
            tags[position] = second.map { FielderNameTag(sharing: starter, with: $0) } ?? FielderNameTag(starter)
        }
        return tags
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
    var ours: Bool = true
    var onDone: () -> Void

    private var lineup: OurLineup { draft.ours }
    /// True after "Take turns by inning…": the grid then picks the even-innings player.
    @State private var choosingAlternate = false

    var body: some View {
        let starter = draft.fieldingDefense(ours: ours)[position]
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.medium) {
                    if choosingAlternate, let starter, let starterPlayer = lineup.player(starter) {
                        Text("Who plays \(position.name) in even innings? \(starterPlayer.lastName) plays the odd ones.")
                            .font(ScorebookFont.caption)
                            .foregroundStyle(ScorebookColor.textSecondary)
                        PlayerGrid(lineup.roster.filter { $0.id != starter }.map { choice($0, isOn: lineup.alternates[position] == $0.id) }) { id in
                            draft.ours.setAlternate(id, at: position); onDone()
                        }
                        Button("Nobody else: \(starterPlayer.lastName) plays every inning") {
                            draft.ours.setAlternate(nil, at: position); onDone()
                        }
                        .buttonStyle(ChipStyle())
                    } else {
                        PlayerGrid(draft.fieldingPlayers(ours: ours).map { choice($0, isOn: starter == $0.id) }) { id in
                            draft.assignFielder(id, to: position, ours: ours); onDone()
                        }
                        HStack(spacing: Spacing.small) {
                            if starter != nil {
                                Button("Nobody") { draft.assignFielder(nil, to: position, ours: ours); onDone() }
                                    .buttonStyle(ChipStyle())
                                if ours {
                                    Button("Take turns by inning…") { choosingAlternate = true }
                                        .buttonStyle(ChipStyle())
                                }
                            }
                        }
                    }
                }
                .padding(Spacing.large)
            }
            .background(ScorebookColor.background)
            .navigationTitle("Who plays \(position.name)?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done", action: onDone) }
            }
        }
    }

    /// One player in the grid, by name.
    private func choice(_ player: Player, isOn: Bool) -> PlayerGrid.Choice {
        PlayerGrid.Choice(id: player.id, name: ours ? player.displayName : PregameWording.theirHitter(player), isChosen: isOn)
    }
}
