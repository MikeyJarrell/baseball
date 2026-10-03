// The real walk-up audio player: the version of Model's `WalkUpAudioPlayer` promise that
// actually makes sound.
//
// What it does, in game terms:
// - When our hitter comes up, one tap plays their announcer introduction (if they have one)
//   and then their walk-up song from its start point. The song fades out by itself after
//   12 seconds of song (the walk-up length setting), or sooner when the button is tapped
//   again, with a fade of about two seconds.
// - When our team takes the field, it plays the pitcher's warm-up song over and over until
//   it is stopped or the first pitch is recorded.
// - It keeps the song library: imports, names, start points, loudness, the announcer echo.
//
// How it behaves on the phone:
// - It plays with the silent switch on, with the screen locked, and through a Bluetooth
//   speaker, and it takes over from any other music the phone is playing (the “playback”
//   audio session, plus the background-audio setting the app shell switches on).
// - A phone call or Siri stops the music; afterward the player is ready to play again.
// - If the Bluetooth speaker disconnects mid-song, the song stops at once, so it does not
//   carry on through the phone's own speaker.
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
    /// How loud the sound coming out is right now, 0 (silence) to about 1. For a level meter.
    public private(set) var outputLevel: Double = 0
    /// The latest thing that went wrong, in words for the scorer, such as a song file that
    /// is missing. Cleared when something plays successfully.
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
    /// The longest introduction recording allowed, in seconds.
    public var longestRecording: TimeInterval = 30

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
    /// Goes up by one every time something new starts or stops. A message from the audio
    /// system about an older play carries an older number and is ignored.
    @ObservationIgnored private var playNumber = 0
    /// The 20-times-a-second heartbeat that runs fades and updates the countdown.
    @ObservationIgnored private var ticker: Task<Void, Never>?
    /// The current play's timing, in seconds on the phone's audio clock.
    @ObservationIgnored private var timing = Timing()
    /// The microphone recorder, while recording.
    @ObservationIgnored private var recorder: AVAudioRecorder?
    /// The listeners for phone calls, speaker changes and audio resets.
    @ObservationIgnored private var listeners: [NSObjectProtocol] = []

    /// A ready-to-play introduction, and what it was made from (so a renamed player or a new
    /// recording makes a fresh one).
    private struct ReadyIntroduction {
        var madeFrom: IntroductionRecipe
        var sound: AVAudioPCMBuffer
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
        /// The playable part of the track after the offset, for repeating warm-ups.
        var trackRemaining: TimeInterval?
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
        let wantsIntroduction = withIntroduction && player.introduction != nil
        guard song != nil || wantsIntroduction else { return }

        // The introduction is usually ready already (cued). If not, show the button as
        // playing straight away and start as soon as it is made.
        if wantsIntroduction, readyIntroduction(for: player) == nil {
            let number = beginPlay(.walkUp, song: song?.id)
            Task {
                let introduction = await introductionSound(for: player)
                guard number == playNumber else { return }   // stopped or replaced meanwhile
                startWalkUp(song: song, introduction: introduction)
            }
            return
        }
        beginPlay(.walkUp, song: song?.id)
        startWalkUp(song: song, introduction: wantsIntroduction ? readyIntroduction(for: player) : nil)
    }

    public func playPreview(_ song: SongID, from seconds: TimeInterval) {
        stopAtOnce()
        guard let song = library.song(song), let file = openFile(for: song) else { return }
        beginPlay(.preview, song: song.id)
        guard startEngine() else { return }
        let start = scheduleSong(song, file: file, from: seconds, length: nil, repeating: false)
        graph.songNode.play(at: start.map { AVAudioTime(hostTime: AVAudioTime.hostTime(forSeconds: $0)) })
        startTicker()
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
        guard let id = pitcher.warmUpSongID, let song = library.song(id), let file = openFile(for: song) else { return }
        beginPlay(.warmUp, song: song.id)
        guard startEngine() else { return }
        let start = scheduleSong(song, file: file, from: song.startTime, length: nil, repeating: true)
        graph.songNode.play(at: start.map { AVAudioTime(hostTime: AVAudioTime.hostTime(forSeconds: $0)) })
        startTicker()
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
            // Ask now; the scorer taps record again once they have answered.
            Task { _ = await AVAudioApplication.requestRecordPermission() }
            throw WalkUpAudioError.microphoneNotAllowed
        default:
            throw WalkUpAudioError.microphoneNotAllowed
        }
        if isRecording { _ = stopRecordingIntroduction() }
        stopAtOnce()   // nothing plays while recording

        try AudioSessionSettings.useRecording()
        try FileManager.default.createDirectory(at: audioFolder, withIntermediateDirectories: true)
        let file = audioFolder.appending(path: "intro-\(UUID().uuidString).m4a")
        // A good-quality, one-channel compressed recording: plenty for a voice.
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
        let recorder = try AVAudioRecorder(url: file, settings: settings)
        guard recorder.record(forDuration: longestRecording) else {
            AudioSessionSettings.usePlayback()
            throw WalkUpAudioError.cannotImport(fileName: "Recording", reason: "The microphone could not start.")
        }
        self.recorder = recorder
        isRecording = true
        recordingSeconds = 0
        startTicker()
    }

    public func stopRecordingIntroduction() -> AnnouncerIntroduction? {
        guard let recorder else { return nil }
        recorder.stop()
        self.recorder = nil
        isRecording = false
        stopTicker()
        AudioSessionSettings.usePlayback()
        AudioSessionSettings.deactivate()

        // Keep it only if something was actually recorded (at least half a second).
        let file = recorder.url
        let seconds = (try? AVAudioFile(forReading: file)).map { Double($0.length) / $0.processingFormat.sampleRate } ?? 0
        guard seconds >= 0.5 else {
            try? FileManager.default.removeItem(at: file)
            return nil
        }
        return AnnouncerIntroduction(source: .recorded, fileName: file.lastPathComponent)
    }

    /// Throws away an introduction the scorer did not keep (“redo”), or one being replaced,
    /// deleting its sound file. The phone voice has no file, so nothing happens for it.
    public func discardIntroduction(_ introduction: AnnouncerIntroduction) {
        guard introduction.source != .phoneVoice, let name = introduction.fileName else { return }
        try? FileManager.default.removeItem(at: audioFolder.appending(path: name))
        readyIntroductions = readyIntroductions.filter { $0.value.madeFrom.introduction != introduction }
    }

    @concurrent nonisolated public func importIntroduction(from file: URL) async throws -> AnnouncerIntroduction {
        let copy = try await SoundFileImporter.copyIn(file, to: audioFolder, prefix: "intro-")
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
                let sound = await introductionSound(for: player)
                guard number == playNumber else { return }
                if let sound { startIntroductionOnly(sound) } else { finish() }
            }
        }
    }

    // MARK: - Starting sound

    /// Marks the start of something new: the button shows playing at once.
    @discardableResult
    private func beginPlay(_ kind: Activity, song: SongID?) -> Int {
        playNumber += 1
        activity = kind
        nowPlaying = song
        isPlaying = true
        isFadingOut = false
        lastProblem = nil
        timing = Timing()
        if let song, let start = library.song(song)?.startTime { playbackPosition = start }
        return playNumber
    }

    /// Plays the introduction, then the song right after it, timed to the sample.
    private func startWalkUp(song: Song?, introduction: AVAudioPCMBuffer?) {
        guard startEngine() else { return }
        let file = song.flatMap { openFile(for: $0) }
        // Nothing to play: the song file is missing and there is no introduction.
        if file == nil, introduction == nil { finish(); return }

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
            _ = scheduleSong(song, file: file, from: song.startTime, length: length, repeating: false,
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

    /// Lines up part of a song on the song player. Returns when the song will start on the
    /// audio clock.
    /// - Parameters:
    ///   - seconds: where in the track to start.
    ///   - length: seconds of song to play; missing plays to the end of the track.
    ///   - repeating: go back to `seconds` at the end of the track and keep going (warm-ups).
    ///   - startingAt: when it will start on the audio clock; missing means right away.
    @discardableResult
    private func scheduleSong(_ song: Song, file: AVAudioFile, from seconds: TimeInterval,
                              length: TimeInterval?, repeating: Bool, startingAt: Double? = nil) -> Double? {
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
            // Line up the track twice; each time one finishes, line up another, so there is
            // always one waiting and the loop never has a gap.
            for _ in 0..<2 { queueWarmUpLoop(file: file, startFrame: startFrame, frames: frames, number: number) }
        } else {
            graph.songNode.scheduleSegment(file, startingFrame: startFrame, frameCount: frames, at: nil,
                                           completionCallbackType: .dataPlayedBack) { @Sendable [weak self] _ in
                // The end of the track (or of the walk-up length): finish, if this is still
                // the current play. The audio system calls this from its own thread
                // (`@Sendable`), so it hops back to the main thread first.
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
        timing.trackRemaining = playSeconds
        return start
    }

    /// Lines up one more time through the warm-up song.
    private func queueWarmUpLoop(file: AVAudioFile, startFrame: AVAudioFramePosition,
                                 frames: AVAudioFrameCount, number: Int) {
        graph.songNode.scheduleSegment(file, startingFrame: startFrame, frameCount: frames, at: nil,
                                       completionCallbackType: .dataConsumed) { @Sendable [weak self] _ in
            Task { @MainActor in
                guard let self, self.playNumber == number, self.activity == .warmUp else { return }
                self.queueWarmUpLoop(file: file, startFrame: startFrame, frames: frames, number: number)
            }
        }
    }

    /// Switches the sound system on: claims the speaker (stopping other apps' music) and
    /// starts the engine. On failure, says why and stops.
    private func startEngine() -> Bool {
        do {
            try AudioSessionSettings.activate()
            if !graph.engine.isRunning { try graph.engine.start() }
            return true
        } catch {
            lastProblem = "The iPhone would not start playing sound (\(error.localizedDescription)). Try again."
            finish()
            return false
        }
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

    /// One heartbeat: move any fade along, start the automatic fade when a walk-up's time is
    /// nearly up, finish when it is over, and update the countdown, position and meter.
    private func tick() {
        let now = Self.audioClockNow()
        setIfChanged(\.outputLevel, Double(graph.meter.current))

        if let recorder {
            setIfChanged(\.recordingSeconds, recorder.currentTime.rounded(toPlaces: 1))
            // It stops by itself at the longest allowed length; show that.
            if !recorder.isRecording { setIfChanged(\.isRecording, false) }
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
        if let start = timing.songStart {
            var intoSong = max(0, now - start)
            if activity == .warmUp, let loop = timing.trackRemaining, loop > 0 {
                intoSong = intoSong.truncatingRemainder(dividingBy: loop)
            }
            setIfChanged(\.playbackPosition, (timing.songOffset + intoSong).rounded(toPlaces: 1))
        }
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
    /// app what ended.
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

    /// Makes the player's introduction into sound (reading the recording, or having the
    /// phone's voice speak it) and keeps it ready for next time.
    private func introductionSound(for player: Player) async -> AVAudioPCMBuffer? {
        if let ready = readyIntroduction(for: player) { return ready }
        guard let introduction = player.introduction else { return nil }
        let sound: AVAudioPCMBuffer?
        switch introduction.source {
        case .phoneVoice:
            sound = await voice.render(for: player)
        case .recorded, .imported:
            sound = introduction.fileName.flatMap { readWholeFile(audioFolder.appending(path: $0)) }
        }
        guard let sound else {
            lastProblem = introduction.source == .phoneVoice
                ? "The phone's voice needs a name or number to read for \(player.displayName)."
                : "The introduction recording for \(player.displayName) is missing. Record it again."
            return nil
        }
        // Keep a modest number ready: plenty for a whole lineup.
        if readyIntroductions.count >= 30 { readyIntroductions.removeAll() }
        readyIntroductions[player.id] = ReadyIntroduction(
            madeFrom: IntroductionRecipe(introduction: introduction, name: player.name, number: player.number),
            sound: sound
        )
        return sound
    }

    /// Reads a whole (short) sound file into memory.
    private func readWholeFile(_ url: URL) -> AVAudioPCMBuffer? {
        guard let file = try? AVAudioFile(forReading: url),
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
        listeners.append(center.addObserver(forName: AVAudioSession.interruptionNotification,
                                            object: session, queue: .main) { [weak self] note in
            let type = (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt)
                .flatMap(AVAudioSession.InterruptionType.init(rawValue:))
            MainActor.assumeIsolated {
                guard let self, type == .began else { return }
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
                self.finish()
                self.graph = AudioGraph()
                self.graph.setEcho(self.library.announcerEcho)
                self.openFiles.removeAll()
                AudioSessionSettings.usePlayback()
            }
        })

        // The engine itself stopped because the audio hardware changed (a speaker connected
        // mid-song, for example). Stop cleanly; the next tap starts it again.
        listeners.append(center.addObserver(forName: .AVAudioEngineConfigurationChange,
                                            object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isPlaying, !self.graph.engine.isRunning else { return }
                self.finish()
            }
        })
    }

    /// A call or Siri took over the audio.
    private func handleInterruption() {
        if let recorder, recorder.isRecording {
            recorder.pause()   // the recording so far is kept; stopping returns it
            isRecording = false
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
