// A small helper for writing the sample game by hand, one plate appearance at a time.
//
// Each step records an event and its play log entry together. The scorer's facts (who
// reached, who scored, who made each out, the runners afterward) are written out by hand
// in SampleGame.swift. The helper only does the bookkeeping that needs no judgment: it
// counts balls and strikes pitch by pitch, numbers the events, stamps their times, and
// copies the current outs, runners, fielders and pitcher into each entry.
//
// This is not a rules engine: it never decides where a runner goes or whether a run scores.

import Foundation
import Model

/// What a finished plate appearance or runner move left behind, written out by hand.
struct Outcome {
    /// Outs after the event, 0 to 3.
    var outs: Int
    /// Runners on base after the event (on a third out, the runners left on base).
    var runners: [BaseRunner] = []
    var runs: [RunScored] = []
    var outsMade: [OutMade] = []
    var errors: [ChargedError] = []
    /// How the plate appearance ended, when it did.
    var result: PlateAppearanceOutcome?
    var rbi = 0
    /// True when the batter ended up on base or scored.
    var reached = false
    var notation: String
}

/// The last event of a plate appearance.
enum Finish {
    /// The ball was put in play.
    case inPlay(Play)
    /// A pitch ended it: ball four, strike three, hit by pitch.
    case pitch(PitchResult)
    /// Awarded first with no pitches.
    case intentionalWalk
}

/// Builds the sample game's events and play log side by side.
struct GameScript {
    let gameID: GameID
    let setup: GameSetup
    private(set) var events: [GameEvent] = []
    private(set) var entries: [PlayLogEntry] = []

    // Where the game stands, as the hand-written outcomes leave it.
    private(set) var inning = 1
    private(set) var half: HalfInning = .top
    private(set) var outs = 0
    private(set) var count = Count()
    private(set) var runners: [BaseRunner] = []
    var away: TeamState
    var home: TeamState
    private(set) var tallies: [PitcherTally] = []
    private let firstEvent: Date

    init(gameID: GameID, setup: GameSetup, firstEventAt: Date) {
        self.gameID = gameID
        self.setup = setup
        self.firstEvent = firstEventAt
        let start = Situation(startOf: setup)
        away = start.away
        home = start.home
    }

    /// The team in the field right now.
    private var fielding: TeamState { half.fieldingSide == .away ? away : home }
    /// The pitcher on the mound right now.
    var pitcher: PlayerID? { fielding.pitcher }

    /// The spot in the batting team's order a player holds now.
    private func index(of batter: PlayerID) -> Int? {
        (half.battingSide == .away ? away : home).battingOrder.index(of: batter)
    }

    /// Pitches that did not end the plate appearance, by letter: B ball, C called strike,
    /// S swinging strike, F foul. Two-strike fouls leave the count alone.
    mutating func pitches(_ codes: String, to batter: PlayerID) {
        for code in codes {
            let result: PitchResult
            switch code {
            case "B": result = .ball
            case "C": result = .calledStrike
            case "S": result = .swingingStrike
            case "F": result = .foul
            default: preconditionFailure("Unknown pitch letter \(code)")
            }
            let before = BasesAndOuts(outs: outs, count: count, runners: runners)
            switch result {
            case .ball: count.balls += 1
            case .foul: if count.strikes < 2 { count.strikes += 1 }
            default: count.strikes += 1
            }
            record(.pitch(Pitch(result)), batter: batter, pitches: 1, strikes: result == .ball ? 0 : 1,
                   before: before, after: BasesAndOuts(outs: outs, count: count, runners: runners),
                   outcome: nil, notation: String(code))
        }
    }

    /// A whole plate appearance: the pitches before the last one, then how it ended.
    mutating func plateAppearance(_ batter: PlayerID, _ codes: String, _ finish: Finish, _ outcome: Outcome) {
        pitches(codes, to: batter)
        let kind: EventKind
        let thrown: Int
        let strike: Int
        switch finish {
        case .inPlay(let play):
            kind = .ballInPlay(play); thrown = 1; strike = 1
        case .pitch(let result):
            kind = .pitch(Pitch(result)); thrown = 1
            strike = (result == .ball || result == .hitByPitch) ? 0 : 1
        case .intentionalWalk:
            kind = .intentionalWalk(IntentionalWalk()); thrown = 0; strike = 0
        }
        finishEvent(kind, batter: batter, pitches: thrown, strikes: strike, outcome: outcome, endsPlateAppearance: true)
    }

