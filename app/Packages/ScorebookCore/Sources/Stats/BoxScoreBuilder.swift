// One game's box score, added up from its play log.
//
// The builder reads the play log once, entry by entry, keeping running tallies the way a
// scorer fills in the back of a scorebook: each batter's line, each pitcher's line, each
// fielder's putouts, assists and errors and the innings they played, the runs in each half
// inning, and the runners stranded when each half inning ended. Then it lays the tallies out
// in box score order.
//
// Who gets credit for what:
//   - A plate appearance belongs to the batter and to the pitcher the play log charges, which
//     is usually the one on the mound (a walk after a mid-count pitching change can belong to
//     the earlier pitcher, rule 9.16(h)).
//   - Pitches and strikes count against the pitcher on the mound when they were thrown.
//   - A run is credited to whoever the play log credits (the designated non-runner, when
//     someone ran for them) and charged to the pitcher who put that runner on base, so a
//     reliever is not charged for a runner they inherited.
//   - Stolen bases and caught stealing go to whoever actually ran.
//   - Putouts, assists and errors go to the player who was at that position at that moment,
//     which the play log records.

import Model

/// Builds one game's box score from its play log.
struct BoxScoreBuilder {
    let log: PlayLog

    /// Reads the whole play log and lays out the box score.
    func build() -> BoxScore {
        var tally = GameTally(log: log)
        tally.readPlayLog()

        let away = tally.teamBox(.away)
        let home = tally.teamBox(.home)
        return BoxScore(
            gameID: log.gameID,
            date: log.setup.scheduledStart,
            away: away,
            home: home,
            lineScore: tally.lineScore(),
            notes: tally.notes(away: away, home: home),
            isFinal: log.isFinal,
            gameLength: log.gameLength
        )
    }
}

/// The running tallies for one game, filled in by reading the play log entry by entry.
private struct GameTally {
    let log: PlayLog

    init(log: PlayLog) {
        self.log = log
        decisions = log.pitchingDecisions()
        substituteEntries = log.substituteEntries()
    }

    /// The winning and losing pitchers, once the game is final.
    let decisions: [PlayerID: PitchingDecision]
    /// How each substitute came in, for the footnotes.
    let substituteEntries: [PlayerID: SubstituteEntry]

    // MARK: Running tallies

    /// Each batter's counting stats.
    var batting: [PlayerID: BattingCounts] = [:]
    /// Each pitcher's counting stats.
    var pitching: [PlayerID: PitchingCounts] = [:]
    /// Each fielder's putouts, assists and errors.
    var fielding: [PlayerID: FieldingCounts] = [:]
    /// Which team each fielder and pitcher played for.
    var fieldingSide: [PlayerID: TeamSide] = [:]
    /// Pitchers in the order they first pitched, for each team.
    var pitchers: [TeamSide: OrderedSet<PlayerID>] = [.away: OrderedSet(), .home: OrderedSet()]
    /// Fielders in the order they first appeared, for each team.
    var fielders: [TeamSide: OrderedSet<PlayerID>] = [.away: OrderedSet(), .home: OrderedSet()]

    /// A fielder at a position: the key for the innings they played there.
    struct Spot: Hashable {
        var player: PlayerID
        var position: Position
    }
    /// The innings each fielder played at each position, counting only events where the ball
    /// was played, and the play log entry where they first did.
    var playInnings: [Spot: (innings: Set<Int>, firstEntry: Int)] = [:]
    /// The same, from lineup events only (substitutions, defense checks), for a fielder who
    /// came in and never saw a ball played before the game ended.
    var lineupInnings: [Spot: (innings: Set<Int>, firstEntry: Int)] = [:]
    /// The order each fielder's positions were first seen in.
    var spotsInOrder: OrderedSet<Spot> = OrderedSet()

    /// "ph" and "pr" for pinch hitters and pinch runners, with the entry where they came in.
    var pinchRoles: [PlayerID: [(position: BoxPosition, entry: Int)]] = [:]
    /// Who ran for each designated non-runner, in the order they first ran.
    var nonRunnerRunners: [PlayerID: OrderedSet<PlayerID>] = [:]
    /// Players who finished a plate appearance, with the spot in the order they batted from,
    /// for each team. Used only to make sure no batter is left out of the box score.
    var battersSeen: [TeamSide: [(player: PlayerID, spot: Int)]] = [.away: [], .home: []]

