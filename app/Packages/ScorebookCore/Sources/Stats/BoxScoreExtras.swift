// The parts of a box score that need more than a running tally: the winning and losing
// pitchers, which pitcher hit each batter, who ran for each designated non-runner, how each
// substitute came in, and how long the game took. Each is read straight from the play log.

import Foundation
import Model

extension PlayLog {
    // MARK: Game length

    /// Seconds from the first pitch to the end-of-game event, once the game is final: the
    /// box score's "T—1:58".
    var gameLength: TimeInterval? {
        guard isFinal,
              let first = entries.first(where: { $0.pitches > 0 })?.event.enteredAt,
              let end = entries.last(where: \.isEndOfGame)?.event.enteredAt else { return nil }
        return end.timeIntervalSince(first)
    }

    // MARK: Winning and losing pitchers

    /// The winning and losing pitchers of a finished game that did not end tied, under
    /// official scoring rule 9.17. Empty otherwise.
    ///
    /// - The winning team took the lead for good at the last moment it went from not ahead to
    ///   ahead. Its pitcher of record then is the one who last pitched for it, or its starter
    ///   if nobody has yet.
    /// - That pitcher gets the win, unless they are the starter without five complete innings
    ///   (four when the winning team played only five innings in the field) and a reliever
    ///   pitched. Then the win goes to a relief pitcher. A starter nobody relieved keeps it. The rule leaves which one to the scorer's judgment; this picks the
    ///   reliever with the most outs, then the fewest runs charged, then the earliest.
    /// - The loss goes to the pitcher charged with the run that gave the winners the lead for
    ///   good. A lead that came from a manual score change charges nobody.
    func pitchingDecisions() -> [PlayerID: PitchingDecision] {
        guard isFinal else { return [:] }
        var score = Score()
        var leadForGood: (index: Int, before: Score)?
        var finalScore = Score()
        for (i, entry) in entries.enumerated() {
            let before = score
            score[entry.battingSide] += entry.runs.count
            if let adjusted = entry.adjustedRuns {
                for side in TeamSide.allCases { score[side] += adjusted[side] }
            }
            // A team that was not ahead before this entry and is now: a new lead. The last new
            // lead in the game is the winners' lead for good.
            let leader = TeamSide.allCases.first { score[$0] > score[$0.opponent] }
            let leaderBefore = TeamSide.allCases.first { before[$0] > before[$0.opponent] }
            if let leader, leader != leaderBefore { leadForGood = (i, before) }
            finalScore = score
        }
        guard finalScore.away != finalScore.home, let lead = leadForGood else { return [:] }
        let winner: TeamSide = finalScore.away > finalScore.home ? .away : .home
        var decisions: [PlayerID: PitchingDecision] = [:]

        // The winner: the pitcher of record when the lead was taken for good.
        let pitchedForWinner = entries[...lead.index]
            .filter { $0.fieldingSide == winner && $0.isPlayOnField }
            .compactMap(\.pitcher)
        let starter = setup[winner].startingPitcher
        if let ofRecord = pitchedForWinner.last ?? starter {
            if ofRecord == starter, outsRecorded(by: ofRecord) < outsNeededByStarter(winner),
               let reliever = mostEffectiveReliever(for: winner, starter: starter) {
                decisions[reliever] = .win
            } else {
                // The pitcher of record, including a starter in a short game nobody relieved:
                // rule 9.17(b) sets innings only for games of five or more innings in the field.
                decisions[ofRecord] = .win
            }
        }

        // The loser: the pitcher charged with the go-ahead run.
        let entry = entries[lead.index]
        if entry.battingSide == winner {
            let needed = lead.before[winner.opponent] - lead.before[winner] + 1
            let scored = runsLeadRunnerFirst(entry)
            if needed >= 1, needed <= scored.count, let pitcher = scored[needed - 1].responsiblePitcher {
                decisions[pitcher] = .loss
            }
        }
        return decisions
    }

    /// Outs made while a pitcher was on the mound.
    private func outsRecorded(by pitcher: PlayerID) -> Int {
        entries.filter { $0.pitcher == pitcher }.reduce(0) { $0 + $1.outs.count }
    }

    /// The outs a starter needs for the win: five complete innings, or four when their team
    /// played only five innings in the field [9.17(b)].
    private func outsNeededByStarter(_ side: TeamSide) -> Int {
        let inningsInField = Set(entries.filter { $0.fieldingSide == side && $0.isPlayOnField }.map(\.inning)).count
        return inningsInField <= 5 ? 12 : 15
    }

