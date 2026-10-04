// The real walk-up audio player: the version of Model's `WalkUpAudioPlayer` promise that
// actually makes sound.
//
// What it does, in game terms:
// - When our hitter comes up, one tap plays their announcer introduction (if they have one)
//   and then their walk-up song from its start point. The song fades out by itself after
//   12 seconds of song (the walk-up length setting), or sooner when the button is tapped
//   again, with a fade of about two seconds.
// - When our team takes the field, it plays the pitcher's warm-up song over and over until
//   it is stopped or the first pitch is recorded, and fades by itself after five minutes in
//   case nobody stops it.
// - It keeps the song library: imports, names, start points, loudness, the announcer echo.
//
// How it behaves on the phone:
// - It plays with the silent switch on, with the screen locked, and through a Bluetooth
//   speaker, and it takes over from any other music the phone is playing (the “playback”
//   audio session, plus the background-audio setting the app shell switches on).
// - A phone call or Siri stops the music; afterward the player is ready to play again.
// - If the Bluetooth speaker disconnects mid-song, the song stops at once, so it does not
//   carry on through the phone's own speaker.
// - If the iPhone switches speakers some other way mid-song (a speaker connecting, or the
//   phone changing its sound settings for a new speaker), the song picks up where it was.
//   If that fails, it stops with the message “The speaker changed. Tap again.”
// - `cue(for:)` loads the next batter's song and introduction ahead of time, so the play
//   button starts instantly.
//
// Everything here runs on the main thread, the same thread that draws the screen, so the
// button and the player always agree. Only copying files in runs in the background.

import AVFoundation
import Foundation
import Model
import Observation

/// Plays walk-up songs, announcer introductions and pitchers' warm-up songs, and keeps the
/// song library. Make one for the whole app and share it.
@MainActor
@Observable
public final class StadiumAudioPlayer: WalkUpAudioPlayer {

    // MARK: - What screens watch

    public private(set) var library: SongLibrary
    /// True while a song, introduction or warm-up song is playing, fade included.
    public private(set) var isPlaying = false
    /// The song playing now (during a walk-up's introduction too), if any.
    public private(set) var nowPlaying: SongID?
    /// Seconds into the playing track, for setting a start point by listening. During a
    /// walk-up's introduction it is the song's start point.
    public private(set) var playbackPosition: TimeInterval?
    /// Seconds until a walk-up goes quiet by itself, for the countdown on the song button:
    /// the rest of the introduction plus the song's walk-up length, or the rest of the fade
    /// once one has started. Missing when nothing is playing, and for previews and warm-ups,
    /// which play until stopped.
    public private(set) var timeLeft: TimeInterval?
    /// True while the announcer introduction is playing, before the song starts.
    public private(set) var isPlayingIntroduction = false
    /// True while the music is fading out.
    public private(set) var isFadingOut = false
    /// What is playing: a walk-up, a preview in the song library, a warm-up song, or an
    /// introduction on its own.
    public private(set) var activity: Activity = .idle
    /// True while the microphone is recording an introduction.
    public private(set) var isRecording = false
    /// Seconds recorded so far, for a timer on the record button.
    public private(set) var recordingSeconds: TimeInterval = 0
    /// A finished recording waiting to be collected with `stopRecordingIntroduction()`, when
    /// the recording ended by itself: it reached 30 seconds, or a call or Siri cut it off.
    /// The record screen should watch this and offer “listen, keep or redo” when it appears.
    public private(set) var pendingRecording: AnnouncerIntroduction?
    /// How loud the sound coming out is right now, 0 (silence) to about 1. For a level meter.
    public private(set) var outputLevel: Double = 0
    /// The latest thing to tell the scorer, such as a song file that is missing or a
    /// recording that stopped at its limit. Cleared when something new starts playing.
    public private(set) var lastProblem: String?

    /// Called whenever something stops playing for any reason, with the song that was playing.
    @ObservationIgnored public var onPlaybackEnded: ((SongID?) -> Void)?
    /// Called whenever the library changes (songs added, renamed, a new start point or
    /// loudness, the echo setting), so the app can save it through storage.
    @ObservationIgnored public var onLibraryChanged: ((SongLibrary) -> Void)?

    /// Seconds of song a walk-up plays before it has faded out completely, counted from when
    /// the song starts (after any introduction). The fade takes the last two of those seconds.
    /// The app sets it from `AppSettings.walkUpSongSeconds`; a song's own play length wins.
    public var walkUpLength: TimeInterval = 12
    /// How long a fade takes, in seconds.
    public var fadeLength: TimeInterval = 2
    /// The longest a warm-up song plays before fading by itself, in seconds: five minutes,
    /// in case the first pitch is never recorded and nobody taps stop.
    public var longestWarmUp: TimeInterval = 300
    /// The longest an introduction may be, recorded or imported, in seconds.
    public nonisolated static let longestIntroduction: TimeInterval = 30

    /// The folder holding the song and introduction files: storage's `songs/audio/` folder.
    public nonisolated let audioFolder: URL

    /// What the player is doing.
    public enum Activity: Equatable, Sendable {
        case idle
        /// A batter's walk-up: introduction (maybe) then song, fading by itself.
        case walkUp
        /// A song played from any point in the song library, until stopped or the track ends.
        case preview
        /// A pitcher's warm-up song, repeating until stopped.
        case warmUp
        /// An announcer introduction on its own, to check it.
        case introduction
    }

    // MARK: - Behind the scenes

