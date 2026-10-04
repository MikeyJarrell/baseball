// The scenario file format: a short game situation with known right answers.
//
// Each file in Tests/Scenarios/ is one `Scenario`: a plain-English description, a setup
// (written out, or named from Tests/Scenarios/setups/), the events, and what should be
// true afterward. Every expected value is optional; a test checks only what the file says.
// Tests/Scenarios/README.md shows the format with an example.
//
// Written by the foundation job; owned by the lead builder. The test writer owns the
// scenario files themselves and asks the lead builder for any new kind of expectation.

import Foundation
import Model

/// One scenario file.
public struct Scenario: Codable, Sendable {
    /// What happens, in one line of plain English.
    public var description: String
    /// Where a real game came from, with Retrosheet's credit line, for converted games.
    public var source: String?
    /// The name of a shared setup in Tests/Scenarios/setups/, without ".json".
    /// Use this or `setup`, not both. After loading, `setup` is always filled in.
    public var setupFile: String?
    /// The setup written out in full.
    public var setup: GameSetup?
    /// The events, in order.
    public var events: [GameEvent]
    /// What should be true part way through: each checkpoint is checked after its event.
    public var checkpoints: [ScenarioCheckpoint]?
    /// What should be true after the last event.
    public var expected: ScenarioExpectation

    /// The file's name without ".json", filled in by the loader.
    public var name: String = ""

    private enum CodingKeys: String, CodingKey {
        case description, source, setupFile, setup, events, checkpoints, expected
    }

    /// The scenario as a game, ready to hand to the rules engine.
    /// The game's id is the scenario's file name.
    public var game: Game {
        guard let setup else {
            preconditionFailure("Scenario \(name) has no setup; load it with Scenarios.load.")
        }
        return Game(id: GameID(rawValue: name), setup: setup, events: events)
    }

    /// The game cut off just after one event, for checking a checkpoint.
    public func game(upThrough event: EventID) -> Game {
        var g = game
        if let i = g.events.firstIndex(where: { $0.id == event }) {
            g.events = Array(g.events[...i])
        }
        return g
    }
}

/// What should be true just after one event.
public struct ScenarioCheckpoint: Codable, Sendable {
    public var afterEvent: EventID
    public var expected: ScenarioExpectation
}

/// The right answers. Leave out anything the scenario does not test.
public struct ScenarioExpectation: Codable, Sendable {
    /// Checked against the rules engine's situation.
    public var situation: ExpectedSituation?
    /// Checked against the play log's notation for particular events.
    public var notation: [ExpectedNotation]?
    /// Checked against the box score's batting lines.
    public var batting: [ExpectedBatting]?
    /// Checked against the box score's pitching lines.
    public var pitching: [ExpectedPitching]?
    /// Checked against the box score's fielding lines.
    public var fielding: [ExpectedFielding]?
    /// Checked against each team's runs, hits, errors, runners left on base and double plays.
    public var teams: [ExpectedTeam]?
}

/// The situation's expected values. Anything left out is not checked.
public struct ExpectedSituation: Codable, Sendable {
    public var inning: Int?
    public var half: HalfInning?
    public var outs: Int?
    public var count: Count?
    public var score: Score?
    /// Every runner on base. When given, bases not listed must be empty; an empty list
    /// means the bases are empty.
    public var runners: [ExpectedRunner]?
    public var batter: PlayerID?
    public var onDeck: PlayerID?
    /// The pitcher on the mound for the fielding team.
    public var pitcher: PlayerID?
    /// Pitch counts for particular pitchers.
    public var pitchers: [ExpectedPitcherTally]?
    /// Facts about particular spots in a team's batting order.
    public var battingSlots: [ExpectedSlot]?
    /// Facts about a team's order as a whole: how many spots, who is due up.
    public var lineups: [ExpectedLineup]?
    /// Who is playing particular positions.
    public var fielders: [ExpectedFielder]?
    /// Whether the app should be asking who runs for a designated non-runner.
    public var isRunnerChoiceOpen: Bool?
    /// The designated non-runner the app is asking about.
    public var runnerChoiceFor: PlayerID?
    /// The runner the app should offer first: the teammate who made the most recent out.
    public var suggestedRunner: PlayerID?
    /// Whether the app should offer anyone first (false before the team has made an out).
    public var hasSuggestedRunner: Bool?
    public var isBetweenHalfInnings: Bool?
    /// Whether the app should open the defense check: our team has just taken the field and
    /// the scorer has not confirmed the fielders yet.
    public var defenseCheckDue: Bool?
    /// Whether the batting screen should offer the dropped third strike button.
    public var droppedThirdStrikePossible: Bool?
    /// Whether enough has been played for the game to count (five innings, or four and a half
    /// with the home team ahead).
    public var isRegulationComplete: Bool?
    /// The "Is the game over?" question the app should be asking: "regulation", "timeLimit"
    /// or "runRule".
    public var gameOverQuestion: EndOfGame.Reason?
    /// Whether any such question is open (false checks that none is).
    public var isGameOverQuestionOpen: Bool?
    /// Whether the time limit has passed during this inning.
    public var isLastInning: Bool?
    /// Whether the batter due up holds a batting hole, so the app should record an automatic out.
    public var isBattingHoleUp: Bool?
    /// The defense the rules engine suggests for the defense check, exactly. An empty list means
    /// no suggestion (the defense check is not due).
    public var suggestedDefense: [ExpectedFielder]?
    public var isFinal: Bool?
}

