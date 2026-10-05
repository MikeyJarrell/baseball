// Recording a player's name for the announcer, on the phone: the piece that goes after
// "Now batting," and their number in a pieced introduction. Opened from the batter sheet,
// the add-a-hitter sheet and a player's page.
//
// The scorer taps the big button, says the name shown, and taps again (it also stops by itself
// after 30 seconds). The take is cleaned up straight away (silence trimmed from both ends, the
// level matched to the Mac's announcer pieces); Listen plays the whole introduction as it will
// sound, and Keep or Redo decide. A recorded or imported full introduction is only replaced
// after the scorer says so.

import SwiftUI
import Model
import DesignSystem
import WalkUpAudio

/// Record one player's name. Hands back the kept pieced introduction, or nothing.
struct NameRecordingSheet: View {
    @Environment(AppModel.self) private var app
    /// The player, with their name, number and current introduction.
    var player: Player
    /// Called once: with the new introduction when the scorer keeps it, or nothing.
    var onFinish: (AnnouncerIntroduction?) -> Void

    /// Where the recording stands.
    private enum Step: Equatable {
        /// Ready to record.
        case ready
        /// Recording since this moment.
        case recording(since: Date)
        /// A cleaned-up take, waiting for Listen, Redo or Keep.
        case recorded(AnnouncerIntroduction)
    }

    @State private var step: Step = .ready
    /// A message for the scorer: no voice heard, microphone not allowed.
    @State private var problem: String?
    /// True while "Replace the recorded introduction?" is showing.
    @State private var askingToReplace = false

