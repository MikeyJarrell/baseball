// Suggestions: the engine's best guess at what happened to the runners, for the scorer to
// confirm or correct. Nothing here is recorded until the scorer saves the play.
//
// - On a ball in play: where every runner (batter included) most likely ended up, and the
//   runs batted in under the official scoring rules.
// - While the play is being entered: its notation so far, and the outs and runs it would make.
// - Between pitches: where the chosen runners went on a steal, pickoff, wild pitch or balk.
// - When a designated non-runner reaches: who the league's rule says should run for them.

import Foundation
import Model

enum Suggestions {
    // MARK: - Ball in play

    /// Where every runner most likely ended up on the play the scorer is entering. Runners
    /// the scorer has already placed (in `draft.runners`) are kept as the scorer has them.
    static func runners(for draft: PlayDraft, in s: Situation) -> RunnerSuggestion {
        var moves = defaultMoves(for: draft, in: s)
        // The scorer's own choices win over the guess, runner by runner.
        for chosen in draft.runners {
            if let i = moves.firstIndex(where: { $0.runner == chosen.runner || ($0.isBatter && chosen.isBatter) }) {
                moves[i] = chosen
            } else {
                moves.append(chosen)
            }
        }
        let rbi = draft.batterResult.map { runsBattedIn(result: $0, draft: draft, moves: moves) } ?? 0
        return RunnerSuggestion(runners: moves, rbi: rbi)
    }

    /// The plain guess, before the scorer changes anything. Runners are listed lead runner
    /// first, then the batter.
    static func defaultMoves(for draft: PlayDraft, in s: Situation) -> [RunnerMove] {
        let onBase = BaseMath.leadFirst(s.runners)
        let holdAll = onBase.map { RunnerMove(runner: $0.runner, from: $0.base, to: .safe(at: $0.base)) }
        guard let result = draft.batterResult, let batter = s.batter else { return holdAll }

        let forced = BaseMath.forcedBases(s.runners)
        let fielders = draft.fielders
        var moves: [RunnerMove] = []

        /// Every runner moves up `bases` bases and so does the batter.
        func everyoneUp(_ bases: Int, batterOnError: Bool = false) {
            for r in onBase {
                moves.append(RunnerMove(runner: r.runner, from: r.base, to: BaseMath.advance(r.base, by: bases)))
            }
            moves.append(RunnerMove(runner: batter, from: .home, to: BaseMath.advance(.home, by: bases),
                                    advancedOnError: batterOnError))
        }

        /// Forced runners move up one base, everyone else holds; the batter ends at `batterEnd`.
        func forcedUp(except out: Set<PlayerID> = [], batterEnd: RunnerMove) {
            for r in onBase where !out.contains(r.runner) {
                let to: RunnerEnd = forced.contains(r.base) ? BaseMath.advance(r.base, by: 1) : .safe(at: r.base)
                moves.append(RunnerMove(runner: r.runner, from: r.base, to: to))
            }
            moves.append(batterEnd)
        }

        let batterOutAtFirst = RunnerMove(runner: batter, from: .home, to: .out, outBy: fielders, outAt: .first)
        let isAirBall = [.flyBall, .lineDrive, .popUp].contains(draft.battedBall)

        switch result {
        case .single: everyoneUp(1)
        case .double: everyoneUp(2)
        case .triple: everyoneUp(3)
        case .homeRun: everyoneUp(4)

        case .reachedOnError:
            // Batter safe at first on the error, runners up one.
            everyoneUp(1, batterOnError: true)

        case .catchersInterference, .reachedOnDroppedThirdStrike:
            forcedUp(batterEnd: RunnerMove(runner: batter, from: .home, to: .first))

        case .fieldersChoice:
            // The lead forced runner is out at the next base; with nobody forced, the lead runner.
            // The batter is safe at first.
            if let lead = onBase.first(where: { forced.contains($0.base) }) ?? onBase.first {
                moves.append(RunnerMove(runner: lead.runner, from: lead.base, to: .out, outBy: fielders,
                                        outAt: BaseMath.nextBase(after: lead.base)))
                forcedUp(except: [lead.runner], batterEnd: RunnerMove(runner: batter, from: .home, to: .first))
            } else {
                moves.append(RunnerMove(runner: batter, from: .home, to: .first))
            }

        case .sacrificeFly:
            // The runner on third scores; everyone else holds.
            for r in onBase {
                moves.append(RunnerMove(runner: r.runner, from: r.base, to: r.base == .third ? .scored : .safe(at: r.base)))
            }
            moves.append(RunnerMove(runner: batter, from: .home, to: .out, outBy: fielders))

        case .sacrificeBunt:
            // The runners on first and second move up; the runner on third only if forced.
            for r in onBase {
                let moves1 = r.base != .third || forced.contains(.third)
                moves.append(RunnerMove(runner: r.runner, from: r.base, to: moves1 ? BaseMath.advance(r.base, by: 1) : .safe(at: r.base)))
            }
            moves.append(batterOutAtFirst)

        case .out:
            moves = outMoves(draft: draft, batter: batter, onBase: onBase, forced: forced, isAirBall: isAirBall)
        }

        // A play that makes the third out: nobody else moves and no run is suggested.
        let outs = moves.filter { $0.to == .out }.count
        if s.outs + outs >= 3 {
            moves = moves.map { m in
                guard !m.isBatter, m.to != .out else { return m }
                return RunnerMove(runner: m.runner, from: m.from, to: .safe(at: m.from))
            }
        }

        if [.single, .double, .triple].contains(result) {
            moves = limitedToWinningRun(moves, in: s)
        }
        return moves
    }

