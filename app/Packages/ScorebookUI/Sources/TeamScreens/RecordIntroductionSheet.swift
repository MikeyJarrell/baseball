// Recording an announcer introduction (mockup: SHEETS.record). The script to read, a bar of
// sound levels, the time recorded, and a big round record button that turns into a square stop
// button while recording. Once stopped (or after importing a recording), Listen and Redo
// appear, and Keep along the bottom saves it as the player's introduction. A stadium echo
// switch sits below, for every introduction at once.
//
// The microphone belongs to the audio player: the sheet only asks to start and stop, and is
// handed back where the recording stands (`IntroductionRecording`).

import SwiftUI
import Model
import DesignSystem

/// Record, listen, keep or redo a player's announcer introduction.
struct RecordIntroductionSheet: View {
    var playerID: PlayerID
    var team: Team
    var data: TeamScreensData
    var onRequest: (TeamScreensRequest) -> Void

    /// True once Keep was tapped, so closing the sheet does not throw the recording away.
    @State private var kept = false
    @Environment(\.dismiss) private var dismiss

    /// The player as saved.
    private var player: Player { team.player(playerID) ?? Player(id: playerID) }

    /// Where the recording stands, for this player only.
    private var state: IntroductionRecording {
        data.audio.recording.player == playerID ? data.audio.recording : .idle
    }

    /// The new introduction waiting for Keep, if any.
    private var pending: AnnouncerIntroduction? {
        if case .recorded(_, let introduction) = state { return introduction }
        return nil
    }

    private var isRecording: Bool {
        if case .recording = state { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.medium) {
                    ScriptQuote(text: TeamWording.announcerScript(for: player))
                    ProblemsBox(problems: data.audio.problems) { onRequest(.dismissProblems) }
                    LevelBars(isLive: isRecording)
                    elapsed
                    if let pending {
                        listenAndRedo(pending)
                    } else {
                        recordButton
                    }
                    settings
                }
                .padding(.horizontal, Spacing.large)
                .padding(.top, Spacing.small)
                .readableWidth()
            }
            .teamPageBackground()
            .safeAreaInset(edge: .bottom) {
                if pending != nil {
                    Button { keep() } label: {
                        Label("Keep", systemImage: "checkmark")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, Spacing.large)
                    .padding(.vertical, Spacing.small)
                    .background(ScorebookColor.background)
                }
            }
            .navigationTitle("Announcer introduction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 0) {
                        Text("Announcer introduction").font(ScorebookFont.headline)
                        Text("#\(player.number ?? "?") \(player.lastName)")
                            .font(ScorebookFont.caption)
                            .foregroundStyle(ScorebookColor.textSecondary)
                    }
                }
            }
        }
        // Closing the sheet any way but Keep throws the new recording away.
        .onDisappear {
            if !kept, state != .idle { onRequest(.cancelRecording) }
        }
    }

    /// The time recorded so far: counts up while recording.
    private var elapsed: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            let seconds: TimeInterval = {
                if case .recording(_, let since) = state { return context.date.timeIntervalSince(since) }
                return 0
            }()
            Text(pending == nil ? TeamWording.clock(seconds) : "Recorded")
                .font(ScorebookFont.scoreboardSmall)
                .foregroundStyle(isRecording ? ScorebookColor.out : ScorebookColor.textSecondary)
        }
    }

    /// The big round button: a red dot to start, a red square to stop.
    private var recordButton: some View {
        VStack(spacing: Spacing.small) {
            Button {
                onRequest(isRecording ? .stopRecording : .startRecording(for: playerID))
            } label: {
                ZStack {
                    Circle().strokeBorder(ScorebookColor.textSecondary, lineWidth: 5)
                    RoundedRectangle(cornerRadius: isRecording ? 9 : 35, style: .continuous)
                        .fill(ScorebookColor.out)
                        .frame(width: isRecording ? 36 : 70, height: isRecording ? 36 : 70)
                }
                .frame(width: 96, height: 96)
                .animation(.easeInOut(duration: 0.2), value: isRecording)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isRecording ? "Stop recording" : "Record")
            Text(isRecording ? "Recording · tap to stop" : "Tap to record. Take your time; silence at the ends is trimmed.")
                .font(ScorebookFont.caption)
                .foregroundStyle(ScorebookColor.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    /// Listen to the new recording, or throw it away and record again.
    private func listenAndRedo(_ pending: AnnouncerIntroduction) -> some View {
        let isListening = data.audio.playback.phase == .introduction
        return AdaptiveStack {
            Button {
                if isListening {
                    onRequest(.stopPlaying)
                } else {
                    var trial = player
                    trial.introduction = pending
                    onRequest(.playIntroduction(trial))
                }
            } label: {
                Label(isListening ? "Stop" : "Listen", systemImage: isListening ? "stop.fill" : "play.fill")
            }
            .buttonStyle(WideButtonStyle(kind: .quiet))
            Button {
                onRequest(.cancelRecording)
            } label: {
                Label("Redo", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(WideButtonStyle(kind: .quiet))
        }
    }

    /// The stadium echo switch (for every introduction) and when the song starts.
    private var settings: some View {
        Card(padding: 0) {
            Toggle("Stadium echo", isOn: Binding(
                get: { data.library.announcerEcho > 0 },
                set: { onRequest(.setAnnouncerEcho($0 ? 0.5 : 0)) }
            ))
            .tint(ScorebookColor.success)
            .padding(.horizontal, Spacing.large - 2)
            .frame(minHeight: 52)
            Divider().padding(.leading, Spacing.large - 2)
            HStack {
                Text("Song starts")
                Spacer()
                Text("right after").foregroundStyle(ScorebookColor.textSecondary)
            }
            .padding(.horizontal, Spacing.large - 2)
            .frame(minHeight: 52)
        }
        .font(ScorebookFont.body)
        .padding(.top, Spacing.small)
    }

    /// Saves the new introduction on the player, frees the old file, and closes the sheet.
    private func keep() {
        guard let pending else { return }
        let (updated, unused) = team.settingIntroduction(pending, for: playerID)
        kept = true
        onRequest(.saveTeam(updated))
        if let unused { onRequest(.discardIntroductionFile(unused)) }
        onRequest(.finishRecording)
        dismiss()
    }
}

/// The bar of sound levels: flat while idle, moving while recording. The microphone's real level
/// is not handed to screens, so the movement only shows that recording is on.
struct LevelBars: View {
    var isLive: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.08, paused: !isLive)) { context in
            let tick = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<44, id: \.self) { i in
                    let wave = abs(sin(Double(i) * 1.7 + tick * 6)) * abs(sin(Double(i) * 0.4 + tick * 2.3))
                    Capsule()
                        .fill(isLive ? ScorebookColor.out : ScorebookColor.divider)
                        .frame(width: 3, height: isLive ? 8 + wave * 44 : 6)
                }
            }
            .frame(height: 56)
        }
        .accessibilityHidden(true)
    }
}
