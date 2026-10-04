// What the in-play sequence has on screen right now: which step it is on, what the scorer has
// picked so far, and where they have moved the runners.
//
// Every button on every step sends one `PlayEntryAction` to `PlayEntryModel.perform(_:)`.
// That keeps all the "what happens when I tap this" rules in one place, lets the demos and
// tests replay a play tap by tap, and counts the taps.
//
// Nothing here works out baseball. Notation, outs, runs, runs batted in, the guessed kind of
// batted ball and where the runners went come from the rules engine's functions
// (`PlayEntryRules`). The model keeps track of the scorer's picks, asks the engine again after
// each one, and checks the picks are complete before Save: every runner the scorer put out has
// the fielders who made the out, every "on an error" says whose, and no two runners end on
// one base or pass each other.

import SwiftUI
import Model
import DesignSystem

/// The steps of the sequence, in the order the scorer meets them.
enum PlayEntryStep: Hashable {
    /// "What happened to the batter?"
    case result
    /// After a dropped third strike: thrown out at first, or safe?
    case droppedThirdStrike
    /// Tap the fielders in the order they handled the ball.
    case fielders
    /// Tap where a hit landed (optional).
    case hitLocation
    /// Tap the fielder who made the error.
    case error
    /// Where every runner ended up.
    case runners
}

/// One tap by the scorer. Every button sends one of these.
enum PlayEntryAction: Equatable, Sendable {
    /// Step one: what happened to the batter.
    case pickResult(BatterResult)
    /// Step one: open the "More" choices (sacrifices and catcher's interference).
    case showMore
    /// Dropped third strike: the batter was thrown out (K 2-3).
    case droppedThirdStrikeOut
    /// Dropped third strike: the batter reached first.
    case droppedThirdStrikeSafe
    /// Ground ball, fly ball, line drive, pop-up or bunt.
    case pickBattedBall(BattedBallType)
    /// Double play or triple play, on or off.
    case toggleMultiOut(MultiOutPlay)
    /// A fielder on the drawing. Tapping the last one again takes it back.
    case tapFielder(Position)
    /// The take-back arrow beside the notation.
    case untapLastFielder
    /// Where a hit landed.
    case tapHitSpot(FieldPoint, nearest: Position)
    /// Fielding or throwing error, on or off.
    case pickErrorType(ErrorType)
    /// The "Runners" button.
    case goToRunners
    /// A base button in a runner's row.
    case moveRunner(PlayerID, to: RunnerEnd)
    /// A runner's tag on the drawing: moves them to their next possible outcome.
    case cycleRunner(PlayerID)
    /// "Who made the out?" for a runner the scorer put out: a fielder, in the order they
    /// handled the ball. Tapping the last one again takes it back.
    case tapOutFielder(PlayerID, Position)
    /// "On the throw" (or "On the hit"/"On the play") versus "On an error", for a runner who
    /// went further than the play carried them.
    case answerExtraBase(PlayerID, onError: Bool)
    /// Whose error let that runner take the extra base.
    case chargeExtraBaseError(PlayerID, fielder: Position)
    /// The runs batted in stepper: +1 or -1.
    case changeRBI(by: Int)
    /// The Back button.
    case back
    /// The Save button.
    case save
    /// The Cancel button.
    case cancel
}

/// How a runner got further than the play carried them.
enum ExtraBaseAnswer: Equatable, Sendable {
    /// On the throw (for the batter) or on the play (for a runner already on base).
    case onThePlay
    /// On an error, by this fielder once the scorer has said whose.
    case onError(Position?)
}

/// The state of the in-play sequence while it is open.
@MainActor
@Observable
final class PlayEntryModel {
    // MARK: What the sequence was handed

    let situation: Situation
    let setup: GameSetup
    let start: PlayEntryStart
    let rules: PlayEntryRules
    let onFinish: (PlayEntryOutcome) -> Void

    // MARK: What is on screen

