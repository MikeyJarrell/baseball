// Made-up game moments for this module's previews and simulator demos, built from the
// sample situations in SampleData, and a small demo screen that opens each sheet and shows
// what it handed back. Nothing here is used during a real game.
//
// The demo screen applies one result itself, crudely, so the add-a-hitter demo can add a tenth
// hitter and then an eleventh: it appends the new hitter to the batting order. Everything else
// is only written to the log; the real app sends results to the rules engine.

import SwiftUI
import Model
import SampleData
import DesignSystem

/// Game moments for previews and demos.
enum DemoMoments {
    /// Bottom of the 3rd: the Diamond Dogs bat nine today, and Sky Barros, ninth, is up.
    /// Jamie Cole and Robin Nash are on the bench, ready to be added as the tenth and eleventh.
    static let ninthBatting: GameChangeContext = {
        let sample = SampleSituations.ourHitterWithoutSong
        var setup = sample.setup
        setup.home.battingOrder.removeLast()   // Cole, tenth in the sample, starts on the bench here
        var situation = sample.situation
        situation.home.battingOrder.slots.removeLast()
        situation.home.nextBatterIndex = 8
        return GameChangeContext(setup: setup, situation: situation)
    }()

    /// The same moment after Cole was added tenth, for adding Nash eleventh.
    static let tenthAdded: GameChangeContext = {
        var context = ninthBatting
        context.situation.home.battingOrder.slots.append(BattingSlot(players: ["d10"]))
        return context
    }()

    /// Top of the 3rd, runner on first, one out, a 2-1 count on Diaz: Barros, ours, is pitching.
    static let midCount = context(SampleSituations.runnerOnFirstOneOut)

    /// The changeover to the top of the 4th: our team takes the field and the check is due.
    static let takingTheField = context(SampleSituations.ourPitcherWarmingUp)

    /// Two fielders swapped on the check: Webb from center to right, Lang from right to center.
    static let swappedFielders = DefenseSuggestion(team: .home, fielders: takingTheField.situation.home.fielders.map { f in
        switch f.position {
        case .centerField: FielderAssignment(position: .centerField, player: "d7")
        case .rightField: FielderAssignment(position: .rightField, player: "d3")
        default: f
        }
    })

    /// First base alternating by inning: Robin Nash plays first in even innings, Pat Quinn in odd ones.
    static let alternatingFirstBase = DefenseSuggestion(
        team: .home,
        fielders: [FielderAssignment(position: .firstBase, player: "d11")],
        reasons: [.firstBase: "alternating"]
    )

    /// The defense check in the top of the 2nd, with first base shared by turns: the rules
    /// engine suggests Robin Nash at first for the even inning.
    static let rotationCheck = context(SampleSituations.defenseCheckWithRotation)

    /// Bottom of the 1st: Pat Quinn, a designated non-runner, has just singled. Chris Tate,
    /// who made the out, is the league rule's runner.
    static let nonRunnerOnFirst = context(SampleSituations.designatedNonRunnerOnFirst)

    /// Bottom of the 7th, the time limit has passed and the Mudcats lead 5-4: the inning just
    /// ended, so the app asks whether the game is over.
    static let timeLimitQuestion: GameChangeContext = {
        var context = DemoMoments.context(SampleSituations.lastInningOnTime)
        context.situation.inning = 8
        context.situation.half = .top
        context.situation.outs = 0
        context.situation.count = .fresh
        context.situation.runners = []
        context.situation.isBetweenHalfInnings = true
        context.situation.gameOverQuestion = .timeLimit
        return context
    }()

    /// The end of the 7th with the Diamond Dogs ahead by 13: the mercy rule's question.
    static let mercyRuleQuestion: GameChangeContext = {
        var context = DemoMoments.context(SampleSituations.betweenHalfInnings)
        context.situation.inning = 8
        context.situation.half = .top
        context.situation.score = Score(away: 2, home: 15)
        context.situation.gameOverQuestion = .runRule
        return context
    }()

    /// Runners on second and third, nobody out, the Mudcats batting: for steals and wild pitches.
    static let twoRunners = context(SampleSituations.secondAndThirdNobodyOut)

    /// Bases loaded, two outs, full count, the Diamond Dogs batting.
    static let basesLoaded = context(SampleSituations.basesLoadedTwoOutsFullCount)

    /// Their hitter known only as number 2, at the Bombers.
    static let theirHitterByNumber = context(SampleSituations.theirHitterKnownByNumber)

    /// The Mudcats batting, ninth spot up: Gus Reyes holds it after Kyle Moss pinch-hit for
    /// Ray Collins, so Collins may re-enter (rule 9.9). Voss has just come in to pitch for us.
    static let reentry: GameChangeContext = {
        var context = DemoMoments.context(SampleSituations.newPitcherJustIn)
        context.situation.away.nextBatterIndex = 8
        return context
    }()

