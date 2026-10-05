// One of our players (mockup: SCREENS.player): their number, name and usual role, then three
// cards. Walk-up song: the song, a preview, and a button to change it. Pitcher warm-up song: the
// song that plays at the changeover when we take the field with them pitching. Announcer
// introduction: the script the announcer reads, where the introduction comes from, a red record
// button, Listen, Import, and a switch for the iPhone's own voice. At the bottom, a test that
// plays the introduction and then the song, as in a game.

import SwiftUI
import UniformTypeIdentifiers
import Model
import DesignSystem

/// One of our players: walk-up song, warm-up song and announcer introduction.
public struct PlayerPage: View {
    public var teamID: TeamID
    public var playerID: PlayerID
    public var data: TeamScreensData
    public var onRequest: (TeamScreensRequest) -> Void

    /// Which song the picker is choosing, while it is open.
    @State private var picking: SongSlot?
    @State private var showsRecorder = false
    @State private var showsIntroductionImporter = false
    @State private var editing: PlayerEditDraft?
    /// Asks before the iPhone voice replaces a recording.
    @State private var confirmsVoice = false

    public init(teamID: TeamID, playerID: PlayerID, data: TeamScreensData, onRequest: @escaping (TeamScreensRequest) -> Void) {
        self.teamID = teamID
        self.playerID = playerID
        self.data = data
        self.onRequest = onRequest
    }

    public var body: some View {
        if let team = data.team(teamID), let player = team.player(playerID) {
            content(player, team: team)
        } else {
            ContentUnavailableView("Player not found", systemImage: "person",
                                   description: Text("This player is no longer on the team."))
                .teamPageBackground()
        }
    }

