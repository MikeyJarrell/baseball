// GameDriver: scores a whole game through the app's real screens, one event at a time, the way
// a scorer would tap it in, and checks after every event that the app agrees with the book.
//
// The driver is handed a finished game (its setup and every event). For each event it works out
// which buttons a scorer taps (Ball, In play, the fielders, where each runner ended up, Save, a
// pitching change, and so on), taps them, then reads the game screen's hidden test readout and
// compares:
//   - where the game stands (`Situation.checkLine`: inning, outs, count, score, runners, batter,
//     both pitchers) with what the rules engine says it should be after that event;
//   - the event the app recorded with the event expected, in everything the box score or the
//     situation uses.
// The first disagreement stops the game, naming the event number, the event expected and the
// event the app recorded. At the end it compares the app's printed box score with the box score
// worked out from the expected events.
//
// Some details never reach the box score or the situation: exactly where a hit landed, the kind
// of batted ball, and which fielders get the putouts and assists. The driver enters what it can,
// notes any difference in those details, and does not stop for them.
//
// When the expected event is something the screens offer no way to enter, the driver records a
// test failure saying so, enters the nearest thing the screens allow, and carries on, so the rest
// of the game is still checked.

import XCTest
import Model
import GameEngine
import Stats
import BoxScoreText
import Scoring

/// Why the driver stopped: the app and the expected game disagree, or a button is missing.
struct DriverStop: Error, CustomStringConvertible {
    var description: String
}

/// Scores one expected game through the app's screens.
@MainActor
final class GameDriver {
    let app: XCUIApplication
    /// The game to score: its setup and every event, as the book has it.
    let expected: Game
    /// Where the game stands just before each expected event, from the rules engine.
    private let situationsBefore: [Situation]
    /// The one-line summary of where the game stands just after each expected event.
    private let linesAfter: [String]
    /// The printed box score of the whole expected game.
    let expectedBox: String

    /// Automatic outs the app recorded by itself (at a batting hole). They are not in the
    /// expected list, so the app's event count runs ahead by this many.
    private var automaticOuts = 0
    /// Differences in details that never show in the box score or the situation.
    private(set) var detailNotes: [String] = []
    /// Expected events the screens offer no way to enter exactly.
    private(set) var gaps: [String] = []
    /// True while entering an event the screens cannot enter exactly: the app's event is then
    /// allowed to differ (the gap is already a recorded failure), but the game must still stand
    /// where the book has it.
    private var enteringGap = false

    init(app: XCUIApplication, expected: Game) {
        self.app = app
        self.expected = expected
        // Replay the game one event at a time, keeping where it stood before and after each.
        let engine = ScorebookRulesEngine()
        var before: [Situation] = []
        var after: [String] = []
        var partial = Game(id: expected.id, setup: expected.setup)
        for event in expected.events {
            before.append(engine.replay(partial).situation)
            partial.events.append(event)
            after.append(engine.replay(partial).situation.checkLine)
        }
        situationsBefore = before
        linesAfter = after
        expectedBox = BoxScorePrinter.text(StatsEngine().boxScore(for: engine.replay(expected).log))
    }

    // MARK: - The whole game

    /// Enters every expected event (or only the first `count` of them), checking the app after
    /// each one. Returns the app's printed box score once the game is over, or nothing when it
    /// stopped early.
    func scoreGame(firstEvents count: Int? = nil) throws -> String? {
        let last = min(count ?? expected.events.count, expected.events.count)
        for index in 0..<last {
            let event = expected.events[index]
            do {
                enteringGap = false
                try enter(event, at: index)
                try check(after: index)
            } catch let stop as DriverStop {
                attachScreenshot(named: "Stopped at event \(index)")
                throw DriverStop(description: "Event \(index) (\(event.kind.label)): \(stop.description)\nExpected event: \(json(event))")
            }
        }
        guard last == expected.events.count else { return nil }
        return readNow()["box"] as? String
    }

    // MARK: - Checking the app after each event