    /// The time limit moment's "now": ten minutes before the limit.
    static func now(for context: GameChangeContext) -> Date {
        (context.situation.timeLimitEndsAt ?? context.setup.scheduledStart).addingTimeInterval(-10 * 60)
    }

    /// A sample situation's setup and situation together.
    static func context(_ sample: SampleSituation) -> GameChangeContext {
        GameChangeContext(setup: sample.setup, situation: sample.situation)
    }

    /// The canned rules engine's runner suggestions, for the runner action sheet.
    static func suggest(in context: GameChangeContext) -> (RunnerMoveReason, [PlayerID]) -> [RunnerMove] {
        { reason, runners in SampleRulesEngine().suggestRunnerAction(reason, runners: runners, in: context.situation) }
    }
}

// MARK: - The demo screen

/// Every sheet in this module, by name, for the demo screen and its launch argument.
public enum GameChangesDemoSheet: String, CaseIterable, Identifiable, Sendable {
    case changesMenu, addTenthHitter, addEleventhHitter, pitchingChangeMidCount, pinchHitterReentry,
         pinchRunner, nonRunnerPrompt, defenseCheck, defenseCheckSwapped, defenseCheckAlternating, defenseCheckRotation,
         fielders, runnerSteal, runnerAfterStrikeout, runnerWildPitch, errorNobodyMoved, manualAdjustment, theirBatter,
         timeLimit, gameOverTimeLimit, gameOverMercyRule, gameMenu

    public var id: String { rawValue }

    /// The words on the demo screen's button.
    public var title: String {
        switch self {
        case .changesMenu: "Changes menu"
        case .addTenthHitter: "Add a tenth hitter while the ninth bats"
        case .addEleventhHitter: "Add an eleventh hitter"
        case .pitchingChangeMidCount: "Pitching change mid-count"
        case .pinchHitterReentry: "Pinch hitter, with re-entry"
        case .pinchRunner: "Pinch runner"
        case .nonRunnerPrompt: "Designated non-runner on first"
        case .defenseCheck: "Defense check"
        case .defenseCheckSwapped: "Defense check, two fielders swapped"
        case .defenseCheckAlternating: "Defense check, first base alternating"
        case .defenseCheckRotation: "Defense check, engine’s alternating first base"
        case .runnerAfterStrikeout: "Runner actions: right after a strikeout"
        case .fielders: "Fielders"
        case .runnerSteal: "Runner actions: steal"
        case .runnerWildPitch: "Runner actions: wild pitch"
        case .errorNobodyMoved: "Error, nobody moved"
        case .manualAdjustment: "Manual adjustment"
        case .theirBatter: "Their batter, known by number"
        case .timeLimit: "Time limit"
        case .gameOverTimeLimit: "Is the game over? (time limit)"
        case .gameOverMercyRule: "Is the game over? (mercy rule)"
        case .gameMenu: "Game menu"
        }
    }
}

/// A list of demos; each opens its sheet and writes what the sheet handed back at the top.
/// For simulator checks. `start` opens one sheet straight away.
public struct GameChangesDemo: View {
    @State private var open: GameChangesDemoSheet?
    @State private var log: [String] = []
    /// The add-a-hitter demo's batting order, which grows as hitters are added.
    @State private var addContext = DemoMoments.ninthBatting
    @State private var songSeconds: Double = 12

    public init(start: GameChangesDemoSheet? = nil) {
        _open = State(initialValue: start)
    }

    public var body: some View {
        NavigationStack {
            List {
                Section("Last result") {
                    Text(log.last ?? "Nothing yet")
                        .font(ScorebookFont.caption)
                        .foregroundStyle(ScorebookColor.textSecondary)
                }
                Section("Sheets") {
                    ForEach(GameChangesDemoSheet.allCases) { demo in
                        Button(demo.title) { open = demo }
                    }
                }
            }
            .navigationTitle("In-game changes")
        }
        .sheet(item: $open) { demo in
            sheet(for: demo)
        }
    }

