// The pinch hitter sheet: choose who bats now in the current batter's spot.
//
// Starters the situation lists as able to re-enter this spot (rule 9.9: a starter may come
// back to their own spot once their substitute has batted) come first under "Can re-enter",
// then the bench, then "Someone else" with everyone, each with a note on where they are now.
// The scorer's choice stands. The bottom of the sheet also offers a batting hole, for a
// player lost with nobody to replace them.

import SwiftUI
import Model
import SampleData
import DesignSystem

/// Choose a pinch hitter. Hands back a substitution (a pinch hitter in the current spot),
/// with the new player attached when the scorer typed one in, or a batting hole.
public struct PinchHitterSheet: View {
    var context: GameChangeContext
    var side: TeamSide
    var onFinish: (GameChangeResult) -> Void

    /// Who the scorer has picked: a player already on the roster, or someone new.
    private enum Pick: Hashable {
        case player(PlayerID)
        case newPlayer
    }

    @State private var pick: Pick?
    @State private var showEveryone = false
    @State private var newNumber = ""
    @State private var newName = ""
    @State private var newBats: BattingSide?
    @State private var askingAboutHole = false

    /// - Parameters:
    ///   - context: The game's setup and the situation now.
    ///   - side: The team at bat. Leave it out for the batting team.
    ///   - onFinish: Called once with the event to record, or `.cancel`.
    public init(context: GameChangeContext, side: TeamSide? = nil, onFinish: @escaping (GameChangeResult) -> Void) {
        self.context = context
        self.side = side ?? context.situation.battingSide
        self.onFinish = onFinish
    }

    private var state: TeamState { context.state(side) }
    private var look: TeamLook { context.look(side) }
    /// The spot that is up, counting from 0.
    private var spot: Int { state.nextBatterIndex }
    /// Who holds that spot now.
    private var batter: PlayerID? { state.currentBatter }

    /// Starters the situation says may come back into this spot.
    private var reentering: [PlayerID] {
        state.eligibleToReenter.filter { $0.spotIndex == spot && $0.player != batter }.map(\.player)
    }

    /// The bench, less anyone already listed under "Can re-enter".
    private var bench: [Player] {
        context.bench(side).filter { !reentering.contains($0.id) }
    }

    /// Everyone else on the roster, for "Someone else".
    private var everyoneElse: [Player] {
        let listed = Set(reentering + bench.map(\.id) + [batter].compactMap { $0 })
        return context.team(side).roster.filter { !listed.contains($0.id) }
    }

    private var pickedPlayer: PlayerID? {
        if case .player(let id) = pick { return id }
        return nil
    }

    public var body: some View {
        SheetFrame(title: "Pinch hitter", subtitle: "\(context.teamName(side)) batting",
                   onCancel: { onFinish(.cancel) }) {
            if let batter {
                InfoBox(Text("Batting for \(Text(context.name(batter)).bold().foregroundStyle(ScorebookColor.textPrimary)), \(ordinal(spot + 1)) in the order."))

                if !reentering.isEmpty {
                    SectionLabel("Can re-enter")
                    Card {
                        ForEach(Array(reentering.enumerated()), id: \.element) { i, id in
                            if i > 0 { RowDivider() }
                            row(id, detail: ["Started in this spot", batsText(context.player(id))])
                        }
                    }
                }

                SectionLabel("Bench")
                Card {
                    ForEach(bench) { player in
                        row(player.id, detail: [batsText(player)])
                        RowDivider()
                    }
                    OptionRow(title: "New hitter",
                              end: .radio(pick == .newPlayer), action: { pick = .newPlayer }) {
                        IconBadge(systemName: "plus")
                    }
                }

                if pick == .newPlayer {
                    SectionLabel("New hitter")
                    NewPlayerFields(number: $newNumber, name: $newName)
                    SectionLabel("Bats")
                    SegmentedChoice(options: [(BattingSide.left, "Left"), (.right, "Right"), (.switchHitter, "Switch")],
                                    selection: $newBats)
                }

                if showEveryone {
                    SectionLabel("Someone else")
                    Card {
                        ForEach(Array(everyoneElse.enumerated()), id: \.element.id) { i, player in
                            if i > 0 { RowDivider() }
                            row(player.id, detail: [whereNow(player.id)])
                        }
                    }
                } else if !everyoneElse.isEmpty {
                    SomeoneElseButton { showEveryone = true }
                }

                SectionLabel("Nobody to bat")
                Card {
                    OptionRow(title: "Leave a batting hole",
                              detail: "An automatic out each time the spot comes up",
                              end: .chevron, action: { askingAboutHole = true }) {
                        IconBadge(systemName: "circle.slash", tint: ScorebookColor.out)
                    }
                }
            } else {
                EmptyNote("Nobody is due up for the \(context.teamName(side)).")
            }
        } footer: {
            Button(confirmTitle, action: confirm)
                .buttonStyle(PrimaryButtonStyle())
                .disabled(pick == nil || batter == nil)
        }
        .confirmationDialog("Leave a batting hole?", isPresented: $askingAboutHole, titleVisibility: .visible) {
            Button("Leave a batting hole", role: .destructive, action: recordHole)
        } message: {
            Text("\(batter.map { context.shortName($0) } ?? "This hitter")’s turn now is an out, and so is every turn of the \(ordinal(spot + 1)) spot until someone fills it.")
        }
    }

    /// One player to choose.
    private func row(_ id: PlayerID, detail: [String?]) -> some View {
        let words = detail.compactMap { $0 }.joined(separator: " · ")
        return PlayerChoiceRow(context: context, player: id, detail: words.isEmpty ? nil : words,
                        look: look, isSelected: pick == .player(id)) {
            pick = .player(id)
        }
    }

    /// Where a player is now, for "Someone else": "Already bats 4th", "Playing shortstop",
    /// "Can re-enter in the 2nd spot", "Left the game".
    private func whereNow(_ id: PlayerID) -> String {
        if let at = context.battingSpot(of: id, side) { return "Already bats \(ordinal(at + 1))" }
        if let option = state.eligibleToReenter.first(where: { $0.player == id }) {
            return "Can re-enter in the \(ordinal(option.spotIndex + 1)) spot"
        }
        if let position = state.position(of: id) { return "Playing \(position.name)" }
        if context.leftTheGame(side).contains(id) { return "Left the game" }
        return "Not batting"
    }

    private var confirmTitle: String {
        switch pick {
        case .player(let id): "\(context.shortName(id)) bats"
        case .newPlayer: "New hitter bats"
        case nil: "Pick a hitter"
        }
    }

    /// Builds the substitution and hands it back.
    private func confirm() {
        guard let pick, let batter else { return }
        var newPlayers: [RosterAddition] = []
        let incoming: PlayerID
        switch pick {
        case .player(let id):
            incoming = id
        case .newPlayer:
            let player = NewPlayerFields.makePlayer(number: newNumber, name: newName, bats: newBats)
            newPlayers.append(RosterAddition(side: side, player: player))
            incoming = player.id
        }
        let change = Substitution(team: side, batting: [BattingChange(kind: .pinchHitter, incoming: incoming, replacing: batter)])
        onFinish(.record(EnteredEvent(event: GameEvent(kind: .substitution(change)), newPlayers: newPlayers)))
    }

    /// Marks the current spot as a batting hole.
    private func recordHole() {
        onFinish(.record(EnteredEvent(event: GameEvent(kind: .battingHole(BattingHole(team: side, spotIndex: spot))))))
    }
}