    /// Waits for the app to record the event, then compares where the game stands and the
    /// event it recorded with the book.
    private func check(after index: Int) throws {
        let wanted = index + 1 + automaticOuts
        var readout = readNow()
        let deadline = Date().addingTimeInterval(10)
        while (readout["count"] as? Int ?? -1) < wanted, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.15)
            readout = readNow()
        }
        let count = readout["count"] as? Int ?? -1
        guard count >= wanted else {
            throw DriverStop(description: "the app did not record it (it has \(count) events, expected \(wanted)). Its last event: \(lastText(readout))")
        }
        // More events than taps: only an automatic out at a batting hole may be added by the app.
        var appAddedOne = false
        if count > wanted {
            guard let last = lastEvent(readout), case .automaticOut = last.kind else {
                throw DriverStop(description: "the app has \(count) events, expected \(wanted). Its last event: \(lastText(readout))")
            }
            automaticOuts += count - wanted
            appAddedOne = true
        }
        let line = readout["line"] as? String ?? "(no line)"
        guard line == linesAfter[index] else {
            throw DriverStop(description: "the game stands differently.\n  app:      \(line)\n  expected: \(linesAfter[index])\nThe app recorded: \(lastText(readout))")
        }
        // The event itself, when it is the app's last (not followed by an automatic out).
        guard !appAddedOne, let recorded = lastEvent(readout) else { return }
        let want = expected.events[index]
        if Self.boxFacts(recorded) != Self.boxFacts(want) {
            if enteringGap {
                detailNotes.append("Event \(index): entered as near as the screens allow (see the failure above).\n  app:      \(Self.allFacts(recorded))\n  expected: \(Self.allFacts(want))")
                return
            }
            throw DriverStop(description: "the app recorded a different event.\n  app:      \(Self.boxFacts(recorded))\n  expected: \(Self.boxFacts(want))")
        }
        if Self.allFacts(recorded) != Self.allFacts(want) {
            detailNotes.append("Event \(index): details differ (not in the box score).\n  app:      \(Self.allFacts(recorded))\n  expected: \(Self.allFacts(want))")
        }
    }

    /// The game screen's hidden readout (see `XCUIApplication.readout`), read without the
    /// one-second pause `waitForExistence` makes even when the readout is already there.
    private func readNow() -> [String: Any] {
        let element = app.descendants(matching: .any)["test-readout"]
        guard element.exists || element.waitForExistence(timeout: 5),
              let data = element.label.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return object
    }

    /// The app's last event, from the readout.
    private func lastEvent(_ readout: [String: Any]) -> GameEvent? {
        guard let object = readout["last"],
              let data = try? JSONSerialization.data(withJSONObject: object) else { return nil }
        return try? ScorebookJSON.decode(GameEvent.self, from: data)
    }

    /// The app's last event as text, for failure messages.
    private func lastText(_ readout: [String: Any]) -> String {
        guard let object = readout["last"],
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) else { return "(none)" }
        return String(decoding: data, as: UTF8.self)
    }

    /// An event in JSON, without its id and time.
    private func json(_ event: GameEvent) -> String {
        guard let data = try? ScorebookJSON.encode(event),
              var object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return "?" }
        object["id"] = nil
        object["enteredAt"] = nil
        guard let text = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) else { return "?" }
        return String(decoding: text, as: UTF8.self)
    }

    /// Everything about an event that the box score or the situation uses, as one line of text.
    /// Left out: where a hit landed, the kind of batted ball, and who made each putout.
    static func boxFacts(_ event: GameEvent) -> String {
        var kind = event.kind
        switch kind {
        case .ballInPlay(var play):
            play.hitSpot = nil
            play.hitLocation = nil
            play.battedBall = nil
            play.runners = play.runners.map { move in
                var m = move
                m.outBy = []
                m.outAt = nil
                return m
            }
            kind = .ballInPlay(play)
        case .runnerAction(var action):
            action.moves = action.moves.map { move in
                var m = move
                m.outBy = []
                m.outAt = nil
                return m
            }
            kind = .runnerAction(action)
        default:
            break
        }
        return facts(kind)
    }

    /// Everything about an event except its id and time, as one line of text. Also left out:
    /// the exact spot a hit landed (the book never has one), and the kind of batted ball on
    /// anything but a batter out, the only play whose screen asks for it.
    static func allFacts(_ event: GameEvent) -> String {
        guard case .ballInPlay(var play) = event.kind else { return facts(event.kind) }
        play.hitSpot = nil
        if play.batterResult != .out { play.battedBall = nil }
        return facts(.ballInPlay(play))
    }

    /// An event's details as sorted JSON, runners and errors in a fixed order.
    private static func facts(_ kind: EventKind) -> String {
        var kind = kind
        switch kind {
        case .ballInPlay(var play):
            // A runner who stayed on their base may be listed or left out: it means the same.
            play.runners.removeAll { $0.to == .safe(at: $0.from) && !$0.isBatter && $0.reason == nil && !$0.advancedOnError }
            play.runners.sort { $0.runner.rawValue < $1.runner.rawValue }
            play.errors.sort { $0.fielder.rawValue < $1.fielder.rawValue }
            kind = .ballInPlay(play)
        case .runnerAction(var action):
            action.moves.sort { $0.runner.rawValue < $1.runner.rawValue }
            kind = .runnerAction(action)
        default:
            break
        }
        let event = GameEvent(id: "x", enteredAt: Date(timeIntervalSinceReferenceDate: 0), kind: kind)
        guard let data = try? ScorebookJSON.encode(event),
              var object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return "?" }
        object["id"] = nil
        object["enteredAt"] = nil
        object["formatVersion"] = nil
        guard let text = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) else { return "?" }
        return String(decoding: text, as: UTF8.self)
    }

    // MARK: - Entering one event

    /// Taps in one expected event.
    private func enter(_ event: GameEvent, at index: Int) throws {
        let before = situationsBefore[index]
        switch event.kind {
        case .pitch(let pitch):
            try enterPitch(pitch, before: before)
        case .intentionalWalk:
            try tap(app.buttons["Intentional walk"], "the Intentional walk chip")
        case .ballInPlay(let play):
            try enterBallInPlay(play, before: before)
        case .runnerAction(let action):
            try enterRunnerAction(action, before: before)
        case .defenseConfirmed(let check):
            try confirmDefense(team: check.team, before: before, index: index)
        case .runnerForNonRunner(let choice):
            try enterRunnerForNonRunner(choice)
        case .pitchingChange(let change):
            try enterPitchingChange(change, before: before, index: index)
        case .substitution(let change):
            try enterSubstitution(change)
        case .endOfGame(let end):
            try endGame(end)
        default:
            throw DriverStop(description: "the driver has no taps for a \(event.kind.label) yet")
        }
    }

    // MARK: Pitches

    /// One pitch: a count button, the long press on Foul for a foul bunt, or a chip.
    private func enterPitch(_ pitch: Pitch, before: Situation) throws {
        guard pitch.droppedThirdStrike == nil else {
            throw DriverStop(description: "the driver has no taps for a dropped third strike yet")
        }
        switch pitch.result {
        case .ball: try tap(app.buttons["Ball"], "the Ball button")
        case .calledStrike: try tap(app.buttons["Called strike"], "the Called button")
        case .swingingStrike: try tap(app.buttons["Strike, swinging"], "the Strike button")
        case .foul: try tap(app.buttons["Foul"], "the Foul button")
        case .foulBunt:
            // Holding Foul down for half a second records a foul bunt.
            let foul = app.buttons["Foul"]
            guard appears(foul, within: 5) else { throw missing("the Foul button") }
            foul.press(forDuration: 0.8)
        case .foulTip:
            let chip = app.buttons["Foul tip"]
            guard appears(chip, within: 3) else {
                throw DriverStop(description: "the Foul tip chip is not on the batting screen (count \(before.count.balls)-\(before.count.strikes))")
            }
            chip.tap()
        case .hitByPitch: try tap(app.buttons["Hit by pitch"], "the Hit by pitch chip")
        }
    }

    // MARK: Balls in play

    /// The in-play sequence: what happened to the batter, the fielders (or the error, or where a
    /// hit landed), where every runner ended up, the runs batted in, then Save.
    private func enterBallInPlay(_ play: Play, before: Situation) throws {
        try tap(app.buttons["In play"], "the In play button")

        // Step one: what happened to the batter. Sacrifices and interference sit under "More".
        if [.sacrificeFly, .sacrificeBunt, .catchersInterference].contains(play.batterResult) {
            try tap(button(startingWith: "More"), "the More button")
        }
        try tap(resultButton(play.batterResult), "the \(play.batterResult.label) answer")

        // The middle step.
        switch play.batterResult {
        case .out, .fieldersChoice, .sacrificeFly, .sacrificeBunt:
            for fielder in play.fielders { try tap(fielderButton(fielder), "the \(fielder.name) on the drawing") }
            if play.batterResult == .out {
                if let kind = play.battedBall { try tap(app.buttons[Self.chipTitle(kind)], "the \(kind) chip") }
                if let multi = play.multiOut {
                    let chip = app.buttons[multi == .doublePlay ? "Double play" : "Triple play"]
                    guard appears(chip, within: 3) else { throw missing("the \(multi) chip") }
                    if !chip.isSelected { chip.tap() }
                }
            } else if play.multiOut != nil {
                gap("a \(play.batterResult.label) marked as a double or triple play: the screen offers the double play chip only on a batter out")
            }
        case .single, .double, .triple, .homeRun:
            if let location = play.hitLocation { try tap(fielderButton(location), "where the hit landed") }
        case .reachedOnError:
            guard let error = play.errors.first else { throw DriverStop(description: "a reached-on-error play with no error listed") }
            if let type = error.type { try tap(app.buttons[type == .fielding ? "Fielding" : "Throwing"], "the error type chip") }
            try tap(fielderButton(error.fielder), "the fielder who made the error")
        case .catchersInterference, .reachedOnDroppedThirdStrike:
            break
        }

        // The runner step comes next when anyone is on base or the batter reached without a hit.
        let needsRunners = !before.runners.isEmpty
            || [.reachedOnError, .fieldersChoice, .catchersInterference, .reachedOnDroppedThirdStrike].contains(play.batterResult)
        if needsRunners {
            if !app.staticTexts["RUNS BATTED IN"].exists {
                try tap(app.buttons["Runners"], "the Runners button")
            }
            try placeRunners(play)
        }
        try tap(app.buttons["Save"], "the Save button")
    }

    /// On the runner step: puts every runner where the play left them, answers "Who put them
    /// out?" and "How did they get there?", and sets the runs batted in.
    private func placeRunners(_ play: Play) throws {
        guard appears(app.staticTexts["RUNS BATTED IN"], within: 5) else { throw missing("the runner step") }
        // Lead runner first, batter last, so moving one never pushes a runner already placed.
        let moves = play.runners.sorted { $0.from > $1.from }
        for _ in 0..<3 {
            var changed = false
            for move in moves {
                let row = app.otherElements["runner-row-\(move.runner.rawValue)"]
                guard appears(row, within: 3) else { throw missing("the runner row for \(name(move.runner))") }
                let end = row.buttons[Self.endLabel(move.to)]
                guard end.exists else { throw missing("the \(Self.endLabel(move.to)) button for \(name(move.runner))") }
                if !end.isSelected {
                    end.tap()
                    changed = true
                }
            }
            if !changed { break }
        }

        // "Who put them out?" for a runner the scorer put out who was not suggested out.
        for move in moves where move.to == .out {
            let question = app.otherElements["out-question-\(move.runner.rawValue)"]
            guard question.exists else { continue }
            if move.outBy.isEmpty { gap("\(name(move.runner)) is out with no fielders listed, but the screen asks who put them out") }
            for fielder in move.outBy {
                try tap(question.buttons["\(Self.fielderWord(fielder).capitalized) made or helped make the out"],
                        "the \(fielder.name) under \"Who put \(name(move.runner)) out?\"")
            }
        }

        // "How did they get there?" for a runner sent past the suggestion.
        for move in moves {
            let question = app.otherElements["extra-base-question-\(move.runner.rawValue)"]
            guard question.exists else { continue }
            let onError = move.advancedOnError && !(move.isBatter && play.batterResult == .reachedOnError)
            guard onError else { continue }
            try tap(question.buttons["On an error"], "\"On an error\" for \(name(move.runner))")
            // The error this runner moved up on: the last one listed that is not the batter's.
            guard let charge = play.errors.last else {
                gap("\(name(move.runner)) moved up on an error, but the play lists no error")
                continue
            }
            try tap(question.buttons["Error by the \(Self.fielderWord(charge.fielder))"], "whose error let \(name(move.runner)) move up")
        }

        // The runs batted in.
        for _ in 0..<6 {
            let shown = rbiShown()
            guard let shown, shown != play.rbi else { break }
            try tap(app.buttons[shown < play.rbi ? "More runs batted in" : "Fewer runs batted in"], "the runs batted in stepper")
        }
        if let shown = rbiShown(), shown != play.rbi {
            throw DriverStop(description: "the runs batted in show \(shown), expected \(play.rbi)")
        }
        // Anything still stopping Save shows in the bottom bar.
        let save = app.buttons["Save"]
        if save.exists, !save.isEnabled {
            let words = app.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: " | ")
            throw DriverStop(description: "Save is not available on the runner step. Screen: \(words)")
        }
    }

    /// The runs batted in on the runner step, as shown.
    private func rbiShown() -> Int? {
        let text = app.staticTexts.matching(NSPredicate(format: "label ENDSWITH %@", " runs batted in")).firstMatch
        guard text.exists else { return nil }
        return Int(text.label.split(separator: " ").first ?? "")
    }

    /// The answer button on "What happened to the batter?".
    private func resultButton(_ result: BatterResult) -> XCUIElement {
        let title: String = switch result {
        case .out: "Batter out"
        case .single: "Single"
        case .double: "Double"
        case .triple: "Triple"
        case .homeRun: "Home run"
        case .reachedOnError: "Reached on error"
        case .fieldersChoice: "Fielder’s choice"
        case .sacrificeFly: "Sacrifice fly"
        case .sacrificeBunt: "Sacrifice bunt"
        case .catchersInterference: "Catcher’s interference"
        case .reachedOnDroppedThirdStrike: "Batter safe at first"
        }
        return app.buttons.matching(NSPredicate(format: "label == %@ OR label BEGINSWITH %@", title, title + ":")).firstMatch
    }

    /// A fielder's circle on a field drawing: "Shortstop, 6".
    private func fielderButton(_ position: Position) -> XCUIElement {
        app.buttons["\(position.name.capitalized), \(position.rawValue)"]
    }

    // MARK: Runner moves between pitches

    /// A steal, caught stealing, defensive indifference and the like: tap the runner on the
    /// field, pick what happened, check where they ended up (and who put them out), Save.
    private func enterRunnerAction(_ action: RunnerAction, before: Situation) throws {
        guard action.moves.count == 1, let move = action.moves.first, let reason = move.reason else {
            throw DriverStop(description: "the driver handles one runner at a time between pitches, with a reason")
        }
        let runnerTag = app.buttons["Runner \(shortName(move.runner)), on \(move.from.rawValue)"]
        try tap(runnerTag, "\(name(move.runner))'s tag on the field")

        let choice: XCUIElement = switch reason {
        case .stolenBase: button(startingWith: "Stole")
        case .caughtStealing: button(startingWith: "Caught stealing")
        case .pickoff: button(startingWith: "Picked off")
        case .wildPitch: button(startingWith: "Wild pitch")
        case .passedBall: button(startingWith: "Passed ball")
        case .balk: button(startingWith: "Balk")
        case .advanceOnError: button(startingWith: "Advanced on error")
        case .outOnAppeal: button(startingWith: "Out on appeal")
        case .defensiveIndifference: button(startingWith: "Took the base, no throw")
        case .other: app.buttons["(no button for other)"]
        }
        try tap(choice, "the \(reason) choice")

        // Where the runner ended up.
        let endWord: String = switch move.to {
        case .scored: "Scored"
        case .out: "Out"
        default: move.to.base == move.from ? "Stays" : Self.endLabel(move.to)
        }
        try tap(app.buttons[endWord], "\"\(endWord)\" for \(name(move.runner))")
        if move.to == .out {
            // Who put them out, tapped on the drawing, unless the suggestion already has them.
            let shown = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Fielders:")).firstMatch
            let wanted = move.outBy.isEmpty ? "Fielders: none tapped" : "Fielders: " + move.outBy.map { String($0.rawValue) }.joined(separator: "-")
            if shown.exists, shown.label != wanted {
                if app.buttons["Clear"].exists { app.buttons["Clear"].tap() }
                for fielder in move.outBy { try tap(fielderButton(fielder), "the \(fielder.name) on the drawing") }
            }
        }
        if move.wasStealing { gap("a pickoff while stealing: the driver does not set it yet") }
        if !action.errors.isEmpty { throw DriverStop(description: "the driver does not enter errors between pitches yet") }
        try tap(button(startingWith: "Save"), "the Save button")
    }

    // MARK: Prompts and changes

    /// The defense check when our team takes the field: nobody moved.
    private func confirmDefense(team: TeamSide, before: Situation, index: Int) throws {
        let confirm = app.buttons["Everyone’s where they were"]
        let saveChanges = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@ AND label CONTAINS %@", "Save ", " change")).firstMatch
        if !appears(confirm, within: 3), !saveChanges.exists {
            // The check is not open by itself: open it from the Defense button on the banner.
            try tap(app.buttons["Defense"], "the Defense button")
        }
        if !appears(confirm, within: 2), saveChanges.exists {
            // The check opened with changes nobody made. Record it, then put every marked
            // position back to the player there now, as a careful scorer would.
            let marked = app.buttons.matching(NSPredicate(format: "label ENDSWITH %@", ", changed"))
                .allElementsBoundByIndex.map(\.label)
            gap("event \(index): the defense check opened already set to change the defense (\(marked.joined(separator: "; "))), so \"Everyone’s where they were\" was not there; tapping the big button would have recorded a substitution nobody made. Put back by hand.")
            let fielders = before[team].fielders
            for position in Position.allCases {
                let title = position.name.prefix(1).uppercased() + position.name.dropFirst()
                let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@ AND label ENDSWITH %@", title + ":", ", changed")).firstMatch
                guard row.exists else { continue }
                guard let here = fielders.first(where: { $0.position == position })?.player,
                      let full = player(here)?.displayName else { continue }
                let chip = button(startingWith: full)
                if !chip.exists { row.tap() }
                try tap(chip, "\(full) among the players for \(position.name)")
            }
        }
        try tap(confirm, "\"Everyone’s where they were\"")
    }

    /// Who runs for a designated non-runner who just reached: the prompt opens by itself.
    private func enterRunnerForNonRunner(_ choice: RunnerForNonRunner) throws {
        let row = button(containing: player(choice.runner)?.displayName ?? choice.runner.rawValue)
        if !appears(row, within: 3) {
            try tap(app.buttons["Substitutions"], "the Subs button")
            try tap(button(startingWith: "Runner for a non-runner"), "\"Runner for a non-runner\"")
        }
        try tap(row, "\(name(choice.runner)) in \"Who runs?\"")
        try tap(app.buttons["\(shortName(choice.runner)) runs for \(shortName(choice.replacing))"], "the confirm button")
    }

    /// A new pitcher: tap the pitcher on the field, pick the new one, say whose batting spot
    /// they take, confirm. A defense check that is open first is put off with "Later"; it comes
    /// back after the change.
    private func enterPitchingChange(_ change: PitchingChange, before: Situation, index: Int) throws {
        if app.buttons["Everyone’s where they were"].exists {
            try tap(app.buttons["Later"], "\"Later\" on the defense check")
        }
        try tap(button(startingWith: "Pitching: "), "the pitcher on the field")
        try tap(button(containing: player(change.newPitcher)?.displayName ?? change.newPitcher.rawValue),
                "\(name(change.newPitcher)) in the pitching change")
        if change.previousPitcherMovesTo != nil {
            throw DriverStop(description: "the driver does not move the old pitcher to another position yet")
        }
        if let spotOf = change.takesBattingSpotOf {
            // The batting spot menu offers every spot in the order, or none.
            let menu = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Batting spot:")).firstMatch
            guard appears(menu, within: 3) else { throw missing("the batting spot menu") }
            // The menu sits at the bottom of a long list: scroll until it is clear of the
            // confirm button pinned along the bottom edge.
            let confirm = app.buttons["\(shortName(change.newPitcher)) pitches"]
            for _ in 0..<6 where !menu.isHittable || menu.frame.maxY > confirm.frame.minY {
                app.swipeUp()
            }
            menu.tap()
            let choice = app.buttons.matching(NSPredicate(format: "label ENDSWITH %@", "in \(shortName(spotOf))’s spot")).firstMatch
            try tap(choice, "\(name(spotOf))’s spot in the batting spot menu")
        }
        try tap(app.buttons["\(shortName(change.newPitcher)) pitches"], "the confirm button")
    }

    /// A pinch hitter, through the Subs button's changes menu.
    private func enterSubstitution(_ change: Substitution) throws {
        guard change.defense.isEmpty, change.leavesField.isEmpty, change.batting.count == 1,
              let swap = change.batting.first, swap.kind == .pinchHitter else {
            throw DriverStop(description: "the driver enters only a single pinch hitter so far")
        }
        try tap(app.buttons["Substitutions"], "the Subs button")
        try tap(button(startingWith: "Pinch hitter"), "\"Pinch hitter\" in the changes menu")
        try tap(button(containing: player(swap.incoming)?.displayName ?? swap.incoming.rawValue), "\(name(swap.incoming)) in the pinch hitter list")
        try tap(app.buttons["\(shortName(swap.incoming)) bats"], "the confirm button")
    }

    /// The end of the game: "End game" on the "Is the game over?" pop-up when it asks, or else
    /// the game menu's End game with the reason.
    private func endGame(_ end: EndOfGame) throws {
        if appears(app.buttons["Keep playing"], within: 2) {
            try tap(app.buttons["End game"], "\"End game\" on \"Is the game over?\"")
            return
        }
        // A defense check open for the next half-inning is put off first.
        if app.buttons["Everyone’s where they were"].exists {
            try tap(app.buttons["Later"], "\"Later\" on the defense check")
        }
        try tap(app.buttons["Game menu"], "the game menu")
        // The menu opens half-height; End game is at the bottom of its list.
        let endGame = button(startingWith: "End game")
        for _ in 0..<4 where !endGame.exists || !endGame.isHittable {
            button(startingWith: "Manual adjustment").swipeUp()
        }
        try tap(endGame, "\"End game\" in the game menu")
        let reason: String = switch end.reason {
        case .regulation: "End game: innings complete"
        case .timeLimit: "End game: time limit"
        case .runRule: "End game: run rule"
        case .called: "End game: rain or darkness"
        }
        try tap(app.buttons[reason], "\"\(reason)\"")
    }

    // MARK: - Finding and tapping

    /// Waits for an element and taps it, or stops naming what was missing.
    private func tap(_ element: XCUIElement, _ what: String) throws {
        // `exists` first: `waitForExistence` always pauses about a second before looking.
        guard element.exists || element.waitForExistence(timeout: 5) else { throw missing(what) }
        element.tap()
    }

    /// True when the element is on screen now, or shows up within this many seconds.
    private func appears(_ element: XCUIElement, within seconds: TimeInterval) -> Bool {
        element.exists || element.waitForExistence(timeout: seconds)
    }

    /// A stop for a button that is not on the screen.
    private func missing(_ what: String) -> DriverStop {
        DriverStop(description: "could not find \(what) on the screen")
    }

    /// A button whose words start with these.
    private func button(startingWith words: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", words)).firstMatch
    }

    /// A button whose words include these (a player row: number badge, name, detail).
    private func button(containing words: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", words)).firstMatch
    }

    /// Records an expected event the screens cannot enter exactly, as a test failure, and
    /// carries on.
    private func gap(_ words: String) {
        gaps.append(words)
        enteringGap = true
        XCTFail("Screens cannot enter this: \(words)")
    }

    /// Adds a picture of the screen to the test results.
    func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        XCTContext.runActivity(named: name) { $0.add(attachment) }
    }

    // MARK: - Words the screens use

    /// A player in the game.
    private func player(_ id: PlayerID) -> Player? { expected.setup.player(id) }
    /// A player's last name, as the screens show it.
    private func shortName(_ id: PlayerID?) -> String {
        guard let id else { return "nobody" }
        return player(id)?.lastName ?? id.rawValue
    }
    /// The same, for messages.
    private func name(_ id: PlayerID?) -> String { shortName(id) }

    /// The base button on the runner step: "1st", "2nd", "3rd", "Scored", "Out".
    static func endLabel(_ end: RunnerEnd) -> String {
        switch end {
        case .first: "1st"
        case .second: "2nd"
        case .third: "3rd"
        case .scored: "Scored"
        case .out: "Out"
        }
    }

    /// The batted-ball chip: "Ground", "Fly", "Line", "Pop-up", "Bunt".
    static func chipTitle(_ kind: BattedBallType) -> String {
        switch kind {
        case .groundBall: "Ground"
        case .flyBall: "Fly"
        case .lineDrive: "Line"
        case .popUp: "Pop-up"
        case .bunt: "Bunt"
        }
    }

    /// The fielder at a position as a person: "shortstop", "first baseman".
    static func fielderWord(_ position: Position) -> String {
        switch position {
        case .pitcher: "pitcher"
        case .catcher: "catcher"
        case .firstBase: "first baseman"
        case .secondBase: "second baseman"
        case .thirdBase: "third baseman"
        case .shortstop: "shortstop"
        case .leftField: "left fielder"
        case .centerField: "center fielder"
        case .rightField: "right fielder"
        }
    }

    /// The box score with the game's length taken out ("T—3:12."): the app's clock runs while
    /// the test taps, so its length is minutes, not the book's hours.
    static func withoutGameLength(_ box: String) -> String {
        box.replacingOccurrences(of: #"[ \n]?T—\d+:\d\d\."#, with: "", options: .regularExpression)
    }
}
