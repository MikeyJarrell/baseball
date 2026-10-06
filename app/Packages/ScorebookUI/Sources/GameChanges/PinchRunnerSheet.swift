// The pinch runner sheet: tap the runner, choose the replacement. A pinch runner takes over
// the replaced runner's spot in the batting order for good. (Someone running for a designated
// non-runner, who leaves the batting order as it was, is the non-runner sheet instead.)

import SwiftUI
import Model
import SampleData
import DesignSystem

/// Put in a pinch runner. Hands back a substitution: the new runner takes the replaced
/// runner's place on base and in the batting order.
public struct PinchRunnerSheet: View {
    var context: GameChangeContext
    var side: TeamSide
    var onFinish: (GameChangeResult) -> Void

    @State private var base: Base?
    @State private var pick: PlayerID?
    @State private var showEveryone = false

    /// - Parameters:
    ///   - context: The game's setup and the situation now.
    ///   - base: The runner to replace, by base. Leave it out to start with the lead runner.
    ///   - onFinish: Called once with the event to record, or `.cancel`.
    public init(context: GameChangeContext, base: Base? = nil, onFinish: @escaping (GameChangeResult) -> Void) {
        self.context = context
        self.side = context.situation.battingSide
        self.onFinish = onFinish
        _base = State(initialValue: base ?? context.runnersLeadFirst.first?.base)
    }

    private var look: TeamLook { context.look(side) }
    private var runner: BaseRunner? { base.flatMap { context.situation.runner(on: $0) } }

    /// Everyone not on the bench and not the runner, for "Someone else".
    private var everyoneElse: [Player] {
        let listed = Set(context.bench(side).map(\.id) + [runner?.runner].compactMap { $0 })
        return context.team(side).roster.filter { !listed.contains($0.id) }
    }

    public var body: some View {
        SheetFrame(title: "Pinch runner", subtitle: "\(context.teamName(side)) batting",
                   onCancel: { onFinish(.cancel) }) {
            if context.situation.runners.isEmpty {
                EmptyNote("Nobody is on base.")
            } else {
                SectionLabel("Replace")
                WrappingChips {
                    ForEach(context.runnersLeadFirst.reversed(), id: \.base) { r in
                        Button("\(context.shortName(r.runner)) on \(baseShortName(r.base))") { base = r.base }
                            .buttonStyle(ChipStyle(isOn: base == r.base))
                    }
                }
                if let runner, let explanation = explanation(for: runner) {
                    InfoBox(explanation)
                }

                SectionLabel("Runner")
                Card {
                    let bench = context.bench(side)
                    if bench.isEmpty { EmptyNote("Nobody on the bench.") }
                    ForEach(Array(bench.enumerated()), id: \.element.id) { i, player in
                        if i > 0 { RowDivider() }
                        PlayerChoiceRow(context: context, player: player.id, detail: nil, look: look,
                                        isSelected: pick == player.id) { pick = player.id }
                    }
                }

                if showEveryone {
                    SectionLabel("Someone else")
                    Card {
                        ForEach(Array(everyoneElse.enumerated()), id: \.element.id) { i, player in
                            if i > 0 { RowDivider() }
                            PlayerChoiceRow(context: context, player: player.id, detail: whereNow(player.id),
                                            look: look, isSelected: pick == player.id) { pick = player.id }
                        }
                    }
                } else if !everyoneElse.isEmpty {
                    SomeoneElseButton { showEveryone = true }
                }
            }
        } footer: {
            Button(pick.map { "\(context.shortName($0)) runs" } ?? "Pick a runner", action: confirm)
                .buttonStyle(PrimaryButtonStyle())
                .disabled(pick == nil || runner == nil)
        }
    }

    /// What a pinch runner does to the batting order, for a runner tied to a designated
    /// non-runner; nothing for an ordinary runner.
    private func explanation(for runner: BaseRunner) -> Text? {
        let name = Text(context.shortName(runner.runner)).bold().foregroundStyle(ScorebookColor.textPrimary)
        if let nonRunner = runner.standingInFor {
            // The runner is already running for a designated non-runner [9.11 N].
            return Text("The new runner takes \(name)’s batting spot and keeps running for \(context.shortName(nonRunner)).")
        }
        if let spot = context.battingSpot(of: runner.runner, side),
           context.state(side).battingOrder.slots[spot].isDesignatedNonRunner {
            // A pinch runner for a designated non-runner takes them out of the order [9.11 M].
            return Text("A pinch runner takes \(name) out of the batting order. To keep them in, use Runner for a non-runner.")
        }
        return nil
    }

    /// Where a player is now: "Bats 4th", "Playing shortstop", "Left the game".
    private func whereNow(_ id: PlayerID) -> String {
        if let at = context.battingSpot(of: id, side) { return "Bats \(ordinal(at + 1))" }
        if let position = context.state(side).position(of: id) { return "Playing \(position.name)" }
        if context.leftTheGame(side).contains(id) { return "Left the game" }
        return "Not batting"
    }

    /// Builds the substitution and hands it back.
    private func confirm() {
        guard let pick, let runner else { return }
        let change = Substitution(team: side, batting: [BattingChange(kind: .pinchRunner, incoming: pick, replacing: runner.runner)])
        onFinish(.record(EnteredEvent(event: GameEvent(kind: .substitution(change)))))
    }
}
