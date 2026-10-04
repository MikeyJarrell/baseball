// Our lineup while the scorer builds it: three lists that do not have to match.
//
// The batting order (any number of hitters, up to two of them designated non-runners), the
// nine fielders (each filled from anyone on the roster, whether or not they bat), and the bench
// (everyone else). A position can also be shared by turns: one player in odd innings, another
// in even ones. These are plain functions with no screen, so they can be tested on their own.

import Foundation
import Model

/// Our lineup for one game, as the scorer edits it on the "Our lineup" step.
public struct OurLineup: Equatable, Sendable {
    /// Everyone on our team who can play today, in roster order.
    public var roster: [Player]
    /// The batting order, leadoff hitter first.
    public var battingOrder: [PlayerID]
    /// Hitters declared designated non-runners, in the order they were declared.
    public var nonRunners: [PlayerID]
    /// Who starts at each position. A position missing from here has nobody yet.
    public var defense: [Position: PlayerID]
    /// For a position shared by turns: who plays it in even innings. The starter in `defense`
    /// plays the odd innings, the first inning included.
    public var alternates: [Position: PlayerID]

    public init(
        roster: [Player],
        battingOrder: [PlayerID] = [],
        nonRunners: [PlayerID] = [],
        defense: [Position: PlayerID] = [:],
        alternates: [Position: PlayerID] = [:]
    ) {
        self.roster = roster
        self.battingOrder = battingOrder
        self.nonRunners = nonRunners
        self.defense = defense
        self.alternates = alternates
    }

    // MARK: Looking things up

    /// Finds a player on our roster.
    public func player(_ id: PlayerID) -> Player? { roster.first { $0.id == id } }

    /// Where a player starts in the field, if they do.
    public func position(of id: PlayerID) -> Position? {
        defense.first { $0.value == id }?.key
    }

    /// The position a player takes in even innings, if they are the second half of a shared position.
    public func alternatePosition(of id: PlayerID) -> Position? {
        alternates.first { $0.value == id }?.key
    }

    /// True if the player is in the batting order.
    public func isBatting(_ id: PlayerID) -> Bool { battingOrder.contains(id) }

    /// True if the player is declared a designated non-runner.
    public func isNonRunner(_ id: PlayerID) -> Bool { nonRunners.contains(id) }

    /// The bench: everyone on the roster who neither bats nor starts in the field, in roster order.
    /// A player who only takes a turn at a shared position is listed here too, since they do not start.
    public var bench: [Player] {
        roster.filter { !isBatting($0.id) && position(of: $0.id) == nil }
    }

    /// Players not in the batting order, in roster order: the choices for "Add to batting order".
    public var notBatting: [Player] {
        roster.filter { !isBatting($0.id) }
    }

    /// Positions with nobody in them, in scorebook order.
    public var emptyPositions: [Position] {
        Position.allCases.filter { defense[$0] == nil }
    }

    // MARK: The batting order

    /// Adds a player to the bottom of the batting order, if they are not already in it.
    public mutating func addToOrder(_ id: PlayerID) {
        guard !isBatting(id), player(id) != nil else { return }
        battingOrder.append(id)
    }

    /// Takes a player out of the batting order. Anyone who leaves the order also stops being a
    /// designated non-runner, since a non-runner is a hitter. If they field, they keep their position.
    public mutating func removeFromOrder(_ id: PlayerID) {
        battingOrder.removeAll { $0 == id }
        nonRunners.removeAll { $0 == id }
    }

    /// Drags hitters to a new place in the order, as a list does when rows are dragged.
    public mutating func moveInOrder(fromOffsets source: IndexSet, toOffset destination: Int) {
        // The same arithmetic as SwiftUI's own move, written out so this file needs no screen code.
        let moving = source.sorted().map { battingOrder[$0] }
        var rest = battingOrder.enumerated().filter { !source.contains($0.offset) }.map(\.element)
        let removedBefore = source.filter { $0 < destination }.count
        rest.insert(contentsOf: moving, at: max(0, min(rest.count, destination - removedBefore)))
        battingOrder = rest
    }

    /// Moves one hitter up (-1) or down (+1) one spot, for the accessibility actions.
    public mutating func moveHitter(_ id: PlayerID, by step: Int) {
        guard let from = battingOrder.firstIndex(of: id) else { return }
        let to = from + step
        guard battingOrder.indices.contains(to) else { return }
        battingOrder.swapAt(from, to)
    }

    // MARK: Designated non-runners

    /// What tapping a hitter's non-runner switch would do.
    public enum NonRunnerTap: Equatable, Sendable {
        /// Declare them: there is room under the league's limit.
        case declare
        /// Take the declaration back.
        case undeclare
        /// Declaring them would go past the league's limit (two). The league is casual, so the
        /// screen asks the scorer to confirm and then allows it.
        case pastLimit(limit: Int)
    }

