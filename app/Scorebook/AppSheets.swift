// Smaller pages the app shell shows itself: the pregame screens' cover, the walk-up song
// settings, the song picker, our pitcher's warm-up songs, the game overview and the teams and
// songs pages.

import SwiftUI
import Model
import DesignSystem
import Scoring
import PregameScreens
import PostgameScreens
import GameOverview
import GameChanges
import PlayEntry

// MARK: - Pregame

/// The pregame screens over the whole screen. "Play ball" saves the new game and opens the
/// batting screen.
struct PregameCover: View {
    @Environment(AppModel.self) private var app
    var onStarted: () -> Void
    var onCancel: () -> Void

    /// Our players whose names were recorded on the announcer step.
    @State private var recorded: Set<PlayerID> = []
    /// The player whose name is being recorded.
    @State private var recording: Player?

    var body: some View {
        if let input = app.pregameInput() {
            PregameFlow(input: input, recordedNames: recorded, onRecordName: record) { result in
                switch result {
                case .playBall(let setup):
                    Task { if await app.startGame(setup) { onStarted() } }
                case .cancel:
                    onCancel()
                }
            }
            .sheet(item: $recording) { player in
                NameRecordingSheet(player: player) { kept in
                    recording = nil
                    guard let kept else { return }
                    recorded.insert(player.id)
                    Task { await app.setNameIntroduction(kept, for: player.id) }
                }
            }
        } else {
            EmptyPage(text: "Set up your team first, in Teams.")
                .onTapGesture(perform: onCancel)
        }
    }

    /// Opens the recorder for one of our players. A player typed in on the setup screens goes
    /// on the saved team first, so the recording has somewhere to be kept.
    private func record(_ player: Player) {
        Task {
            if let team = app.ourTeam, team.player(player.id) == nil {
                await app.updateSavedPlayer(player, teamID: team.id)
            }
            recording = app.ourTeam?.player(player.id) ?? player
        }
    }
}

// MARK: - Walk-up song settings

/// Music and PA, from the game menu: how much song plays before it fades, whether the first
/// pitch fades it, whether announcer introductions play, and each of our players' walk-up
/// song, warm-up songs and recorded name, any of which can be changed here.
struct SongSettingsSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    /// What is open on top of the page.
    private enum Open: Identifiable {
        case walkUp(Player), warmUp(Player), name(Player)
        var id: String {
            switch self {
            case .walkUp(let p): "walk-\(p.id.rawValue)"
            case .warmUp(let p): "warm-\(p.id.rawValue)"
            case .name(let p): "name-\(p.id.rawValue)"
            }
        }
    }
    @State private var open: Open?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(value: Binding(get: { app.settings.walkUpSongSeconds },
                                           set: { seconds in Task { await app.updateSettings { $0.walkUpSongSeconds = seconds } } }),
                            in: 4...60, step: 1) {
                        Text("\(Int(app.settings.walkUpSongSeconds)) seconds of song")
                    }
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
                Section("Players") {
                    ForEach(app.ourTeam?.roster ?? []) { player in
                        playerRow(player)
                    }
                }
            }
            .navigationTitle("Music and PA")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(item: $open) { shown in
                switch shown {
                case .walkUp(let player):
                    SongPickerSheet(player: player.id) { song in
                        open = nil
                        guard let song, let team = app.ourTeam else { return }
                        Task {
                            await app.setWalkUpSong(song, for: player.id, teamID: team.id)
                            app.cueOurNextHitter()
                        }
                    }
                case .warmUp(let player):
                    if let team = app.ourTeam {
                        WarmUpSongsSheet(pitcher: player, teamID: team.id) { open = nil }
                    }
                case .name(let player):
                    NameRecordingSheet(player: player) { kept in
                        open = nil
                        if let kept { Task { await app.setNameIntroduction(kept, for: player.id) } }
                    }
                }
            }
        }
    }

    /// One player: their name, their walk-up song, and buttons for the walk-up song, the
    /// warm-up songs and recording their name.
    private func playerRow(_ player: Player) -> some View {
        let song = player.walkUpSongID.flatMap { app.audio?.library.song($0) }
        let recorded = player.introduction != nil && player.introduction?.source != .phoneVoice
        return VStack(alignment: .leading, spacing: Spacing.small) {
            Text(player.displayName).font(ScorebookFont.headline)
            Text(song.map { "Walk-up: \($0.title)" } ?? "No walk-up song")
                .font(ScorebookFont.caption)
                .foregroundStyle(ScorebookColor.textSecondary)
            HStack(spacing: Spacing.small) {
                Button("Walk-up") { open = .walkUp(player) }
                Button("Warm-up") { open = .warmUp(player) }
                Button(recorded ? "Re-record name" : "Record name") { open = .name(player) }
            }
            .buttonStyle(.bordered)
            .font(ScorebookFont.caption)
        }
        .padding(.vertical, Spacing.extraSmall)
    }
}

