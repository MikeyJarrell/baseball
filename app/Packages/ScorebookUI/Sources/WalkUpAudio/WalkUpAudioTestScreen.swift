// The audio test screen: a plain workbench for checking every sound the app makes before
// the batting screen exists. List and import songs, play and stop them, set a start point
// by listening, even out loudness, play a walk-up with its announcer introduction, record
// an introduction, set the stadium echo, and play a pitcher's warm-up song.
//
// It is for checking, not for games, so it uses plain iPhone styling. Open it from the
// previews at the bottom of this file, or the app shell can show it from a hidden menu to
// check the audio on Mikey's phone.

import Model
import SwiftUI
import UniformTypeIdentifiers

/// The audio workbench.
public struct WalkUpAudioTestScreen: View {
    /// The player being tested.
    @Bindable var player: StadiumAudioPlayer

    /// The made-up batter used to try walk-ups and introductions.
    @State private var batter = Player(name: "Derek Jeter", number: "2",
                                       introduction: AnnouncerIntroduction(source: .phoneVoice))
    /// A new recording waiting for “keep” or “redo”.
    @State private var newRecording: AnnouncerIntroduction?
    /// Messages for the scorer, such as import problems.
    @State private var messages: [String] = []
    /// Whether the Files picker is showing, and what it is picking.
    @State private var pickingSongs = false
    @State private var pickingIntroduction = false

    public init(player: StadiumAudioPlayer) {
        self.player = player
    }

    public var body: some View {
        NavigationStack {
            List {
                nowPlayingSection
                walkUpSection
                announcerSection
                songsSection
                warmUpSection
                if !messages.isEmpty {
                    Section("Messages") {
                        ForEach(messages, id: \.self) { Text($0).font(.footnote) }
                        Button("Clear messages") { messages.removeAll() }
                    }
                }
            }
            .navigationTitle("Audio test")
            .fileImporter(isPresented: $pickingSongs, allowedContentTypes: [.audio],
                          allowsMultipleSelection: true) { result in
                if case .success(let files) = result { importSongs(files) }
            }
            .fileImporter(isPresented: $pickingIntroduction, allowedContentTypes: [.audio]) { result in
                if case .success(let file) = result { importIntroduction(file) }
            }
        }
    }

    // MARK: - Sections

    /// What is playing, the countdown, and a loudness meter.
    private var nowPlayingSection: some View {
        Section("Now playing") {
            LabeledContent("Playing", value: playingDescription)
            if let left = player.timeLeft {
                LabeledContent("Time left", value: String(format: "%.1f s", left))
            }
            if let position = player.playbackPosition {
                LabeledContent("Position in track", value: String(format: "%.1f s", position))
            }
            ProgressView(value: min(1, player.outputLevel * 4)) { Text("Level").font(.caption) }
            if let problem = player.lastProblem {
                Text(problem).font(.footnote).foregroundStyle(.red)
            }
            HStack {
                Button("Fade out") { player.fadeOut() }.disabled(!player.isPlaying)
                Spacer()
                Button("Stop now", role: .destructive) { player.stop() }.disabled(!player.isPlaying)
            }
            .buttonStyle(.bordered)
        }
    }

    /// The one-tap walk-up, as the batting screen will use it.
    private var walkUpSection: some View {
        Section("Walk-up") {
            TextField("Name", text: Binding(get: { batter.name ?? "" }, set: { batter.name = $0 }))
            TextField("Number", text: Binding(get: { batter.number ?? "" }, set: { batter.number = $0 }))
                .keyboardType(.numberPad)
            Picker("Song", selection: $batter.walkUpSongID) {
                Text("None").tag(SongID?.none)
                ForEach(player.library.songs) { Text($0.title).tag(Optional($0.id)) }
            }
            Stepper(value: $player.walkUpLength, in: 4...30, step: 1) {
                Text("Walk-up length: \(Int(player.walkUpLength)) seconds of song")
            }
            Button("Load ahead (cue)") { player.cue(for: batter) }
            Button("Play introduction, then song") { player.playWalkUp(for: batter, withIntroduction: true) }
            Button("Play song only") { player.playWalkUp(for: batter, withIntroduction: false) }
        }
    }

    /// The stadium announcer: phone voice, a recording, or an imported file, plus the echo.
    private var announcerSection: some View {
        Section("Announcer") {
            LabeledContent("Introduction", value: introductionDescription)
            Button("Use the phone's voice") { replaceIntroduction(with: AnnouncerIntroduction(source: .phoneVoice)) }
            if player.isRecording {
                Button("Stop recording (\(String(format: "%.1f", player.recordingSeconds)) s)") {
                    newRecording = player.stopRecordingIntroduction()
                    if newRecording == nil { messages.append("Nothing was recorded. Try again.") }
                }
                .foregroundStyle(.red)
            } else {
                Button("Record an introduction") { startRecording() }
            }
            if let newRecording {
                Button("Listen to the new recording") {
                    var trial = batter
                    trial.introduction = newRecording
                    player.playIntroduction(for: trial)
                }
                Button("Keep it") {
                    replaceIntroduction(with: newRecording)
                    self.newRecording = nil
                }
                Button("Redo", role: .destructive) {
                    player.discardIntroduction(newRecording)
                    self.newRecording = nil
                }
            }
            Button("Import a recording") { pickingIntroduction = true }
            Button("Play the introduction alone") { player.playIntroduction(for: batter) }
            VStack(alignment: .leading) {
                Text("Stadium echo: \(Int(player.library.announcerEcho * 100))%")
                Slider(value: Binding(get: { player.library.announcerEcho },
                                      set: { player.setAnnouncerEcho($0) }), in: 0...1)
            }
        }
    }

