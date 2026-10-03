// Scripted demos of the in-play sequence: the plays the brief asks for, each with where it
// starts, the taps that enter it, and what the finished play should read. Used by the
// previews and by `PlayEntryDemoGallery`, a screen for trying them in the simulator.
//
// Each script is the scorer's taps inside the sequence. The "In play" (or "Dropped 3rd
// strike") tap on the batting screen that opens it is one more.

import SwiftUI
import Model
import SampleData
import DesignSystem

/// One scripted play.
struct PlayEntryDemo: Identifiable, Sendable {
    /// A short id for launch arguments: "6-3", "dp".
    var id: String
    /// What the play is, in words.
    var title: String
    /// Where the game stands as the ball is put in play.
    var sample: SampleSituation
    /// Which button opened the sequence.
    var start: PlayEntryStart = .inPlay
    /// The scorer's taps, in order.
    var taps: [PlayEntryAction]
    /// What the finished play should read: its notation, outs, runs and runs batted in.
    var expected: (notation: String, outs: Int, runs: Int, rbi: Int)

    /// A fresh sequence for this demo with the first `count` taps already made (all of them
    /// when `count` is missing), using the demo rules engine.
    @MainActor
    func model(afterTaps count: Int? = nil, onFinish: @escaping (PlayEntryOutcome) -> Void = { _ in }) -> PlayEntryModel {
        let model = PlayEntryModel(situation: sample.situation, setup: sample.setup, start: start,
                                   rules: .demo, onFinish: onFinish)
        for tap in taps.prefix(count ?? taps.count) { model.perform(tap) }
        return model
    }

    /// Runs the whole script and says whether the play came out as expected.
    @MainActor
    func check() -> DemoCheck {
        var outcome: PlayEntryOutcome?
        // Everything but the final Save, so the preview still shows the play...
        let model = model(afterTaps: taps.count - 1) { outcome = $0 }
        let preview = model.preview
        // ...then Save.
        if let last = taps.last { model.perform(last) }
        let play = outcome?.play
        let got = (notation: preview.notation, outs: preview.outsOnPlay, runs: preview.runsOnPlay, rbi: play?.rbi ?? -1)
        let passed = play != nil && got.notation == expected.notation && got.outs == expected.outs
            && got.runs == expected.runs && got.rbi == expected.rbi
        return DemoCheck(passed: passed, taps: model.taps,
                         summary: "\(got.notation) · \(PlayWords.outs(got.outs)), \(PlayWords.runs(got.runs)), \(got.rbi) RBI",
                         play: play)
    }
}

extension PlayEntryOutcome {
    /// The play inside the outcome, whichever kind it is. Nothing for a cancel.
    var play: Play? {
        switch self {
        case .ballInPlay(let event):
            if case .ballInPlay(let play) = event.kind { return play }
            return nil
        case .droppedThirdStrike(let play): return play
        case .cancelled: return nil
        }
    }
}

/// The result of running one demo's script.
struct DemoCheck {
    var passed: Bool
    /// Taps inside the sequence, Save included.
    var taps: Int
    /// What the play read: "6-3 · 1 out, 0 runs, 0 RBI".
    var summary: String
    var play: Play?
}

/// The demo plays.
enum PlayEntryDemos {
    // The batter is Tommy Diaz of the Mudcats (top of the 3rd, our team in the field, so our
    // fielders' names show), or Pat Quinn and Jordan Webb of the Diamond Dogs (bottom of the 4th).
    // Runners: Marcus Hale, Danny Ruiz and Luis Ortiz of the Mudcats; Webb and Chris Tate of ours.

    /// The Mudcats batting with these runners and outs.
    static func mudcats(_ title: String, outs: Int, runners: [PlayerID: Base] = [:]) -> SampleSituation {
        var sample = SampleSituations.runnerOnFirstOneOut
        sample.title = title
        sample.situation.outs = outs
        sample.situation.count = Count(balls: 1, strikes: 1)
        sample.situation.runners = runners.map { BaseRunner(runner: $0.key, base: $0.value, responsiblePitcher: "d9") }
        return sample
    }

    /// The Diamond Dogs batting (Quinn up unless `batterSpot` says otherwise) with these runners and outs.
    static func diamondDogs(_ title: String, outs: Int, runners: [PlayerID: Base] = [:], batterSpot: Int = 3,
                            count: Count = Count(balls: 2, strikes: 1)) -> SampleSituation {
        var sample = SampleSituations.basesLoadedTwoOutsFullCount
        sample.title = title
        sample.situation.outs = outs
        sample.situation.count = count
        sample.situation.home.nextBatterIndex = batterSpot
        sample.situation.runners = runners.map { BaseRunner(runner: $0.key, base: $0.value, responsiblePitcher: "m9") }
        return sample
    }