// MARK: - Soundboard

/// The soundboard, from the speaker button beside the song button: a grid of songs and sound
/// effects for breaks in the game (a 1-2-3 inning, a mound visit). A tap plays one; a tap on
/// the one playing fades it. Like a warm-up song, the next pitch fades it too. The sounds and
/// their order come from team/soundboard.csv through tools/load_team.sh.
struct SoundboardSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                let ids = app.audio?.library.soundboard ?? []
                if ids.isEmpty {
                    Text("No sounds yet. Add them to team/soundboard.csv and load the team.")
                        .foregroundStyle(ScorebookColor.textSecondary)
                        .padding()
                }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: Spacing.small), GridItem(.flexible(), spacing: Spacing.small)],
                          spacing: Spacing.small) {
                    ForEach(ids, id: \.self) { id in
                        if let song = app.audio?.library.song(id) { tile(song) }
                    }
                }
                .padding(Spacing.large)
            }
            .background(ScorebookColor.background)
            .navigationTitle("Soundboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.large])
    }

    /// One sound: its name over the artist, filled while it plays.
    private func tile(_ song: Song) -> some View {
        let playback = app.audio?.playback
        let playing = playback?.phase == .warmUp && playback?.song == song.id
        let shape = RoundedRectangle(cornerRadius: Spacing.cornerRadius, style: .continuous)
        return Button {
            if playing { app.audio?.fadeOut() } else { app.audio?.playSound(song.id) }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Image(systemName: playing ? "stop.fill" : "play.fill")
                    Spacer()
                }
                .font(.system(size: 15, weight: .bold))
                Text(song.title).font(ScorebookFont.headline).lineLimit(2).minimumScaleFactor(0.8)
                if let artist = song.artist, !artist.isEmpty {
                    Text(artist).font(ScorebookFont.caption).lineLimit(1)
                        .foregroundStyle(playing ? Color.white.opacity(0.85) : ScorebookColor.textSecondary)
                }
            }
            .foregroundStyle(playing ? Color.white : ScorebookColor.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 84, alignment: .topLeading)
            .padding(Spacing.medium)
            .background(playing ? ScorebookColor.warmUpMusic : ScorebookColor.surface, in: shape)
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(playing ? "Stop \(song.title)" : "Play \(song.title)"))
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
                    Text("No songs yet. Add them on the Songs page.")
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

// MARK: - Warm-up songs

/// Our pitcher's warm-up songs, from the batting screen during a game: the songs he has (his
/// first-inning song, then the extras shuffled for his later innings), then the rest of the
/// library. Tapping a song adds it to his list or takes it off; its play button plays it now as
/// his warm-up song. Each change saves to the team at once, so it holds for this game and the
/// next ones.
struct WarmUpSongsSheet: View {
    @Environment(AppModel.self) private var app
    /// The pitcher as this game has him.
    var pitcher: Player
    /// His saved team.
    var teamID: TeamID
    var onClose: () -> Void

    @State private var search = ""

    /// The pitcher as the saved team has him now, or as this game has him if he is not on the
    /// saved team yet (a pitcher typed in by number during the game).
    private var player: Player? { app.ourTeam?.player(pitcher.id) ?? pitcher }

