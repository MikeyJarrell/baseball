// Previews of the pregame steps, driven by PregameSamples (built from SampleData): a game
// against the full-roster Mudcats, the numbers-only Bombers and the Riverhawks (no saved
// roster, so blank numbers), our lineup before the first game, in light and dark mode and at
// the largest text size.

import SwiftUI
import Model
import DesignSystem

#Preview("1. The game") {
    PregameFlow(input: PregameSamples.input) { _ in }
}

#Preview("1. The game, Mudcats picked, dark") {
    PregameFlow.sample(against: "mudcats", at: .game).preferredColorScheme(.dark)
}

#Preview("2. Batting order, from last game") {
    PregameFlow.sample(against: "mudcats", at: .ours)
}

#Preview("2. Batting order, before the first game") {
    PregameFlow.sample(against: "mudcats", at: .ours, firstGame: true)
}

#Preview("2. Batting order, dark") {
    PregameFlow.sample(against: "mudcats", at: .ours).preferredColorScheme(.dark)
}

#Preview("2. Batting order, largest text") {
    PregameFlow.sample(against: "mudcats", at: .ours).environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("3. Fielders") {
    PregameFlow.sample(against: "mudcats", at: .fielding)
}

#Preview("3. Fielders, dark") {
    PregameFlow.sample(against: "mudcats", at: .fielding).preferredColorScheme(.dark)
}

#Preview("3. Fielders, largest text") {
    PregameFlow.sample(against: "mudcats", at: .fielding).environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("4. Mudcats, names and numbers") {
    PregameFlow.sample(against: "mudcats", at: .theirs)
}

#Preview("4. Bombers, numbers only") {
    PregameFlow.sample(against: "bombers", at: .theirs)
}

#Preview("4. Riverhawks, blank numbers") {
    PregameFlow.sample(against: "riverhawks", at: .theirs)
}

#Preview("4. Bombers, dark") {
    PregameFlow.sample(against: "bombers", at: .theirs).preferredColorScheme(.dark)
}

#Preview("5. Starting pitchers, Mudcats") {
    PregameFlow.sample(against: "mudcats", at: .pitchers)
}

#Preview("5. Starting pitchers, Riverhawks, largest text") {
    PregameFlow.sample(against: "riverhawks", at: .pitchers).environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("6. Review, Mudcats") {
    PregameFlow.sample(against: "mudcats", at: .review)
}

#Preview("6. Review, Bombers") {
    PregameFlow.sample(against: "bombers", at: .review)
}

#Preview("6. Review, Riverhawks, dark") {
    PregameFlow.sample(against: "riverhawks", at: .review).preferredColorScheme(.dark)
}

#Preview("6. Review, largest text") {
    PregameFlow.sample(against: "mudcats", at: .review).environment(\.dynamicTypeSize, .accessibility5)
}
