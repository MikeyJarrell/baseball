// Runner actions between pitches: stolen base, caught stealing, pickoff, wild pitch, passed
// ball, balk, advance on error, out on appeal, and defensive indifference.
//
// Tapping a runner on the batting screen opens this sheet with that runner chosen. Tap more
// runners for a double steal (one entry for both), then pick what happened. The next page
// shows where each runner most likely ended up, worked out by the function the sheet is
// handed (the rules engine's `suggestRunnerAction`), and the scorer can change any of them.
// A wild pitch, passed ball or balk moves every runner, so it shows every runner. Where a
// fielder made an out, tap the fielders on the field drawing, as in the in-play sequence;
// for an advance on an error, tap the fielder who made it.

import SwiftUI
import Model
import SampleData
import DesignSystem

/// Record what one or more runners did between pitches. Hands back one `runnerAction` event.
public struct RunnerActionSheet: View {
    var context: GameChangeContext
    var suggest: (RunnerMoveReason, [PlayerID]) -> [RunnerMove]
    var followsStrikeout: Bool
    var onFinish: (GameChangeResult) -> Void

    /// The runners the scorer has chosen.
    @State private var chosen: [PlayerID]
    /// What happened, once picked: opens the page that checks where everyone ended up.
    @State private var reason: RunnerMoveReason?
    /// True while the pinch runner sheet is shown on top.
    @State private var pinchRunning = false

    /// - Parameters:
    ///   - context: The game's setup and the situation now.
    ///   - runner: The runner the scorer tapped. Leave it out to start with the lead runner.
    ///   - suggest: Where the runners most likely ended up, for a reason and the runners
    ///     chosen: the rules engine's `suggestRunnerAction(_:runners:in:)` for this situation.
    ///   - followsStrikeout: True when the last event was a strikeout in this half-inning
    ///     (`RunnerActionBuilder.followsStrikeout(log:situation:)`): the sheet then offers
    ///     "same pitch as the strikeout" for a runner put out.
    ///   - onFinish: Called once with the event to record, or `.cancel`.
    public init(context: GameChangeContext, runner: PlayerID? = nil,
                suggest: @escaping (RunnerMoveReason, [PlayerID]) -> [RunnerMove],
                followsStrikeout: Bool = false,
                onFinish: @escaping (GameChangeResult) -> Void) {
        self.context = context
        self.suggest = suggest
        self.followsStrikeout = followsStrikeout
        self.onFinish = onFinish
        let start = runner ?? context.runnersLeadFirst.first?.runner
        _chosen = State(initialValue: start.map { [$0] } ?? [])
    }

    private var title: String {
        guard chosen.count == 1, let id = chosen.first, let r = context.situation.runners.first(where: { $0.runner == id }) else {
            return chosen.isEmpty ? "Runners" : "\(chosen.count) runners"
        }
        return "\(context.shortName(id)) on \(baseName(r.base))"
    }

    public var body: some View {
        SheetFrame(title: title, onCancel: { onFinish(.cancel) }) {
            VStack(alignment: .leading, spacing: 0) {
                if context.situation.runners.isEmpty {
                    EmptyNote("Nobody is on base.")
                } else {
                    chooseRunners
                    actionGrid
                    SectionLabel("Also")
                    Card {
                        OptionRow(title: "Took the base, no throw", detail: "Defensive indifference",
                                  end: .chevron, action: { reason = .defensiveIndifference }) {
                            IconBadge(systemName: "figure.walk")
                        }
                        RowDivider()
                        OptionRow(title: "Pinch runner", end: .chevron, action: { pinchRunning = true }) {
                            IconBadge(systemName: "figure.run")
                        }
                    }
                }
            }
            // The next pages open inside this sheet's own navigation stack.
            .navigationDestination(item: $reason) { reason in
                RunnerActionConfirmPage(context: context, reason: reason, runners: runnersMoving(for: reason),
                                        suggest: suggest, followsStrikeout: followsStrikeout, onFinish: onFinish)
            }
            .navigationDestination(isPresented: $pinchRunning) {
                PinchRunnerSheet(context: context, base: firstChosenBase, onFinish: onFinish)
            }
        }
    }