    private func content(_ player: Player, team: Team) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header(player)
                ProblemsBox(problems: data.audio.problems) { onRequest(.dismissProblems) }
                    .padding(.top, Spacing.small)
                walkUpCard(player)
                warmUpCard(player)
                introductionCard(player, team: team)
                testButton(player)
                    .padding(.top, Spacing.large - 2)
            }
            .padding(.horizontal, Spacing.large)
            .padding(.bottom, Spacing.huge)
            .readableWidth()
        }
        .teamPageBackground()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    editing = PlayerEditDraft(player: player, usuals: data.usuals(for: player.id), isNew: false)
                }
            }
        }
        .sheet(item: $editing) { draft in
            PlayerEditSheet(draft: draft, team: team, onRequest: onRequest)
        }
        .sheet(item: $picking) { slot in
            SongPickerSheet(slot: slot, playerID: player.id, team: team, data: data, onRequest: onRequest)
        }
        .sheet(isPresented: $showsRecorder) {
            RecordIntroductionSheet(playerID: player.id, team: team, data: data, onRequest: onRequest)
        }
        .fileImporter(isPresented: $showsIntroductionImporter, allowedContentTypes: [.audio]) { result in
            if case .success(let url) = result {
                onRequest(.importIntroduction(url, for: player.id))
            }
        }
        // An imported introduction comes back waiting to be kept: open the sheet to listen and keep it.
        .onChange(of: data.audio.recording) { _, recording in
            if case .recorded(let id, _) = recording, id == player.id, !showsRecorder {
                showsRecorder = true
            }
        }
        .confirmationDialog("Use the iPhone voice instead of the recording?", isPresented: $confirmsVoice,
                            titleVisibility: .visible) {
            Button("Use the iPhone voice", role: .destructive) {
                setIntroduction(AnnouncerIntroduction(source: .phoneVoice), for: player, in: team)
            }
        } message: {
            Text("The recording is deleted.")
        }
    }

    /// The big number badge, the name, and "Shortstop · Bats R · Throws R".
    private func header(_ player: Player) -> some View {
        AdaptiveStack(spacing: Spacing.large - 2) {
            NumberBadge(player: player, look: .ours, size: 72)
            VStack(alignment: .leading, spacing: 2) {
                Text(player.displayName)
                    .font(ScorebookFont.largeTitle)
                    .foregroundStyle(ScorebookColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                let line = TeamWording.playerLine(player, usuals: data.usuals(for: player.id))
                if !line.isEmpty {
                    Text(line).font(ScorebookFont.body).foregroundStyle(ScorebookColor.textSecondary)
                }
            }
        }
        .padding(.top, Spacing.small)
    }

    /// The walk-up song, Preview, and Change song.
    private func walkUpCard(_ player: Player) -> some View {
        let song = player.walkUpSongID.flatMap { data.library.song($0) }
        let isPlaying = data.audio.isPlayingSong(song?.id)
        return VStack(alignment: .leading, spacing: 0) {
            SectionLabel("Walk-up song")
            Card {
                if let song {
                    SongLine(title: song.title, details: TeamWording.songDetails(song))
                } else {
                    SongLine(title: "No song yet", details: "Pick one from the library")
                }
                AdaptiveStack {
                    Button {
                        if isPlaying {
                            onRequest(.stopPlaying)
                        } else if let song {
                            onRequest(.playPreview(song.id, from: song.startTime))
                        }
                    } label: {
                        Label(isPlaying ? "Stop" : "Preview", systemImage: isPlaying ? "stop.fill" : "play.fill")
                    }
                    .buttonStyle(WideButtonStyle(kind: .quiet, compact: true))
                    .disabled(song == nil)
                    Button(song == nil ? "Pick a song" : "Change song") { picking = .walkUp }
                        .buttonStyle(WideButtonStyle(kind: .quiet, compact: true))
                }
                .padding(.top, Spacing.medium)
            }
        }
    }

    /// The pitcher warm-up song and a button to change it.
    private func warmUpCard(_ player: Player) -> some View {
        // With no main song, his first extra song plays his first inning, so it is shown as his song.
        let mainID = player.warmUpSongID ?? player.extraWarmUpSongIDs.first
        let song = mainID.flatMap { data.library.song($0) }
        var extras: [String] = []
        for id in player.extraWarmUpSongIDs where id != mainID {
            if let title = data.library.song(id)?.title, !extras.contains(title) { extras.append(title) }
        }
        let who = player.lastName
        return VStack(alignment: .leading, spacing: 0) {
            SectionLabel("Pitcher warm-up song")
            Card {
                SongLine(title: song?.title ?? "No warm-up song",
                         details: extras.isEmpty
                            ? "Plays at the changeover when we take the field with \(who) pitching"
                            : "Plays at \(who)’s first changeover each game")
                // Extra songs come from the roster files; later innings shuffle through them.
                if !extras.isEmpty {
                    SongLine(title: extras.joined(separator: " · "),
                             details: "Later innings: one of these at random, each once before any repeats")
                        .padding(.top, Spacing.medium)
                }
                Button(song == nil ? "Pick a warm-up song" : "Change warm-up song") { picking = .warmUp }
                    .buttonStyle(WideButtonStyle(kind: .quiet, compact: true))
                    .padding(.top, Spacing.medium)
            }
        }
    }

    /// The script, where the introduction comes from, Record, Listen, Import and the iPhone voice.
    private func introductionCard(_ player: Player, team: Team) -> some View {
        let isListening = data.audio.playback.phase == .introduction
        return VStack(alignment: .leading, spacing: 0) {
            SectionLabel("Announcer introduction")
            Card {
                ScriptQuote(text: TeamWording.announcerScript(for: player))
                Text(TeamWording.introductionStatus(player.introduction, echo: data.library.announcerEcho))
                    .font(ScorebookFont.caption)
                    .foregroundStyle(ScorebookColor.textSecondary)
                    .padding(.bottom, Spacing.medium)
                Button { showsRecorder = true } label: {
                    Label(player.introduction?.source == .recorded ? "Record again" : "Record introduction",
                          systemImage: "mic.fill")
                }
                .buttonStyle(WideButtonStyle(kind: .record))
                // Just the name, pieced together with the shared "Now batting," and their number.
                Button { onRequest(.recordName(player.id)) } label: {
                    Label(player.introduction?.source == .pieced ? "Record name again" : "Record name",
                          systemImage: "person.wave.2")
                }
                .buttonStyle(WideButtonStyle(kind: .quiet, compact: true))
                .padding(.top, Spacing.medium)
                AdaptiveStack {
                    Button {
                        onRequest(isListening ? .stopPlaying : .playIntroduction(player))
                    } label: {
                        Label(isListening ? "Stop" : "Listen", systemImage: isListening ? "stop.fill" : "play.fill")
                    }
                    .buttonStyle(WideButtonStyle(kind: .quiet, compact: true))
                    .disabled(player.introduction == nil && !isListening)
                    Button { showsIntroductionImporter = true } label: {
                        Label("Import", systemImage: "folder")
                    }
                    .buttonStyle(WideButtonStyle(kind: .quiet, compact: true))
                }
                .padding(.top, Spacing.medium)
                Toggle("Use the iPhone voice", isOn: Binding(
                    get: { player.introduction?.source == .phoneVoice },
                    set: { useVoice in
                        if useVoice, player.introduction?.fileName != nil {
                            confirmsVoice = true
                        } else {
                            setIntroduction(useVoice ? AnnouncerIntroduction(source: .phoneVoice) : nil, for: player, in: team)
                        }
                    }
                ))
                .font(ScorebookFont.body)
                .tint(ScorebookColor.success)
                .padding(.top, Spacing.medium)
            }
        }
    }

    /// "Test: introduction, then song", or Stop while anything plays.
    private func testButton(_ player: Player) -> some View {
        let isPlaying = data.audio.isPlaying
        return Button {
            onRequest(isPlaying ? .stopPlaying : .playWalkUp(player))
        } label: {
            Label(isPlaying ? "Stop" : (player.introduction == nil ? "Test: the song as it plays in a game" : "Test: introduction, then song"),
                  systemImage: isPlaying ? "stop.fill" : "speaker.wave.2.fill")
        }
        .buttonStyle(WideButtonStyle(kind: .ours))
        .disabled(!isPlaying && player.walkUpSongID == nil && player.introduction == nil)
    }

    /// Hands back the team with the player's introduction changed, and says the old sound file is no longer used.
    private func setIntroduction(_ introduction: AnnouncerIntroduction?, for player: Player, in team: Team) {
        let (updated, unused) = team.settingIntroduction(introduction, for: player.id)
        onRequest(.saveTeam(updated))
        if let unused { onRequest(.introductionReplaced(unused)) }
    }
}

/// The announcer's script in italic serif type on a gray box, like a quotation.
struct ScriptQuote: View {
    var text: String

    var body: some View {
        Text("“\(text)”")
            .font(.system(.body, design: .serif).italic())
            .foregroundStyle(ScorebookColor.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Spacing.large - 2)
            .padding(.vertical, Spacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ScorebookColor.surfaceSecondary, in: RoundedRectangle(cornerRadius: Spacing.cornerRadius, style: .continuous))
            .padding(.bottom, Spacing.small)
            .accessibilityLabel("Script: \(text)")
    }
}

extension SongSlot: Identifiable {
    public var id: String { rawValue }
}
