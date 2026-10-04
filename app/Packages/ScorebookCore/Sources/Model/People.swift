// People and teams: players, rosters, walk-up songs and announcer introductions.

import Foundation

/// One player, on our team or theirs.
///
/// Every detail except the id is optional, because the scorer often knows very little
/// about the other team: "their number 22" is a player with only a `number`, and a
/// hitter nobody has named yet is a player with only a `placeholder` ("Batter 4").
/// Details can be filled in at any point, even mid-game.
public struct Player: Identifiable, Codable, Equatable, Hashable, Sendable {
    public var id: PlayerID
    /// Full name, "Derek Jeter". Missing when we only know a number, or nothing.
    public var name: String?
    /// Jersey number as text, so "00" and "0" stay different.
    public var number: String?
    /// The stand-in label used until the scorer names this hitter: "Batter 4".
    public var placeholder: String?
    /// Which side of the plate they bat from, if known.
    public var bats: BattingSide?
    /// Which hand they throw with, if known.
    public var throwsWith: Hand?
    /// Their walk-up song, for our players.
    public var walkUpSongID: SongID?
    /// Their warm-up song, for our pitchers: played while they warm up when our team takes the field.
    public var warmUpSongID: SongID?
    /// The stadium announcer introduction played before their song, if they have one.
    public var introduction: AnnouncerIntroduction?
    /// The position they usually play, for our players: the first game's lineup puts them
    /// there. Missing when they have no usual position.
    public var usualPosition: Position?
    /// Whether they usually bat, field, both, or start on the bench. Missing when nobody has
    /// said; the first game's lineup then has them bat, and field at their usual position if
    /// they have one.
    public var usualRole: UsualRole?
    /// True for our usual leadoff hitter, who heads the first game's batting order.
    public var usuallyLeadsOff: Bool

    public init(
        id: PlayerID = .make(),
        name: String? = nil,
        number: String? = nil,
        placeholder: String? = nil,
        bats: BattingSide? = nil,
        throwsWith: Hand? = nil,
        walkUpSongID: SongID? = nil,
        warmUpSongID: SongID? = nil,
        introduction: AnnouncerIntroduction? = nil,
        usualPosition: Position? = nil,
        usualRole: UsualRole? = nil,
        usuallyLeadsOff: Bool = false
    ) {
        self.id = id
        self.name = name
        self.number = number
        self.placeholder = placeholder
        self.bats = bats
        self.throwsWith = throwsWith
        self.walkUpSongID = walkUpSongID
        self.warmUpSongID = warmUpSongID
        self.introduction = introduction
        self.usualPosition = usualPosition
        self.usualRole = usualRole
        self.usuallyLeadsOff = usuallyLeadsOff
    }

    // MARK: Reading and writing JSON

    private enum CodingKeys: String, CodingKey {
        case id, name, number, placeholder, bats, throwsWith, walkUpSongID, warmUpSongID, introduction
        case usualPosition, usualRole, usuallyLeadsOff
    }

    /// Reads a player from a saved file. Files saved before a player had a usual position,
    /// role or leadoff mark read with none.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(PlayerID.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        number = try c.decodeIfPresent(String.self, forKey: .number)
        placeholder = try c.decodeIfPresent(String.self, forKey: .placeholder)
        bats = try c.decodeIfPresent(BattingSide.self, forKey: .bats)
        throwsWith = try c.decodeIfPresent(Hand.self, forKey: .throwsWith)
        walkUpSongID = try c.decodeIfPresent(SongID.self, forKey: .walkUpSongID)
        warmUpSongID = try c.decodeIfPresent(SongID.self, forKey: .warmUpSongID)
        introduction = try c.decodeIfPresent(AnnouncerIntroduction.self, forKey: .introduction)
        usualPosition = try c.decodeIfPresent(Position.self, forKey: .usualPosition)
        usualRole = try c.decodeIfPresent(UsualRole.self, forKey: .usualRole)
        usuallyLeadsOff = try c.decodeIfPresent(Bool.self, forKey: .usuallyLeadsOff) ?? false
    }

    /// Writes a player to a file, leaving out the leadoff mark when it is off so files stay short.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(name, forKey: .name)
        try c.encodeIfPresent(number, forKey: .number)
        try c.encodeIfPresent(placeholder, forKey: .placeholder)
        try c.encodeIfPresent(bats, forKey: .bats)
        try c.encodeIfPresent(throwsWith, forKey: .throwsWith)
        try c.encodeIfPresent(walkUpSongID, forKey: .walkUpSongID)
        try c.encodeIfPresent(warmUpSongID, forKey: .warmUpSongID)
        try c.encodeIfPresent(introduction, forKey: .introduction)
        try c.encodeIfPresent(usualPosition, forKey: .usualPosition)
        try c.encodeIfPresent(usualRole, forKey: .usualRole)
        if usuallyLeadsOff { try c.encode(true, forKey: .usuallyLeadsOff) }
    }

    /// What to call this player on screen: their name, else "#22", else the
    /// placeholder ("Batter 4"), else "Unknown player".
    public var displayName: String {
        if let name, !name.isEmpty { return name }
        if let number, !number.isEmpty { return "#\(number)" }
        if let placeholder, !placeholder.isEmpty { return placeholder }
        return "Unknown player"
    }

    /// The last word of the name, for box scores ("Jeter"). Falls back to `displayName`.
    public var lastName: String {
        guard let name, let last = name.split(separator: " ").last else { return displayName }
        return String(last)
    }

    /// True when the scorer knows neither a name nor a number yet.
    public var isUnnamed: Bool {
        (name?.isEmpty ?? true) && (number?.isEmpty ?? true)
    }
}

