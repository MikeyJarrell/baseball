// Smaller pages the app shell shows itself: the pregame screens' cover, the walk-up song
// settings, the song picker, the game overview and the teams and songs pages.

import SwiftUI
import Model
import DesignSystem
import Scoring
import PregameScreens
import PostgameScreens

// MARK: - Pregame

/// The pregame screens over the whole screen. "Play ball" saves the new game and opens the
/// batting screen.
struct PregameCover: View {
    @Environment(AppModel.self) private var app
    var onStarted: () -> Void
    var onCancel: () -> Void

    var body: some View {
        if let input = app.pregameInput() {
            PregameFlow(input: input) { result in
                switch result {
                case .playBall(let setup):
                    Task { if await app.startGame(setup) { onStarted() } }
                case .cancel:
                    onCancel()
                }
            }
        } else {
            EmptyPage(text: "Set up your team first: open Teams and add your team and its players.")
                .onTapGesture(perform: onCancel)
        }
    }
}

// MARK: - Walk-up song settings

/// How much song plays before it fades, whether the first pitch fades it, and whether
/// announcer introductions play first. Opened from the batting screen's menu.
struct SongSettingsSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(value: Binding(get: { app.settings.walkUpSongSeconds },
                                           set: { seconds in Task { await app.updateSettings { $0.walkUpSongSeconds = seconds } } }),
                            in: 4...60, step: 1) {
                        Text("\(Int(app.settings.walkUpSongSeconds)) seconds of song")
                    }
                } footer: {
                    Text("The last two seconds are the fade. A song’s own length, set on its page, wins.")
                }
                Section {
                    Toggle("Fade on the first pitch", isOn: Binding(
                        get: { app.settings.fadeSongOnFirstPitch },
                        set: { on in Task { await app.updateSettings { $0.fadeSongOnFirstPitch = on } } }))
                    Toggle("Announcer introductions", isOn: Binding(
                        get: { app.settings.playIntroductions },
                        set: { on in Task { await app.updateSettings { $0.playIntroductions = on } } }))
                    Toggle("Keep the screen on during games", isOn: Binding(
                        get: { app.settings.keepScreenAwakeDuringGames },
                        set: { on in
                            UIApplication.shared.isIdleTimerDisabled = on
                            Task { await app.updateSettings { $0.keepScreenAwakeDuringGames = on } }
                        }))
                }
            }
            .navigationTitle("Songs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Song picker

/// Every song in the library, to give one of our hitters a walk-up song. Hands back the song
/// picked, or nothing for Cancel.
struct SongPickerSheet: View {
    @Environment(AppModel.self) private var app
    var player: PlayerID
    var onFinish: (SongID?) -> Void

    var body: some View {
        NavigationStack {
            List {
                let songs = app.audio?.library.songs ?? []
                if songs.isEmpty {
                    Text("No songs yet. Add songs from the home screen’s Songs page.")
                        .foregroundStyle(ScorebookColor.textSecondary)
                }
                ForEach(songs) { song in
                    Button {
                        onFinish(song.id)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(song.title).foregroundStyle(ScorebookColor.textPrimary)
                            if let artist = song.artist { Text(artist).font(.caption).foregroundStyle(ScorebookColor.textSecondary) }
                        }
                    }
                }
            }
            .navigationTitle("Walk-up song")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { onFinish(nil) } } }
        }
    }
}

// MARK: - Game overview

/// The game so far, opened from the batting screen's Box score button.
struct OverviewPage: View {
    var session: GameSession
    var onClose: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                BoxScoreTable(box: session.boxScore, ourSide: session.setup.ourSide)
                    .padding(Spacing.screenEdge)
            }
            .background(ScorebookColor.background)
            .navigationTitle("Box score")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back to batting", action: onClose)
                }
            }
        }
    }
}

// MARK: - Teams and songs

/// The teams and songs pages.
struct TeamsPage: View {
    /// Which page to open on.
    enum Start { case teams, songs }
    var start: Start

    var body: some View {
        EmptyPage(text: start == .teams ? "Teams" : "Songs")
    }
}
