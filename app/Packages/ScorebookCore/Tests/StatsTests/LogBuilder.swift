// A helper for writing short play logs by hand in stats tests, a few plays at a time.
//
// The stats engine only reads the play log, so a test can hand it a play log written
// straight out, without a rules engine. This helper does the bookkeeping that needs no
// judgment, the way the sample game's helper does: it numbers the events, copies who is
// pitching and fielding into each entry, keeps the outs and runners, and switches sides after
// the third out. The test says what happened: who reached, who scored, who made each out.
//
// It is not a rules engine. It never decides where a runner goes or whether a run counts.

import Foundation
import Model

struct LogBuilder {
    let gameID: GameID
    var setup: GameSetup
    private(set) var entries: [PlayLogEntry] = []
    private(set) var inning = 1
    private(set) var half: HalfInning = .top
    private(set) var outs = 0
    private(set) var runners: [BaseRunner] = []
    /// Each team's batting order, with everyone who has batted in each spot.
    var orders: [TeamSide: BattingOrder]
    /// Who is at each position for each team right now.
    var defense: [TeamSide: [FielderAssignment]]

    init(_ setup: GameSetup, gameID: GameID = "test-game") {
        self.gameID = gameID
        self.setup = setup
        let start = Situation(startOf: setup)
        orders = [.away: start.away.battingOrder, .home: start.home.battingOrder]
        defense = [.away: setup.away.defense, .home: setup.home.defense]
    }

    // MARK: Who is where

    /// The pitcher on the mound for the team in the field.
    var pitcher: PlayerID? { fielder(.pitcher) }

    /// The player at a position for the team in the field, if anyone is known to be there.
    func fielder(_ position: Position) -> PlayerID? {
        defense[half.fieldingSide]?.first { $0.position == position }?.player
    }

    /// Puts a player at a position for a team, as a substitution would. Records nothing.
    mutating func setFielder(_ side: TeamSide, _ position: Position, _ player: PlayerID) {
        var list = defense[side] ?? []
        list.removeAll { $0.position == position || $0.player == player }
        list.append(FielderAssignment(position: position, player: player))
        defense[side] = list
    }

    /// Puts a new player into a spot in a team's batting order. Records nothing.
    mutating func putInSlot(_ side: TeamSide, _ spot: Int, _ player: PlayerID) {
        orders[side]?.slots[spot].players.append(player)
    }

    // MARK: Shorthand for what happened

    /// A runner standing on a base after the event. A runner already on base keeps the
    /// pitcher responsible for them and whoever they are running for; a new runner (the
    /// batter) is charged to the pitcher on the mound.
    func on(_ runner: PlayerID, _ base: Base) -> BaseRunner {
        if let existing = runners.first(where: { $0.runner == runner }) {
            return BaseRunner(runner: runner, base: base, responsiblePitcher: existing.responsiblePitcher,
                              standingInFor: existing.standingInFor)
        }
        return BaseRunner(runner: runner, base: base, responsiblePitcher: pitcher)
    }

    /// An out made by the listed fielders: the last one gets the putout, the others assists.
    func out(_ runner: PlayerID, by positions: [Position] = [], at base: Base? = nil) -> OutMade {
        OutMade(runner: runner, putout: positions.last.flatMap(fielder),
                assists: positions.dropLast().compactMap(fielder), at: base)
    }

    /// An error charged to whoever is playing a position.
    func error(_ position: Position) -> ChargedError {
        ChargedError(fielder: position, player: fielder(position))
    }

    // MARK: Recording

    /// Records one event and its play log entry.
    ///
    /// - `result`: how the batter's plate appearance ended, if it did.
    /// - `chargedTo`: the pitcher charged with the batter; the one on the mound unless given.
    /// - `scored`: the runners who crossed the plate. Each is charged to the pitcher who put
    ///   them on base and credited to the designated non-runner they ran for, if any.
    /// - `after`: the runners on base afterward; unchanged when left out.
    mutating func record(
        _ kind: EventKind,
        batter: PlayerID? = nil,
        pitches: Int = 0,
        strikes: Int = 0,
        result: PlateAppearanceOutcome? = nil,
        rbi: Int = 0,
        chargedTo: PlayerID? = nil,
        scored: [PlayerID] = [],
        outsMade: [OutMade] = [],
        errors: [ChargedError] = [],
        after: [BaseRunner]? = nil,
        adjustedRuns: Score? = nil,
        notation: String = ""
    ) {
        let side = half.battingSide
        let before = BasesAndOuts(outs: outs, runners: runners)
        let runs = scored.map { runner -> RunScored in
            let standing = runners.first { $0.runner == runner }
            return RunScored(runner: runner, creditedTo: standing?.runCreditedTo ?? runner,
                             responsiblePitcher: standing?.responsiblePitcher ?? pitcher)
        }
        let newOuts = outs + outsMade.count
        let afterState = BasesAndOuts(outs: newOuts, runners: after ?? runners)
        let reached = batter.map { b in afterState.runners.contains { $0.runner == b } || scored.contains(b) } ?? false
        let plateAppearance = result.map {
            PlateAppearanceResult(batter: batter!, pitcher: chargedTo ?? pitcher, outcome: $0, rbi: rbi, batterReachedBase: reached)
        }

        let event = GameEvent(id: EventID(rawValue: "e\(entries.count + 1)"),
                              enteredAt: setup.scheduledStart.addingTimeInterval(Double(entries.count) * 20), kind: kind)
        entries.append(PlayLogEntry(
            event: event,
            inning: inning,
            half: half,
            batter: batter,
            batterIndex: batter.flatMap { orders[side]?.index(of: $0) },
            pitcher: pitcher,
            fielders: defense[half.fieldingSide] ?? [],
            before: before,
            after: afterState,
            pitches: pitches,
            strikes: strikes,
            runs: runs,
            adjustedRuns: adjustedRuns,
            outs: outsMade,
            errors: errors,
            plateAppearance: plateAppearance,
            endsHalfInning: newOuts >= 3,
            notation: notation
        ))

        if newOuts >= 3 {
            // Third out: clear the bases and switch sides.
            outs = 0
            runners = []
            if half == .top { half = .bottom } else { half = .top; inning += 1 }
        } else {
            outs = newOuts
            runners = afterState.runners
        }
    }

