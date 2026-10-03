// Replay: works through a game's events from the first pitch to the latest one, keeping the
// situation (inning, outs, count, runners, lineups) up to date, and writing one play log
// entry for each event.
//
// The rules applied here are the ones a scorer applies without thinking: four balls is a
// walk, three strikes is a strikeout, three outs switch sides, the batting order wraps, a
// walk pushes forced runners up. Anything that needs judgment (where a runner went on a
// hit, whether a run counted) comes from the event itself, as the scorer entered it.
//
// When an event no longer makes sense, usually because an earlier one was edited (a steal
// by a runner who is no longer on base), the entry is marked "needs review" and the replay
// carries on with whatever part of the event still makes sense. It never stops or crashes.

import Foundation
import Model

/// One pass through a game's events.
struct Replay {
    let game: Game
    private var setup: GameSetup { game.setup }

    /// Where the game stands after the events so far.
    private(set) var s: Situation
    /// One play log entry per event so far.
    private(set) var entries: [PlayLogEntry] = []

    // MARK: Bookkeeping the situation does not carry

    /// The umpire's end of the time limit, once the scorer has set one. `nil` inside means the
    /// scorer went back to the first pitch plus the setup's limit.
    private var umpireLimit: Date?? = nil
    /// Official Baseball Rules 9.16(h): when the pitcher is changed with the count at 2-0, 2-1,
    /// 3-0, 3-1 or 3-2, a walk to this batter belongs to the earlier pitcher. That pitcher is
    /// kept here until the plate appearance ends.
    private var walkChargedTo: PlayerID?
    /// The spot in each team's order whose plate appearance ended most recently, so a hitter
    /// added after the last spot just batted can be put up next.
    private var lastSpotUp: [TeamSide: Int] = [:]
    /// True once the batter now up has seen any play (a pitch, a steal). A batter who was up
    /// when a runner made the third out still leads off next time, even with no pitches.
    private var batterStarted: [TeamSide: Bool] = [:]
    /// Plate appearances completed in each batting spot, for the re-entry rule.
    private var spotAppearances: [TeamSide: [Int]] = [:]
    /// For each batting spot whose starter has been replaced: how many plate appearances the
    /// spot had at that moment. The starter may re-enter once the spot has had more [9.9].
    private var starterLeftAt: [TeamSide: [Int?]] = [:]
    /// The starter of each batting spot; `nil` for spots added during the game.
    private var spotStarters: [TeamSide: [PlayerID?]] = [:]
    /// Each pitcher who has pitched for a team, in order, with how many times they have taken
    /// the mound. A pitcher may come back once [9.12 B].
    private var moundTrips: [TeamSide: [(pitcher: PlayerID, times: Int)]] = [:]
    /// The pitcher each team had on the mound after the previous event, to spot a change.
    private var lastPitcher: [TeamSide: PlayerID?] = [:]

    init(game: Game) {
        self.game = game
        s = Situation(startOf: game.setup)
        for side in TeamSide.allCases {
            let order = game.setup[side].battingOrder
            spotAppearances[side] = Array(repeating: 0, count: order.count)
            starterLeftAt[side] = Array(repeating: nil, count: order.count)
            spotStarters[side] = order.map { Optional($0) }
            let starter = game.setup[side].startingPitcher
            moundTrips[side] = starter.map { [($0, 1)] } ?? []
            lastPitcher[side] = starter
        }
    }

    /// Runs every event and hands back the situation and the play log.
    mutating func run() -> GameReplay {
        for event in game.events { apply(event) }
        let log = PlayLog(
            gameID: game.id, setup: setup, entries: entries,
            awayOrder: s.away.battingOrder, homeOrder: s.home.battingOrder, isFinal: s.isFinal
        )
        return GameReplay(situation: s, log: log)
    }

    // MARK: - One event

    /// What one event did, gathered while it is applied, for its play log entry.
    private struct Effects {
        var pitches = 0
        var strikes = 0
        var runs: [RunScored] = []
        var adjustedRuns: Score?
        var outs: [OutMade] = []
        var errors: [ChargedError] = []
        var plateAppearance: PlateAppearanceResult?
        var problems: [String] = []
    }

