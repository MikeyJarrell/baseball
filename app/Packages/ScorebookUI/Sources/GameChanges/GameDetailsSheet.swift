// The game details, from the game menu: the date, the scheduled start, how many innings, and
// which team is home, for fixing a mistake made on the pregame screens. Home and away can
// switch only before the first pitch, since the top of the first belongs to the visitors.

import SwiftUI
import Model
import SampleData
import DesignSystem

/// Fix the date, start time, innings, or home and away. Hands back `.changeDetails`.
public struct GameDetailsSheet: View {
    var context: GameChangeContext
    /// True while home and away can still switch: before the first pitch.
    var canSwitch: Bool
    var onFinish: (GameChangeResult) -> Void

    @State private var start: Date
    @State private var innings: Int
    /// The team the scorer has as home: `.home` keeps it, `.away` switches the two.
    @State private var homeTeam: TeamSide?

    /// - Parameters:
    ///   - context: The game's setup and the situation now.
    ///   - canSwitchHomeAndAway: True before the first pitch, from the game session.
    ///   - onFinish: Called once with the new details, or `.cancel`.
    public init(context: GameChangeContext, canSwitchHomeAndAway: Bool,
                onFinish: @escaping (GameChangeResult) -> Void) {
        self.context = context
        self.canSwitch = canSwitchHomeAndAway
        self.onFinish = onFinish
        _start = State(initialValue: context.setup.scheduledStart)
        _innings = State(initialValue: context.setup.scheduledInnings)
        _homeTeam = State(initialValue: .home)
    }

    private var change: GameDetailsChange {
        GameDetailsChange(scheduledStart: start, innings: innings, switchHomeAndAway: homeTeam == .away)
    }

    private var unchanged: Bool {
        start.wholeSecond == context.setup.scheduledStart && innings == context.setup.scheduledInnings && homeTeam == .home
    }

    public var body: some View {
        SheetFrame(title: "Game details", subtitle: "\(context.teamName(.away)) at \(context.teamName(.home))",
                   onCancel: { onFinish(.cancel) }) {
            Card {
                DatePicker("Date", selection: $start, displayedComponents: .date)
                    .font(ScorebookFont.headline)
                    .frame(minHeight: Spacing.minimumTapSize)
                    .padding(.horizontal, Spacing.large - 2)
                RowDivider()
                DatePicker("Start time", selection: $start, displayedComponents: .hourAndMinute)
                    .font(ScorebookFont.headline)
                    .frame(minHeight: Spacing.minimumTapSize)
                    .padding(.horizontal, Spacing.large - 2)
                RowDivider()
                // Never fewer innings than the one being played, which would end the game
                // partway through what is already recorded.
                Stepper(value: $innings, in: max(1, context.situation.inning)...max(15, context.situation.inning)) {
                    Text("\(innings) innings").font(ScorebookFont.headline).monospacedDigit()
                }
                .frame(minHeight: Spacing.minimumTapSize)
                .padding(.horizontal, Spacing.large - 2)
                .accessibilityLabel("Innings")
                .accessibilityValue("\(innings)")
            }

            SectionLabel("Home team")
            SegmentedChoice(options: [(TeamSide.home, context.teamName(.home)), (.away, context.teamName(.away))],
                            selection: $homeTeam)
                .disabled(!canSwitch)
                .opacity(canSwitch ? 1 : 0.5)
            if !canSwitch {
                FootNote("Set before the first pitch only.")
            }
            InfoBox(Text("Once play starts, change the time limit from the game menu."))
        } footer: {
            Button("Save") { onFinish(.changeDetails(change)) }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(unchanged)
        }
    }
}
