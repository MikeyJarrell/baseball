// Lineups and rosters: both teams' batting orders, fielders who do not bat and the rest of the
// roster, editable at any point in the game. The first row of the changes menu.
//
// Made for the other team's lineup card arriving late. Tap anyone to:
//   - fix their name, number or batting side;
//   - say it was really someone else: a player on that team's roster, or someone new typed in.
//     The two trade places in the whole game, including every play already recorded, so a
//     hitter who batted as "#22" is credited to the player the card names;
//   - before the first pitch, take a hitter out of the batting order.
// Below the lists: add a hitter to the bottom of the order, or a player to the roster.
//
// The page stays open while the scorer works through a card: each change is handed back
// wrapped in `.keepOpen`, and the page shows the game as it is after the change.

import SwiftUI
import Model
import SampleData
import DesignSystem

/// Both teams' lineups and rosters, to fix during the game. Hands back each change wrapped in
/// `.keepOpen`, and `.cancel` when the scorer is done.
public struct LineupsSheet: View {
    var context: GameChangeContext
    var onFinish: (GameChangeResult) -> Void

    /// A page pushed on top of the lists.
    private enum Page: Hashable {
        case player(PlayerID)
        case addHitter
        case addPlayer
    }

    @State private var side: TeamSide
    @State private var open: Page?

    /// - Parameters:
    ///   - context: The game's setup and the situation now.
    ///   - side: The team shown first. Leave it out for the other team (theirs is the card that
    ///     comes late), or the visitors when neither team is ours.
    ///   - onFinish: Called with each change, wrapped in `.keepOpen`, and `.cancel` for Done.
    public init(context: GameChangeContext, side: TeamSide? = nil, onFinish: @escaping (GameChangeResult) -> Void) {
        self.context = context
        self.onFinish = onFinish
        _side = State(initialValue: side ?? context.ourSide?.opponent ?? .away)
    }

    private var state: TeamState { context.state(side) }
    private var look: TeamLook { context.look(side) }

    /// Who holds each spot in the batting order now, top to bottom.
    private var order: [(spot: Int, player: PlayerID?)] {
        state.battingOrder.slots.enumerated().map { ($0.offset, $0.element.current) }
    }

    /// Fielders who hold no spot in the batting order: a pitcher who does not hit, say.
    private var fieldingOnly: [PlayerID] {
        let batting = context.inBattingOrder(side)
        return state.fielders.sorted { $0.position < $1.position }.map(\.player).filter { !batting.contains($0) }
    }

    /// Everyone else on the roster: the bench, and anyone who has left the game.
    private var restOfRoster: [Player] {
        let playing = context.inBattingOrder(side).union(context.inField(side))
        return context.team(side).roster.filter { !playing.contains($0.id) }
    }

    public var body: some View {
        SheetFrame(title: "Lineups and rosters", subtitle: "Fix names, numbers and who batted where",
                   onCancel: { onFinish(.cancel) }) {
            SegmentedChoice(options: [(TeamSide.away, context.teamName(.away)), (.home, context.teamName(.home))],
                            selection: Binding(get: { side }, set: { if let new = $0 { side = new } }))
                .padding(.bottom, Spacing.medium)

            SectionLabel("Batting order")
            Card {
                ForEach(order, id: \.spot) { spot, player in
                    if spot > 0 { RowDivider() }
                    if let player {
                        playerRow(player, title: "\(spot + 1). \(context.name(player))",
                                  detail: LineupWording.position(player, side: side, in: context))
                    } else {
                        OptionRow(title: "\(spot + 1). Empty spot", detail: "Nobody bats here") {
                            IconBadge(systemName: "minus", tint: ScorebookColor.out)
                        }
                    }
                }
                RowDivider()
                OptionRow(title: "Add a hitter", detail: "To the bottom of the order", end: .chevron,
                          action: { open = .addHitter }) {
                    IconBadge(systemName: "person.badge.plus")
                }
            }

            if !fieldingOnly.isEmpty {
                SectionLabel("In the field, not batting")
                Card {
                    ForEach(Array(fieldingOnly.enumerated()), id: \.element) { i, player in
                        if i > 0 { RowDivider() }
                        playerRow(player, title: context.name(player),
                                  detail: LineupWording.whereIs(player, side: side, in: context))
                    }
                }
            }

            SectionLabel("Rest of the roster")
            Card {
                ForEach(restOfRoster) { player in
                    playerRow(player.id, title: player.displayName,
                              detail: LineupWording.whereIs(player.id, side: side, in: context))
                    RowDivider()
                }
                OptionRow(title: "Add a player to the roster", detail: "Someone not listed yet", end: .chevron,
                          action: { open = .addPlayer }) {
                    IconBadge(systemName: "plus")
                }
            }

            FootNote("Tap a player to fix their name or number, or to say it was really someone else. Changes save as you make them.")
        } footer: {
            Button("Done") { onFinish(.cancel) }
                .buttonStyle(PrimaryButtonStyle())
        }
        .navigationDestination(item: $open) { page in
            switch page {
            case .player(let id):
                PlayerFixPage(context: context, side: side, player: id, onDone: finish)
            case .addHitter:
                AddHitterSheet(context: context, side: side, onFinish: { finish($0 == .cancel ? nil : $0) })
            case .addPlayer:
                NewRosterPlayerPage(context: context, side: side, onDone: finish)
            }
        }
    }

