// A team's roster (mockup: SCREENS.roster). The team's logo or letter, its name, chips for
// quick entry and (for our team) the song library, then every player: number, name, what they
// usually do, and for our players their walk-up song, warm-up song and introduction. Tapping one
// of our players opens their page; tapping an opponent opens the edit sheet. Swipe a row to
// remove the player. The plus button adds one player; quick entry adds many in a row.

import SwiftUI
import Model
import DesignSystem

/// One team's players: add, edit and remove.
public struct RosterScreen: View {
    public var teamID: TeamID
    public var data: TeamScreensData
    public var onRequest: (TeamScreensRequest) -> Void

    /// The player being added or edited in the edit sheet.
    @State private var editing: PlayerEditDraft?
    @State private var showsQuickEntry = false
    /// The player waiting for "Remove" to be confirmed.
    @State private var removing: Player?
    @State private var showsRename = false
    @State private var showsSongs = false
    @State private var renameText = ""

    public init(teamID: TeamID, data: TeamScreensData, onRequest: @escaping (TeamScreensRequest) -> Void) {
        self.teamID = teamID
        self.data = data
        self.onRequest = onRequest
    }

    public var body: some View {
        if let team = data.team(teamID) {
            content(team)
        } else {
            ContentUnavailableView("Team not found", systemImage: "person.3",
                                   description: Text("This team is no longer saved."))
                .teamPageBackground()
        }
    }