    /// His warm-up songs: the first-inning song, then the extras.
    private var hisSongs: [SongID] {
        guard let player else { return [] }
        return (player.warmUpSongID.map { [$0] } ?? []) + player.extraWarmUpSongIDs.filter { $0 != player.warmUpSongID }
    }

    /// The rest of the library, alphabetical, narrowed by the search.
    private var otherSongs: [Song] {
        let his = Set(hisSongs)
        return (app.audio?.library.songs ?? [])
            .filter { !his.contains($0.id) }
            .filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search)
                      || ($0.artist ?? "").localizedCaseInsensitiveContains(search) }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            List {
                if !hisSongs.isEmpty {
                    Section {
                        ForEach(hisSongs, id: \.self) { id in
                            row(id, isHis: true, note: id == player?.warmUpSongID ? "First inning" : "Later innings")
                        }
                    } header: {
                        Text("Their warm-up songs")
                    }
                }
                Section {
                    ForEach(otherSongs) { song in row(song.id, isHis: false, note: song.artist) }
                } header: {
                    Text("Add a song")
                }
            }
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search songs")
            .navigationTitle("Warm-up songs for \(player?.lastName ?? "pitcher")")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done", action: onClose) } }
        }
    }

    /// One song: a play button, the title over a smaller line, and a check when it is his.
    private func row(_ id: SongID, isHis: Bool, note: String?) -> some View {
        let song = app.audio?.library.song(id)
        let playback = app.audio?.playback
        let playingThis = playback?.phase == .warmUp && playback?.song == id
        return HStack(spacing: Spacing.small) {
            Button {
                if playingThis { app.audio?.fadeOut() } else { playNow(id) }
            } label: {
                Image(systemName: playingThis ? "stop.fill" : "play.fill")
                    .font(.system(size: 15, weight: .bold))
                    .frame(width: 40, height: 40)
                    .background(ScorebookColor.surfaceSecondary, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(playingThis ? "Fade out \(song?.title ?? "song")" : "Play \(song?.title ?? "song") now"))
            Button {
                Task { await toggle(id, isHis: isHis) }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(song?.title ?? "A song no longer in the library").foregroundStyle(ScorebookColor.textPrimary)
                        if let note { Text(note).font(.caption).foregroundStyle(ScorebookColor.textSecondary) }
                    }
                    Spacer(minLength: 0)
                    Image(systemName: isHis ? "checkmark.circle.fill" : "plus.circle")
                        .font(.title3)
                        .foregroundStyle(isHis ? ScorebookColor.highlight : ScorebookColor.textSecondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(song?.title ?? "Song"))
            .accessibilityValue(Text(isHis ? "One of their warm-up songs" : "Not one of theirs"))
            .accessibilityHint(Text(isHis ? "Takes it off their list" : "Adds it to their list"))
        }
    }

    /// Plays one song now as his warm-up song.
    private func playNow(_ id: SongID) {
        guard var pitcherNow = player else { return }
        pitcherNow.warmUpSongID = id
        app.audio?.playWarmUp(for: pitcherNow)
    }

    /// Adds a song to his list (as his first-inning song if he has none) or takes it off. A
    /// pitcher not on the saved team yet goes on it first.
    private func toggle(_ id: SongID, isHis: Bool) async {
        if app.ourTeam?.player(pitcher.id) == nil { await app.updateSavedPlayer(pitcher, teamID: teamID) }
        await app.changeWarmUpSongs(for: pitcher.id, teamID: teamID) { player in
            if isHis {
                if player.warmUpSongID == id {
                    player.warmUpSongID = player.extraWarmUpSongIDs.first
                    if !player.extraWarmUpSongIDs.isEmpty { player.extraWarmUpSongIDs.removeFirst() }
                } else {
                    player.extraWarmUpSongIDs.removeAll { $0 == id }
                }
            } else if player.warmUpSongID == nil {
                player.warmUpSongID = id
            } else if !player.extraWarmUpSongIDs.contains(id) {
                player.extraWarmUpSongIDs.append(id)
            }
        }
    }
}