    /// The audio engine and its pieces.
    @ObservationIgnored private var graph = AudioGraph()
    /// Makes the phone-voice introductions.
    private let voice = AnnouncerVoice()
    /// Song files already opened, so the play button does not wait for the disk.
    @ObservationIgnored private var openFiles: [String: AVAudioFile] = [:]
    /// Introductions already turned into sound, by player, so they start instantly.
    @ObservationIgnored private var readyIntroductions: [PlayerID: ReadyIntroduction] = [:]
    /// Introductions being made right now, by player, so a tap during `cue` waits for the
    /// same job instead of starting a second one.
    @ObservationIgnored private var introductionJobs: [PlayerID: IntroductionJob] = [:]
    /// Goes up by one every time something new starts or stops. A message from the audio
    /// system about an older play carries an older number and is ignored.
    @ObservationIgnored private var playNumber = 0
    /// The 20-times-a-second heartbeat that runs fades and updates the countdown.
    @ObservationIgnored private var ticker: Task<Void, Never>?
    /// The current play's timing, in seconds on the phone's audio clock.
    @ObservationIgnored private var timing = Timing()
    /// What the current play is made of, so it can be picked up again after a speaker change.
    @ObservationIgnored private var currentSong: Song?
    @ObservationIgnored private var currentIntroduction: AVAudioPCMBuffer?
    /// When the current play began, on the audio clock (for the warm-up time limit).
    @ObservationIgnored private var playStartedAt: Double?
    /// How many times the current play has been picked up again after a speaker change.
    @ObservationIgnored private var restartsThisPlay = 0
    /// The microphone recorder, while recording.
    @ObservationIgnored private var recorder: AVAudioRecorder?
    /// The listeners for phone calls, speaker changes and audio resets.
    @ObservationIgnored private var listeners: [NSObjectProtocol] = []

    /// What the scorer sees when a speaker change stops a song that could not be picked up.
    private static let speakerChangedMessage = "The speaker changed. Tap again."

    /// A ready-to-play introduction, and what it was made from (so a renamed player or a new
    /// recording makes a fresh one).
    private struct ReadyIntroduction {
        var madeFrom: IntroductionRecipe
        var sound: AVAudioPCMBuffer
    }

    /// An introduction being made, and what it is being made from.
    private struct IntroductionJob {
        var madeFrom: IntroductionRecipe
        var task: Task<SoundBox, Never>
    }

    /// Everything that decides how an introduction sounds.
    private struct IntroductionRecipe: Equatable {
        var introduction: AnnouncerIntroduction
        var name: String?
        var number: String?
    }

    /// When the parts of the current play start and stop, on the audio clock.
    private struct Timing {
        /// When the song part starts (after any introduction).
        var songStart: Double?
        /// Seconds into the track where the song starts.
        var songOffset: TimeInterval = 0
        /// Seconds of song before it goes quiet by itself; missing means until stopped.
        var songLength: TimeInterval?
        /// For repeating warm-ups: the length of the first pass (from the offset to the end of
        /// the track), and where each later pass begins and how long it lasts.
        var firstPass: TimeInterval?
        var loopStart: TimeInterval = 0
        var loopLength: TimeInterval?
        /// When the introduction finishes.
        var introductionEnd: Double?
        /// When an introduction played on its own, echo tail included, is over.
        var introductionOnlyEnd: Double?
        /// When the current fade started, how long it lasts, and the volume it started from.
        var fadeStart: Double?
        var fadeSeconds: TimeInterval = 2
        var fadeFrom: Float = 1
    }

    /// Makes the player.
    /// - Parameters:
    ///   - audioFolder: where song and introduction files live: storage's `audioFolder`.
    ///   - library: the saved song library, if already loaded.
    public init(audioFolder: URL, library: SongLibrary = SongLibrary()) {
        self.audioFolder = audioFolder
        self.library = library
        graph.setEcho(library.announcerEcho)
        try? FileManager.default.createDirectory(at: audioFolder, withIntermediateDirectories: true)
        AudioSessionSettings.usePlayback()
        listenForInterruptions()
        voice.findVoice()   // in the background, so the first introduction is not delayed
    }

    /// A player for previews and the test screen, keeping its files in a temporary folder.
    public static func forPreviews() -> StadiumAudioPlayer {
        let folder = FileManager.default.temporaryDirectory.appending(path: "WalkUpAudioPreview/audio")
        return StadiumAudioPlayer(audioFolder: folder)
    }

    public func load(_ library: SongLibrary) {
        self.library = library
        graph.setEcho(library.announcerEcho)
        openFiles.removeAll()
    }

    // MARK: - Library

    @concurrent nonisolated public func importSongs(from files: [URL]) async throws -> [Song] {
        let report = await importSongsWithReport(from: files)
        // Some files came in: hand them back, and let the report version tell the scorer
        // about the rest. Nothing came in: say why.
        if report.songs.isEmpty, let first = report.problems.first { throw first }
        return report.songs
    }

    /// Like `importSongs`, but reports every file that could not be copied alongside the
    /// songs that were, so one bad file among ten does not hide the other nine. Prefer this.
    @concurrent nonisolated public func importSongsWithReport(from files: [URL]) async -> SongImportReport {
        var report = SongImportReport()
        for file in files {
            do {
                let copy = try await SoundFileImporter.copyIn(file, to: audioFolder)
                let title = file.deletingPathExtension().lastPathComponent
                report.songs.append(Song(title: title, fileName: copy.fileName, duration: copy.duration))
            } catch {
                report.problems.append(error)
            }
        }
        return report
    }

    public func addSongs(_ songs: [Song]) {
        let known = Set(library.songs.map(\.id))
        changeLibrary { $0.songs.append(contentsOf: songs.filter { !known.contains($0.id) }) }
    }

    public func rename(_ song: SongID, to title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        changeSong(song) { $0.title = trimmed }
    }

    public func setStartPoint(_ seconds: TimeInterval, for song: SongID) {
        changeSong(song) { song in
            var start = max(0, seconds)
            // Keep at least a second of song after the start point.
            if let duration = song.duration { start = min(start, max(0, duration - 1)) }
            song.startTime = start
        }
    }

    public func setPlayLength(_ seconds: TimeInterval?, for song: SongID) {
        changeSong(song) { $0.playLength = seconds.map { max(1, $0) } }
    }

