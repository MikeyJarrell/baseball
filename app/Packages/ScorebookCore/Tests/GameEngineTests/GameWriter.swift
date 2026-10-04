// A small helper for writing test games by hand: it numbers the events ("e1", "e2", …),
// stamps them 20 seconds apart, and has short ways to write the common plays. It never
// works out where a runner goes; every runner move in a test game is written by hand.

import Foundation
import Model
import TestSupport

/// Builds a game's event list one event at a time.
struct GameWriter {
    var setup: GameSetup
    private(set) var events: [GameEvent] = []
    /// When the next event is entered.
    var clock: Date
    /// Seconds between events.
    var gap: TimeInterval = 20

    init(setup: GameSetup, firstEventAt: Date? = nil) {
        self.setup = setup
        clock = firstEventAt ?? setup.scheduledStart.addingTimeInterval(300)
    }

    /// The standard scenario setup: Mudcats (m1 to m12) at Diamond Dogs (d1 to d12).
    static func standard() throws -> GameWriter {
        GameWriter(setup: try Scenarios.setup(named: "standard"))
    }

    /// The game so far.
    var game: Game { Game(id: "test-game", setup: setup, events: events) }

    /// Adds one event and returns its id.
    @discardableResult
    mutating func add(_ kind: EventKind) -> EventID {
        let id = EventID(rawValue: "e\(events.count + 1)")
        events.append(GameEvent(id: id, enteredAt: clock, kind: kind))
        clock = clock.addingTimeInterval(gap)
        return id
    }

    /// Pitches by letter: B ball, C called strike, S swinging strike, F foul, T foul tip,
    /// L foul bunt, H hit by pitch.
    mutating func pitches(_ codes: String) {
        for code in codes {
            let result: PitchResult
            switch code {
            case "B": result = .ball
            case "C": result = .calledStrike
            case "S": result = .swingingStrike
            case "F": result = .foul
            case "T": result = .foulTip
            case "L": result = .foulBunt
            case "H": result = .hitByPitch
            default: preconditionFailure("Unknown pitch letter \(code)")
            }
            add(.pitch(Pitch(result)))
        }
    }

    /// Some pitches, then the ball in play.
    @discardableResult
    mutating func pa(_ codes: String, _ play: Play) -> EventID {
        pitches(codes)
        return add(.ballInPlay(play))
    }

    /// Some pitches, then a final pitch (strike three or ball four) written the same way.
    mutating func pa(_ codes: String, last: String) {
        pitches(codes + last)
    }
}

// MARK: - Short ways to write plays

/// A runner's move on a play.
func mv(_ runner: PlayerID, _ from: Base, _ to: RunnerEnd, outBy: [Position] = [], at: Base? = nil,
        reason: RunnerMoveReason? = nil, onError: Bool = false) -> RunnerMove {
    RunnerMove(runner: runner, from: from, to: to, reason: reason, outBy: outBy, outAt: at, advancedOnError: onError)
}

/// Positions by scorebook number: `pos(6, 3)`.
func pos(_ numbers: Int...) -> [Position] { numbers.compactMap(Position.init(rawValue:)) }

/// A ground out: `ground("m1", 6, 3)`, the batter out at first.
func ground(_ batter: PlayerID, _ fielders: Int..., others: [RunnerMove] = []) -> Play {
    let f = fielders.compactMap(Position.init(rawValue:))
    return Play(batterResult: .out, battedBall: .groundBall, fielders: f,
                runners: others + [mv(batter, .home, .out, outBy: f, at: .first)])
}

/// A fly out to one fielder.
func fly(_ batter: PlayerID, _ fielder: Int, others: [RunnerMove] = []) -> Play {
    let f = pos(fielder)
    return Play(batterResult: .out, battedBall: .flyBall, fielders: f, runners: others + [mv(batter, .home, .out, outBy: f)])
}

/// A hit: `hit(.single, "m1", to: 7, others: [...])`. The batter ends on the hit's base.
func hit(_ result: BatterResult, _ batter: PlayerID, to location: Int, others: [RunnerMove] = [], rbi: Int = 0) -> Play {
    let end: RunnerEnd
    switch result {
    case .double: end = .second
    case .triple: end = .third
    case .homeRun: end = .scored
    default: end = .first
    }
    return Play(batterResult: result, battedBall: .lineDrive, hitLocation: Position(rawValue: location),
                runners: others + [mv(batter, .home, end)], rbi: rbi)
}
