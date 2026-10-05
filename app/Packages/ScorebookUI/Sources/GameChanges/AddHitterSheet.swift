// The add-a-hitter sheet: pick a player from the roster, or type in a new one, to bat at the
// bottom of the order (rule 9.5 B: hitters may be added at any time). Shows where in the order
// they will bat and how soon they will be up.

import SwiftUI
import Model
import SampleData
import DesignSystem

/// Add a hitter to the bottom of a batting order. Hands back an `addHitter` event, with the
/// new player attached when the scorer typed one in.
public struct AddHitterSheet: View {
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

    /// - Parameters:
    ///   - context: The game's setup and the situation now.
    ///   - side: The team adding a hitter. Leave it out for the batting team.
    ///   - onFinish: Called once with the event to record, or `.cancel`.
    public init(context: GameChangeContext, side: TeamSide? = nil, onFinish: @escaping (GameChangeResult) -> Void) {
        self.context = context
        self.side = side ?? context.situation.battingSide
        self.onFinish = onFinish
    }

    private var state: TeamState { context.state(side) }
    private var look: TeamLook { context.look(side) }

    /// Players not batting now who have not left the game: the usual choices.
    private var choices: [Player] {
        let skip = context.inBattingOrder(side).union(context.leftTheGame(side))
        return context.team(side).roster.filter { !skip.contains($0.id) }
    }

    /// Players who have left the game, for "Someone else" (a removed substitute may not come
    /// back under rule 9.6 B; the scorer decides).
    private var everyoneElse: [Player] {
        let gone = context.leftTheGame(side)
        return context.team(side).roster.filter { gone.contains($0.id) }
    }

    public var body: some View {
        SheetFrame(title: "Add a hitter", subtitle: "To the bottom of the \(context.teamName(side)) order",
                   onCancel: { onFinish(.cancel) }) {
            Card {
                ForEach(choices) { player in
                    PlayerChoiceRow(context: context, player: player.id, detail: detail(for: player), look: look,
                                    isSelected: pick == .player(player.id)) { pick = .player(player.id) }
                    RowDivider()
                }
                OptionRow(title: "New player", detail: "Number, name and batting side",
                          end: .radio(pick == .newPlayer), action: { pick = .newPlayer }) {
                    IconBadge(systemName: "plus")
                }
            }

            if pick == .newPlayer {
                SectionLabel("New player")
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
                        PlayerChoiceRow(context: context, player: player.id, detail: "Left the game · your call", look: look,
                                        isSelected: pick == .player(player.id)) { pick = .player(player.id) }
                    }
                }
            } else if !everyoneElse.isEmpty {
                SomeoneElseButton { showEveryone = true }
            }

            InfoBox(whenTheyBat)
        } footer: {
            VStack(spacing: Spacing.small) {
                Button(pick == nil ? "Pick a hitter" : "Add to the batting order") { confirm(recordName: false) }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(pick == nil)
                // Our new hitter's name, recorded for the announcer straight after adding them.
                if context.setup[side].isOurs, pickedName != nil {
                    Button("Add and record their name") { confirm(recordName: true) }
                        .font(ScorebookFont.headline)
                        .frame(minHeight: Spacing.minimumTapSize)
                }
            }
        }
    }

    /// A line about a player who could be added: "Playing shortstop, not batting yet", or
    /// "Bench · bats left".
    private func detail(for player: Player) -> String {
        if let position = state.position(of: player.id) { return "Playing \(position.name), not batting yet" }
        return ["Bench", batsText(player)].compactMap { $0 }.joined(separator: " · ")
    }

    /// Where the new hitter bats and how soon they are up: "Bats 10th, after Barros. With
    /// Barros up now, they bat next." Counting spots in the list, nothing more.
    private var whenTheyBat: Text {
        let slots = state.battingOrder.slots
        let newSpot = Text(ordinal(slots.count + 1)).bold().foregroundStyle(ScorebookColor.textPrimary)
        let after = slots.last?.current.map { ", after \(context.shortName($0))" } ?? ""
        let start = Text("Bats \(newSpot)\(after).")
        guard !slots.isEmpty else { return start }
        if side == context.situation.battingSide, let batter = state.currentBatter {
            // Hitters between the one at bat now and the new last spot.
            let between = slots.count - 1 - state.nextBatterIndex
            let soon = between == 0
                ? Text("they bat right after \(context.shortName(batter))")
                : Text("they bat after \(context.shortName(batter)) and \(between) more")
            return Text("\(start) With \(context.shortName(batter)) up now, \(soon.bold().foregroundStyle(ScorebookColor.textPrimary)).")
        }
        // Not batting now: hitters from the next one due up to the end of the order.
        let ahead = slots.count - state.nextBatterIndex
        return Text("\(start) When the \(context.teamName(side)) bat next, \(ahead == 1 ? "1 hitter comes" : "\(ahead) hitters come") up first.")
    }

    /// The name of the hitter picked, if they have one (for "Add and record their name").
    private var pickedName: String? {
        switch pick {
        case .player(let id): context.player(id)?.name.flatMap { $0.isEmpty ? nil : $0 }
        case .newPlayer: newName.trimmingCharacters(in: .whitespaces).isEmpty ? nil : newName
        case nil: nil
        }
    }

    /// Builds the event and hands it back, asking for the name recording next if wanted.
    private func confirm(recordName: Bool) {
        guard let pick else { return }
        var newPlayers: [RosterAddition] = []
        let player: PlayerID
        switch pick {
        case .player(let id):
            player = id
        case .newPlayer:
            let made = NewPlayerFields.makePlayer(number: newNumber, name: newName, bats: newBats)
            newPlayers.append(RosterAddition(side: side, player: made))
            player = made.id
        }
        let entered = EnteredEvent(event: GameEvent(kind: .addHitter(AddHitter(team: side, player: player))), newPlayers: newPlayers)
        onFinish(recordName ? .recordThenRecordName(entered, player) : .record(entered))
    }
}