    private func content(_ team: Team) -> some View {
        List {
            Section {
                header(team)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            if team.roster.isEmpty {
                Section {
                    emptyRoster(team)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            } else {
                Section {
                    ForEach(team.roster) { player in
                        row(player, in: team)
                            .listRowBackground(ScorebookColor.surface)
                            .swipeActions(edge: .trailing) {
                                Button("Remove", role: .destructive) { removing = player }
                            }
                    }
                } header: {
                    HStack {
                        ListHeader(TeamWording.playerCount(team.roster.count))
                        Spacer()
                        Text(team.isOurs ? "Songs and intro on each page" : "Tap a player to edit")
                            .font(ScorebookFont.caption.weight(.semibold))
                            .foregroundStyle(ScorebookColor.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    }
                }
            }
        }
        .teamListStyle()
        .navigationTitle(team.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    Button {
                        renameText = team.name
                        showsRename = true
                    } label: {
                        Label("Rename team", systemImage: "pencil")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Team options")
                Button {
                    editing = PlayerEditDraft(player: Player(), usuals: PlayerUsuals(), isNew: true)
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add a player")
            }
        }
        .navigationDestination(isPresented: $showsSongs) {
            SongLibraryScreen(data: data, onRequest: onRequest)
        }
        .sheet(item: $editing) { draft in
            PlayerEditSheet(draft: draft, team: team, onRequest: onRequest)
        }
        .sheet(isPresented: $showsQuickEntry) {
            QuickEntrySheet(team: team, onRequest: onRequest)
        }
        .confirmationDialog(
            "Remove \(removing?.displayName ?? "this player") from the \(team.name)?",
            isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }),
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) { remove(from: team) }
            Button("Cancel", role: .cancel) { removing = nil }
        } message: {
            Text("Games already played keep them in their box scores.")
        }
        .alert("Rename team", isPresented: $showsRename) {
            TextField("Team name", text: $renameText)
                .textInputAutocapitalization(.words)
            Button("Cancel", role: .cancel) {}
            Button("Rename") {
                var renamed = team
                let name = renameText.trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty, name != team.name else { return }
                renamed.name = name
                onRequest(.saveTeam(renamed))
            }
        }
    }

    /// The logo or letter, the team name and its summary, and the chips.
    private func header(_ team: Team) -> some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            AdaptiveStack(spacing: Spacing.large - 2) {
                TeamBadge(team: team, size: 64)
                VStack(alignment: .leading, spacing: 2) {
                    Text(team.name)
                        .font(ScorebookFont.largeTitle)
                        .foregroundStyle(ScorebookColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(team.isOurs ? TeamWording.ourTeamSummary(team) : TeamWording.opponentSummary(team))
                        .font(ScorebookFont.body)
                        .foregroundStyle(ScorebookColor.textSecondary)
                }
            }
            HStack(spacing: Spacing.small) {
                Button { showsQuickEntry = true } label: {
                    ChipLabel(title: "Quick entry", systemImage: "list.bullet")
                }
                .buttonStyle(.plain)
                if team.isOurs {
                    // A plain button rather than a link, so the rest of the header row is not a link.
                    Button { showsSongs = true } label: {
                        ChipLabel(title: "Songs", systemImage: "music.note")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.top, Spacing.small)
    }

    /// The empty roster: a word of explanation and the two ways to add players.
    private func emptyRoster(_ team: Team) -> some View {
        VStack(spacing: Spacing.medium) {
            InfoBox(text: "No players yet. Quick entry is the fastest way to type a whole roster: number and name, then Return, for each player.")
            Button { showsQuickEntry = true } label: {
                Label("Quick entry", systemImage: "list.bullet")
            }
            .buttonStyle(PrimaryButtonStyle())
            Button {
                editing = PlayerEditDraft(player: Player(), usuals: PlayerUsuals(), isNew: true)
            } label: {
                Label("Add one player", systemImage: "plus")
            }
            .buttonStyle(WideButtonStyle(kind: .outlined))
        }
    }

    /// One player. Ours open their page; an opponent opens the edit sheet.
    @ViewBuilder
    private func row(_ player: Player, in team: Team) -> some View {
        if team.isOurs {
            NavigationLink(value: TeamScreensRoute.player(team.id, player.id)) {
                RosterRow(player: player, usuals: data.usuals(for: player.id), team: team, library: data.library)
            }
        } else {
            Button {
                editing = PlayerEditDraft(player: player, usuals: data.usuals(for: player.id), isNew: false)
            } label: {
                HStack {
                    RosterRow(player: player, usuals: data.usuals(for: player.id), team: team, library: data.library)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(ScorebookColor.textSecondary.opacity(0.6))
                }
            }
            .buttonStyle(.plain)
        }
    }

    /// Hands back the team without the player waiting to be removed, and says their
    /// introduction's sound file is no longer used.
    private func remove(from team: Team) {
        guard let player = removing else { return }
        removing = nil
        onRequest(.saveTeam(team.removing(player.id)))
        onRequest(.setUsuals(PlayerUsuals(), for: player.id))
        if let introduction = player.introduction, introduction.fileName != nil {
            onRequest(.introductionReplaced(introduction))
        }
    }
}

/// One roster row: number badge, name and usual role, and a second line with songs and
/// introduction (ours) or batting side and throwing hand (theirs).
struct RosterRow: View {
    var player: Player
    var usuals: PlayerUsuals
    var team: Team
    var library: SongLibrary

    var body: some View {
        HStack(spacing: Spacing.medium) {
            NumberBadge(player: player, look: team.isOurs ? .ours : .theirs)
            VStack(alignment: .leading, spacing: 2) {
                (Text(player.displayName).font(ScorebookFont.headline).foregroundColor(ScorebookColor.textPrimary)
                 + Text(roleText).font(ScorebookFont.caption).foregroundColor(ScorebookColor.textSecondary))
                    .lineLimit(4)
                secondLine
                    .font(ScorebookFont.caption)
                    .lineLimit(4)
                // Two players may share a number; the roster marks both so the scorer notices.
                if let note = TeamWording.sharedNumberNote(for: player, in: team) {
                    Text(note)
                        .font(ScorebookFont.caption.weight(.semibold))
                        .foregroundStyle(ScorebookColor.ourTeamText)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(minHeight: 52)
        .contentShape(Rectangle())
    }

    /// "  Shortstop" after the name, when a usual role is set.
    private var roleText: String {
        let text = TeamWording.usualText(usuals)
        return text.isEmpty ? "" : "  " + text
    }

    /// Ours: "♪ Rally Cap · warm-up: Infield Fly · intro recorded", or "No walk-up song".
    /// Theirs: "Bats L · Throws L".
    @ViewBuilder
    private var secondLine: some View {
        if team.isOurs {
            let song = player.walkUpSongID.flatMap { library.song($0) }
            let warmUp = player.warmUpSongID.flatMap { library.song($0) }
            let rest = (warmUp.map { " · warm-up: \($0.title)" } ?? "") + " · " + TeamWording.introductionShort(player.introduction)
            if let song {
                Text("♪ \(song.title)\(rest)").foregroundStyle(ScorebookColor.textSecondary)
            } else {
                (Text("No walk-up song").fontWeight(.semibold).foregroundColor(ScorebookColor.ourTeamText)
                 + Text(rest).foregroundColor(ScorebookColor.textSecondary))
            }
        } else {
            let hands = TeamWording.handedness(player)
            Text(hands.isEmpty ? (player.name == nil ? "Number only" : "Bats and throws unknown") : hands)
                .foregroundStyle(ScorebookColor.textSecondary)
        }
    }
}