    /// The song library: import, preview, start points, loudness.
    private var songsSection: some View {
        Section("Songs") {
            Button("Import songs from Files") { pickingSongs = true }
            Button("Make three test songs") { makeTestSongs() }
            ForEach(player.library.songs) { song in
                SongTestRow(player: player, song: song)
            }
        }
    }

    /// The pitcher's warm-up song, which repeats until stopped.
    private var warmUpSection: some View {
        Section("Pitcher warm-up") {
            Picker("Warm-up song", selection: $batter.warmUpSongID) {
                Text("None").tag(SongID?.none)
                ForEach(player.library.songs) { Text($0.title).tag(Optional($0.id)) }
            }
            Button("Play warm-up song") { player.playWarmUp(for: batter) }
        }
    }

    // MARK: - Words on screen

    private var playingDescription: String {
        guard player.isPlaying else { return "Nothing" }
        let title = player.nowPlaying.flatMap { player.library.song($0)?.title }
        let what: String
        switch player.activity {
        case .walkUp: what = player.isPlayingIntroduction ? "Introduction" : "Walk-up"
        case .preview: what = "Preview"
        case .warmUp: what = "Warm-up"
        case .introduction: what = "Introduction"
        case .idle: what = "Nothing"
        }
        let fading = player.isFadingOut ? ", fading" : ""
        return [what, title].compactMap { $0 }.joined(separator: ": ") + fading
    }

    private var introductionDescription: String {
        switch batter.introduction?.source {
        case .phoneVoice: "Phone's voice"
        case .recorded: "Recorded"
        case .imported: "Imported"
        case nil: "None"
        }
    }

    // MARK: - Actions

    /// Swaps the batter's introduction, deleting the old recording's file.
    private func replaceIntroduction(with introduction: AnnouncerIntroduction) {
        if let old = batter.introduction, old != introduction { player.discardIntroduction(old) }
        batter.introduction = introduction
    }

    private func startRecording() {
        Task {
            guard await player.requestMicrophoneAccess() else {
                messages.append(WalkUpAudioError.microphoneNotAllowed.message)
                return
            }
            do {
                try player.startRecordingIntroduction()
            } catch let problem as WalkUpAudioError {
                messages.append(problem.message)
            } catch {
                messages.append("Recording could not start: \(error.localizedDescription)")
            }
        }
    }

    private func importSongs(_ files: [URL]) {
        Task {
            let report = await player.importSongsWithReport(from: files)
            player.addSongs(report.songs)
            messages.append(contentsOf: report.problems.map(\.message))
            if batter.walkUpSongID == nil { batter.walkUpSongID = player.library.songs.first?.id }
        }
    }

    private func importIntroduction(_ file: URL) {
        Task {
            do {
                replaceIntroduction(with: try await player.importIntroduction(from: file))
            } catch let problem as WalkUpAudioError {
                messages.append(problem.message)
            } catch {
                messages.append(error.localizedDescription)
            }
        }
    }

    private func makeTestSongs() {
        do {
            let folder = FileManager.default.temporaryDirectory.appending(path: "TestSongs")
            importSongs(try TestSongMaker.makeTestSongs(in: folder))
        } catch {
            messages.append("The test songs could not be made: \(error.localizedDescription)")
        }
    }
}

/// One song in the test list: preview it, set its start point by listening, set loudness.
private struct SongTestRow: View {
    let player: StadiumAudioPlayer
    let song: Song

    /// True while this song's preview is the thing playing.
    private var isPreviewing: Bool { player.nowPlaying == song.id && player.activity == .preview }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(song.title).font(.headline)
            Text("Starts at \(String(format: "%.1f", song.startTime)) s" +
                 (song.duration.map { String(format: " of %.0f s", $0) } ?? ""))
                .font(.caption)
            HStack {
                Button(isPreviewing ? "Stop" : "Play from top") {
                    isPreviewing ? player.stop() : player.playPreview(song.id, from: 0)
                }
                Button("Play from start point") { player.playPreview(song.id, from: song.startTime) }
                Button("Start here") {
                    if let position = player.playbackPosition { player.setStartPoint(position, for: song.id) }
                }
                .disabled(!isPreviewing)
            }
            .buttonStyle(.bordered)
            .font(.caption)
            HStack {
                Image(systemName: "speaker.fill")
                Slider(value: Binding(get: { song.volume }, set: { player.setVolume($0, for: song.id) }), in: 0...1)
                Image(systemName: "speaker.wave.3.fill")
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview("Audio test screen") {
    WalkUpAudioTestScreen(player: .forPreviews())
}

#Preview("Audio test screen, dark") {
    WalkUpAudioTestScreen(player: .forPreviews())
        .preferredColorScheme(.dark)
}

#Preview("Audio test screen, largest text") {
    WalkUpAudioTestScreen(player: .forPreviews())
        .dynamicTypeSize(.accessibility5)
}
