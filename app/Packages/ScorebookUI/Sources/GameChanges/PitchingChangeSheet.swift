// The pitching change sheet: choose the new pitcher from the fielding team's roster, or add
// someone new with their number and throwing hand. Shows the outgoing pitcher's pitch count.
//
// Pitchers who may come back (each removed pitcher may pitch again once per game, rule
// 9.12 B) are listed first, from the situation's `eligibleToPitchAgain`. Anyone else who has
// pitched today is under "Someone else". Nothing is blocked; the scorer records what happened.
//
// The new pitcher can take any batting spot, or none: usually the old pitcher's, but it may be
// the spot of the pinch hitter who just batted for them.

import SwiftUI
import Model
import SampleData
import DesignSystem

/// Choose a new pitcher. Hands back a `pitchingChange` event, with the new player attached
/// when the scorer typed one in.
public struct PitchingChangeSheet: View {
    var context: GameChangeContext
    /// The team changing pitchers: the fielding team unless the caller says otherwise.
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
    @State private var newHand: Hand?
    /// Where the old pitcher goes; missing means they leave the field.
    @State private var oldPitcherMovesTo: Position?
    /// The player whose batting spot the new pitcher takes: usually the old pitcher, or the
    /// pinch hitter who just batted for them. Missing means the new pitcher does not bat.
    @State private var battingSpotOf: PlayerID?

    /// - Parameters:
    ///   - context: The game's setup and the situation now.
    ///   - side: The team changing pitchers. Leave it out for the team in the field.
    ///   - onFinish: Called once with the event to record, or `.cancel`.
    public init(context: GameChangeContext, side: TeamSide? = nil, onFinish: @escaping (GameChangeResult) -> Void) {
        self.context = context
        self.side = side ?? context.situation.fieldingSide
        self.onFinish = onFinish
    }

    // MARK: Who goes in which list

    private var state: TeamState { context.state(side) }
    private var look: TeamLook { context.look(side) }
    private var outgoing: PlayerID? { state.pitcher }

    /// Everyone on this team who has pitched today.
    private var pitchedToday: Set<PlayerID> {
        Set(context.situation.pitchers.filter { $0.team == side }.map(\.pitcher))
    }

    /// Removed pitchers the situation says may pitch again.
    private var canPitchAgain: [PlayerID] {
        state.eligibleToPitchAgain.filter { $0 != outgoing }
    }

    /// The roster, less the pitcher now and anyone who has pitched today: the bench first,
    /// where relievers usually wait, then players already in the game.
    private var freshArms: [Player] {
        let candidates = context.team(side).roster.filter { $0.id != outgoing && !pitchedToday.contains($0.id) }
        let bench = Set(context.bench(side).map(\.id))
        return candidates.filter { bench.contains($0.id) } + candidates.filter { !bench.contains($0.id) }
    }

    /// Players who pitched today and are not listed as able to come back: only under "Someone else".
    private var everyoneElse: [Player] {
        context.team(side).roster.filter {
            $0.id != outgoing && pitchedToday.contains($0.id) && !canPitchAgain.contains($0.id)
        }
    }

    /// The player picked, if they are already on the roster.
    private var pickedPlayer: PlayerID? {
        if case .player(let id) = pick { return id }
        return nil
    }

    // MARK: The sheet

    public var body: some View {
        SheetFrame(title: "Pitching change",
                   subtitle: "\(context.teamName(side)) pitcher",
                   onCancel: { onFinish(.cancel) }) {
            outgoingInfo

            if !canPitchAgain.isEmpty {
                SectionLabel("Can pitch again")
                Card {
                    ForEach(Array(canPitchAgain.enumerated()), id: \.element) { i, id in
                        if i > 0 { RowDivider() }
                        row(for: id, detail: [throwsText(context.player(id)), "Pitched earlier today; can return once"])
                    }
                }
            }

            SectionLabel(canPitchAgain.isEmpty ? "Who pitches next" : "Everyone else")
            Card {
                ForEach(freshArms) { player in
                    row(for: player.id, detail: [throwsText(player), whereNow(player.id)])
                    RowDivider()
                }
                OptionRow(title: "New pitcher",
                          end: .radio(pick == .newPlayer), action: { pick = .newPlayer }) {
                    IconBadge(systemName: "plus")
                }
            }

            if !everyoneElse.isEmpty {
                if showEveryone {
                    SectionLabel("Someone else")
                    Card {
                        ForEach(Array(everyoneElse.enumerated()), id: \.element.id) { i, player in
                            if i > 0 { RowDivider() }
                            row(for: player.id, detail: ["Already pitched today"])
                        }
                    }
                } else {
                    SomeoneElseButton { showEveryone = true }
                }
            }

            if pick == .newPlayer {
                SectionLabel("New pitcher")
                NewPlayerFields(number: $newNumber, name: $newName)
                SectionLabel("Throws")
                SegmentedChoice(options: [(Hand.left, "Left"), (Hand.right, "Right")], selection: $newHand)
            }

            if pick != nil, let outgoing {
                afterTheChange(outgoing)
            }
        } footer: {
            Button(confirmTitle, action: confirm)
                .buttonStyle(PrimaryButtonStyle())
                .disabled(pick == nil)
        }
    }

