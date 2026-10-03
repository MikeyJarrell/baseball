// Walk-up audio's promise: what the WalkUpAudio module provides to the rest of the app.
//
// Almost everything here runs on the main thread (marked `@MainActor`), the same thread
// that draws the screen, so the play button and the player always agree about what is
// playing. Copying files in is the exception: it runs in the background (marked
// `@concurrent`) so a long song or a slow iCloud download never freezes the screen.
// The silent stand-in at the bottom is for previews and tests.

import Foundation
import Observation

/// Plays walk-up songs, announcer introductions and pitchers' warm-up songs, and manages
/// the song library.
///
/// The player keeps the library it was given. Whenever it changes (new songs added, a new
/// start point), the app reads `library` back and saves it through storage.
///
/// The player is `Observable`: a screen that shows `isPlaying` or `nowPlaying` redraws by
/// itself when they change, including when a clip fades out on its own after its play length
/// or the speaker disconnects. `onPlaybackEnded` tells the app the same thing in code.
@MainActor
public protocol WalkUpAudioPlayer: AnyObject, Observable {
    /// The song library as the player has it now.
    var library: SongLibrary { get }
    /// True while a song, introduction or warm-up song is playing.
    var isPlaying: Bool { get }
    /// The song playing now, if any.
    var nowPlaying: SongID? { get }
    /// Seconds into the playing track, for setting a start point by listening.
    var playbackPosition: TimeInterval? { get }
    /// Called whenever something stops playing for any reason (stopped, faded, reached its
    /// play length, the end of the track, an interruption), with the song that was playing.
    var onPlaybackEnded: ((SongID?) -> Void)? { get set }

    /// Hands the player the saved library when the app opens.
    func load(_ library: SongLibrary)

    // Library

    /// Copies sound files the scorer picked into the app's audio folder, in the background,
    /// and returns a new song for each, named after its file. It does not touch the library;
    /// hand the songs to `addSongs` afterward.
    @concurrent nonisolated func importSongs(from files: [URL]) async throws -> [Song]
    /// Adds imported songs to the library.
    func addSongs(_ songs: [Song])
    func rename(_ song: SongID, to title: String)
    /// Sets where the walk-up clip starts, in seconds into the track.
    func setStartPoint(_ seconds: TimeInterval, for song: SongID)
    /// Sets how long this song plays before fading out by itself. Missing means the usual
    /// walk-up length (`walkUpLength`).
    func setPlayLength(_ seconds: TimeInterval?, for song: SongID)
    /// Seconds of song a walk-up plays before fading out by itself, counted from when the song
    /// starts (after any announcer introduction). The app sets it from
    /// `AppSettings.walkUpSongSeconds`. A tap on the song button stops it sooner.
    var walkUpLength: TimeInterval { get set }
    /// Sets the song's loudness, 0 to 1.
    func setVolume(_ volume: Double, for song: SongID)
    /// Sets how much stadium echo recorded introductions get, 0 to 1.
    func setAnnouncerEcho(_ amount: Double)

    // Walk-up songs

    /// Loads a player's song (and introduction) ahead of time so the play button starts instantly.
    func cue(for player: Player)
    /// Plays a player's walk-up song from its start point, with their announcer introduction
    /// first when `withIntroduction` is true and they have one. The song fades out by itself
    /// after `walkUpLength` seconds (or the song's own play length).
    func playWalkUp(for player: Player, withIntroduction: Bool)
    /// Plays any song from a given point, for previewing in the song library.
    func playPreview(_ song: SongID, from seconds: TimeInterval)
    /// Fades out whatever is playing over about two seconds.
    func fadeOut()
    /// Stops whatever is playing at once.
    func stop()

    // Pitcher warm-ups

    /// Plays our pitcher's warm-up song while our team takes the field. It plays until stopped
    /// or faded; the app fades it when the first pitch of the half-inning is recorded. Nothing
    /// plays for the other team's warm-ups.
    func playWarmUp(for pitcher: Player)

    // Announcer introductions

    /// Starts recording an introduction with the phone's microphone.
    func startRecordingIntroduction() throws
    /// Stops recording and returns the new introduction, ready to keep or throw away.
    func stopRecordingIntroduction() -> AnnouncerIntroduction?
    /// Copies an introduction recorded elsewhere into the app, in the background.
    @concurrent nonisolated func importIntroduction(from file: URL) async throws -> AnnouncerIntroduction
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
@Observable
public final class SilentAudioPlayer: WalkUpAudioPlayer {
    public private(set) var library: SongLibrary
    public private(set) var isPlaying = false
    public private(set) var nowPlaying: SongID?
    public private(set) var playbackPosition: TimeInterval?
    public var onPlaybackEnded: ((SongID?) -> Void)?
    public var walkUpLength: TimeInterval = 12

    public init(library: SongLibrary = SongLibrary()) {
        self.library = library
    }

    public func load(_ library: SongLibrary) { self.library = library }

    @concurrent nonisolated public func importSongs(from files: [URL]) async throws -> [Song] {
        files.map { Song(title: $0.deletingPathExtension().lastPathComponent, fileName: $0.lastPathComponent) }
    }

    public func addSongs(_ songs: [Song]) { library.songs.append(contentsOf: songs) }

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
        let ended = nowPlaying
        isPlaying = false
        nowPlaying = nil
        playbackPosition = nil
        onPlaybackEnded?(ended)
    }

    public func playWarmUp(for pitcher: Player) {
        nowPlaying = pitcher.warmUpSongID
        isPlaying = nowPlaying != nil
    }

    public func startRecordingIntroduction() throws {}

    public func stopRecordingIntroduction() -> AnnouncerIntroduction? { nil }

    @concurrent nonisolated public func importIntroduction(from file: URL) async throws -> AnnouncerIntroduction {
        AnnouncerIntroduction(source: .imported, fileName: file.lastPathComponent)
    }

    public func playIntroduction(for player: Player) {}

    /// Changes one song in the library.
    private func update(_ id: SongID, _ change: (inout Song) -> Void) {
        guard let i = library.songs.firstIndex(where: { $0.id == id }) else { return }
        change(&library.songs[i])
    }
}