    public func setVolume(_ volume: Double, for song: SongID) {
        let level = min(max(volume, 0), 1)
        changeSong(song) { $0.volume = level }
        // Turn it up or down right away if it is the song playing now.
        if nowPlaying == song, activity != .introduction { graph.songNode.volume = Float(level) }
    }

    public func setAnnouncerEcho(_ amount: Double) {
        let level = min(max(amount, 0), 1)
        changeLibrary { $0.announcerEcho = level }
        graph.setEcho(level)
    }

    // MARK: - Walk-up songs

    public func cue(for player: Player) {
        if let id = player.walkUpSongID, let song = library.song(id) {
            _ = openFile(for: song)
        }
        if player.introduction != nil {
            Task { _ = await introductionSound(for: player) }
        }
        graph.engine.prepare()
    }

    public func playWalkUp(for player: Player, withIntroduction: Bool) {
        stopAtOnce()   // a new song stops the current one
        let song = player.walkUpSongID.flatMap { library.song($0) }
        // The player has a song, but it is no longer in the library (deleted or never saved).
        let songMissing = player.walkUpSongID != nil && song == nil
        let missingMessage = "\(player.displayName)'s walk-up song is no longer in the song library. Pick a song for them again."
        let wantsIntroduction = withIntroduction && player.introduction != nil
        guard song != nil || wantsIntroduction else {
            if songMissing { lastProblem = missingMessage }
            return
        }

        // The introduction is usually ready already (cued). If not, show the button as
        // playing straight away and start as soon as it is made, but wait no more than
        // three seconds: after that the song plays on its own, so the button never sits
        // silent. The introduction carries on being made, ready for next time.
        if wantsIntroduction, readyIntroduction(for: player) == nil {
            let number = beginPlay(.walkUp, song: song)
            if songMissing { lastProblem = missingMessage }
            Task {
                let introduction = await introductionSound(for: player, waitingAtMost: 3)
                guard number == playNumber else { return }   // stopped or replaced meanwhile
                if introduction == nil, lastProblem == nil, song != nil {
                    lastProblem = "The introduction was not ready, so the song played without it."
                }
                startWalkUp(song: song, introduction: introduction)
            }
            return
        }
        beginPlay(.walkUp, song: song)
        if songMissing { lastProblem = missingMessage }
        startWalkUp(song: song, introduction: wantsIntroduction ? readyIntroduction(for: player) : nil)
    }

    public func playPreview(_ song: SongID, from seconds: TimeInterval) {
        stopAtOnce()
        guard let song = library.song(song) else { return }
        beginPlay(.preview, song: song)
        startSong(song, from: seconds, length: nil, repeating: false)
    }

    public func fadeOut() {
        guard isPlaying, !isFadingOut else { return }
        beginFade(over: fadeLength)
    }

    public func stop() {
        guard isPlaying else { return }
        finish()
    }

    // MARK: - Pitcher warm-ups

    public func playWarmUp(for pitcher: Player) {
        stopAtOnce()
        guard let id = pitcher.warmUpSongID else { return }
        guard let song = library.song(id) else {
            lastProblem = "\(pitcher.displayName)'s warm-up song is no longer in the song library. Pick a song for them again."
            return
        }
        beginPlay(.warmUp, song: song)
        startSong(song, from: song.startTime, length: nil, repeating: true)
    }

    // MARK: - Announcer introductions

    /// Asks the scorer for permission to use the microphone, if they have not been asked
    /// yet. Call it before `startRecordingIntroduction`. Returns true when allowed.
    public func requestMicrophoneAccess() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    public func startRecordingIntroduction() throws {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            break
        case .undetermined:
            // iOS is about to ask the scorer for the first time; they tap record again after
            // answering. (Better: call `requestMicrophoneAccess()` first.)
            Task { _ = await AVAudioApplication.requestRecordPermission() }
            throw RecordingProblem.askingForPermission
        default:
            throw WalkUpAudioError.microphoneNotAllowed
        }
        // A take still recording, or finished but never collected, is replaced by this one.
        if recorder != nil { finishRecording(note: nil) }
        if let old = pendingRecording {
            discardIntroduction(old)
            pendingRecording = nil
        }
        stopAtOnce()   // nothing plays while recording

