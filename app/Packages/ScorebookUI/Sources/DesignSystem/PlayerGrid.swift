// A grid of players to pick from, for the pages that ask who plays a position. Every player
// shows at once, two to a row (three for a big roster), so a pick is one tap with no scrolling
// on a phone: the name, with a smaller line under it saying where they are now. The player
// already there is filled blue.

import SwiftUI
import Model

/// Players to pick from, laid out in a grid. Tapping one hands back their id.
public struct PlayerGrid: View {
    /// One player in the grid.
    public struct Choice: Identifiable, Equatable, Sendable {
        public var id: PlayerID
        /// "Jon Marianowits", or "#22".
        public var name: String
        /// Where they are now: "SS · bats 3rd", "Bench".
        public var detail: String?
        /// True for the player already at the position.
        public var isChosen: Bool

        public init(id: PlayerID, name: String, detail: String? = nil, isChosen: Bool = false) {
            self.id = id
            self.name = name
            self.detail = detail
            self.isChosen = isChosen
        }
    }

    var choices: [Choice]
    var onPick: (PlayerID) -> Void

    public init(_ choices: [Choice], onPick: @escaping (PlayerID) -> Void) {
        self.choices = choices
        self.onPick = onPick
    }

    @Environment(\.dynamicTypeSize) private var typeSize

    public var body: some View {
        // Three to a row only for a roster too big for two rows of ten; one at the largest text sizes.
        let count = typeSize.isAccessibilitySize ? 1 : (choices.count > 20 ? 3 : 2)
        let columns = Array(repeating: GridItem(.flexible(), spacing: Spacing.small), count: count)
        LazyVGrid(columns: columns, spacing: Spacing.small) {
            ForEach(choices) { choice in
                cell(choice)
            }
        }
    }

    /// One player's button: the name over where they are now.
    private func cell(_ choice: Choice) -> some View {
        let shape = RoundedRectangle(cornerRadius: Spacing.cornerRadius, style: .continuous)
        return Button { onPick(choice.id) } label: {
            VStack(alignment: .leading, spacing: 1) {
                Text(choice.name)
                    .font(ScorebookFont.headline)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .multilineTextAlignment(.leading)
                if let detail = choice.detail {
                    Text(detail)
                        .font(ScorebookFont.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(choice.isChosen ? Color.white.opacity(0.85) : ScorebookColor.textSecondary)
                }
            }
            .foregroundStyle(choice.isChosen ? Color.white : ScorebookColor.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
            .padding(.horizontal, Spacing.medium)
            .padding(.vertical, Spacing.extraSmall)
            .background(choice.isChosen ? ScorebookColor.highlight : ScorebookColor.surface, in: shape)
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text([choice.name, choice.detail].compactMap { $0 }.joined(separator: ", ")))
        .accessibilityAddTraits(choice.isChosen ? .isSelected : [])
    }
}

#Preview("Seventeen players") {
    ScrollView {
        PlayerGrid((1...17).map { i in
            PlayerGrid.Choice(id: PlayerID(rawValue: "p\(i)"), name: "Player Number \(i)",
                              detail: i == 3 ? "SS · bats 3rd" : "Bench", isChosen: i == 3)
        }, onPick: { _ in })
        .padding()
    }
    .background(ScorebookColor.background)
}
