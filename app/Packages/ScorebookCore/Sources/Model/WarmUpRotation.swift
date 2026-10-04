// Which warm-up song plays when our team takes the field.
//
// A pitcher has a main warm-up song and may have extra ones. The first inning he starts in a
// game gets the main song. Every later inning gets one of his extra songs: they go by in a
// shuffled order, each once before any repeats, and never the same song two innings running.
//
// Nothing is remembered between changeovers. The song is worked out from the play log (how
// many innings this pitcher has already started) and a shuffle seeded by the game and the
// pitcher, so the same moment always gives the same song: after Undo and Redo, after a
// pitching change at the changeover, and after the app is closed and the game reopened.

import Foundation

public enum WarmUpRotation {
    /// The warm-up song for a pitcher who is about to start an inning.
    ///
    /// - Parameters:
    ///   - pitcher: Our pitcher, with his main and extra warm-up songs.
    ///   - inningsStarted: How many innings he has already started this game (`inningsStarted`
    ///     below): 0 for his first.
    ///   - game: The game, so each game shuffles differently.
    /// - Returns: The song to play, or nil when he has no warm-up song at all.
    public static func song(for pitcher: Player, inningsStarted: Int, game: GameID) -> SongID? {
        // With no main song, his first extra song stands in for it.
        let main = pitcher.warmUpSongID ?? pitcher.extraWarmUpSongIDs.first
        let extras = distinctExtras(of: pitcher, besides: main)
        // His first inning, or no extras to choose from: the main song.
        if inningsStarted == 0 || extras.isEmpty { return main }
        // Later innings go through the extras in passes, each a fresh shuffle.
        let turn = inningsStarted - 1
        let pass = turn / extras.count
        return order(of: extras, pass: pass, seed: "\(game.rawValue)|\(pitcher.id.rawValue)")[turn % extras.count]
    }

    /// How many innings a pitcher has started for the fielding side this game, before the given
    /// half-inning: half-innings in which he threw that side's first pitch.
    public static func inningsStarted(by pitcher: PlayerID, fielding side: TeamSide, before inning: Int,
                                      _ half: HalfInning, in log: PlayLog) -> Int {
        var startedBy: [String: PlayerID] = [:]   // "3 top" → who threw its first pitch
        for entry in log.entries where entry.half.fieldingSide == side && entry.isDelivery {
            // Only half-innings before this one (the top of an inning comes before its bottom).
            let earlier = entry.inning < inning || (entry.inning == inning && entry.half == .top && half == .bottom)
            guard earlier, let thrower = entry.pitcher else { continue }
            let key = "\(entry.inning) \(entry.half)"
            if startedBy[key] == nil { startedBy[key] = thrower }
        }
        return startedBy.values.filter { $0 == pitcher }.count
    }

    /// His extra songs, without his main song and without repeats, in the order listed.
    static func distinctExtras(of pitcher: Player, besides main: SongID?) -> [SongID] {
        var seen: Set<SongID> = main.map { [$0] } ?? []
        return pitcher.extraWarmUpSongIDs.filter { seen.insert($0).inserted }
    }

    /// The extras' order for one pass. A pass never starts with the song that ended the pass
    /// before it, so no song plays two innings running.
    static func order(of extras: [SongID], pass: Int, seed: String) -> [SongID] {
        var random = SeededRandom(seed: "\(seed)|\(pass)")
        var shuffled = extras.shuffled(using: &random)
        if pass > 0, shuffled.count > 1, shuffled.first == order(of: extras, pass: pass - 1, seed: seed).last {
            shuffled.swapAt(0, 1)
        }
        return shuffled
    }
}

extension PlayLogEntry {
    /// True for an entry where the pitcher threw: a pitch, an intentional walk, a ball in play.
    var isDelivery: Bool {
        switch event.kind {
        case .pitch, .intentionalWalk, .ballInPlay: true
        default: false
        }
    }
}

/// Random numbers that come out the same for the same seed text, on every phone and every run
/// (Swift's own hashing changes from run to run, so it cannot be the seed).
public struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64

    public init(seed: String) {
        // FNV-1a over the text's bytes: a standard, simple way to turn text into a number.
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in seed.utf8 { hash = (hash ^ UInt64(byte)) &* 0x0000_0100_0000_01B3 }
        state = hash
    }

    /// The next number (SplitMix64, a standard small generator).
    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
