// Song assignment, both ways round. From a player: the song picker (mockup: SHEETS.songpick),
// a searchable list of every song with a play button to hear it, "No song" at the top, and a
// check by the one chosen. From a song: the list of our players, with a Walk-up / Warm-up
// choice at the top, and a check by everyone who has it. Each tap saves at once.

import SwiftUI
import Model
import DesignSystem

/// Pick a walk-up or warm-up song for one player.
struct SongPickerSheet: View {
    var slot: SongSlot
    var playerID: PlayerID
    var team: Team
    var data: TeamScreensData
    var onRequest: (TeamScreensRequest) -> Void

    @State private var search = ""
    @Environment(\.dismiss) private var dismiss

    private var player: Player? { team.player(playerID) }

    /// The song chosen now.
    private var chosen: SongID? {
        slot == .walkUp ? player?.walkUpSongID : player?.warmUpSongID
    }

    /// The songs whose title matches the search, in alphabetical order.
    private var songs: [Song] {
        data.library.songs
            .filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            List {
                if data.library.songs.isEmpty {
                    Text("The library is empty. Import songs on the Songs page first.")
                        .font(ScorebookFont.body)
                        .foregroundStyle(ScorebookColor.textSecondary)
                        .listRowBackground(ScorebookColor.surface)
                } else {
                    Section {
                        if search.isEmpty {
                            choiceRow(nil, title: slot == .walkUp ? "No walk-up song" : "No warm-up song", details: nil)
                        }
                        ForEach(songs) { song in
                            choiceRow(song.id, title: song.title, details: TeamWording.usageText(of: song.id, in: team))
                        }
                    }
                }
            }
            .teamListStyle()
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search songs")
            .navigationTitle("\(slot == .walkUp ? "Walk-up" : "Warm-up") song for \(player?.lastName ?? "player")")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.bold)
                }
            }
        }
    }

    /// One choice: a play button (none for "No song"), the title and who uses it, and a check.
    private func choiceRow(_ song: SongID?, title: String, details: String?) -> some View {
        let isOn = chosen == song
        let isPlaying = data.audio.isPlayingSong(song)
        return HStack(spacing: Spacing.small) {
            if let song {
                SongPlayButton(isPlaying: isPlaying) {
                    if isPlaying {
                        onRequest(.stopPlaying)
                    } else {
                        onRequest(.playPreview(song, from: data.library.song(song)?.startTime ?? 0))
                    }
                }
            } else {
                Image(systemName: "nosign")
                    .foregroundStyle(ScorebookColor.textSecondary)
                    .frame(width: Spacing.minimumTapSize, height: Spacing.minimumTapSize)
            }
            Button {
                onRequest(.saveTeam(team.assigning(song, as: slot, to: playerID)))
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(ScorebookFont.headline).foregroundStyle(ScorebookColor.textPrimary)
                        if let details {
                            Text(details).font(ScorebookFont.caption).foregroundStyle(ScorebookColor.textSecondary)
                        }
                    }
                    Spacer()
                    CheckCircle(isOn: isOn)
                }
                .frame(minHeight: 50)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isOn ? .isSelected : [])
        }
        .listRowBackground(ScorebookColor.surface)
    }
}

/// Assign one song to our players, as a walk-up or warm-up song.
struct AssignSongSheet: View {
    var song: Song
    var data: TeamScreensData
    var onRequest: (TeamScreensRequest) -> Void

    @State private var slot: SongSlot = .walkUp
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Use as", selection: $slot) {
                        ForEach(SongSlot.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
                if let team = data.ourTeam {
                    Section {
                        ForEach(team.roster) { player in
                            playerRow(player, team: team)
                        }
                    } footer: {
                        Text("Tap a player to give them “\(song.title)”, and again to take it away. A player has one \(slot == .walkUp ? "walk-up" : "warm-up") song, so it replaces theirs.")
                    }
                }
            }
            .teamListStyle()
            .navigationTitle(song.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.bold)
                }
            }
        }
    }

    /// One of our players, with their current song in this slot and a check if it is this one.
    private func playerRow(_ player: Player, team: Team) -> some View {
        let current = slot == .walkUp ? player.walkUpSongID : player.warmUpSongID
        let isOn = current == song.id
        let currentTitle = current.flatMap { data.library.song($0)?.title }
        return Button {
            onRequest(.saveTeam(team.assigning(isOn ? nil : song.id, as: slot, to: player.id)))
        } label: {
            HStack(spacing: Spacing.medium) {
                NumberBadge(player: player, look: .ours, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(player.displayName).font(ScorebookFont.headline).foregroundStyle(ScorebookColor.textPrimary)
                    Text(isOn ? "Has this song" : (currentTitle.map { "Now: \($0)" } ?? "No \(slot == .walkUp ? "walk-up" : "warm-up") song"))
                        .font(ScorebookFont.caption).foregroundStyle(ScorebookColor.textSecondary)
                }
                Spacer()
                CheckCircle(isOn: isOn)
            }
            .frame(minHeight: 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(ScorebookColor.surface)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// The round check from the mockup's `.radio`: an empty ring, or filled blue with a check.
struct CheckCircle: View {
    var isOn: Bool

    var body: some View {
        ZStack {
            Circle().strokeBorder(isOn ? ScorebookColor.inPlay : ScorebookColor.divider, lineWidth: 2)
            if isOn {
                Circle().fill(ScorebookColor.inPlay)
                Image(systemName: "checkmark").font(.system(size: 12, weight: .heavy)).foregroundStyle(.white)
            }
        }
        .frame(width: 24, height: 24)
        .accessibilityHidden(true)
    }
}
