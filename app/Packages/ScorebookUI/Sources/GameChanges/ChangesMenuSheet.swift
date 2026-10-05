// The changes menu: what the batting screen's one big substitution button opens. A short
// list of every kind of change, each opening its own sheet inside this one: lineups and
// rosters (fixing names, numbers and who batted where), pitcher, fielders, pinch hitter, pinch
// runner, runner for a designated non-runner, add a hitter.

import SwiftUI
import Model
import SampleData
import DesignSystem

/// The list of changes. Whatever sheet the scorer opens from it hands its result back
/// through this menu's `onFinish`; the back arrow returns to the list without recording.
public struct ChangesMenuSheet: View {
    var context: GameChangeContext
    var onFinish: (GameChangeResult) -> Void

    /// The sheet open on top of the list.
    private enum Item: Hashable {
        case lineups, pitcher, fielders, pinchHitter, pinchRunner, nonRunner, addHitter
    }

    @State private var open: Item?

    /// - Parameters:
    ///   - context: The game's setup and the situation now.
    ///   - onFinish: Called once with whatever the chosen sheet hands back, or `.cancel`.
    public init(context: GameChangeContext, onFinish: @escaping (GameChangeResult) -> Void) {
        self.context = context
        self.onFinish = onFinish
    }

    private var situation: Situation { context.situation }

    public var body: some View {
        SheetFrame(title: "Changes", subtitle: "\(context.teamName(situation.battingSide)) batting",
                   onCancel: { onFinish(.cancel) }) {
            Card {
                row(.lineups, icon: "list.number", title: "Lineups and rosters",
                    detail: "Fix names, numbers, who batted where; add players")
            }
            .padding(.bottom, Spacing.medium)
            Card {
                row(.pitcher, icon: "baseball", title: "Pitching change", detail: pitcherDetail)
                RowDivider()
                row(.fielders, icon: "shield.lefthalf.filled", title: "Fielders", detail: "Move players or bring them in")
                RowDivider()
                row(.pinchHitter, icon: "hand.raised", title: "Pinch hitter",
                    detail: situation.batter.map { "Bat for \(context.shortName($0))" } ?? "Nobody is up")
                RowDivider()
                row(.pinchRunner, icon: "figure.run", title: "Pinch runner",
                    detail: situation.runners.isEmpty ? "Nobody is on base" : "Takes over a runner’s spot in the order")
                RowDivider()
                row(.nonRunner, icon: "figure.run.circle", title: "Runner for a non-runner",
                    detail: "For a designated non-runner on base")
                RowDivider()
                row(.addHitter, icon: "person.badge.plus", title: "Add a hitter", detail: "To the bottom of the order")
            }
            .navigationDestination(item: $open) { item in
                switch item {
                case .lineups: LineupsSheet(context: context, onFinish: onFinish)
                case .pitcher: PitchingChangeSheet(context: context, onFinish: onFinish)
                case .fielders: DefenseSheet(context: context, purpose: .changes, onFinish: onFinish)
                case .pinchHitter: PinchHitterSheet(context: context, onFinish: onFinish)
                case .pinchRunner: PinchRunnerSheet(context: context, onFinish: onFinish)
                case .nonRunner: NonRunnerSheet(context: context, onFinish: onFinish)
                case .addHitter: AddHitterSheet(context: context, onFinish: onFinish)
                }
            }
        }
    }

    /// "Sky Barros has thrown 57".
    private var pitcherDetail: String {
        guard let pitcher = situation.pitcher else { return "Nobody is pitching yet" }
        let pitches = situation.tally(for: pitcher)?.pitches ?? 0
        return "\(context.name(pitcher)) has thrown \(pitches)"
    }

    /// One item in the list.
    private func row(_ item: Item, icon: String, title: String, detail: String) -> some View {
        OptionRow(title: title, detail: detail, end: .chevron, action: { open = item }) {
            IconBadge(systemName: icon)
        }
    }
}