    /// Runs by inning for each team, manual score changes included.
    var runsByInning: [TeamSide: [Int: Int]] = [.away: [:], .home: [:]]
    /// Every half inning in which the ball was played (or the score was changed by hand).
    var halvesPlayed: Set<HalfInningKey> = []
    /// Runs for each team, manual score changes included: the team's final score.
    var teamRuns: [TeamSide: Int] = [.away: 0, .home: 0]
    /// Hits for each team.
    var teamHits: [TeamSide: Int] = [.away: 0, .home: 0]
    /// Errors each team made in the field, including errors by a fielder nobody named.
    var teamErrors: [TeamSide: Int] = [.away: 0, .home: 0]
    /// Runners left on base by each team.
    var leftOnBase: [TeamSide: Int] = [.away: 0, .home: 0]
    /// Double and triple plays each team turned in the field.
    var doublePlays: [TeamSide: Int] = [.away: 0, .home: 0]
    var triplePlays: [TeamSide: Int] = [.away: 0, .home: 0]

    /// One half inning: the third inning's bottom half, say.
    struct HalfInningKey: Hashable {
        var inning: Int
        var half: HalfInning
    }

    // MARK: Reading the play log

    /// Goes through every entry in order and adds it to the tallies.
    mutating func readPlayLog() {
        for (index, entry) in log.entries.enumerated() {
            read(entry, at: index)
        }
    }

    /// Adds one play log entry to the tallies.
    private mutating func read(_ entry: PlayLogEntry, at index: Int) {
        let battingTeam = entry.battingSide
        let fieldingTeam = entry.fieldingSide

        // Where everyone was standing, for the innings each fielder played.
        noteFielders(entry, at: index)

        // The pitcher on the mound: their pitches, strikes and outs.
        if let pitcher = entry.pitcher {
            if entry.isPlayOnField { notePitcher(pitcher, side: fieldingTeam) }
            pitching[pitcher, default: PitchingCounts()].pitches += entry.pitches
            pitching[pitcher, default: PitchingCounts()].strikes += entry.strikes
            // Every out made while they were on the mound, a batting hole's automatic out
            // included, counts toward their innings pitched.
            pitching[pitcher, default: PitchingCounts()].outsRecorded += entry.outs.count
        }

        // A plate appearance that ended: the batter's line and the charged pitcher's line.
        if let result = entry.plateAppearance {
            // A pinch hitter's strikeout can belong to the batter they replaced [9.15(b)].
            batting[result.batterCharged, default: BattingCounts()].add(result)
            if let spot = entry.batterIndex {
                battersSeen[battingTeam, default: []].append((result.batter, spot))
            }
            if result.outcome.isHit { teamHits[battingTeam, default: 0] += 1 }
            if let pitcher = result.pitcher {
                notePitcher(pitcher, side: fieldingTeam)
                pitching[pitcher, default: PitchingCounts()].add(result)
            }
        }

        // Runs: credited to the runner (or the designated non-runner they ran for), charged
        // to the pitcher who put the runner on base.
        for run in entry.runs {
            batting[run.creditedTo, default: BattingCounts()].runs += 1
            if let pitcher = run.responsiblePitcher {
                notePitcher(pitcher, side: fieldingTeam)
                pitching[pitcher, default: PitchingCounts()].runs += 1
            }
        }
        teamRuns[battingTeam, default: 0] += entry.runs.count
        if !entry.runs.isEmpty {
            runsByInning[battingTeam, default: [:]][entry.inning, default: 0] += entry.runs.count
        }

        // Runs a manual adjustment added or took away: they count for the team, in this
        // inning, but belong to no player and no pitcher.
        if let adjusted = entry.adjustedRuns {
            for side in TeamSide.allCases where adjusted[side] != 0 {
                teamRuns[side, default: 0] += adjusted[side]
                runsByInning[side, default: [:]][entry.inning, default: 0] += adjusted[side]
            }
            halvesPlayed.insert(HalfInningKey(inning: entry.inning, half: entry.half))
        }
        if entry.isPlayOnField {
            halvesPlayed.insert(HalfInningKey(inning: entry.inning, half: entry.half))
        }

        // Stolen bases and caught stealing, to whoever actually ran.
        for move in entry.runnerMoves {
            switch move.reason {
            case .stolenBase: batting[move.runner, default: BattingCounts()].stolenBases += 1
            default:
                // Caught stealing, or picked off while trying to steal [9.07(h)].
                if move.countsAsCaughtStealing { batting[move.runner, default: BattingCounts()].caughtStealing += 1 }
            }
        }

        // Putouts and assists. A fielder gets at most one assist on any one out, even if they
        // handled the ball twice in a rundown (rule 9.10).
        //
        // A batting hole's automatic out is not a real play, so nobody gets its putout (the
        // play log leaves `putout` empty). A team's putouts can therefore add up to fewer than
        // the outs its pitchers recorded.
        for out in entry.outs {
            if let putout = out.putout {
                noteFielder(putout, side: fieldingTeam)
                fielding[putout, default: FieldingCounts()].putouts += 1
            }
            var assisted: Set<PlayerID> = []
            for assist in out.assists where assisted.insert(assist).inserted {
                noteFielder(assist, side: fieldingTeam)
                fielding[assist, default: FieldingCounts()].assists += 1
            }
        }

        // Errors, to the player at that position; the team's count includes errors by a
        // fielder nobody named.
        for error in entry.errors {
            teamErrors[fieldingTeam, default: 0] += 1
            if let player = error.player {
                noteFielder(player, side: fieldingTeam)
                fielding[player, default: FieldingCounts()].errors += 1
            }
        }

        // Double and triple plays turned by the fielding team.
        switch entry.multiOutTurned {
        case .doublePlay: doublePlays[fieldingTeam, default: 0] += 1
        case .triplePlay: triplePlays[fieldingTeam, default: 0] += 1
        case nil: break
        }

        // Runners left on base: those still on base when a half inning ended, and those still
        // on base when the game ended (after a walk-off, or when the time limit ran out).
        if entry.endsHalfInning || entry.isEndOfGame {
            leftOnBase[battingTeam, default: 0] += entry.after.runners.count
        }

        // Pinch hitters, pinch runners, new pitchers, and runners for designated non-runners.
        switch entry.event.kind {
        case .substitution(let substitution):
            for change in substitution.batting {
                switch change.kind {
                case .pinchHitter: pinchRoles[change.incoming, default: []].append((.ph, index))
                case .pinchRunner: pinchRoles[change.incoming, default: []].append((.pr, index))
                case .replacement: break
                }
            }
        case .pitchingChange(let change):
            // A pitcher who comes in gets a line even if the game ends before they throw.
            notePitcher(change.newPitcher, side: change.team)
        case .runnerForNonRunner(let runner):
            nonRunnerRunners[runner.replacing, default: OrderedSet()].add(runner.runner)
        default:
            break
        }
    }