/// A runner who should be on a base.
public struct ExpectedRunner: Codable, Sendable {
    public var base: Base
    public var runner: PlayerID
    /// The pitcher who should be charged if this runner scores.
    public var responsiblePitcher: PlayerID?
    /// For the runner for a designated non-runner: the designated non-runner.
    public var standingInFor: PlayerID?
}

/// A pitcher's expected pitches, strikes and batters faced so far.
public struct ExpectedPitcherTally: Codable, Sendable {
    public var pitcher: PlayerID
    public var pitches: Int?
    public var strikes: Int?
    public var battersFaced: Int?
}

/// One spot in a team's batting order. `index` counts from 0 for the leadoff spot.
public struct ExpectedSlot: Codable, Sendable {
    public var team: TeamSide
    public var index: Int
    /// Everyone who has batted in the spot, in order.
    public var players: [PlayerID]?
    /// Where the current player is fielding now, from the team's defense. Use `isBattingOnly`
    /// to check for no position.
    public var position: Position?
    /// True when the current player should bat only, with no fielding position.
    public var isBattingOnly: Bool?
    /// Whether the spot is a batting hole.
    public var isHole: Bool?
}

/// A team's batting order as a whole.
public struct ExpectedLineup: Codable, Sendable {
    public var team: TeamSide
    /// How many spots the order has.
    public var length: Int?
    /// The spot due up, counting from 0.
    public var nextBatterIndex: Int?
    /// Exactly the starters who may re-enter now, in any order.
    public var eligibleToReenter: [PlayerID]?
    /// Exactly the pitchers who may come back to pitch, in any order.
    public var eligibleToPitchAgain: [PlayerID]?
}

/// Who should be playing a position.
public struct ExpectedFielder: Codable, Sendable {
    public var team: TeamSide
    public var position: Position
    public var player: PlayerID
}

/// The notation one event should have in the play log.
public struct ExpectedNotation: Codable, Sendable {
    public var event: EventID
    public var notation: String
}

/// A batter's expected box score numbers. Names match `BattingCounts`.
public struct ExpectedBatting: Codable, Sendable {
    public var player: PlayerID
    public var plateAppearances: Int?
    public var atBats: Int?
    public var runs: Int?
    public var hits: Int?
    public var doubles: Int?
    public var triples: Int?
    public var homeRuns: Int?
    public var runsBattedIn: Int?
    public var walks: Int?
    public var strikeouts: Int?
    public var hitByPitch: Int?
    public var sacrificeFlies: Int?
    public var sacrificeBunts: Int?
    public var stolenBases: Int?
    public var caughtStealing: Int?
    /// The positions on the batter's line, in order, as the box score prints them: ["ph", "2b"].
    /// An empty list means a batter who only batted.
    public var positions: [String]?
}

/// A pitcher's expected box score numbers. Names match `PitchingCounts`.
public struct ExpectedPitching: Codable, Sendable {
    public var pitcher: PlayerID
    public var outsRecorded: Int?
    public var battersFaced: Int?
    public var hits: Int?
    public var runs: Int?
    public var walks: Int?
    public var strikeouts: Int?
    public var homeRuns: Int?
    public var hitBatters: Int?
    public var pitches: Int?
    public var strikes: Int?
    /// The pitcher's decision: "win" or "loss". Use `hasDecision: false` to check for none.
    public var decision: PitchingDecision?
    /// Whether the pitcher has any decision.
    public var hasDecision: Bool?
}

/// A fielder's expected putouts, assists and errors.
public struct ExpectedFielding: Codable, Sendable {
    public var player: PlayerID
    public var putouts: Int?
    public var assists: Int?
    public var errors: Int?
}

/// A team's expected totals.
public struct ExpectedTeam: Codable, Sendable {
    public var team: TeamSide
    public var runs: Int?
    public var hits: Int?
    public var errors: Int?
    public var leftOnBase: Int?
    /// Runs in each inning, first inning first, as the line score shows them. `null` is an
    /// inning the team did not bat.
    public var lineScore: [Int?]?
    /// Double plays this team turned in the field.
    public var doublePlays: Int?
    /// Triple plays this team turned in the field.
    public var triplePlays: Int?
    /// The players on the team's batting lines, in the order the box score lists them,
    /// substitutes under the player they replaced.
    public var battingLines: [PlayerID]?
}
