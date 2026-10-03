// The game menu: the batting screen's menu for everything that is not a substitution.
// Manual adjustment, an error with nobody moving, the time limit, editing this batter, the
// walk-up song length, and ending the game.

import SwiftUI
import Model
import SampleData
import DesignSystem

/// The game menu. Whatever the scorer does from it comes back through `onFinish`.
public struct GameMenuSheet: View {
    var context: GameChangeContext
    var walkUpSongSeconds: Binding<Double>?
    var now: Date
    var onFinish: (GameChangeResult) -> Void

    /// The page open on top of the menu.
    private enum Item: Hashable {
        case adjustment, error, timeLimit, batter
    }

    @State private var open: Item?
    @State private var askingToEnd = false

    /// - Parameters:
    ///   - context: The game's setup and the situation now.
    ///   - walkUpSongSeconds: The app setting for how much song plays before it fades. Leave it
    ///     out to hide that row.
    ///   - now: The time, for the time limit row. The current time unless a preview says otherwise.
    ///   - onFinish: Called once with what the scorer did, or `.cancel`.
    public init(context: GameChangeContext, walkUpSongSeconds: Binding<Double>? = nil, now: Date = Date(),
                onFinish: @escaping (GameChangeResult) -> Void) {
        self.context = context
        self.walkUpSongSeconds = walkUpSongSeconds
        self.now = now
        self.onFinish = onFinish
    }

    public var body: some View {
        SheetFrame(title: "Game", onCancel: { onFinish(.cancel) }) {
            VStack(alignment: .leading, spacing: 0) {
                Card {
                    row(.adjustment, icon: "slider.horizontal.3", title: "Manual adjustment", detail: "Set outs, count, score or runners")
                    RowDivider()
                    row(.error, icon: "xmark", title: "Error, nobody moved", detail: "Like a dropped foul pop-up")
                    RowDivider()
                    row(.timeLimit, icon: "clock", title: "Time limit", detail: timeLimitDetail)
                    RowDivider()
                    row(.batter, icon: "pencil", title: "Edit this batter", detail: "Name, number, batting side")
                    if let walkUpSongSeconds {
                        RowDivider()
                        songLengthRow(walkUpSongSeconds)
                    }
                }
                Card {
                    OptionRow(title: "End game", detail: "Time limit reached, or the last out", end: .chevron,
                              action: { askingToEnd = true }) {
                        IconBadge(systemName: "flag.checkered", tint: ScorebookColor.out)
                    }
                }
                .padding(.top, Spacing.medium)
            }
            .navigationDestination(item: $open) { item in
                switch item {
                case .adjustment: ManualAdjustmentSheet(context: context, onFinish: onFinish)
                case .error: ErrorSheet(context: context, onFinish: onFinish)
                case .timeLimit: TimeLimitSheet(context: context, now: now, onFinish: onFinish)
                case .batter: BatterSheet(context: context, onFinish: onFinish)
                }
            }
        }
        .confirmationDialog("End the game?", isPresented: $askingToEnd, titleVisibility: .visible) {
            Button("End game: last out or innings complete") { end(.regulation) }
            Button("End game: time limit") { end(.timeLimit) }
            Button("End game: mercy rule") { end(.runRule) }
            Button("End game: called (rain, darkness)") { end(.called) }
        } message: {
            Text(scoreLine)
        }
    }

    /// One item in the menu.
    private func row(_ item: Item, icon: String, title: String, detail: String) -> some View {
        OptionRow(title: title, detail: detail, end: .chevron, action: { open = item }) {
            IconBadge(systemName: icon)
        }
    }

    /// The walk-up song length: how much song plays before it fades by itself.
    private func songLengthRow(_ seconds: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            HStack(spacing: Spacing.medium) {
                IconBadge(systemName: "speaker.wave.2")
                VStack(alignment: .leading, spacing: 2) {
                    Text("Walk-up song length").font(ScorebookFont.headline)
                    Text("Fades by itself after the introduction and this much song")
                        .font(ScorebookFont.caption)
                        .foregroundStyle(ScorebookColor.textSecondary)
                }
            }
            Stepper(value: seconds, in: 4...60, step: 1) {
                Text("\(Int(seconds.wrappedValue)) seconds").font(ScorebookFont.headline).monospacedDigit()
            }
            .accessibilityLabel("Walk-up song length")
            .accessibilityValue("\(Int(seconds.wrappedValue)) seconds")
        }
        .padding(.horizontal, Spacing.large - 2)
        .padding(.vertical, Spacing.small + 2)
    }

    /// "12:05 PM · 1 hr 12 min left".
    private var timeLimitDetail: String {
        guard let end = context.situation.timeLimitEndsAt ?? context.setup.scheduledEnd else { return "No time limit" }
        let minutes = Int((end.timeIntervalSince(now) / 60).rounded(.down))
        let left = minutes >= 0
            ? (minutes >= 60 ? "\(minutes / 60) hr \(minutes % 60) min left" : "\(minutes) min left")
            : "Past the limit"
        return "\(end.formatted(date: .omitted, time: .shortened)) · \(left)"
    }

    /// "Diamond Dogs 5, Mudcats 3".
    private var scoreLine: String {
        let first = context.ourSide ?? .away
        let score = context.situation.score
        return "\(context.teamName(first)) \(score[first]), \(context.teamName(first.opponent)) \(score[first.opponent])"
    }

    /// Records the end of the game, with the score as it stands.
    private func end(_ reason: EndOfGame.Reason) {
        let event = GameEvent(kind: .endOfGame(EndOfGame(reason: reason, finalScore: context.situation.score)))
        onFinish(.record(EnteredEvent(event: event)))
    }
}
