// Rosters, from the game menu: both teams' starting lineups on the same screens as game setup
// (batting order and fielders for each team), for finishing the lineups after a rushed start.
// The page hands back both teams as edited; the app shell has the game session apply them, so
// everything already recorded follows the batting order spot by spot.

import SwiftUI
import Model
import DesignSystem

/// Both teams' starting lineups, to fix during the game. Hands back the edited teams on Done.
public struct LineupEditorPage: View {
    /// The game's setup as it is now.
    var setup: GameSetup
    /// Called with both teams, as edited, when the scorer taps Done.
    var onDone: (_ away: GameTeam, _ home: GameTeam) -> Void
    var onCancel: () -> Void

    @State private var draft: PregameDraft
    @State private var path: [PregameStep] = []

    /// Our side (the home team in a game between two other teams).
    private let ourSide: TeamSide

    public init(setup: GameSetup, onDone: @escaping (_ away: GameTeam, _ home: GameTeam) -> Void, onCancel: @escaping () -> Void) {
        self.setup = setup
        self.onDone = onDone
        self.onCancel = onCancel
        let side = setup.ourSide ?? .home
        ourSide = side
        _draft = State(initialValue: Self.draft(from: setup, ourSide: side))
    }

    /// The setup's two lineups as a pregame draft, so the setup screens can edit them.
    static func draft(from setup: GameSetup, ourSide: TeamSide) -> PregameDraft {
        let ours = setup[ourSide], theirs = setup[ourSide.opponent]
        let ourTeam = Team(id: ours.teamID, name: ours.name, isOurs: true, roster: ours.roster, shortName: ours.shortName)
        let theirTeam = Team(id: theirs.teamID, name: theirs.name, roster: theirs.roster, shortName: theirs.shortName)
        var draft = PregameDraft(input: PregameInput(ourTeam: ourTeam, opponents: [theirTeam], today: setup.scheduledStart))
        draft.ours = OurLineup.fromLastGame(ours, roster: ours.roster)
        draft.chooseOpponent(.saved(theirTeam.id))
        var lineup = TheirLineup(mode: .names, namedOrder: theirs.battingOrder, pitcher: theirs.startingPitcher)
        lineup.nonRunners = theirs.designatedNonRunners
        for spot in theirs.defense where spot.position != .pitcher { lineup.fielders[spot.position] = spot.player }
        draft.theirs = lineup
        return draft
    }

    public var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    row("Batting order", .ours)
                    row("Fielders", .fielding)
                } header: {
                    SectionHeader(title: draft.input.ourTeam.name)
                }
                Section {
                    row("Batting order", .theirs)
                    row("Fielders", .theirFielding)
                } header: {
                    SectionHeader(title: draft.opponentName)
                }
                Section {
                    Text("These are the lineups at the first pitch. Plays already recorded follow each batting spot.")
                        .font(ScorebookFont.caption)
                        .foregroundStyle(ScorebookColor.textSecondary)
                        .bareRow()
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(ScorebookColor.background)
            .navigationTitle("Rosters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: onCancel) }
                ToolbarItem(placement: .confirmationAction) { Button("Done", action: finish).bold() }
            }
            .navigationDestination(for: PregameStep.self) { step in
                Group {
                    switch step {
                    case .ours: BattingOrderStep(draft: $draft, onNext: back)
                    case .fielding: FieldingStep(draft: $draft, onNext: back)
                    case .theirs: TheirLineupStep(draft: $draft, onNext: back)
                    default: FieldingStep(draft: $draft, ours: false, onNext: back)
                    }
                }
                .environment(\.editingInGame, true)
            }
        }
        .tint(ScorebookColor.inPlay)
    }

    /// One page to open.
    private func row(_ title: String, _ step: PregameStep) -> some View {
        Button { path.append(step) } label: {
            HStack {
                Text(title).font(ScorebookFont.headline).foregroundStyle(ScorebookColor.textPrimary)
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(ScorebookColor.textSecondary)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .cardRow()
    }

    private func back() { if !path.isEmpty { path.removeLast() } }

    /// Hands back both teams as edited.
    private func finish() {
        let ourTeam = Team(id: setup[ourSide].teamID, name: setup[ourSide].name, isOurs: true, shortName: setup[ourSide].shortName)
        let ours = draft.ours.gameTeam(for: ourTeam, handEdits: draft.handEdits)
        let theirs = draft.opponent.map { draft.theirs.gameTeam(for: $0, handEdits: draft.handEdits) } ?? setup[ourSide.opponent]
        onDone(ourSide == .away ? ours : theirs, ourSide == .home ? ours : theirs)
    }
}

// MARK: - Editing during a game

/// True when a setup screen is open from Rosters during a game: its big button says "Done"
/// and goes back, with no step dots and no Skip.
private struct EditingInGameKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var editingInGame: Bool {
        get { self[EditingInGameKey.self] }
        set { self[EditingInGameKey.self] = newValue }
    }
}
