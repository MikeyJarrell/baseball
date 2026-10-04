// The in-play sequence's frame: the header, the strip saying who is on base, and whichever
// step is showing. Also the words the steps use to describe the play ("Ground out to
// shortstop"), which describe what the scorer tapped and work out nothing.

import SwiftUI
import Model
import DesignSystem

/// The whole sequence: header, context strip, and the current step.
struct PlayEntryScreen: View {
    @Bindable var model: PlayEntryModel

    var body: some View {
        VStack(spacing: Spacing.small) {
            FlowHeader(title: model.stepTitle, subtitle: model.headerSubtitle,
                       onBack: { model.perform(.back) }, onCancel: { model.perform(.cancel) })
            ContextStrip(text: model.contextText, look: model.battingLook, stepNumber: model.stepNumber)
            Group {
                switch model.step {
                case .result: ResultStep(model: model)
                case .droppedThirdStrike: DroppedThirdStrikeStep(model: model)
                case .fielders: FieldersStep(model: model)
                case .hitLocation: HitLocationStep(model: model)
                case .error: ErrorStep(model: model)
                case .runners: RunnersStep(model: model)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .id(model.steps.count)
            .transition(.opacity)
        }
        .animation(.easeOut(duration: 0.15), value: model.steps.count)
        .background(ScorebookColor.background.ignoresSafeArea())
    }
}

// MARK: - Words for the screen

extension PlayEntryModel {
    /// The title in the header for the step showing.
    var stepTitle: String {
        switch step {
        case .result: return "In play"
        case .droppedThirdStrike: return "Dropped 3rd strike"
        case .hitLocation: return draft.batterResult.map(PlayWords.resultTitle) ?? "Hit"
        case .error: return "Reached on error"
        case .runners: return "Runners"
        case .fielders:
            if draft.context == .droppedThirdStrike { return "Dropped 3rd strike" }
            switch draft.batterResult {
            case .fieldersChoice: return "Fielder’s choice"
            case .sacrificeFly: return "Sacrifice fly"
            case .sacrificeBunt: return "Sacrifice bunt"
            default: return "Who handled it?"
            }
        }
    }

    /// Under the title: the batter, the half-inning and the outs. "Diaz · ▲3, 1 out".
    var headerSubtitle: String {
        let arrow = situation.half == .top ? "▲" : "▼"
        return "\(name(of: situation.batter)) · \(arrow)\(situation.inning), \(situation.outs) out\(situation.outs == 1 ? "" : "s")"
    }

    /// The context strip: who is on base and the count. "Runners on 1st and 2nd · count 2–1".
    var contextText: String {
        let bases = situation.runners.map(\.base).sorted().map(\.shortLabel)
        let onBase: String
        switch bases.count {
        case 0: onBase = "Bases empty"
        case 1: onBase = "Runner on \(bases[0])"
        default: onBase = "Runners on \(bases.dropLast().joined(separator: ", ")) and \(bases.last!)"
        }
        return "\(onBase) · count \(situation.count.balls)–\(situation.count.strikes)"
    }

    /// Which of the three dashes to fill: step one, the middle step, or the runners.
    var stepNumber: Int {
        switch step {
        case .result: 1
        case .runners: 3
        default: 2
        }
    }

    /// One line of words for the fielders step: "Ground out to shortstop", "Fly out to center field",
    /// "Ground out, third base to second base to first base, double play".
    var fieldersDetail: String {
        let fielders = draft.fielders
        guard !fielders.isEmpty else { return "" }
        let path = fielders.map(\.name).joined(separator: " to ")
        if draft.context == .droppedThirdStrike { return "Strikeout, \(path)" }
        switch draft.batterResult {
        case .fieldersChoice: return "Fielder’s choice, \(path)"
        case .sacrificeFly: return "Sacrifice fly to \(path)"
        case .sacrificeBunt: return "Sacrifice bunt, \(path)"
        default:
            let kind = PlayWords.outWord(draft.battedBall)
            var words = fielders.count == 1 ? "\(kind) to \(path)" : "\(kind), \(path)"
            if draft.multiOut == .doublePlay { words += ", double play" }
            if draft.multiOut == .triplePlay { words += ", triple play" }
            return words
        }
    }
}

/// Plain words for the parts of a play.
enum PlayWords {
    /// "Single", "Home run": the title for a hit.
    static func resultTitle(_ result: BatterResult) -> String {
        switch result {
        case .single: "Single"
        case .double: "Double"
        case .triple: "Triple"
        case .homeRun: "Home run"
        default: result.label.capitalized
        }
    }

    /// "Ground out", "Fly out": the kind of out for a batted ball.
    static func outWord(_ kind: BattedBallType?) -> String {
        switch kind {
        case .groundBall: "Ground out"
        case .flyBall: "Fly out"
        case .lineDrive: "Line out"
        case .popUp: "Pop out"
        case .bunt: "Bunt out"
        case nil: "Out"
        }
    }

    /// The word on a batted-ball chip.
    static func chipTitle(_ kind: BattedBallType) -> String {
        switch kind {
        case .groundBall: "Ground"
        case .flyBall: "Fly"
        case .lineDrive: "Line"
        case .popUp: "Pop-up"
        case .bunt: "Bunt"
        }
    }

    /// The fielder at a position, as a person: "shortstop", "left fielder", "first baseman".
    static func fielder(_ position: Position) -> String {
        switch position {
        case .pitcher: "pitcher"
        case .catcher: "catcher"
        case .firstBase: "first baseman"
        case .secondBase: "second baseman"
        case .thirdBase: "third baseman"
        case .shortstop: "shortstop"
        case .leftField: "left fielder"
        case .centerField: "center fielder"
        case .rightField: "right fielder"
        }
    }

    /// "1 out", "2 outs".
    static func outs(_ n: Int) -> String { "\(n) out\(n == 1 ? "" : "s")" }

    /// "1 run", "0 runs".
    static func runs(_ n: Int) -> String { "\(n) run\(n == 1 ? "" : "s")" }
}
