// Saving a player changed during a game onto the saved team.
//
// A game keeps its own copy of both rosters, made at the first pitch. When the scorer fills in
// a name, a number or a batting side during the game, the change goes onto the saved team as
// well, so it is there next game. But the game's copy also carries the songs and announcer
// introduction as they were at the first pitch, and the scorer may have changed those on the
// team pages since. Only what the game's sheets edit is copied across.

import Model

extension Player {
    /// The saved team's player with the details a game's sheets can change (name, number,
    /// stand-in label, batting side, throwing hand) taken from this game copy. Songs, the
    /// introduction, and the usual position and role stay as the saved team has them.
    public func savedCopy(updating saved: Player) -> Player {
        var updated = saved
        updated.name = name
        updated.number = number
        updated.placeholder = placeholder
        updated.bats = bats
        updated.throwsWith = throwsWith
        return updated
    }
}
