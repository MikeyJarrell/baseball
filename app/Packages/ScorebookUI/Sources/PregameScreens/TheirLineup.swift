// Their lineup while the scorer builds it, in one of two ways: names and numbers from their
// saved roster (with each player's jersey number typeable in their row), or numbers only, typed
// in batting order. Plus their starting pitcher. Plain functions with no screen, so they can be
// tested on their own. Numbers typed here are saved back to the opponent's roster after
// "Play ball" (`PregameBuilder.updatedTeam`).

import Foundation
import Model

/// How much we know about their batting order.
public enum TheirLineupMode: String, Equatable, Hashable, Sendable, CaseIterable {
    /// Names and numbers, from their saved roster.
    case names
    /// Only their jersey numbers, typed in batting order.
    case numbers
}

/// One hitter typed in by number on the "Numbers only" list.
public struct NumberEntry: Identifiable, Equatable, Hashable, Sendable {
    /// The id the hitter gets if their number matches nobody on the saved roster.
    public var id: PlayerID
    /// The jersey number as typed: "22". Empty means not typed yet.
    public var number: String

    public init(id: PlayerID = .make(), number: String = "") {
        self.id = id
        self.number = number
    }
}

/// Their lineup for one game, as the scorer edits it on the "Their lineup" and "Starting
/// pitchers" steps.
public struct TheirLineup: Equatable, Sendable {
    /// Which of the two ways the scorer chose.
    public var mode: TheirLineupMode
    /// The batting order when we know names: players from their saved roster.
    public var namedOrder: [PlayerID]
    /// Jersey numbers typed in the names-and-numbers rows, by player. They replace the saved
    /// number for this game and are saved back to the roster afterward.
    public var numberEdits: [PlayerID: String]
    /// The batting order when we know only numbers.
    public var numbers: [NumberEntry]
    /// Players typed in on these screens who are not on their saved roster: "someone new" pitching.
    public var newPlayers: [Player]
    /// Their starting pitcher. Missing means not known yet: a placeholder "Pitcher" starts.
    public var pitcher: PlayerID?
    /// Their hitters declared designated non-runners.
    public var nonRunners: [PlayerID] = []
    /// The id of that placeholder pitcher.
    public let placeholderPitcherID: PlayerID

    public init(
        mode: TheirLineupMode,
        namedOrder: [PlayerID] = [],
        numberEdits: [PlayerID: String] = [:],
        numbers: [NumberEntry] = [],
        newPlayers: [Player] = [],
        pitcher: PlayerID? = nil,
        placeholderPitcherID: PlayerID = .make()
    ) {
        self.mode = mode
        self.namedOrder = namedOrder
        self.numberEdits = numberEdits
        self.numbers = numbers
        self.newPlayers = newPlayers
        self.pitcher = pitcher
        self.placeholderPitcherID = placeholderPitcherID
    }

    // MARK: Where it starts

    /// Their lineup when the scorer picks an opponent. The batting order comes from the last game
    /// against them if there was one, else their whole saved roster in roster order. The way in
    /// is names if the roster has any names, else numbers (nine blank numbers for a team with no
    /// saved roster). The pitcher is whoever pitched against us most recently, if anyone did.
    public static func starting(for team: Team, lastGame: GameTeam?, pitching: [PitchingAppearance]) -> TheirLineup {
        let onRoster = Set(team.roster.map(\.id))
        let lastOrder = lastGame?.battingOrder.filter { onRoster.contains($0) } ?? []
        let order = lastOrder.isEmpty ? team.roster.map(\.id) : lastOrder
        let hasNames = team.roster.contains { !($0.name ?? "").isEmpty }

        // Numbers in batting order, from whoever has one; nine blank ones if nobody does.
        var numbers = order.compactMap { id in team.player(id)?.number }.filter { !$0.isEmpty }.map { NumberEntry(number: $0) }
        if numbers.isEmpty { numbers = (0..<9).map { _ in NumberEntry() } }

        let recentPitcher = PregameBuilder.mostRecent(pitching.filter { onRoster.contains($0.player) })?.player
        return TheirLineup(mode: hasNames ? .names : .numbers, namedOrder: order, numbers: numbers, pitcher: recentPitcher)
    }

    // MARK: Editing

    /// Adds a blank number at the bottom of the numbers-only order.
    public mutating func addNumber() { numbers.append(NumberEntry()) }

    /// Adds one of their saved players to the bottom of the named order, if not already in it.
    public mutating func addToNamedOrder(_ id: PlayerID) {
        if !namedOrder.contains(id) { namedOrder.append(id) }
    }