    /// Applies one event to the situation and writes its play log entry.
    private mutating func apply(_ event: GameEvent) {
        let now = event.enteredAt
        var fx = Effects()
        if s.isFinal { fx.problems.append("Recorded after the game was ended.") }
        // The dropped-third-strike button is offered only until the next event.
        s.droppedThirdStrikePossible = false

        // The time limit as of this moment, so a walk-off right after the limit passes counts.
        refreshClock(at: now)

        let before = s
        let beforeLog = BasesAndOuts(outs: s.outs, count: s.count, runners: s.runners)
        let isPlay = Self.isPlay(event.kind)
        if isPlay { startOfPlay(event) }

        switch event.kind {
        case .pitch(let pitch): applyPitch(pitch, &fx)
        case .intentionalWalk: applyWalk(outcome: .intentionalWalk, &fx)
        case .ballInPlay(let play): applyBallInPlay(play, &fx)
        case .runnerAction(let action): applyRunnerAction(action, &fx)
        case .errorWithNoAdvance(let error): fx.errors.append(charge(error))
        case .substitution(let sub): applySubstitution(sub, &fx)
        case .defenseConfirmed(let check): if setup[check.team].isOurs { s.defenseCheckDue = false }
        case .runnerForNonRunner(let r): applyRunnerForNonRunner(r, &fx)
        case .pitchingChange(let change): applyPitchingChange(change, &fx)
        case .addHitter(let add): applyAddHitter(add, &fx)
        case .battingHole(let hole): applyBattingHole(hole, &fx)
        case .automaticOut(let auto): applyAutomaticOut(auto, &fx)
        case .timeLimitChange(let change): umpireLimit = .some(change.endsAt)
        case .keepPlaying(let answer): applyKeepPlaying(answer)
        case .manualAdjustment(let adjustment): applyManualAdjustment(adjustment, &fx)
        case .endOfGame: applyEndOfGame()
        }

        // The entry describes the half-inning the event happened in, so it is written before
        // the sides switch on a third out. A manual adjustment that moved the inning is
        // described in the inning it moved to.
        let fielding = s[s.fieldingSide]
        let endsHalf = s.outs >= 3 && !s.isFinal
        if s.outs > 3 { fx.problems.append("More than three outs in the half-inning.") }
        let afterLog = BasesAndOuts(outs: min(s.outs, 3), count: s.count, runners: s.runners)
        let entryInning = s.inning
        let entryHalf = s.half
        let battingSide = before.battingSide

        // The first pitch may have just started the clock.
        refreshClock(at: now)
        // A run that puts the home team ahead in the bottom of the last inning: ask whether the
        // game is over, straight away. A manual adjustment never raises the question.
        if case .manualAdjustment = event.kind {} else {
            checkWalkOff(before: before)
        }
        if endsHalf {
            endHalfInning(at: now)
            refreshClock(at: now)
        }
        refreshLineups()
        s.isRegulationComplete = Self.isOfficial(s)

        if s.isFinal { s.gameOverQuestion = nil }

        let notation = Notation.event(event, before: before, name: name(of:))
        var entry = PlayLogEntry(
            event: event,
            inning: entryInning,
            half: entryHalf,
            batter: { if case .endOfGame = event.kind { return nil }; return before.batter }(),
            batterIndex: { if case .endOfGame = event.kind { return nil }; return before[battingSide].nextBatterIndex }(),
            pitcher: fielding.pitcher,
            fielders: fielding.fielders,
            before: beforeLog,
            after: afterLog,
            pitches: fx.pitches,
            strikes: fx.strikes,
            runs: fx.runs,
            adjustedRuns: fx.adjustedRuns,
            outs: fx.outs,
            errors: fx.errors,
            plateAppearance: fx.plateAppearance,
            endsHalfInning: endsHalf,
            notation: notation
        )
        if !fx.problems.isEmpty {
            entry.needsReview = true
            entry.reviewNote = fx.problems.joined(separator: " ")
        }
        entries.append(entry)

        tally(entry)
        if entry.plateAppearance != nil { s.lastPlayNotation = notation }
        updateRunnerChoice(after: entry)
    }

    /// True for the events that are part of the action on the field, as opposed to lineup
    /// changes and bookkeeping. Each one closes any open "who runs?" or "is the game over?"
    /// question that was not answered, since play went on.
    private static func isPlay(_ kind: EventKind) -> Bool {
        switch kind {
        case .pitch, .intentionalWalk, .ballInPlay, .runnerAction, .errorWithNoAdvance, .automaticOut: true
        default: false
        }
    }

    /// What happens at the start of any piece of play: the changeover is over, the defense
    /// check (if it never happened) is no longer due, and an unanswered "is the game over?"
    /// lapses because the teams played on. A pitch also starts the clock.
    private mutating func startOfPlay(_ event: GameEvent) {
        batterStarted[s.battingSide] = true
        s.isBetweenHalfInnings = false
        s.defenseCheckDue = false
        s.droppedThirdStrikePossible = false
        s.gameOverQuestion = nil
        switch event.kind {
        case .pitch, .ballInPlay:
            // The first pitch of the game starts the time limit [9.1 G]; the first pitch of an
            // inning says when that inning began.
            if s.gameStartedAt == nil { s.gameStartedAt = event.enteredAt }
            if s.currentInningStartedAt == nil { s.currentInningStartedAt = event.enteredAt }
            // A pitch or a ball in play closes the "who runs?" question: the designated
            // non-runner ran themselves [9.11 A 3, D].
            s.runnerChoice = nil
        case .intentionalWalk:
            s.runnerChoice = nil
        default:
            break
        }
    }

    // MARK: - Pitches and plate appearances

