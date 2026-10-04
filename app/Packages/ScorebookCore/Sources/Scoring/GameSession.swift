// Scoring: one game being scored, connecting the saved game, the rules engine and the stats.
//
// The batting screen and the sheets never change the game themselves. They hand back an
// event ("ball", "6-3", "pitching change"), and the app shell passes it to a `GameSession`,
// which:
//   1. saves it through storage first, so a dead battery a moment later loses nothing;
//   2. only then adds it to the game and replays every event through the rules engine, which
//      works out where the game stands (the `Situation`) and the play log;
//   3. works out the box score so far from the play log, through the stats engine.
//
// It also keeps what Undo and Redo need, records the automatic out when a batting hole comes
// up (the league's rule for a team that lost a hitter), and remembers when the scorer said
// "Later" to the defense check or let a designated non-runner run themselves, so those
// prompts do not pop up again straight away.
//
// The session lives on the main thread (`@MainActor`), the same thread that draws the
// screens, and is `@Observable`, so a screen showing it redraws whenever it changes.

import Foundation
import Observation
import Model
import GameEngine
import Stats

/// One game being scored.
@MainActor
@Observable
public final class GameSession {
    /// The game: its setup and every event so far, exactly as saved.
    public private(set) var game: Game
    /// Where the game stands and the play log, from replaying every event.
    public private(set) var replay: GameReplay
    /// The box score so far (or final), from the play log.
    public private(set) var boxScore: BoxScore
    /// Events taken back by Undo, newest last, ready for Redo. Recording anything new clears it.
    public private(set) var redoStack: [GameEvent] = []
    /// A plain message when the last save failed, for the screen to show. Nothing changed in
    /// the game when this is set: the event was not added, so the scorer can try again.
    public var saveProblem: String?

    /// The designated non-runner the scorer let run themselves. The "who runs for them?"
    /// prompt stays closed while they are still the runner it would ask about.
    public private(set) var nonRunnerRunsThemselves: PlayerID?
    /// The number of events when the scorer said "Later" to the defense check. The check
    /// stays closed until something else is recorded.
    public private(set) var defenseCheckPostponedAt: Int?
    /// The number of events when the scorer backed out of the "who runs?" prompt without
    /// answering. It stays closed until something else is recorded.
    public private(set) var nonRunnerPromptPostponedAt: Int?

    /// Where games are saved.
    private let storage: any ScorebookStorage
    /// The league's rules: replays events into a situation, suggests runners, keeps the clock.
    public let engine: any RulesEngine
    /// Turns the play log into box scores and batter histories.
    public let stats: any StatsCalculator

    /// Opens a game for scoring: one already saved (a game in progress being resumed) or one
    /// just created by `start(setup:storage:)`.
    public init(game: Game, storage: any ScorebookStorage,
                engine: any RulesEngine = ScorebookRulesEngine(),
                stats: any StatsCalculator = StatsEngine()) {
        self.game = game
        self.storage = storage
        self.engine = engine
        self.stats = stats
        let replay = engine.replay(game)
        self.replay = replay
        self.boxScore = stats.boxScore(for: replay.log)
    }

    /// Starts a new game from the pregame screens' setup: saves it with no events yet (so it
    /// is "the game in progress" if the app closes before the first pitch), then opens it.
    public static func start(setup: GameSetup, storage: any ScorebookStorage,
                             engine: any RulesEngine = ScorebookRulesEngine(),
                             stats: any StatsCalculator = StatsEngine()) async throws -> GameSession {
        let game = Game(setup: setup)
        try await storage.saveGame(game)
        let session = GameSession(game: game, storage: storage, engine: engine, stats: stats)
        // A batting hole leading off the game is an out before anyone bats.
        await session.recordAutomaticOuts()
        return session
    }

    // MARK: What the screens read