    /// A finished plate appearance on a ball in play, one pitch.
    mutating func play(_ batter: PlayerID, _ result: PlateAppearanceOutcome, rbi: Int = 0, scored: [PlayerID] = [],
                       outs: [OutMade] = [], errors: [ChargedError] = [], after: [BaseRunner]? = nil,
                       multiOut: MultiOutPlay? = nil, notation: String = "") {
        let batterResult: BatterResult = switch result {
        case .single: .single
        case .double: .double
        case .triple: .triple
        case .homeRun: .homeRun
        case .sacrificeFly: .sacrificeFly
        case .sacrificeBunt: .sacrificeBunt
        case .reachedOnError: .reachedOnError
        case .fieldersChoice: .fieldersChoice
        case .catchersInterference: .catchersInterference
        default: .out
        }
        record(.ballInPlay(Play(batterResult: batterResult, multiOut: multiOut, rbi: rbi)), batter: batter,
               pitches: 1, strikes: 1, result: result, rbi: rbi, scored: scored, outsMade: outs, errors: errors,
               after: after, notation: notation)
    }

    /// A plate appearance ended by a pitch: ball four, strike three, hit by pitch.
    mutating func pitch(_ batter: PlayerID, _ pitch: PitchResult, result: PlateAppearanceOutcome, rbi: Int = 0,
                        scored: [PlayerID] = [], outs: [OutMade] = [], after: [BaseRunner]? = nil, notation: String = "") {
        record(.pitch(Pitch(pitch)), batter: batter, pitches: 1,
               strikes: (pitch == .ball || pitch == .hitByPitch) ? 0 : 1,
               result: result, rbi: rbi, scored: scored, outsMade: outs, after: after, notation: notation)
    }

    /// A pitch that did not end the plate appearance.
    mutating func takePitch(_ batter: PlayerID, _ pitch: PitchResult) {
        record(.pitch(Pitch(pitch)), batter: batter, pitches: 1, strikes: pitch == .ball ? 0 : 1)
    }

    /// A batter put out on a ball in play, with the fielders who made the out.
    mutating func quickOut(_ batter: PlayerID, _ positions: [Position], notation: String = "") {
        play(batter, .out, outs: [out(batter, by: positions)], notation: notation)
    }

    /// Runners moving between pitches, such as a steal.
    mutating func runnerAction(_ moves: [RunnerMove], batter: PlayerID? = nil, scored: [PlayerID] = [],
                               outs: [OutMade] = [], errors: [ChargedError] = [], after: [BaseRunner]) {
        record(.runnerAction(RunnerAction(moves: moves)), batter: batter, scored: scored, outsMade: outs,
               errors: errors, after: after)
    }

    /// A lineup event with nothing happening on the field: substitution, pitching change and so on.
    /// `change` updates the batting orders and defense first.
    mutating func lineupChange(_ kind: EventKind, change: (inout LogBuilder) -> Void = { _ in }) {
        change(&self)
        record(kind)
    }

    /// Someone runs for a designated non-runner who is on base.
    mutating func runnerForNonRunner(_ runner: PlayerID, replacing nonRunner: PlayerID) {
        let moved = runners.map {
            $0.runner == nonRunner
                ? BaseRunner(runner: runner, base: $0.base, responsiblePitcher: $0.responsiblePitcher, standingInFor: nonRunner)
                : $0
        }
        record(.runnerForNonRunner(RunnerForNonRunner(runner: runner, replacing: nonRunner)), after: moved)
    }

    /// A manual adjustment that moves the game to an inning and half and changes the score.
    mutating func adjust(toInning newInning: Int, _ newHalf: HalfInning, outs newOuts: Int, runners newRunners: [BaseRunner],
                         addingRuns: Score) {
        inning = newInning
        half = newHalf
        outs = newOuts
        let placed = newRunners.map { BaseRunner(runner: $0.runner, base: $0.base, responsiblePitcher: pitcher) }
        runners = placed
        record(.manualAdjustment(ManualAdjustment(inning: newInning, half: newHalf, outs: newOuts)),
               after: placed, adjustedRuns: addingRuns)
    }

    /// The scorer ends the game.
    mutating func endGame(_ reason: EndOfGame.Reason = .regulation) {
        record(.endOfGame(EndOfGame(reason: reason)))
    }

    /// The play log for everything recorded so far.
    func log(isFinal: Bool = true) -> PlayLog {
        PlayLog(gameID: gameID, setup: setup, entries: entries,
                awayOrder: orders[.away]!, homeOrder: orders[.home]!, isFinal: isFinal)
    }
}

extension BoxScore {
    /// Every batting, pitching or fielding line for one player, from either team.
    func battingLines(_ player: PlayerID) -> [BattingLine] { (away.batting + home.batting).filter { $0.player == player } }
    func pitching(_ player: PlayerID) -> PitchingCounts? { (away.pitching + home.pitching).first { $0.player == player }?.stats }
    func fielding(_ player: PlayerID) -> FieldingLine? { (away.fielding + home.fielding).first { $0.player == player } }
    /// One player's batting stats, from their first batting line.
    func batting(_ player: PlayerID) -> BattingCounts? { battingLines(player).first?.stats }
}