    /// One pitch: the count goes up, and ball four, strike three or a hit batter ends the
    /// plate appearance.
    private mutating func applyPitch(_ pitch: Pitch, _ fx: inout Effects) {
        fx.pitches = 1
        fx.strikes = (pitch.result == .ball || pitch.result == .hitByPitch) ? 0 : 1
        var droppedUsed = false
        switch pitch.result {
        case .ball:
            s.count.balls += 1
            if s.count.balls >= 4 { applyWalk(outcome: .walk, &fx) }
        case .calledStrike, .swingingStrike:
            s.count.strikes += 1
            if s.count.strikes >= 3 {
                droppedUsed = pitch.droppedThirdStrike != nil
                applyStrikeout(dropped: pitch.droppedThirdStrike, canBeDropped: true, &fx)
            }
        case .foul:
            // A foul with two strikes leaves the count alone.
            if s.count.strikes < 2 { s.count.strikes += 1 }
        case .foulTip, .foulBunt:
            // Always a strike, and strike three with two strikes. A foul tip is caught by
            // definition and a foul bunt is dead, so neither can be a dropped third strike.
            s.count.strikes += 1
            if s.count.strikes >= 3 { applyStrikeout(dropped: nil, canBeDropped: false, &fx) }
        case .hitByPitch:
            applyAward(outcome: .hitByPitch, chargedTo: s.pitcher, &fx)
        }
        if pitch.droppedThirdStrike != nil, !droppedUsed {
            fx.problems.append("A dropped third strike is recorded on a pitch that is not strike three.")
        }
    }

    /// Strike three. The catcher gets the putout, unless the catcher did not hold the ball, in
    /// which case the dropped-third-strike play says what happened to the batter and runners.
    private mutating func applyStrikeout(dropped: Play?, canBeDropped: Bool, _ fx: inout Effects) {
        guard let batter = s.batter else {
            fx.problems.append("Nobody is due up.")
            return
        }
        let pitcher = s.pitcher
        if let dropped {
            var moves = dropped.runners
            if !moves.contains(where: \.isBatter) {
                let reached = dropped.batterResult != .out
                moves.append(RunnerMove(runner: batter, from: .home, to: reached ? .first : .out,
                                        outBy: reached ? [] : dropped.fielders))
            }
            let end = applyMoves(moves, batter: batter, batterPitcher: pitcher, batterFielders: dropped.fielders,
                                 inheritsFromRetired: false, &fx)
            for error in dropped.errors { fx.errors.append(charge(error)) }
            endPlateAppearance(batter, outcome: .strikeout, rbi: dropped.rbi,
                               reached: end.map { $0 != .out } ?? false, chargedTo: pitcher, &fx)
        } else {
            let catcher = s[s.fieldingSide].fielder(at: .catcher)
            fx.outs.append(OutMade(runner: batter, putout: catcher))
            s.outs += 1
            endPlateAppearance(batter, outcome: .strikeout, rbi: 0, reached: false, chargedTo: pitcher, &fx)
            // The batting screen offers the dropped-third-strike button until the next event.
            s.droppedThirdStrikePossible = canBeDropped
        }
    }

    /// Ball four or an intentional walk. Under rule 9.16(h) the walk may belong to an
    /// earlier pitcher.
    private mutating func applyWalk(outcome: PlateAppearanceOutcome, _ fx: inout Effects) {
        applyAward(outcome: outcome, chargedTo: walkChargedTo ?? s.pitcher, &fx)
    }

    /// The batter is awarded first base (walk, hit by pitch, catcher's interference): the
    /// batter goes to first and forced runners move up one base. Nobody else moves.
    private mutating func applyAward(outcome: PlateAppearanceOutcome, chargedTo pitcher: PlayerID?, _ fx: inout Effects) {
        guard let batter = s.batter else {
            fx.problems.append("Nobody is due up.")
            return
        }
        let runs = forceBatterToFirst(batter, responsible: pitcher, &fx)
        endPlateAppearance(batter, outcome: outcome, rbi: runs, reached: true, chargedTo: pitcher, &fx)
    }

    /// Puts the batter on first and pushes forced runners up one. Returns the runs forced in.
    private mutating func forceBatterToFirst(_ batter: PlayerID, responsible: PlayerID?, _ fx: inout Effects) -> Int {
        let forced = BaseMath.forcedBases(s.runners)
        var runs = 0
        var moved: [BaseRunner] = []
        for var runner in s.runners {
            if forced.contains(runner.base) {
                if runner.base == .third {
                    fx.runs.append(RunScored(runner: runner.runner, creditedTo: runner.runCreditedTo,
                                             responsiblePitcher: runner.responsiblePitcher))
                    runs += 1
                    continue
                }
                runner.base = BaseMath.nextBase(after: runner.base)
            }
            moved.append(runner)
        }
        moved.append(BaseRunner(runner: batter, base: .first, responsiblePitcher: responsible))
        s.runners = BaseMath.leadFirst(moved)
        s.score[s.battingSide] += runs
        return runs
    }