    /// Where the game stands now.
    public var situation: Situation { replay.situation }
    /// Every event so far in words, with outs, runs and notation.
    public var log: PlayLog { replay.log }
    /// The game's setup: teams, rosters, batting orders, rules.
    public var setup: GameSetup { game.setup }
    /// True once the scorer has ended the game.
    public var isFinished: Bool { game.isFinished }

    /// The batter's earlier plate appearances today, for the line under their name.
    public var batterHistory: [PlateAppearanceSummary] {
        guard let batter = situation.batter else { return [] }
        return stats.plateAppearances(of: batter, in: log)
    }

    /// Each player's plate appearances today, for the game overview's batter history.
    public var plateAppearancesByPlayer: [PlayerID: [PlateAppearanceSummary]] {
        var result: [PlayerID: [PlateAppearanceSummary]] = [:]
        for player in setup.away.roster + setup.home.roster {
            let appearances = stats.plateAppearances(of: player.id, in: log)
            if !appearances.isEmpty { result[player.id] = appearances }
        }
        return result
    }

    /// The game clock at a moment: time left, last inning, and whether to ask if the game is
    /// over on time.
    public func clock(at now: Date) -> GameClock { engine.clock(for: situation, at: now) }

    /// What a pitch would do to the count now ("makes it 2–1", "walk").
    public func countAfter(_ pitch: PitchResult) -> CountChange { engine.countAfter(pitch, in: situation) }

    /// True when the "who runs for the designated non-runner?" prompt should be open: the rules
    /// engine says one just reached base, and the scorer has not already said they run.
    public var showsNonRunnerPrompt: Bool {
        guard let choice = situation.runnerChoice, !situation.isFinal else { return false }
        return choice.nonRunner != nonRunnerRunsThemselves && nonRunnerPromptPostponedAt != game.events.count
    }

    /// True when the defense check should be open: our team is taking the field, and the
    /// scorer has not said "Later" since the last event.
    public var showsDefenseCheck: Bool {
        situation.defenseCheckDue && !situation.isFinal && defenseCheckPostponedAt != game.events.count
    }

    // MARK: Undo and redo

    /// The scorer's own last event: the last one that is not an automatic out the app added.
    private var lastScorerEventIndex: Int? {
        game.events.lastIndex { !$0.isAutomaticOut }
    }

    /// True when there is something to undo.
    public var canUndo: Bool { lastScorerEventIndex != nil }

    /// What Undo would take back, in a word or two ("ball", "6-3"), or nothing.
    public var undoLabel: String? {
        guard let index = lastScorerEventIndex else { return nil }
        let event = game.events[index]
        let notation = log.entries.first { $0.event.id == event.id }?.notation
        return Self.label(for: event, notation: notation)
    }

    /// What Redo would put back, right after an undo, or nothing.
    public var redoLabel: String? {
        guard let event = redoStack.last else { return nil }
        return Self.label(for: event, notation: engine.notation(for: event, in: situation))
    }

    /// An event's undo label: the scorebook notation for a ball in play or a runner move
    /// ("6-3", "SB"), else a word for the kind ("ball", "pitching change").
    static func label(for event: GameEvent, notation: String?) -> String {
        switch event.kind {
        case .ballInPlay, .runnerAction, .errorWithNoAdvance:
            if let notation, !notation.isEmpty { return notation }
            return event.kind.label
        default:
            return event.kind.label
        }
    }

    // MARK: Recording

    /// Records one event: saves it, then updates the game. Clears Redo. Afterward records an
    /// automatic out if a batting hole has come up. Returns false if the save failed (the
    /// game is then unchanged and `saveProblem` says why).
    @discardableResult
    public func record(_ event: GameEvent) async -> Bool {
        guard await append(event) else { return false }
        redoStack.removeAll()
        await recordAutomaticOuts()
        return true
    }

