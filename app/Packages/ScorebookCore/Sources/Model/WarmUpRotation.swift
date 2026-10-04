// Which warm-up song plays when our team takes the field.
//
// A pitcher has a main warm-up song and may have extra ones. His first inning of each game
// gets the main song. Every later inning gets an extra song he has not heard yet this game,
// picked at random; once he has heard them all, they are shuffled again, never repeating
// the song that just played.

import Foundation

public enum WarmUpRotation {
    /// The warm-up song for a pitcher's next inning.
    ///
    /// - Parameters:
    ///   - pitcher: Our pitcher, with his main and extra warm-up songs.
    ///   - alreadyPlayed: The warm-up songs played for him earlier this game, oldest first.
    ///   - random: Where the random picks come from (a fixed one in tests).
    /// - Returns: The song to play, or nil when he has no warm-up song at all.
    public static func nextSong<R: RandomNumberGenerator>(
        for pitcher: Player, alreadyPlayed: [SongID], using random: inout R
    ) -> SongID? {
        let extras = pitcher.extraWarmUpSongIDs.filter { $0 != pitcher.warmUpSongID }
        // His first inning, or no extras to choose from: the main song.
        if let main = pitcher.warmUpSongID, alreadyPlayed.isEmpty || extras.isEmpty { return main }
        guard !extras.isEmpty else { return nil }
        // Later innings go through the extras in passes. Within a pass, each extra plays once.
        let extrasPlayed = alreadyPlayed.filter { extras.contains($0) }
        let intoPass = extrasPlayed.count % extras.count
        if intoPass > 0 {
            let heardThisPass = extrasPlayed.suffix(intoPass)
            return extras.filter { !heardThisPass.contains($0) }.randomElement(using: &random)
        }
        // A new pass: any extra, but not the song that just played.
        let fresh = extras.filter { $0 != alreadyPlayed.last }
        return (fresh.isEmpty ? extras : fresh).randomElement(using: &random)
    }

    /// The same, with the system's random numbers.
    public static func nextSong(for pitcher: Player, alreadyPlayed: [SongID]) -> SongID? {
        var random = SystemRandomNumberGenerator()
        return nextSong(for: pitcher, alreadyPlayed: alreadyPlayed, using: &random)
    }
}