    /// A ball put in play: the play says where everyone ended up.
    private mutating func applyBallInPlay(_ play: Play, _ fx: inout Effects) {
        fx.pitches = 1
        fx.strikes = 1
        guard let batter = s.batter else {
            fx.problems.append("Nobody is due up.")
            return
        }
        let pitcher = s.pitcher
        let outcome = Self.outcome(of: play.batterResult)

        // Catcher's interference entered with no runner moves: award first like a walk.
        if play.batterResult == .catchersInterference, play.runners.isEmpty {
            _ = forceBatterToFirst(batter, responsible: pitcher, &fx)
            for error in play.errors { fx.errors.append(charge(error)) }
            endPlateAppearance(batter, outcome: outcome, rbi: play.rbi, reached: true, chargedTo: pitcher, &fx)
            return
        }

        var moves = play.runners
        if !moves.contains(where: \.isBatter) {
            moves.append(RunnerMove(runner: batter, from: .home, to: Self.defaultBatterEnd(play.batterResult),
                                    outBy: Self.defaultBatterEnd(play.batterResult) == .out ? play.fielders : []))
        }
        let end = applyMoves(moves, batter: batter, batterPitcher: pitcher, batterFielders: play.fielders,
                             inheritsFromRetired: play.batterResult == .fieldersChoice, &fx)
        for error in play.errors { fx.errors.append(charge(error)) }
        endPlateAppearance(batter, outcome: outcome, rbi: play.rbi,
                           reached: end.map { $0 != .out } ?? false, chargedTo: pitcher, &fx)
    }

    /// Runners moving between pitches: steals, pickoffs, wild pitches. The batter's count stays.
    private mutating func applyRunnerAction(_ action: RunnerAction, _ fx: inout Effects) {
        var moves = action.moves
        if moves.contains(where: \.isBatter) {
            fx.problems.append("A runner move between pitches starts at home plate.")
            moves.removeAll(where: \.isBatter)
        }
        // A designated non-runner who steals or is picked off has run themselves.
        if let choice = s.runnerChoice, moves.contains(where: { $0.runner == choice.nonRunner }) {
            s.runnerChoice = nil
        }
        _ = applyMoves(moves, batter: nil, batterPitcher: nil, batterFielders: [], inheritsFromRetired: false, &fx)
        for error in action.errors { fx.errors.append(charge(error)) }
    }

    /// Ends the batter's plate appearance: writes how it ended, moves the order to the next
    /// spot (wrapping after the last), and resets the count.
    private mutating func endPlateAppearance(
        _ batter: PlayerID, outcome: PlateAppearanceOutcome, rbi: Int, reached: Bool,
        chargedTo pitcher: PlayerID?, _ fx: inout Effects
    ) {
        fx.plateAppearance = PlateAppearanceResult(batter: batter, pitcher: pitcher, outcome: outcome,
                                                   rbi: rbi, batterReachedBase: reached)
        let side = s.battingSide
        let spot = s[side].nextBatterIndex
        if spotAppearances[side]?.indices.contains(spot) == true { spotAppearances[side]![spot] += 1 }
        advanceBatter(side)
    }

    /// Moves a team's order on to the next spot after the one up now, with a fresh count.
    private mutating func advanceBatter(_ side: TeamSide) {
        let spot = s[side].nextBatterIndex
        let count = s[side].battingOrder.count
        lastSpotUp[side] = spot
        batterStarted[side] = false
        s[side].nextBatterIndex = count == 0 ? 0 : (spot + 1) % count
        s.count = .fresh
        walkChargedTo = nil
    }

    // MARK: - Runner moves

    /// Applies a list of runner moves, batter included, all at once: outs, runs and new bases.
    /// Runners left out of the list stay where they are. Returns where the batter ended up.
    ///
    /// - `batterPitcher`: the pitcher charged if the batter reaches.
    /// - `batterFielders`: used for the batter's putout when the move does not name fielders.
    /// - `inheritsFromRetired`: on a fielder's choice that retires a runner, the batter takes
    ///   over that runner's responsible pitcher (Official Baseball Rules 9.16(g)).
    @discardableResult
    private mutating func applyMoves(
        _ moves: [RunnerMove], batter: PlayerID?, batterPitcher: PlayerID?, batterFielders: [Position],
        inheritsFromRetired: Bool, _ fx: inout Effects
    ) -> RunnerEnd? {
        let side = s.battingSide
        var staying = s.runners
        var arriving: [BaseRunner] = []
        var handled: Set<PlayerID> = []
        var batterEnd: RunnerEnd?
        var batterRunner: BaseRunner?
        var retiredPitcher: PlayerID??

        for move in moves {
            if move.isBatter {
                guard let batter else { continue }
                if move.runner != batter {
                    fx.problems.append("The play names \(name(of: move.runner)) as the batter, but \(name(of: batter)) is up.")
                }
                guard batterEnd == nil else {
                    fx.problems.append("The batter is listed twice.")
                    continue
                }
                batterEnd = move.to
                switch move.to {
                case .out:
                    fx.outs.append(out(batter, by: move.outBy.isEmpty ? batterFielders : move.outBy, at: move.outAt))
                    s.outs += 1
                case .scored:
                    fx.runs.append(RunScored(runner: batter, creditedTo: batter, responsiblePitcher: batterPitcher))
                    s.score[side] += 1
                case .first, .second, .third:
                    batterRunner = BaseRunner(runner: batter, base: move.to.base!, responsiblePitcher: batterPitcher)
                }
                continue
            }

            guard !handled.contains(move.runner) else {
                fx.problems.append("\(name(of: move.runner)) is listed twice.")
                continue
            }
            guard let index = staying.firstIndex(where: { $0.runner == move.runner }) else {
                fx.problems.append("\(name(of: move.runner)) is not on base.")
                continue
            }
            var runner = staying.remove(at: index)
            handled.insert(move.runner)
            if runner.base != move.from {
                fx.problems.append("\(name(of: move.runner)) was on \(runner.base.rawValue), not \(move.from.rawValue).")
            }
            switch move.to {
            case .out:
                fx.outs.append(out(runner.runner, by: move.outBy, at: move.outAt))
                s.outs += 1
                if retiredPitcher == nil { retiredPitcher = .some(runner.responsiblePitcher) }
            case .scored:
                fx.runs.append(RunScored(runner: runner.runner, creditedTo: runner.runCreditedTo,
                                         responsiblePitcher: runner.responsiblePitcher))
                s.score[side] += 1
            case .first, .second, .third:
                runner.base = move.to.base!
                arriving.append(runner)
            }
        }

        if var batterRunner {
            // Rule 9.16(g): the batter who reaches on a fielder's choice that retires a runner
            // is charged to that runner's pitcher.
            if inheritsFromRetired, let inherited = retiredPitcher { batterRunner.responsiblePitcher = inherited }
            arriving.append(batterRunner)
        }

        let all = staying + arriving
        let bases = all.map(\.base)
        if Set(bases).count != bases.count {
            fx.problems.append("Two runners end up on the same base.")
        }
        s.runners = BaseMath.leadFirst(all)
        return batterEnd
    }