    /// The steps the scorer has walked through; the last one is showing. Back removes it.
    private(set) var steps: [PlayEntryStep]
    /// The play as the scorer has it so far, every runner included. This is what is saved.
    private(set) var draft: PlayDraft
    /// True while the kind of batted ball is the rules engine's guess, shown as a dashed chip.
    /// The scorer's own pick replaces it.
    private(set) var battedBallIsGuess = true
    /// True once "More" has been tapped on step one.
    private(set) var showsMore = false
    /// On a reached-on-error: the fielder who made the error.
    private(set) var errorFielder: Position?
    /// On a reached-on-error: fielding or throwing, if the scorer says.
    private(set) var errorType: ErrorType?
    /// The rules engine's runner suggestion when the runner step opened, by runner. Its ends
    /// are the dots on each runner's row.
    private(set) var firstMoves: [PlayerID: RunnerMove] = [:]
    /// The rules engine's latest answer, in its order (lead runner first, batter last).
    private(set) var engineMoves: [RunnerMove] = []
    /// The runs batted in the rules engine suggests for the play as it stands.
    private(set) var suggestedRBI = 0
    /// On a game-ending hit, the hit the rules engine says to save instead of the scorer's pick.
    private(set) var creditedResult: BatterResult?
    /// Where the scorer has put runners themselves, overriding the suggestion.
    private(set) var scorerPicks: [PlayerID: RunnerEnd] = [:]
    /// For a runner the scorer put out: the fielders who made the out, in order.
    private(set) var outFielders: [PlayerID: [Position]] = [:]
    /// The scorer's answers to "How did they get there?".
    private(set) var extraBaseAnswers: [PlayerID: ExtraBaseAnswer] = [:]
    /// Taps so far, for the demos' tap counts.
    private(set) var taps = 0
    /// Set once the sequence has closed, so a second tap on Save cannot record twice.
    private(set) var outcome: PlayEntryOutcome?

    init(situation: Situation, setup: GameSetup, start: PlayEntryStart, rules: PlayEntryRules,
         onFinish: @escaping (PlayEntryOutcome) -> Void = { _ in }) {
        self.situation = situation
        self.setup = setup
        self.start = start
        self.rules = rules
        self.onFinish = onFinish
        self.steps = [start == .inPlay ? .result : .droppedThirdStrike]
        self.draft = PlayDraft(context: start == .inPlay ? .ballInPlay : .droppedThirdStrike)
    }

    // MARK: Reading the state

    /// The step showing now.
    var step: PlayEntryStep { steps.last ?? .result }

    /// What the rules engine says the play does so far: notation, outs, runs, inning over.
    var preview: PlayPreview { rules.preview(draft, situation) }

    /// The runs batted in to show: the scorer's number if they changed it, else the suggestion.
    var rbi: Int { draft.rbi ?? suggestedRBI }

    /// True for a single, double, triple or home run, for the words "On the hit".
    var isHit: Bool {
        switch draft.batterResult {
        case .single, .double, .triple, .homeRun: true
        default: false
        }
    }

    /// True when the batter is out on the play: a batter out, a sacrifice, or a dropped third
    /// strike thrown out. The batter's row then offers only Out.
    var batterIsOut: Bool {
        switch draft.batterResult {
        case .out, .sacrificeFly, .sacrificeBunt: true
        default: false
        }
    }

    /// Whether the runner step comes next, rather than saving straight away: there are
    /// runners to confirm, or the batter reached base on something other than a hit.
    var needsRunnerStep: Bool {
        if !situation.runners.isEmpty { return true }
        switch draft.batterResult {
        case .reachedOnError, .fieldersChoice, .catchersInterference, .reachedOnDroppedThirdStrike: return true
        default: return false
        }
    }

    /// Whether Save can be tapped on this step.
    var canSave: Bool {
        switch step {
        case .fielders: !draft.fielders.isEmpty
        case .hitLocation: true
        case .runners: runnerProblem == nil
        case .result, .droppedThirdStrike, .error: false
        }
    }

    /// Whether the Runners button can be tapped on this step.
    var canGoToRunners: Bool {
        switch step {
        case .fielders: !draft.fielders.isEmpty
        case .error: errorFielder != nil
        case .hitLocation: true
        case .result, .droppedThirdStrike, .runners: false
        }
    }

    /// What stops the runner step from saving, in one line for the screen, or nothing when it
    /// can save: a question still to answer, two runners on one base, or a runner who passed
    /// the runner ahead of them.
    var runnerProblem: String? {
        for move in draft.runners {
            let name = name(of: move.runner)
            if needsOutFielders(move.runner), (outFielders[move.runner] ?? []).isEmpty {
                return "Tap who put \(name) out"
            }
            if asksHow(move.runner), extraBaseAnswer(for: move.runner) == .onError(nil) {
                return "Tap whose error let \(name) move up"
            }
        }
        // Runners still on base, or who scored, in the order they started (lead runner first).
        let safe = draft.runners.filter { $0.to != .out }.sorted { $0.from > $1.from }
        for (i, ahead) in safe.enumerated() {
            for behind in safe.dropFirst(i + 1) {
                guard let aheadEnd = ahead.to.progress, let behindEnd = behind.to.progress else { continue }
                if aheadEnd == behindEnd, let base = ahead.to.base {
                    return "\(name(of: ahead.runner)) and \(name(of: behind.runner)) can’t both end on \(base.shortLabel)"
                }
                if behindEnd > aheadEnd {
                    return "\(name(of: behind.runner)) can’t pass \(name(of: ahead.runner))"
                }
            }
        }
        return nil
    }

