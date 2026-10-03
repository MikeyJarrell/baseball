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
    /// The stadium announcer introduction played before their song, if they have one.
    public var introduction: AnnouncerIntroduction?

    public init(
        id: PlayerID = .make(),
        name: String? = nil,
        number: String? = nil,
        placeholder: String? = nil,
        bats: BattingSide? = nil,
        throwsWith: Hand? = nil,
        walkUpSongID: SongID? = nil,
        introduction: AnnouncerIntroduction? = nil
    ) {
        self.id = id
        self.name = name
        self.number = number
        self.placeholder = placeholder
        self.bats = bats
        self.throwsWith = throwsWith
        self.walkUpSongID = walkUpSongID
        self.introduction = introduction
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
    }

    public var source: Source
    /// The sound file's name inside the app's audio folder. Missing for `phoneVoice`.
    public var fileName: String?

    public init(source: Source, fileName: String? = nil) {
        self.source = source
        self.fileName = fileName
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

    public init(id: TeamID = .make(), name: String, isOurs: Bool = false, roster: [Player] = []) {
        self.id = id
        self.name = name
        self.isOurs = isOurs
        self.roster = roster
    }

    /// Finds a player on this team by id.
    public func player(_ id: PlayerID) -> Player? {
        roster.first { $0.id == id }
    }
}

/// One song in the walk-up song library.
public struct Song: Identifiable, Codable, Equatable, Hashable, Sendable {
    public var id: SongID
    /// The name shown in the app. Starts as the file name; the scorer can rename it.
    public var title: String
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
        duration: TimeInterval? = nil
    ) {
        self.id = id
        self.title = title
        self.fileName = fileName
        self.startTime = startTime
        self.playLength = playLength
        self.volume = volume
        self.duration = duration
    }
}

/// Every imported song, plus the between-innings playlist and the announcer echo setting.
/// Saved as `songs/library.json`.
public struct SongLibrary: Codable, Equatable, Hashable, Sendable {
    public var songs: [Song]
    /// Songs for the changeover between half-innings, in playing order.
    public var betweenInningsPlaylist: [SongID]
    /// Play the between-innings playlist in random order.
    public var shufflePlaylist: Bool
    /// How much stadium echo to add to recorded introductions, from 0 (none) to 1 (lots).
    public var announcerEcho: Double

    public init(
        songs: [Song] = [],
        betweenInningsPlaylist: [SongID] = [],
        shufflePlaylist: Bool = false,
        announcerEcho: Double = 0.5
    ) {
        self.songs = songs
        self.betweenInningsPlaylist = betweenInningsPlaylist
        self.shufflePlaylist = shufflePlaylist
        self.announcerEcho = announcerEcho
    }

    /// Finds a song by id.
    public func song(_ id: SongID) -> Song? {
        songs.first { $0.id == id }
    }
}