    /// An out with the putout and assists tied to the players at those positions. The last
    /// fielder made the putout; every other fielder who handled the ball gets one assist.
    private func out(_ runner: PlayerID, by fielders: [Position], at base: Base?) -> OutMade {
        let defense = s[s.fieldingSide]
        let putout = fielders.last.flatMap { defense.fielder(at: $0) }
        var assists: [PlayerID] = []
        var seen: Set<Position> = []
        for position in fielders.dropLast() where !seen.contains(position) {
            seen.insert(position)
            if let player = defense.fielder(at: position) { assists.append(player) }
        }
        return OutMade(runner: runner, putout: putout, assists: assists, at: base)
    }

    /// An error tied to whoever is playing that position right now.
    private func charge(_ error: ErrorCharge) -> ChargedError {
        ChargedError(fielder: error.fielder, player: s[s.fieldingSide].fielder(at: error.fielder))
    }

    // MARK: - Lineup changes

    /// Pinch hitters, pinch runners, replacements and fielding changes.
    private mutating func applySubstitution(_ sub: Substitution, _ fx: inout Effects) {
        let side = sub.team
        for change in sub.batting {
            guard let spot = s[side].battingOrder.index(of: change.replacing) else {
                fx.problems.append("\(name(of: change.replacing)) is not in the batting order.")
                continue
            }
            putInSpot(change.incoming, spot: spot, side: side)
            if change.kind == .pinchRunner { pinchRun(change, &fx) }
        }
        if !sub.defense.isEmpty || !sub.leavesField.isEmpty {
            var fielders = s[side].fielders
            for assignment in sub.defense {
                // The player leaves any other position, and whoever played this one leaves it.
                fielders.removeAll { $0.player == assignment.player || $0.position == assignment.position }
                fielders.append(assignment)
            }
            fielders.removeAll { sub.leavesField.contains($0.player) }
            s[side].fielders = fielders.sorted { $0.position < $1.position }
            // Changes found during the defense check are recorded this way.
            if setup[side].isOurs, side == s.fieldingSide { s.defenseCheckDue = false }
        }
    }

    /// Puts a player into a batting spot, keeping the re-entry bookkeeping: when the spot's
    /// starter leaves, note how many times the spot had batted; when they come back, clear it.
    private mutating func putInSpot(_ player: PlayerID, spot: Int, side: TeamSide) {
        let leaving = s[side].battingOrder.slots[spot].current
        s[side].battingOrder.slots[spot].players.append(player)
        // A batting hole is filled again by anyone who takes the spot.
        s[side].battingOrder.slots[spot].isHole = false
        let starter = spotStarters[side]?[safe: spot] ?? nil
        if let starter {
            if player == starter {
                starterLeftAt[side]?[spot] = nil
            } else if leaving == starter {
                starterLeftAt[side]?[spot] = spotAppearances[side]?[safe: spot] ?? 0
            }
        }
    }

    /// A pinch runner takes over the base of the player they replace. A pinch runner for the
    /// runner who is running for a designated non-runner keeps running for that non-runner
    /// [9.11 N]; a pinch runner for the designated non-runner themself takes them out of the
    /// order and is an ordinary runner [9.11 M].
    private mutating func pinchRun(_ change: BattingChange, _ fx: inout Effects) {
        if let i = s.runners.firstIndex(where: { $0.runner == change.replacing }) {
            s.runners[i].runner = change.incoming
        } else if let i = s.runners.firstIndex(where: { $0.standingInFor == change.replacing }) {
            s.runners[i].runner = change.incoming
            s.runners[i].standingInFor = nil
        } else {
            fx.problems.append("\(name(of: change.replacing)) is not on base for a pinch runner to replace.")
        }
        if s.runnerChoice?.nonRunner == change.replacing { s.runnerChoice = nil }
    }

