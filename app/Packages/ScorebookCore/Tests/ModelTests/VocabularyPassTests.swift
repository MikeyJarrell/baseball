// Tests for the vocabulary pass's additions: the new box score data, the strikeout double
// play and pickoff flags, count hints, short team names, fielding rotations, audio playback
// state, and the in-memory storage's resume choice.

import Foundation
import Testing
import Model
import SampleData

@Suite("Vocabulary pass additions")
struct VocabularyPassTests {
    @Test("The new box score data reads back exactly, and older notes without it still read")
    func boxScoreData() throws {
        #expect(try roundTrip(SampleGame.boxScore) == SampleGame.boxScore)
        #expect(SampleGame.boxScore.gameLength == 11_552)
        #expect(SampleGame.boxScore.home.pitching.first?.decision == .win)
        #expect(SampleGame.boxScore.away.pitching.last?.decision == .loss)
        #expect(SampleGame.boxScore.away.batting.first { $0.player == "m10" }?.entered?.notation == "P6")
        #expect(SampleGame.boxScore.notes.hitBatters.first?.pitcherName == "Gus Reyes")
        #expect(SampleGame.boxScore.notes.ranForNonRunners.first?.runnerName == "Jordan Webb")

        // Notes written before the new lists existed.
        var json = try JSONSerialization.jsonObject(with: ScorebookJSON.encode(BoxScoreNotes())) as! [String: Any]
        json["hitBatters"] = nil
        json["ranForNonRunners"] = nil
        let old = try JSONSerialization.data(withJSONObject: json)
        #expect(try ScorebookJSON.decode(BoxScoreNotes.self, from: old) == BoxScoreNotes())
    }

    @Test("Runner flags: a pickoff while stealing is caught stealing, and the strikeout double play reads back")
    func runnerFlags() throws {
        let pickedOff = RunnerMove(runner: "a", from: .first, to: .out, reason: .pickoff, wasStealing: true)
        #expect(pickedOff.countsAsCaughtStealing)
        #expect(!RunnerMove(runner: "a", from: .first, to: .out, reason: .pickoff).countsAsCaughtStealing)
        #expect(RunnerMove(runner: "a", from: .first, to: .out, reason: .caughtStealing).countsAsCaughtStealing)
        let action = RunnerAction(moves: [pickedOff], completesStrikeoutDoublePlay: true)
        #expect(try roundTrip(action) == action)
        let plain = try ScorebookJSON.decode(RunnerAction.self, from: Data(#"{"moves": []}"#.utf8))
        #expect(!plain.completesStrikeoutDoublePlay)
    }

    @Test("Count hints follow the counting rules", arguments: [
        (PitchResult.ball, Count(balls: 1, strikes: 0), "makes it 2–0"),
        (.ball, Count(balls: 3, strikes: 2), "walk"),
        (.calledStrike, Count(balls: 2, strikes: 1), "makes it 2–2"),
        (.swingingStrike, Count(balls: 0, strikes: 2), "strikeout"),
        (.foul, Count(balls: 3, strikes: 2), "stays 3–2"),
        (.foul, Count(balls: 1, strikes: 1), "makes it 1–2"),
        (.foulTip, Count(balls: 1, strikes: 2), "strikeout"),
        (.hitByPitch, Count(balls: 0, strikes: 0), "hit by pitch"),
    ])
    func countHints(pitch: PitchResult, count: Count, hint: String) {
        var situation = SampleSituations.topOfFirst.situation
        situation.count = count
        #expect(SampleRulesEngine().countAfter(pitch, in: situation).hint == hint)
        #expect(DoNothingRulesEngine().countAfter(pitch, in: situation) == CountChange.after(pitch, from: count))
    }

    @Test("Short team names: chosen, or made from the name")
    func shortNames() {
        #expect(SampleTeams.diamondDogs.displayShortName == "DOGS")
        #expect(SampleTeams.bombers.displayShortName == "BOM")
        #expect(ShortTeamName.make(from: "Diamond Dogs") == "DOGS")
        #expect(ShortTeamName.make(from: "Mudcats") == "MUD")
        #expect(SampleSetups.mudcatsAtDiamondDogs.away.displayShortName == "MUD")
    }

    @Test("A fielding rotation hands a position to whoever's turn it is")
    func rotations() throws {
        let setup = SampleSetups.mudcatsAtDiamondDogsAlternatingFirstBase
        let team = setup.home
        let second = team.defense(forInning: 2, from: team.defense)
        #expect(second.first { $0.position == .firstBase }?.player == "d11")
        #expect(!second.contains { $0.player == "d4" })
        #expect(team.defense(forInning: 3, from: second).first { $0.position == .firstBase }?.player == "d4")
        #expect(try roundTrip(setup) == setup)
        let suggested = SampleSituations.defenseCheckWithRotation.situation.suggestedDefense
        #expect(suggested?.first { $0.position == .firstBase }?.player == "d11")
        // The start of the game suggests the starting defense for the defense check.
        #expect(Situation(startOf: setup).suggestedDefense == team.defense)
    }

    @Test("Audio playback state reads back, and players that do not report it say playing or not")
    @MainActor
    func playback() throws {
        let state = AudioPlayback(phase: .song, song: "song-01", fadesAt: Date(timeIntervalSince1970: 1_777_737_612))
        #expect(try roundTrip(state) == state)
        let player = SilentAudioPlayer(library: SampleSongs.library)
        #expect(player.playback.phase == .idle)
        player.playWalkUp(for: SampleTeams.diamondDogs.roster[0], withIntroduction: false)
        #expect(player.playback.phase == .song && player.playback.song == "song-01")
    }

    @Test("The in-memory storage resumes the game with the latest event, as the real one does")
    func resume() async throws {
        var older = SampleGame.throughThreeInnings.game
        older.id = "older"
        var newer = SampleGame.throughThreeInnings.game
        newer.id = "scheduled-later"
        newer.events = Array(newer.events.prefix(5))
        newer.setup.scheduledStart = older.setup.scheduledStart.addingTimeInterval(86_400)
        let unstarted = Game(id: "unstarted", setup: SampleSetups.mudcatsAtDiamondDogs)
        let storage = InMemoryStorage(games: [unstarted, newer, older])
        // `older` was entered most recently, though `newer` is scheduled a day later.
        #expect(try await storage.gameInProgress()?.id == "older")
        #expect(try await storage.listBackups().isEmpty)
        let onlyUnstarted = InMemoryStorage(games: [Game(id: "a", setup: SampleSetups.mudcatsAtDiamondDogs), unstarted])
        #expect(try await onlyUnstarted.gameInProgress()?.id == "unstarted")
    }
}
