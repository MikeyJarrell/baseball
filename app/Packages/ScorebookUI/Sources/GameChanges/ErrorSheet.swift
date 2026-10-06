// An error with nobody moving, such as a dropped foul pop-up: tap the fielder, and nothing
// else changes. (The foul itself is its own pitch, entered on the batting screen.)

import SwiftUI
import Model
import SampleData
import DesignSystem

/// Charge an error to a fielder with no runner moving. Hands back an `errorWithNoAdvance` event.
public struct ErrorSheet: View {
    var context: GameChangeContext
    var onFinish: (GameChangeResult) -> Void

    @State private var fielder: Position?
    @State private var type: ErrorType?

    /// - Parameters:
    ///   - context: The game's setup and the situation now.
    ///   - onFinish: Called once with the event to record, or `.cancel`.
    public init(context: GameChangeContext, onFinish: @escaping (GameChangeResult) -> Void) {
        self.context = context
        self.onFinish = onFinish
    }

    private var fieldingSide: TeamSide { context.situation.fieldingSide }

    /// Fielders' names under the circles: ours by last name, theirs only when known.
    private var names: [Position: String] {
        Dictionary(context.state(fieldingSide).fielders.map { ($0.position, context.shortName($0.player)) },
                   uniquingKeysWith: { first, _ in first })
    }

    public var body: some View {
        SheetFrame(title: "Error, nobody moved", subtitle: "Like a dropped foul pop-up",
                   onCancel: { onFinish(.cancel) }) {
            FieldDrawing(highlightedPositions: fielder.map { [$0] } ?? [], onTap: { tap in
                if case .position(let position) = tap { fielder = fielder == position ? nil : position }
            })
            .fielderNames(names)
            .errorPositions(fielder.map { [$0] } ?? [])
            .frame(height: 300)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.small)

            InfoBox(Text(fielder.map { position in
                let who = context.state(fieldingSide).fielder(at: position).map { " (\(context.name($0)))" } ?? ""
                return "Error on the \(position.name)\(who): E\(position.number)."
            } ?? "Tap the fielder who made the error."))

            SectionLabel("Kind of error (optional)")
            SegmentedChoice(options: [(ErrorType.fielding, "Fielding"), (.throwing, "Throwing")], selection: $type)
        } footer: {
            Button(fielder.map { "Charge E\($0.number)" } ?? "Tap a fielder") {
                guard let fielder else { return }
                let event = GameEvent(kind: .errorWithNoAdvance(ErrorCharge(fielder: fielder, type: type)))
                onFinish(.record(EnteredEvent(event: event)))
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(fielder == nil)
        }
    }
}
