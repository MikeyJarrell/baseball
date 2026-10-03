// The last step: where every runner, batter included, ended up. Each runner starts at the
// base the rules engine suggests, with an arrow on the drawing from where they started. A row
// of base buttons under the drawing changes any runner in one tap; the small dot marks the
// rules engine's guess. The outs, runs and runs batted in on the play show at the top, and
// "Inning over" when the play makes the third out.
//
// On a hit, a runner the scorer moves further than the hit carried them gets a question: how
// did they get there, on the throw (or on the hit, for a runner already on base) or on an
// error, and whose? A single plus the left fielder's error reads "1B 7, E7".

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
                VStack(spacing: 6) {
                    ForEach(model.draft.runners, id: \.runner) { move in
                        RunnerRow(model: model, move: move)
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
            BottomBar(title: bottomTitle(preview), detail: bottomDetail(preview)) {
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
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
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
        let suggested = model.firstSuggestion[move.runner]
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
                .foregroundStyle(isPicked ? Color.white : ScorebookColor.textSecondary)
                .frame(maxWidth: .infinity, minHeight: Spacing.minimumTapSize)
                .overlay(alignment: .bottom) {
                    if isSuggested {
                        Circle().frame(width: 5, height: 5).opacity(0.6).padding(.bottom, 4)
                            .foregroundStyle(isPicked ? Color.white : ScorebookColor.textSecondary)
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
                segment(move.isBatter ? "On the throw" : "On the hit", isPicked: answer == .onThePlay) {
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
                HStack(spacing: 3) {
                    ForEach(Position.allCases, id: \.self) { position in
                        fielderButton(position, isPicked: answer == .onError(position))
                    }
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
                .foregroundStyle(isPicked ? ScorebookColor.textPrimary : ScorebookColor.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(isPicked ? ScorebookColor.surface : Color.clear, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isPicked ? .isSelected : [])
    }

    /// One fielder button under "Whose error?": the number, with "LF" under it.
    private func fielderButton(_ position: Position, isPicked: Bool) -> some View {
        Button { model.perform(.chargeExtraBaseError(move.runner, fielder: position)) } label: {
            VStack(spacing: 0) {
                Text("\(position.number)").font(ScorebookFont.headline)
                Text(position.abbreviation.uppercased()).font(ScorebookFont.caption.weight(.bold)).opacity(0.75)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .foregroundStyle(isPicked ? Color.white : ScorebookColor.textPrimary)
            .frame(maxWidth: .infinity, minHeight: Spacing.minimumTapSize)
            .background(isPicked ? ScorebookColor.out : ScorebookColor.surface, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Error by the \(PlayWords.fielder(position))"))
        .accessibilityAddTraits(isPicked ? .isSelected : [])
    }
}

private extension Optional where Wrapped == ExtraBaseAnswer {
    /// True for "on an error", whether or not the scorer has said whose yet.
    var isError: Bool {
        if case .onError = self { return true }
        return false
    }
}