    /// The relief pitcher credited with the win when the starter does not qualify.
    private func mostEffectiveReliever(for side: TeamSide, starter: PlayerID?) -> PlayerID? {
        var relievers: [PlayerID] = []
        for entry in entries where entry.fieldingSide == side && entry.isPlayOnField {
            if let p = entry.pitcher, p != starter, !relievers.contains(p) { relievers.append(p) }
        }
        let charged = { (p: PlayerID) in self.entries.flatMap(\.runs).filter { $0.responsiblePitcher == p }.count }
        return relievers.enumerated().max { a, b in
            (outsRecorded(by: a.element), -charged(a.element), -a.offset) < (outsRecorded(by: b.element), -charged(b.element), -b.offset)
        }?.element
    }

    /// The runs that scored on an entry, the lead runner's first, as they crossed the plate.
    private func runsLeadRunnerFirst(_ entry: PlayLogEntry) -> [RunScored] {
        let from = Dictionary(entry.runnerMoves.map { ($0.runner, $0.from) }, uniquingKeysWith: { a, _ in a })
        return entry.runs.enumerated().sorted { a, b in
            let fa = from[a.element.runner]?.order ?? 0, fb = from[b.element.runner]?.order ?? 0
            return fa != fb ? (fa == 0 ? false : fb == 0 ? true : fa > fb) : a.offset < b.offset
        }.map(\.element)
    }

    // MARK: Notes

    /// Each batter hit by a pitch, with the pitcher, visitors first, in the order it happened.
    func hitBatterNotes() -> [HitBatterNote] {
        var notes: [HitBatterNote] = []
        for entry in entries {
            guard let result = entry.plateAppearance, result.outcome == .hitByPitch else { continue }
            if let i = notes.firstIndex(where: { $0.batter == result.batter && $0.pitcher == result.pitcher }) {
                notes[i].count += 1
            } else {
                notes.append(HitBatterNote(
                    batter: result.batter, batterName: name(result.batter), team: entry.battingSide,
                    pitcher: result.pitcher, pitcherName: result.pitcher.map(name), count: 1))
            }
        }
        return notes.filter { $0.team == .away } + notes.filter { $0.team == .home }
    }

    /// Who ran for each designated non-runner, and in which innings, visitors first.
    func nonRunnerRunnerNotes() -> [NonRunnerRunnerNote] {
        var notes: [NonRunnerRunnerNote] = []
        for entry in entries {
            guard case .runnerForNonRunner(let r) = entry.event.kind else { continue }
            if let i = notes.firstIndex(where: { $0.runner == r.runner && $0.nonRunner == r.replacing }) {
                if !notes[i].innings.contains(entry.inning) { notes[i].innings.append(entry.inning) }
            } else {
                notes.append(NonRunnerRunnerNote(
                    runner: r.runner, runnerName: name(r.runner), nonRunner: r.replacing,
                    nonRunnerName: name(r.replacing), team: entry.battingSide, innings: [entry.inning]))
            }
        }
        return notes.filter { $0.team == .away } + notes.filter { $0.team == .home }
    }

    // MARK: Substitutes

    /// How each substitute first came into the batting order: the inning, the kind of change,
    /// whose spot they took, and how the plate appearance they finished in that same
    /// half-inning ended, if any.
    func substituteEntries() -> [PlayerID: SubstituteEntry] {
        var found: [PlayerID: SubstituteEntry] = [:]
        for (i, entry) in entries.enumerated() {
            var changes: [(incoming: PlayerID, replacing: PlayerID, kind: BattingChangeKind)] = []
            switch entry.event.kind {
            case .substitution(let sub):
                changes = sub.batting.map { ($0.incoming, $0.replacing, $0.kind) }
            case .pitchingChange(let change):
                if let spot = change.takesBattingSpotOf { changes = [(change.newPitcher, spot, .replacement)] }
            default:
                break
            }
            for change in changes where found[change.incoming] == nil {
                let later = entries[(i + 1)...].first {
                    $0.inning == entry.inning && $0.half == entry.half && $0.plateAppearance?.batter == change.incoming
                }
                found[change.incoming] = SubstituteEntry(
                    inning: entry.inning, kind: change.kind, replaced: change.replacing,
                    replacedName: name(change.replacing),
                    outcome: later?.plateAppearance?.outcome, notation: later?.notation)
            }
        }
        return found
    }

    /// A player's name as the box score prints it.
    private func name(_ id: PlayerID) -> String {
        setup.player(id)?.displayName ?? id.rawValue
    }
}
