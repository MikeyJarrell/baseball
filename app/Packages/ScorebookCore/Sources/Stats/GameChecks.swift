// Checks of a finished game for scoring that is possible but unlikely, so a slip made in a
// hurry is caught before the stats are published: a batter scoring on his own single, a
// substitution undone straight after, two copies of one player, a pitcher nobody named, one
// pitcher throwing every inning. Each finding is a sentence to put to the scorer; none of them
// changes the game.

import Foundation
import Model

/// Unlikely scoring in one game.
public enum GameChecks {
    /// Everything in the game worth asking the scorer about, in the order it happened.
    public static func findings(in game: Game, log: PlayLog) -> [String] {
        var found: [String] = []
        let setup = game.setup
        func name(_ id: PlayerID?) -> String { id.flatMap { setup.player($0)?.displayName } ?? "someone" }
        func when(_ entry: PlayLogEntry) -> String {
            "\(entry.half == .top ? "Top" : "Bottom") of the \(ordinal(entry.inning))"
        }
        let hitBases: [BatterResult: Int] = [.single: 1, .double: 2, .triple: 3]

        for (index, entry) in log.entries.enumerated() {
            if entry.needsReview {
                found.append("\(when(entry)): the app marked this play for review. \(entry.reviewNote ?? "")")
            }
            switch entry.event.kind {
            case .ballInPlay(let play):
                guard let bases = hitBases[play.batterResult] else { break }
                for move in play.runners where !move.advancedOnError && move.reason == nil {
                    let gained = (move.to == .scored ? 4 : move.to.base?.order ?? 0) - move.from.order
                    if move.isBatter, move.to == .scored {
                        found.append("\(when(entry)): \(name(move.runner)) scored on his own \(play.batterResult.label), with no error.")
                    } else if move.isBatter, gained > bases + 1 {
                        found.append("\(when(entry)): \(name(move.runner)) reached \(move.to.rawValue) on a \(play.batterResult.label), with no error.")
                    } else if !move.isBatter, gained >= 3, bases == 1 {
                        found.append("\(when(entry)): \(name(move.runner)) scored from first on a single, with no error.")
                    }
                }
            case .substitution(let sub):
                for change in sub.batting {
                    if change.kind == .pinchRunner, setup[sub.team].isDesignatedNonRunner(change.replacing) {
                        found.append("\(when(entry)): a pinch runner for \(name(change.replacing)), a designated non-runner. Was it the non-runner’s runner instead?")
                    }
                    // The same two players swapped back within the next few events.
                    let later = log.entries[(index + 1)...].prefix(150)
                    if later.contains(where: { other in
                        if case .substitution(let back) = other.event.kind {
                            return back.batting.contains { $0.incoming == change.replacing && $0.replacing == change.incoming }
                        }
                        return false
                    }) {
                        found.append("\(when(entry)): \(name(change.incoming)) replaced \(name(change.replacing)), and soon after it was undone. A slip?")
                    }
                }
            default:
                break
            }
        }

        for side in TeamSide.allCases {
            let team = setup[side]
            // Two copies of one player: the same number, or one name the last word of another.
            let players = team.roster
            for (i, a) in players.enumerated() {
                for b in players[(i + 1)...] {
                    let sameNumber = a.number != nil && a.number == b.number && !(a.number ?? "").isEmpty
                    let an = a.name ?? "", bn = b.name ?? ""
                    let nested = !an.isEmpty && !bn.isEmpty && an != bn
                        && (an.split(separator: " ").contains { bn.hasSuffix(" \($0)") || bn == String($0) }
                            || bn.split(separator: " ").contains { an.hasSuffix(" \($0)") || an == String($0) })
                    if sameNumber && nested || (!team.isOurs ? false : nested && sameNumber) {
                        found.append("\(team.name): \(a.displayName) and \(b.displayName) may be the same player.")
                    } else if sameNumber {
                        found.append("\(team.name): \(a.displayName) and \(b.displayName) both wear #\(a.number ?? "").")
                    }
                }
            }
            // Who pitched for this team, from the plays they were in the field for.
            let fielding = log.entries.filter { $0.half.fieldingSide == side }
            let pitchers = Array(Set(fielding.compactMap(\.pitcher)))
            for id in pitchers where setup.player(id)?.isUnnamed == true {
                found.append("\(team.name): a pitcher with no name or number (“\(name(id))”). Who was it?")
            }
            let innings = Set(fielding.map(\.inning)).count
            if pitchers.count == 1, innings >= 6 {
                found.append("\(team.name): \(name(pitchers.first)) pitched all \(innings) innings. Any pitching changes missed?")
            }
        }
        return found
    }

    private static func ordinal(_ n: Int) -> String {
        let ones = n % 10, tens = (n / 10) % 10
        let suffix = tens == 1 ? "th" : (ones == 1 ? "st" : ones == 2 ? "nd" : ones == 3 ? "rd" : "th")
        return "\(n)\(suffix)"
    }
}
