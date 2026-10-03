// Identifiers: the name tags that point at a player, team, game, event or song.
//
// Every one is a short piece of text under the hood ("mud-07", or a long random
// code for things made in the app). Each kind gets its own type so the compiler
// stops anyone from passing a team's id where a player's id belongs.
//
// In a saved JSON file an id is written as plain text: "mud-07".

import Foundation

/// Points at one player. Stays the same for the player's whole career with the team,
/// which is how season stats match a player across games.
public struct PlayerID: Hashable, Codable, Sendable, RawRepresentable, CodingKeyRepresentable,
    ExpressibleByStringLiteral, CustomStringConvertible, Comparable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { self.rawValue = value }
    /// A brand-new id for a player created in the app.
    public static func make() -> PlayerID { PlayerID(rawValue: UUID().uuidString) }
    public var description: String { rawValue }
    public static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
}

/// Points at one team: ours, or an opponent we have played.
public struct TeamID: Hashable, Codable, Sendable, RawRepresentable, CodingKeyRepresentable,
    ExpressibleByStringLiteral, CustomStringConvertible, Comparable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { self.rawValue = value }
    /// A brand-new id for a team created in the app.
    public static func make() -> TeamID { TeamID(rawValue: UUID().uuidString) }
    public var description: String { rawValue }
    public static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
}

/// Points at one game.
public struct GameID: Hashable, Codable, Sendable, RawRepresentable, CodingKeyRepresentable,
    ExpressibleByStringLiteral, CustomStringConvertible, Comparable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { self.rawValue = value }
    /// A brand-new id for a game created in the app.
    public static func make() -> GameID { GameID(rawValue: UUID().uuidString) }
    public var description: String { rawValue }
    public static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
}

/// Points at one entry in a game's event list (one pitch, one play, one substitution).
/// Edits and undo find the event by this id.
public struct EventID: Hashable, Codable, Sendable, RawRepresentable, CodingKeyRepresentable,
    ExpressibleByStringLiteral, CustomStringConvertible, Comparable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { self.rawValue = value }
    /// A brand-new id for an event entered in the app.
    public static func make() -> EventID { EventID(rawValue: UUID().uuidString) }
    public var description: String { rawValue }
    public static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
}

/// Points at one song in the walk-up song library.
public struct SongID: Hashable, Codable, Sendable, RawRepresentable, CodingKeyRepresentable,
    ExpressibleByStringLiteral, CustomStringConvertible, Comparable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { self.rawValue = value }
    /// A brand-new id for a song imported in the app.
    public static func make() -> SongID { SongID(rawValue: UUID().uuidString) }
    public var description: String { rawValue }
    public static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
}
