// The manual adjustment: set outs, count, score, runners and who is up directly, for when the
// field and the book disagree and nobody can say why. It overrides the book, so the sheet says
// so plainly. Only what the scorer changes goes into the event; everything else stays as the
// rules engine has it.

import SwiftUI
import Model
import SampleData
import DesignSystem

/// Set parts of the situation by hand. Hands back a `manualAdjustment` event.
public struct ManualAdjustmentSheet: View {
    var context: GameChangeContext
    var onFinish: (GameChangeResult) -> Void

    @State private var outs: Int?
    @State private var balls: Int?
    @State private var strikes: Int?
    @State private var awayRuns: Int
    @State private var homeRuns: Int
    @State private var onFirst: PlayerID?
    @State private var onSecond: PlayerID?
    @State private var onThird: PlayerID?
    @State private var batterIndex: Int
    @State private var note = ""

    /// - Parameters:
    ///   - context: The game's setup and the situation now; the sheet starts from it.
    ///   - onFinish: Called once with the event to record, or `.cancel`.
    public init(context: GameChangeContext, onFinish: @escaping (GameChangeResult) -> Void) {
        self.context = context
        self.onFinish = onFinish
        let s = context.situation
        _outs = State(initialValue: s.outs)
        _balls = State(initialValue: s.count.balls)
        _strikes = State(initialValue: s.count.strikes)
        _awayRuns = State(initialValue: s.score.away)
        _homeRuns = State(initialValue: s.score.home)
        _onFirst = State(initialValue: s.baseOccupants.first)
        _onSecond = State(initialValue: s.baseOccupants.second)
        _onThird = State(initialValue: s.baseOccupants.third)
        _batterIndex = State(initialValue: s[s.battingSide].nextBatterIndex)
    }

    private var situation: Situation { context.situation }
    private var battingSide: TeamSide { situation.battingSide }

    /// The adjustment, holding only what differs from the book.
    private var adjustment: ManualAdjustment {
        var a = ManualAdjustment()
        if let outs, outs != situation.outs { a.outs = outs }
        let count = Count(balls: balls ?? 0, strikes: strikes ?? 0)
        if count != situation.count { a.count = count }
        let score = Score(away: awayRuns, home: homeRuns)
        if score != situation.score { a.score = score }
        let runners = BaseOccupants(first: onFirst, second: onSecond, third: onThird)
        if runners != situation.baseOccupants { a.runners = runners }
        if batterIndex != situation[battingSide].nextBatterIndex { a.batterIndex = batterIndex }
        let trimmed = note.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { a.note = trimmed }
        return a
    }

    /// True when something other than the note would change.
    private var changesSomething: Bool {
        var a = adjustment
        a.note = nil
        return a != ManualAdjustment()
    }

    public var body: some View {
        SheetFrame(title: "Manual adjustment", subtitle: "\(situation.half == .top ? "Top" : "Bottom") \(ordinal(situation.inning))",
                   onCancel: { onFinish(.cancel) }) {
            WarningBox(Text("This overrides the book. Use it only when the field and the book disagree and nobody can say why. Runs added here go to the team in this inning, credited to no player and charged to no pitcher."))

            SectionLabel("Outs")
            SegmentedChoice(options: [(0, "0"), (1, "1"), (2, "2")], selection: $outs)

            SectionLabel("Count")
            HStack(spacing: Spacing.medium) {
                VStack(alignment: .leading, spacing: Spacing.extraSmall) {
                    Text("Balls").font(ScorebookFont.caption).foregroundStyle(ScorebookColor.textSecondary)
                    SegmentedChoice(options: [(0, "0"), (1, "1"), (2, "2"), (3, "3")], selection: $balls)
                }
                VStack(alignment: .leading, spacing: Spacing.extraSmall) {
                    Text("Strikes").font(ScorebookFont.caption).foregroundStyle(ScorebookColor.textSecondary)
                    SegmentedChoice(options: [(0, "0"), (1, "1"), (2, "2")], selection: $strikes)
                }
            }

            SectionLabel("Score")
            Card {
                scoreRow(.away, runs: $awayRuns)
                RowDivider()
                scoreRow(.home, runs: $homeRuns)
            }

            SectionLabel("Runners (\(context.teamName(battingSide)))")
            Card {
                runnerRow(.third, $onThird)
                RowDivider()
                runnerRow(.second, $onSecond)
                RowDivider()
                runnerRow(.first, $onFirst)
            }

            SectionLabel("Up to bat")
            Card {
                Menu {
                    ForEach(Array(situation[battingSide].battingOrder.slots.enumerated()), id: \.offset) { i, slot in
                        Button("\(ordinal(i + 1)): \(context.name(slot.current))") { batterIndex = i }
                    }
                } label: {
                    pickerLabel(title: "\(ordinal(batterIndex + 1)) in the order",
                                value: context.name(situation[battingSide].battingOrder.slots[safe: batterIndex]?.current))
                }
            }

            SectionLabel("Why (optional)")
            LabeledField(label: "Note", placeholder: "Umpire’s count was 2–1", text: $note)
        } footer: {
            Button("Save adjustment") {
                onFinish(.record(EnteredEvent(event: GameEvent(kind: .manualAdjustment(adjustment)))))
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!changesSomething)
        }
    }

    /// One team's runs, with minus and plus buttons.
    private func scoreRow(_ side: TeamSide, runs: Binding<Int>) -> some View {
        HStack {
            Text(context.teamName(side)).font(ScorebookFont.headline)
            Spacer()
            Stepper(value: runs, in: 0...99) {
                Text("\(runs.wrappedValue)")
                    .font(ScorebookFont.scoreboardSmall)
                    .frame(minWidth: 44, alignment: .trailing)
            }
            .fixedSize()
            .accessibilityLabel("\(context.teamName(side)) runs")
            .accessibilityValue("\(runs.wrappedValue)")
        }
        .padding(.horizontal, Spacing.large - 2)
        .frame(minHeight: 58)
    }

    /// Who is on one base: nobody, or one of the batting team's players.
    private func runnerRow(_ base: Base, _ runner: Binding<PlayerID?>) -> some View {
        Menu {
            Button("Nobody") { runner.wrappedValue = nil }
            ForEach(battingTeamPlayers, id: \.self) { id in
                Button(context.name(id)) { runner.wrappedValue = id }
            }
        } label: {
            pickerLabel(title: "On \(baseName(base))", value: runner.wrappedValue.map { context.name($0) } ?? "Nobody")
        }
    }

    /// The batting team's hitters in order, then the rest of their roster.
    private var battingTeamPlayers: [PlayerID] {
        let order = situation[battingSide].battingOrder.slots.compactMap(\.current)
        let rest = context.team(battingSide).roster.map(\.id).filter { !order.contains($0) }
        return order + rest
    }

    /// A row showing a choice that opens a menu.
    private func pickerLabel(title: String, value: String) -> some View {
        HStack {
            Text(title).font(ScorebookFont.headline).foregroundStyle(ScorebookColor.textPrimary)
            Spacer()
            Text(value).font(ScorebookFont.body).foregroundStyle(ScorebookColor.textSecondary)
            Image(systemName: "chevron.up.chevron.down").foregroundStyle(ScorebookColor.textSecondary)
        }
        .padding(.horizontal, Spacing.large - 2)
        .frame(minHeight: 52)
        .contentShape(Rectangle())
    }
}

fileprivate extension Array {
    /// The element at an index, or nothing when the index is past either end.
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