    /// Someone runs for a designated non-runner, who stays in the batting order and is credited
    /// with the run if it scores. The runner keeps the same responsible pitcher.
    private mutating func applyRunnerForNonRunner(_ r: RunnerForNonRunner, _ fx: inout Effects) {
        if let i = s.runners.firstIndex(where: { $0.runner == r.replacing }) {
            s.runners[i].runner = r.runner
            s.runners[i].standingInFor = r.replacing
        } else {
            fx.problems.append("\(name(of: r.replacing)) is not on base.")
        }
        if s.runners.filter({ $0.runner == r.runner }).count > 1 {
            fx.problems.append("\(name(of: r.runner)) is already on base.")
        }
        s.runnerChoice = nil
    }

    /// A new pitcher takes the mound. The old one leaves the field, or moves to another
    /// position, and keeps their batting spot unless the new pitcher takes it.
    private mutating func applyPitchingChange(_ change: PitchingChange, _ fx: inout Effects) {
        let side = change.team
        let old = s[side].pitcher
        var fielders = s[side].fielders
        fielders.removeAll { $0.player == change.newPitcher || $0.position == .pitcher }
        fielders.append(FielderAssignment(position: .pitcher, player: change.newPitcher))
        if let old, let moveTo = change.previousPitcherMovesTo, moveTo != .pitcher {
            fielders.removeAll { $0.player == old || $0.position == moveTo }
            fielders.append(FielderAssignment(position: moveTo, player: old))
        }
        s[side].fielders = fielders.sorted { $0.position < $1.position }

        if let replaced = change.takesBattingSpotOf {
            if let spot = s[side].battingOrder.index(of: replaced) {
                putInSpot(change.newPitcher, spot: spot, side: side)
            } else {
                fx.problems.append("\(name(of: replaced)) is not in the batting order.")
            }
        }

        // Rule 9.16(h): with the count at 2-0, 2-1, 3-0, 3-1 or 3-2, a walk to this batter is
        // the earlier pitcher's.
        let count = s.count
        if side == s.fieldingSide, walkChargedTo == nil, count.balls >= 2, count.balls > count.strikes {
            walkChargedTo = old
        }
    }

    /// A hitter added to the bottom of the order [9.5 B]. If the old last hitter has just
    /// batted, the new hitter is up next instead of the leadoff hitter.
    private mutating func applyAddHitter(_ add: AddHitter, _ fx: inout Effects) {
        let side = add.team
        if s[side].battingOrder.index(of: add.player) != nil {
            fx.problems.append("\(name(of: add.player)) is already in the batting order.")
        }
        let oldCount = s[side].battingOrder.count
        s[side].battingOrder.slots.append(BattingSlot(players: [add.player]))
        spotAppearances[side]?.append(0)
        starterLeftAt[side]?.append(nil)
        spotStarters[side]?.append(nil)
        // Only if the leadoff hitter has not already come up (a third out on the bases leaves
        // them up, to lead off next time).
        if s[side].nextBatterIndex == 0, lastSpotUp[side] == oldCount - 1, batterStarted[side] != true {
            s[side].nextBatterIndex = oldCount
        }
    }

    /// Marks a batting spot as a hole: an automatic out each time it comes up [9.2 B, 9.5 C].
    private mutating func applyBattingHole(_ hole: BattingHole, _ fx: inout Effects) {
        guard s[hole.team].battingOrder.slots.indices.contains(hole.spotIndex) else {
            fx.problems.append("The batting order has no spot \(hole.spotIndex + 1).")
            return
        }
        s[hole.team].battingOrder.slots[hole.spotIndex].isHole = true
    }

    /// The automatic out at a batting hole: an out for the batting team that is nobody's plate
    /// appearance and gives no fielder a putout. The order moves on to the next spot.
    private mutating func applyAutomaticOut(_ auto: AutomaticOut, _ fx: inout Effects) {
        let team = s[auto.team]
        guard auto.team == s.battingSide, team.nextBatterIndex == auto.spotIndex,
              team.battingOrder.slots.indices.contains(auto.spotIndex),
              team.battingOrder.slots[auto.spotIndex].isHole,
              let holder = team.battingOrder.slots[auto.spotIndex].current
        else {
            fx.problems.append("The batting hole is not up, so this automatic out was not counted.")
            return
        }
        fx.outs.append(OutMade(runner: holder, putout: nil))
        s.outs += 1
        advanceBatter(auto.team)
    }

    // MARK: - Overrides and the end of the game

    /// The scorer answered "Is the game over?" with "keep playing": that reason is not asked
    /// again, and later innings are ordinary innings.
    private mutating func applyKeepPlaying(_ answer: KeepPlaying) {
        if !s.declinedEndings.contains(answer.reason) { s.declinedEndings.append(answer.reason) }
        if s.gameOverQuestion == answer.reason { s.gameOverQuestion = nil }
        if answer.reason == .timeLimit { s.isLastInning = false }
    }

