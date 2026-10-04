// Editing a batter: name, number and batting side, at any point in the game. For their
// hitters this is how "Batter 4" or "#22" gets a name. For ours it also leads to the pinch
// hitter sheet. A name or number holds for the whole game, so it is a roster change, not an
// event.

import SwiftUI
import Model
import SampleData
import DesignSystem

/// Edit a hitter's name, number and batting side. Hands back `.updatePlayer` with the changed
/// player (same id), or whatever the pinch hitter sheet hands back when the scorer goes there.
public struct BatterSheet: View {
    var context: GameChangeContext
    var side: TeamSide
    var playerID: PlayerID?
    var onFinish: (GameChangeResult) -> Void

    @State private var number: String
    @State private var name: String
    @State private var bats: BattingSide?
    @State private var pinchHitting = false

    /// - Parameters:
    ///   - context: The game's setup and the situation now.
    ///   - player: The hitter to edit. Leave it out for the batter at the plate.
    ///   - side: Their team. Leave it out for the batting team.
    ///   - onFinish: Called once with the edited player, or `.cancel`.
    public init(context: GameChangeContext, player: PlayerID? = nil, side: TeamSide? = nil,
                onFinish: @escaping (GameChangeResult) -> Void) {
        self.context = context
        self.side = side ?? context.situation.battingSide
        self.playerID = player ?? context.situation.batter
        self.onFinish = onFinish
        let p = context.player(self.playerID)
        _number = State(initialValue: p?.number ?? "")
        _name = State(initialValue: p?.name ?? "")
        _bats = State(initialValue: p?.bats)
    }

    private var player: Player? { context.player(playerID) }
    private var isOurs: Bool { context.setup[side].isOurs }

    /// The player with the boxes' contents; blank boxes mean unknown.
    private var edited: Player? {
        guard var p = player else { return nil }
        let n = number.trimmingCharacters(in: .whitespaces)
        let m = name.trimmingCharacters(in: .whitespaces)
        p.number = n.isEmpty ? nil : n
        p.name = m.isEmpty ? nil : m
        p.bats = bats
        return p
    }

    private var subtitle: String {
        var parts: [String] = []
        if let n = player?.number, !n.isEmpty { parts.append("#\(n)") }
        if let id = playerID, let spot = context.battingSpot(of: id, side) { parts.append("\(ordinal(spot + 1)) in the order") }
        return parts.joined(separator: " · ")
    }

    public var body: some View {
        SheetFrame(title: isOurs ? context.name(playerID) : "\(context.teamName(side)) hitter",
                   subtitle: subtitle, onCancel: { onFinish(.cancel) }) {
            VStack(alignment: .leading, spacing: 0) {
                if player == nil {
                    EmptyNote("Nobody is at bat.")
                } else {
                    if isOurs, playerID == context.situation[side].currentBatter {
                        Card {
                            OptionRow(title: "Pinch hit for \(context.shortName(playerID))", end: .chevron,
                                      action: { pinchHitting = true }) {
                                IconBadge(systemName: "hand.raised")
                            }
                        }
                        .padding(.bottom, Spacing.medium)
                    }
                    LabeledField(label: "Number", placeholder: "#", text: $number, keyboard: .numberPad)
                    LabeledField(label: "Name", placeholder: "Optional", text: $name)
                    SectionLabel("Bats")
                    SegmentedChoice(options: [(BattingSide.left, "Left"), (.right, "Right"), (.switchHitter, "Switch")],
                                    selection: $bats)
                    InfoBox(Text("Kept for the whole game, and saved to the \(context.teamName(side)) roster for next time."))
                }
            }
            .navigationDestination(isPresented: $pinchHitting) {
                PinchHitterSheet(context: context, side: side, onFinish: onFinish)
            }
        } footer: {
            Button("Save") {
                guard let edited else { return }
                onFinish(.updatePlayer(PlayerEdit(side: side, player: edited)))
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(edited == nil || edited == player)
        }
    }
}