    /// "Coming out: Sky Barros (R) · 57 pitches, 35 strikes", and a note when a batter is
    /// part way through a count.
    @ViewBuilder private var outgoingInfo: some View {
        if let outgoing {
            let tally = context.situation.tally(for: outgoing)
            let hand = context.player(outgoing)?.throwsWith.map { $0 == .left ? " (L)" : " (R)" } ?? ""
            let work = tally.map { "\($0.pitches) pitches, \($0.strikes) strikes" } ?? "no pitches yet"
            InfoBox(Text("Coming out: \(Text(context.name(outgoing) + hand).bold().foregroundStyle(ScorebookColor.textPrimary)) · \(work)"))
            let count = context.situation.count
            if side == context.situation.fieldingSide, count != .fresh, let batter = context.situation.batter {
                FootNote("Mid-count, \(count.balls)–\(count.strikes) to \(context.shortName(batter)). League rule: a pitcher finishes the batter unless hurt.")
            }
        } else {
            InfoBox(Text("Nobody is pitching for the \(context.teamName(side)) yet."))
        }
    }

    /// What happens to the old pitcher and the batting order: where the old pitcher goes, and
    /// whether the new one takes the old one's batting spot.
    @ViewBuilder private func afterTheChange(_ outgoing: PlayerID) -> some View {
        let oldName = context.shortName(outgoing)
        SectionLabel("\(oldName) after the change")
        Card {
            Menu {
                Button("Leaves the field") { oldPitcherMovesTo = nil }
                ForEach(Position.allCases.filter { $0 != .pitcher }, id: \.self) { position in
                    Button("Moves to \(position.name)") { oldPitcherMovesTo = position }
                }
            } label: {
                HStack {
                    Text(oldPitcherMovesTo.map { "Moves to \($0.name)" } ?? "Leaves the field")
                        .font(ScorebookFont.headline)
                        .foregroundStyle(ScorebookColor.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .foregroundStyle(ScorebookColor.textSecondary)
                }
                .padding(.horizontal, Spacing.large - 2)
                .frame(minHeight: 52)
                .contentShape(Rectangle())
            }
            // Offer a batting spot only when the new pitcher does not already have one.
            if offersBattingSpot {
                RowDivider()
                battingSpotMenu
            }
        }
    }

    /// Whose batting spot the new pitcher takes, if any: every spot in the order is offered,
    /// with the old pitcher's first, since a pinch hitter may have batted for them.
    private var battingSpotMenu: some View {
        Menu {
            Button("Doesn’t bat") { battingSpotOf = nil }
            ForEach(spotChoices, id: \.self) { id in
                Button(spotWords(id)) { battingSpotOf = id }
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(battingSpotOf.map(spotWords) ?? "Doesn’t bat")
                        .font(ScorebookFont.headline)
                        .foregroundStyle(ScorebookColor.textPrimary)
                    if let battingSpotOf {
                        Text("\(context.shortName(battingSpotOf)) leaves the batting order")
                            .font(ScorebookFont.caption)
                            .foregroundStyle(ScorebookColor.textSecondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .foregroundStyle(ScorebookColor.textSecondary)
            }
            .padding(.horizontal, Spacing.large - 2)
            .frame(minHeight: 58)
            .contentShape(Rectangle())
        }
        .accessibilityLabel(Text("Batting spot: \(battingSpotOf.map(spotWords) ?? "Doesn’t bat")"))
    }

    /// Everyone holding a batting spot now, the old pitcher first, then in batting order.
    private var spotChoices: [PlayerID] {
        let holders = state.battingOrder.slots.compactMap(\.current)
        guard let outgoing, holders.contains(outgoing) else { return holders }
        return [outgoing] + holders.filter { $0 != outgoing }
    }

    /// "Bats 9th, in Webb’s spot".
    private func spotWords(_ id: PlayerID) -> String {
        let spot = context.battingSpot(of: id, side).map { ordinal($0 + 1) } ?? "?"
        return "Bats \(spot), in \(context.shortName(id))’s spot"
    }

    /// True when the new pitcher could take a batting spot: they do not hold one already, and
    /// the team has a batting order.
    private var offersBattingSpot: Bool {
        guard !state.battingOrder.slots.isEmpty else { return false }
        return pickedPlayer.flatMap { context.battingSpot(of: $0, side) } == nil
    }

    /// One player to choose.
    private func row(for id: PlayerID, detail: [String?]) -> some View {
        PlayerChoiceRow(context: context, player: id, detail: detail.compactMap { $0 }.joined(separator: " · "),
                        look: look, isSelected: pick == .player(id)) {
            pick = .player(id)
        }
    }

    /// Where a player is now, in a few words: "Playing shortstop", "Bats 10th", "Bench".
    private func whereNow(_ id: PlayerID) -> String {
        if let position = state.position(of: id) { return "Playing \(position.name)" }
        if let spot = context.battingSpot(of: id, side) { return "Bats \(ordinal(spot + 1))" }
        return "Bench"
    }

    // MARK: Finishing

    private var confirmTitle: String {
        switch pick {
        case .player(let id): "\(context.shortName(id)) pitches"
        case .newPlayer: "New pitcher pitches"
        case nil: "Pick a pitcher"
        }
    }

    /// Builds the pitching change and hands it back.
    private func confirm() {
        guard let pick else { return }
        var newPlayers: [RosterAddition] = []
        let newPitcher: PlayerID
        switch pick {
        case .player(let id):
            newPitcher = id
        case .newPlayer:
            let player = NewPlayerFields.makePlayer(number: newNumber, name: newName, throwsWith: newHand)
            newPlayers.append(RosterAddition(side: side, player: player))
            newPitcher = player.id
        }
        let change = PitchingChange(
            team: side,
            newPitcher: newPitcher,
            previousPitcherMovesTo: oldPitcherMovesTo,
            takesBattingSpotOf: offersBattingSpot ? battingSpotOf : nil
        )
        onFinish(.record(EnteredEvent(event: GameEvent(kind: .pitchingChange(change)), newPlayers: newPlayers)))
    }
}
