// The games list: every game, newest first, with the opponent, the date and the result
// ("W 7–5"). Tapping a game asks for its box score. As in the approved mockup.

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
///   - onRequest: Called with the game the scorer taps.
public struct GamesListScreen: View {
    public var games: [GameSummary]
    public var unreadableGames: Int
    public var onRequest: (PostgameRequest) -> Void

    public init(games: [GameSummary], unreadableGames: Int = 0, onRequest: @escaping (PostgameRequest) -> Void) {
        self.games = games
        self.unreadableGames = unreadableGames
        self.onRequest = onRequest
    }

    /// Newest first. Games on the same day keep the order they were handed in.
    static func newestFirst(_ games: [GameSummary]) -> [GameSummary] {
        games.enumerated()
            .sorted { a, b in
                a.element.date != b.element.date ? a.element.date > b.element.date : a.offset < b.offset
            }
            .map(\.element)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                if games.isEmpty {
                    Text("No games yet. A game shows up here once it starts.")
                        .font(ScorebookFont.body)
                        .foregroundStyle(ScorebookColor.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Spacing.large)
                        .background(ScorebookColor.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                } else {
                    VStack(spacing: 0) {
                        let ordered = Self.newestFirst(games)
                        ForEach(ordered) { game in
                            GameRow(game: game) { onRequest(.openGame(game.id)) }
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
    }
}

/// One game in the list: "vs Mudcats" over "Sat, Oct 3", and the result on the right.
private struct GameRow: View {
    var game: GameSummary
    var onTap: () -> Void

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
                }
                Spacer(minLength: Spacing.small)
                result
                Image(systemName: "chevron.right")
                    .font(ScorebookFont.caption.weight(.semibold))
                    .foregroundStyle(ScorebookColor.textSecondary)
            }
            .padding(.horizontal, Spacing.large)
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

    private func color(for outcome: PostgameWording.Outcome) -> Color {
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
