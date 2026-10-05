// The teams list (mockup: SCREENS.teams): our team on top with the logo, saved opponents below,
// and a button to add a team. A long press on a team renames it. If no team is ours yet (the
// first time the app opens), the top card offers to set ours up.

import SwiftUI
import Model
import DesignSystem

/// Our team on top, opponents below, add and rename.
public struct TeamsListScreen: View {
    public var data: TeamScreensData
    public var onRequest: (TeamScreensRequest) -> Void

    /// The name being typed for a new team, and whether it will be ours.
    @State private var newTeam: NewTeamDraft?
    /// The team being renamed, and the name being typed.
    @State private var renaming: Team?
    @State private var renameText = ""

    public init(data: TeamScreensData, onRequest: @escaping (TeamScreensRequest) -> Void) {
        self.data = data
        self.onRequest = onRequest
    }

    /// The opponents, in alphabetical order.
    private var opponents: [Team] {
        data.teams.filter { !$0.isOurs }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    public var body: some View {
        List {
            Section {
                if let ours = data.ourTeam {
                    teamRow(ours)
                } else {
                    Button {
                        newTeam = NewTeamDraft(isOurs: true)
                    } label: {
                        Label("Set up our team", systemImage: "plus.circle.fill")
                            .font(ScorebookFont.headline)
                            .foregroundStyle(ScorebookColor.inPlay)
                            .frame(minHeight: 56)
                    }
                }
            } header: {
                ListHeader("Our team")
            }

            Section {
                if opponents.isEmpty {
                    Text("No opponents saved yet.")
                        .font(ScorebookFont.body)
                        .foregroundStyle(ScorebookColor.textSecondary)
                        .padding(.vertical, Spacing.small)
                } else {
                    ForEach(opponents) { teamRow($0) }
                }
            } header: {
                ListHeader("Opponents")
            }

            Section {
                Button {
                    newTeam = NewTeamDraft(isOurs: false)
                } label: {
                    Label("Add a team", systemImage: "plus")
                }
                .buttonStyle(WideButtonStyle(kind: .outlined))
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
        .teamListStyle()
        .navigationTitle("Teams")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    newTeam = NewTeamDraft(isOurs: false)
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add a team")
            }
        }
        .alert(newTeam?.isOurs == true ? "Our team’s name" : "New team",
               isPresented: Binding(get: { newTeam != nil }, set: { if !$0 { newTeam = nil } })) {
            TextField("Team name", text: Binding(get: { newTeam?.name ?? "" }, set: { newTeam?.name = $0 }))
                .textInputAutocapitalization(.words)
            Button("Cancel", role: .cancel) { newTeam = nil }
            Button("Add") { addTeam() }
        }
        .alert("Rename team", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Team name", text: $renameText)
                .textInputAutocapitalization(.words)
            Button("Cancel", role: .cancel) { renaming = nil }
            Button("Rename") { rename() }
        }
    }

    /// One team: logo or letter badge, name, a summary line, and an arrow to its roster.
    private func teamRow(_ team: Team) -> some View {
        NavigationLink(value: TeamScreensRoute.team(team.id)) {
            HStack(spacing: Spacing.medium) {
                TeamBadge(team: team)
                VStack(alignment: .leading, spacing: 2) {
                    Text(team.name).font(ScorebookFont.headline).foregroundStyle(ScorebookColor.textPrimary)
                    Text(team.isOurs ? TeamWording.ourTeamSummary(team) : TeamWording.opponentSummary(team))
                        .font(ScorebookFont.caption)
                        .foregroundStyle(ScorebookColor.textSecondary)
                }
            }
            .frame(minHeight: 52)
        }
        .listRowBackground(ScorebookColor.surface)
        .contextMenu {
            Button {
                renameText = team.name
                renaming = team
            } label: {
                Label("Rename", systemImage: "pencil")
            }
        }
        .swipeActions(edge: .trailing) {
            Button("Rename") {
                renameText = team.name
                renaming = team
            }
            .tint(ScorebookColor.inPlay)
        }
    }

    /// Hands back the new team, if it has a name.
    private func addTeam() {
        guard let draft = newTeam else { return }
        let name = draft.name.trimmingCharacters(in: .whitespaces)
        newTeam = nil
        guard !name.isEmpty else { return }
        onRequest(.saveTeam(Team(name: name, isOurs: draft.isOurs)))
    }

    /// Hands back the renamed team, if the new name is not empty.
    private func rename() {
        guard var team = renaming else { return }
        let name = renameText.trimmingCharacters(in: .whitespaces)
        renaming = nil
        guard !name.isEmpty, name != team.name else { return }
        team.name = name
        onRequest(.saveTeam(team))
    }
}

/// A team being added: the name typed so far, and whether it is ours.
private struct NewTeamDraft {
    var name = ""
    var isOurs: Bool
}