        let file = audioFolder.appending(path: "intro-\(UUID().uuidString).m4a")
        do {
            try AudioSessionSettings.useRecording()
            try FileManager.default.createDirectory(at: audioFolder, withIntermediateDirectories: true)
            // A good-quality, one-channel compressed recording: plenty for a voice.
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            ]
            let recorder = try AVAudioRecorder(url: file, settings: settings)
            guard recorder.record(forDuration: Self.longestIntroduction) else {
                throw RecordingProblem.couldNotStart("The microphone did not start.")
            }
            self.recorder = recorder
        } catch {
            // Back to ordinary playback, so the next song plays normally and other apps'
            // music can resume.
            AudioSessionSettings.usePlayback()
            AudioSessionSettings.deactivate()
            try? FileManager.default.removeItem(at: file)
            if let problem = error as? RecordingProblem { throw problem }
            throw RecordingProblem.couldNotStart(error.localizedDescription)
        }
        isRecording = true
        recordingSeconds = 0
        lastProblem = nil
        startTicker()
    }

    public func stopRecordingIntroduction() -> AnnouncerIntroduction? {
        finishRecording(note: nil)
        defer { pendingRecording = nil }
        return pendingRecording
    }

    /// Ends the recording, however it ended: switches the phone back to ordinary playback,
    /// and keeps the take in `pendingRecording` if it is at least half a second long
    /// (otherwise deletes its file). `note` is shown to the scorer, for takes that ended by
    /// themselves.
    private func finishRecording(note: String?) {
        guard let recorder else { return }
        recorder.stop()
        self.recorder = nil
        isRecording = false
        AudioSessionSettings.usePlayback()
        AudioSessionSettings.deactivate()
        if !isPlaying { stopTicker() }

        let file = recorder.url
        let seconds = (try? AVAudioFile(forReading: file)).map { Double($0.length) / $0.processingFormat.sampleRate } ?? 0
        if seconds >= 0.5 {
            pendingRecording = AnnouncerIntroduction(source: .recorded, fileName: file.lastPathComponent)
            if let note { lastProblem = note }
        } else {
            try? FileManager.default.removeItem(at: file)
            pendingRecording = nil
            if note != nil { lastProblem = "The recording was cut off before anything was recorded. Try again." }
        }
    }

    /// Throws away an introduction the scorer did not keep (“redo”), or one being replaced,
    /// deleting its sound file. The phone voice has no file, so nothing happens for it.
    public func discardIntroduction(_ introduction: AnnouncerIntroduction) {
        guard introduction.source != .phoneVoice, let name = introduction.fileName else { return }
        try? FileManager.default.removeItem(at: audioFolder.appending(path: name))
        readyIntroductions = readyIntroductions.filter { $0.value.madeFrom.introduction != introduction }
        if pendingRecording == introduction { pendingRecording = nil }
    }

    @concurrent nonisolated public func importIntroduction(from file: URL) async throws -> AnnouncerIntroduction {
        let copy = try await SoundFileImporter.copyIn(file, to: audioFolder, prefix: "intro-")
        // An introduction is a few seconds of announcer; a whole song picked by mistake would
        // take a lot of memory and play for minutes before the walk-up song.
        guard copy.duration <= Self.longestIntroduction else {
            try? FileManager.default.removeItem(at: audioFolder.appending(path: copy.fileName))
            throw WalkUpAudioError.cannotImport(
                fileName: file.lastPathComponent,
                reason: "It is \(Int(copy.duration.rounded())) seconds long, and an introduction can be at most \(Int(Self.longestIntroduction)) seconds. Pick the announcer recording, not a song."
            )
        }
        return AnnouncerIntroduction(source: .imported, fileName: copy.fileName)
    }

    /// Plays a player's introduction on its own, to check it. To listen to a new recording
    /// before keeping it, pass a copy of the player with the new introduction set.
    public func playIntroduction(for player: Player) {
        stopAtOnce()
        guard player.introduction != nil else { return }
        let number = beginPlay(.introduction, song: nil)
        if let ready = readyIntroduction(for: player) {
            startIntroductionOnly(ready)
        } else {
            Task {
                let sound = await introductionSound(for: player, waitingAtMost: 10)
                guard number == playNumber else { return }
                if let sound {
                    startIntroductionOnly(sound)
                } else {
                    if lastProblem == nil { lastProblem = "The introduction was not ready. Try again in a moment." }
                    finish()
                }
            }
        }
    }

    // MARK: - Starting sound

    /// Marks the start of something new: the button shows playing at once.
    @discardableResult
    private func beginPlay(_ kind: Activity, song: Song?) -> Int {
        playNumber += 1
        activity = kind
        currentSong = song
        currentIntroduction = nil
        nowPlaying = song?.id
        isPlaying = true
        isFadingOut = false
        lastProblem = nil
        timing = Timing()
        playStartedAt = Self.audioClockNow()
        restartsThisPlay = 0
        if let song { playbackPosition = song.startTime }
        return playNumber
    }

    /// Plays the introduction, then the song right after it, timed to the sample.
    private func startWalkUp(song: Song?, introduction: AVAudioPCMBuffer?) {
        currentIntroduction = introduction
        let file = song.flatMap { openFile(for: $0) }
        // Nothing to play: the song file is missing and there is no introduction.
        if file == nil, introduction == nil { finish(); return }
        guard startEngine() else { return }

        // Start a twentieth of a second from now, so the introduction and the song share
        // one clock reading.
        let begin = Self.audioClockNow() + 0.05
        var songStart = begin
        if let introduction {
            graph.connectIntroPlayer(format: introduction.format)
            graph.introNode.scheduleBuffer(introduction, at: nil, options: [], completionCallbackType: .dataPlayedBack) { @Sendable _ in }
            graph.introNode.play(at: AVAudioTime(hostTime: AVAudioTime.hostTime(forSeconds: begin)))
            let seconds = Double(introduction.frameLength) / introduction.format.sampleRate
            timing.introductionEnd = begin + seconds
            isPlayingIntroduction = true
            // A short breath after “Number two.” before the music hits.
            songStart = begin + seconds + 0.3
        }
        if let song, let file {
            let length = song.playLength ?? walkUpLength
            scheduleSong(song, file: file, from: song.startTime, length: length, repeating: false,
                         startingAt: songStart)
            graph.songNode.play(at: AVAudioTime(hostTime: AVAudioTime.hostTime(forSeconds: songStart)))
        } else {
            // An introduction with no song: done once the echo dies away.
            timing.introductionOnlyEnd = (timing.introductionEnd ?? begin) + 1.5
        }
        startTicker()
    }

    /// Plays an introduction with no song after it.
    private func startIntroductionOnly(_ sound: AVAudioPCMBuffer) {
        currentIntroduction = sound
        guard startEngine() else { return }
        let begin = Self.audioClockNow() + 0.05
        graph.connectIntroPlayer(format: sound.format)
        graph.introNode.scheduleBuffer(sound, at: nil, options: [], completionCallbackType: .dataPlayedBack) { @Sendable _ in }
        graph.introNode.play(at: AVAudioTime(hostTime: AVAudioTime.hostTime(forSeconds: begin)))
        let seconds = Double(sound.frameLength) / sound.format.sampleRate
        timing.introductionEnd = begin + seconds
        timing.introductionOnlyEnd = begin + seconds + 1.5   // let the stadium echo ring out
        isPlayingIntroduction = true
        startTicker()
    }

    /// Plays part of a song straight away: a preview, a warm-up, or a song picked up again
    /// after a speaker change.
    private func startSong(_ song: Song, from seconds: TimeInterval, length: TimeInterval?, repeating: Bool,
                           failureMessage: String? = nil) {
        guard let file = openFile(for: song) else { finish(); return }
        guard startEngine(failureMessage: failureMessage) else { return }
        let start = scheduleSong(song, file: file, from: seconds, length: length, repeating: repeating)
        graph.songNode.play(at: AVAudioTime(hostTime: AVAudioTime.hostTime(forSeconds: start)))
        startTicker()
    }

    /// Lines up part of a song on the song player. Returns when the song will start on the
    /// audio clock.
    /// - Parameters:
    ///   - seconds: where in the track to start.
    ///   - length: seconds of song to play; missing plays to the end of the track.
    ///   - repeating: at the end of the track, go back to the song's start point and keep
    ///     going (warm-ups).
    ///   - startingAt: when it will start on the audio clock; missing means right away.
    @discardableResult
    private func scheduleSong(_ song: Song, file: AVAudioFile, from seconds: TimeInterval,
                              length: TimeInterval?, repeating: Bool, startingAt: Double? = nil) -> Double {
        let rate = file.processingFormat.sampleRate
        let startFrame = min(max(0, AVAudioFramePosition(seconds * rate)), max(0, file.length - 1))
        let available = AVAudioFrameCount(file.length - startFrame)
        let frames = length.map { min(AVAudioFrameCount($0 * rate), available) } ?? available
        let playSeconds = Double(frames) / rate

        graph.connectSongPlayer(format: file.processingFormat)
        graph.songNode.volume = Float(song.volume)
        graph.engine.mainMixerNode.outputVolume = 1

        let number = playNumber
        if repeating {
            // The first pass runs from here to the end of the track; each later pass from the
            // song's start point. One pass is always lined up ahead, so the loop has no gap.
            let loopFrame = min(max(0, AVAudioFramePosition(song.startTime * rate)), max(0, file.length - 1))
            let loopFrames = AVAudioFrameCount(file.length - loopFrame)
            queueWarmUpPass(file: file, startFrame: startFrame, frames: frames,
                            loopFrame: loopFrame, loopFrames: loopFrames, number: number)
            queueWarmUpPass(file: file, startFrame: loopFrame, frames: loopFrames,
                            loopFrame: loopFrame, loopFrames: loopFrames, number: number)
            timing.firstPass = playSeconds
            timing.loopStart = Double(loopFrame) / rate
            timing.loopLength = Double(loopFrames) / rate
        } else {
            // The audio system calls this from its own thread (`@Sendable`), so it hops back
            // to the main thread first. At the end of the track (or of the walk-up length),
            // finish, if this is still the current play.
            graph.songNode.scheduleSegment(file, startingFrame: startFrame, frameCount: frames, at: nil,
                                           completionCallbackType: .dataPlayedBack) { @Sendable [weak self] _ in
                Task { @MainActor in
                    guard let self, self.playNumber == number else { return }
                    self.finish()
                }
            }
        }

        let start = startingAt ?? (Self.audioClockNow() + 0.05)
        timing.songStart = start
        timing.songOffset = Double(startFrame) / rate
        timing.songLength = length.map { min($0, playSeconds) }
        return start
    }

    /// Lines up one pass through the warm-up song; when it has been read, lines up the next.
    private func queueWarmUpPass(file: AVAudioFile, startFrame: AVAudioFramePosition, frames: AVAudioFrameCount,
                                 loopFrame: AVAudioFramePosition, loopFrames: AVAudioFrameCount, number: Int) {
        graph.songNode.scheduleSegment(file, startingFrame: startFrame, frameCount: frames, at: nil,
                                       completionCallbackType: .dataConsumed) { @Sendable [weak self] _ in
            Task { @MainActor in
                guard let self, self.playNumber == number, self.activity == .warmUp else { return }
                self.queueWarmUpPass(file: file, startFrame: loopFrame, frames: loopFrames,
                                     loopFrame: loopFrame, loopFrames: loopFrames, number: number)
            }
        }
    }

    /// Switches the sound system on: claims the speaker (stopping other apps' music) and
    /// starts the engine. On failure, says why and stops.
    private func startEngine(failureMessage: String? = nil) -> Bool {
        do {
            try AudioSessionSettings.activate()
            if !graph.engine.isRunning { try graph.engine.start() }
            return true
        } catch {
            lastProblem = failureMessage
                ?? "The iPhone would not start playing sound (\(error.localizedDescription)). Try again."
            finish()
            return false
        }
    }

    // MARK: - Speaker changes

    /// The audio engine stopped by itself mid-play, which iOS does when the speaker changes
    /// (a speaker connecting, or the phone's sound settings changing to suit a new one).
    /// Wait a moment first: if the speaker was disconnected, that news arrives now and stops
    /// the song for good, which is what should happen.
    private func engineStoppedByItself() {
        // Only if sound had actually started. While a walk-up is still waiting for its
        // introduction to be made, nothing has started yet, and the start to come switches
        // the engine on by itself.
        let started = timing.songStart != nil || timing.introductionEnd != nil
        guard isPlaying, started, !graph.engine.isRunning else { return }
        let number = playNumber
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard number == playNumber, isPlaying else { return }
            pickUpAfterSpeakerChange()
        }
    }

    /// Starts the engine again and carries on from where the play was: a walk-up song from
    /// the same point with the same time left, a walk-up still in its introduction from the
    /// top, a warm-up or preview from the same point. Never ends silently: if it cannot, it
    /// stops with “The speaker changed. Tap again.”
    private func pickUpAfterSpeakerChange() {
        // Already fading: it was ending anyway.
        if isFadingOut { finish(); return }
        // Give up after two tries, rather than flickering on and off.
        guard restartsThisPlay < 2 else {
            lastProblem = Self.speakerChangedMessage
            finish()
            return
        }
        restartsThisPlay += 1

        let now = Self.audioClockNow()
        let old = timing
        let position = playbackPosition
        // Forget the old line-up: messages about it are ignored from here on.
        playNumber += 1
        graph.songNode.stop()
        graph.introNode.stop()
        graph.engine.mainMixerNode.outputVolume = 1
        timing = Timing()
        isPlayingIntroduction = false

        switch activity {
        case .walkUp:
            if let start = old.songStart, now >= start, let length = old.songLength, let song = currentSong {
                // In the song: carry on with the time that was left.
                let intoSong = now - start
                let left = length - intoSong
                guard left > 0.5 else { finish(); return }
                startSong(song, from: old.songOffset + intoSong, length: left, repeating: false,
                          failureMessage: Self.speakerChangedMessage)
            } else {
                // Still in the introduction: start the walk-up over.
                startWalkUp(song: currentSong, introduction: currentIntroduction)
            }
        case .preview, .warmUp:
            guard let song = currentSong else { finish(); return }
            startSong(song, from: position ?? song.startTime, length: nil, repeating: activity == .warmUp,
                      failureMessage: Self.speakerChangedMessage)
        case .introduction:
            if let sound = currentIntroduction { startIntroductionOnly(sound) } else { finish() }
        case .idle:
            return
        }
        // Whatever went wrong above, the scorer is told.
        if !isPlaying, lastProblem == nil { lastProblem = Self.speakerChangedMessage }
    }

    // MARK: - Fades, the countdown, and stopping

    /// Starts lowering the volume to silence over `seconds`.
    private func beginFade(over seconds: TimeInterval) {
        isFadingOut = true
        timing.fadeStart = Self.audioClockNow()
        timing.fadeSeconds = max(0.05, seconds)
        timing.fadeFrom = graph.engine.mainMixerNode.outputVolume
        startTicker()
    }

    /// Runs `tick` twenty times a second while something is playing or recording.
    private func startTicker() {
        guard ticker == nil else { return }
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                self?.tick()
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
    }

    private func stopTicker() {
        ticker?.cancel()
        ticker = nil
    }

    /// One heartbeat: move any fade along, start the automatic fade when a walk-up's or
    /// warm-up's time is nearly up, finish when it is over, and update the countdown,
    /// position and meter. Also notices a recording that stopped by itself.
    private func tick() {
        let now = Self.audioClockNow()
        setIfChanged(\.outputLevel, Double(graph.meter.current))

        if let recorder {
            setIfChanged(\.recordingSeconds, recorder.currentTime.rounded(toPlaces: 1))
            // It stops by itself at the longest allowed length: hand the take back.
            if !recorder.isRecording {
                finishRecording(note: "The recording stopped at the \(Int(Self.longestIntroduction))-second limit. Listen to it, then keep it or redo it.")
            }
        }
        guard isPlaying else {
            if recorder == nil { stopTicker() }
            return
        }

        // The introduction has finished and the song has begun.
        if isPlayingIntroduction, let end = timing.introductionEnd, now >= end {
            isPlayingIntroduction = false
        }

        // An introduction on its own (or with no song after it) is over once its echo fades.
        if let end = timing.introductionOnlyEnd, now >= end {
            finish()
            return
        }

        // A walk-up's automatic fade: it starts so that it ends exactly when the walk-up
        // length is up.
        if activity == .walkUp, !isFadingOut, let start = timing.songStart, let length = timing.songLength {
            let songSoFar = now - start
            let fade = min(fadeLength, length)
            if songSoFar >= length - fade {
                beginFade(over: max(0.05, length - songSoFar))
            }
        }

        // A warm-up nobody stopped: fade it after the longest warm-up time.
        if activity == .warmUp, !isFadingOut, let began = playStartedAt, now - began >= longestWarmUp - fadeLength {
            beginFade(over: fadeLength)
        }

        // Move the fade along. The volume follows a curve that drops gently at first and
        // faster at the end, which sounds smoother than a straight line.
        if isFadingOut, let fadeStart = timing.fadeStart {
            let progress = min(1, (now - fadeStart) / timing.fadeSeconds)
            let remaining = Float(1 - progress)
            graph.engine.mainMixerNode.outputVolume = timing.fadeFrom * remaining * remaining
            if progress >= 1 {
                finish()
                return
            }
        }

        // The countdown and the position in the track.
        setIfChanged(\.timeLeft, countdown(at: now)?.rounded(toPlaces: 1))
        if let start = timing.songStart, now >= start {
            setIfChanged(\.playbackPosition, trackPosition(intoSong: now - start).rounded(toPlaces: 1))
        }
    }

    /// Where in the track the song is, given how long it has been playing. A warm-up goes
    /// back to the start point each time it reaches the end.
    private func trackPosition(intoSong: TimeInterval) -> TimeInterval {
        guard activity == .warmUp, let first = timing.firstPass, let loop = timing.loopLength, loop > 0,
              intoSong >= first else {
            return timing.songOffset + intoSong
        }
        return timing.loopStart + (intoSong - first).truncatingRemainder(dividingBy: loop)
    }

    /// Seconds until the walk-up is silent: the rest of the fade once one has started,
    /// otherwise the rest of the introduction plus the song's length. Nothing for plays that
    /// go on until stopped.
    private func countdown(at now: Double) -> TimeInterval? {
        if isFadingOut, let fadeStart = timing.fadeStart {
            return max(0, timing.fadeSeconds - (now - fadeStart))
        }
        guard activity == .walkUp else { return nil }
        if let start = timing.songStart, let length = timing.songLength {
            return max(0, start + length - now)
        }
        if let end = timing.introductionOnlyEnd { return max(0, end - now) }
        return nil
    }

    /// Stops whatever is playing at once, quietly: used when something new starts.
    private func stopAtOnce() {
        if isPlaying { finish() }
    }

    /// Stops all sound, resets the button, gives other apps their music back, and tells the
    /// app what ended. Leaves `lastProblem` alone, so a reason for stopping stays on screen.
    private func finish() {
        let ended = nowPlaying
        let wasPlaying = isPlaying
        playNumber += 1   // anything the audio system says about the old play is now ignored
        graph.songNode.stop()
        graph.introNode.stop()
        graph.engine.mainMixerNode.outputVolume = 1
        graph.meter.reset()
        if recorder == nil {
            graph.engine.stop()
            AudioSessionSettings.deactivate()
            stopTicker()
        }
        timing = Timing()
        currentSong = nil
        currentIntroduction = nil
        playStartedAt = nil
        activity = .idle
        isPlaying = false
        isPlayingIntroduction = false
        isFadingOut = false
        nowPlaying = nil
        playbackPosition = nil
        timeLeft = nil
        outputLevel = 0
        if wasPlaying { onPlaybackEnded?(ended) }
    }

    // MARK: - Files and introductions

    /// Opens a song's file, or reuses it if already open. On failure, says which song and
    /// why in `lastProblem`.
    private func openFile(for song: Song) -> AVAudioFile? {
        if let open = openFiles[song.fileName] { return open }
        do {
            let file = try AVAudioFile(forReading: audioFolder.appending(path: song.fileName))
            // Keep only a few open: the next batter's, the current one's, a warm-up.
            if openFiles.count >= 6 { openFiles.removeAll() }
            openFiles[song.fileName] = file
            return file
        } catch {
            lastProblem = "The sound file for “\(song.title)” is missing or damaged. Import the song again."
            return nil
        }
    }

    /// The player's introduction, if it is ready and still matches their name, number and
    /// recording.
    private func readyIntroduction(for player: Player) -> AVAudioPCMBuffer? {
        guard let introduction = player.introduction, let ready = readyIntroductions[player.id] else { return nil }
        let recipe = IntroductionRecipe(introduction: introduction, name: player.name, number: player.number)
        return ready.madeFrom == recipe ? ready.sound : nil
    }

    /// The player's introduction as sound: ready already, being made already (then it waits
    /// for that job), or made now. A good result is kept ready for next time; a failed one
    /// (a missing file, or the phone's voice cut short) is not kept, so the next try starts
    /// fresh.
    private func introductionSound(for player: Player) async -> AVAudioPCMBuffer? {
        if let ready = readyIntroduction(for: player) { return ready }
        guard let introduction = player.introduction else { return nil }
        let recipe = IntroductionRecipe(introduction: introduction, name: player.name, number: player.number)

        let job: Task<SoundBox, Never>
        if let running = introductionJobs[player.id], running.madeFrom == recipe {
            job = running.task
        } else {
            job = Task { SoundBox(sound: await self.makeIntroductionSound(for: player)) }
            introductionJobs[player.id] = IntroductionJob(madeFrom: recipe, task: job)
        }
        let sound = await job.value.sound
        if introductionJobs[player.id]?.madeFrom == recipe { introductionJobs[player.id] = nil }

        guard let sound else {
            lastProblem = introduction.source == .phoneVoice
                ? "The phone's voice could not read the introduction for \(player.displayName). It needs a name or number; try again."
                : "The introduction recording for \(player.displayName) is missing or too long. Record it again."
            return nil
        }
        // Keep a modest number ready: plenty for a whole lineup.
        if readyIntroductions.count >= 30 { readyIntroductions.removeAll() }
        readyIntroductions[player.id] = ReadyIntroduction(madeFrom: recipe, sound: sound)
        return sound
    }

    /// The player's introduction as sound, but giving up waiting after `seconds`. The job
    /// itself carries on and keeps its result ready for next time.
    private func introductionSound(for player: Player, waitingAtMost seconds: Double) async -> AVAudioPCMBuffer? {
        let job = Task { SoundBox(sound: await self.introductionSound(for: player)) }
        // Two racers: the job and a timer. Whichever finishes first decides.
        let first = await withTaskGroup(of: SoundBox?.self) { group in
            group.addTask { await job.value }
            group.addTask {
                try? await Task.sleep(for: .seconds(seconds))
                return nil   // the timer won
            }
            let winner = await group.next() ?? nil
            group.cancelAll()
            return winner
        }
        return first?.sound
    }

    /// Turns an introduction into sound: reads the recording, or has the phone's voice speak.
    private func makeIntroductionSound(for player: Player) async -> AVAudioPCMBuffer? {
        guard let introduction = player.introduction else { return nil }
        switch introduction.source {
        case .phoneVoice:
            return await voice.render(for: player)
        case .recorded, .imported:
            return introduction.fileName.flatMap { readIntroductionFile(audioFolder.appending(path: $0)) }
        }
    }

    /// Reads a short introduction file into memory. Refuses anything much longer than the
    /// longest introduction, so a whole song saved as an introduction cannot fill the memory.
    private func readIntroductionFile(_ url: URL) -> AVAudioPCMBuffer? {
        guard let file = try? AVAudioFile(forReading: url),
              Double(file.length) / file.processingFormat.sampleRate <= Self.longestIntroduction + 5,
              let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length))
        else { return nil }
        do {
            try file.read(into: buffer)
            return buffer
        } catch {
            return nil
        }
    }

    // MARK: - Phone calls, Siri, speakers coming and going

    /// Listens for the iPhone's audio news: an interruption (a call, Siri, an alarm), a
    /// speaker or headphones disconnecting, the engine being reconfigured, or iOS resetting
    /// its whole audio system.
    private func listenForInterruptions() {
        let center = NotificationCenter.default
        let session = AVAudioSession.sharedInstance()

        // A phone call or Siri. When it begins, iOS has already silenced us: tidy up so the
        // button shows stopped. When it ends there is nothing to resume (a walk-up song
        // should not start again by itself); the next tap starts the engine afresh.
        // A late notice about the app having been paused in the background is old news
        // and is ignored, so it cannot stop a song started since. (Apple says iOS 16 and
        // later no longer send that kind; the check stays as a guard. It compares the
        // reason's number, 1, because Apple has retired the reason's name.)
        listeners.append(center.addObserver(forName: AVAudioSession.interruptionNotification,
                                            object: session, queue: .main) { [weak self] note in
            let type = (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt)
                .flatMap(AVAudioSession.InterruptionType.init(rawValue:))
            let wasSuspendedNotice = (note.userInfo?[AVAudioSessionInterruptionReasonKey] as? UInt) == 1
            MainActor.assumeIsolated {
                guard let self, type == .began, !wasSuspendedNotice else { return }
                self.handleInterruption()
            }
        })

        // The speaker changed. “Old device unavailable” means a Bluetooth speaker or
        // headphones went away: stop at once, so the song does not carry on through the
        // phone's own speaker.
        listeners.append(center.addObserver(forName: AVAudioSession.routeChangeNotification,
                                            object: session, queue: .main) { [weak self] note in
            let reason = (note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt)
                .flatMap(AVAudioSession.RouteChangeReason.init(rawValue:))
            MainActor.assumeIsolated {
                guard let self, reason == .oldDeviceUnavailable, self.isPlaying else { return }
                self.lastProblem = "The speaker disconnected, so the song stopped."
                self.finish()
            }
        })

        // iOS restarted its audio system (rare). Everything audio has to be built again.
        listeners.append(center.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification,
                                            object: session, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                if self.isPlaying { self.lastProblem = Self.speakerChangedMessage }
                self.finishRecording(note: "The iPhone reset its sound system and the recording stopped.")
                self.finish()
                self.graph = AudioGraph()
                self.graph.setEcho(self.library.announcerEcho)
                self.openFiles.removeAll()
                AudioSessionSettings.usePlayback()
            }
        })

        // The engine itself stopped because the audio hardware changed. Pick the song up
        // again (see `engineStoppedByItself`).
        listeners.append(center.addObserver(forName: .AVAudioEngineConfigurationChange,
                                            object: nil, queue: .main) { [weak self] note in
            let source = note.object.map { ObjectIdentifier($0 as AnyObject) }
            MainActor.assumeIsolated {
                guard let self, source == ObjectIdentifier(self.graph.engine) else { return }
                self.engineStoppedByItself()
            }
        })
    }

    /// A call or Siri took over the audio.
    private func handleInterruption() {
        if recorder != nil {
            finishRecording(note: "A call or Siri stopped the recording. Listen to what was recorded, then keep it or redo it.")
        }
        if isPlaying { finish() }
    }

    // MARK: - Small helpers

    /// The phone's audio clock, in seconds. All timing here uses it, because it is the
    /// clock the audio engine uses to start sounds exactly on time.
    static func audioClockNow() -> Double {
        AVAudioTime.seconds(forHostTime: mach_absolute_time())
    }

    /// Makes a change to the library and tells the app so it can save.
    private func changeLibrary(_ change: (inout SongLibrary) -> Void) {
        change(&library)
        onLibraryChanged?(library)
    }

    /// Makes a change to one song in the library.
    private func changeSong(_ id: SongID, _ change: (inout Song) -> Void) {
        guard let i = library.songs.firstIndex(where: { $0.id == id }) else { return }
        changeLibrary { change(&$0.songs[i]) }
    }

    /// Sets a watched value only when it changed, so screens redraw only when needed.
    private func setIfChanged<Value: Equatable>(_ key: ReferenceWritableKeyPath<StadiumAudioPlayer, Value>, _ value: Value) {
        if self[keyPath: key] != value { self[keyPath: key] = value }
    }
}

