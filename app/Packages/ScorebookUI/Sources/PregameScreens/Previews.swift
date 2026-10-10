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

#Preview("2. Home or away") {
    PregameFlow.sample(against: "mudcats", at: .homeOrAway)
}

#Preview("3. Date and start") {
    PregameFlow.sample(against: "mudcats", at: .when)
}

#Preview("3. Date and start, largest text") {
    PregameFlow.sample(against: "mudcats", at: .when).environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("4. Game length") {
    PregameFlow.sample(against: "mudcats", at: .length)
}

#Preview("4. Game length, dark") {
    PregameFlow.sample(against: "mudcats", at: .length).preferredColorScheme(.dark)
}

#Preview("5. Batting order, from last game") {
    PregameFlow.sample(against: "mudcats", at: .ours)
}

#Preview("5. Batting order, before the first game") {
    PregameFlow.sample(against: "mudcats", at: .ours, firstGame: true)
}

#Preview("5. Batting order, dark") {
    PregameFlow.sample(against: "mudcats", at: .ours).preferredColorScheme(.dark)
}

#Preview("5. Batting order, largest text") {
    PregameFlow.sample(against: "mudcats", at: .ours).environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("6. Fielders") {
    PregameFlow.sample(against: "mudcats", at: .fielding)
}

#Preview("6. Fielders, dark") {
    PregameFlow.sample(against: "mudcats", at: .fielding).preferredColorScheme(.dark)
}

#Preview("6. Fielders, largest text") {
    PregameFlow.sample(against: "mudcats", at: .fielding).environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("7. Mudcats, names and numbers") {
    PregameFlow.sample(against: "mudcats", at: .theirs)
}

#Preview("7. Bombers, numbers only") {
    PregameFlow.sample(against: "bombers", at: .theirs)
}

#Preview("7. Riverhawks, blank numbers") {
    PregameFlow.sample(against: "riverhawks", at: .theirs)
}

#Preview("7. Mudcats, largest text") {
    PregameFlow.sample(against: "mudcats", at: .theirs).environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("7. Bombers, numbers only, largest text") {
    PregameFlow.sample(against: "bombers", at: .theirs).environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("7. Bombers, dark") {
    PregameFlow.sample(against: "bombers", at: .theirs).preferredColorScheme(.dark)
}

#Preview("8. Our starting pitcher") {
    PregameFlow.sample(against: "mudcats", at: .ourPitcher)
}

#Preview("9. Their starting pitcher, Mudcats") {
    PregameFlow.sample(against: "mudcats", at: .theirPitcher)
}

#Preview("9. Their starting pitcher, Riverhawks, largest text") {
    PregameFlow.sample(against: "riverhawks", at: .theirPitcher).environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("10. Review, Mudcats") {
    PregameFlow.sample(against: "mudcats", at: .review)
}

#Preview("10. Review, Bombers") {
    PregameFlow.sample(against: "bombers", at: .review)
}

#Preview("10. Review, Riverhawks, dark") {
    PregameFlow.sample(against: "riverhawks", at: .review).preferredColorScheme(.dark)
}

#Preview("10. Review, largest text") {
    PregameFlow.sample(against: "mudcats", at: .review).environment(\.dynamicTypeSize, .accessibility5)
}