    /// The runner chips: tap more than one for a double steal.
    @ViewBuilder private var chooseRunners: some View {
        if context.situation.runners.count > 1 {
            SectionLabel("Runners")
            WrappingChips {
                ForEach(context.runnersLeadFirst.reversed(), id: \.base) { r in
                    Button {
                        toggle(r.runner)
                    } label: {
                        Label("\(context.shortName(r.runner)) on \(baseShortName(r.base))",
                              systemImage: chosen.contains(r.runner) ? "checkmark" : "plus")
                    }
                    .buttonStyle(ChipStyle(isOn: chosen.contains(r.runner)))
                }
            }
            FootNote("Double steal? Tap both runners, then pick once.")
        }
    }

    /// The eight actions in two columns, like the mockup.
    private var actionGrid: some View {
        let next = singleRunnerNextBase
        let actions: [(RunnerMoveReason, String, String?)] = [
            (.stolenBase, next.map { "Stole \($0)" } ?? "Stolen base", nil),
            (.caughtStealing, "Caught stealing", "tap the fielders"),
            (.pickoff, "Picked off", "tap the fielders"),
            (.wildPitch, "Wild pitch", "every runner moves"),
            (.passedBall, "Passed ball", "every runner moves"),
            (.balk, "Balk", "every runner moves"),
            (.advanceOnError, "Advanced on error", "tap the fielder"),
            (.outOnAppeal, "Out on appeal", nil),
        ]
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: Spacing.small + 2), GridItem(.flexible())],
                         spacing: Spacing.small + 2) {
            ForEach(actions, id: \.0) { action in
                Button {
                    reason = action.0
                } label: {
                    VStack(spacing: 2) {
                        Text(action.1).font(ScorebookFont.headline)
                        if let hint = action.2 {
                            Text(hint).font(ScorebookFont.caption).foregroundStyle(ScorebookColor.textSecondary)
                        }
                    }
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(ScorebookColor.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: 60)
                    .padding(.horizontal, Spacing.small)
                    .background(ScorebookColor.surface, in: RoundedRectangle(cornerRadius: Spacing.cornerRadius + 2, style: .continuous))
                }
                .buttonStyle(RowPressStyle())
                .disabled(chosen.isEmpty && !movesEveryone(action.0))
            }
        }
        .padding(.top, Spacing.medium)
        // Two buttons share each row, so their words stop growing at a large accessibility
        // size instead of breaking in the middle of a word.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    /// "2nd", "3rd" or "home": the next base for a single chosen runner, for "Stole 3rd".
    private var singleRunnerNextBase: String? {
        guard chosen.count == 1, let r = context.situation.runners.first(where: { $0.runner == chosen[0] }) else { return nil }
        switch r.base {
        case .first: return "2nd"
        case .second: return "3rd"
        case .third: return "home"
        case .home: return nil
        }
    }

    /// The base of the first chosen runner, for the pinch runner sheet.
    private var firstChosenBase: Base? {
        chosen.first.flatMap { id in context.situation.runners.first { $0.runner == id }?.base }
    }

    /// True for the reasons that move every runner on base.
    private func movesEveryone(_ reason: RunnerMoveReason) -> Bool {
        [.wildPitch, .passedBall, .balk].contains(reason)
    }

    /// The runners a reason applies to: everyone for a wild pitch, passed ball or balk, else the chosen ones.
    private func runnersMoving(for reason: RunnerMoveReason) -> [PlayerID] {
        movesEveryone(reason) ? context.runnersLeadFirst.map(\.runner) : chosen
    }

    private func toggle(_ id: PlayerID) {
        if let i = chosen.firstIndex(of: id) { chosen.remove(at: i) } else { chosen.append(id) }
    }
}