    /// Runners moving between pitches. The count stays as it is.
    mutating func runnerAction(_ action: RunnerAction, batter: PlayerID, _ outcome: Outcome) {
        finishEvent(.runnerAction(action), batter: batter, pitches: 0, strikes: 0, outcome: outcome, endsPlateAppearance: false)
    }

    /// A substitution, pitching change or defense check: nothing happens on the field.
    /// `change` updates the batting orders and fielders by hand.
    mutating func lineupChange(_ kind: EventKind, notation: String, change: (inout GameScript) -> Void = { _ in }) {
        let before = BasesAndOuts(outs: outs, count: count, runners: runners)
        let batter = (half.battingSide == .away ? away : home).currentBatter
        change(&self)
        record(kind, batter: batter, pitches: 0, strikes: 0, before: before, after: before, outcome: nil, notation: notation)
    }

    /// Someone runs for a designated non-runner who is on base. The runner takes the base,
    /// keeps the same pitcher responsible, and runs for the designated non-runner.
    mutating func runnerForNonRunner(_ runner: PlayerID, replacing original: PlayerID, notation: String) {
        let before = BasesAndOuts(outs: outs, count: count, runners: runners)
        runners = runners.map {
            $0.runner == original ? BaseRunner(runner: runner, base: $0.base, responsiblePitcher: $0.responsiblePitcher,
                                               standingInFor: original) : $0
        }
        let batter = (half.battingSide == .away ? away : home).currentBatter
        record(.runnerForNonRunner(RunnerForNonRunner(runner: runner, replacing: original)), batter: batter,
               pitches: 0, strikes: 0, before: before, after: BasesAndOuts(outs: outs, count: count, runners: runners),
               outcome: nil, notation: notation)
    }

    /// The scorer ends the game.
    mutating func endGame(_ ending: EndOfGame) {
        let state = BasesAndOuts(outs: outs, count: count, runners: runners)
        record(.endOfGame(ending), batter: nil, pitches: 0, strikes: 0, before: state, after: state, outcome: nil, notation: "Final")
    }

    /// Records the last event of a plate appearance or a runner move, then moves the game on.
    private mutating func finishEvent(_ kind: EventKind, batter: PlayerID, pitches: Int, strikes: Int, outcome: Outcome, endsPlateAppearance: Bool) {
        let before = BasesAndOuts(outs: outs, count: count, runners: runners)
        let afterCount = endsPlateAppearance ? Count() : count
        let after = BasesAndOuts(outs: outcome.outs, count: afterCount, runners: outcome.runners)
        record(kind, batter: batter, pitches: pitches, strikes: strikes, before: before, after: after,
               outcome: outcome, notation: outcome.notation)

        outs = outcome.outs
        runners = outcome.runners
        count = afterCount
        let battingSide = half.battingSide
        if endsPlateAppearance, let i = index(of: batter) {
            // The next spot in the order is up, wrapping after the last.
            let next = (i + 1) % (battingSide == .away ? away : home).battingOrder.count
            if battingSide == .away { away.nextBatterIndex = next } else { home.nextBatterIndex = next }
        }
        if outs == 3 {
            // Third out: clear the bases, fresh count, other team bats.
            outs = 0
            runners = []
            count = Count()
            if half == .top { half = .bottom } else { half = .top; inning += 1 }
        }
    }