    /// Back to the lists, handing on the change made on the page, if any.
    private func finish(_ result: GameChangeResult?) {
        open = nil
        if let result { onFinish(.keepOpen(result)) }
    }

    /// One player: number badge, name, and where they are in the game now.
    private func playerRow(_ id: PlayerID, title: String, detail: String) -> some View {
        OptionRow(title: title, detail: detail, end: .chevron,
                  action: { open = .player(id) }) {
            PlayerNumberBadge(context.number(id), look: look, size: 36)
        }
    }
}

// MARK: - One player

/// One player from the lineups page: fix their details, or say it was really someone else.
struct PlayerFixPage: View {
    var context: GameChangeContext
    var side: TeamSide
    var player: PlayerID
    /// Called with the change made, or nothing to go back without one.
    var onDone: (GameChangeResult?) -> Void

    @State private var editing = false
    @State private var typingNew = false
    @State private var newNumber = ""
    @State private var newName = ""
    /// The player picked as the one who was really there, waiting for the scorer to confirm.
    @State private var confirming: Player?

    /// True when the player is in the game now or was earlier, so "someone else" makes sense.
    private var isInTheGame: Bool {
        context.inBattingOrder(side).contains(player) || context.inField(side).contains(player)
            || context.leftTheGame(side).contains(player)
    }

    /// True while this hitter can still come out of the starting order (before the first pitch).
    private var canRemove: Bool {
        context.startingOrderOpen.contains(side) && context.team(side).battingOrder.contains(player)
    }

    /// Everyone else on the team, to pick the one who was really there.
    private var others: [Player] {
        context.team(side).roster.filter { $0.id != player }
    }