    /// The sheet for one demo.
    @ViewBuilder private func sheet(for demo: GameChangesDemoSheet) -> some View {
        switch demo {
        case .changesMenu:
            ChangesMenuSheet(context: DemoMoments.midCount, onFinish: finish)
        case .addTenthHitter, .addEleventhHitter:
            AddHitterSheet(context: demo == .addTenthHitter ? addContext : DemoMoments.tenthAdded, onFinish: finish)
        case .pitchingChangeMidCount:
            PitchingChangeSheet(context: DemoMoments.midCount, onFinish: finish)
        case .pinchHitterReentry:
            PinchHitterSheet(context: DemoMoments.reentry, onFinish: finish)
        case .pinchRunner:
            PinchRunnerSheet(context: DemoMoments.basesLoaded, base: .second, onFinish: finish)
        case .nonRunnerPrompt:
            NonRunnerSheet(context: DemoMoments.nonRunnerOnFirst, onFinish: finish)
        case .defenseCheck:
            DefenseSheet(context: DemoMoments.takingTheField, onFinish: finish)
        case .defenseCheckSwapped:
            DefenseSheet(context: DemoMoments.takingTheField, suggestion: DemoMoments.swappedFielders, onFinish: finish)
        case .defenseCheckAlternating:
            DefenseSheet(context: DemoMoments.takingTheField, suggestion: DemoMoments.alternatingFirstBase, onFinish: finish)
        case .defenseCheckRotation:
            DefenseSheet(context: DemoMoments.rotationCheck, onFinish: finish)
        case .runnerAfterStrikeout:
            RunnerActionSheet(context: DemoMoments.midCount, runner: "m3", suggest: DemoMoments.suggest(in: DemoMoments.midCount),
                              followsStrikeout: true, onFinish: finish)
        case .fielders:
            DefenseSheet(context: DemoMoments.midCount, purpose: .changes, onFinish: finish)
        case .runnerSteal:
            RunnerActionSheet(context: DemoMoments.midCount, runner: "m3", suggest: DemoMoments.suggest(in: DemoMoments.midCount), onFinish: finish)
        case .runnerWildPitch:
            RunnerActionSheet(context: DemoMoments.twoRunners, suggest: DemoMoments.suggest(in: DemoMoments.twoRunners), onFinish: finish)
        case .errorNobodyMoved:
            ErrorSheet(context: DemoMoments.midCount, onFinish: finish)
        case .manualAdjustment:
            ManualAdjustmentSheet(context: DemoMoments.basesLoaded, onFinish: finish)
        case .theirBatter:
            BatterSheet(context: DemoMoments.theirHitterByNumber, onFinish: finish)
        case .timeLimit:
            TimeLimitSheet(context: DemoMoments.midCount, now: DemoMoments.now(for: DemoMoments.midCount), onFinish: finish)
        case .gameOverTimeLimit:
            GameOverSheet(context: DemoMoments.timeLimitQuestion, onFinish: finish)
        case .gameOverMercyRule:
            GameOverSheet(context: DemoMoments.mercyRuleQuestion, onFinish: finish)
        case .gameMenu:
            GameMenuSheet(context: DemoMoments.midCount, walkUpSongSeconds: $songSeconds,
                          now: DemoMoments.now(for: DemoMoments.midCount), onFinish: finish)
        }
    }

    /// Writes down what a sheet handed back and closes it. An added hitter is appended to the
    /// demo's batting order, so the next add shows the order one longer.
    private func finish(_ result: GameChangeResult) {
        if case .record(let entered) = result, case .addHitter(let add) = entered.event.kind, add.team == .home {
            addContext.situation.home.battingOrder.slots.append(BattingSlot(players: [add.player]))
            addContext.setup.home.roster += entered.newPlayers.map(\.player)
        }
        log.append(describe(result))
        open = nil
    }
}

/// A short description of a result, for the demo log: "Recorded: added hitter d10".
func describe(_ result: GameChangeResult) -> String {
    switch result {
    case .record(let entered):
        let extra = entered.newPlayers.isEmpty ? "" : " (with \(entered.newPlayers.count) new player)"
        return "Recorded: \(entered.event.kind.label)\(details(entered.event.kind))\(extra)"
    case .updatePlayer(let edit): return "Updated player: \(edit.player.displayName)"
    case .nothingToRecord: return "Nothing to record"
    case .cancel: return "Cancelled"
    }
}

/// The main details of an event, for the demo log, by player id and position number.
private func details(_ kind: EventKind) -> String {
    switch kind {
    case .substitution(let s):
        let batting = s.batting.map { "\($0.incoming) for \($0.replacing)" }
        let defense = s.defense.map { "\($0.position.number): \($0.player)" }
        let leaving = s.leavesField.map { "\($0) leaves the field" }
        return " (" + (batting + defense + leaving).joined(separator: ", ") + ")"
    case .addHitter(let a): return " \(a.player)"
    case .pitchingChange(let p): return " \(p.newPitcher)"
    case .runnerForNonRunner(let r): return " \(r.runner) for \(r.replacing)"
    case .runnerAction(let a):
        let moves = a.moves.map { "\($0.runner) \($0.from.rawValue)→\($0.to.rawValue)\($0.outBy.isEmpty ? "" : " " + $0.outBy.map(\.description).joined(separator: "-"))\($0.wasStealing ? " stealing" : "")" }
        let errors = a.errors.map { "E\($0.fielder.number)" }
        let dp = a.completesStrikeoutDoublePlay ? ["with the strikeout: DP"] : []
        return " (" + (moves + errors + dp).joined(separator: ", ") + ")"
    case .errorWithNoAdvance(let e): return " E\(e.fielder.number)"
    case .keepPlaying(let k): return " (\(k.reason.rawValue))"
    case .endOfGame(let e): return " (\(e.reason.rawValue))"
    default: return ""
    }
}