    /// The batter in the Mudcats demos (Diaz) and in most Diamond Dogs demos (Quinn).
    static let mudcatsBatter: PlayerID = "m4"
    static let ourBatter: PlayerID = "d4"

    /// Where a ball to shallow left field lands.
    static let shallowLeft = FieldPoint(x: 0.24, y: 0.66)

    static let groundOut = PlayEntryDemo(
        id: "6-3", title: "6-3 with nobody on",
        sample: mudcats("Nobody on, nobody out", outs: 0),
        taps: [.pickResult(.out), .tapFielder(.shortstop), .tapFielder(.firstBase), .save],
        expected: ("6-3", 1, 0, 0))

    static let flyOut = PlayEntryDemo(
        id: "f8", title: "F8 with a runner on second",
        sample: mudcats("Runner on second, one out", outs: 1, runners: ["m2": .second]),
        taps: [.pickResult(.out), .tapFielder(.centerField), .goToRunners, .save],
        expected: ("F8", 1, 0, 0))

    static let singleRunnerScores = PlayEntryDemo(
        id: "1b", title: "Single, runner from second sent home",
        sample: diamondDogs("Runners on first and second, one out", outs: 1, runners: ["d3": .first, "d2": .second]),
        taps: [.pickResult(.single), .tapHitSpot(shallowLeft, nearest: .leftField), .goToRunners,
               .moveRunner("d2", to: .scored), .save],
        expected: ("1B 7", 0, 1, 1))

    static let doublePlay = PlayEntryDemo(
        id: "dp", title: "5-4-3 double play, runner on first",
        sample: mudcats("Runner on first, nobody out", outs: 0, runners: ["m3": .first]),
        taps: [.pickResult(.out), .toggleMultiOut(.doublePlay), .tapFielder(.thirdBase), .tapFielder(.secondBase),
               .tapFielder(.firstBase), .goToRunners, .save],
        expected: ("5-4-3 DP", 2, 0, 0))

    static let errorBatterToSecond = PlayEntryDemo(
        id: "e6", title: "Error by the shortstop, batter to second",
        sample: mudcats("Nobody on, nobody out", outs: 0),
        taps: [.pickResult(.reachedOnError), .tapFielder(.shortstop), .goToRunners, .moveRunner(mudcatsBatter, to: .second), .save],
        expected: ("E6", 0, 0, 0))

    static let fieldersChoice = PlayEntryDemo(
        id: "fc", title: "Fielder’s choice, lead runner out at second",
        sample: mudcats("Runner on first, one out", outs: 1, runners: ["m3": .first]),
        taps: [.pickResult(.fieldersChoice), .tapFielder(.shortstop), .tapFielder(.secondBase), .goToRunners, .save],
        expected: ("FC 6-4", 1, 0, 0))

    static let sacrificeFly = PlayEntryDemo(
        id: "sf", title: "Sacrifice fly",
        sample: mudcats("Runners on second and third, one out", outs: 1, runners: ["m1": .third, "m2": .second]),
        taps: [.showMore, .pickResult(.sacrificeFly), .tapFielder(.centerField), .goToRunners, .save],
        expected: ("SF 8", 1, 1, 1))

    static let singlePlusError = PlayEntryDemo(
        id: "1b-e7", title: "Single, batter to second on the left fielder’s error",
        sample: diamondDogs("Nobody on, nobody out", outs: 0),
        taps: [.pickResult(.single), .tapHitSpot(shallowLeft, nearest: .leftField), .goToRunners,
               .moveRunner(ourBatter, to: .second), .answerExtraBase(ourBatter, onError: true),
               .chargeExtraBaseError(ourBatter, fielder: .leftField), .save],
        expected: ("1B 7, E7", 0, 0, 0))

    static let droppedThirdStrikeSafe = PlayEntryDemo(
        id: "k3-safe", title: "Dropped third strike, batter safe",
        sample: diamondDogs("Webb up, 1-2, one out", outs: 1, batterSpot: 2, count: Count(balls: 1, strikes: 2)),
        start: .droppedThirdStrike,
        taps: [.droppedThirdStrikeSafe, .save],
        expected: ("K", 0, 0, 0))

