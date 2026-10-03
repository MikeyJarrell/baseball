// A play: one ball in play, from contact until the ball is dead.
//
// Here is how a 5-4-3 double play with a runner on first is recorded. The batter ("c2")
// grounds to the third baseman, who throws to second for the force on the runner from
// first ("c1"); the second baseman throws on to first to get the batter:
//
//     "ballInPlay": {
//       "batterResult": "out",
//       "battedBall": "groundBall",
//       "fielders": [5, 4, 3],
//       "multiOut": "doublePlay",
//       "runners": [
//         { "runner": "c1", "from": "first", "to": "out", "outAt": "second", "outBy": [5, 4] },
//         { "runner": "c2", "from": "home",  "to": "out", "outAt": "first",  "outBy": [4, 3] }
//       ],
//       "rbi": 0
//     }
//
// `fielders` is the whole play in the order the ball was handled, which gives the
// scorebook notation "5-4-3 DP". Each runner's `outBy` says who made that out: the last
// fielder gets the putout, the ones before get assists. So the third baseman has an
// assist, the second baseman a putout and an assist, the first baseman a putout.

import Foundation

/// One ball in play: what happened to the batter, who handled the ball, and where every
/// runner ended up.
public struct Play: Codable, Equatable, Hashable, Sendable {
    /// What happened to the batter.
    public var batterResult: BatterResult
    /// Ground ball, fly ball, line drive, pop-up or bunt, if the scorer says.
    public var battedBall: BattedBallType?
    /// The fielders in the order they handled the ball: `[6, 3]` for a 6-3 groundout,
    /// `[8]` for a fly to center, `[6]` for an error by the shortstop.
    public var fielders: [Position]
    /// For a hit: the fielding area the ball went to, if the scorer tapped one
    /// (left field for "1B 7", a single to left).
    public var hitLocation: Position?
    /// Exactly where the ball went on the field drawing, for a spray chart later.
    public var hitSpot: FieldPoint?
    /// Where every runner ended up, batter included (the batter starts at `.home`).
    /// A runner left out of the list is taken to have stayed on their base.
    public var runners: [RunnerMove]
    /// Errors on the play, each listed once even if it let several runners move.
    public var errors: [ErrorCharge]
    /// Whether the scorer marked this a double or triple play.
    public var multiOut: MultiOutPlay?
    /// Runs batted in, as confirmed by the scorer. Stats use this number as it is.
    public var rbi: Int

    public init(
        batterResult: BatterResult,
        battedBall: BattedBallType? = nil,
        fielders: [Position] = [],
        hitLocation: Position? = nil,
        hitSpot: FieldPoint? = nil,
        runners: [RunnerMove] = [],
        errors: [ErrorCharge] = [],
        multiOut: MultiOutPlay? = nil,
        rbi: Int = 0
    ) {
        self.batterResult = batterResult
        self.battedBall = battedBall
        self.fielders = fielders
        self.hitLocation = hitLocation
        self.hitSpot = hitSpot
        self.runners = runners
        self.errors = errors
        self.multiOut = multiOut
        self.rbi = rbi
    }

    /// The batter's own move, if listed.
    public var batterMove: RunnerMove? {
        runners.first { $0.isBatter }
    }

    // Reading from JSON: `fielders`, `runners` and `errors` may be left out (empty),
    // and so may `rbi` (zero).
    private enum CodingKeys: String, CodingKey {
        case batterResult, battedBall, fielders, hitLocation, hitSpot, runners, errors, multiOut, rbi
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        batterResult = try c.decode(BatterResult.self, forKey: .batterResult)
        battedBall = try c.decodeIfPresent(BattedBallType.self, forKey: .battedBall)
        fielders = try c.decodeIfPresent([Position].self, forKey: .fielders) ?? []
        hitLocation = try c.decodeIfPresent(Position.self, forKey: .hitLocation)
        hitSpot = try c.decodeIfPresent(FieldPoint.self, forKey: .hitSpot)
        runners = try c.decodeIfPresent([RunnerMove].self, forKey: .runners) ?? []
        errors = try c.decodeIfPresent([ErrorCharge].self, forKey: .errors) ?? []
        multiOut = try c.decodeIfPresent(MultiOutPlay.self, forKey: .multiOut)
        rbi = try c.decodeIfPresent(Int.self, forKey: .rbi) ?? 0
    }
}

/// What happened to the batter on a ball in play.
public enum BatterResult: String, Codable, Sendable, CaseIterable {
    /// Put out: a groundout, fly out, line out or pop-up. On a dropped third strike,
    /// the batter thrown out (K 2-3).
    case out
    case single
    case double
    case triple
    case homeRun
    /// Safe because of an error.
    case reachedOnError
    /// Safe because the fielders chose to put out (or try for) another runner.
    case fieldersChoice
    /// A fly out that lets a runner score.
    case sacrificeFly
    /// A bunt that moves a runner up at the cost of the batter.
    case sacrificeBunt
    /// Struck out, but safe at first because the catcher did not hold strike three.
    case reachedOnDroppedThirdStrike
    /// Awarded first because the catcher interfered with the swing.
    case catchersInterference

    /// The word for screens: "single", "fielder's choice".
    public var label: String {
        switch self {
        case .out: "out"
        case .single: "single"
        case .double: "double"
        case .triple: "triple"
        case .homeRun: "home run"
        case .reachedOnError: "error"
        case .fieldersChoice: "fielder's choice"
        case .sacrificeFly: "sacrifice fly"
        case .sacrificeBunt: "sacrifice bunt"
        case .reachedOnDroppedThirdStrike: "dropped third strike"
        case .catchersInterference: "catcher's interference"
        }
    }
}

/// A play that made more than one out.
public enum MultiOutPlay: String, Codable, Sendable, CaseIterable {
    case doublePlay
    case triplePlay
}