/// Whether a player usually bats, fields, both, or starts on the bench. The league lets a team
/// bat any number of hitters while nine players field, so some players only bat and some only
/// field. Used for the first game's lineup, before there is a last game to copy.
public enum UsualRole: String, Codable, Sendable, CaseIterable {
    /// Bats and plays the field (at their usual position, if they have one).
    case batsAndFields
    /// Bats but does not play the field.
    case batsOnly
    /// Plays the field but does not bat.
    case fieldsOnly
    /// Usually starts the game on the bench.
    case startsOnBench
}

/// The stadium announcer's "Now batting, number two, Derek Jeter. Number two."
public struct AnnouncerIntroduction: Codable, Equatable, Hashable, Sendable {
    /// Where the introduction comes from.
    public enum Source: String, Codable, Sendable, CaseIterable {
        /// Recorded in the app with the phone's microphone.
        case recorded
        /// A sound file imported from the Files app.
        case imported
        /// The iPhone's built-in speech voice reads the number and name.
        case phoneVoice
        /// Put together at play time from short recordings shared by the whole team
        /// ("Now batting," and every number) and one of this player's name, so a new jersey
        /// number needs no new recording. `fileName` is the name recording.
        case pieced
    }

    public var source: Source
    /// The sound file's name inside the app's audio folder. Missing for `phoneVoice`.
    public var fileName: String?

    public init(source: Source, fileName: String? = nil) {
        self.source = source
        self.fileName = fileName
    }

    // The shared pieces of a `pieced` introduction, in the app's audio folder. The team
    // loader copies them in from ~/Dropbox/baseball/intros/.

    /// "Now batting,"
    public static let nowBattingFile = "announcer-now-batting.m4a"

    /// "Number twenty-two," said mid-sentence, for jersey number "22" (or "00").
    public static func numberFile(_ number: String) -> String {
        "announcer-number-\(number).m4a"
    }

    /// "Number twenty-two." said to end the introduction, voice falling. Optional: without
    /// it, the mid-sentence recording is used again.
    public static func closingNumberFile(_ number: String) -> String {
        "announcer-closing-\(number).m4a"
    }

    /// A player's name recording, from the plain file name stem "aidan-kurt".
    public static func nameFile(_ stem: String) -> String {
        "announcer-name-\(stem).m4a"
    }
}

/// A team: ours, or an opponent. Opponents are saved too, so their roster can be
/// reused the next time we play them.
public struct Team: Identifiable, Codable, Equatable, Hashable, Sendable {
    public var id: TeamID
    /// "Mudcats".
    public var name: String
    /// True for our team. Exactly one saved team should be ours.
    public var isOurs: Bool
    /// Everyone on the team.
    public var roster: [Player]
    /// The short name for the scoreboard, chosen on the team page: "DOGS", "MUD". Missing
    /// means the app makes one with `ShortTeamName.make(from:)`.
    public var shortName: String?

    public init(id: TeamID = .make(), name: String, isOurs: Bool = false, roster: [Player] = [], shortName: String? = nil) {
        self.id = id
        self.name = name
        self.isOurs = isOurs
        self.roster = roster
        self.shortName = shortName
    }

    /// The short name to show: the chosen one, or one made from the name.
    public var displayShortName: String { shortName ?? ShortTeamName.make(from: name) }

    /// Finds a player on this team by id.
    public func player(_ id: PlayerID) -> Player? {
        roster.first { $0.id == id }
    }
}

/// Short team names for the scoreboard.
public enum ShortTeamName {
    /// A short name made from a team name, in capitals: the last word if it has four letters or
    /// fewer, else its first three letters. "Diamond Dogs" gives "DOGS", "Mudcats" gives "MUD".
    public static func make(from name: String) -> String {
        let last = name.split(separator: " ").last.map(String.init) ?? name
        return (last.count <= 4 ? last : String(last.prefix(3))).uppercased()
    }
}

/// One song in the walk-up song library.
public struct Song: Identifiable, Codable, Equatable, Hashable, Sendable {
    public var id: SongID
    /// The name shown in the app. Starts as the file name; the scorer can rename it.
    public var title: String
    /// Who recorded it, if the scorer knows or the file said: "AC/DC". Shown under the title.
    public var artist: String?
    /// The audio file's name inside the app's `songs/audio/` folder.
    public var fileName: String
    /// Seconds into the track where the walk-up clip starts (the hook).
    public var startTime: TimeInterval
    /// Seconds of song before it fades out by itself, for this song only. Missing means the
    /// walk-up length in the app settings (12 seconds unless changed).
    public var playLength: TimeInterval?
    /// Loudness for this song, from 0 (silent) to 1 (full), to even out the library.
    public var volume: Double
    /// Length of the whole track in seconds, if known.
    public var duration: TimeInterval?

    public init(
        id: SongID = .make(),
        title: String,
        fileName: String,
        startTime: TimeInterval = 0,
        playLength: TimeInterval? = nil,
        volume: Double = 1,
        duration: TimeInterval? = nil,
        artist: String? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.fileName = fileName
        self.startTime = startTime
        self.playLength = playLength
        self.volume = volume
        self.duration = duration
    }
}

/// Every imported song, plus the announcer echo setting. Saved as `songs/library.json`.
public struct SongLibrary: Codable, Equatable, Hashable, Sendable {
    public var songs: [Song]
    /// How much stadium echo to add to recorded introductions, from 0 (none) to 1 (lots).
    public var announcerEcho: Double

    public init(songs: [Song] = [], announcerEcho: Double = 0.5) {
        self.songs = songs
        self.announcerEcho = announcerEcho
    }

    /// Finds a song by id.
    public func song(_ id: SongID) -> Song? {
        songs.first { $0.id == id }
    }
}