    private var name: String { player.name ?? "" }
    private var audio: StadiumAudioPlayer? { app.audio }

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.large) {
                Text("Say the name")
                    .font(ScorebookFont.sectionLabel)
                    .foregroundStyle(ScorebookColor.textSecondary)
                Text(name.isEmpty ? "No name yet" : name)
                    .font(.system(size: 40, weight: .heavy))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)
                    .accessibilityIdentifier("name-prompt")
                Text(scriptLine)
                    .font(ScorebookFont.body)
                    .foregroundStyle(ScorebookColor.textSecondary)
                    .multilineTextAlignment(.center)

                Spacer(minLength: 0)
                recordButton
                Spacer(minLength: 0)

                if let problem {
                    Text(problem)
                        .font(ScorebookFont.body)
                        .foregroundStyle(ScorebookColor.out)
                        .multilineTextAlignment(.center)
                }
                if audio?.hasNowBattingRecording == false {
                    Text("No “Now batting” recording on this phone yet.")
                        .font(ScorebookFont.caption)
                        .foregroundStyle(ScorebookColor.textSecondary)
                        .multilineTextAlignment(.center)
                }
                if case .recorded(let take) = step {
                    HStack(spacing: Spacing.medium) {
                        Button {
                            listen(to: take)
                        } label: {
                            Label(isListening ? "Stop" : "Listen", systemImage: isListening ? "stop.fill" : "play.fill")
                                .frame(maxWidth: .infinity, minHeight: Spacing.primaryButtonHeight)
                        }
                        .buttonStyle(.bordered)
                        Button {
                            redo(take)
                        } label: {
                            Label("Redo", systemImage: "arrow.counterclockwise")
                                .frame(maxWidth: .infinity, minHeight: Spacing.primaryButtonHeight)
                        }
                        .buttonStyle(.bordered)
                    }
                    Button("Keep") { keepTapped(take) }
                        .buttonStyle(PrimaryButtonStyle())
                }
            }
            .padding(Spacing.extraLarge)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(ScorebookColor.background)
            .navigationTitle("Record name")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: cancel) }
            }
            .confirmationDialog("Replace \(name)’s recorded introduction?", isPresented: $askingToReplace,
                                titleVisibility: .visible) {
                Button("Use the name recording instead", role: .destructive) {
                    if case .recorded(let take) = step { keep(take) }
                }
            } message: {
                Text("This replaces their full recording.")
            }
        }
        // A recording that stopped by itself (30 seconds, or a phone call) is collected.
        .onChange(of: audio?.isRecording) { _, recording in
            if recording == false, case .recording = step { stopRecording() }
        }
        .interactiveDismissDisabled(step != .ready)
    }

    /// "Now batting, number 22, Aidan Kurt.", or without the number when there is none.
    private var scriptLine: String {
        if let number = player.number, !number.isEmpty { return "“Now batting, number \(number), \(name).”" }
        return "“Now batting, \(name).”"
    }

    /// True while the introduction is playing.
    private var isListening: Bool { audio?.playback.phase == .introduction }

    /// The big round button: record, or stop while recording.
    private var recordButton: some View {
        let recording: Bool = { if case .recording = step { true } else { false } }()
        return Button {
            if recording { stopRecording() } else { startRecording() }
        } label: {
            VStack(spacing: Spacing.small) {
                ZStack {
                    Circle().fill(ScorebookColor.out).frame(width: 120, height: 120)
                    if recording {
                        RoundedRectangle(cornerRadius: 8).fill(.white).frame(width: 40, height: 40)
                    } else {
                        Circle().fill(.white).frame(width: 40, height: 40)
                    }
                }
                Group {
                    if case .recording(let since) = step {
                        TimelineView(.periodic(from: since, by: 0.5)) { context in
                            Text("Recording · \(Int(context.date.timeIntervalSince(since)))s · tap to stop")
                        }
                    } else {
                        Text(step == .ready ? "Tap to record" : "Tap to record again")
                    }
                }
                .font(ScorebookFont.body)
                .foregroundStyle(ScorebookColor.textSecondary)
            }
        }
        .buttonStyle(.plain)
        .disabled(name.isEmpty)
        .accessibilityLabel(Text(recording ? "Stop recording" : "Record name"))
    }

    // MARK: Recording

    private func startRecording() {
        guard let audio else { return }
        if case .recorded(let take) = step { audio.discardNameCandidate(take) }
        problem = nil
        Task {
            guard await audio.requestMicrophoneAccess() else {
                problem = "Microphone is off for Scorebook. Turn it on in Settings."
                return
            }
            do {
                try audio.startRecordingIntroduction()
                step = .recording(since: .now)
            } catch let trouble as RecordingProblem {
                problem = trouble.message
            } catch {
                problem = "The recording could not start. (\(error.localizedDescription))"
            }
        }
    }

    /// Stops the microphone and cleans the take up, ready to listen to.
    private func stopRecording() {
        guard let audio else { return }
        guard let take = audio.stopRecordingIntroduction() else {
            step = .ready
            problem = "Nothing was recorded. Try again."
            return
        }
        do {
            step = .recorded(try audio.makeNameCandidate(from: take))
        } catch let trouble as NameTakeProblem {
            step = .ready
            problem = trouble.message
        } catch {
            step = .ready
            problem = "The recording could not be read. Try again."
        }
    }

    /// Plays the whole introduction as it will sound, with this take as the name.
    private func listen(to take: AnnouncerIntroduction) {
        guard let audio else { return }
        if isListening { audio.stop(); return }
        var trial = player
        trial.introduction = take
        audio.playIntroduction(for: trial)
    }

    private func redo(_ take: AnnouncerIntroduction) {
        audio?.stop()
        audio?.discardNameCandidate(take)
        step = .ready
    }

    /// Keep, asking first when it would replace a full introduction recorded or imported.
    private func keepTapped(_ take: AnnouncerIntroduction) {
        switch player.introduction?.source {
        case .recorded?, .imported?: askingToReplace = true
        default: keep(take)
        }
    }

    private func keep(_ take: AnnouncerIntroduction) {
        guard let audio else { return }
        audio.stop()
        do {
            let kept = try audio.keepNameRecording(take, stem: AnnouncerIntroduction.nameStem(name))
            onFinish(kept)
        } catch {
            problem = "The name could not be saved. (\(error.localizedDescription))"
        }
    }

    private func cancel() {
        guard let audio else { onFinish(nil); return }
        audio.stop()
        switch step {
        case .recording:
            // Throw the unfinished take away.
            if let take = audio.stopRecordingIntroduction() { audio.discardIntroduction(take) }
        case .recorded(let take):
            audio.discardNameCandidate(take)
        case .ready:
            break
        }
        onFinish(nil)
    }
}
