// Tests of which warm-up song plays each time our team takes the field: a pitcher's main song
// the first inning he starts, then his extra songs in a shuffled order, none repeated until all
// have played and never two innings running; the same answer every time for the same moment of
// the same game; innings counted from the play log; and older saved players still reading.

import Foundation
import Testing
import Model
import SampleData

@Suite("Pitcher warm-up song rotation")
struct WarmUpRotationTests {
    let chris = Player(id: "p1", name: "Chris Strong", warmUpSongID: "alabama",
                       extraWarmUpSongIDs: ["thunder", "eye", "back"])

    /// The songs for a pitcher's first `count` innings in one game.
    func innings(_ count: Int, for pitcher: Player, game: GameID = "game-1") -> [SongID?] {
        (0..<count).map { WarmUpRotation.song(for: pitcher, inningsStarted: $0, game: game) }
    }

    @Test("His first inning always gets his main song")
    func firstInningIsMain() {
        for n in 0..<20 {
            #expect(innings(1, for: chris, game: GameID(rawValue: "game-\(n)")) == ["alabama"])
        }
    }

    @Test("Later innings play every extra song once before any repeats, never two innings running")
    func extrasPlayOncePerPass() {
        for n in 0..<30 {
            let songs = innings(10, for: chris, game: GameID(rawValue: "game-\(n)")).compactMap { $0 }
            #expect(songs[0] == "alabama")
            // Innings two to four: each extra once. Five to seven, and eight to ten: the same again.
            #expect(Set(songs[1...3]) == ["thunder", "eye", "back"])
            #expect(Set(songs[4...6]) == ["thunder", "eye", "back"])
            #expect(Set(songs[7...9]) == ["thunder", "eye", "back"])
            for i in 1..<songs.count { #expect(songs[i] != songs[i - 1]) }
        }
    }

    @Test("The same inning of the same game always gives the same song; other games shuffle differently")
    func sameMomentSameSong() {
        #expect(innings(8, for: chris, game: "game-1") == innings(8, for: chris, game: "game-1"))
        let orders = Set((0..<20).map { innings(4, for: chris, game: GameID(rawValue: "game-\($0)")).map { $0 ?? "" } })
        #expect(orders.count > 1)
    }

    @Test("A pitcher with no extra songs hears his main song every inning")
    func noExtras() {
        let gaven = Player(id: "p2", name: "Gaven Lejano", warmUpSongID: "rising-sun")
        #expect(innings(4, for: gaven) == ["rising-sun", "rising-sun", "rising-sun", "rising-sun"])
    }

    @Test("A pitcher with one extra song hears it every inning after his first")
    func oneExtra() {
        let saul = Player(id: "p3", name: "Saul Teodosio", warmUpSongID: "tiburon", extraWarmUpSongIDs: ["sandstorm"])
        #expect(innings(4, for: saul) == ["tiburon", "sandstorm", "sandstorm", "sandstorm"])
    }

    @Test("A song listed twice, or his main song listed as an extra, still leaves a song every inning")
    func repeatsInTheList() {
        let darin = Player(id: "p4", name: "Darin Dietrich", warmUpSongID: "eagle",
                           extraWarmUpSongIDs: ["a", "b", "a", "eagle"])
        let songs = innings(12, for: darin)
        #expect(songs.allSatisfy { $0 != nil })
        #expect(songs[0] == "eagle")
        #expect(Set(songs.dropFirst().compactMap { $0 }) == ["a", "b"])
    }

    @Test("Extra songs but no main song: his first extra stands in as his main song; no songs at all: none")
    func missingMain() {
        let allan = Player(id: "p5", name: "Allan Nojadera", extraWarmUpSongIDs: ["stamp", "takedown"])
        #expect(innings(3, for: allan) == ["stamp", "takedown", "takedown"])
        #expect(innings(2, for: Player(id: "p6", name: "Yered Teodosio")) == [nil, nil])
    }

    // MARK: Innings counted from the play log

    /// A play-log entry: one event in an inning and half, with the pitcher on the mound.
    func entry(_ inning: Int, _ half: HalfInning, _ pitcher: PlayerID?, _ kind: EventKind = .pitch(Pitch(.ball))) -> PlayLogEntry {
        PlayLogEntry(event: GameEvent(kind: kind), inning: inning, half: half, batter: nil, batterIndex: nil,
                     pitcher: pitcher, fielders: [], before: BasesAndOuts(), after: BasesAndOuts(), notation: "")
    }

    func log(_ entries: [PlayLogEntry]) -> PlayLog {
        PlayLog(gameID: "game-1", setup: SampleSetups.mudcatsAtDiamondDogs, entries: entries,
                awayOrder: BattingOrder(slots: []), homeOrder: BattingOrder(slots: []), isFinal: false)
    }

    @Test("Innings started: counted from who threw the first pitch of each of our fielding half-innings")
    func inningsFromTheLog() {
        // We are home, so we field in the top halves. Ace starts the first and second; a
        // reliever comes in during the second and starts the third.
        let game = log([
            entry(1, .top, "ace"), entry(1, .top, "ace"), entry(1, .bottom, "their-guy"),
            entry(2, .top, "ace"), entry(2, .top, "reliever"), entry(2, .bottom, "their-guy"),
            entry(3, .top, "reliever"),
        ])
        func started(_ p: PlayerID, before inning: Int) -> Int {
            WarmUpRotation.inningsStarted(by: p, fielding: .home, before: inning, .top, in: game)
        }
        #expect(started("ace", before: 1) == 0)
        #expect(started("ace", before: 2) == 1)
        #expect(started("ace", before: 3) == 2)
        // The reliever came in mid-inning, so his first changeover, the third, gets his main song.
        #expect(started("reliever", before: 3) == 0)
        #expect(started("reliever", before: 4) == 1)
        // Their pitcher's innings are not ours.
        #expect(started("their-guy", before: 4) == 0)
    }

    @Test("A pitching change at the changeover, before the first pitch, does not count as an inning")
    func changeAtTheChangeover() {
        let game = log([
            entry(1, .top, "ace"),
            entry(2, .top, "ace", .pitchingChange(PitchingChange(team: .home, newPitcher: "reliever"))),
            entry(2, .top, "reliever"),
        ])
        #expect(WarmUpRotation.inningsStarted(by: "ace", fielding: .home, before: 3, .top, in: game) == 1)
        #expect(WarmUpRotation.inningsStarted(by: "reliever", fielding: .home, before: 3, .top, in: game) == 1)
    }

    // MARK: Saved files

    @Test("A player saved before extra warm-up songs existed reads with none, and they round-trip")
    func savedFiles() throws {
        let old = Data(#"{"id":"p1","name":"Chris Strong","warmUpSongID":"alabama","usuallyLeadsOff":false}"#.utf8)
        #expect(try ScorebookJSON.decode(Player.self, from: old).extraWarmUpSongIDs == [])
        let back = try ScorebookJSON.decode(Player.self, from: ScorebookJSON.encode(chris))
        #expect(back == chris)
    }
}
