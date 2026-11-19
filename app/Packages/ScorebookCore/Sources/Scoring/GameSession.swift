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

    /// Reopens a game saved earlier (the app was closed mid-game). If the phone died between
    /// saving the scorer's last event and the automatic out that should follow it, that out is
    /// recorded now, before anything else.
    public static func resume(_ game: Game, storage: any ScorebookStorage,
                              engine: any RulesEngine = ScorebookRulesEngine(),
                              stats: any StatsCalculator = StatsEngine()) async -> GameSession {
        let session = GameSession(game: game, storage: storage, engine: engine, stats: stats)
        _ = await session.oneAtATime {
            await session.recordAutomaticOuts()
            return true
        }
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

    /// The scorer's own last entry: the last event that is neither an automatic out the app
    /// added nor a defense check confirmed with no changes. A confirmed check changes nothing
    /// in the game, so Undo passes over it to the last real entry (and takes the check with it,
    /// so the check comes back once that entry is put back).
    private var lastScorerEventIndex: Int? {
        game.events.lastIndex { !$0.isAutomaticOut && !$0.isDefenseConfirmed }
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

    // MARK: One change at a time

    /// The change being saved now, if any. Each new change waits for it to finish, so two
    /// quick taps (Undo twice, a pitch during a slow save) are made one after the other, each
    /// starting from the game the one before left, and nothing is saved twice.
    private var lastChange: Task<Bool, Never>?

    /// Runs one change after every change asked for before it has finished.
    private func oneAtATime(_ change: @escaping @MainActor () async -> Bool) async -> Bool {
        let previous = lastChange
        let task = Task { @MainActor in
            _ = await previous?.value
            return await change()
        }
        lastChange = task
        return await task.value
    }

    /// Records one event: saves it, then updates the game. Clears Redo. Afterward records an
    /// automatic out if a batting hole has come up. Returns false if the save failed (the
    /// game is then unchanged and `saveProblem` says why).
    @discardableResult
    public func record(_ event: GameEvent) async -> Bool {
        await oneAtATime { await self.recordNow(event) }
    }

    /// Records an event a sheet handed back, first adding any players the scorer created on
    /// the spot (a new pitcher known only by number) to that team's game roster.
    @discardableResult
    public func record(_ entered: EnteredEvent) async -> Bool {
        await oneAtATime { await self.recordNow(entered) }
    }

    /// Puts an edited player in place of the one with the same id on one team's game roster.
    @discardableResult
    public func updatePlayer(_ player: Player, on side: TeamSide) async -> Bool {
        await oneAtATime { await self.updatePlayerNow(player, on: side) }
    }

    /// Takes back the scorer's last event, with any automatic outs after it, keeping it for Redo.
    @discardableResult
    public func undo() async -> Bool {
        await oneAtATime { await self.undoNow() }
    }

    /// Puts back the event Undo just took back.
    @discardableResult
    public func redo() async -> Bool {
        await oneAtATime { await self.redoNow() }
    }

    /// Puts a dropped-third-strike play on the strike-three pitch.
    @discardableResult
    public func addDroppedThirdStrike(_ play: Play) async -> Bool {
        await oneAtATime { await self.addDroppedThirdStrikeNow(play) }
    }

    /// Applies a fix from the play-by-play.
    @discardableResult
    public func apply(_ edit: EventEdit) async -> Bool {
        await oneAtATime { await self.applyNow(edit) }
    }

    /// Changes the game's details mid-game: the date and start time, or the number of innings.
    @discardableResult
    public func changeDetails(_ change: @escaping @MainActor (inout GameSetup) -> Void) async -> Bool {
        await oneAtATime { await self.changeDetailsNow(change) }
    }

    /// Swaps which team is home and which is away. Only before the first pitch (see
    /// `canSwitchHomeAndAway`).
    @discardableResult
    public func switchHomeAndAway() async -> Bool {
        await oneAtATime { await self.switchHomeAndAwayNow() }
    }

    /// Fixes who a player in the game really was (see `LineupCorrection`).
    @discardableResult
    public func correctLineup(_ correction: LineupCorrection) async -> Bool {
        await oneAtATime { await self.correctLineupNow(correction) }
    }

    // MARK: Recording

    /// Records one event: saves it, then updates the game. Clears Redo. Afterward records an
    /// automatic out if a batting hole has come up. Returns false if the save failed (the
    /// game is then unchanged and `saveProblem` says why).
    @discardableResult
    private func recordNow(_ event: GameEvent) async -> Bool {
        guard await append(event) else { return false }
        redoStack.removeAll()
        await recordAutomaticOuts()
        return true
    }

    /// Records an event a sheet handed back, first adding any players the scorer created on
    /// the spot (a new pitcher known only by number) to that team's game roster.
    @discardableResult
    private func recordNow(_ entered: EnteredEvent) async -> Bool {
        guard !entered.newPlayers.isEmpty else { return await recordNow(entered.event) }
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
    private func updatePlayerNow(_ player: Player, on side: TeamSide) async -> Bool {
        var changed = game
        changed.setup.replace(player, on: side)
        return await saveWhole(changed)
    }

    /// Takes back the scorer's last event, along with any automatic outs the app added after
    /// it, and keeps it for Redo.
    @discardableResult
    private func undoNow() async -> Bool {
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
    private func redoNow() async -> Bool {
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
    private func addDroppedThirdStrikeNow(_ play: Play) async -> Bool {
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
    private func applyNow(_ edit: EventEdit) async -> Bool {
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

    // MARK: Fixing the game's details and lineups

    /// True until the first pitch: home and away can only be switched while nobody has batted,
    /// since the top of the first belongs to whoever was away. Lineup business before then (a
    /// substitution, a pitching change, an added hitter, a batting hole) moves with its team.
    public var canSwitchHomeAndAway: Bool {
        game.events.allSatisfy { event in
            switch event.kind {
            case .defenseConfirmed, .automaticOut, .battingHole, .timeLimitChange,
                 .substitution, .pitchingChange, .addHitter: true
            default: false
            }
        }
    }

    /// True when a hitter can come out of the starting batting order: before the first pitch,
    /// he is in the starting order, and nothing is recorded for his team but a defense check.
    public func canRemoveFromOrder(_ player: PlayerID, on side: TeamSide) -> Bool {
        canChangeStartingOrder(side) && game.setup[side].battingOrder.contains(player)
    }

    /// True before the first pitch while nothing but a defense check is recorded for a team,
    /// so its starting batting order can still lose a hitter.
    public func canChangeStartingOrder(_ side: TeamSide) -> Bool {
        guard canSwitchHomeAndAway else { return false }
        return game.events.allSatisfy { event in
            switch event.kind {
            case .defenseConfirmed, .timeLimitChange: true
            case .battingHole(let e): e.team != side
            case .automaticOut(let e): e.team != side
            case .substitution(let e): e.team != side
            case .pitchingChange(let e): e.team != side
            case .addHitter(let e): e.team != side
            default: false
            }
        }
    }

    /// Changes the setup's date, start time or innings and replays. Clears Redo.
    @discardableResult
    private func changeDetailsNow(_ change: @MainActor (inout GameSetup) -> Void) async -> Bool {
        var changed = game
        change(&changed.setup)
        changed.setup.scheduledStart = changed.setup.scheduledStart.wholeSecond
        changed.setup.rules.scheduledInnings = max(1, changed.setup.rules.scheduledInnings)
        guard changed != game else { return true }
        guard await saveWhole(changed) else { return false }
        redoStack.removeAll()
        return true
    }

    /// Swaps the two teams, and with them the side named in each pregame entry: a defense check
    /// is dropped (it was for the team that was fielding first) and will be asked again, a
    /// batting hole or lineup change moves with its team, and automatic outs are worked out again.
    @discardableResult
    private func switchHomeAndAwayNow() async -> Bool {
        guard canSwitchHomeAndAway else {
            saveProblem = "Home and away can switch only before the first pitch. Undo back to before it, then switch."
            return false
        }
        var changed = game
        swap(&changed.setup.away, &changed.setup.home)
        changed.events = changed.events.compactMap { event in
            var event = event
            switch event.kind {
            case .defenseConfirmed, .automaticOut: return nil
            case .battingHole(var hole):
                hole.team = hole.team.opponent
                event.kind = .battingHole(hole)
            case .substitution(var change):
                change.team = change.team.opponent
                event.kind = .substitution(change)
            case .pitchingChange(var change):
                change.team = change.team.opponent
                event.kind = .pitchingChange(change)
            case .addHitter(var added):
                added.team = added.team.opponent
                event.kind = .addHitter(added)
            default: break
            }
            return event
        }
        guard await saveWhole(changed) else { return false }
        redoStack.removeAll()
        defenseCheckPostponedAt = nil
        await recordAutomaticOuts()
        return true
    }

    /// Replaces one team's starting lineup (batting order, fielders, designated non-runners,
    /// roster) with one fixed on the game menu's Rosters page, after a rushed start. Everything
    /// already recorded follows the batting order by spot: if the hitter listed third was really
    /// someone else, every plate appearance, run and stolen base of the third spot becomes theirs.
    /// Fielding credit goes by position, so it follows the new fielders by itself. Once a team's
    /// order has come around, its length can no longer change here (use Add a hitter).
    public func editStartingLineup(_ team: GameTeam, on side: TeamSide) async -> Bool {
        await oneAtATime { await self.editStartingLineupNow(team, on: side) }
    }

    @discardableResult
    private func editStartingLineupNow(_ team: GameTeam, on side: TeamSide) async -> Bool {
        let old = game.setup[side]
        let oldOrder = old.battingOrder, newOrder = team.battingOrder
        // Plate appearances the team has had: a different length is only safe before the order
        // comes around, since every spot after the change would shift.
        let appearances = log.entries.filter { $0.half.battingSide == side && $0.plateAppearance != nil }.count
        if oldOrder.count != newOrder.count, appearances > min(oldOrder.count, newOrder.count) {
            saveProblem = "The \(old.name) order has already come around, so hitters can’t be added to or taken out of the starting order now. Use Subs, Add a hitter."
            return false
        }
        // Who each spot's references become: the player listed there before → the one listed now.
        var map: [PlayerID: PlayerID] = [:]
        for i in 0..<min(oldOrder.count, newOrder.count) where oldOrder[i] != newOrder[i] {
            map[oldOrder[i]] = newOrder[i]
        }
        var changed = game
        var newTeam = team
        newTeam.teamID = old.teamID
        newTeam.name = old.name
        newTeam.isOurs = old.isOurs
        newTeam.shortName = old.shortName
        changed.setup[side] = newTeam
        changed.events = game.events.map { Self.remappingBatters($0, team: side, map) }
        guard changed != game else { return true }
        guard await saveWhole(changed) else { return false }
        redoStack.removeAll()
        await recordAutomaticOuts()
        return true
    }

    /// One event with the batting team's hitters and runners renamed through `map`, leaving
    /// pitchers and fielders alone.
    static func remappingBatters(_ event: GameEvent, team side: TeamSide, _ map: [PlayerID: PlayerID]) -> GameEvent {
        guard !map.isEmpty else { return event }
        func m(_ id: PlayerID) -> PlayerID { map[id] ?? id }
        func moves(_ list: [RunnerMove]) -> [RunnerMove] { list.map { var move = $0; move.runner = m(move.runner); return move } }
        var event = event
        switch event.kind {
        case .ballInPlay(var play):
            play.runners = moves(play.runners)
            event.kind = .ballInPlay(play)
        case .pitch(var pitch):
            if var play = pitch.droppedThirdStrike {
                play.runners = moves(play.runners)
                pitch.droppedThirdStrike = play
                event.kind = .pitch(pitch)
            }
        case .runnerAction(var action):
            action.moves = moves(action.moves)
            event.kind = .runnerAction(action)
        case .substitution(var sub) where sub.team == side:
            sub.batting = sub.batting.map { var change = $0; change.incoming = m(change.incoming); change.replacing = m(change.replacing); return change }
            event.kind = .substitution(sub)
        case .runnerForNonRunner(var r):
            r.runner = m(r.runner)
            r.replacing = m(r.replacing)
            event.kind = .runnerForNonRunner(r)
        case .pitchingChange(var change) where change.team == side:
            change.takesBattingSpotOf = change.takesBattingSpotOf.map(m)
            event.kind = .pitchingChange(change)
        case .addHitter(var add) where add.team == side:
            add.player = m(add.player)
            event.kind = .addHitter(add)
        case .manualAdjustment(var adjustment):
            if var runners = adjustment.runners {
                runners.first = runners.first.map(m)
                runners.second = runners.second.map(m)
                runners.third = runners.third.map(m)
                adjustment.runners = runners
                event.kind = .manualAdjustment(adjustment)
            }
        default:
            break
        }
        return event
    }

    /// Applies a lineup correction and replays. Clears Redo.
    @discardableResult
    private func correctLineupNow(_ correction: LineupCorrection) async -> Bool {
        var changed = game
        switch correction {
        case .wasReally(let side, let shown, let really):
            guard shown != really.id else { return true }
            guard let fixed = Self.swapping(shown, with: really, on: side, in: changed) else {
                saveProblem = "That lineup fix could not be made, so nothing changed."
                return false
            }
            changed = fixed
        case .removeFromOrder(let side, let player):
            // Before the first pitch only, and only from the starting order with nothing yet
            // recorded for that team: batting holes and automatic outs are kept by spot number,
            // which taking a hitter out would shift.
            guard canRemoveFromOrder(player, on: side) else {
                saveProblem = "A hitter can come out of the order only before the first pitch, and only before any batting hole or lineup change for that team."
                return false
            }
            changed.setup[side].battingOrder.removeAll { $0 == player }
            changed.setup[side].designatedNonRunners.removeAll { $0 == player }
        }
        guard await saveWhole(changed) else { return false }
        redoStack.removeAll()
        await recordAutomaticOuts()
        return true
    }

    /// The game with two players' places exchanged everywhere: the starting batting order and
    /// defense, the designated non-runners, the fielding turns and every event. `really` is
    /// added to the team's roster if new. When `really` was not in the game, this simply puts
    /// them where `shown` was, and `shown` goes to the bench.
    static func swapping(_ shown: PlayerID, with really: Player, on side: TeamSide, in game: Game) -> Game? {
        var changed = game
        changed.setup.add(really, to: side)
        let a = shown, b = really.id
        func swapped(_ id: PlayerID) -> PlayerID { id == a ? b : (id == b ? a : id) }
        var team = changed.setup[side]
        team.battingOrder = team.battingOrder.map(swapped)
        team.defense = team.defense.map { FielderAssignment(position: $0.position, player: swapped($0.player)) }
        team.designatedNonRunners = team.designatedNonRunners.map(swapped)
        team.fieldingRotations = team.fieldingRotations.map { FieldingRotation(position: $0.position, players: $0.players.map(swapped)) }
        changed.setup[side] = team

        // Every event that names either player: rewritten through its saved form, so no kind
        // of event can be missed. Player ids are long random codes, so the quoted id matches
        // nothing else.
        guard let data = try? ScorebookJSON.encode(changed.events),
              var text = String(data: data, encoding: .utf8) else { return nil }
        let placeholder = "\"swap-\(UUID().uuidString)\""
        text = text.replacingOccurrences(of: "\"\(a.rawValue)\"", with: placeholder)
            .replacingOccurrences(of: "\"\(b.rawValue)\"", with: "\"\(a.rawValue)\"")
            .replacingOccurrences(of: placeholder, with: "\"\(b.rawValue)\"")
        guard let events = try? ScorebookJSON.decoder().decode([GameEvent].self, from: Data(text.utf8)) else { return nil }
        changed.events = events
        return changed
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

    /// Lets the defense check open again straight away: after the scorer left it for the
    /// dropped-third-strike steps, it comes back if the inning still ends.
    public func reopenDefenseCheck() {
        defenseCheckPostponedAt = nil
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

    /// True for a defense check confirmed with nobody moving.
    var isDefenseConfirmed: Bool {
        if case .defenseConfirmed = kind { return true }
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

extension Situation {
    /// Where the game stands in one line, for automated checks and for debugging: the half
    /// inning, outs, count, score, who is on each base, the batter and both pitchers.
    /// "top 3 · 1 out · 2-1 · 2-4 · 1st:m4 3rd:m2 · up:m6 · pitching:d9/m10".
    public var checkLine: String {
        let bases = runners.sorted { $0.base < $1.base }
            .map { "\($0.base.rawValue):\($0.runner.rawValue)" }.joined(separator: " ")
        let state = isFinal ? "final" : (isBetweenHalfInnings ? "between" : "playing")
        return [
            "\(half.rawValue) \(inning)", "\(outs) out", "\(count.balls)-\(count.strikes)",
            "\(score.away)-\(score.home)", bases.isEmpty ? "empty" : bases,
            "up:\(batter?.rawValue ?? "-")",
            "pitching:\(away.pitcher?.rawValue ?? "-")/\(home.pitcher?.rawValue ?? "-")", state,
        ].joined(separator: " · ")
    }
}
