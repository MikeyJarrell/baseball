// "Is the game over?" The pop-up the app shows when a rule says the game could be over (the
// situation's `gameOverQuestion`): the time limit, the mercy rule, or the end of the scheduled
// innings. The app never ends a game by itself; the umpire makes the call. "End game" records
// the end; "Keep playing" records that answer, so the same reason is never asked again.

import SwiftUI
import Model
import SampleData
import DesignSystem

/// Ask whether the game is over. Hands back an `endOfGame` or a `keepPlaying` event; it has no
/// Cancel, since the question needs an answer.
public struct GameOverSheet: View {
    var context: GameChangeContext
    var reason: EndOfGame.Reason
    var onFinish: (GameChangeResult) -> Void

    @Environment(\.dynamicTypeSize) private var textSize

    /// - Parameters:
    ///   - context: The game's setup and the situation now.
    ///   - reason: Why the app is asking. Leave it out for the situation's `gameOverQuestion`.
    ///   - onFinish: Called once with the event to record.
    public init(context: GameChangeContext, reason: EndOfGame.Reason? = nil, onFinish: @escaping (GameChangeResult) -> Void) {
        self.context = context
        self.reason = reason ?? context.situation.gameOverQuestion ?? .regulation
        self.onFinish = onFinish
    }

    private var score: Score { context.situation.score }

    /// "Mudcats 3, Diamond Dogs 5": the visiting team first, as in the newspaper box score.
    private var scoreLine: String {
        "\(context.teamName(.away)) \(score.away), \(context.teamName(.home)) \(score.home)"
    }

    /// Why the app is asking, in a few words.
    private var why: String {
        let rules = context.setup.rules
        switch reason {
        case .timeLimit:
            let limit = context.situation.timeLimitEndsAt.map { ", \($0.formatted(date: .omitted, time: .shortened))" } ?? ""
            let tie = score.away == score.home ? " A tie at the time limit stays a tie (rule 9.1 H)." : ""
            return "Past the time limit\(limit).\(tie)"
        case .runRule:
            let margin = rules.runRuleMargin ?? 12
            return "Mercy rule: \(margin) or more ahead after \(rules.runRuleInning) innings."
        case .regulation:
            return "\(rules.scheduledInnings) innings complete, or the home team ahead in its last at-bat."
        case .called:
            return "Play has stopped."
        }
    }

    public var body: some View {
        SheetFrame(title: "Is the game over?", cancelTitle: nil) {
            Text(scoreLine)
                .font(ScorebookFont.title)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, Spacing.small)
            InfoBox(Text(why))
        } footer: {
            Button("End game") {
                let event = GameEvent(kind: .endOfGame(EndOfGame(reason: reason, finalScore: score)))
                onFinish(.record(EnteredEvent(event: event)))
            }
            .buttonStyle(TeamButtonStyle(.ours))
            Button("Keep playing") {
                onFinish(.record(EnteredEvent(event: GameEvent(kind: .keepPlaying(KeepPlaying(reason: reason))))))
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .interactiveDismissDisabled()
        // Half height normally, so the batting screen shows behind it; full height at the
        // accessibility text sizes, so the explanation is not hidden.
        .presentationDetents(textSize.isAccessibilitySize ? [.large] : [.medium, .large])
    }
}
