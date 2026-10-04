// The whole pregame setup while the scorer works through the five steps, and the plain
// functions that turn it into a `GameSetup`. Nothing here draws on screen, so all of it can be
// tested on its own (the tests are in ScorebookUI/Tests/PregameScreensTests).
//
// The screens work out no baseball: they arrange the lists the scorer asked for and copy the
// game's details into the setup. The league's rules are shown, never enforced.

import Foundation
import Model

// MARK: - The game's details

/// The first step: date, home or away, innings, the scheduled start and the time limit.
public struct GameDetails: Equatable, Sendable {
    /// The day of the game.
    public var day: Date
    /// True when we are the home team and bat second.
    public var weAreHome: Bool
    /// Innings in a full game: nine by default [9.1 D].
    public var innings: Int
    /// The scheduled start, in minutes after midnight: 540 is 9:00 AM.
    public var startMinutes: Int
    /// How long after the start the time limit falls, in minutes: 180 (three hours) by default
    /// [9.1 G]. The scorer sets it as a clock time, which moves with the start.
    public var timeLimitMinutes: Int
    /// A championship game: three hours fifteen and the 15-run rule [9.1 J, 9.13 B].
    public var isChampionship: Bool

    public init(day: Date, weAreHome: Bool = true, innings: Int = 9, startMinutes: Int = 9 * 60,
                timeLimitMinutes: Int = 180, isChampionship: Bool = false) {
        self.day = day
        self.weAreHome = weAreHome
        self.innings = innings
        self.startMinutes = startMinutes
        self.timeLimitMinutes = timeLimitMinutes
        self.isChampionship = isChampionship
    }

    /// One more or one fewer inning, between 1 and 15.
    public mutating func changeInnings(by step: Int) {
        innings = min(max(innings + step, 1), 15)
    }

    /// Sets the scheduled start to a clock time picked on the time wheel (any minute: 1:03 PM).
    /// The time limit moves with it, staying the same length (three hours unless changed).
    public mutating func setStart(_ time: Date, calendar: Calendar = .current) {
        let parts = calendar.dateComponents([.hour, .minute], from: time)
        startMinutes = (parts.hour ?? 9) * 60 + (parts.minute ?? 0)
    }

    /// Sets the time limit to a clock time picked on the time wheel. The setup keeps it as the
    /// time from the start to the limit, so a late first pitch moves it later (rule 9.1 G). A
    /// clock time at or before the start is taken as after midnight.
    public mutating func setTimeLimitEnd(_ time: Date, calendar: Calendar = .current) {
        let parts = calendar.dateComponents([.hour, .minute], from: time)
        var length = (parts.hour ?? 0) * 60 + (parts.minute ?? 0) - startMinutes
        if length <= 0 { length += 24 * 60 }
        timeLimitMinutes = length
    }

    /// Switches championship rules on or off. A time limit still at the usual length for the old
    /// choice changes to the usual length for the new one (three hours, or three fifteen).
    public mutating func setChampionship(_ on: Bool) {
        let usualBefore = isChampionship ? GameRules.championship.timeLimitMinutes : GameRules.league.timeLimitMinutes
        if timeLimitMinutes == usualBefore {
            timeLimitMinutes = (on ? GameRules.championship.timeLimitMinutes : GameRules.league.timeLimitMinutes) ?? 180
        }
        isChampionship = on
    }

    /// The scheduled start as a moment, on the game's day, in the phone's time zone.
    public func scheduledStart(calendar: Calendar = .current) -> Date {
        calendar.date(bySettingHour: startMinutes / 60, minute: startMinutes % 60, second: 0, of: day) ?? day
    }

    /// When the time limit falls if the game starts on schedule: three hours after the start
    /// unless changed. At the first pitch the rules engine moves it to three hours after that pitch.
    public func timeLimitEnd(calendar: Calendar = .current) -> Date {
        scheduledStart(calendar: calendar).addingTimeInterval(Double(timeLimitMinutes * 60))
    }

    /// The rules for this game: the league's, or the championship's, with these innings and time limit.
    public var rules: GameRules {
        var rules = isChampionship ? GameRules.championship : GameRules.league
        rules.scheduledInnings = innings
        rules.timeLimitMinutes = timeLimitMinutes
        return rules
    }
}

// MARK: - The whole draft

/// Which opponent the scorer picked on the first step.
public enum OpponentChoice: Equatable, Hashable, Sendable {
    /// A saved team.
    case saved(TeamID)
    /// A team we have never played, named on the spot.
    case new
}

