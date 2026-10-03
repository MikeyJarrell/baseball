// A stand-in rules engine for screens to use until the real one is wired in.
//
// Its answers are canned and rough: good enough for previews and simulator demos of
// the in-play sequence, never for keeping a real book. The real rules engine lives in
// GameEngine.

import Foundation
import Model

/// Canned rules-engine answers for building screens.
///
/// - Replaying the sample game gives its hand-written final situation and play log; any
///   other game gives the start of that game.
/// - Runner suggestions use the plainest defaults: on a hit everyone moves up as many bases
///   as the batter; on a walk-like result only forced runners move; on an out the batter is
///   out and runners stay; on a double play the lead forced runner and the batter are out;
///   on a fielder's choice the lead forced runner is out; on an error everyone moves up one;
///   on a sacrifice fly the runner on third scores.
public struct SampleRulesEngine: RulesEngine {
    public init() {}

    public func replay(_ game: Game) -> GameReplay {
        if game.id == SampleGame.id {
            return GameReplay(situation: SampleGame.finalSituation, log: SampleGame.playLog)
        }
        return DoNothingRulesEngine().replay(game)
    }

    public func suggestRunners(for draft: PlayDraft, in situation: Situation) -> RunnerSuggestion {
        guard let result = draft.batterResult, let batter = situation.batter else {
            return RunnerSuggestion(runners: [], rbi: 0)
        }
        // Runners from the lead runner back, so "the lead forced runner" is easy to find.
        let onBase = situation.runners.sorted { $0.base > $1.base }
        var moves: [RunnerMove] = []

        /// Moves every runner up `bases`, and the batter to `bases`.
        func everyoneUp(_ bases: Int, batterSafe: Bool = true) {
            for r in onBase { moves.append(RunnerMove(runner: r.runner, from: r.base, to: advance(r.base, by: bases))) }
            moves.append(RunnerMove(runner: batter, from: .home, to: batterSafe ? advance(.home, by: bases) : .out,
                                    outBy: batterSafe ? [] : draft.fielders))
        }

        /// The runners forced to move when the batter goes to first.
        func forced() -> Set<Base> {
            var bases: Set<Base> = []
            for base in Base.occupiable {
                if situation.runner(on: base) != nil, base == .first || bases.contains(Base.occupiable[base.order - 2]) {
                    bases.insert(base)
                } else { break }
            }
            return bases
        }

        switch result {
        case .single: everyoneUp(1)
        case .double: everyoneUp(2)
        case .triple: everyoneUp(3)
        case .homeRun: everyoneUp(4)
        case .reachedOnError: everyoneUp(1)
        case .catchersInterference, .reachedOnDroppedThirdStrike:
            let pushed = forced()
            for r in onBase {
                moves.append(RunnerMove(runner: r.runner, from: r.base, to: pushed.contains(r.base) ? advance(r.base, by: 1) : .safe(at: r.base)))
            }
            moves.append(RunnerMove(runner: batter, from: .home, to: .first))
        case .out where draft.multiOut != .doublePlay, .sacrificeBunt:
            for r in onBase { moves.append(RunnerMove(runner: r.runner, from: r.base, to: .safe(at: r.base))) }
            moves.append(RunnerMove(runner: batter, from: .home, to: .out, outBy: draft.fielders))
        case .fieldersChoice, .out:
            // A fielder's choice, or a double play: the lead forced runner is out.
            let pushed = forced()
            let lead = onBase.first { pushed.contains($0.base) }
            for r in onBase {
                if r.runner == lead?.runner {
                    moves.append(RunnerMove(runner: r.runner, from: r.base, to: .out, outBy: Array(draft.fielders.prefix(2)), outAt: advanceBase(r.base)))
                } else {
                    moves.append(RunnerMove(runner: r.runner, from: r.base, to: pushed.contains(r.base) ? advance(r.base, by: 1) : .safe(at: r.base)))
                }
            }
            let batterOut = result == .out
            moves.append(RunnerMove(runner: batter, from: .home, to: batterOut ? .out : .first,
                                    outBy: batterOut ? Array(draft.fielders.suffix(2)) : [], outAt: batterOut ? .first : nil))
        case .sacrificeFly:
            for r in onBase {
                moves.append(RunnerMove(runner: r.runner, from: r.base, to: r.base == .third ? .scored : .safe(at: r.base)))
            }
            moves.append(RunnerMove(runner: batter, from: .home, to: .out, outBy: draft.fielders))
        }
        let runs = moves.filter { $0.to == .scored }.count
        let rbi = (result == .reachedOnError || draft.multiOut == .doublePlay) ? 0 : runs
        return RunnerSuggestion(runners: moves, rbi: rbi)
    }

