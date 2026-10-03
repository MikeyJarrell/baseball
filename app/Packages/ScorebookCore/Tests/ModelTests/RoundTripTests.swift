// Tests that everything in the vocabulary survives being saved as JSON and read back,
// with nothing lost: the sample data, and one of every kind of event.

import Foundation
import Testing
import Model
import SampleData

/// Saves a value as JSON and reads it back.
func roundTrip<T: Codable>(_ value: T) throws -> T {
    try ScorebookJSON.decode(T.self, from: ScorebookJSON.encode(value))
}

@Suite("Saving and reading back")
struct RoundTripTests {
    @Test("Teams and the song library read back exactly")
    func teamsAndSongs() throws {
        for team in SampleTeams.all + [SampleTeams.emptyTeam, SampleTeams.unknown()] {
            #expect(try roundTrip(team) == team)
        }
        #expect(try roundTrip(SampleSongs.library) == SampleSongs.library)
    }

    @Test("Game setups read back exactly")
    func setups() throws {
        for setup in [SampleSetups.cardinalsAtMudcats,
                      SampleSetups.mudcatsAtBombers, SampleSetups.unknownAtMudcats] {
            #expect(try roundTrip(setup) == setup)
        }
    }

    @Test("The complete sample game, its play log and box score read back exactly")
    func sampleGame() throws {
        #expect(try roundTrip(SampleGame.game) == SampleGame.game)
        #expect(try roundTrip(SampleGame.playLog) == SampleGame.playLog)
        #expect(try roundTrip(SampleGame.boxScore) == SampleGame.boxScore)
        #expect(try roundTrip(SampleGame.finalSituation) == SampleGame.finalSituation)
        #expect(try roundTrip(SampleSeason.totals) == SampleSeason.totals)
        #expect(try roundTrip(SampleSeason.games) == SampleSeason.games)
    }

    @Test("Every sample situation reads back exactly")
    func situations() throws {
        for sample in SampleSituations.all {
            #expect(try roundTrip(sample.situation) == sample.situation, "\(sample.title)")
        }
        for history in SamplePlateAppearances.byPlayer.values {
            #expect(try roundTrip(history) == history)
        }
    }

    @Test("One of every kind of event reads back exactly")
    func everyEventKind() throws {
        let play = Play(
            batterResult: .double, battedBall: .lineDrive, fielders: [.leftField], hitLocation: .leftField,
            hitSpot: FieldPoint(x: 0.2, y: 0.8),
            runners: [RunnerMove(runner: "a", from: .first, to: .scored), RunnerMove(runner: "b", from: .home, to: .second)],
            errors: [ErrorCharge(fielder: .leftField, type: .throwing)], rbi: 1
        )
        let kinds: [EventKind] = [
            .pitch(Pitch(.ball)),
            .pitch(Pitch(.swingingStrike, droppedThirdStrike: Play(batterResult: .out, fielders: [.catcher, .firstBase]))),
            .intentionalWalk(IntentionalWalk()),
            .ballInPlay(play),
            .runnerAction(RunnerAction(moves: [RunnerMove(runner: "a", from: .first, to: .out, reason: .caughtStealing,
                                                          outBy: [.catcher, .shortstop], outAt: .second)])),
            .errorWithNoAdvance(ErrorCharge(fielder: .firstBase, type: .fielding)),
            .substitution(Substitution(team: .home, changes: [
                LineupChange(kind: .positionSwitch, incoming: "a", position: .shortstop),
                LineupChange(kind: .defensiveReplacement, incoming: "c", replacing: "b", position: .secondBase),
            ])),
            .defenseConfirmed(DefenseConfirmed(team: .home)),
            .runnerForNonRunner(RunnerForNonRunner(runner: "c", replacing: "a")),
            .pitchingChange(PitchingChange(team: .away, newPitcher: "p2", previousPitcherMovesTo: .rightField, takesBattingSpotOf: "x")),
            .addHitter(AddHitter(team: .home, player: "n", position: nil)),
            .manualAdjustment(ManualAdjustment(inning: 4, half: .bottom, outs: 2, count: Count(balls: 1, strikes: 2),
                                               score: Score(away: 1, home: 2), runners: BaseOccupants(first: "a", third: "b"),
                                               batterIndex: 3, note: "Fixing the book")),
            .endOfGame(EndOfGame(reason: .timeLimit, finalScore: Score(away: 3, home: 5))),
        ]
        for kind in kinds {
            let event = GameEvent(enteredAt: Date(timeIntervalSince1970: 1_777_746_600.75), kind: kind)
            #expect(try roundTrip(event) == event, "\(kind.label)")
        }
        let edits: [EventEdit] = [.delete("e1"), .replace(GameEvent(kind: kinds[0])), .insert(GameEvent(kind: kinds[1]), after: nil)]
        for edit in edits {
            #expect(try roundTrip(edit) == edit)
        }
    }