    var body: some View {
        SheetFrame(title: context.name(player), subtitle: LineupWording.whereIs(player, side: side, in: context)) {
            Card {
                OptionRow(title: "Name, number, batting side", detail: detailsLine, end: .chevron,
                          action: { editing = true }) {
                    IconBadge(systemName: "pencil")
                }
            }

            if isInTheGame {
                SectionLabel("It was really someone else")
                Card {
                    ForEach(Array(others.enumerated()), id: \.element.id) { i, other in
                        if i > 0 { RowDivider() }
                        OptionRow(title: other.displayName,
                                  detail: LineupWording.whereIs(other.id, side: side, in: context),
                                  action: { confirming = other }) {
                            PlayerNumberBadge(other.number ?? "?", look: context.look(side), size: 36)
                        }
                    }
                    if !others.isEmpty { RowDivider() }
                    OptionRow(title: "Someone new", detail: "Type their number and name",
                              end: typingNew ? .close : .chevron, action: { typingNew.toggle() }) {
                        IconBadge(systemName: "plus")
                    }
                    if typingNew {
                        VStack(alignment: .leading, spacing: 0) {
                            NewPlayerFields(number: $newNumber, name: $newName)
                            Button("Use this player") {
                                confirming = NewPlayerFields.makePlayer(number: newNumber, name: newName)
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(newNumber.trimmingCharacters(in: .whitespaces).isEmpty
                                      && newName.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                        .padding(Spacing.large - 2)
                        .background(ScorebookColor.surfaceSecondary)
                    }
                }
                FootNote("Everything recorded for \(context.name(player)) moves to the player you pick. If they were in the game too, the two trade places.")
            }

            if canRemove {
                Card {
                    OptionRow(title: "Take out of the batting order", detail: "Before the first pitch only",
                              action: { onDone(.correctLineup(.removeFromOrder(side: side, player: player))) }) {
                        IconBadge(systemName: "minus", tint: ScorebookColor.out)
                    }
                }
                .padding(.top, Spacing.medium)
            }
        }
        .navigationDestination(isPresented: $editing) {
            BatterSheet(context: context, player: player, side: side, onFinish: { result in
                editing = false
                onDone(result == .cancel ? nil : result)
            })
        }
        .confirmationDialog(confirmQuestion, isPresented: Binding(get: { confirming != nil },
                                                                  set: { if !$0 { confirming = nil } }),
                            titleVisibility: .visible) {
            Button("Yes, it was \(confirming?.displayName ?? "them")") {
                guard let really = confirming else { return }
                confirming = nil
                onDone(.correctLineup(.wasReally(side: side, shown: player, really: really)))
            }
        } message: {
            Text("Every play already recorded for \(context.name(player)) becomes \(confirming?.displayName ?? "theirs")’s. If both were in the game, they trade places.")
        }
    }

    /// "#22 · bats left", or "Nothing known yet".
    private var detailsLine: String {
        let p = context.player(player)
        var parts: [String] = []
        if let n = p?.number, !n.isEmpty { parts.append("#\(n)") }
        if let bats = batsText(p) { parts.append(bats) }
        return parts.isEmpty ? "Nothing known yet" : parts.joined(separator: " · ")
    }

    private var confirmQuestion: String {
        "Was \(context.name(player)) really \(confirming?.displayName ?? "someone else")?"
    }
}

// MARK: - A new player on the roster

/// A player added to a team's roster during the game, on the bench until brought in.
struct NewRosterPlayerPage: View {
    var context: GameChangeContext
    var side: TeamSide
    var onDone: (GameChangeResult?) -> Void

    @State private var number = ""
    @State private var name = ""
    @State private var bats: BattingSide?

    private var isEmpty: Bool {
        number.trimmingCharacters(in: .whitespaces).isEmpty && name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        SheetFrame(title: "New player", subtitle: context.teamName(side)) {
            NewPlayerFields(number: $number, name: $name)
            SectionLabel("Bats")
            SegmentedChoice(options: [(BattingSide.left, "Left"), (.right, "Right"), (.switchHitter, "Switch")],
                            selection: $bats)
            InfoBox(Text("Added to the \(context.teamName(side)) roster for this game and next time. Bring them in with a substitution or Add a hitter."))
        } footer: {
            Button("Add to the roster") {
                let player = NewPlayerFields.makePlayer(number: number, name: name, bats: bats)
                onDone(.updatePlayer(PlayerEdit(side: side, player: player)))
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isEmpty)
        }
    }
}

// MARK: - Words

enum LineupWording {
    /// Where a hitter plays in the field now: "Shortstop", or "Not in the field".
    static func position(_ id: PlayerID, side: TeamSide, in context: GameChangeContext) -> String {
        context.state(side).fielders.first { $0.player == id }.map { positionTitle($0.position) } ?? "Not in the field"
    }

    /// Where a player is in the game now: "Bats 4th · SS", "Pitcher · doesn’t bat", "Bench",
    /// "Left the game".
    static func whereIs(_ id: PlayerID, side: TeamSide, in context: GameChangeContext) -> String {
        let position = context.state(side).fielders.first { $0.player == id }?.position
        if let spot = context.battingSpot(of: id, side) {
            return "Bats \(ordinal(spot + 1))" + (position.map { " · \($0.abbreviation)" } ?? "")
        }
        if let position { return "\(positionTitle(position)) · doesn’t bat" }
        if context.leftTheGame(side).contains(id) { return "Left the game" }
        return "Bench"
    }
}
