// PregameScreens: game setup and lineups, in ten steps, one question on each screen.
//
// 1. The opponent (`OpponentStep`).
// 2. Home or away (`HomeOrAwayStep`).
// 3. The date and the scheduled start, on the iOS time wheel (`WhenStep`).
// 4. The game's length: innings, championship rules and the time limit (`LengthStep`).
// 5. Our batting order: who bats and in what order, designated non-runners, the bench
//    (`BattingOrderStep`).
// 6. Our fielders, on the field drawing, with positions shared by turns (`FieldingStep`).
// 7. Their lineup: names and numbers, or numbers only (`TheirLineupStep`).
// 8. Our starting pitcher (`OurPitcherStep`).
// 9. Their starting pitcher, with throwing hand (`TheirPitcherStep`).
// 10. Review and "Play ball" (`ReviewStep`).
//
// How these screens talk to the rest of the app: `PregameFlow` is handed a `PregameInput`
// (our team, the saved opponents, recent games, who pitched lately, today) and hands back one
// `PregameResult` through `onFinish`: the finished `GameSetup`, or a cancel. Everything the
// scorer picks lives in one `PregameDraft`, whose plain functions (in PregameBuilder.swift,
// OurLineup.swift and TheirLineup.swift) are tested without a screen. Nothing here enforces a
// league rule: a third designated non-runner asks first and then is allowed, an empty position
// is a note on the review step, and nothing blocks "Play ball" except a batting order with
// nobody in it.
//
// Screens here may use Model, SampleData and DesignSystem, and nothing else.

import SwiftUI
import Model
import SampleData
import DesignSystem

/// The ten pregame steps, in order. `when` is the date and start; `length` is innings and the
/// time limit; `ours` is our batting order; `fielding` is where we field.
public enum PregameStep: Hashable, CaseIterable, Sendable {
    case opponent, homeOrAway, when, length, ours, fielding, theirs, ourPitcher, theirPitcher, review

    /// Where this step falls in the sequence, counting from 1, for the dots under the title.
    var number: Int { (Self.allCases.firstIndex(of: self) ?? 0) + 1 }
}

/// The pregame sequence, from picking the opponent to "Play ball".
public struct PregameFlow: View {
    /// Called once, with the finished setup or a cancel.
    var onFinish: (PregameResult) -> Void

    @State private var draft: PregameDraft
    @State private var path: [PregameStep]

    /// - Parameters:
    ///   - input: Our team, the saved opponents, recent games and who pitched lately.
    ///   - onFinish: Hands back the game setup when the scorer taps "Play ball", or a cancel.
    public init(input: PregameInput, onFinish: @escaping (PregameResult) -> Void) {
        self.init(draft: PregameDraft(input: input), startingAt: .opponent, onFinish: onFinish)
    }

    /// Opens partway through, for previews: the steps before `step` are already behind it.
    init(draft: PregameDraft, startingAt step: PregameStep, onFinish: @escaping (PregameResult) -> Void = { _ in }) {
        self.onFinish = onFinish
        _draft = State(initialValue: draft)
        let steps = PregameStep.allCases
        let index = steps.firstIndex(of: step) ?? 0
        // Every step after the first, up to and including the one to open at.
        _path = State(initialValue: index == 0 ? [] : Array(steps[1...index]))
    }

    public var body: some View {
        NavigationStack(path: $path) {
            OpponentStep(draft: $draft, onCancel: { onFinish(.cancel) }, onNext: { path.append(.homeOrAway) })
                .navigationDestination(for: PregameStep.self) { step in
                    switch step {
                    case .opponent:
                        EmptyView()
                    case .homeOrAway:
                        HomeOrAwayStep(draft: $draft, onNext: { path.append(.when) })
                    case .when:
                        WhenStep(draft: $draft, onNext: { path.append(.length) })
                    case .length:
                        LengthStep(draft: $draft, onNext: { path.append(.ours) })
                    case .ours:
                        BattingOrderStep(draft: $draft, onNext: { path.append(.fielding) })
                    case .fielding:
                        FieldingStep(draft: $draft, onNext: { path.append(.theirs) })
                    case .theirs:
                        TheirLineupStep(draft: $draft, onNext: { path.append(.ourPitcher) })
                    case .ourPitcher:
                        OurPitcherStep(draft: $draft, onNext: { path.append(.theirPitcher) })
                    case .theirPitcher:
                        TheirPitcherStep(draft: $draft, onNext: { path.append(.review) })
                    case .review:
                        // A binding, not a copy: a pushed screen keeps whatever it was first
                        // handed, so a plain copy could miss choices made on earlier steps.
                        ReviewStep(draft: $draft, onPlayBall: { setup in onFinish(.playBall(setup)) })
                    }
                }
        }
        .tint(ScorebookColor.inPlay)
    }
}
