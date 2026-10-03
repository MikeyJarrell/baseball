// Helpers shared by the storage tests: a throwaway folder for each test, and one of every
// kind of event a game can hold.

import Foundation
import Model
import SampleData
@testable import Storage

/// A fresh, empty folder for one test, deleted when the test is done with it.
final class TemporaryFolder {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScorebookStorageTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit { try? FileManager.default.removeItem(at: url) }

    /// A new storage on this folder. Making a second one is how a test checks that something
    /// really reached the disk rather than only the first storage's memory.
    func storage() throws -> FileStorage { try FileStorage(folder: url) }

    /// The bytes of a file inside the folder, such as "games/sample-game.json".
    func contents(of fileName: String) throws -> Data {
        try Data(contentsOf: url.appendingPathComponent(fileName))
    }

    /// Overwrites a file inside the folder directly, the way a crash or a bad copy might.
    func overwrite(_ fileName: String, with data: Data) throws {
        try data.write(to: url.appendingPathComponent(fileName))
    }

    /// Every file name in one subfolder, including hidden ones.
    func names(in subfolder: String) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: url.appendingPathComponent(subfolder).path).sorted()
    }
}

/// One of every kind of event, with every optional detail filled in somewhere, so a test
/// can check that nothing about any of them is lost on the way to disk and back.
let oneOfEveryEvent: [GameEvent] = {
    let play = Play(
        batterResult: .double, battedBall: .lineDrive, fielders: [.leftField], hitLocation: .leftField,
        hitSpot: FieldPoint(x: 0.2, y: 0.8),
        runners: [RunnerMove(runner: "d1", from: .first, to: .scored),
                  RunnerMove(runner: "d2", from: .home, to: .second, advancedOnError: true)],
        errors: [ErrorCharge(fielder: .leftField, type: .throwing)], rbi: 1
    )
    let doublePlay = Play(
        batterResult: .out, battedBall: .groundBall, fielders: [.thirdBase, .secondBase, .firstBase],
        runners: [RunnerMove(runner: "m1", from: .first, to: .out, outBy: [.thirdBase, .secondBase], outAt: .second),
                  RunnerMove(runner: "m2", from: .home, to: .out, outBy: [.secondBase, .firstBase], outAt: .first)],
        multiOut: .doublePlay
    )
    let kinds: [EventKind] = [
        .pitch(Pitch(.ball)),
        .pitch(Pitch(.foulTip)),
        .pitch(Pitch(.hitByPitch)),
        .pitch(Pitch(.swingingStrike, droppedThirdStrike: Play(batterResult: .out, fielders: [.catcher, .firstBase]))),
        .intentionalWalk(IntentionalWalk()),
        .ballInPlay(play),
        .ballInPlay(doublePlay),
        .runnerAction(RunnerAction(moves: [RunnerMove(runner: "d3", from: .first, to: .out, reason: .caughtStealing,
                                                      outBy: [.catcher, .shortstop], outAt: .second)])),
        .runnerAction(RunnerAction(moves: [RunnerMove(runner: "d1", from: .first, to: .second, reason: .stolenBase),
                                           RunnerMove(runner: "d2", from: .second, to: .third, reason: .stolenBase,
                                                      advancedOnError: true)],
                                   errors: [ErrorCharge(fielder: .catcher, type: .throwing)])),
        .errorWithNoAdvance(ErrorCharge(fielder: .firstBase, type: .fielding)),
        .substitution(Substitution(team: .home,
            batting: [BattingChange(kind: .pinchHitter, incoming: "d10", replacing: "d7")],
            defense: [FielderAssignment(position: .shortstop, player: "d1"), FielderAssignment(position: .secondBase, player: "d11")],
            leavesField: ["d7"])),
        .defenseConfirmed(DefenseConfirmed(team: .home)),
        .runnerForNonRunner(RunnerForNonRunner(runner: "d3", replacing: "d4")),
        .pitchingChange(PitchingChange(team: .away, newPitcher: "m12", previousPitcherMovesTo: .rightField, takesBattingSpotOf: "m6")),
        .addHitter(AddHitter(team: .home, player: "d11")),
        .battingHole(BattingHole(team: .away, spotIndex: 4)),
        .automaticOut(AutomaticOut(team: .away, spotIndex: 4)),
        .timeLimitChange(TimeLimitChange(endsAt: Date(timeIntervalSince1970: 1_777_748_400), note: "Umpire added 20 minutes")),
        .keepPlaying(KeepPlaying(reason: .timeLimit)),
        .manualAdjustment(ManualAdjustment(inning: 4, half: .bottom, outs: 2, count: Count(balls: 1, strikes: 2),
                                           score: Score(away: 1, home: 2), runners: BaseOccupants(first: "d1", third: "d2"),
                                           batterIndex: 3, note: "Fixing the book")),
        .endOfGame(EndOfGame(reason: .timeLimit, finalScore: Score(away: 3, home: 5))),
    ]
    return kinds.enumerated().map { index, kind in
        GameEvent(id: EventID(rawValue: "every-\(index)"),
                  enteredAt: Date(timeIntervalSince1970: 1_777_741_000 + Double(index) * 30), kind: kind)
    }
}()

/// A copy of a game under a new id, starting at a new time, keeping only some of its events.
func copy(of game: Game, id: GameID, startingAt start: Date, eventCount: Int? = nil) -> Game {
    var copy = game
    copy.id = id
    copy.setup.scheduledStart = start
    if let eventCount { copy.events = Array(game.events.prefix(eventCount)) }
    return copy
}