/// The second page: where each runner ended up, starting from the suggestion, with fielders
/// tapped on the drawing for any out, and the fielder who made an error.
struct RunnerActionConfirmPage: View {
    var context: GameChangeContext
    var reason: RunnerMoveReason
    var followsStrikeout: Bool
    var onFinish: (GameChangeResult) -> Void

    /// True when the scorer says the out came on the same pitch as the strikeout just before.
    @State private var sameStrikeoutPitch = false
    @State private var moves: [RunnerMove]
    /// The runner whose out the fielder taps go to.
    @State private var activeRunner: PlayerID?
    /// True once the scorer has said there was an error on the play.
    @State private var hasError: Bool
    /// True while fielder taps go to the error instead of to an out.
    @State private var tappingError: Bool
    @State private var errorFielder: Position?
    @State private var errorType: ErrorType?

    init(context: GameChangeContext, reason: RunnerMoveReason, runners: [PlayerID],
         suggest: (RunnerMoveReason, [PlayerID]) -> [RunnerMove], followsStrikeout: Bool = false,
         onFinish: @escaping (GameChangeResult) -> Void) {
        self.context = context
        self.reason = reason
        self.followsStrikeout = followsStrikeout
        self.onFinish = onFinish
        // Start from the suggestion; any chosen runner it left out stays where they are.
        var start = suggest(reason, runners)
        for id in runners where !start.contains(where: { $0.runner == id }) {
            if let r = context.situation.runners.first(where: { $0.runner == id }) {
                start.append(RunnerMove(runner: id, from: r.base, to: .safe(at: r.base), reason: reason))
            }
        }
        for i in start.indices { start[i].reason = reason }
        _moves = State(initialValue: start.sorted { $0.from > $1.from })
        _activeRunner = State(initialValue: start.first { $0.to == .out }?.runner)
        // "Advanced on error" always has an error; any other action can add one.
        _hasError = State(initialValue: reason == .advanceOnError)
        _tappingError = State(initialValue: reason == .advanceOnError)
    }

