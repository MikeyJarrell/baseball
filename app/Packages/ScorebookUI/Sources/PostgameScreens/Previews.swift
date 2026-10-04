// Previews of the postgame and season screens, from SampleData and the made-up seasons in
// PreviewSeason. Each comes in light mode; the main ones also in dark mode and at the largest
// accessibility text size. The brief's finish line is covered by: the twelve-player team's
// totals and the one-game season (SampleSeason.totals, both), and a player with no at-bats
// (Robin Nash, who did not play, and Taylor Voss, who only pitched).

import SwiftUI
import Model
import SampleData
import DesignSystem

/// Wraps a screen in a navigation stack, as the app shell will.
private struct InNavigation<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        NavigationStack { content }
    }
}

/// Prints a request to the console, so previews show what the screen hands back.
private func log(_ request: PostgameRequest) {
    print("Postgame request:", request)
}

// MARK: - End of game

#Preview("End of game") {
    InNavigation { EndOfGameScreen(box: SampleGame.boxScore, ourSide: .home, onRequest: log) }
}

#Preview("End of game, dark") {
    InNavigation { EndOfGameScreen(box: SampleGame.boxScore, ourSide: .home, onRequest: log) }
        .preferredColorScheme(.dark)
}

#Preview("End of game, largest text") {
    InNavigation { EndOfGameScreen(box: SampleGame.boxScore, ourSide: .home, onRequest: log) }
        .dynamicTypeSize(.accessibility5)
}

#Preview("Box score so far, from the games list") {
    InNavigation {
        EndOfGameScreen(box: SampleGame.boxScoreThroughThree, ourSide: .home, showsDoneButton: false, onRequest: log)
    }
}

#Preview("End of game, picture slot filled") {
    // A stand-in for the newspaper picture: 375 points wide, like the real one, to show it
    // shrinks to fit.
    InNavigation {
        EndOfGameScreen(box: SampleGame.boxScore, ourSide: .home, onRequest: log) {
            Text("Newspaper picture goes here")
                .font(ScorebookFont.newspaperHeadline)
                .foregroundStyle(ScorebookColor.newspaperInk)
                .frame(width: 375, height: 500)
                .background(ScorebookColor.newspaperPaper)
        } shareButton: {
            Button("Share link goes here") {}.buttonStyle(TeamButtonStyle(.ours))
        }
    }
}

// MARK: - Games list

#Preview("Games list") {
    InNavigation { GamesListScreen(games: PreviewSeason.games, unreadableGames: 1, onRequest: log) }
}

#Preview("Games list, dark") {
    InNavigation { GamesListScreen(games: PreviewSeason.games, onRequest: log) }
        .preferredColorScheme(.dark)
}

#Preview("Games list, largest text") {
    InNavigation { GamesListScreen(games: PreviewSeason.games, onRequest: log) }
        .dynamicTypeSize(.accessibility5)
}

#Preview("Games list, one game") {
    InNavigation { GamesListScreen(games: SampleSeason.games, onRequest: log) }
}

#Preview("Games list, empty") {
    InNavigation { GamesListScreen(games: [], onRequest: log) }
}

// MARK: - Season stats

#Preview("Season, twelve players, one game") {
    // The one-game season: with the filter at its usual 10 plate appearances every average is
    // hidden, so the filter starts off here to show them.
    InNavigation {
        SeasonStatsScreen(totals: SampleSeason.totals,
                          minimumPlateAppearances: 0, onRequest: log)
    }
}

#Preview("Season, one game, filter on") {
    InNavigation { SeasonStatsScreen(totals: SampleSeason.totals, onRequest: log) }
}

#Preview("Season, fourteen games") {
    InNavigation {
        SeasonStatsScreen(totals: PreviewSeason.fourteenGames, onRequest: log)
    }
}

#Preview("Season, fourteen games, dark") {
    InNavigation {
        SeasonStatsScreen(totals: PreviewSeason.fourteenGames, onRequest: log)
    }
    .preferredColorScheme(.dark)
}

#Preview("Season, largest text") {
    InNavigation {
        SeasonStatsScreen(totals: PreviewSeason.fourteenGames, onRequest: log)
    }
    .dynamicTypeSize(.accessibility5)
}

#Preview("Season, no games yet") {
    InNavigation {
        SeasonStatsScreen(totals: SeasonTotals(teamID: "diamond-dogs", teamName: "Diamond Dogs", games: 0,
                                               batting: [], pitching: [], fielding: []),
                          onRequest: log)
    }
}

// MARK: - Player page

#Preview("Player, one game") {
    InNavigation { PlayerSeasonScreen(totals: SampleSeason.totals, player: "d1", onRequest: log) }
}

#Preview("Player, three games") {
    InNavigation { PlayerSeasonScreen(totals: PreviewSeason.morenoThreeGames, player: "d1", onRequest: log) }
}

#Preview("Player, three games, dark") {
    InNavigation { PlayerSeasonScreen(totals: PreviewSeason.morenoThreeGames, player: "d1", onRequest: log) }
        .preferredColorScheme(.dark)
}

#Preview("Player, three games, largest text") {
    InNavigation { PlayerSeasonScreen(totals: PreviewSeason.morenoThreeGames, player: "d1", onRequest: log) }
        .dynamicTypeSize(.accessibility5)
}

#Preview("Player with no at-bats (did not play)") {
    InNavigation { PlayerSeasonScreen(totals: SampleSeason.totals, player: "d11", onRequest: log) }
}

#Preview("Pitcher with no at-bats") {
    InNavigation { PlayerSeasonScreen(totals: SampleSeason.totals, player: "d12", onRequest: log) }
}

#Preview("Pitcher who also batted") {
    InNavigation { PlayerSeasonScreen(totals: SampleSeason.totals, player: "d9", onRequest: log) }
}
