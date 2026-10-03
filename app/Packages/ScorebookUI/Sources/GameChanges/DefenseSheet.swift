// The defense check and the fielders sheet: the nine positions with who is at each.
//
// - Defense check: each time our team takes the field, a compact list of the nine positions.
//   One tap confirms nobody moved; tapping a position swaps in another player. The app can
//   hand in a suggested defense, such as two players who alternate at first base by inning:
//   the sheet starts from the suggestion, marks each position that differs from now ("Ruiz at
//   first base · alternating"), and one tap on the big button records the change.
// - Fielders (from the changes menu): the same list, for moving players between positions and
//   bringing players in from the bench, saved as one batch.
//
// Changes are handed back as one substitution touching only the defense; a check with no
// changes is a `defenseConfirmed` event.

import SwiftUI
import Model
import SampleData
import DesignSystem

/// A defense to start the check from instead of the one on the field now, with a reason for
/// each position that differs. Built by the app from the game's plan (two players alternating
/// at one position by inning, for example); this sheet only shows it.
public struct DefenseSuggestion: Equatable, Sendable {
    /// Who should be at each position this half-inning.
    public var fielders: [FielderAssignment]
    /// Why a position differs from now, shown beside it: "alternating".
    public var reasons: [Position: String]

    public init(fielders: [FielderAssignment], reasons: [Position: String] = [:]) {
        self.fielders = fielders
        self.reasons = reasons
    }
}

/// The nine positions, to confirm or change. Hands back `defenseConfirmed`, a substitution with
/// the fielding changes, or `.cancel`.
public struct DefenseSheet: View {
    /// Why the sheet is open.
    public enum Purpose: Sendable {
        /// Our team is taking the field: confirm who is where.
        case check
        /// The scorer opened Fielders from the changes menu to make changes.
        case changes
    }

    var context: GameChangeContext
    var purpose: Purpose
    var suggestion: DefenseSuggestion?
    var onFinish: (GameChangeResult) -> Void

    @State private var side: TeamSide
    /// Who is at each position as the scorer has it on this sheet.
    @State private var draft: [Position: PlayerID]
    /// The position whose player list is open.
    @State private var openPosition: Position?

    /// - Parameters:
    ///   - context: The game's setup and the situation now.
    ///   - purpose: `.check` when our team takes the field, `.changes` from the changes menu.
    ///   - side: The team. Leave it out for our team on a check, or the fielding team for changes.
    ///   - suggestion: A defense to start from instead of the one on the field, with reasons.
    ///   - onFinish: Called once with the event to record, or `.cancel` ("Later").
    public init(context: GameChangeContext, purpose: Purpose = .check, side: TeamSide? = nil,
                suggestion: DefenseSuggestion? = nil, onFinish: @escaping (GameChangeResult) -> Void) {
        self.context = context
        self.purpose = purpose
        self.suggestion = suggestion
        self.onFinish = onFinish
        let team = side ?? (purpose == .check ? context.ourSide : nil) ?? context.situation.fieldingSide
        _side = State(initialValue: team)
        _draft = State(initialValue: Self.startingDraft(context: context, side: team, suggestion: suggestion))
    }

    /// The defense the sheet opens with: the suggestion if there is one, else the field as it is.
    private static func startingDraft(context: GameChangeContext, side: TeamSide, suggestion: DefenseSuggestion?) -> [Position: PlayerID] {
        let fielders = suggestion?.fielders ?? context.state(side).fielders
        return Dictionary(fielders.map { ($0.position, $0.player) }, uniquingKeysWith: { first, _ in first })
    }

    /// Who is at each position now, as the situation has it.
    private var current: [Position: PlayerID] {
        Dictionary(context.state(side).fielders.map { ($0.position, $0.player) }, uniquingKeysWith: { first, _ in first })
    }

    /// Positions where the sheet differs from the field now.
    private var changedPositions: [Position] {
        Position.allCases.filter { draft[$0] != current[$0] }
    }

    private var look: TeamLook { context.look(side) }

    public var body: some View {
        SheetFrame(title: purpose == .check ? "Take the field" : "Fielders",
                   subtitle: subtitle,
                   cancelTitle: purpose == .check ? "Later" : "Cancel",
                   onCancel: { onFinish(.cancel) }) {
            if purpose == .changes {
                SegmentedChoice(options: [(TeamSide.away, context.teamName(.away)), (.home, context.teamName(.home))],
                                selection: Binding(get: { side }, set: { switchTeam(to: $0) }))
                    .padding(.bottom, Spacing.medium)
            }
            if let suggestion, !suggestion.reasons.isEmpty, !changedPositions.isEmpty, purpose == .check {
                InfoBox(Text("Set up from the plan for this inning. Check the marked positions, then save."))
            }
            Card {
                ForEach(Array(Position.allCases.enumerated()), id: \.element) { i, position in
                    if i > 0 { RowDivider() }
                    positionRow(position)
                    if openPosition == position {
                        playerPicker(for: position)
                    }
                }
            }
            FootNote("Tap a position to put someone else there. Picking someone already in the field swaps the two.")
        } footer: {
            confirmButton
        }
    }