/// Everything the scorer has chosen so far, across all five steps.
public struct PregameDraft: Equatable, Sendable {
    /// What the screens were handed.
    public let input: PregameInput
    /// Date, home or away, innings, start and time limit.
    public var details: GameDetails
    /// The opponent, once picked.
    public private(set) var opponentChoice: OpponentChoice?
    /// The name typed for a new opponent.
    public var newOpponentName: String = ""
    /// The id a new opponent gets, made once.
    public let newOpponentID: TeamID
    /// Our lineup.
    public var ours: OurLineup
    /// Their lineup and pitcher. Starts empty until an opponent is picked.
    public var theirs: TheirLineup
    /// Throwing hands the scorer filled in on the pitchers step, for either team.
    public var handEdits: [PlayerID: Hand] = [:]
    /// The game our lineup started from, if any (else it started from the roster).
    public let lineupStartedFrom: GameSetup?

    /// A fresh draft: today's date, nine innings, 9:00 AM, three hours, and our lineup from last
    /// game (or from the roster before our first game).
    public init(input: PregameInput, newOpponentID: TeamID = .make()) {
        self.input = input
        self.newOpponentID = newOpponentID
        self.details = GameDetails(day: input.today)
        if let last = input.lastGame, let side = last.ourSide {
            ours = OurLineup.fromLastGame(last[side], roster: input.ourTeam.roster)
            lineupStartedFrom = last
        } else {
            ours = OurLineup.fromRoster(input.ourTeam.roster)
            lineupStartedFrom = nil
        }
        theirs = TheirLineup(mode: .numbers)
    }

    /// Picks the opponent, and starts their lineup from their saved roster and the last game against them.
    public mutating func chooseOpponent(_ choice: OpponentChoice) {
        guard choice != opponentChoice else { return }
        opponentChoice = choice
        let team = opponent ?? Team(id: newOpponentID, name: "")
        let last = input.lastGame(against: team.id).flatMap { game in game.ourSide.map { game[$0.opponent] } }
        theirs = TheirLineup.starting(for: team, lastGame: last, pitching: input.pitching)
    }

    /// The opponent as a team: the saved one, or the new one with the name typed so far.
    public var opponent: Team? {
        switch opponentChoice {
        case .saved(let id):
            return input.opponents.first { $0.id == id }
        case .new:
            let name = newOpponentName.trimmingCharacters(in: .whitespaces)
            return Team(id: newOpponentID, name: name.isEmpty ? "Opponent" : name)
        case nil:
            return nil
        }
    }

    /// The opponent's name for headings: "Mudcats", or "Opponent" before one is picked.
    public var opponentName: String { opponent?.name ?? "Opponent" }

    /// The league's limit on designated non-runners: two [9.11 J].
    public var nonRunnerLimit: Int { details.rules.maxDesignatedNonRunners }

    // MARK: Pitchers

    /// Our pitchers to choose from: whoever pitched most recently first, then everyone else on
    /// the roster in roster order.
    public var ourPitcherChoices: [PitcherChoice] {
        PregameBuilder.pitcherChoices(players: input.ourTeam.roster, history: input.pitching)
    }

    /// Their pitchers to choose from: anyone who has pitched against us, most recently first,
    /// then their hitters in batting order, then the rest of their roster and anyone new.
    /// Placeholder hitters ("Batter 3") are left out.
    public var theirPitcherChoices: [PitcherChoice] {
        guard let team = opponent else { return [] }
        let order = theirs.battingOrder(for: team)
        let everyone = theirs.roster(for: team).filter { $0.placeholder == nil || !$0.isUnnamed }
        let ordered = order.compactMap { id in everyone.first { $0.id == id } }
            + everyone.filter { !order.contains($0.id) }
        return PregameBuilder.pitcherChoices(players: ordered, history: input.pitching)
    }

    /// Our starting pitcher: whoever is at position 1.
    public var ourPitcher: PlayerID? { ours.defense[.pitcher] }

    /// A player on either team, as they will be in the game (with any throwing hand filled in).
    public func player(_ id: PlayerID) -> Player? {
        let found = ours.player(id) ?? opponent.flatMap { team in theirs.roster(for: team).first { $0.id == id } }
        return found.map { PregameBuilder.applying(handEdits, to: [$0])[0] }
    }

    // MARK: Finishing

    /// Things the scorer may want to know before "Play ball". None of them blocks the game.
    public var notes: [String] {
        var notes: [String] = []
        for position in ours.emptyPositions {
            notes.append("Nobody is playing \(position.name).")
        }
        // Turns by inning can leave a position empty in even innings only.
        for position in ours.emptyPositions(inInning: 2) where !ours.emptyPositions.contains(position) {
            notes.append("Nobody plays \(position.name) in even innings.")
        }
        if ours.nonRunners.count > nonRunnerLimit {
            notes.append("\(ours.nonRunners.count) designated non-runners; the league allows \(nonRunnerLimit).")
        }
        return notes
    }