    /// What tapping the non-runner switch for this hitter would do, given the league's limit.
    public func nonRunnerTap(for id: PlayerID, limit: Int) -> NonRunnerTap {
        if isNonRunner(id) { return .undeclare }
        return nonRunners.count >= limit ? .pastLimit(limit: limit) : .declare
    }

    /// Declares a hitter a designated non-runner, or takes it back. Never refuses: the limit
    /// is checked by the screen, which asks first.
    public mutating func setNonRunner(_ id: PlayerID, _ isNonRunner: Bool) {
        nonRunners.removeAll { $0 == id }
        if isNonRunner, isBatting(id) { nonRunners.append(id) }
    }

    // MARK: Fielders

    /// Puts a player at a position. If they were already at another position, the player who was
    /// here moves there, so the two swap (or that position is left empty if nobody was here).
    /// `nil` empties the position.
    public mutating func assign(_ id: PlayerID?, to position: Position) {
        let previous = defense[position]
        guard let id else {
            defense[position] = nil
            alternates[position] = nil
            return
        }
        if let oldPosition = self.position(of: id), oldPosition != position {
            defense[oldPosition] = previous
        }
        defense[position] = id
        tidyAlternates()
    }

    /// Shares a position by turns: the starter there plays odd innings and this player plays even
    /// ones. `nil` stops sharing it.
    public mutating func setAlternate(_ id: PlayerID?, at position: Position) {
        alternates[position] = id
        tidyAlternates()
    }

    /// Drops any shared position that no longer makes sense: nobody starting there, or the same
    /// player taking both turns.
    private mutating func tidyAlternates() {
        for (position, second) in alternates where defense[position] == nil || defense[position] == second {
            alternates[position] = nil
        }
    }

    // MARK: Into the game setup

    /// This lineup as one team in the game setup.
    public func gameTeam(for team: Team, handEdits: [PlayerID: Hand] = [:]) -> GameTeam {
        let defenseList = defense
            .map { FielderAssignment(position: $0.key, player: $0.value) }
            .sorted { $0.position < $1.position }
        let rotations = alternates
            .compactMap { position, second -> FieldingRotation? in
                guard let starter = defense[position] else { return nil }
                return FieldingRotation(position: position, players: [starter, second])
            }
            .sorted { $0.position < $1.position }
        return GameTeam(
            teamID: team.id,
            name: team.name,
            isOurs: true,
            roster: PregameBuilder.applying(handEdits, to: roster),
            battingOrder: battingOrder,
            defense: defenseList,
            // Kept in batting order, the way a lineup card reads.
            designatedNonRunners: battingOrder.filter { nonRunners.contains($0) },
            fieldingRotations: rotations,
            shortName: team.shortName
        )
    }

    // MARK: Where the lineup starts

    /// Today's lineup, started from last game's: the same batting order, fielders, non-runners and
    /// shared positions, less anyone no longer on the roster. Anyone new on the roster starts on
    /// the bench.
    public static func fromLastGame(_ last: GameTeam, roster: [Player]) -> OurLineup {
        let onRoster = Set(roster.map(\.id))
        var lineup = OurLineup(roster: roster)
        lineup.battingOrder = last.battingOrder.filter { onRoster.contains($0) }
        for assignment in last.defense where onRoster.contains(assignment.player) {
            lineup.defense[assignment.position] = assignment.player
        }
        lineup.nonRunners = last.designatedNonRunners.filter { lineup.battingOrder.contains($0) }
        for rotation in last.fieldingRotations {
            // Keep a two-player turn whose first player still starts at the position.
            guard rotation.players.count >= 2,
                  lineup.defense[rotation.position] == rotation.players[0],
                  onRoster.contains(rotation.players[1]) else { continue }
            lineup.alternates[rotation.position] = rotation.players[1]
        }
        lineup.tidyAlternates()
        return lineup
    }

    /// Today's lineup, started from the roster before our first game: everyone at their usual
    /// position (the first player listed wins a position two people usually play), the usual
    /// leadoff hitter first, then everyone else who does not usually start on the bench, in
    /// roster order. Players who usually start on the bench are on the bench.
    public static func fromRoster(_ roster: [Player], usual: [PlayerID: UsualRole]) -> OurLineup {
        var lineup = OurLineup(roster: roster)
        let starters = roster.filter { !(usual[$0.id]?.startsOnBench ?? false) }
        let leadoff = starters.filter { usual[$0.id]?.leadsOff ?? false }
        let others = starters.filter { !(usual[$0.id]?.leadsOff ?? false) }
        lineup.battingOrder = (leadoff + others).map(\.id)
        for player in starters {
            if let position = usual[player.id]?.position, lineup.defense[position] == nil {
                lineup.defense[position] = player.id
            }
        }
        return lineup
    }
}
