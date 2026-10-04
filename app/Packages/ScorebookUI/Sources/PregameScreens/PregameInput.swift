// What the pregame screens are handed, and what they hand back.
//
// The screens work out no baseball and load nothing themselves. The app shell hands them our
// saved team, the saved opponents, our recent games (for last game's lineup and the last
// lineup we saw from each opponent), who has pitched lately, and today's date. They hand back
// one finished `GameSetup` when the scorer taps "Play ball", or nothing if the scorer cancels.

import Foundation
import Model

/// Everything the pregame screens start from. All of it is plain data the app shell loads.
public struct PregameInput: Equatable, Sendable {
    /// Our saved team, with its full roster.
    public var ourTeam: Team
    /// Every saved opponent, in the order to list them (most recently played first reads best).
    public var opponents: [Team]
    /// Our recent games' setups, newest first. The first one is "last game": our lineup starts
    /// from it. The newest one against the chosen opponent gives their batting order.
    /// Empty before our first game, and then our lineup starts from the roster instead.
    public var recentGames: [GameSetup]
    /// Who has pitched lately, for either team, newest or oldest first (the screens sort it).
    /// The app shell can fill it from box scores, which include relievers; if it is left
    /// empty, the starting pitchers in `recentGames` are used.
    public var pitchingHistory: [PitchingAppearance]
    /// Today: the game's date unless the scorer changes it.
    public var today: Date

    public init(
        ourTeam: Team,
        opponents: [Team],
        recentGames: [GameSetup] = [],
        pitchingHistory: [PitchingAppearance] = [],
        today: Date = Date()
    ) {
        self.ourTeam = ourTeam
        self.opponents = opponents
        self.recentGames = recentGames
        self.pitchingHistory = pitchingHistory
        self.today = today
    }

    /// Our last game's setup, if we have played one.
    public var lastGame: GameSetup? { recentGames.first { $0.ourSide != nil } }

    /// The newest game against one opponent, if we have played them.
    public func lastGame(against opponent: TeamID) -> GameSetup? {
        recentGames.first { game in
            guard let ours = game.ourSide else { return false }
            return game[ours.opponent].teamID == opponent
        }
    }

    /// Who has pitched lately: the history handed in, or else the starters of our recent games.
    var pitching: [PitchingAppearance] {
        pitchingHistory.isEmpty ? PregameBuilder.startingPitchers(in: recentGames) : pitchingHistory
    }
}

/// One pitcher's appearance in an earlier game, for listing whoever pitched most recently first.
public struct PitchingAppearance: Equatable, Hashable, Sendable {
    public var player: PlayerID
    /// The game's scheduled start.
    public var date: Date
    /// True if they started the game; false if they came on in relief.
    public var started: Bool

    public init(player: PlayerID, date: Date, started: Bool = true) {
        self.player = player
        self.date = date
        self.started = started
    }
}

/// What the pregame screens hand back.
public enum PregameResult: Equatable, Sendable {
    /// The scorer tapped "Play ball": start a game with this setup. Its opponent's game roster
    /// may hold players typed in here (numbers, a new pitcher); `PregameBuilder.updatedTeam`
    /// merges them into the saved team, so they are there next time.
    case playBall(GameSetup)
    /// The scorer cancelled. Nothing changes.
    case cancel
}
