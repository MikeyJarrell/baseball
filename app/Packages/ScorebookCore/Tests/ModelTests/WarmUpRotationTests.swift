// Tests of which warm-up song plays each time our team takes the field: a pitcher's main
// song his first inning, then his extra songs at random, none repeated until all have played,
// and older saved players without extra songs still reading.

import Foundation
import Testing
import Model

/// Random numbers that come out the same every run, so a test can play a whole game.
struct FixedRandom: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        // A standard small generator (SplitMix64).
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

@Suite("Pitcher warm-up song rotation")
struct WarmUpRotationTests {
    let chris = Player(id: "p1", name: "Chris Strong", warmUpSongID: "alabama",
                       extraWarmUpSongIDs: ["thunder", "eye", "back"])

    /// The songs played over a number of innings, choosing as the game screen does.
    func innings(_ count: Int, for pitcher: Player, seed: UInt64) -> [SongID?] {
        var random = FixedRandom(state: seed)
        var played: [SongID] = []
        var songs: [SongID?] = []
        for _ in 0..<count {
            let song = WarmUpRotation.nextSong(for: pitcher, alreadyPlayed: played, using: &random)
            songs.append(song)
            if let song { played.append(song) }
        }
        return songs
    }

    @Test("His first inning always gets his main song")
    func firstInningIsMain() {
        for seed in 0..<20 as Range<UInt64> {
            #expect(innings(1, for: chris, seed: seed) == ["alabama"])
        }
    }

    @Test("Later innings play every extra song once before any repeats")
    func extrasPlayOncePerPass() {
        for seed in 0..<20 as Range<UInt64> {
            let songs = innings(7, for: chris, seed: seed).compactMap { $0 }
            #expect(songs[0] == "alabama")
            // Innings two to four: each extra once. Five to seven: each extra once again.
            #expect(Set(songs[1...3]) == ["thunder", "eye", "back"])
            #expect(Set(songs[4...6]) == ["thunder", "eye", "back"])
            // Never the same song two innings running, even across passes.
            for i in 1..<songs.count { #expect(songs[i] != songs[i - 1]) }
        }
    }

    @Test("The order changes from game to game")
    func orderVaries() {
        let orders = Set((0..<20 as Range<UInt64>).map { innings(4, for: chris, seed: $0).map { $0 ?? "" } })
        #expect(orders.count > 1)
    }

    @Test("A pitcher with no extra songs hears his main song every inning")
    func noExtras() {
        let gaven = Player(id: "p2", name: "Gaven Lejano", warmUpSongID: "rising-sun")
        #expect(innings(4, for: gaven, seed: 1) == ["rising-sun", "rising-sun", "rising-sun", "rising-sun"])
    }

    @Test("A pitcher with one extra song hears it every inning after his first")
    func oneExtra() {
        let saul = Player(id: "p3", name: "Saul Teodosio", warmUpSongID: "tiburon", extraWarmUpSongIDs: ["sandstorm"])
        #expect(innings(4, for: saul, seed: 1) == ["tiburon", "sandstorm", "sandstorm", "sandstorm"])
    }

    @Test("A pitcher with no warm-up songs gets none")
    func noSongs() {
        #expect(innings(2, for: Player(id: "p4", name: "Yered Teodosio"), seed: 1) == [nil, nil])
    }

    @Test("A player saved before extra warm-up songs existed reads with none, and they round-trip")
    func savedFiles() throws {
        let old = Data(#"{"id":"p1","name":"Chris Strong","warmUpSongID":"alabama","usuallyLeadsOff":false}"#.utf8)
        #expect(try ScorebookJSON.decode(Player.self, from: old).extraWarmUpSongIDs == [])
        let back = try ScorebookJSON.decode(Player.self, from: ScorebookJSON.encode(chris))
        #expect(back == chris)
    }
}