    static let droppedThirdStrikeOut = PlayEntryDemo(
        id: "k3-out", title: "Dropped third strike, thrown out (K 2-3)",
        sample: diamondDogs("Webb up, 1-2, one out", outs: 1, batterSpot: 2, count: Count(balls: 1, strikes: 2)),
        start: .droppedThirdStrike,
        taps: [.droppedThirdStrikeOut, .tapFielder(.catcher), .tapFielder(.firstBase), .save],
        expected: ("K 2-3", 1, 0, 0))

    /// Every demo, in the order the brief lists them, then the extras.
    static let all: [PlayEntryDemo] = [
        groundOut, flyOut, singleRunnerScores, doublePlay, errorBatterToSecond, fieldersChoice, sacrificeFly,
        singlePlusError, droppedThirdStrikeSafe, droppedThirdStrikeOut,
    ]
}

// MARK: - A screen for trying the demos in the simulator

/// A list of the demo plays, for trying the in-play sequence in the simulator before the app
/// is wired. Each row runs its script once to check the play comes out as expected, and shows
/// the taps it takes; tapping a row opens the sequence to enter the play by hand. The finished
/// play shows below the list as JSON. Not part of the app itself.
public struct PlayEntryDemoGallery: View {
    @State private var open: OpenDemo?
    @State private var lastResult = "Nothing entered yet."
    /// The text size the gallery was given, passed on to the sequence, which opens full screen.
    @Environment(\.dynamicTypeSize) private var typeSize
    private let autoOpen: OpenDemo?

    /// - Parameters:
    ///   - demoID: open this demo straight away ("6-3", "f8", "1b", "dp", "e6", "fc", "sf",
    ///     "1b-e7", "k3-safe", "k3-out"), for screenshots.
    ///   - taps: with `demoID`, make this many of its scripted taps first.
    public init(open demoID: String? = nil, afterTaps taps: Int? = nil) {
        autoOpen = demoID.flatMap { id in PlayEntryDemos.all.first { $0.id == id } }
            .map { OpenDemo(demo: $0, taps: taps ?? 0) }
    }

    public var body: some View {
        NavigationStack {
            List {
                Section("Demo plays (taps after “In play”)") {
                    ForEach(PlayEntryDemos.all) { demo in
                        let check = demo.check()
                        Button { open = OpenDemo(demo: demo, taps: 0) } label: {
                            HStack(spacing: Spacing.medium) {
                                Image(systemName: check.passed ? "checkmark.circle.fill" : "xmark.octagon.fill")
                                    .foregroundStyle(check.passed ? ScorebookColor.success : ScorebookColor.out)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(demo.title).font(ScorebookFont.headline)
                                    Text("\(check.summary) · \(check.taps) taps")
                                        .font(ScorebookFont.caption)
                                        .foregroundStyle(ScorebookColor.textSecondary)
                                }
                            }
                        }
                        .foregroundStyle(ScorebookColor.textPrimary)
                    }
                }
                Section("Last play entered") {
                    Text(lastResult)
                        .font(ScorebookFont.caption.monospaced())
                        .textSelection(.enabled)
                }
            }
            .navigationTitle("In-play demos")
        }
        .fullScreenCover(item: $open) { opened in
            PlayEntryView(model: opened.demo.model(afterTaps: opened.taps) { outcome in
                lastResult = Self.describe(outcome)
                open = nil
            })
            .environment(\.dynamicTypeSize, typeSize)
        }
        .onAppear { if let autoOpen { open = autoOpen } }
    }

    /// The outcome as readable JSON.
    private static func describe(_ outcome: PlayEntryOutcome) -> String {
        let play: Play
        let kind: String
        switch outcome {
        case .cancelled: return "Cancelled: nothing recorded."
        case .droppedThirdStrike(let p): play = p; kind = "Dropped third strike"
        case .ballInPlay(let event):
            guard case .ballInPlay(let p) = event.kind else { return "Unexpected event" }
            play = p; kind = "Ball in play"
        }
        let json = (try? ScorebookJSON.encode(play)).flatMap { String(data: $0, encoding: .utf8) } ?? "?"
        return "\(kind):\n\(json)"
    }
}

/// A demo opened in the gallery, with how many of its taps were already made.
private struct OpenDemo: Identifiable {
    var demo: PlayEntryDemo
    var taps: Int
    var id: String { "\(demo.id)-\(taps)" }
}