    /// Records that a pitcher pitched for a team, keeping the order they first pitched in.
    private mutating func notePitcher(_ pitcher: PlayerID, side: TeamSide) {
        pitchers[side, default: OrderedSet()].add(pitcher)
        fieldingSide[pitcher] = side
    }

    /// Records that a player fielded for a team.
    private mutating func noteFielder(_ player: PlayerID, side: TeamSide) {
        fielders[side, default: OrderedSet()].add(player)
        fieldingSide[player] = side
    }

    /// Records the innings each fielder played at each position, from who the play log says
    /// was standing where during this entry.
    private mutating func noteFielders(_ entry: PlayLogEntry, at index: Int) {
        guard entry.isPlayOnField || entry.isLineupMoment else { return }
        for assignment in entry.fielders {
            let spot = Spot(player: assignment.player, position: assignment.position)
            noteFielder(assignment.player, side: entry.fieldingSide)
            spotsInOrder.add(spot)
            if entry.isPlayOnField {
                playInnings[spot, default: ([], index)].innings.insert(entry.inning)
            } else {
                lineupInnings[spot, default: ([], index)].innings.insert(entry.inning)
            }
        }
    }

    // MARK: Laying out one team

    /// One team's half of the box score.
    func teamBox(_ side: TeamSide) -> TeamBoxScore {
        let team = log.setup[side]
        let battingLines = battingLines(side)
        return TeamBoxScore(
            side: side,
            teamID: team.teamID,
            name: team.name,
            batting: battingLines,
            pitching: pitchingLines(side),
            fielding: fieldingLines(side, battingOrder: battingLines.map(\.player)),
            runs: teamRuns[side] ?? 0,
            hits: teamHits[side] ?? 0,
            errors: teamErrors[side] ?? 0,
            leftOnBase: leftOnBase[side] ?? 0
        )
    }

