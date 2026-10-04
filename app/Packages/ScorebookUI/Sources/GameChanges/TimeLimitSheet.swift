// The time limit: no new inning starts after this time (rule 9.1 G). The app sets it from the
// first pitch; the plate umpire keeps the official time (9.1 B) and can extend it (9.1 I), so
// the scorer nudges it to match.

import SwiftUI
import Model
import SampleData
import DesignSystem

/// Match the time limit to the umpire's. Hands back a `timeLimitChange` event.
public struct TimeLimitSheet: View {
    var context: GameChangeContext
    var now: Date
    var onFinish: (GameChangeResult) -> Void

    @State private var endsAt: Date?

    /// - Parameters:
    ///   - context: The game's setup and the situation now.
    ///   - now: The time to count from, for "1 hr 12 min left". The current time unless a
    ///     preview says otherwise.
    ///   - onFinish: Called once with the event to record, or `.cancel`.
    public init(context: GameChangeContext, now: Date = Date(), onFinish: @escaping (GameChangeResult) -> Void) {
        self.context = context
        self.now = now
        self.onFinish = onFinish
        _endsAt = State(initialValue: context.situation.timeLimitEndsAt ?? context.setup.scheduledEnd)
    }

    /// The limit as the book has it now.
    private var original: Date? { context.situation.timeLimitEndsAt ?? context.setup.scheduledEnd }

    public var body: some View {
        SheetFrame(title: "Time limit", subtitle: context.situation.gameStartedAt == nil ? "Before the first pitch" : nil,
                   onCancel: { onFinish(.cancel) }) {
            if let endsAt {
                Text(clock(endsAt))
                    .font(ScorebookFont.scoreboard)
                    .frame(maxWidth: .infinity)
                    .padding(.top, Spacing.small)
                    .accessibilityLabel("Time limit \(clock(endsAt))")
                Text("\(timeLeft(until: endsAt)) · now \(clock(now))")
                    .font(ScorebookFont.body)
                    .foregroundStyle(ScorebookColor.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, Spacing.medium)

                HStack(spacing: Spacing.small) {
                    ForEach([-5, -1, 1, 5], id: \.self) { minutes in
                        Button(minutes < 0 ? "−\(-minutes) min" : "+\(minutes) min") {
                            self.endsAt = endsAt.addingTimeInterval(Double(minutes * 60))
                        }
                        .buttonStyle(PlainActionButtonStyle())
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel(minutes < 0 ? "\(-minutes) minutes earlier" : "\(minutes) minutes later")
                    }
                }

                InfoBox(Text("No new inning starts after this time (rule 9.1 G). The app set it to \(limitLength) after the first pitch; match it to the plate umpire, who keeps the official time."))

                if context.situation.gameStartedAt != nil {
                    Button("Go back to \(limitLength) after the first pitch") {
                        let event = GameEvent(kind: .timeLimitChange(TimeLimitChange(endsAt: nil)))
                        onFinish(.record(EnteredEvent(event: event)))
                    }
                    .buttonStyle(PlainActionButtonStyle())
                    .frame(maxWidth: .infinity)
                }
            } else {
                EmptyNote("This game has no time limit.")
            }
        } footer: {
            Button(endsAt.map { "Set to \(clock($0))" } ?? "Done") {
                guard let endsAt, endsAt != original else { onFinish(.cancel); return }
                onFinish(.record(EnteredEvent(event: GameEvent(kind: .timeLimitChange(TimeLimitChange(endsAt: endsAt))))))
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(endsAt == original)
        }
    }

    /// "12:05 PM".
    private func clock(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    /// "1 hr 12 min left", or "Past the limit by 4 min".
    private func timeLeft(until end: Date) -> String {
        let minutes = Int((end.timeIntervalSince(now) / 60).rounded(.down))
        let length = { (m: Int) -> String in
            m >= 60 ? "\(m / 60) hr \(m % 60) min" : "\(m) min"
        }
        return minutes >= 0 ? "\(length(minutes)) left" : "Past the limit by \(length(-minutes))"
    }

    /// "three hours", "3 hours 15 minutes": the setup's time limit in words.
    private var limitLength: String {
        let minutes = context.setup.timeLimitMinutes ?? 180
        if minutes == 180 { return "three hours" }
        let hours = minutes / 60, rest = minutes % 60
        return rest == 0 ? "\(hours) hours" : "\(hours) hours \(rest) minutes"
    }
}
