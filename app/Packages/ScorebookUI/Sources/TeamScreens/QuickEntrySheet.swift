// Quick entry: typing a whole roster in a row. One line per player, "22 Jordan Webb", then
// Return: the player is saved, the line clears, and the keyboard stays up for the next one.
// Batting side, throwing hand and usual position are one optional tap each beside the line;
// they start as right-handed with no position for our team, and unknown for an opponent.
// Every player is saved the moment they are added, so a dead battery loses nothing.

import SwiftUI
import Model
import DesignSystem

/// Type a whole roster in a row.
struct QuickEntrySheet: View {
    var team: Team
    var onRequest: (TeamScreensRequest) -> Void

    @State private var line = ""
    @State private var bats: BattingSide?
    @State private var throwsWith: Hand?
    @State private var position: Position?
    /// The players added since the sheet opened, newest first.
    @State private var added: [Player] = []
    @FocusState private var typing: Bool
    @Environment(\.dismiss) private var dismiss

    init(team: Team, onRequest: @escaping (TeamScreensRequest) -> Void) {
        self.team = team
        self.onRequest = onRequest
        _bats = State(initialValue: team.isOurs ? .right : nil)
        _throwsWith = State(initialValue: team.isOurs ? .right : nil)
    }

    /// The typed line, read into a number and a name.
    private var parsed: QuickEntryLine { QuickEntryLine(line) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.medium) {
                    entryCard
                    if !added.isEmpty { addedList }
                }
                .padding(.horizontal, Spacing.large)
                .padding(.vertical, Spacing.small)
            }
            .scrollDismissesKeyboard(.never)
            .teamPageBackground()
            .navigationTitle("Quick entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.bold)
                }
            }
            .onAppear { typing = true }
        }
    }

    /// The typing line, what it will add, the three optional choices and the Add button.
    private var entryCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                Text(team.name + " · " + TeamWording.playerCount(team.roster.count))
                    .font(ScorebookFont.caption.weight(.semibold))
                    .foregroundStyle(ScorebookColor.textSecondary)

                TextField("Number and name: 22 Jordan Webb", text: $line)
                    .font(.title3.weight(.semibold))
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .focused($typing)
                    .onSubmit(add)
                    .padding(.horizontal, Spacing.medium)
                    .frame(minHeight: 52)
                    .background(ScorebookColor.surfaceSecondary, in: RoundedRectangle(cornerRadius: Spacing.cornerRadius, style: .continuous))

                Text(lineHint)
                    .font(ScorebookFont.caption)
                    .foregroundStyle(TeamWording.playerWearing(parsed.number, in: team) == nil
                                     ? ScorebookColor.textSecondary : ScorebookColor.ourTeamText)

                labeled("Bats") { ClearableSegments(options: HandChoices.bats, selection: $bats) }
                labeled("Throws") { ClearableSegments(options: HandChoices.throwsWith, selection: $throwsWith) }
                labeled("Usual position") { positionChips }

                Button(action: add) {
                    Label("Add player", systemImage: "plus")
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(parsed.isEmpty)
            }
        }
    }

    /// The line under the typing field: what Return will add, or how to type it.
    private var lineHint: String {
        if parsed.isEmpty { return "Number first, then the name. Return adds the player." }
        if let twin = TeamWording.playerWearing(parsed.number, in: team) {
            return parsed.preview + " · \(twin.displayName) also wears \(parsed.number ?? "")"
        }
        return parsed.preview + " · Return adds"
    }

    /// The nine positions as small chips, one tap each; tapping the chosen one clears it.
    private var positionChips: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 9), spacing: 4) {
            ForEach(Position.allCases, id: \.self) { spot in
                let isOn = position == spot
                Button {
                    position = isOn ? nil : spot
                } label: {
                    Text(spot.abbreviation.uppercased())
                        .font(ScorebookFont.chip)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .foregroundStyle(isOn ? .white : ScorebookColor.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: Spacing.minimumTapSize)
                        .background(isOn ? ScorebookColor.inPlay : ScorebookColor.surfaceSecondary,
                                    in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(spot.name)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    /// A small label above a choice.
    private func labeled<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.extraSmall) {
            Text(title)
                .font(ScorebookFont.sectionLabel)
                .foregroundStyle(ScorebookColor.textSecondary)
            content()
        }
    }

    /// The players added since the sheet opened, newest first.
    private var addedList: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel("Added just now", trailing: "\(added.count)")
            Card(padding: 0) {
                ForEach(added) { player in
                    HStack(spacing: Spacing.medium) {
                        NumberBadge(player: player, look: team.isOurs ? .ours : .theirs, size: 36)
                        Text(player.displayName).font(ScorebookFont.headline)
                        Spacer()
                        Text(TeamWording.handedness(player))
                            .font(ScorebookFont.caption)
                            .foregroundStyle(ScorebookColor.textSecondary)
                    }
                    .padding(.horizontal, Spacing.large - 2)
                    .frame(minHeight: 50)
                    if player.id != added.last?.id { Divider().padding(.leading, 62) }
                }
            }
        }
    }

    /// Saves the typed player, clears the line for the next one, and keeps the keyboard up.
    private func add() {
        let entry = parsed
        guard !entry.isEmpty else { return }
        let player = entry.player(bats: bats, throwsWith: throwsWith)
        // Build on the team as handed in, plus anyone added here that has not come back yet,
        // so two quick adds never lose the first.
        let current = added.reduce(team) { team, earlier in team.player(earlier.id) == nil ? team.saving(earlier) : team }
        onRequest(.saveTeam(current.saving(player)))
        if let position {
            onRequest(.setUsuals(PlayerUsuals(position: position), for: player.id))
        }
        added.insert(player, at: 0)
        line = ""
        bats = team.isOurs ? .right : nil
        throwsWith = team.isOurs ? .right : nil
        position = nil
        typing = true
    }
}