    /// The team at bat, for colors.
    var battingLook: TeamLook { setup.ourSide == situation.battingSide ? .ours : .theirs }

    /// Our fielders' names under the fielder circles, when our team is in the field.
    var fielderNames: [Position: String] {
        guard setup.ourSide == situation.fieldingSide else { return [:] }
        var names: [Position: String] = [:]
        for assignment in situation[situation.fieldingSide].fielders {
            names[assignment.position] = name(of: assignment.player)
        }
        return names
    }

    /// What to call a player on screen: their last name, or "#22" for a number only.
    func name(of player: PlayerID?) -> String {
        guard let player else { return "Batter" }
        return setup.player(player)?.lastName ?? player.rawValue
    }

    /// The outcomes a runner can be given on the runner step: the base they started on (not for
    /// the batter), each base ahead of it, scored, and out. A batter who is out on the play
    /// (a batter out or a sacrifice) can only be out.
    func choices(for move: RunnerMove) -> [RunnerEnd] {
        if move.isBatter && batterIsOut { return [.out] }
        let bases = Base.occupiable.filter { move.isBatter ? true : $0 >= move.from }
        return bases.map { RunnerEnd.safe(at: $0) } + [.scored, .out]
    }

    /// Whether to ask "How did they get there?" for a runner: whenever the scorer has moved
    /// them, batter included, further than the rules engine first suggested, on any kind of play.
    func asksHow(_ runner: PlayerID) -> Bool {
        guard let pick = scorerPicks[runner], let suggested = firstMoves[runner]?.to,
              let pickedOrder = pick.progress, let suggestedOrder = suggested.progress else { return false }
        return pickedOrder > suggestedOrder
    }

    /// Whether to ask "Who made the out?" for a runner: the scorer put them out and the rules
    /// engine had not.
    func needsOutFielders(_ runner: PlayerID) -> Bool {
        scorerPicks[runner] == .out && firstMoves[runner]?.to != .out
    }

    /// The answer showing for a runner's "How did they get there?". A runner already on base
    /// starts at "on the play", so the common play costs no extra tap; the batter starts with no
    /// answer, which saves as "on the throw".
    func extraBaseAnswer(for runner: PlayerID) -> ExtraBaseAnswer? {
        if let answer = extraBaseAnswers[runner] { return answer }
        return isBatterMove(runner) ? nil : .onThePlay
    }

    /// True when this runner is the batter.
    func isBatterMove(_ runner: PlayerID) -> Bool {
        firstMoves[runner]?.isBatter ?? (runner == situation.batter)
    }

    // MARK: Taps

    /// Does what one tap asks, and counts it.
    func perform(_ action: PlayEntryAction) {
        guard outcome == nil else { return }
        taps += 1
        switch action {
        case .pickResult(let result): pickResult(result)
        case .showMore: showsMore = true
        case .droppedThirdStrikeOut:
            startOver(context: .droppedThirdStrike, result: .out)
            steps.append(.fielders)
        case .droppedThirdStrikeSafe:
            startOver(context: .droppedThirdStrike, result: .reachedOnDroppedThirdStrike)
            openRunnerStep()
        case .pickBattedBall(let kind):
            draft.battedBall = kind
            battedBallIsGuess = false
        case .toggleMultiOut(let kind):
            draft.multiOut = draft.multiOut == kind ? nil : kind
        case .tapFielder(let position): tapFielder(position)
        case .untapLastFielder:
            if !draft.fielders.isEmpty { draft.fielders.removeLast() }
            guessBattedBall()
        case .tapHitSpot(let spot, let nearest):
            draft.hitSpot = spot
            draft.hitLocation = nearest
        case .pickErrorType(let type):
            errorType = errorType == type ? nil : type
            draft.errors = composedErrors()
        case .goToRunners:
            if canGoToRunners { openRunnerStep() }
        case .moveRunner(let runner, let end): moveRunner(runner, to: end)
        case .cycleRunner(let runner):
            guard let move = draft.runners.first(where: { $0.runner == runner }) else { return }
            let options = choices(for: move)
            let next = options[((options.firstIndex(of: move.to) ?? -1) + 1) % options.count]
            moveRunner(runner, to: next)
        case .tapOutFielder(let runner, let fielder):
            var fielders = outFielders[runner] ?? []
            if fielders.last == fielder { fielders.removeLast() } else { fielders.append(fielder) }
            outFielders[runner] = fielders
            askEngineAboutRunners()
        case .answerExtraBase(let runner, let onError):
            extraBaseAnswers[runner] = onError ? .onError(nil) : .onThePlay
            askEngineAboutRunners()
        case .chargeExtraBaseError(let runner, let fielder):
            extraBaseAnswers[runner] = .onError(fielder)
            askEngineAboutRunners()
        case .changeRBI(let change):
            draft.rbi = max(0, rbi + change)
        case .back: goBack()
        case .save: save()
        case .cancel: finish(.cancelled)
        }
    }

