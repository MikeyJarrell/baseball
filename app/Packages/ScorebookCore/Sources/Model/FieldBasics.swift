// Field basics: the small words every other part of the vocabulary is built from.
// Fielding positions by their scorebook numbers, the bases, top and bottom of an
// inning, home and away, the count, the score, and the kinds of batted balls.

import Foundation

/// A fielding position, by its standard scorebook number.
/// Saved in JSON as the number itself, so a 6-3 groundout's fielders are `[6, 3]`.
public enum Position: Int, Codable, Sendable, CaseIterable, Comparable, CustomStringConvertible {
    case pitcher = 1
    case catcher = 2
    case firstBase = 3
    case secondBase = 4
    case thirdBase = 5
    case shortstop = 6
    case leftField = 7
    case centerField = 8
    case rightField = 9

    /// The scorebook number: 6 for the shortstop.
    public var number: Int { rawValue }

    /// The short label used in lineups and box scores: "ss", "cf", "1b".
    public var abbreviation: String {
        switch self {
        case .pitcher: "p"
        case .catcher: "c"
        case .firstBase: "1b"
        case .secondBase: "2b"
        case .thirdBase: "3b"
        case .shortstop: "ss"
        case .leftField: "lf"
        case .centerField: "cf"
        case .rightField: "rf"
        }
    }

    /// The full name for screens: "shortstop".
    public var name: String {
        switch self {
        case .pitcher: "pitcher"
        case .catcher: "catcher"
        case .firstBase: "first base"
        case .secondBase: "second base"
        case .thirdBase: "third base"
        case .shortstop: "shortstop"
        case .leftField: "left field"
        case .centerField: "center field"
        case .rightField: "right field"
        }
    }

    /// True for the three outfielders.
    public var isOutfield: Bool { rawValue >= 7 }

    public var description: String { String(rawValue) }
    public static func < (a: Position, b: Position) -> Bool { a.rawValue < b.rawValue }
}

/// A base on the diamond. Home plate is a base too: a batter starts there,
/// and a runner who reaches it has scored.
public enum Base: String, Codable, Sendable, CaseIterable, Comparable {
    case home
    case first
    case second
    case third

    /// How far round the bases this is: home 0, first 1, second 2, third 3.
    public var order: Int {
        switch self {
        case .home: 0
        case .first: 1
        case .second: 2
        case .third: 3
        }
    }

    /// The bases a runner can stand on between plays: first, second and third.
    public static let occupiable: [Base] = [.first, .second, .third]

    public static func < (a: Base, b: Base) -> Bool { a.order < b.order }
}

/// Where a runner (or the batter) finished up after a play or a runner move.
/// Saved in JSON as one word: "first", "second", "third", "scored" or "out".
public enum RunnerEnd: String, Codable, Sendable, CaseIterable {
    case first
    case second
    case third
    /// Crossed home plate: a run.
    case scored
    /// Put out somewhere on the bases.
    case out

    /// The base the runner is standing on afterward, if they are still on base.
    public var base: Base? {
        switch self {
        case .first: .first
        case .second: .second
        case .third: .third
        case .scored, .out: nil
        }
    }

    /// The end that means "standing safely on this base". Home plate means scored.
    public static func safe(at base: Base) -> RunnerEnd {
        switch base {
        case .home: .scored
        case .first: .first
        case .second: .second
        case .third: .third
        }
    }
}

/// Top or bottom of an inning. The visiting team bats in the top, the home team in the bottom.
public enum HalfInning: String, Codable, Sendable, CaseIterable {
    case top
    case bottom

    /// Which team bats in this half.
    public var battingSide: TeamSide { self == .top ? .away : .home }

    /// Which team is in the field in this half.
    public var fieldingSide: TeamSide { battingSide.opponent }
}

/// One of the two teams in a game, by whether they are the home team.
/// Our team can be either; `GameSetup` says which one is ours.
public enum TeamSide: String, Codable, Sendable, CaseIterable {
    case away
    case home

    /// The other team.
    public var opponent: TeamSide { self == .away ? .home : .away }
}

/// Which side of the plate a hitter bats from.
public enum BattingSide: String, Codable, Sendable, CaseIterable {
    case right
    case left
    /// Bats from either side.
    case switchHitter
}

/// Which hand a player throws with.
public enum Hand: String, Codable, Sendable, CaseIterable {
    case right
    case left
}

/// Balls and strikes on the current batter.
public struct Count: Codable, Equatable, Hashable, Sendable, CustomStringConvertible {
    public var balls: Int
    public var strikes: Int

    public init(balls: Int = 0, strikes: Int = 0) {
        self.balls = balls
        self.strikes = strikes
    }

    /// No balls, no strikes: the count for a new batter.
    public static let fresh = Count()

    /// Written the usual way, balls first: "3-1".
    public var description: String { "\(balls)-\(strikes)" }
}

/// Runs for each team.
public struct Score: Codable, Equatable, Hashable, Sendable {
    public var away: Int
    public var home: Int

    public init(away: Int = 0, home: Int = 0) {
        self.away = away
        self.home = home
    }

    /// Runs for one team.
    public subscript(side: TeamSide) -> Int {
        get { side == .away ? away : home }
        set { if side == .away { away = newValue } else { home = newValue } }
    }
}

/// What kind of batted ball it was, when the scorer says.
public enum BattedBallType: String, Codable, Sendable, CaseIterable {
    case groundBall
    case flyBall
    case lineDrive
    case popUp
    case bunt
}

/// A spot on the field drawing, for a spray chart later. Both numbers run from 0 to 1:
/// `x` from the left-field foul line side (0) to the right-field side (1), and `y` from
/// home plate (0) to the deepest part of the outfield (1).
public struct FieldPoint: Codable, Equatable, Hashable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}
