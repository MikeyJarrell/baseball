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

    /// "Diamond Dogs 5, Mudcats 3": our team first when one team is ours.
    private var scoreLine: String {
        let first = context.ourSide ?? .away
        return "\(context.teamName(first)) \(score[first]), \(context.teamName(first.opponent)) \(score[first.opponent])"
    }

    /// Why the app is asking, in words, with the rule.
    private var why: String {
        let rules = context.setup.rules
        switch reason {
        case .timeLimit:
            let limit = context.situation.timeLimitEndsAt.map { ", \($0.formatted(date: .omitted, time: .shortened))," } ?? ""
            let tie = score.away == score.home ? " A tie at the time limit stays a tie (rule 9.1 H)." : ""
            return "The time limit\(limit) has passed and the inning is over. No new inning starts after the limit (rule 9.1 G).\(tie)"
        case .runRule:
            let margin = rules.runRuleMargin ?? 12
            return "A \(margin)-run lead from the end of the \(ordinal(rules.runRuleInning)) inning on ends the game under the mercy rule (rule 9.13)."
        case .regulation:
            return "The scheduled \(rules.scheduledInnings) innings are complete, or the home team has taken the lead in its last at-bat."
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
            InfoBox(Text("\(why) The umpire makes the call; the app only asks."))
            FootNote("Keep playing carries on, and the app will not ask again for this reason.")
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
        .presentationDetents([.medium, .large])
    }
}