// MARK: - Game overview

/// The game overview (the Box score button on the batting screen, or a swipe to the left),
/// with "Fix a play" connected: a change or a delete goes to the game session, and "change
/// it" opens that event's own steps from where the game stood just before it. What the
/// scorer enters there takes the old event's place, keeping its id and time.
struct OverviewPage: View {
    var session: GameSession
    /// True from Manual adjustment: the play-by-play opens and its plays can be fixed.
    var canFix: Bool = true
    var onClose: () -> Void

    /// An event being entered again, and where the game stood before it.
    struct Fixing: Identifiable {
        var event: GameEvent
        var before: Situation
        var id: EventID { event.id }
    }

    /// The ball in play being entered again, full screen.
    @State private var fixingPlay: Fixing?
    /// Another event being entered again in its sheet.
    @State private var fixingOther: Fixing?

    var body: some View {
        GameOverview(log: session.log, boxScore: session.boxScore,
                     plateAppearances: session.plateAppearancesByPlayer,
                     situation: session.isFinished ? nil : session.situation,
                     startingTab: canFix ? .plays : .score, canFix: canFix) { action in
            switch action {
            case .backToBatting:
                onClose()
            case .edit(let edit):
                Task { await session.apply(edit) }
            case .openEditor(let event):
                guard let before = session.situation(before: event.id) else { return }
                if case .ballInPlay = event.kind {
                    fixingPlay = Fixing(event: event, before: before)
                } else {
                    fixingOther = Fixing(event: event, before: before)
                }
            }
        }
        .fullScreenCover(item: $fixingPlay) { fixing in
            PlayEntryView(situation: fixing.before, setup: session.setup, start: .inPlay,
                          rules: PlayEntryRules(engine: session.engine)) { outcome in
                fixingPlay = nil
                if case .ballInPlay(let event) = outcome { replace(fixing.event, with: event) }
            }
        }
        .sheet(item: $fixingOther) { fixing in
            editor(for: fixing)
        }
    }

    /// The sheet that enters this kind of event, opened where the game stood before it.
    @ViewBuilder
    private func editor(for fixing: Fixing) -> some View {
        let context = GameChangeContext(setup: session.setup, situation: fixing.before)
        let done = { (result: GameChangeResult) in
            fixingOther = nil
            if case .record(let entered) = result { replace(fixing.event, with: entered.event, adding: entered.newPlayers) }
        }
        switch fixing.event.kind {
        case .runnerAction(let action):
            RunnerActionSheet(context: context, runner: action.moves.first?.runner,
                              suggest: { [session] reason, runners in
                                  session.engine.suggestRunnerAction(reason, runners: runners, in: fixing.before)
                              },
                              followsStrikeout: false, onFinish: done)
        case .pitchingChange:
            PitchingChangeSheet(context: context, onFinish: done)
        case .substitution, .runnerForNonRunner, .addHitter:
            ChangesMenuSheet(context: context, onFinish: done)
        case .errorWithNoAdvance:
            ErrorSheet(context: context, onFinish: done)
        case .manualAdjustment:
            ManualAdjustmentSheet(context: context, onFinish: done)
        case .timeLimitChange:
            TimeLimitSheet(context: context, onFinish: done)
        default:
            // Pitches are changed on the overview itself; anything else can only be deleted.
            EmptyPage(text: "Delete it from the play-by-play, then enter it again.")
                .onTapGesture { fixingOther = nil }
        }
    }

    /// Puts a newly entered event in the old one's place, keeping the old one's id and time.
    private func replace(_ old: GameEvent, with new: GameEvent, adding players: [RosterAddition] = []) {
        let replacement = GameEvent(id: old.id, enteredAt: old.enteredAt, kind: new.kind)
        Task {
            for addition in players { await session.updatePlayer(addition.player, on: addition.side) }
            await session.apply(.replace(replacement))
        }
    }
}