    @Test("Settings, damaged-file lists and manual run changes read back exactly")
    func settingsAndLists() throws {
        let settings = AppSettings(fadeSongOnFirstPitch: true)
        #expect(try roundTrip(settings) == settings)
        // An older settings file with nothing in it takes every default.
        #expect(try ScorebookJSON.decode(AppSettings.self, from: Data("{}".utf8)) == AppSettings())
        #expect(AppSettings().fadeSongOnFirstPitch == false)
        #expect(AppSettings().walkUpSongSeconds == 12)

        let list = LoadedList(items: SampleSeason.games, damaged: [DamagedFile(fileName: "games/x.json", reason: "cut off mid-write")])
        #expect(try roundTrip(list) == list)

        var entry = SampleGame.playLog.entries[0]
        entry.adjustedRuns = Score(away: 2, home: -1)
        #expect(try roundTrip(entry) == entry)
    }

    @Test("A hand-written event may leave out its id, time and empty lists")
    func handWrittenEvent() throws {
        let json = """
        { "ballInPlay": { "batterResult": "out", "fielders": [6, 3],
                          "runners": [ { "runner": "c1", "from": "home", "to": "out", "outBy": [6, 3] } ] } }
        """
        let event = try ScorebookJSON.decode(GameEvent.self, from: Data(json.utf8))
        guard case .ballInPlay(let play) = event.kind else {
            Issue.record("Expected a ball in play")
            return
        }
        #expect(play.rbi == 0 && play.errors.isEmpty && play.multiOut == nil)
        #expect(play.runners.first?.advancedOnError == false)
        #expect(event.enteredAt == Date(timeIntervalSinceReferenceDate: 0))
    }

    @Test("An event with no kind is reported, not guessed")
    func eventWithNoKind() {
        #expect(throws: DecodingError.self) {
            try ScorebookJSON.decode(GameEvent.self, from: Data(#"{ "id": "e1" }"#.utf8))
        }
    }
}

@Suite("Small vocabulary helpers")
struct HelperTests {
    @Test("Rates print the baseball way, with a dash when there are no at-bats")
    func rates() {
        #expect(formattedRate(1.0 / 3.0) == ".333")
        #expect(formattedRate(1) == "1.000")
        #expect(formattedRate(0) == ".000")
        #expect(formattedRate(nil) == "—")
        #expect(BattingCounts(plateAppearances: 2, walks: 2).battingAverage == nil)
    }

    @Test("Innings pitched print as whole innings and outs: 16 outs is 5.1")
    func inningsPitched() {
        #expect(PitchingCounts(outsRecorded: 16).inningsPitchedText == "5.1")
        #expect(PitchingCounts(outsRecorded: 0).inningsPitchedText == "0.0")
        #expect(PitchingCounts(outsRecorded: 0).walksAndHitsPerInning == nil)
    }

    @Test("Batting average, on-base and slugging follow the standard formulas")
    func battingRates() {
        // 10 at-bats: 3 hits (a single, a double, a home run), 2 walks, 1 hit by pitch, 1 sacrifice fly.
        let s = BattingCounts(plateAppearances: 14, atBats: 10, hits: 3, doubles: 1, homeRuns: 1,
                              walks: 2, hitByPitch: 1, sacrificeFlies: 1)
        #expect(s.totalBases == 7)
        #expect(s.battingAverage == 0.3)
        #expect(s.onBasePercentage == 6.0 / 14.0)
        #expect(s.sluggingPercentage == 0.7)
    }

    @Test("A player's name falls back to their number, then their placeholder")
    func displayNames() {
        #expect(Player(name: "Derek Jeter", number: "2").displayName == "Derek Jeter")
        #expect(Player(number: "22").displayName == "#22")
        #expect(Player(placeholder: "Batter 4").displayName == "Batter 4")
        #expect(Player(name: "Derek Jeter").lastName == "Jeter")
    }

    @Test("The order wraps from the last spot to the first for the on-deck hitter")
    func onDeckWraps() {
        let order = BattingOrder(slots: [BattingSlot(players: ["a"]), BattingSlot(players: ["b"]), BattingSlot(players: ["c"])])
        let state = TeamState(battingOrder: order, nextBatterIndex: 2)
        #expect(state.currentBatter == "c")
        #expect(state.onDeckBatter == "a")
    }

    @Test("The game clock counts down from the time limit, from the first event")
    func gameClock() {
        var situation = SampleSituations.topOfFirst.situation
        #expect(situation.timeLimitMinutes == 100)
        #expect(situation.timeRemaining(at: Date()) == nil)
        let start = Date(timeIntervalSinceReferenceDate: 1_000)
        situation.gameStartedAt = start
        #expect(situation.timeRemaining(at: start.addingTimeInterval(30 * 60)) == TimeInterval(70 * 60))
        situation.timeLimitMinutes = nil
        #expect(situation.timeRemaining(at: start) == nil)
    }

    @Test("Event times are kept to the whole second")
    func wholeSeconds() {
        let event = GameEvent(enteredAt: Date(timeIntervalSinceReferenceDate: 100.9), kind: .intentionalWalk(IntentionalWalk()))
        #expect(event.enteredAt == Date(timeIntervalSinceReferenceDate: 100))
    }
}