    /// Records an event a sheet handed back, first adding any players the scorer created on
    /// the spot (a new pitcher known only by number) to that team's game roster.
    @discardableResult
    public func record(_ entered: EnteredEvent) async -> Bool {
        guard !entered.newPlayers.isEmpty else { return await record(entered.event) }
        var changed = game
        for addition in entered.newPlayers {
            changed.setup.add(addition.player, to: addition.side)
        }
        changed.events.append(entered.event)
        guard await saveWhole(changed) else { return false }
        redoStack.removeAll()
        await recordAutomaticOuts()
        return true
    }

    /// Puts an edited player in place of the one with the same id on one team's game roster
    /// (a name, number or batting side filled in). Rosters change without an event.
    @discardableResult
    public func updatePlayer(_ player: Player, on side: TeamSide) async -> Bool {
        var changed = game
        changed.setup.replace(player, on: side)
        return await saveWhole(changed)
    }

    /// Takes back the scorer's last event, along with any automatic outs the app added after
    /// it, and keeps it for Redo.
    @discardableResult
    public func undo() async -> Bool {
        guard let index = lastScorerEventIndex else { return false }
        var changed = game
        let taken = changed.events[index]
        changed.events.removeSubrange(index...)
        guard await saveWhole(changed) else { return false }
        redoStack.append(taken)
        // Undoing past the "Later" moment brings the defense check back.
        if let postponed = defenseCheckPostponedAt, postponed > game.events.count { defenseCheckPostponedAt = nil }
        if let postponed = nonRunnerPromptPostponedAt, postponed > game.events.count { nonRunnerPromptPostponedAt = nil }
        return true
    }

    /// Puts back the event Undo just took back.
    @discardableResult
    public func redo() async -> Bool {
        guard let event = redoStack.last else { return false }
        guard await append(event) else { return false }
        redoStack.removeLast()
        await recordAutomaticOuts()
        return true
    }

    /// After "Dropped 3rd strike": puts the play (thrown out, or safe, and where the runners
    /// went) on the strike-three pitch, in place of the plain strikeout. The pitch keeps its id
    /// and time. Automatic outs after it are worked out again.
    @discardableResult
    public func addDroppedThirdStrike(_ play: Play) async -> Bool {
        guard let index = strikeThreeIndex, case .pitch(let pitch) = game.events[index].kind else { return false }
        var changed = game
        var event = changed.events[index]
        event.kind = .pitch(Pitch(pitch.result, droppedThirdStrike: play))
        changed.events.removeSubrange(index...)
        changed.events.append(event)
        guard await saveWhole(changed) else { return false }
        redoStack.removeAll()
        await recordAutomaticOuts()
        return true
    }

    /// The strike-three pitch the "Dropped 3rd strike" button refers to: the scorer's last
    /// event, when it is a pitch.
    private var strikeThreeIndex: Int? {
        guard let index = lastScorerEventIndex, case .pitch = game.events[index].kind else { return nil }
        return index
    }

    /// Where the game stood just before the strike-three pitch, so the in-play sequence for a
    /// dropped third strike shows the batter who struck out and the runners as they were.
    public var situationBeforeStrikeThree: Situation? {
        guard let index = strikeThreeIndex else { return nil }
        let earlier = Game(id: game.id, setup: game.setup, events: Array(game.events[..<index]))
        return engine.replay(earlier).situation
    }

    /// Where the game stood just before one earlier event, so that event can be entered again
    /// from the same spot when the scorer fixes it from the play-by-play.
    public func situation(before id: EventID) -> Situation? {
        guard let index = game.events.firstIndex(where: { $0.id == id }) else { return nil }
        let earlier = Game(id: game.id, setup: game.setup, events: Array(game.events[..<index]))
        return engine.replay(earlier).situation
    }