    public func preview(_ draft: PlayDraft, in situation: Situation) -> PlayPreview {
        let runners = draft.runners.isEmpty ? suggestRunners(for: draft, in: situation).runners : draft.runners
        let outs = runners.filter { $0.to == .out }.count
        let runs = runners.filter { $0.to == .scored }.count
        let after = min(3, situation.outs + outs)
        var notation = draft.fielders.map(\.description).joined(separator: "-")
        if draft.batterResult == .out, draft.battedBall == .flyBall, draft.fielders.count == 1 { notation = "F" + notation }
        if draft.multiOut == .doublePlay { notation += " DP" }
        return PlayPreview(notation: notation, outsOnPlay: outs, runsOnPlay: after == 3 ? 0 : runs,
                           outsAfter: after, endsHalfInning: after == 3, endsGame: false)
    }

    /// Canned answers: a caught stealing, pickoff or appeal is an out at the next base (a
    /// pickoff at the runner's own base); a balk, wild pitch or passed ball moves every runner
    /// up one; anything else moves the chosen runners up one.
    public func suggestRunnerAction(_ reason: RunnerMoveReason, runners: [PlayerID], in situation: Situation) -> [RunnerMove] {
        let chosen = situation.runners.filter { runners.contains($0.runner) }.sorted { $0.base > $1.base }
        return chosen.map { r in
            switch reason {
            case .caughtStealing, .outOnAppeal:
                RunnerMove(runner: r.runner, from: r.base, to: .out, reason: reason, outAt: advanceBase(r.base))
            case .pickoff:
                RunnerMove(runner: r.runner, from: r.base, to: .out, reason: reason, outAt: r.base)
            default:
                RunnerMove(runner: r.runner, from: r.base, to: advance(r.base, by: 1), reason: reason)
            }
        }
    }

    public func notation(for event: GameEvent, in situation: Situation) -> String {
        switch event.kind {
        case .pitch(let pitch):
            switch pitch.result {
            case .ball: "B"
            case .calledStrike: situation.count.strikes == 2 ? "ꓘ" : "C"
            case .swingingStrike, .foulTip, .foulBunt: situation.count.strikes == 2 ? "K" : "S"
            case .foul: "F"
            case .hitByPitch: "HBP"
            }
        case .intentionalWalk: "IBB"
        case .ballInPlay(let play): preview(PlayDraft(batterResult: play.batterResult, battedBall: play.battedBall,
                                                      fielders: play.fielders, multiOut: play.multiOut, runners: play.runners),
                                            in: situation).notation
        default: event.kind.label
        }
    }

    /// Where a runner ends up after moving `bases` bases from `base`.
    private func advance(_ base: Base, by bases: Int) -> RunnerEnd {
        let to = base.order + bases
        return to >= 4 ? .scored : RunnerEnd.safe(at: Base.occupiable[to - 1])
    }

    /// The next base along, where a forced runner would be put out.
    private func advanceBase(_ base: Base) -> Base {
        base.order >= 3 ? .home : Base.occupiable[base.order]
    }
}
