// Walk-up audio's promise: what the WalkUpAudio module provides to the rest of the app.
//
// Everything here runs on the main thread (marked `@MainActor`), the same thread that
// draws the screen, so the play button and the player always agree about what is playing.
// The silent stand-in at the bottom is for previews and tests.

import Foundation

/// Plays walk-up songs, announcer introductions and between-innings music, and manages
/// the song library.
///
/// The player keeps the library it was given. Whenever it changes (an import, a new start
/// point), the app reads `library` back and saves it through storage.
@MainActor
public protocol WalkUpAudioPlayer: AnyObject {
    /// The song library as the player has it now.
    var library: SongLibrary { get }
    /// True while a song, introduction or between-innings track is playing.
    var isPlaying: Bool { get }
    /// The song playing now, if any.
    var nowPlaying: SongID? { get }
    /// Seconds into the playing track, for setting a start point by listening.
    var playbackPosition: TimeInterval? { get }

    /// Hands the player the saved library when the app opens.
    func load(_ library: SongLibrary)

    // Library

    /// Copies sound files the scorer picked into the app and adds them to the library,
    /// named after their files. Returns the new songs.
    func importSongs(from files: [URL]) async throws -> [Song]
    func rename(_ song: SongID, to title: String)
    /// Sets where the walk-up clip starts, in seconds into the track.
    func setStartPoint(_ seconds: TimeInterval, for song: SongID)
    /// Sets how long the clip plays before fading out by itself. Missing means until stopped.
    func setPlayLength(_ seconds: TimeInterval?, for song: SongID)
    /// Sets the song's loudness, 0 to 1.
    func setVolume(_ volume: Double, for song: SongID)
    func setBetweenInningsPlaylist(_ songs: [SongID], shuffle: Bool)
    /// Sets how much stadium echo recorded introductions get, 0 to 1.
    func setAnnouncerEcho(_ amount: Double)

    // Walk-up songs

    /// Loads a player's song (and introduction) ahead of time so the play button starts instantly.
    func cue(for player: Player)
    /// Plays a player's walk-up song from its start point, with their announcer introduction
    /// first when `withIntroduction` is true and they have one.
    func playWalkUp(for player: Player, withIntroduction: Bool)
    /// Plays any song from a given point, for previewing in the song library.
    func playPreview(_ song: SongID, from seconds: TimeInterval)
    /// Fades out whatever is playing over about two seconds.
    func fadeOut()
    /// Stops whatever is playing at once.
    func stop()

    // Between innings

    /// Starts the between-innings playlist.
    func playBetweenInnings()

    // Announcer introductions

    /// Starts recording an introduction with the phone's microphone.
    func startRecordingIntroduction() throws
    /// Stops recording and returns the new introduction, ready to keep or throw away.
    func stopRecordingIntroduction() -> AnnouncerIntroduction?
    /// Imports an introduction recorded elsewhere.
    func importIntroduction(from file: URL) async throws -> AnnouncerIntroduction
    /// Plays a player's introduction on its own, to check it.
    func playIntroduction(for player: Player)
}

/// What can go wrong with audio, in words the scorer can act on.
public enum WalkUpAudioError: Error, Equatable, Sendable {
    /// A file could not be copied into the app.
    case cannotImport(fileName: String, reason: String)
    /// The file is copy-protected, such as a song bought or streamed through Apple Music.
    case copyProtected(fileName: String)
    /// The scorer has not allowed the app to use the microphone.
    case microphoneNotAllowed
}

/// An audio player that makes no sound but keeps track of what it was asked to do.
/// For previews and tests.
@MainActor
public final class SilentAudioPlayer: WalkUpAudioPlayer {
    public private(set) var library: SongLibrary
    public private(set) var isPlaying = false
    public private(set) var nowPlaying: SongID?
    public private(set) var playbackPosition: TimeInterval?

    public init(library: SongLibrary = SongLibrary()) {
        self.library = library
    }

    public func load(_ library: SongLibrary) { self.library = library }

    public func importSongs(from files: [URL]) async throws -> [Song] {
        let new = files.map { Song(title: $0.deletingPathExtension().lastPathComponent, fileName: $0.lastPathComponent) }
        library.songs.append(contentsOf: new)
        return new
    }

    public func rename(_ song: SongID, to title: String) {
        update(song) { $0.title = title }
    }

    public func setStartPoint(_ seconds: TimeInterval, for song: SongID) {
        update(song) { $0.startTime = seconds }
    }

    public func setPlayLength(_ seconds: TimeInterval?, for song: SongID) {
        update(song) { $0.playLength = seconds }
    }

    public func setVolume(_ volume: Double, for song: SongID) {
        update(song) { $0.volume = volume }
    }

    public func setBetweenInningsPlaylist(_ songs: [SongID], shuffle: Bool) {
        library.betweenInningsPlaylist = songs
        library.shufflePlaylist = shuffle
    }

    public func setAnnouncerEcho(_ amount: Double) { library.announcerEcho = amount }

    public func cue(for player: Player) {}

    public func playWalkUp(for player: Player, withIntroduction: Bool) {
        guard let song = player.walkUpSongID else { return }
        nowPlaying = song
        isPlaying = true
        playbackPosition = library.song(song)?.startTime ?? 0
    }

    public func playPreview(_ song: SongID, from seconds: TimeInterval) {
        nowPlaying = song
        isPlaying = true
        playbackPosition = seconds
    }

    public func fadeOut() { stop() }

    public func stop() {
        isPlaying = false
        nowPlaying = nil
        playbackPosition = nil
    }

    public func playBetweenInnings() {
        nowPlaying = library.betweenInningsPlaylist.first
        isPlaying = nowPlaying != nil
    }

    public func startRecordingIntroduction() throws {}

    public func stopRecordingIntroduction() -> AnnouncerIntroduction? { nil }

    public func importIntroduction(from file: URL) async throws -> AnnouncerIntroduction {
        AnnouncerIntroduction(source: .imported, fileName: file.lastPathComponent)
    }

    public func playIntroduction(for player: Player) {}

    /// Changes one song in the library.
    private func update(_ id: SongID, _ change: (inout Song) -> Void) {
        guard let i = library.songs.firstIndex(where: { $0.id == id }) else { return }
        change(&library.songs[i])
    }
}
