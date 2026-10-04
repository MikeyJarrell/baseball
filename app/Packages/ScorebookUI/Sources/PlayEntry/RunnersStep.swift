// The last step: where every runner, batter included, ended up. Each runner starts at the
// base the rules engine suggests, with an arrow on the drawing from where they started. A row
// of base buttons under the drawing changes any runner in one tap; the small dot marks the
// rules engine's guess. The outs, runs and runs batted in on the play show at the top, and
// "Inning over" when the play makes the third out.
//
// A runner the scorer moves further than the play carried them, on any kind of play, gets a
// question: how did they get there, on the throw (or on the play, for a runner already on
// base) or on an error, and whose? A single plus the left fielder's error reads "1B 7, E7";
// a fly to right with the runner scoring on the right fielder's bad throw, "F9, E9".
// A runner the scorer puts out who was not suggested out gets "Who made the out?". Save
// waits until both questions are answered, and refuses two runners on one base.

import SwiftUI
import Model
import DesignSystem

/// Where every runner ended up, for a glance and a save.
struct RunnersStep: View {
    let model: PlayEntryModel

    var body: some View {
        let preview = model.preview
        ScrollView {
            VStack(spacing: Spacing.small) {
                summary(preview)
                FieldDrawing(runnerMarkers: model.draft.runners.map { FieldRunnerMarker($0, label: model.name(of: $0.runner)) },
                             onTap: { tap in
                                 if case .runner(let runner) = tap { model.perform(.cycleRunner(runner)) }
                             })
                    .zoom(.infield)
                    .battingTeam(model.battingLook)
                    .frame(maxHeight: 230)
                    .padding(.horizontal, Spacing.screenEdge)
                Text("Dot = the app’s guess. Tap any base to change it.")
                    .font(ScorebookFont.caption)
                    .foregroundStyle(ScorebookColor.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Spacing.large)
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                VStack(spacing: 6) {
                    ForEach(model.draft.runners, id: \.runner) { move in
                        RunnerRow(model: model, move: move)
                        if model.needsOutFielders(move.runner) {
                            OutQuestion(model: model, move: move)
                        }
                        if model.asksHow(move.runner) {
                            ExtraBaseQuestion(model: model, move: move)
                        }
                    }
                }
                .padding(.horizontal, Spacing.screenEdge)
                .padding(.bottom, Spacing.medium)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BottomBar(title: bottomTitle(preview), detail: bottomDetail(preview), problem: model.runnerProblem) {
                SaveButton(enabled: model.canSave) { model.perform(.save) }
            }
        }
    }

    /// The card at the top: the notation, the outs and runs on the play, and the runs batted in.
    private func summary(_ preview: PlayPreview) -> some View {
        HStack(spacing: Spacing.medium) {
            VStack(alignment: .leading, spacing: 2) {
                Text(preview.notation.isEmpty ? " " : preview.notation)
                    .font(ScorebookFont.scoreboardSmall)
                    .foregroundStyle(ScorebookColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text("\(PlayWords.outs(preview.outsOnPlay)) and \(PlayWords.runs(preview.runsOnPlay)) on the play")
                    .font(ScorebookFont.caption)
                    .foregroundStyle(ScorebookColor.textSecondary)
                if preview.endsHalfInning {
                    InningOverTag()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            VStack(spacing: 2) {
                Text("RUNS BATTED IN")
                    .font(ScorebookFont.sectionLabel)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(ScorebookColor.textSecondary)
                HStack(spacing: 0) {
                    stepperButton("minus", label: "Fewer runs batted in", change: -1)
                    Text("\(model.rbi)")
                        .font(ScorebookFont.headline.monospacedDigit())
                        .foregroundStyle(ScorebookColor.textPrimary)
                        .frame(minWidth: 34)
                        .accessibilityLabel(Text("\(model.rbi) runs batted in"))
                    stepperButton("plus", label: "More runs batted in", change: 1)
                }
                .background(ScorebookColor.surfaceSecondary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .padding(Spacing.medium)
        .background(ScorebookColor.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, Spacing.screenEdge)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    /// The minus or plus beside the runs batted in.
    private func stepperButton(_ symbol: String, label: String, change: Int) -> some View {
        Button { model.perform(.changeRBI(by: change)) } label: {
            Image(systemName: symbol)
                .font(ScorebookFont.headline)
                .foregroundStyle(ScorebookColor.textPrimary)
                .frame(width: Spacing.minimumTapSize, height: Spacing.minimumTapSize)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(Text(label))
    }

    /// The bold line in the bottom bar: the outs after the play.
    private func bottomTitle(_ preview: PlayPreview) -> String {
        preview.endsHalfInning ? "Three outs" : "\(PlayWords.outs(preview.outsAfter)) after this"
    }

    /// The line under it: what saving does next.
    private func bottomDetail(_ preview: PlayPreview) -> String {
        if preview.endsHalfInning { return "Saving switches sides" }
        if preview.endsGame { return "Home team ahead: the app asks if the game is over" }
        return "Then the next batter is up"
    }
}

/// One runner's row: who they are, where they started, and a button for every place they
/// could have ended up. The picked one is filled; a dot marks the rules engine's guess.
struct RunnerRow: View {
    let model: PlayEntryModel
    let move: RunnerMove

    var body: some View {
        let suggested = model.firstMoves[move.runner]?.to
        HStack(spacing: Spacing.small) {
            VStack(alignment: .leading, spacing: 0) {
                Text(model.name(of: move.runner))
                    .font(ScorebookFont.headline)
                    .foregroundStyle(ScorebookColor.textPrimary)
                Text(move.isBatter ? "Batter" : "Was on \(move.from.shortLabel)")
                    .font(ScorebookFont.caption)
                    .foregroundStyle(ScorebookColor.textSecondary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(width: 84, alignment: .leading)
            HStack(spacing: 3) {
                ForEach(model.choices(for: move), id: \.self) { end in
                    baseButton(end, isPicked: move.to == end, isSuggested: suggested == end)
                }
            }
            .padding(3)
            .background(ScorebookColor.surfaceSecondary, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(model.name(of: move.runner)))
    }

    /// One base button: "1st", "2nd", "3rd", "Home" or "Out".
    private func baseButton(_ end: RunnerEnd, isPicked: Bool, isSuggested: Bool) -> some View {
        let fill = end == .out ? ScorebookColor.out : ScorebookColor.highlight
        return Button { model.perform(.moveRunner(move.runner, to: end)) } label: {
            Text(end.buttonLabel)
                .font(ScorebookFont.chip)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(isPicked ? Color.white : ScorebookColor.textPrimary)
                .frame(maxWidth: .infinity, minHeight: Spacing.minimumTapSize)
                .overlay(alignment: .bottom) {
                    // The rules engine's guess: a solid dot, big enough to see in sun.
                    if isSuggested {
                        Circle().frame(width: 7, height: 7).padding(.bottom, 3)
                            .foregroundStyle(isPicked ? Color.white : ScorebookColor.textPrimary)
                    }
                }
                .background(isPicked ? fill : Color.clear, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(end == .scored ? "Scored" : end.buttonLabel))
        .accessibilityValue(Text(isSuggested ? "suggested" : ""))
        .accessibilityAddTraits(isPicked ? .isSelected : [])
    }
}

/// "How did they get to 2nd?": on the throw (on the hit, for a runner already on base) or on
/// an error, and if an error, whose.
struct ExtraBaseQuestion: View {
    let model: PlayEntryModel
    let move: RunnerMove

    var body: some View {
        let answer = model.extraBaseAnswer(for: move.runner)
        VStack(alignment: .leading, spacing: 6) {
            Text("How did \(model.name(of: move.runner)) get \(move.to == .scored ? "home" : "to \(move.to.sentenceLabel)")?")
                .font(ScorebookFont.chip)
            HStack(spacing: 3) {
                segment(move.isBatter ? "On the throw" : (model.isHit ? "On the hit" : "On the play"), isPicked: answer == .onThePlay) {
                    model.perform(.answerExtraBase(move.runner, onError: false))
                }
                segment("On an error", isPicked: answer.isError) {
                    model.perform(.answerExtraBase(move.runner, onError: true))
                }
            }
            .padding(3)
            .background(ScorebookColor.surfaceSecondary, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            if answer.isError {
                Text("Whose error?")
                    .font(ScorebookFont.chip)
                FielderPicker(picked: { position in answer == .onError(position) ? 1 : nil },
                              label: { "Error by the \(PlayWords.fielder($0))" }) { position in
                    model.perform(.chargeExtraBaseError(move.runner, fielder: position))
                }
            }
        }
        .foregroundStyle(ScorebookColor.textPrimary)
        .padding(Spacing.small)
        .background(ScorebookColor.warning.opacity(0.18), in: RoundedRectangle(cornerRadius: Spacing.cornerRadius, style: .continuous))
        .padding(.leading, 92)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    /// One half of the "on the throw / on an error" switch.
    private func segment(_ title: String, isPicked: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(ScorebookFont.chip)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(ScorebookColor.textPrimary)
                .frame(maxWidth: .infinity, minHeight: Spacing.minimumTapSize)
                .background(isPicked ? ScorebookColor.surface : Color.clear, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isPicked ? .isSelected : [])
    }
}

/// "Who made the out?", under a runner the scorer put out who was not suggested out: tap the
/// fielders in the order they handled the ball ("8-4" for a runner doubled off second). Tapping
/// the last one again takes it back. Save waits for at least one.
struct OutQuestion: View {
    let model: PlayEntryModel
    let move: RunnerMove

    var body: some View {
        let fielders = model.outFielders[move.runner] ?? []
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Who put \(model.name(of: move.runner)) out?")
                    .font(ScorebookFont.chip)
                Spacer(minLength: Spacing.small)
                Text(fielders.isEmpty ? "tap in order" : fielders.map(\.description).joined(separator: "-"))
                    .font(fielders.isEmpty ? ScorebookFont.caption : ScorebookFont.notation)
                    .foregroundStyle(fielders.isEmpty ? ScorebookColor.textSecondary : ScorebookColor.textPrimary)
            }
            FielderPicker(picked: { position in fielders.firstIndex(of: position).map { $0 + 1 } },
                          label: { "\(PlayWords.fielder($0).capitalized) made or helped make the out" }) { position in
                model.perform(.tapOutFielder(move.runner, position))
            }
        }
        .foregroundStyle(ScorebookColor.textPrimary)
        .padding(Spacing.small)
        .background(ScorebookColor.out.opacity(0.12), in: RoundedRectangle(cornerRadius: Spacing.cornerRadius, style: .continuous))
        .padding(.leading, 92)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}

/// A row of nine fielder buttons, the number with "LF" under it, for "Whose error?" and
/// "Who made the out?". A picked fielder is red; when the order matters, it shows its place.
struct FielderPicker: View {
    /// For a fielder: nothing when not picked, else its place in the order (1 for the only pick).
    var picked: (Position) -> Int?
    /// What VoiceOver says for a fielder.
    var label: (Position) -> String
    var onTap: (Position) -> Void

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Position.allCases, id: \.self) { position in
                let order = picked(position)
                Button { onTap(position) } label: {
                    VStack(spacing: 0) {
                        Text("\(position.number)").font(ScorebookFont.headline)
                        Text(position.abbreviation.uppercased()).font(ScorebookFont.caption.weight(.bold)).opacity(0.8)
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(order != nil ? Color.white : ScorebookColor.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: Spacing.minimumTapSize + 4)
                    .background(order != nil ? ScorebookColor.out : ScorebookColor.surface,
                                in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(label(position)))
                .accessibilityValue(Text(order.map { "picked, \($0)" } ?? ""))
                .accessibilityAddTraits(order != nil ? .isSelected : [])
            }
        }
    }
}

private extension Optional where Wrapped == ExtraBaseAnswer {
    /// True for "on an error", whether or not the scorer has said whose yet.
    var isError: Bool {
        if case .onError = self { return true }
        return false
    }
}