    private var subtitle: String {
        let half = context.situation.half == .top ? "Top" : "Bottom"
        let team = context.teamName(side)
        return purpose == .check
            ? "\(half) \(ordinal(context.situation.inning)) · \(team): check who is where"
            : "\(team) · move players or bring them in"
    }

    /// One position: its number, who is there, and what changed.
    private func positionRow(_ position: Position) -> some View {
        let player = draft[position]
        let changed = draft[position] != current[position]
        var detail = positionTitle(position)
        if changed {
            if let reason = suggestion?.reasons[position], draft[position] == suggestedPlayer(at: position) {
                detail += " · \(reason)"
            } else {
                detail += " · changed"
            }
            detail += current[position].map { " (was \(context.shortName($0)))" } ?? " (was empty)"
        }
        return OptionRow(title: player.map { context.name($0) } ?? "Nobody",
                         detail: detail,
                         end: openPosition == position ? .close : .swap,
                         isChanged: changed,
                         action: { openPosition = openPosition == position ? nil : position }) {
            PositionCircle(position: position)
        }
        .accessibilityLabel("\(positionTitle(position)): \(player.map { context.name($0) } ?? "nobody")\(changed ? ", changed" : "")")
        .accessibilityHint("Shows players to put here")
    }

    /// The suggestion's player at a position, if any.
    private func suggestedPlayer(at position: Position) -> PlayerID? {
        suggestion?.fielders.first { $0.position == position }?.player
    }

    /// The chips for choosing who plays a position: everyone on the roster except the player
    /// there now, each marked with where they are on the sheet, plus "Nobody".
    private func playerPicker(for position: Position) -> some View {
        let here = draft[position]
        let whereOnSheet = Dictionary(draft.map { ($0.value, $0.key) }, uniquingKeysWith: { first, _ in first })
        return WrappingChips {
            ForEach(context.team(side).roster.filter { $0.id != here }) { player in
                Button {
                    put(player.id, at: position)
                } label: {
                    HStack(spacing: Spacing.extraSmall) {
                        Text(player.lastName)
                        if let at = whereOnSheet[player.id] {
                            Text(at.abbreviation).opacity(0.6)
                        }
                    }
                }
                .buttonStyle(ChipStyle(isOn: false, fill: ScorebookColor.surface))
                .accessibilityLabel("\(player.displayName)\(whereOnSheet[player.id].map { ", now at \($0.name)" } ?? "")")
            }
            if here != nil {
                Button("Nobody") { put(nil, at: position) }
                    .buttonStyle(ChipStyle(isOn: false, fill: ScorebookColor.surface))
                    .accessibilityLabel("Leave \(position.name) empty")
            }
        }
        .padding(.horizontal, Spacing.large - 2)
        .padding(.top, Spacing.small + 2)
        .padding(.bottom, Spacing.large - 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ScorebookColor.surfaceSecondary)
    }

    /// Puts a player at a position on the sheet. Someone already in the field swaps with the
    /// player who was there; someone coming in from the bench sends that player off the field.
    private func put(_ player: PlayerID?, at position: Position) {
        let previous = draft[position]
        if let player, let from = draft.first(where: { $0.value == player })?.key {
            draft[from] = previous
        }
        draft[position] = player
        openPosition = nil
    }

    /// Switches the fielders sheet to the other team, starting again from their field as it is.
    private func switchTeam(to newSide: TeamSide?) {
        guard let newSide, newSide != side else { return }
        side = newSide
        draft = Self.startingDraft(context: context, side: newSide, suggestion: nil)
        openPosition = nil
    }

    @ViewBuilder private var confirmButton: some View {
        let count = changedPositions.count
        if count > 0 {
            Button {
                saveChanges()
            } label: {
                Label("Save \(count) change\(count == 1 ? "" : "s")", systemImage: "checkmark")
            }
            .buttonStyle(PrimaryButtonStyle())
        } else if purpose == .check {
            Button {
                onFinish(.record(EnteredEvent(event: GameEvent(kind: .defenseConfirmed(DefenseConfirmed(team: side))))))
            } label: {
                Label("Everyone’s where they were", systemImage: "checkmark")
            }
            .buttonStyle(TeamButtonStyle(look))
        } else {
            Button("No changes") { onFinish(.cancel) }
                .buttonStyle(SecondaryButtonStyle())
        }
    }

    /// Hands back one substitution with every position that changed. A player moved off the
    /// field with nobody taking their position, and not playing anywhere else, leaves the field.
    private func saveChanges() {
        let assignments = changedPositions.compactMap { position in
            draft[position].map { FielderAssignment(position: position, player: $0) }
        }
        let stillFielding = Set(draft.values)
        let leaving = changedPositions.compactMap { position -> PlayerID? in
            guard draft[position] == nil, let old = current[position], !stillFielding.contains(old) else { return nil }
            return old
        }
        let change = Substitution(team: side, defense: assignments, leavesField: leaving)
        onFinish(.record(EnteredEvent(event: GameEvent(kind: .substitution(change)))))
    }
}