    /// Why "Play ball" cannot be tapped yet, if it cannot: no opponent, or a batting order with
    /// nobody in it (the game needs someone to bat).
    public var missing: String? {
        guard let team = opponent else { return "Pick an opponent first." }
        if ours.battingOrder.isEmpty { return "Our batting order is empty." }
        if theirs.battingOrder(for: team).isEmpty { return "The \(team.name) batting order is empty." }
        return nil
    }

    /// The finished game setup, once nothing is missing.
    public func setup(calendar: Calendar = .current) -> GameSetup? {
        guard missing == nil, let opponent else { return nil }
        let ourTeam = ours.gameTeam(for: input.ourTeam, handEdits: handEdits)
        let theirTeam = theirs.gameTeam(for: opponent, handEdits: handEdits)
        return GameSetup(
            scheduledStart: details.scheduledStart(calendar: calendar),
            away: details.weAreHome ? theirTeam : ourTeam,
            home: details.weAreHome ? ourTeam : theirTeam,
            rules: details.rules
        )
    }
}

/// One pitcher on the starting pitchers step, with their most recent appearance if they have one.
public struct PitcherChoice: Identifiable, Equatable, Sendable {
    public var player: Player
    public var lastPitched: PitchingAppearance?
    public var id: PlayerID { player.id }
}

// MARK: - Plain helpers

/// Small plain functions the pregame screens share, and that the app shell may want.
public enum PregameBuilder {
    /// The starting pitchers of some games, for both teams: a stand-in pitching history when no
    /// box scores are handed in.
    public static func startingPitchers(in games: [GameSetup]) -> [PitchingAppearance] {
        games.flatMap { game in
            [game.away, game.home].compactMap { team in
                team.startingPitcher.map { PitchingAppearance(player: $0, date: game.scheduledStart, started: true) }
            }
        }
    }

    /// The newest appearance in a list; a start beats a relief outing on the same day.
    static func mostRecent(_ appearances: [PitchingAppearance]) -> PitchingAppearance? {
        appearances.max { a, b in
            a.date != b.date ? a.date < b.date : (!a.started && b.started)
        }
    }

    /// Players as pitcher choices: whoever pitched most recently first, then everyone who has
    /// not pitched, in the order given.
    static func pitcherChoices(players: [Player], history: [PitchingAppearance]) -> [PitcherChoice] {
        let choices = players.map { player in
            PitcherChoice(player: player, lastPitched: mostRecent(history.filter { $0.player == player.id }))
        }
        let pitched = choices.filter { $0.lastPitched != nil }.sorted {
            guard let a = $0.lastPitched, let b = $1.lastPitched else { return false }
            return a.date != b.date ? a.date > b.date : (a.started && !b.started)
        }
        return pitched + choices.filter { $0.lastPitched == nil }
    }

    /// Players with any throwing hands the scorer filled in.
    static func applying(_ handEdits: [PlayerID: Hand], to players: [Player]) -> [Player] {
        guard !handEdits.isEmpty else { return players }
        return players.map { player in
            var player = player
            if let hand = handEdits[player.id] { player.throwsWith = hand }
            return player
        }
    }

    /// A saved team brought up to date from a game's roster, for saving after "Play ball": anyone
    /// typed in on the pregame screens (a number, a new pitcher) joins the roster; a jersey number
    /// typed in replaces the saved one; details the saved team was missing (a throwing hand) are
    /// filled in. Placeholders nobody has named ("Batter 4", "Pitcher") are left off. Our team's
    /// game roster is a copy of the saved one, so for our team nothing changes but throwing hands.
    public static func updatedTeam(saved: Team, from game: GameTeam) -> Team {
        var team = saved
        for player in game.roster {
            if let i = team.roster.firstIndex(where: { $0.id == player.id }) {
                var known = team.roster[i]
                known.name = known.name ?? player.name
                // A number typed on the pregame screens replaces the saved one.
                if let typed = player.number, !typed.isEmpty { known.number = typed }
                known.bats = known.bats ?? player.bats
                known.throwsWith = known.throwsWith ?? player.throwsWith
                team.roster[i] = known
            } else if !player.isUnnamed {
                var added = player
                added.placeholder = nil
                team.roster.append(added)
            }
        }
        return team
    }
}
