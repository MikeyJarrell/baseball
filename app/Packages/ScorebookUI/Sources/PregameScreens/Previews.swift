// Previews of the pregame steps, driven by PregameSamples (built from SampleData): a game
// against the full-roster Mudcats, the numbers-only Bombers and the Riverhawks (no saved
// roster, so blank numbers), our lineup before the first game, in light and dark mode and at
// the largest text size.

import SwiftUI
import Model
import DesignSystem

#Preview("1. Opponent") {
    PregameFlow(input: PregameSamples.input) { _ in }
}

#Preview("1. Opponent, Mudcats picked, dark") {
    PregameFlow.sample(against: "mudcats", at: .opponent).preferredColorScheme(.dark)
}

#Preview("2. Game details") {
    PregameFlow.sample(against: "mudcats", at: .game)
}

#Preview("2. Game details, dark") {
    PregameFlow.sample(against: "mudcats", at: .game).preferredColorScheme(.dark)
}

#Preview("2. Game details, largest text") {
    PregameFlow.sample(against: "mudcats", at: .game).environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("3. Batting order, from last game") {
    PregameFlow.sample(against: "mudcats", at: .ours)
}

#Preview("3. Batting order, before the first game") {
    PregameFlow.sample(against: "mudcats", at: .ours, firstGame: true)
}

#Preview("3. Batting order, dark") {
    PregameFlow.sample(against: "mudcats", at: .ours).preferredColorScheme(.dark)
}

#Preview("3. Batting order, largest text") {
    PregameFlow.sample(against: "mudcats", at: .ours).environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("4. Fielders") {
    PregameFlow.sample(against: "mudcats", at: .fielding)
}

#Preview("4. Fielders, dark") {
    PregameFlow.sample(against: "mudcats", at: .fielding).preferredColorScheme(.dark)
}

#Preview("4. Fielders, largest text") {
    PregameFlow.sample(against: "mudcats", at: .fielding).environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("5. Mudcats, names and numbers") {
    PregameFlow.sample(against: "mudcats", at: .theirs)
}

#Preview("5. Bombers, numbers only") {
    PregameFlow.sample(against: "bombers", at: .theirs)
}

#Preview("5. Riverhawks, blank numbers") {
    PregameFlow.sample(against: "riverhawks", at: .theirs)
}

#Preview("5. Mudcats, largest text") {
    PregameFlow.sample(against: "mudcats", at: .theirs).environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("5. Bombers, numbers only, largest text") {
    PregameFlow.sample(against: "bombers", at: .theirs).environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("5. Bombers, dark") {
    PregameFlow.sample(against: "bombers", at: .theirs).preferredColorScheme(.dark)
}

#Preview("6. Starting pitchers, Mudcats") {
    PregameFlow.sample(against: "mudcats", at: .pitchers)
}

#Preview("6. Starting pitchers, Riverhawks, largest text") {
    PregameFlow.sample(against: "riverhawks", at: .pitchers).environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("7. Review, Mudcats") {
    PregameFlow.sample(against: "mudcats", at: .review)
}

#Preview("7. Review, Bombers") {
    PregameFlow.sample(against: "bombers", at: .review)
}

#Preview("7. Review, Riverhawks, dark") {
    PregameFlow.sample(against: "riverhawks", at: .review).preferredColorScheme(.dark)
}

#Preview("7. Review, largest text") {
    PregameFlow.sample(against: "mudcats", at: .review).environment(\.dynamicTypeSize, .accessibility5)
}