    var body: some View {
        SheetFrame(title: reasonTitle(reason)) {
            FieldDrawing(
                highlightedPositions: errorFielder.map { [$0] } ?? [],
                tapSequence: activeMove?.outBy ?? [],
                runnerMarkers: moves.map { FieldRunnerMarker($0, label: context.shortName($0.runner)) },
                onTap: tapped
            )
            .fielderNames(fielderNames)
            .battingTeam(context.look(context.situation.battingSide))
            .errorPositions(errorFielder.map { [$0] } ?? [])
            .frame(height: 280)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.small)

            Text(drawingHint)
                .font(ScorebookFont.caption)
                .foregroundStyle(ScorebookColor.textSecondary)
                .frame(maxWidth: .infinity)

            ForEach(moves.indices, id: \.self) { i in
                runnerCard(i)
            }

            if followsStrikeout && moves.contains(where: { $0.to == .out }) {
                SectionLabel("Strikeout")
                Card {
                    Toggle(isOn: $sameStrikeoutPitch) {
                        Text("Same pitch as the strikeout").font(ScorebookFont.headline)
                    }
                    .tint(ScorebookColor.highlight)
                    .padding(.horizontal, Spacing.large - 2)
                    .frame(minHeight: 58)
                }
            }

            SectionLabel("Error")
            if hasError {
                Card {
                    HStack {
                        Text(errorFielder.map { "E\($0.number), \($0.name)" } ?? "Tap the fielder on the drawing")
                            .font(ScorebookFont.headline)
                            .foregroundStyle(errorFielder == nil ? ScorebookColor.textSecondary : ScorebookColor.out)
                        Spacer()
                        if !tappingError {
                            Button("Change") { tappingError = true }
                                .buttonStyle(ChipStyle(isOn: false))
                        }
                        if reason != .advanceOnError {
                            Button("Remove") { removeError() }
                                .buttonStyle(ChipStyle(isOn: false))
                        }
                    }
                    .padding(.horizontal, Spacing.large - 2)
                    .frame(minHeight: 52)
                }
                SegmentedChoice(options: [(ErrorType.fielding, "Fielding"), (.throwing, "Throwing")], selection: $errorType)
                    .padding(.top, Spacing.small)
            } else {
                Card {
                    OptionRow(title: "Add an error",
                              end: .chevron, action: { hasError = true; tappingError = true }) {
                        IconBadge(systemName: "exclamationmark.circle", tint: ScorebookColor.out)
                    }
                }
            }
        } footer: {
            Button(saveTitle, action: save)
                .buttonStyle(PrimaryButtonStyle())
                .disabled(builtAction == nil)
        }
    }

    /// The move the fielder taps go to.
    private var activeMove: RunnerMove? {
        moves.first { $0.runner == activeRunner && $0.to == .out }
    }

    /// Our fielders' names under the circles, when our team is in the field.
    private var fielderNames: [Position: String] {
        let side = context.situation.fieldingSide
        guard context.setup[side].isOurs else { return [:] }
        return Dictionary(context.state(side).fielders.map { ($0.position, context.shortName($0.player)) },
                          uniquingKeysWith: { first, _ in first })
    }

    private var drawingHint: String {
        if tappingError { return "Tap the fielder who made the error." }
        if let active = activeMove { return "Tap the fielders who put \(context.shortName(active.runner)) out, in order." }
        return "Check where each runner ended up."
    }

    /// One runner: where they started, and a button for every place they could have ended up.
    private func runnerCard(_ i: Int) -> some View {
        let move = moves[i]
        let ends: [RunnerEnd] = Base.occupiable.filter { $0 >= move.from }.map { RunnerEnd.safe(at: $0) } + [.scored, .out]
        return VStack(alignment: .leading, spacing: Spacing.small) {
            Text("\(context.name(move.runner)), from \(baseName(move.from))")
                .font(ScorebookFont.headline)
            WrappingChips {
                ForEach(ends, id: \.self) { end in
                    Button(endLabel(end, from: move.from)) { setEnd(end, for: i) }
                        .buttonStyle(ChipStyle(isOn: move.to == end))
                }
            }
            if move.to == .out {
                HStack(spacing: Spacing.small) {
                    Text("Out at").font(ScorebookFont.caption).foregroundStyle(ScorebookColor.textSecondary)
                    ForEach([Base.first, .second, .third, .home], id: \.self) { base in
                        Button(baseShortName(base)) { moves[i].outAt = base }
                            .buttonStyle(ChipStyle(isOn: move.outAt == base))
                    }
                }
                if reason == .pickoff {
                    Toggle(isOn: Binding(get: { moves[i].wasStealing }, set: { moves[i].wasStealing = $0 })) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Picked off while stealing").font(ScorebookFont.headline)
                            Text("Counts as caught stealing").font(ScorebookFont.caption)
                                .foregroundStyle(ScorebookColor.textSecondary)
                        }
                    }
                    .tint(ScorebookColor.highlight)
                    .frame(minHeight: Spacing.minimumTapSize)
                }
                HStack {
                    Text(move.outBy.isEmpty ? "Fielders: none tapped" : "Fielders: \(move.outBy.map(\.description).joined(separator: "-"))")
                        .font(ScorebookFont.notation)
                    Spacer()
                    if activeRunner != move.runner {
                        Button("Tap fielders") { activeRunner = move.runner; tappingError = false }
                            .buttonStyle(ChipStyle(isOn: false))
                    } else if !move.outBy.isEmpty {
                        Button("Clear") { moves[i].outBy = [] }
                            .buttonStyle(ChipStyle(isOn: false))
                    }
                }
            }
        }
        .padding(Spacing.large - 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ScorebookColor.surface, in: RoundedRectangle(cornerRadius: Spacing.cornerRadius + 2, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Spacing.cornerRadius + 2, style: .continuous)
            .strokeBorder(activeRunner == move.runner && move.to == .out ? ScorebookColor.highlight : Color.clear, lineWidth: 2))
        .padding(.top, Spacing.medium)
    }

    /// "Stays", "2nd", "3rd", "Scored", "Out".
    private func endLabel(_ end: RunnerEnd, from: Base) -> String {
        switch end {
        case .scored: return "Scored"
        case .out: return "Out"
        default: return end.base == from ? "Stays" : baseShortName(end.base ?? .home)
        }
    }

    /// Sets where a runner ended up. A runner newly put out gets the next base as where they
    /// were put out, until the scorer says otherwise, and receives the fielder taps.
    private func setEnd(_ end: RunnerEnd, for i: Int) {
        moves[i].to = end
        if end == .out {
            if moves[i].outAt == nil {
                moves[i].outAt = RunnerActionBuilder.defaultOutBase(for: reason, from: moves[i].from)
            }
            activeRunner = moves[i].runner
            tappingError = false
        } else {
            moves[i].outBy = []
            moves[i].outAt = nil
            if activeRunner == moves[i].runner { activeRunner = moves.first { $0.to == .out }?.runner }
        }
    }

    /// A tap on the drawing: a fielder joins the active out (or is charged with the error),
    /// and a runner's marker picks that runner.
    private func tapped(_ tap: FieldTap) {
        switch tap {
        case .position(let position):
            if tappingError {
                errorFielder = position
                // Once the error is placed, further taps go back to any out.
                tappingError = false
            } else if let i = moves.firstIndex(where: { $0.runner == activeRunner && $0.to == .out }) {
                // Tapping the last fielder again takes them back off, as in the in-play sequence.
                if moves[i].outBy.last == position { moves[i].outBy.removeLast() } else { moves[i].outBy.append(position) }
            }
        case .runner(let id):
            if moves.contains(where: { $0.runner == id && $0.to == .out }) { activeRunner = id }
        default:
            break
        }
    }

    /// The error entered, if any.
    private var errors: [ErrorCharge] {
        guard hasError, let errorFielder else { return [] }
        return [ErrorCharge(fielder: errorFielder, type: errorType)]
    }

    /// The event as it stands (see `RunnerActionBuilder.action`): nothing when no runner moved.
    private var builtAction: RunnerAction? {
        RunnerActionBuilder.action(moves: moves, picked: reason, errors: errors, sameStrikeoutPitch: followsStrikeout && sameStrikeoutPitch)
    }

    /// "Save", or "Save without fielders" when an out or the error has nobody tapped.
    private var saveTitle: String {
        let missing = RunnerActionBuilder.outsMissingFielders(moves) || (hasError && errorFielder == nil)
        return missing ? "Save without fielders" : "Save"
    }

    /// Takes the error back off.
    private func removeError() {
        hasError = false
        tappingError = false
        errorFielder = nil
        errorType = nil
    }

    /// Hands back the runner action.
    private func save() {
        guard let action = builtAction else { return }
        onFinish(.record(EnteredEvent(event: GameEvent(kind: .runnerAction(action)))))
    }
}

/// The name of a runner action for a page title: "Caught stealing".
func reasonTitle(_ reason: RunnerMoveReason) -> String {
    switch reason {
    case .stolenBase: "Stolen base"
    case .caughtStealing: "Caught stealing"
    case .pickoff: "Picked off"
    case .wildPitch: "Wild pitch"
    case .passedBall: "Passed ball"
    case .balk: "Balk"
    case .advanceOnError: "Advanced on error"
    case .defensiveIndifference: "Defensive indifference"
    case .outOnAppeal: "Out on appeal"
    case .other: "Runner moved"
    }
}
