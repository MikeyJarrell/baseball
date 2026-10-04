// The three middle steps, each built on the whole-field drawing: tap the fielders in order
// (outs, fielder's choices, sacrifices, a dropped third strike thrown out), tap where a hit
// landed, or tap the fielder who made an error.

import SwiftUI
import Model
import DesignSystem

/// Tap the fielders in the order they handled the ball. The notation builds as they tap
/// ("6", then "6-3"); tapping the last fielder again, or the arrow, takes it back. On a batter
/// out, chips above say what kind of ball it was, with double play and triple play beside them.
struct FieldersStep: View {
    let model: PlayEntryModel

    var body: some View {
        let preview = model.preview
        VStack(spacing: 0) {
            if showsBattedBallChips {
                battedBallChips
            }
            NotationBar(notation: model.draft.fielders.isEmpty ? "" : preview.notation,
                        hint: hint,
                        detail: model.fieldersDetail,
                        onUndo: model.draft.fielders.isEmpty ? nil : { model.perform(.untapLastFielder) })
            FieldDrawing(occupiedBases: model.situation.occupiedBases,
                         tapSequence: model.draft.fielders,
                         onTap: { tap in
                             if case .position(let position) = tap { model.perform(.tapFielder(position)) }
                         })
                .fielderNames(model.fielderNames)
                .battingTeam(model.battingLook)
                .padding(.horizontal, Spacing.small)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BottomBar(title: summaryTitle,
                      detail: "Makes \(PlayWords.outs(preview.outsOnPlay))",
                      showsInningOver: preview.endsHalfInning) {
                if model.needsRunnerStep {
                    RunnersButton(enabled: model.canGoToRunners) { model.perform(.goToRunners) }
                } else {
                    SaveButton(enabled: model.canSave) { model.perform(.save) }
                }
            }
        }
    }

    /// The batted-ball chips show only for an ordinary batter out.
    private var showsBattedBallChips: Bool {
        model.draft.batterResult == .out && model.draft.context == .ballInPlay
    }

    /// Ground, Fly, Line, Pop-up, Bunt, then Double play and Triple play. The screen's guess
    /// shows as a dashed chip once a fielder is tapped; the scorer's pick shows filled.
    private var battedBallChips: some View {
        VStack(alignment: .leading, spacing: Spacing.extraSmall) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(BattedBallType.allCases, id: \.self) { kind in
                        ChoiceChip(title: PlayWords.chipTitle(kind), state: chipState(kind)) {
                            model.perform(.pickBattedBall(kind))
                        }
                    }
                }
            }
            HStack(spacing: 6) {
                ChoiceChip(title: "Double play", state: model.draft.multiOut == .doublePlay ? .on : .off) {
                    model.perform(.toggleMultiOut(.doublePlay))
                }
                ChoiceChip(title: "Triple play", state: model.draft.multiOut == .triplePlay ? .on : .off) {
                    model.perform(.toggleMultiOut(.triplePlay))
                }
            }
        }
        .padding(.horizontal, Spacing.screenEdge)
    }

    /// How one batted-ball chip looks: filled if the scorer picked it, dashed if it is the
    /// screen's guess, plain otherwise.
    private func chipState(_ kind: BattedBallType) -> ChipState {
        guard model.draft.battedBall == kind else { return .off }
        return model.battedBallIsGuess ? .guess : .on
    }

    /// The gray words shown before the first fielder is tapped.
    private var hint: String {
        if model.draft.context == .droppedThirdStrike { return "Tap the catcher, then whoever caught the throw" }
        switch model.draft.batterResult {
        case .fieldersChoice: return "Tap the fielders who made the out"
        case .sacrificeFly: return "Tap who caught it"
        case .sacrificeBunt: return "Tap the fielders in order"
        default: return "Tap fielders in the order they touched the ball"
        }
    }

    /// The bold line in the bottom bar.
    private var summaryTitle: String {
        if model.draft.batterResult == .fieldersChoice { return "Batter safe at 1st" }
        switch model.draft.multiOut {
        case .doublePlay: return "Batter out, double play"
        case .triplePlay: return "Batter out, triple play"
        case nil: return "Batter out"
        }
    }
}

/// On a hit: tap where the ball landed, for a spray chart later, or go straight on.
struct HitLocationStep: View {
    let model: PlayEntryModel

    var body: some View {
        VStack(spacing: 0) {
            NotationBar(notation: model.preview.notation,
                        hint: model.stepTitle,
                        detail: detail)
            FieldDrawing(occupiedBases: model.situation.occupiedBases,
                         onTap: { tap in
                             switch tap {
                             case .spot(let spot, let nearest): model.perform(.tapHitSpot(spot, nearest: nearest))
                             case .position(let position): model.perform(.tapFielder(position))
                             case .base, .runner: break
                             }
                         })
                .battingTeam(model.battingLook)
                .hitLocation(model.draft.hitSpot)
                .padding(.horizontal, Spacing.small)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BottomBar(title: "Where is optional", detail: "For a spray chart later") {
                if model.needsRunnerStep {
                    RunnersButton(enabled: true) { model.perform(.goToRunners) }
                } else {
                    // Nobody on: the batter's base is the whole story, so Save is right here.
                    RunnersButton(enabled: true, isSecondary: true) { model.perform(.goToRunners) }
                    SaveButton(enabled: model.canSave) { model.perform(.save) }
                }
            }
        }
    }

    /// "Single to left field", or how to use the step before anything is tapped.
    private var detail: String {
        guard let location = model.draft.hitLocation else { return "Tap where it landed, or go straight on" }
        return "\(model.stepTitle) to \(location.name)"
    }
}

/// On a reached-on-error: tap the fielder who made the error. Fielding or throwing is optional.
struct ErrorStep: View {
    let model: PlayEntryModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                ChoiceChip(title: "Fielding", state: model.errorType == .fielding ? .on : .off) {
                    model.perform(.pickErrorType(.fielding))
                }
                ChoiceChip(title: "Throwing", state: model.errorType == .throwing ? .on : .off) {
                    model.perform(.pickErrorType(.throwing))
                }
                Text("optional")
                    .font(ScorebookFont.caption)
                    .foregroundStyle(ScorebookColor.textSecondary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Spacing.screenEdge)
            NotationBar(notation: model.errorFielder == nil ? "" : model.preview.notation,
                        hint: "Who made the error?",
                        detail: model.errorFielder.map { "Error by the \(PlayWords.fielder($0))" } ?? "")
            FieldDrawing(occupiedBases: model.situation.occupiedBases,
                         onTap: { tap in
                             if case .position(let position) = tap { model.perform(.tapFielder(position)) }
                         })
                .errorPositions(model.errorFielder.map { [$0] } ?? [])
                .fielderNames(model.fielderNames)
                .battingTeam(model.battingLook)
                .padding(.horizontal, Spacing.small)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BottomBar(title: "Batter reaches", detail: "Next: where everyone ended up") {
                RunnersButton(enabled: model.canGoToRunners) { model.perform(.goToRunners) }
            }
        }
    }
}
