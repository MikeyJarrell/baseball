// A fix to who was in a game, made from the lineups page while the game is being scored: the
// other team's lineup card arrives late, or the wrong player was picked. The game session
// (Scoring) carries it out.

import Foundation

/// A fix to who was in the game, from the lineups page.
public enum LineupCorrection: Equatable, Sendable {
    /// The player shown in the game was really this other player all along (the lineup card
    /// came late, or the wrong name was picked): the two trade places in the whole game,
    /// including everything already recorded. A player new to the team is added to its roster.
    case wasReally(side: TeamSide, shown: PlayerID, really: Player)
    /// Takes a hitter out of the starting batting order. Only before the first pitch.
    case removeFromOrder(side: TeamSide, player: PlayerID)
}