    /// Types a jersey number for one of their saved players in the names-and-numbers rows.
    /// Digits only, at most three.
    public mutating func setNumber(_ text: String, for id: PlayerID) {
        numberEdits[id] = String(text.filter(\.isNumber).prefix(3))
    }

    /// Types the number of one hitter on the numbers-only list. Digits only, at most three.
    public mutating func setNumber(_ text: String, forEntry id: PlayerID) {
        guard let i = numbers.firstIndex(where: { $0.id == id }) else { return }
        numbers[i].number = String(text.filter(\.isNumber).prefix(3))
    }

    /// Adds a hitter who is not on their saved roster to the bottom of the batting order.
    public mutating func addNewHitter(name: String, number: String) {
        let id = addNewPlayer(name: name, number: number, throwsWith: nil)
        namedOrder.append(id)
    }

    /// Declares one of their hitters a designated non-runner, or takes it back.
    public mutating func toggleNonRunner(_ id: PlayerID) {
        if nonRunners.contains(id) { nonRunners.removeAll { $0 == id } } else { nonRunners.append(id) }
    }

    /// Adds someone typed in on the spot (a pitcher not on their saved roster) and returns their id.
    @discardableResult
    public mutating func addNewPlayer(name: String, number: String, throwsWith: Hand?) -> PlayerID {
        let name = name.trimmingCharacters(in: .whitespaces)
        let number = number.trimmingCharacters(in: .whitespaces)
        let player = Player(name: name.isEmpty ? nil : name,
                            number: number.isEmpty ? nil : number,
                            placeholder: name.isEmpty && number.isEmpty ? "Pitcher" : nil,
                            throwsWith: throwsWith)
        newPlayers.append(player)
        return player.id
    }

    // MARK: Into the game setup

    /// Their saved roster with any numbers typed in the names-and-numbers rows. A number erased
    /// to blank leaves the saved number as it was.
    public func savedPlayers(for team: Team) -> [Player] {
        team.roster.map { player in
            var player = player
            if mode == .names, let typed = numberEdits[player.id], !typed.isEmpty { player.number = typed }
            return player
        }
    }

    /// Everyone on their side for this game: the saved roster (with typed numbers), anyone typed
    /// in by number, and anyone new. Use `battingOrder(for:)` for the order.
    public func roster(for team: Team) -> [Player] {
        let saved = savedPlayers(for: team)
        let numbered = numberedPlayers(for: team).filter { added in !saved.contains { $0.id == added.id } }
        return saved + numbered + newPlayers
    }

    /// Their batting order, by player id.
    public func battingOrder(for team: Team) -> [PlayerID] {
        switch mode {
        case .names:
            let onRoster = Set(team.roster.map(\.id) + newPlayers.map(\.id))
            return namedOrder.filter { onRoster.contains($0) }
        case .numbers:
            return numberedPlayers(for: team).map(\.id)
        }
    }

    /// The hitters on the numbers-only list as players. A number that matches someone on the
    /// saved roster is that player (each saved player at most once), so their stats carry over;
    /// any other number is a new player known only by number; a blank is "Batter 4".
    func numberedPlayers(for team: Team) -> [Player] {
        guard mode == .numbers else { return [] }
        var used = Set<PlayerID>()
        return numbers.enumerated().map { i, entry in
            let typed = entry.number.trimmingCharacters(in: .whitespaces)
            if typed.isEmpty {
                return Player(id: entry.id, placeholder: "Batter \(i + 1)")
            }
            if let saved = team.roster.first(where: { $0.number == typed && !used.contains($0.id) }) {
                used.insert(saved.id)
                return saved
            }
            return Player(id: entry.id, number: typed)
        }
    }

    /// This lineup as one team in the game setup. Their only known fielder is the pitcher; if
    /// none was chosen, or the one chosen is no longer in this lineup, a placeholder "Pitcher"
    /// starts, to be named when the scorer learns who it is.
    public func gameTeam(for team: Team, handEdits: [PlayerID: Hand] = [:]) -> GameTeam {
        var players = roster(for: team)
        var startingPitcher = pitcher.flatMap { id in players.contains { $0.id == id } ? id : nil }
        if startingPitcher == nil {
            players.append(Player(id: placeholderPitcherID, placeholder: "Pitcher"))
            startingPitcher = placeholderPitcherID
        }
        return GameTeam(
            teamID: team.id,
            name: team.name,
            isOurs: false,
            roster: PregameBuilder.applying(handEdits, to: players),
            battingOrder: battingOrder(for: team),
            defense: startingPitcher.map { [FielderAssignment(position: .pitcher, player: $0)] } ?? [],
            designatedNonRunners: battingOrder(for: team).filter { nonRunners.contains($0) },
            shortName: team.shortName
        )
    }
}