    /// The team's batting lines: spot by spot down the order, each spot's first player and
    /// then whoever replaced them, plus a "pr" line under a designated non-runner for anyone
    /// who ran for them and holds no batting spot of their own.
    private func battingLines(_ side: TeamSide) -> [BattingLine] {
        let order = log.battingOrder(side)
        let startingOrder = log.setup[side].battingOrder
        let everyoneInOrder = Set(order.slots.flatMap(\.players))
        var lines: [BattingLine] = []
        var listed: Set<PlayerID> = []

        for (spot, slot) in order.slots.enumerated() {
            for player in slot.players where !listed.contains(player) {
                listed.insert(player)
                // A substitute is anyone who was not this spot's starter.
                let starter = spot < startingOrder.count ? startingOrder[spot] : nil
                lines.append(battingLine(player, spot: spot, isSubstitute: player != starter, side: side))

                // Right under a designated non-runner: anyone who ran for them without a
                // batting spot of their own, with their stolen bases and caught stealing.
                for runner in nonRunnerRunners[player]?.items ?? []
                where !everyoneInOrder.contains(runner) && !listed.contains(runner) {
                    listed.insert(runner)
                    var line = battingLine(runner, spot: spot, isSubstitute: true, side: side)
                    line.positions = uniqueInOrder([.pr] + line.positions)
                    lines.append(line)
                }
            }
        }

        // A batter the play log says batted but who is missing from the final batting order
        // (the play log disagrees with itself after an edit) still gets a line, at the end,
        // so no plate appearance is lost.
        for (player, spot) in battersSeen[side] ?? [] where !listed.contains(player) {
            listed.insert(player)
            lines.append(battingLine(player, spot: spot, isSubstitute: true, side: side))
        }
        return lines
    }

    /// One batter's line, with their name, number, positions and stats.
    private func battingLine(_ player: PlayerID, spot: Int, isSubstitute: Bool, side: TeamSide) -> BattingLine {
        let person = log.setup[side].player(player) ?? log.setup.player(player)
        return BattingLine(
            player: player,
            name: person?.displayName ?? player.rawValue,
            number: person?.number,
            batterIndex: spot,
            positions: positions(of: player),
            isSubstitute: isSubstitute,
            stats: batting[player] ?? BattingCounts(),
            entered: isSubstitute ? substituteEntries[player] : nil
        )
    }

    /// Every position a player played, in the order they first played it, with "ph" or "pr"
    /// where they came in as a pinch hitter or pinch runner: "ph", then "2b".
    private func positions(of player: PlayerID) -> [BoxPosition] {
        var timeline: [(entry: Int, position: BoxPosition)] = (pinchRoles[player] ?? []).map { ($0.entry, $0.position) }
        for (spot, entry, _) in appearances(of: player) {
            timeline.append((entry, BoxPosition(spot.position)))
        }
        // Sort by when it happened; ties keep their order.
        let sorted = timeline.enumerated().sorted { ($0.element.entry, $0.offset) < ($1.element.entry, $1.offset) }
        return uniqueInOrder(sorted.map(\.element.position))
    }

    /// The positions a player played, each with the innings they played it and the entry
    /// where they first did. Innings come from events where the ball was played; a position
    /// they took only at a lineup change (a defensive replacement just before the game ended)
    /// uses the inning of that change instead.
    private func appearances(of player: PlayerID) -> [(spot: Spot, firstEntry: Int, innings: [Int])] {
        spotsInOrder.items.filter { $0.player == player }.compactMap { spot in
            if let played = playInnings[spot] {
                return (spot, played.firstEntry, played.innings.sorted())
            }
            if let listed = lineupInnings[spot] {
                return (spot, listed.firstEntry, listed.innings.sorted())
            }
            return nil
        }
        .sorted { $0.firstEntry < $1.firstEntry }
    }

    /// The team's pitching lines, in the order the pitchers first pitched. A pitcher who came
    /// back later in the game keeps one line.
    private func pitchingLines(_ side: TeamSide) -> [PitchingLine] {
        (pitchers[side]?.items ?? []).map { pitcher in
            let person = log.setup[side].player(pitcher) ?? log.setup.player(pitcher)
            return PitchingLine(
                player: pitcher,
                name: person?.displayName ?? pitcher.rawValue,
                number: person?.number,
                stats: pitching[pitcher] ?? PitchingCounts(),
                decision: decisions[pitcher]
            )
        }
    }

    /// The team's fielding lines: a line for every player who took a position, even with no
    /// putouts, assists or errors. Listed in batting order, then anyone who fielded without
    /// batting, in the order they first took the field.
    private func fieldingLines(_ side: TeamSide, battingOrder: [PlayerID]) -> [FieldingLine] {
        let fieldedForTeam = fielders[side] ?? OrderedSet()
        var order = OrderedSet<PlayerID>()
        for player in battingOrder where fieldedForTeam.contains(player) { order.add(player) }
        for player in fieldedForTeam.items { order.add(player) }

        return order.items.map { player in
            let person = log.setup[side].player(player) ?? log.setup.player(player)
            let appearances = appearances(of: player).map {
                FieldingAppearance(position: $0.spot.position, innings: $0.innings)
            }
            return FieldingLine(
                player: player,
                name: person?.displayName ?? player.rawValue,
                appearances: appearances,
                stats: fielding[player] ?? FieldingCounts()
            )
        }
    }

