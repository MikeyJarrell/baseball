// The runner for a designated non-runner. When a designated non-runner reaches base, the app
// opens this sheet by itself (the situation's `runnerChoice` is set) and asks who runs:
//
// 1. the runner the league's rule names (rule 9.11: the team's last recorded out), handed in
//    as `runnerChoice.suggestedRunner`;
// 2. the designated non-runner runs themselves, which records nothing;
// 3. a pinch runner instead, which takes the non-runner out of the batting order (9.11 M);
// 4. "Someone else": anyone on the roster, since the app never enforces the rule.
//
// "Later" closes it without an answer; the choice stays open until the next pitch.

import SwiftUI
import Model
import SampleData
import DesignSystem

/// Who runs for a designated non-runner on base. Hands back a `runnerForNonRunner` event, a
/// pinch-runner substitution, `.nothingToRecord` when they run themselves, or `.cancel` for Later.
public struct NonRunnerSheet: View {
    var context: GameChangeContext
    var onFinish: (GameChangeResult) -> Void

    /// What the scorer has picked.
    private enum Pick: Hashable {
        /// This player runs for the non-runner, who stays in the batting order.
        case runner(PlayerID)
        /// The non-runner runs themselves.
        case themselves
        /// This player pinch-runs, and the non-runner leaves the batting order.
        case pinchRunner(PlayerID)
    }

    @State private var pick: Pick?
    @State private var showPinchRunners = false
    @State private var showEveryone = false

    /// The designated non-runner on base.
    private let nonRunner: PlayerID?

    /// - Parameters:
    ///   - context: The game's setup and the situation just after the non-runner reached.
    ///   - nonRunner: The designated non-runner to ask about. Leave it out to use the one in the
    ///     situation's `runnerChoice`, or else the first designated non-runner standing on base.
    ///   - onFinish: Called once with the answer.
    public init(context: GameChangeContext, nonRunner: PlayerID? = nil, onFinish: @escaping (GameChangeResult) -> Void) {
        self.context = context
        self.onFinish = onFinish
        self.nonRunner = nonRunner ?? context.situation.runnerChoice?.nonRunner ?? Self.nonRunnerOnBase(in: context)
    }

    /// The first runner standing on base for themselves whose batting spot is marked as a
    /// designated non-runner's: read straight from the batting order.
    private static func nonRunnerOnBase(in context: GameChangeContext) -> PlayerID? {
        let side = context.situation.battingSide
        let slots = context.state(side).battingOrder.slots
        return context.situation.runners.first { r in
            r.standingInFor == nil && slots.contains { $0.current == r.runner && $0.isDesignatedNonRunner }
        }?.runner
    }

    private var side: TeamSide { context.situation.battingSide }
    private var look: TeamLook { context.look(side) }
    private var onBase: BaseRunner? { nonRunner.flatMap { id in context.situation.runners.first { $0.runner == id } } }

    /// The league rule's runner, when the situation's question is about this non-runner.
    private var suggested: PlayerID? {
        guard let choice = context.situation.runnerChoice, choice.nonRunner == nonRunner else { return nil }
        return choice.suggestedRunner
    }

    /// Anyone on the roster except the non-runner, the suggested runner, the batter and
    /// players already on base, for "Someone else".
    private var everyoneElse: [Player] {
        let skip = Set([nonRunner, suggested, context.situation.batter].compactMap { $0} + context.situation.runners.map(\.runner))
        return context.team(side).roster.filter { !skip.contains($0.id) }
    }

    public var body: some View {
        let title = nonRunner.map { "Who runs for \(context.shortName($0))?" } ?? "Runner for a non-runner"
        SheetFrame(title: title, subtitle: "A suggestion, by rule 9.11", cancelTitle: "Later",
                   onCancel: { onFinish(.cancel) }) {
            if let nonRunner, let onBase {
                content(nonRunner, onBase)
            } else {
                EmptyNote("No designated non-runner is on base right now. This sheet opens by itself when one reaches.")
            }
        } footer: {
            Button(confirmTitle, action: confirm)
                .buttonStyle(PrimaryButtonStyle())
                .disabled(pick == nil)
        }
    }