#if DEBUG
extension StadiumAudioPlayer {
    /// For testing only (debug builds): acts out what iOS does when the speaker changes
    /// mid-song: stops the audio engine and sends the “engine reconfigured” notice. The
    /// player should pick the song up where it was.
    public func actOutSpeakerChangeForTesting() {
        graph.engine.stop()
        NotificationCenter.default.post(name: .AVAudioEngineConfigurationChange, object: graph.engine)
    }
}
#endif

/// Problems starting a recording, in words the scorer can act on.
public enum RecordingProblem: Error, Equatable, Sendable {
    /// iOS is asking the scorer, for the first time, whether the app may use the microphone.
    case askingForPermission
    /// The microphone could not start, with the iPhone's reason.
    case couldNotStart(String)

    /// A sentence to show the scorer.
    public var message: String {
        switch self {
        case .askingForPermission:
            return "Answer the iPhone's question about the microphone, then tap record again."
        case .couldNotStart(let reason):
            return "Recording could not start. \(reason)"
        }
    }
}

/// An introduction's sound, passed from the job that makes it to whoever is waiting for it.
/// Both sides are on the main thread; the label only satisfies Swift's thread checks.
private struct SoundBox: @unchecked Sendable {
    var sound: AVAudioPCMBuffer?
}

/// How the app uses the iPhone's audio, set in one place.
@MainActor
enum AudioSessionSettings {
    /// “Playback”: plays with the silent switch on and the screen locked, through Bluetooth
    /// speakers, and stops other apps' music while it plays.
    static func usePlayback() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
    }

    /// “Play and record”: needed while the microphone records. Sound still comes out of the
    /// loudspeaker (not the earpiece) or a Bluetooth speaker.
    static func useRecording() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothA2DP])
        try session.setActive(true)
    }

    /// Claims the speaker, before playing.
    static func activate() throws {
        try AVAudioSession.sharedInstance().setActive(true)
    }

    /// Lets go of the speaker after playing, so other apps' music can carry on.
    static func deactivate() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

private extension Double {
    /// Rounds to a number of decimal places: 3.14159 to one place is 3.1.
    func rounded(toPlaces places: Int) -> Double {
        let scale = pow(10, Double(places))
        return (self * scale).rounded() / scale
    }
}