    /// Step one: the scorer said what happened to the batter. Anything picked before is dropped.
    private func pickResult(_ result: BatterResult) {
        startOver(context: .ballInPlay, result: result)
        switch result {
        case .out, .fieldersChoice:
            steps.append(.fielders)
        case .single, .double, .triple, .homeRun:
            steps.append(.hitLocation)
        case .reachedOnError:
            steps.append(.error)
        case .sacrificeFly, .sacrificeBunt:
            // The rules engine says what kind of ball a sacrifice is (a fly ball, a bunt).
            draft.battedBall = rules.suggestBattedBall(draft)
            battedBallIsGuess = false
            steps.append(.fielders)
        case .catchersInterference, .reachedOnDroppedThirdStrike:
            openRunnerStep()
        }
    }

    /// Clears everything picked after step one, for a fresh pick of what happened to the batter.
    private func startOver(context: PlayDraft.Context, result: BatterResult?) {
        draft = PlayDraft(context: context, batterResult: result)
        battedBallIsGuess = true
        showsMore = false
        errorFielder = nil
        errorType = nil
        clearRunnerStep()
    }

    /// A fielder tapped on the drawing. On the error step it picks (or unpicks) who made the
    /// error; on a hit it says where the ball went; otherwise it adds to the fielders in order,
    /// and tapping the last one again takes it back.
    private func tapFielder(_ position: Position) {
        switch step {
        case .error:
            errorFielder = errorFielder == position ? nil : position
            draft.fielders = errorFielder.map { [$0] } ?? []
            draft.errors = composedErrors()
        case .hitLocation:
            draft.hitLocation = position
            draft.hitSpot = FieldDrawing.spot(for: position)
        default:
            if draft.fielders.last == position {
                draft.fielders.removeLast()
            } else {
                draft.fielders.append(position)
            }
            guessBattedBall()
        }
    }

    /// Keeps the rules engine's guess at the kind of batted ball up to date as fielders are
    /// tapped, on a batter out, until the scorer picks a kind themselves. A guess the scorer
    /// never changes is saved with the play.
    private func guessBattedBall() {
        guard battedBallIsGuess, draft.batterResult == .out, draft.context == .ballInPlay else { return }
        var asked = draft
        asked.battedBall = nil
        draft.battedBall = rules.suggestBattedBall(asked)
    }

    // MARK: The runner step

    /// Opens the runner step with every runner where the rules engine suggests.
    private func openRunnerStep() {
        clearRunnerStep()
        draft.errors = composedErrors()
        let suggestion = rules.suggestRunners(draft, situation)
        engineMoves = suggestion.runners
        suggestedRBI = suggestion.rbi
        creditedResult = suggestion.batterResult
        firstMoves = Dictionary(suggestion.runners.map { ($0.runner, $0) }, uniquingKeysWith: { first, _ in first })
        draft.runners = suggestion.runners
        steps.append(.runners)
    }

    /// Forgets everything the runner step knew, for going back or starting over.
    private func clearRunnerStep() {
        draft.runners = []
        draft.rbi = nil
        engineMoves = []
        firstMoves = [:]
        suggestedRBI = 0
        creditedResult = nil
        scorerPicks = [:]
        outFielders = [:]
        extraBaseAnswers = [:]
    }

    /// The scorer put a runner somewhere new. Any answer about how they got there, or who put
    /// them out, starts over, and so do the runs batted in.
    private func moveRunner(_ runner: PlayerID, to end: RunnerEnd) {
        scorerPicks[runner] = end
        extraBaseAnswers[runner] = nil
        outFielders[runner] = nil
        draft.rbi = nil
        askEngineAboutRunners()
    }