    /// Adds one event and its play log entry, and adds its pitches to the pitcher's tally.
    private mutating func record(
        _ kind: EventKind, batter: PlayerID?, pitches: Int, strikes: Int,
        before: BasesAndOuts, after: BasesAndOuts, outcome: Outcome?, notation: String
    ) {
        let n = events.count + 1
        let event = GameEvent(id: EventID(rawValue: "e\(n)"), enteredAt: firstEvent.addingTimeInterval(Double(n - 1) * 30), kind: kind)
        events.append(event)

        let result = outcome?.result.map {
            PlateAppearanceResult(batter: batter!, pitcher: pitcher, outcome: $0, rbi: outcome!.rbi, batterReachedBase: outcome!.reached)
        }
        entries.append(PlayLogEntry(
            event: event,
            inning: inning,
            half: half,
            batter: batter,
            batterIndex: batter.flatMap(index(of:)),
            pitcher: pitcher,
            fielders: fielding.fielders,
            before: before,
            after: after,
            pitches: pitches,
            strikes: strikes,
            runs: outcome?.runs ?? [],
            outs: outcome?.outsMade ?? [],
            errors: outcome?.errors ?? [],
            plateAppearance: result,
            endsHalfInning: after.outs == 3,
            notation: notation
        ))

        // Keep each pitcher's running tally for the final situation.
        if let pitcher, pitches > 0 || result != nil {
            if !tallies.contains(where: { $0.pitcher == pitcher }) {
                tallies.append(PitcherTally(pitcher: pitcher, team: half.fieldingSide))
            }
            let i = tallies.firstIndex { $0.pitcher == pitcher }!
            tallies[i].pitches += pitches
            tallies[i].strikes += strikes
            if let result { tallies[i].battersFaced += result.pitcher == pitcher ? 1 : 0 }
        }
    }

    /// The play log for everything recorded so far.
    func playLog(isFinal: Bool) -> PlayLog {
        PlayLog(gameID: gameID, setup: setup, entries: entries,
                awayOrder: away.battingOrder, homeOrder: home.battingOrder, isFinal: isFinal)
    }

    /// The game for everything recorded so far.
    var game: Game { Game(id: gameID, setup: setup, events: events) }

    /// Where the game stands after everything recorded so far.
    func situation(isFinal: Bool) -> Situation {
        Situation(
            inning: inning,
            half: half,
            outs: outs,
            count: count,
            score: Score(
                away: entries.filter { $0.half == .top }.reduce(0) { $0 + $1.runs.count },
                home: entries.filter { $0.half == .bottom }.reduce(0) { $0 + $1.runs.count }
            ),
            runners: runners,
            away: away,
            home: home,
            pitchers: tallies,
            lastPlayNotation: entries.last { $0.plateAppearance != nil }?.notation,
            isBetweenHalfInnings: outs == 0 && runners.isEmpty && entries.last?.endsHalfInning == true,
            isFinal: isFinal,
            gameStartedAt: events.first?.enteredAt,
            scheduledInnings: setup.scheduledInnings
        )
    }
}

// MARK: - Shorthand for writing plays by hand

/// A runner standing on a base, charged to a pitcher.
func on(_ runner: PlayerID, _ base: Base, by pitcher: PlayerID, for original: PlayerID? = nil) -> BaseRunner {
    BaseRunner(runner: runner, base: base, responsiblePitcher: pitcher, standingInFor: original)
}

/// A runner's move on a play.
func move(_ runner: PlayerID, _ from: Base, _ to: RunnerEnd, outBy: [Position] = [], at: Base? = nil,
          reason: RunnerMoveReason? = nil, onError: Bool = false) -> RunnerMove {
    RunnerMove(runner: runner, from: from, to: to, reason: reason, outBy: outBy, outAt: at, advancedOnError: onError)
}

/// A run, credited to the runner and charged to a pitcher.
func run(_ runner: PlayerID, charged pitcher: PlayerID, creditedTo: PlayerID? = nil) -> RunScored {
    RunScored(runner: runner, creditedTo: creditedTo ?? runner, responsiblePitcher: pitcher)
}

/// An out, with the putout and assists tied to players.
func out(_ runner: PlayerID, putout: PlayerID, assists: [PlayerID] = [], at: Base? = nil) -> OutMade {
    OutMade(runner: runner, putout: putout, assists: assists, at: at)
}