    /// Sets whatever the scorer filled in. Runners already on base keep their responsible
    /// pitcher; runners newly placed are charged to the pitcher on the mound.
    private mutating func applyManualAdjustment(_ adj: ManualAdjustment, _ fx: inout Effects) {
        let movesHalf = (adj.inning.map { $0 != s.inning } ?? false) || (adj.half.map { $0 != s.half } ?? false)
        if movesHalf {
            if let inning = adj.inning, inning != s.inning { s.currentInningStartedAt = nil }
            s.inning = adj.inning ?? s.inning
            s.half = adj.half ?? s.half
            // A new half-inning starts empty unless the adjustment says otherwise.
            s.outs = 0
            s.count = .fresh
            s.runners = []
            s.isBetweenHalfInnings = false
            s.runnerChoice = nil
            walkChargedTo = nil
        }
        if let outs = adj.outs { s.outs = max(0, outs) }
        if let count = adj.count { s.count = count }
        if let score = adj.score {
            let added = Score(away: score.away - s.score.away, home: score.home - s.score.home)
            if added != Score() { fx.adjustedRuns = added }
            s.score = score
        }
        if let placed = adj.runners {
            let pitcher = s.pitcher
            var runners: [BaseRunner] = []
            for base in Base.occupiable {
                guard let id = placed[base] else { continue }
                var runner = s.runners.first { $0.runner == id } ?? BaseRunner(runner: id, base: base, responsiblePitcher: pitcher)
                runner.base = base
                runners.append(runner)
            }
            s.runners = BaseMath.leadFirst(runners)
        }
        if let index = adj.batterIndex {
            let side = s.battingSide
            if s[side].battingOrder.slots.indices.contains(index) {
                s[side].nextBatterIndex = index
                lastSpotUp[side] = nil
                batterStarted[side] = false
                walkChargedTo = nil
            } else {
                fx.problems.append("The batting order has no spot \(index + 1).")
            }
        }
    }

    /// The scorer ended the game. No more questions are asked.
    private mutating func applyEndOfGame() {
        s.isFinal = true
        s.gameOverQuestion = nil
        s.runnerChoice = nil
        s.defenseCheckDue = false
        s.isLastInning = false
        s.droppedThirdStrikePossible = false
        s.isBetweenHalfInnings = false
    }

    // MARK: - Between events

    /// Third out: clear the bases, reset the count, switch sides. The batter who was up when a
    /// runner made the third out leads off next time with a fresh count, because their spot
    /// was never moved on. Then ask "Is the game over?" if a rule says it could be.
    private mutating func endHalfInning(at now: Date) {
        let endedInning = s.inning
        let endedHalf = s.half
        s.outs = 0
        s.count = .fresh
        s.runners = []
        s.runnerChoice = nil
        walkChargedTo = nil
        if s.half == .top {
            s.half = .bottom
        } else {
            s.half = .top
            s.inning += 1
            s.currentInningStartedAt = nil
        }
        s.isBetweenHalfInnings = true
        s.defenseCheckDue = setup[s.fieldingSide].isOurs
        if let question = GameEndRules.questionAtEndOfHalf(
            inning: endedInning, half: endedHalf, situation: s, rules: setup.rules,
            timeIsUp: timeIsUp(at: now)
        ) {
            s.gameOverQuestion = question
        }
    }

    /// In the bottom of a last inning (the scheduled last or later, or the one the time limit
    /// made the last), the moment the home team goes ahead the scorer is asked whether the game
    /// is over.
    private mutating func checkWalkOff(before: Situation) {
        guard before.isWalkOffInning, before.score.home <= before.score.away,
              s.score.home > s.score.away, !s.isFinal else { return }
        if before.inning >= setup.scheduledInnings, !s.declinedEndings.contains(.regulation) {
            s.gameOverQuestion = .regulation
        } else if before.isLastInning, !s.declinedEndings.contains(.timeLimit) {
            s.gameOverQuestion = .timeLimit
        }
    }

    /// True once the time limit has run out at this moment, the game has started, and the
    /// scorer has not chosen to keep playing past it.
    private func timeIsUp(at now: Date) -> Bool {
        guard let end = s.timeLimitEndsAt, s.gameStartedAt != nil else { return false }
        return now >= end && !s.declinedEndings.contains(.timeLimit)
    }

    /// Recomputes the end of the time limit and whether this is the last inning: the limit has
    /// passed during an inning that has begun [9.1 G].
    private mutating func refreshClock(at now: Date) {
        if let set = umpireLimit, let end = set {
            s.timeLimitEndsAt = end
        } else if let minutes = setup.timeLimitMinutes {
            let start = s.gameStartedAt ?? setup.scheduledStart
            s.timeLimitEndsAt = start.addingTimeInterval(Double(minutes * 60))
        } else {
            s.timeLimitEndsAt = nil
        }
        s.isLastInning = !s.isFinal && timeIsUp(at: now) && s.currentInningStartedAt != nil
    }

    /// Official if rain or darkness stops it: five innings, or four and a half with the home
    /// team ahead [9.1 E].
    static func isOfficial(_ s: Situation) -> Bool {
        let needed = min(5, s.scheduledInnings)
        let fullInningsDone = s.inning - 1
        if fullInningsDone >= needed { return true }
        return s.half == .bottom && s.inning >= needed && s.score.home > s.score.away
    }

