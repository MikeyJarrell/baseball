// PostgameScreens: what the scorer sees once a game is over, and the season so far.
//
// Four screens, matching the approved mockup (plan/mockups/index.html: "End of game",
// "Season stats" and "Games list"):
//   1. EndOfGameScreen: the final score, who won and lost on the mound, how long the game took,
//      the box score, and buttons to share it, copy it as text, or see the season.
//   2. GamesListScreen: every game, newest first, with date, opponent and result.
//   3. SeasonStatsScreen: our hitters and pitchers in sortable tables, names pinned on the left
//      while the numbers scroll sideways, with a minimum plate appearances filter for averages.
//   4. PlayerSeasonScreen: one player's season line and game-by-game log.
//
// Like every screen, these are handed plain data (a box score, season totals, the games list)
// and never work anything out about baseball: the stats engine adds everything up. They only
// sort and filter what they show. Every tap that leaves the screen comes back as a
// `PostgameRequest`, and the app shell acts on it.
//
// The newspaper-style picture and its share sheet live in the BoxScorePicture module, which a
// screen may not import. The end-of-game screen leaves two slots for them; until the wiring job
// fills the slots, it shows the box score as a plain table and a share button that hands back
// a request.
//
// The other files in this folder: EndOfGameScreen, BoxScoreTable (the plain table),
// GamesListScreen, SeasonStatsScreen, StatsTable (the table with the pinned name column),
// StatColumns (the columns and how they sort), PlayerSeasonScreen, PostgameWording (the words
// on screen), PreviewSeason (made-up seasons for previews) and Previews.
//
// Screens here may use Model, SampleData and DesignSystem, and nothing else.

import SwiftUI
import Model
import SampleData
import DesignSystem

/// Everything the postgame and season screens ask the app shell to do.
public enum PostgameRequest: Equatable, Sendable {
    /// Leave the end-of-game screen (its Done button).
    case done
    /// Share this game's box score picture, such as by text message. Sent only by the plain
    /// share button shown until the wiring job puts the real share button in its slot.
    case shareBoxScore(GameID)
    /// Copy this game's box score as plain text, for email.
    case copyBoxScoreText(GameID)
    /// Open the season stats.
    case openSeasonStats
    /// Open one game's box score, from the games list or a player's game log.
    case openGame(GameID)
    /// Open one player's page: their season line and game log.
    case openPlayer(PlayerID)
    /// The scorer picked a new minimum plate appearances for hitters' averages. Keep it and
    /// hand it back as `minimumPlateAppearances` the next time the season stats open.
    case setMinimumPlateAppearances(Int)
    /// The scorer picked a new minimum innings pitched for pitchers' per-inning rates. Keep it
    /// and hand it back as `minimumInnings` the next time the season stats open.
    case setMinimumInnings(Int)
    /// Delete this game, after the scorer confirmed. The app writes a backup first.
    case deleteGame(GameID)
}
