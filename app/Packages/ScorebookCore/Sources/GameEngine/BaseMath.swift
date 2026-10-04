// Base math: small helpers for counting bases, shared by the replay and the suggestions.
// "Two bases from first is third", "which runners are forced when the batter goes to first",
// "list the runners lead runner first".

import Foundation
import Model

enum BaseMath {
    /// Where a runner ends up after moving `bases` bases from `base`: a base, or scored.
    static func advance(_ base: Base, by bases: Int) -> RunnerEnd {
        let to = base.order + bases
        if to >= 4 { return .scored }
        if to <= 0 { return .safe(at: .home) }
        return RunnerEnd.safe(at: Base.occupiable[to - 1])
    }

    /// The next base along: where a forced runner from `base` is headed.
    static func nextBase(after base: Base) -> Base {
        base.order >= 3 ? .home : Base.occupiable[base.order]
    }

    /// How many bases a move covers: first to third is two, second to scored is two.
    static func distance(from: Base, to: RunnerEnd) -> Int {
        switch to {
        case .scored: return 4 - from.order
        case .out: return 0
        default: return (to.base?.order ?? from.order) - from.order
        }
    }

    /// The order of an ending: first 1, second 2, third 3, scored 4.
    static func order(of end: RunnerEnd) -> Int {
        switch end {
        case .scored: 4
        case .out: 0
        default: end.base?.order ?? 0
        }
    }

    /// The bases whose runners must move up when the batter is awarded first: the runner on
    /// first, the runner on second if first is also taken, and so on up the line.
    static func forcedBases(_ runners: [BaseRunner]) -> Set<Base> {
        var forced: Set<Base> = []
        for base in Base.occupiable {
            guard runners.contains(where: { $0.base == base }) else { break }
            forced.insert(base)
        }
        return forced
    }

    /// Runners listed lead runner first: third, then second, then first.
    static func leadFirst(_ runners: [BaseRunner]) -> [BaseRunner] {
        runners.sorted { $0.base > $1.base }
    }
}
