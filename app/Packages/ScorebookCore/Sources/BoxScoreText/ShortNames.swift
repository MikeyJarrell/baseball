// Shortening players' names the way a newspaper box score does: last names only, with a
// first initial added only when two players in the game share a last name.
//
// "Danny Ruiz" prints as "Ruiz". If both teams have an Ortiz, Luis Ortiz prints as
// "L. Ortiz" and Ana Ortiz as "A. Ortiz". If even the initials match (Luis and Leo Ortiz),
// both print in full. A name that is only a number or a stand-in ("#22", "Batter 4")
// is printed whole, since its last word alone would mean nothing.

import Foundation
import Model

/// The short name for every player in one box score.
public struct ShortNames: Equatable, Sendable {
    /// Short name by player id.
    private var names: [PlayerID: String]

    /// Works out every player's short name from the full names in a box score. Players are
    /// compared across both teams, because the notes paragraph mixes the two teams together.
    public init(_ box: BoxScore) {
        // Every player mentioned anywhere in the box score, with the first full name given.
        var fullNames: [PlayerID: String] = [:]
        var order: [PlayerID] = []
        func note(_ id: PlayerID, _ name: String) {
            if fullNames[id] == nil {
                fullNames[id] = name
                order.append(id)
            }
        }
        for team in [box.away, box.home] {
            team.batting.forEach { note($0.player, $0.name) }
            team.pitching.forEach { note($0.player, $0.name) }
            team.fielding.forEach { note($0.player, $0.name) }
        }
        let n = box.notes
        for list in [n.errors, n.doubles, n.triples, n.homeRuns, n.runsBattedIn, n.stolenBases,
                     n.caughtStealing, n.sacrificeFlies, n.sacrificeBunts, n.hitByPitch] {
            list.forEach { note($0.player, $0.name) }
        }
        self.init(fullNames: order.map { ($0, fullNames[$0]!) })
    }

    /// Works out short names for a list of players and their full names.
    public init(fullNames list: [(PlayerID, String)]) {
        // Group the players by last name, ignoring capital letters.
        let parts = list.map { (id: $0.0, parts: NameParts($0.1)) }
        var countByLastName: [String: Int] = [:]
        for entry in parts {
            countByLastName[entry.parts.lastName.lowercased(), default: 0] += 1
        }

        // Among players who share a last name, count how many share an initial too.
        var countByInitialed: [String: Int] = [:]
        for entry in parts where countByLastName[entry.parts.lastName.lowercased()]! > 1 {
            countByInitialed[entry.parts.initialed.lowercased(), default: 0] += 1
        }

        var names: [PlayerID: String] = [:]
        for entry in parts {
            let p = entry.parts
            if countByLastName[p.lastName.lowercased()]! == 1 {
                names[entry.id] = p.lastName
            } else if countByInitialed[p.initialed.lowercased()]! == 1 {
                names[entry.id] = p.initialed
            } else {
                names[entry.id] = p.fullName
            }
        }
        self.names = names
    }

    /// The short name to print for a player, or `fallback` shortened on its own if the
    /// player is not in the box score.
    public func name(for id: PlayerID, fallback: String) -> String {
        names[id] ?? NameParts(fallback).lastName
    }
}

/// A full name taken apart into the pieces a box score needs.
struct NameParts {
    /// The name as given, with extra spaces removed: "Luis Ortiz".
    var fullName: String
    /// The last name, kept with "Jr." or "III" when there is one: "Ortiz", "Griffey Jr.".
    var lastName: String
    /// First initial and last name, "L. Ortiz"; just the last name when there is no first name.
    var initialed: String

    /// Words that follow a last name rather than being one.
    static let suffixes: Set<String> = ["jr", "jr.", "sr", "sr.", "ii", "iii", "iv", "v"]

    init(_ name: String) {
        let words = name.split(whereSeparator: \.isWhitespace).map(String.init)
        fullName = words.joined(separator: " ")
        if fullName.isEmpty {
            fullName = "?"
        }

        // A number ("#22"), a stand-in ("Batter 4") or one word is printed whole.
        let isStandIn = fullName.hasPrefix("#")
            || (words.last?.contains(where: \.isNumber) ?? false)
            || fullName == "Unknown player"
        if isStandIn || words.count < 2 {
            lastName = fullName
            initialed = fullName
            return
        }

        // Keep a suffix with the last name: "Ken Griffey Jr." is "Griffey Jr.".
        var lastWordCount = 1
        if words.count >= 3, NameParts.suffixes.contains(words.last!.lowercased()) {
            lastWordCount = 2
        }
        lastName = words.suffix(lastWordCount).joined(separator: " ")
        initialed = "\(words[0].prefix(1)). \(lastName)"
    }
}