    // MARK: Line score and notes

    /// Runs by inning for both teams, from the first inning to the last one played. The home
    /// team's cell for the last inning is empty ("x") when they did not bat in it, as when they
    /// led after the top half. An inning skipped over by a manual adjustment shows 0.
    func lineScore() -> LineScore {
        let lastInning = halvesPlayed.map(\.inning).max() ?? 0
        guard lastInning > 0 else { return LineScore(away: [], home: []) }

        let away: [Int?] = (1...lastInning).map { runsByInning[.away]?[$0] ?? 0 }
        let home: [Int?] = (1...lastInning).map { inning in
            let didNotBat = inning == lastInning
                && !halvesPlayed.contains(HalfInningKey(inning: inning, half: .bottom))
                && runsByInning[.home]?[inning] == nil
            return didNotBat ? nil : (runsByInning[.home]?[inning] ?? 0)
        }
        return LineScore(away: away, home: home)
    }

    /// The notes under the box score, visitors first, players in box score order.
    func notes(away: TeamBoxScore, home: TeamBoxScore) -> BoxScoreNotes {
        let teams = [away, home]

        /// Every player with a count above zero, as "Ruiz 2" entries.
        func tallies(_ count: (PlayerID, TeamBoxScore) -> Int) -> [PlayerTally] {
            teams.flatMap { team in
                notePlayers(team).compactMap { player, name in
                    let n = count(player, team)
                    return n > 0 ? PlayerTally(player: player, name: name, team: team.side, count: n) : nil
                }
            }
        }
        /// A batting stat added over the player's lines in one team's box score.
        func battingStat(_ stat: KeyPath<BattingCounts, Int>) -> [PlayerTally] {
            tallies { player, team in
                team.batting.filter { $0.player == player }.reduce(0) { $0 + $1.stats[keyPath: stat] }
            }
        }
        /// One count per team, for teams with a count above zero (or every team when `always`).
        func teamTallies(_ counts: [TeamSide: Int], always: Bool = false) -> [TeamTally] {
            teams.compactMap { team in
                let n = counts[team.side] ?? 0
                return (n > 0 || always) ? TeamTally(team: team.side, name: team.name, count: n) : nil
            }
        }

        return BoxScoreNotes(
            errors: tallies { player, team in
                team.fielding.filter { $0.player == player }.reduce(0) { $0 + $1.stats.errors }
            },
            doubles: battingStat(\.doubles),
            triples: battingStat(\.triples),
            homeRuns: battingStat(\.homeRuns),
            runsBattedIn: battingStat(\.runsBattedIn),
            stolenBases: battingStat(\.stolenBases),
            caughtStealing: battingStat(\.caughtStealing),
            sacrificeFlies: battingStat(\.sacrificeFlies),
            sacrificeBunts: battingStat(\.sacrificeBunts),
            hitByPitch: battingStat(\.hitByPitch),
            doublePlays: teamTallies(doublePlays),
            triplePlays: teamTallies(triplePlays),
            leftOnBase: teamTallies(leftOnBase, always: true),
            hitBatters: log.hitBatterNotes(),
            ranForNonRunners: log.nonRunnerRunnerNotes()
        )
    }

    /// Everyone in one team's box score, once each, in box score order: batters, then fielders
    /// who did not bat, then pitchers who did neither.
    private func notePlayers(_ team: TeamBoxScore) -> [(PlayerID, String)] {
        var seen = OrderedSet<PlayerID>()
        var names: [PlayerID: String] = [:]
        for line in team.batting { seen.add(line.player); names[line.player] = names[line.player] ?? line.name }
        for line in team.fielding { seen.add(line.player); names[line.player] = names[line.player] ?? line.name }
        for line in team.pitching { seen.add(line.player); names[line.player] = names[line.player] ?? line.name }
        return seen.items.map { ($0, names[$0] ?? $0.rawValue) }
    }
}

/// A list with repeats removed, keeping the first of each.
private func uniqueInOrder<T: Hashable>(_ items: [T]) -> [T] {
    var set = OrderedSet<T>()
    for item in items { set.add(item) }
    return set.items
}
