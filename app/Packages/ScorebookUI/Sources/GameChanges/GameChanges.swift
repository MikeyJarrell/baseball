// GameChanges: the sheets that slide up from the batting screen for anything other than a
// pitch or a ball in play.
//
// - The changes menu (`ChangesMenuSheet`) and the sheets it opens: lineups and rosters,
//   pitching change, fielders, pinch hitter, pinch runner, runner for a designated
//   non-runner, add a hitter.
// - The game details (`GameDetailsSheet`): date, start time, innings, home and away.
// - The defense check when our team takes the field (`DefenseSheet`).
// - Runner actions between pitches: steals, pickoffs, wild pitches and the rest (`RunnerActionSheet`).
// - The game menu (`GameMenuSheet`) and what it opens: manual adjustment, an error with
//   nobody moving, the time limit, editing the batter, ending the game.
// - The "Is the game over?" pop-up (`GameOverSheet`).
//
// How these sheets talk to the rest of the app: each one is handed the game's setup (both
// rosters, with names and numbers) and the situation (inning, runners, both batting orders
// and both teams' fielders), and hands back one `GameChangeResult` through `onFinish`: an
// event to record, a player to update, nothing to record, or a cancel. The sheets never work
// out any baseball. Suggestions (who the league's rule says should run, who may re-enter,
// who may pitch again, where runners most likely ended up) come from the data they are handed
// or from a function they are handed. Every suggestion can be overridden: "Someone else" is
// always one tap away, because the app never enforces a league rule.
//
// Screens here may use Model, SampleData and DesignSystem, and nothing else.

import SwiftUI
import Model
import SampleData
import DesignSystem

/// What a sheet hands back when the scorer is done with it.
public enum GameChangeResult: Equatable, Sendable {
    /// Record this event. Any players the scorer created on the spot (a new pitcher known only
    /// by number) are in `newPlayers`: add them to the game's roster first.
    case record(EnteredEvent)
    /// Replace this player in the game's roster with the edited copy (same id): their batter's
    /// name, number or batting side. Rosters change without an event.
    case updatePlayer(PlayerEdit)
    /// The scorer finished, and there is nothing to record: the designated non-runner runs
    /// themselves. Close the sheet and do not open it again for this runner.
    case nothingToRecord
    /// The scorer backed out ("Cancel" or "Later"). Nothing changes; a prompt the game raised,
    /// like the defense check, may be shown again later.
    case cancel
    /// Fix who was in the game: the lineup card came late, or the wrong player was picked.
    case correctLineup(LineupCorrection)
    /// Change the game's details: the date and start time, innings, or home and away.
    case changeDetails(GameDetailsChange)
    /// Do this, and leave the sheet open: the lineups page stays up while the scorer works
    /// through a whole lineup card.
    indirect case keepOpen(GameChangeResult)
}

/// The game's details as the scorer set them on the game details sheet.
public struct GameDetailsChange: Equatable, Sendable {
    /// The scheduled start: the game's date and time.
    public var scheduledStart: Date
    /// Innings in a full game.
    public var innings: Int
    /// True to swap home and away. Only before the first pitch.
    public var switchHomeAndAway: Bool

    public init(scheduledStart: Date, innings: Int, switchHomeAndAway: Bool) {
        self.scheduledStart = scheduledStart
        self.innings = innings
        self.switchHomeAndAway = switchHomeAndAway
    }
}

/// A changed player, to put in place of the one with the same id on one team's game roster.
public struct PlayerEdit: Equatable, Sendable {
    public var side: TeamSide
    public var player: Player

    public init(side: TeamSide, player: Player) {
        self.side = side
        self.player = player
    }
}

/// Everything a sheet is handed about the game: the setup (both rosters, names and numbers,
/// who is a designated non-runner) and the situation now (both batting orders and fielders,
/// the runners, the count). The helpers below only look things up; none of them works out
/// any baseball.
public struct GameChangeContext: Equatable, Sendable {
    public var setup: GameSetup
    public var situation: Situation
    /// The teams whose starting batting order can still lose a hitter: before the first pitch,
    /// with nothing but a defense check recorded for them. The game session says which.
    public var startingOrderOpen: Set<TeamSide>

    /// - Parameter startingOrderOpen: Leave it out for both teams before the first pitch and
    ///   neither after it.
    public init(setup: GameSetup, situation: Situation, startingOrderOpen: Set<TeamSide>? = nil) {
        self.setup = setup
        self.situation = situation
        self.startingOrderOpen = startingOrderOpen ?? (situation.gameStartedAt == nil ? [.away, .home] : [])
    }