    /// Applies a change to an earlier event from the play-by-play (replace, delete or insert),
    /// then works out everything after it again. Clears Redo.
    @discardableResult
    public func apply(_ edit: EventEdit) async -> Bool {
        var changed = game
        switch edit {
        case .replace(let event):
            guard let i = changed.events.firstIndex(where: { $0.id == event.id }) else { return false }
            changed.events[i] = event
        case .delete(let id):
            changed.events.removeAll { $0.id == id }
        case .insert(let event, let after):
            if let after {
                guard let i = changed.events.firstIndex(where: { $0.id == after }) else { return false }
                changed.events.insert(event, at: i + 1)
            } else {
                changed.events.insert(event, at: 0)
            }
        }
        guard await saveWhole(changed) else { return false }
        redoStack.removeAll()
        await recordAutomaticOuts()
        return true
    }

    // MARK: Prompts

    /// The scorer let the designated non-runner run themselves: keep the prompt closed for them.
    public func letNonRunnerRun() {
        nonRunnerRunsThemselves = situation.runnerChoice?.nonRunner
    }

    /// The scorer backed out of the "who runs?" prompt: keep it closed until the next event.
    public func postponeNonRunnerPrompt() {
        nonRunnerPromptPostponedAt = game.events.count
    }

    /// The scorer said "Later" to the defense check: keep it closed until the next event.
    public func postponeDefenseCheck() {
        defenseCheckPostponedAt = game.events.count
    }

    // MARK: Saving and replaying

    /// Saves one new event at the end of the game, then adds it and replays.
    private func append(_ event: GameEvent) async -> Bool {
        do {
            try await storage.appendEvent(event, toGame: game.id)
        } catch {
            saveProblem = Self.problem(error)
            return false
        }
        game.events.append(event)
        saveProblem = nil
        refresh()
        return true
    }

    /// Saves the whole game (after an undo, an edit or a roster change), then uses it and replays.
    private func saveWhole(_ changed: Game) async -> Bool {
        do {
            try await storage.saveGame(changed)
        } catch {
            saveProblem = Self.problem(error)
            return false
        }
        game = changed
        saveProblem = nil
        refresh()
        return true
    }

    /// Replays every event and works out the box score again.
    private func refresh() {
        replay = engine.replay(game)
        boxScore = stats.boxScore(for: replay.log)
        // The non-runner the scorer let run is forgotten once the prompt is about someone else
        // (or nobody), so the next time they reach base the scorer is asked again.
        if situation.runnerChoice?.nonRunner != nonRunnerRunsThemselves { nonRunnerRunsThemselves = nil }
    }

    /// While a batting hole is up, records the automatic out the league's rule calls for, one
    /// at a time (two holes in a row make two outs). Stops when the game is over.
    func recordAutomaticOuts() async {
        var guardCount = 0
        while situation.isBattingHoleUp, !situation.isFinal, !game.isFinished, guardCount < 30 {
            guardCount += 1
            let side = situation.battingSide
            let out = AutomaticOut(team: side, spotIndex: situation[side].nextBatterIndex)
            guard await append(GameEvent(kind: .automaticOut(out))) else { return }
        }
    }

    /// A save failure in words the scorer can act on.
    static func problem(_ error: Error) -> String {
        "The last change could not be saved, so it was not recorded. Try again. (\(error.localizedDescription))"
    }
}

extension GameEvent {
    /// True for an automatic out: one the app records itself when a batting hole comes up.
    var isAutomaticOut: Bool {
        if case .automaticOut = kind { return true }
        return false
    }
}

extension GameSetup {
    /// Adds a player to one team's game roster, or replaces the one with the same id.
    mutating func add(_ player: Player, to side: TeamSide) {
        replace(player, on: side)
    }

    /// Puts a player on one team's game roster in place of the one with the same id, or adds
    /// them at the end if they are new.
    mutating func replace(_ player: Player, on side: TeamSide) {
        switch side {
        case .away:
            if let i = away.roster.firstIndex(where: { $0.id == player.id }) { away.roster[i] = player } else { away.roster.append(player) }
        case .home:
            if let i = home.roster.firstIndex(where: { $0.id == player.id }) { home.roster[i] = player } else { home.roster.append(player) }
        }
    }
}