    /// An out on a ball in play.
    /// - In the air: the batter is out and runners hold; on a double play the lead runner is
    ///   doubled off their base.
    /// - On the ground, marked a double play or handled by three or more fielders with a runner
    ///   on first: the runner from first is forced at second and the batter is out at first.
    ///   Otherwise forced runners move up one and the batter is out.
    private static func outMoves(
        draft: PlayDraft, batter: PlayerID, onBase: [BaseRunner], forced: Set<Base>, isAirBall: Bool
    ) -> [RunnerMove] {
        let fielders = draft.fielders
        var moves: [RunnerMove] = []
        if isAirBall {
            let doubledOff = draft.multiOut != nil ? onBase.first : nil
            for r in onBase {
                if r.runner == doubledOff?.runner {
                    moves.append(RunnerMove(runner: r.runner, from: r.base, to: .out, outBy: fielders, outAt: r.base))
                } else {
                    moves.append(RunnerMove(runner: r.runner, from: r.base, to: .safe(at: r.base)))
                }
            }
            let catcher = fielders.first.map { [$0] } ?? []
            moves.append(RunnerMove(runner: batter, from: .home, to: .out, outBy: draft.multiOut != nil ? catcher : fielders))
            return moves
        }

        let runnerOnFirst = onBase.first { $0.base == .first }
        let isDoublePlay = draft.multiOut != nil || (fielders.count >= 3 && runnerOnFirst != nil)
        if isDoublePlay, let forcedAtSecond = runnerOnFirst ?? onBase.first(where: { forced.contains($0.base) }) ?? onBase.first {
            // 5-4-3: the runner is out 5-4 at second, the batter 4-3 at first.
            let runnerOutBy = fielders.count >= 2 ? Array(fielders.dropLast()) : fielders
            let batterOutBy = Array(fielders.suffix(2))
            for r in onBase {
                if r.runner == forcedAtSecond.runner {
                    moves.append(RunnerMove(runner: r.runner, from: r.base, to: .out, outBy: runnerOutBy,
                                            outAt: BaseMath.nextBase(after: r.base)))
                } else {
                    let to: RunnerEnd = forced.contains(r.base) ? BaseMath.advance(r.base, by: 1) : .safe(at: r.base)
                    moves.append(RunnerMove(runner: r.runner, from: r.base, to: to))
                }
            }
            moves.append(RunnerMove(runner: batter, from: .home, to: .out, outBy: batterOutBy, outAt: .first))
            return moves
        }

        for r in onBase {
            let to: RunnerEnd = forced.contains(r.base) ? BaseMath.advance(r.base, by: 1) : .safe(at: r.base)
            moves.append(RunnerMove(runner: r.runner, from: r.base, to: to))
        }
        moves.append(RunnerMove(runner: batter, from: .home, to: .out, outBy: fielders,
                                outAt: draft.battedBall == nil && fielders.count == 1 ? nil : .first))
        return moves
    }

    /// A game-ending hit in the bottom of the last inning or later: only the winning run scores,
    /// and nobody, batter included, moves more bases than that runner did (rule 9.06(f)).
    /// A home run is left alone.
    static func limitedToWinningRun(_ moves: [RunnerMove], in s: Situation) -> [RunnerMove] {
        guard s.isWalkOffInning, s.score.home <= s.score.away else { return moves }
        let needed = s.score.away - s.score.home + 1
        // Runners score lead runner first.
        let scorers = moves.filter { $0.to == .scored }.sorted { $0.from > $1.from }
        guard scorers.count >= needed else { return moves }
        let winning = scorers[needed - 1]
        let bases = BaseMath.distance(from: winning.from, to: .scored)
        return moves.map { m in
            guard m.to != .out, BaseMath.distance(from: m.from, to: m.to) > bases else { return m }
            var limited = m
            limited.to = BaseMath.advance(m.from, by: bases)
            return limited
        }
    }