    // MARK: Teams

    /// One team as it lined up for the game: its name and roster.
    func team(_ side: TeamSide) -> GameTeam { setup[side] }

    /// One team's batting order and fielders now.
    func state(_ side: TeamSide) -> TeamState { situation[side] }

    /// "Diamond Dogs".
    func teamName(_ side: TeamSide) -> String { setup[side].name }

    /// Our colors or theirs.
    func look(_ side: TeamSide) -> TeamLook { setup[side].isOurs ? .ours : .theirs }

    // MARK: Players

    /// A player on either team.
    func player(_ id: PlayerID?) -> Player? { id.flatMap(setup.player) }

    /// The full name, or "#22", or "Batter 4".
    func name(_ id: PlayerID?) -> String { player(id)?.displayName ?? "Unknown player" }

    /// The last name, for buttons and short labels: "Webb", or "#22".
    func shortName(_ id: PlayerID?) -> String { player(id)?.lastName ?? "Unknown player" }

    /// The jersey number, or "?" when nobody knows it.
    func number(_ id: PlayerID?) -> String {
        guard let n = player(id)?.number, !n.isEmpty else { return "?" }
        return n
    }

    // MARK: Who is where (reading the lists as they are)

    /// Players holding a spot in a team's batting order right now.
    func inBattingOrder(_ side: TeamSide) -> Set<PlayerID> {
        Set(state(side).battingOrder.slots.compactMap(\.current))
    }

    /// Players in a team's field right now.
    func inField(_ side: TeamSide) -> Set<PlayerID> {
        Set(state(side).fielders.map(\.player))
    }

    /// Players who held a batting spot earlier in the game and hold none now, and are not in
    /// the field: they have left the game. Under the league's rules most may not come back,
    /// so the sheets list them only under "Someone else".
    func leftTheGame(_ side: TeamSide) -> Set<PlayerID> {
        let everBatted = Set(state(side).battingOrder.slots.flatMap(\.players))
        return everBatted.subtracting(inBattingOrder(side)).subtracting(inField(side))
    }

    /// The bench right now: on the roster, neither batting nor fielding, and never in the game.
    func bench(_ side: TeamSide) -> [Player] {
        let taken = inBattingOrder(side).union(inField(side)).union(leftTheGame(side))
        return team(side).roster.filter { !taken.contains($0.id) }
    }

    /// The spot a player holds in the batting order now, counting from 0.
    func battingSpot(of id: PlayerID, _ side: TeamSide) -> Int? {
        state(side).battingOrder.index(of: id)
    }

    /// The runners on base, lead runner first.
    var runnersLeadFirst: [BaseRunner] {
        situation.runners.sorted { $0.base > $1.base }
    }

    /// Who our team is, if either team is ours.
    var ourSide: TeamSide? { setup.ourSide }
}

// MARK: - Words

/// "1st", "2nd", "3rd", "4th", "11th": a batting spot counted from 1.
func ordinal(_ n: Int) -> String {
    let ones = n % 10, tens = (n / 10) % 10
    let suffix = tens == 1 ? "th" : (ones == 1 ? "st" : ones == 2 ? "nd" : ones == 3 ? "rd" : "th")
    return "\(n)\(suffix)"
}

/// "first", "second", "third", "home".
func baseName(_ base: Base) -> String {
    switch base {
    case .home: "home"
    case .first: "first"
    case .second: "second"
    case .third: "third"
    }
}

/// "1st", "2nd", "3rd", "Home": short base labels for buttons.
func baseShortName(_ base: Base) -> String {
    switch base {
    case .home: "Home"
    case .first: "1st"
    case .second: "2nd"
    case .third: "3rd"
    }
}

/// "Left", "Right", "Switch".
func battingSideName(_ side: BattingSide) -> String {
    switch side {
    case .left: "Left"
    case .right: "Right"
    case .switchHitter: "Switch"
    }
}

/// "Throws right", or nothing when nobody knows.
func throwsText(_ player: Player?) -> String? {
    switch player?.throwsWith {
    case .left: "Throws left"
    case .right: "Throws right"
    case nil: nil
    }
}

/// "bats left", or nothing when nobody knows.
func batsText(_ player: Player?) -> String? {
    switch player?.bats {
    case .left: "bats left"
    case .right: "bats right"
    case .switchHitter: "switch hitter"
    case nil: nil
    }
}

/// "Shortstop": a position's full name with a capital letter.
func positionTitle(_ position: Position) -> String {
    position.name.prefix(1).uppercased() + position.name.dropFirst()
}
