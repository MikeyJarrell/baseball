// PregameScreens: game setup and lineups, in five steps.
//
// 1. The game: opponent, date, home or away, innings, the scheduled start and the time limit
//    as a clock time (`GameStep`).
// 2. Our lineup: the batting order, the nine fielders and the bench, as three separate lists,
//    with designated non-runners and positions shared by turns (`OurLineupStep`).
// 3. Their lineup: names and numbers, numbers only, or unknown (`TheirLineupStep`).
// 4. Starting pitchers for both teams, with throwing hands (`PitchersStep`).
// 5. Review and "Play ball" (`ReviewStep`).
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

/// The five pregame steps.
public enum PregameStep: Hashable, CaseIterable, Sendable {
    case game, ours, theirs, pitchers, review
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
        self.init(draft: PregameDraft(input: input), startingAt: .game, onFinish: onFinish)
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
            GameStep(draft: $draft, onCancel: { onFinish(.cancel) }, onNext: { path.append(.ours) })
                .navigationDestination(for: PregameStep.self) { step in
                    switch step {
                    case .game:
                        EmptyView()
                    case .ours:
                        OurLineupStep(draft: $draft, onNext: { path.append(.theirs) })
                    case .theirs:
                        TheirLineupStep(draft: $draft, onNext: { path.append(.pitchers) })
                    case .pitchers:
                        PitchersStep(draft: $draft, onNext: { path.append(.review) })
                    case .review:
                        ReviewStep(draft: draft, onPlayBall: {
                            if let setup = draft.setup() { onFinish(.playBall(setup)) }
                        })
                    }
                }
        }
        .tint(ScorebookColor.inPlay)
    }
}