    /// Asks the rules engine again. Only the runners the scorer placed go in the question, so
    /// the engine is free to move everyone else along; its answer is shown with the scorer's
    /// placements kept exactly as the scorer made them.
    private func askEngineAboutRunners() {
        draft.errors = composedErrors()
        var question = draft
        question.runners = engineMoves.filter { scorerPicks[$0.runner] != nil }.map(placedMove)
        let suggestion = rules.suggestRunners(question, situation)
        if !suggestion.runners.isEmpty { engineMoves = suggestion.runners }
        suggestedRBI = suggestion.rbi
        creditedResult = suggestion.batterResult
        draft.runners = engineMoves.map { scorerPicks[$0.runner] == nil ? $0 : placedMove($0) }
    }

    /// A runner the scorer placed: the rules engine's own move for them with only the end
    /// changed, so its other details (such as a batter who reached on an error) are kept. A
    /// runner taken off Out loses who put them out; a runner the scorer put out gets the
    /// fielders the scorer tapped; a runner who took an extra base on an error is marked so.
    private func placedMove(_ move: RunnerMove) -> RunnerMove {
        guard let pick = scorerPicks[move.runner] else { return move }
        var placed = move
        if placed.to != pick {
            if placed.to == .out {
                placed.outBy = []
                placed.outAt = nil
            }
            placed.to = pick
        }
        if needsOutFielders(move.runner) {
            placed.outBy = outFielders[move.runner] ?? []
        }
        if asksHow(move.runner) {
            let first = firstMoves[move.runner]?.advancedOnError ?? false
            placed.advancedOnError = extraBaseErrorFielder(move.runner) != nil || first
        }
        return placed
    }

    /// The fielder charged for a runner's extra base, once the scorer has said whose error it was.
    private func extraBaseErrorFielder(_ runner: PlayerID) -> Position? {
        if case .onError(let fielder) = extraBaseAnswer(for: runner) { return fielder }
        return nil
    }

    /// Every error on the play, each fielder listed once: the error the batter reached on, then
    /// any error that let a runner take an extra base.
    private func composedErrors() -> [ErrorCharge] {
        var errors: [ErrorCharge] = []
        if let errorFielder {
            errors.append(ErrorCharge(fielder: errorFielder, type: errorType))
        }
        for move in engineMoves where asksHow(move.runner) {
            if let fielder = extraBaseErrorFielder(move.runner), !errors.contains(where: { $0.fielder == fielder }) {
                errors.append(ErrorCharge(fielder: fielder))
            }
        }
        return errors
    }

    // MARK: Back, save and cancel

    /// Back one step. On the first step, Back closes the sequence without recording anything.
    private func goBack() {
        guard steps.count > 1 else { return finish(.cancelled) }
        let leaving = steps.removeLast()
        if leaving == .runners {
            clearRunnerStep()
            draft.errors = composedErrors()
        }
        if steps.last == .result { showsMore = false }
    }

    /// Saves the play. When the runner step was skipped (nobody on base), the rules engine's
    /// suggestion fills in where the batter went.
    private func save() {
        guard canSave else { return }
        var finished = draft
        finished.errors = composedErrors()
        var rbi = suggestedRBI
        var credited = creditedResult
        if step != .runners {
            let suggestion = rules.suggestRunners(finished, situation)
            finished.runners = suggestion.runners
            rbi = suggestion.rbi
            credited = suggestion.batterResult
        }
        // On a game-ending hit the batter is credited only with the bases the winning run needed.
        if let credited { finished.batterResult = credited }
        guard let play = finished.finishedPlay(suggestedRBI: rbi) else { return }
        if finished.context == .droppedThirdStrike {
            finish(.droppedThirdStrike(play))
        } else {
            finish(.ballInPlay(GameEvent(kind: .ballInPlay(play))))
        }
    }

    /// Closes the sequence, once.
    private func finish(_ result: PlayEntryOutcome) {
        guard outcome == nil else { return }
        outcome = result
        onFinish(result)
    }
}

extension RunnerEnd {
    /// How far round the bases this end is, for telling whether a runner went further than
    /// suggested: first 1, second 2, third 3, scored 4. Nothing for out.
    var progress: Int? {
        switch self {
        case .first: 1
        case .second: 2
        case .third: 3
        case .scored: 4
        case .out: nil
        }
    }

    /// The word on a base button: "1st", "Home", "Out".
    var buttonLabel: String {
        switch self {
        case .first: "1st"
        case .second: "2nd"
        case .third: "3rd"
        case .scored: "Home"
        case .out: "Out"
        }
    }

    /// The same, in a sentence: "to 2nd", "home".
    var sentenceLabel: String {
        self == .scored ? "home" : buttonLabel
    }
}

extension Base {
    /// The base as people say it: "1st", "2nd", "3rd", "home".
    var shortLabel: String {
        switch self {
        case .home: "home"
        case .first: "1st"
        case .second: "2nd"
        case .third: "3rd"
        }
    }
}
