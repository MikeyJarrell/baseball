// The sheet for adding or editing one player: number, name, batting side, throwing hand, usual
// position and usual role, and (for a saved player) a button to remove them from the team.
// Save hands back the whole team with the player in it.

import SwiftUI
import Model
import DesignSystem

/// A player being added or edited, with their usual position and role.
struct PlayerEditDraft: Identifiable {
    var player: Player
    var usuals: PlayerUsuals
    /// True for a player not yet on the team.
    var isNew: Bool

    var id: PlayerID { player.id }
}

/// Add or edit one player.
struct PlayerEditSheet: View {
    var team: Team
    var onRequest: (TeamScreensRequest) -> Void

    @State private var draft: PlayerEditDraft
    @State private var number: String
    @State private var name: String
    @State private var confirmsRemove = false
    /// The usual position and role as they were, so they are saved only when changed.
    private let originalUsuals: PlayerUsuals
    @Environment(\.dismiss) private var dismiss

    init(draft: PlayerEditDraft, team: Team, onRequest: @escaping (TeamScreensRequest) -> Void) {
        self.team = team
        self.onRequest = onRequest
        _draft = State(initialValue: draft)
        originalUsuals = draft.usuals
        _number = State(initialValue: draft.player.number ?? "")
        _name = State(initialValue: draft.player.name ?? "")
    }

    /// Another player already wearing the number typed, if any.
    private var numberTwin: Player? {
        TeamWording.playerWearing(number, in: team, except: draft.player.id)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Number", text: $number)
                        .keyboardType(.numberPad)
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                } footer: {
                    if let twin = numberTwin {
                        Text("\(twin.displayName) also wears \(number).")
                    } else if team.isOurs {
                        Text("A number or a name is enough. Fill in the rest later.")
                    } else {
                        Text("A number is enough for their players.")
                    }
                }

                Section("Bats") {
                    ClearableSegments(options: HandChoices.bats, selection: $draft.player.bats)
                        .listRowInsets(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
                }
                Section("Throws") {
                    ClearableSegments(options: HandChoices.throwsWith, selection: $draft.player.throwsWith)
                        .listRowInsets(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
                }

                Section {
                    Picker("Usual position", selection: $draft.usuals.position) {
                        Text("None (DH)").tag(Position?.none)
                        ForEach(Position.allCases, id: \.self) { position in
                            Text("\(position.number) · \(position.name.capitalizedFirst)").tag(Position?.some(position))
                        }
                    }
                    Toggle("Leads off", isOn: $draft.usuals.leadsOff)
                    Toggle("Starts on the bench", isOn: $draft.usuals.startsOnBench)
                } footer: {
                    Text("Pregame starts the lineup from these.")
                }

                if !draft.isNew {
                    Section {
                        Button("Remove from team", role: .destructive) { confirmsRemove = true }
                    }
                }
            }
            .navigationTitle(draft.isNew ? "New player" : "Edit player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.bold)
                }
            }
            .confirmationDialog("Remove \(draft.player.displayName) from the \(team.name)?",
                                isPresented: $confirmsRemove, titleVisibility: .visible) {
                Button("Remove", role: .destructive) { remove() }
            } message: {
                Text("Games already played keep them in their box scores.")
            }
        }
    }

    /// Hands back the team with the player saved, and their usual position and role if changed.
    private func save() {
        var player = draft.player
        player.number = number.trimmingCharacters(in: .whitespaces).nilIfEmpty
        player.name = name.trimmingCharacters(in: .whitespaces).nilIfEmpty
        onRequest(.saveTeam(team.saving(player)))
        if draft.usuals != originalUsuals {
            onRequest(.setUsuals(draft.usuals, for: player.id))
        }
        dismiss()
    }

    /// Hands back the team without the player, and says their introduction's sound file is no longer used.
    private func remove() {
        onRequest(.saveTeam(team.removing(draft.player.id)))
        onRequest(.setUsuals(PlayerUsuals(), for: draft.player.id))
        if let introduction = draft.player.introduction, introduction.fileName != nil {
            onRequest(.introductionReplaced(introduction))
        }
        dismiss()
    }
}
