// The games list: every game, newest first, with the opponent, the date and the result
// ("W 7–5"). Tapping a game asks for its box score. As in the approved mockup.
//
// A game can be deleted: Edit in the top bar puts a Delete button on every row (a long press
// on a row offers it too), and a question naming the game comes up before anything happens.

import SwiftUI
import Model
import SampleData
import DesignSystem

/// Every game we have scored.
///
/// - Parameters:
///   - games: The games, in any order; the screen puts the newest first.
///   - unreadableGames: How many saved games could not be read (storage's damaged files), so
///     the scorer knows something is missing. 0 shows nothing.
///   - ourTeamName: Our team's name, for the delete question ("Delete Diamond Dogs vs
///     Mudcats, Oct 4?").
///   - onRequest: Called with the game the scorer taps, or the game to delete once confirmed.
public struct GamesListScreen: View {
    public var games: [GameSummary]
    public var unreadableGames: Int
    public var ourTeamName: String?
    public var onRequest: (PostgameRequest) -> Void

    /// True while the rows show their Delete buttons.
    @State private var editing = false
    /// The game the scorer asked to delete, waiting for them to confirm.
    @State private var deleting: GameSummary?

    public init(games: [GameSummary], unreadableGames: Int = 0, ourTeamName: String? = nil,
                onRequest: @escaping (PostgameRequest) -> Void) {
        self.games = games
        self.unreadableGames = unreadableGames
        self.ourTeamName = ourTeamName
        self.onRequest = onRequest
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                if games.isEmpty {
                    Text("No games yet.")
                        .font(ScorebookFont.body)
                        .foregroundStyle(ScorebookColor.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Spacing.large)
                        .background(ScorebookColor.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                } else {
                    VStack(spacing: 0) {
                        let ordered = StatSorting.newestFirst(games)
                        ForEach(ordered) { game in
                            HStack(spacing: 0) {
                                GameRow(game: game, showsChevron: !editing) { onRequest(.openGame(game.id)) }
                                if editing {
                                    Button("Delete", role: .destructive) { deleting = game }
                                        .font(ScorebookFont.chip)
                                        .buttonStyle(.borderedProminent)
                                        .tint(ScorebookColor.out)
                                        .padding(.trailing, Spacing.medium)
                                        .accessibilityLabel(Text("Delete \(PostgameWording.opponent(game)), \(PostgameWording.listDate(game.date))"))
                                }
                            }
                            .contextMenu {
                                Button("Delete game", systemImage: "trash", role: .destructive) { deleting = game }
                            }
                            if game.id != ordered.last?.id {
                                Rectangle().fill(ScorebookColor.divider).frame(height: 0.5)
                                    .padding(.leading, Spacing.large)
                            }
                        }
                    }
                    .background(ScorebookColor.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                if unreadableGames > 0 {
                    Label(PostgameWording.counted(unreadableGames, "saved game could not be read.",
                                                  "saved games could not be read."),
                          systemImage: "exclamationmark.triangle.fill")
                        .font(ScorebookFont.caption)
                        .foregroundStyle(ScorebookColor.textSecondary)
                        .padding(.horizontal, Spacing.small)
                }
            }
            .padding(.horizontal, Spacing.screenEdge)
            .padding(.vertical, Spacing.small)
        }
        .background(ScorebookColor.background)
        .navigationTitle("Games")
        .toolbar {
            if !games.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(editing ? "Done" : "Edit") { editing.toggle() }
                }
            }
        }
        .confirmationDialog(deleting.map { PostgameWording.deleteQuestion($0, ourTeamName: ourTeamName) } ?? "",
                            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                            titleVisibility: .visible, presenting: deleting) { game in
            Button("Delete game", role: .destructive) {
                onRequest(.deleteGame(game.id))
                deleting = nil
            }
        } message: { _ in
            Text(PostgameWording.deleteWarning)
        }
    }
}

/// One game in the list: "vs Mudcats" over "Sat, Oct 3", and the result on the right.
private struct GameRow: View {
    var game: GameSummary
    /// The arrow on the right; hidden while the Delete buttons show.
    var showsChevron = true
    var onTap: () -> Void

    /// At the accessibility text sizes the result goes under the date instead of beside it.
    @Environment(\.dynamicTypeSize) private var textSize

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.medium) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(PostgameWording.opponent(game))
                        .font(ScorebookFont.headline)
                        .foregroundStyle(ScorebookColor.textPrimary)
                    Text(PostgameWording.listDate(game.date))
                        .font(ScorebookFont.caption)
                        .foregroundStyle(ScorebookColor.textSecondary)
                    if textSize.isAccessibilitySize { result }
                }
                Spacer(minLength: Spacing.small)
                if !textSize.isAccessibilitySize { result }
                if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(ScorebookFont.caption.weight(.semibold))
                        .foregroundStyle(ScorebookColor.textSecondary)
                }
            }
            .padding(.horizontal, Spacing.large)
            .padding(.vertical, Spacing.small)
            .frame(minHeight: 60)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenLabel)
        .accessibilityHint("Opens the box score")
        .accessibilityAddTraits(.isButton)
    }

    /// "W 7–5" in green, "L 3–5" in red, "T 4–4", or "In progress".
    @ViewBuilder
    private var result: some View {
        if let outcome = PostgameWording.outcome(of: game), let score = PostgameWording.scoreOursFirst(game) {
            Text("\(outcome.letter) \(score)")
                .font(ScorebookFont.headline.weight(.heavy).monospacedDigit())
                .foregroundStyle(color(for: outcome))
        } else {
            Text(game.isFinished ? "Final" : "In progress")
                .font(ScorebookFont.chip)
                .foregroundStyle(ScorebookColor.textSecondary)
        }
    }

    private func color(for outcome: GameResult) -> Color {
        switch outcome {
        case .win: ScorebookColor.success
        case .loss: ScorebookColor.out
        case .tie: ScorebookColor.textSecondary
        }
    }

    /// "vs Mudcats, Sat, Oct 3. Won 7 to 5."
    private var spokenLabel: String {
        let start = "\(PostgameWording.opponent(game)), \(PostgameWording.listDate(game.date))."
        if let outcome = PostgameWording.outcome(of: game), let score = PostgameWording.scoreOursFirst(game) {
            return start + " \(outcome.word) \(score.replacingOccurrences(of: "–", with: " to "))."
        }
        return start + (game.isFinished ? " Final." : " In progress.")
    }
}