    /// Runs batted in under the official scoring rules: every run that scores on the play,
    /// except on an error, a dropped third strike, or a ground-ball double play, and except a
    /// runner who scored because of an error.
    static func runsBattedIn(result: BatterResult, draft: PlayDraft, moves: [RunnerMove]) -> Int {
        switch result {
        case .reachedOnError, .reachedOnDroppedThirdStrike:
            return 0
        case .out where draft.multiOut != nil && ![.flyBall, .lineDrive, .popUp].contains(draft.battedBall):
            return 0
        default:
            return moves.filter { $0.to == .scored && !$0.advancedOnError }.count
        }
    }

    // MARK: - Preview

    /// What a play in progress would do: notation so far, outs, runs, and whether it ends the
    /// half-inning or (in a walk-off inning) puts the home team ahead.
    static func preview(_ draft: PlayDraft, in s: Situation) -> PlayPreview {
        let moves = draft.runners.isEmpty ? runners(for: draft, in: s).runners : draft.runners
        let outs = moves.filter { $0.to == .out }.count
        let runs = moves.filter { $0.to == .scored }.count
        let outsAfter = min(3, s.outs + outs)
        let endsHalf = outsAfter >= 3
        let endsGame = !endsHalf && s.isWalkOffInning && s.score.home <= s.score.away
            && s.score.home + runs > s.score.away
        return PlayPreview(
            notation: Notation.draft(draft, runners: moves),
            outsOnPlay: outs, runsOnPlay: runs, outsAfter: outsAfter,
            endsHalfInning: endsHalf, endsGame: endsGame
        )
    }

    // MARK: - Between pitches

    /// Where the chosen runners most likely ended up on a move between pitches. A caught
    /// stealing is out at the next base and a pickoff at the runner's own base; a balk, wild
    /// pitch or passed ball moves every runner up one; anything else moves the chosen runners
    /// up one. One move per runner, lead runner first.
    static func runnerAction(_ reason: RunnerMoveReason, runners chosen: [PlayerID], in s: Situation) -> [RunnerMove] {
        let movesEveryone: Bool = [.balk, .wildPitch, .passedBall].contains(reason)
        let picked = BaseMath.leadFirst(s.runners.filter { movesEveryone || chosen.contains($0.runner) })
        return picked.map { r in
            switch reason {
            case .caughtStealing:
                RunnerMove(runner: r.runner, from: r.base, to: .out, reason: reason, outAt: BaseMath.nextBase(after: r.base))
            case .pickoff, .outOnAppeal:
                RunnerMove(runner: r.runner, from: r.base, to: .out, reason: reason, outAt: r.base)
            default:
                RunnerMove(runner: r.runner, from: r.base, to: BaseMath.advance(r.base, by: 1), reason: reason)
            }
        }
    }

    // MARK: - Designated non-runners

    /// The runner the league's rule names for a designated non-runner who has just reached
    /// base [9.11 D to G]: the batting team's last recorded out, skipping the batter now at bat,
    /// anyone on base, and the non-runner themself. An automatic out at a batting hole is not a
    /// recorded out: that player has left the game. Before the team's first out, the last batter
    /// in the batting order [9.11 E].
    static func suggestedRunner(for nonRunner: PlayerID, entries: [PlayLogEntry], situation s: Situation) -> PlayerID? {
        let side = s.battingSide
        let atBat = s.batter
        let onBase = Set(s.runners.map(\.runner))
        let unavailable = onBase.union([nonRunner]).union(atBat.map { [$0] } ?? [])

        // Every out the team has made, oldest first.
        let outs = entries.filter { $0.battingSide == side }.flatMap { entry -> [PlayerID] in
            if case .automaticOut = entry.event.kind { return [] }
            return entry.outs.map(\.runner)
        }
        if let last = outs.last(where: { !unavailable.contains($0) }) { return last }
        guard outs.isEmpty else { return nil }
        return s[side].battingOrder.slots.last { slot in
            guard let current = slot.current else { return false }
            return !unavailable.contains(current) && !slot.isHole
        }?.current
    }
}