    /// Keeps the parts of the lineups that follow from the history up to date: who is a
    /// designated non-runner in each spot, who may re-enter, and who may pitch again.
    private mutating func refreshLineups() {
        for side in TeamSide.allCases {
            let team = setup[side]
            for i in s[side].battingOrder.slots.indices {
                let current = s[side].battingOrder.slots[i].current
                s[side].battingOrder.slots[i].isDesignatedNonRunner = current.map(team.isDesignatedNonRunner) ?? false
            }

            // Pitchers: count each trip to the mound.
            let pitcher = s[side].pitcher
            if let pitcher, pitcher != (lastPitcher[side] ?? nil) {
                if let i = moundTrips[side]?.firstIndex(where: { $0.pitcher == pitcher }) {
                    moundTrips[side]![i].times += 1
                } else {
                    moundTrips[side, default: []].append((pitcher, 1))
                }
            }
            lastPitcher[side] = pitcher
            s[side].eligibleToPitchAgain = (moundTrips[side] ?? [])
                .filter { $0.times == 1 && $0.pitcher != pitcher }
                .map(\.pitcher)

            // Re-entry: a starter not in the order now, whose spot has batted since they left [9.9].
            var options: [ReentryOption] = []
            let inOrder = Set(s[side].battingOrder.slots.compactMap(\.current))
            for (spot, starter) in (spotStarters[side] ?? []).enumerated() {
                guard let starter, !inOrder.contains(starter),
                      let leftAt = starterLeftAt[side]?[safe: spot] ?? nil,
                      (spotAppearances[side]?[safe: spot] ?? 0) > leftAt else { continue }
                options.append(ReentryOption(player: starter, spotIndex: spot))
            }
            s[side].eligibleToReenter = options
        }
    }

    /// Adds the event's pitches and batters faced to each pitcher's running tally.
    private mutating func tally(_ entry: PlayLogEntry) {
        if let pitcher = entry.pitcher, entry.pitches > 0 {
            bump(pitcher, team: entry.fieldingSide) { $0.pitches += entry.pitches; $0.strikes += entry.strikes }
        }
        if let pa = entry.plateAppearance, let pitcher = pa.pitcher {
            bump(pitcher, team: entry.fieldingSide) { $0.battersFaced += 1 }
        }
    }

    /// Changes one pitcher's tally, adding them to the list the first time they appear.
    private mutating func bump(_ pitcher: PlayerID, team: TeamSide, _ change: (inout PitcherTally) -> Void) {
        if let i = s.pitchers.firstIndex(where: { $0.pitcher == pitcher }) {
            change(&s.pitchers[i])
        } else {
            var tally = PitcherTally(pitcher: pitcher, team: team)
            change(&tally)
            s.pitchers.append(tally)
        }
    }

    /// Opens the "who runs?" question when a designated non-runner has just reached base, and
    /// closes it if they are no longer on base.
    private mutating func updateRunnerChoice(after entry: PlayLogEntry) {
        if let choice = s.runnerChoice, !s.runners.contains(where: { $0.runner == choice.nonRunner }) {
            s.runnerChoice = nil
        }
        guard !s.isFinal, let pa = entry.plateAppearance, pa.batterReachedBase,
              setup[entry.battingSide].isDesignatedNonRunner(pa.batter),
              entry.battingSide == s.battingSide,
              s.runners.contains(where: { $0.runner == pa.batter }) else { return }
        let suggested = Suggestions.suggestedRunner(for: pa.batter, entries: entries, situation: s)
        s.runnerChoice = RunnerChoice(nonRunner: pa.batter, suggestedRunner: suggested)
    }

    // MARK: - Small helpers

    /// The player's last name for notation, or their id if the roster does not have them.
    private func name(of id: PlayerID) -> String {
        setup.player(id)?.lastName ?? id.rawValue
    }

    /// How a ball in play counts as a plate appearance.
    static func outcome(of result: BatterResult) -> PlateAppearanceOutcome {
        switch result {
        case .out: .out
        case .single: .single
        case .double: .double
        case .triple: .triple
        case .homeRun: .homeRun
        case .reachedOnError: .reachedOnError
        case .fieldersChoice: .fieldersChoice
        case .sacrificeFly: .sacrificeFly
        case .sacrificeBunt: .sacrificeBunt
        case .reachedOnDroppedThirdStrike: .strikeout
        case .catchersInterference: .catchersInterference
        }
    }

    /// Where the batter ends up when the play does not say: on base for a hit or a reach,
    /// out otherwise.
    static func defaultBatterEnd(_ result: BatterResult) -> RunnerEnd {
        switch result {
        case .single, .reachedOnError, .fieldersChoice, .reachedOnDroppedThirdStrike, .catchersInterference: .first
        case .double: .second
        case .triple: .third
        case .homeRun: .scored
        case .out, .sacrificeFly, .sacrificeBunt: .out
        }
    }
}

extension Array {
    /// The element at `index`, or nothing if the index is out of range.
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