    @ViewBuilder private func content(_ nonRunner: PlayerID, _ onBase: BaseRunner) -> some View {
        let short = context.shortName(nonRunner)
        InfoBox(Text("\(Text(context.name(nonRunner)).bold().foregroundStyle(ScorebookColor.textPrimary)) is a designated non-runner and just reached \(baseName(onBase.base)). Pick before the next pitch."))

        Card {
            if let suggested {
                OptionRow(title: context.name(suggested), detail: "The league rule’s pick: the team’s last recorded out",
                          end: .radio(pick == .runner(suggested)), action: { pick = .runner(suggested) }) {
                    PlayerNumberBadge(context.number(suggested), look: look, size: 40)
                }
                RowDivider()
            }
            OptionRow(title: "\(short) runs", detail: "Nobody replaces them",
                      end: .radio(pick == .themselves), action: { pick = .themselves }) {
                PlayerNumberBadge(context.number(nonRunner), look: look, size: 40)
            }
            RowDivider()
            OptionRow(title: "Pinch runner instead", detail: "\(short) leaves the batting order",
                      end: showPinchRunners ? .close : .chevron,
                      action: togglePinchRunners) {
                IconBadge(systemName: "figure.run")
            }
        }

        if showEveryone {
            SectionLabel("Someone else")
            Card {
                ForEach(Array(everyoneElse.enumerated()), id: \.element.id) { i, player in
                    if i > 0 { RowDivider() }
                    PlayerChoiceRow(context: context, player: player.id, detail: "Your call", look: look,
                                    isSelected: pick == .runner(player.id)) { pick = .runner(player.id) }
                }
            }
        } else {
            SomeoneElseButton { showEveryone = true }
        }

        if showPinchRunners {
            SectionLabel("Pinch runner")
            Card {
                let bench = context.bench(side)
                if bench.isEmpty { EmptyNote("Nobody on the bench.") }
                ForEach(Array(bench.enumerated()), id: \.element.id) { i, player in
                    if i > 0 { RowDivider() }
                    PlayerChoiceRow(context: context, player: player.id, detail: "Bench", look: look,
                                    isSelected: pick == .pinchRunner(player.id)) { pick = .pinchRunner(player.id) }
                }
            }
        }

        FootNote("With a runner for \(short), \(short) stays in the batting order, and if the runner scores, the run is \(short)’s. The rule’s runner is the team’s last recorded out; if that player is batting, the out before; in the first inning before any out, the last batter on the lineup card.")
    }

    /// Opens or closes the bench list for a pinch runner.
    private func togglePinchRunners() {
        showPinchRunners.toggle()
        if !showPinchRunners, case .pinchRunner = pick { pick = nil }
    }

    private var confirmTitle: String {
        guard let nonRunner else { return "Pick a runner" }
        let short = context.shortName(nonRunner)
        switch pick {
        case .runner(let id): return "\(context.shortName(id)) runs for \(short)"
        case .themselves: return "\(short) runs"
        case .pinchRunner(let id): return "\(context.shortName(id)) pinch-runs"
        case nil: return "Pick a runner"
        }
    }

    /// Hands back the answer.
    private func confirm() {
        guard let pick, let nonRunner else { return }
        switch pick {
        case .runner(let id):
            let event = GameEvent(kind: .runnerForNonRunner(RunnerForNonRunner(runner: id, replacing: nonRunner)))
            onFinish(.record(EnteredEvent(event: event)))
        case .themselves:
            onFinish(.nothingToRecord)
        case .pinchRunner(let id):
            let change = Substitution(team: side, batting: [BattingChange(kind: .pinchRunner, incoming: id, replacing: nonRunner)])
            onFinish(.record(EnteredEvent(event: GameEvent(kind: .substitution(change)))))
        }
    }
}
