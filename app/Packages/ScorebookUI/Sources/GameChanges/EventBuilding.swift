// The small decisions the sheets make when they turn the scorer's taps into an event, kept
// here as plain functions with no screen, so they can be tested on their own:
//
// - Runner actions: which runners go into the event, and the reason each one carries
//   (on a double steal with the lead runner thrown out, the trail runner stole and the lead
//   runner was caught stealing), and where an out goes by default.
// - The defense check: starting from the fielders on the field, laying a planned defense
//   over them, swapping players, and turning the finished list into one substitution.
//
// None of this works out the game. It only decides what the scorer's own entries mean.

import Foundation
import Model

// MARK: - Runner actions

/// Turning the runner action page into an event.
public enum RunnerActionBuilder {
    /// Where an out goes when the scorer taps Out: the runner's own base for a pickoff or an
    /// appeal (picked off first is an out at first), otherwise the next base along (caught
    /// stealing second is an out at second).
    public static func defaultOutBase(for reason: RunnerMoveReason, from base: Base) -> Base {
        switch reason {
        case .pickoff, .outOnAppeal:
            return base
        default:
            return Base.allCases.first { $0.order == (base.order + 1) % 4 } ?? .second
        }
    }

    /// How many bases a runner went: 1 from first to second, 3 from first to home. Zero for
    /// a runner who stayed or was put out.
    static func basesGained(from: Base, to: RunnerEnd) -> Int {
        switch to {
        case .out: return 0
        case .scored: return 4 - from.order
        default: return (to.base?.order ?? from.order) - from.order
        }
    }

    /// The reason one runner's move carries, from what the scorer picked and where this runner
    /// ended up.
    ///
    /// - Steals: a runner put out was caught stealing, and a runner who moved up stole, whichever
    ///   button the scorer started from. So a double steal with the lead runner thrown out gives
    ///   the trail runner a stolen base and the lead runner a caught stealing.
    /// - Pickoffs and appeals: the runner put out carries the pickoff or appeal; anyone who moved
    ///   up did so on an error if one was entered, or for some other reason.
    /// - Wild pitch, passed ball, balk, defensive indifference, advance on error: runners who
    ///   moved carry that reason; a runner put out trying for an extra base carries "other".
    public static func reason(picked: RunnerMoveReason, ended: RunnerEnd, hasError: Bool) -> RunnerMoveReason {
        let out = ended == .out
        switch picked {
        case .stolenBase, .caughtStealing:
            return out ? .caughtStealing : .stolenBase
        case .pickoff, .outOnAppeal:
            return out ? picked : (hasError ? .advanceOnError : .other)
        case .wildPitch, .passedBall, .balk, .defensiveIndifference, .advanceOnError, .other:
            return out ? .other : picked
        }
    }

    /// The finished runner action.
    ///
    /// - Runners who stayed on their base are left out: nothing happened to them.
    /// - Each remaining runner gets their own reason (see `reason(picked:ended:hasError:)`).
    /// - With an error entered, a runner marked as helped by it: on "advanced on error", every
    ///   runner who moved up; otherwise a runner who went more than one base (a steal of second
    ///   who reached third when the catcher threw the ball away is a stolen base and an error).
    /// - A runner who moved up keeps no fielders or out base.
    ///
    /// Returns nothing when no runner moved or was put out.
    public static func action(moves: [RunnerMove], picked: RunnerMoveReason, errors: [ErrorCharge]) -> RunnerAction? {
        let hasError = !errors.isEmpty
        var result: [RunnerMove] = []
        for move in moves where move.to != .safe(at: move.from) {
            var m = move
            m.reason = reason(picked: picked, ended: m.to, hasError: hasError)
            if m.to == .out {
                m.advancedOnError = false
            } else {
                m.outBy = []
                m.outAt = nil
                let gained = basesGained(from: m.from, to: m.to)
                m.advancedOnError = hasError && (picked == .advanceOnError || m.reason == .advanceOnError || gained > 1)
            }
            result.append(m)
        }
        guard !result.isEmpty else { return nil }
        return RunnerAction(moves: result, errors: errors)
    }

    /// True when a runner was put out and nobody was tapped as making the out, so the save
    /// button says "Save without fielders".
    public static func outsMissingFielders(_ moves: [RunnerMove]) -> Bool {
        moves.contains { $0.to == .out && $0.outBy.isEmpty }
    }
}

// MARK: - The defense

/// A defense to start the defense check from instead of the one on the field now, with a
/// reason for each position that differs. Built by the app from the game's plan (two players
/// alternating at one position by inning, for example); the sheet only shows it.
public struct DefenseSuggestion: Equatable, Sendable {
    /// The team the plan is for. It is used only on that team's defense check.
    public var team: TeamSide
    /// Who should be at each planned position this half-inning. A position left out keeps the
    /// player there now.
    public var fielders: [FielderAssignment]
    /// Why a position differs from now, shown beside it: "alternating".
    public var reasons: [Position: String]

    public init(team: TeamSide, fielders: [FielderAssignment], reasons: [Position: String] = [:]) {
        self.team = team
        self.fielders = fielders
        self.reasons = reasons
    }
}

/// Who is at each position on the defense sheet, and the substitution it makes.
public enum DefenseBuilder {
    /// The fielders as a lookup from position to player.
    public static func lineup(_ fielders: [FielderAssignment]) -> [Position: PlayerID] {
        Dictionary(fielders.map { ($0.position, $0.player) }, uniquingKeysWith: { first, _ in first })
    }

    /// Puts a player at a position. Someone already in the field swaps with the player who was
    /// there; someone coming in from the bench sends that player off the field. `nil` leaves
    /// the position empty.
    public static func put(_ player: PlayerID?, at position: Position, in draft: inout [Position: PlayerID]) {
        let previous = draft[position]
        if let player, let from = draft.first(where: { $0.value == player })?.key {
            guard from != position else { return }
            draft[from] = previous
        }
        draft[position] = player
    }

    /// The defense the sheet opens with: the fielders on the field now, with the plan laid over
    /// them, one planned position at a time, swapping as the scorer's own taps would. The plan
    /// counts only when it is for this team and the sheet is that team's defense check.
    public static func startingDraft(current: [FielderAssignment], plan: DefenseSuggestion?,
                                     side: TeamSide, isCheck: Bool) -> [Position: PlayerID] {
        var draft = lineup(current)
        guard isCheck, let plan, plan.team == side else { return draft }
        for planned in plan.fielders {
            put(planned.player, at: planned.position, in: &draft)
        }
        return draft
    }

    /// Positions where the sheet differs from the field now.
    public static func changedPositions(current: [Position: PlayerID], draft: [Position: PlayerID]) -> [Position] {
        Position.allCases.filter { draft[$0] != current[$0] }
    }

    /// One substitution with every position that changed, or nothing when nothing changed.
    /// A player moved off the field with nobody taking their position, and not playing
    /// anywhere else, leaves the field.
    public static func substitution(team: TeamSide, current: [Position: PlayerID], draft: [Position: PlayerID]) -> Substitution? {
        let changed = changedPositions(current: current, draft: draft)
        guard !changed.isEmpty else { return nil }
        let assignments = changed.compactMap { position in
            draft[position].map { FielderAssignment(position: position, player: $0) }
        }
        let stillFielding = Set(draft.values)
        let leaving = changed.compactMap { position -> PlayerID? in
            guard draft[position] == nil, let old = current[position], !stillFielding.contains(old) else { return nil }
            return old
        }
        return Substitution(team: team, defense: assignments, leavesField: leaving)
    }
}
