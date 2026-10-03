// Previews for every sheet in this module, each in light mode, dark mode and at the largest
// accessibility text size, using the game moments in Demos.swift (built from SampleData).
// The demo screen at the bottom opens each sheet for real and shows what it hands back.

import SwiftUI
import Model
import SampleData
import DesignSystem

/// Previews drop whatever a sheet hands back.
@MainActor private func ignore(_ result: GameChangeResult) {}

#Preview("Changes menu") {
    ChangesMenuSheet(context: DemoMoments.midCount, onFinish: ignore)
}

#Preview("Changes menu, dark") {
    ChangesMenuSheet(context: DemoMoments.midCount, onFinish: ignore)
        .preferredColorScheme(.dark)
}

#Preview("Changes menu, largest text") {
    ChangesMenuSheet(context: DemoMoments.midCount, onFinish: ignore)
        .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Add a tenth hitter while the ninth bats") {
    AddHitterSheet(context: DemoMoments.ninthBatting, onFinish: ignore)
}

#Preview("Add a tenth hitter while the ninth bats, dark") {
    AddHitterSheet(context: DemoMoments.ninthBatting, onFinish: ignore)
        .preferredColorScheme(.dark)
}

#Preview("Add a tenth hitter while the ninth bats, largest text") {
    AddHitterSheet(context: DemoMoments.ninthBatting, onFinish: ignore)
        .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Add an eleventh hitter") {
    AddHitterSheet(context: DemoMoments.tenthAdded, onFinish: ignore)
}

#Preview("Add an eleventh hitter, dark") {
    AddHitterSheet(context: DemoMoments.tenthAdded, onFinish: ignore)
        .preferredColorScheme(.dark)
}

#Preview("Add an eleventh hitter, largest text") {
    AddHitterSheet(context: DemoMoments.tenthAdded, onFinish: ignore)
        .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Pitching change mid-count") {
    PitchingChangeSheet(context: DemoMoments.midCount, onFinish: ignore)
}

#Preview("Pitching change mid-count, dark") {
    PitchingChangeSheet(context: DemoMoments.midCount, onFinish: ignore)
        .preferredColorScheme(.dark)
}

#Preview("Pitching change mid-count, largest text") {
    PitchingChangeSheet(context: DemoMoments.midCount, onFinish: ignore)
        .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Pitching change, their team") {
    PitchingChangeSheet(context: DemoMoments.basesLoaded, onFinish: ignore)
}

#Preview("Pitching change, their team, dark") {
    PitchingChangeSheet(context: DemoMoments.basesLoaded, onFinish: ignore)
        .preferredColorScheme(.dark)
}

#Preview("Pitching change, their team, largest text") {
    PitchingChangeSheet(context: DemoMoments.basesLoaded, onFinish: ignore)
        .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Pinch hitter with re-entry") {
    PinchHitterSheet(context: DemoMoments.reentry, onFinish: ignore)
}

#Preview("Pinch hitter with re-entry, dark") {
    PinchHitterSheet(context: DemoMoments.reentry, onFinish: ignore)
        .preferredColorScheme(.dark)
}

#Preview("Pinch hitter with re-entry, largest text") {
    PinchHitterSheet(context: DemoMoments.reentry, onFinish: ignore)
        .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Pinch hitter, ours") {
    PinchHitterSheet(context: DemoMoments.ninthBatting, onFinish: ignore)
}

#Preview("Pinch hitter, ours, dark") {
    PinchHitterSheet(context: DemoMoments.ninthBatting, onFinish: ignore)
        .preferredColorScheme(.dark)
}

#Preview("Pinch hitter, ours, largest text") {
    PinchHitterSheet(context: DemoMoments.ninthBatting, onFinish: ignore)
        .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Pinch runner") {
    PinchRunnerSheet(context: DemoMoments.basesLoaded, base: .second, onFinish: ignore)
}

#Preview("Pinch runner, dark") {
    PinchRunnerSheet(context: DemoMoments.basesLoaded, base: .second, onFinish: ignore)
        .preferredColorScheme(.dark)
}

#Preview("Pinch runner, largest text") {
    PinchRunnerSheet(context: DemoMoments.basesLoaded, base: .second, onFinish: ignore)
        .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Non-runner on first") {
    NonRunnerSheet(context: DemoMoments.nonRunnerOnFirst, onFinish: ignore)
}

#Preview("Non-runner on first, dark") {
    NonRunnerSheet(context: DemoMoments.nonRunnerOnFirst, onFinish: ignore)
        .preferredColorScheme(.dark)
}

#Preview("Non-runner on first, largest text") {
    NonRunnerSheet(context: DemoMoments.nonRunnerOnFirst, onFinish: ignore)
        .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Defense check") {
    DefenseSheet(context: DemoMoments.takingTheField, onFinish: ignore)
}

#Preview("Defense check, dark") {
    DefenseSheet(context: DemoMoments.takingTheField, onFinish: ignore)
        .preferredColorScheme(.dark)
}

#Preview("Defense check, largest text") {
    DefenseSheet(context: DemoMoments.takingTheField, onFinish: ignore)
        .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Defense check, two fielders swapped") {
    DefenseSheet(context: DemoMoments.takingTheField, suggestion: DemoMoments.swappedFielders, onFinish: ignore)
}

#Preview("Defense check, two fielders swapped, dark") {
    DefenseSheet(context: DemoMoments.takingTheField, suggestion: DemoMoments.swappedFielders, onFinish: ignore)
        .preferredColorScheme(.dark)
}

#Preview("Defense check, two fielders swapped, largest text") {
    DefenseSheet(context: DemoMoments.takingTheField, suggestion: DemoMoments.swappedFielders, onFinish: ignore)
        .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Defense check, first base alternating") {
    DefenseSheet(context: DemoMoments.takingTheField, suggestion: DemoMoments.alternatingFirstBase, onFinish: ignore)
}

#Preview("Defense check, first base alternating, dark") {
    DefenseSheet(context: DemoMoments.takingTheField, suggestion: DemoMoments.alternatingFirstBase, onFinish: ignore)
        .preferredColorScheme(.dark)
}

#Preview("Defense check, first base alternating, largest text") {
    DefenseSheet(context: DemoMoments.takingTheField, suggestion: DemoMoments.alternatingFirstBase, onFinish: ignore)
        .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Fielders") {
    DefenseSheet(context: DemoMoments.midCount, purpose: .changes, onFinish: ignore)
}

#Preview("Fielders, dark") {
    DefenseSheet(context: DemoMoments.midCount, purpose: .changes, onFinish: ignore)
        .preferredColorScheme(.dark)
}

#Preview("Fielders, largest text") {
    DefenseSheet(context: DemoMoments.midCount, purpose: .changes, onFinish: ignore)
        .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Runner actions, steal") {
    RunnerActionSheet(context: DemoMoments.midCount, runner: "m3", suggest: DemoMoments.suggest(in: DemoMoments.midCount), onFinish: ignore)
}

#Preview("Runner actions, steal, dark") {
    RunnerActionSheet(context: DemoMoments.midCount, runner: "m3", suggest: DemoMoments.suggest(in: DemoMoments.midCount), onFinish: ignore)
        .preferredColorScheme(.dark)
}

#Preview("Runner actions, steal, largest text") {
    RunnerActionSheet(context: DemoMoments.midCount, runner: "m3", suggest: DemoMoments.suggest(in: DemoMoments.midCount), onFinish: ignore)
        .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Runner actions, wild pitch page") {
    NavigationStack { RunnerActionConfirmPage(context: DemoMoments.twoRunners, reason: .wildPitch, runners: ["m4", "m5"], suggest: DemoMoments.suggest(in: DemoMoments.twoRunners), onFinish: ignore) }.environment(\.insideChangesStack, true)
}

#Preview("Runner actions, wild pitch page, dark") {
    NavigationStack { RunnerActionConfirmPage(context: DemoMoments.twoRunners, reason: .wildPitch, runners: ["m4", "m5"], suggest: DemoMoments.suggest(in: DemoMoments.twoRunners), onFinish: ignore) }.environment(\.insideChangesStack, true)
        .preferredColorScheme(.dark)
}

#Preview("Runner actions, wild pitch page, largest text") {
    NavigationStack { RunnerActionConfirmPage(context: DemoMoments.twoRunners, reason: .wildPitch, runners: ["m4", "m5"], suggest: DemoMoments.suggest(in: DemoMoments.twoRunners), onFinish: ignore) }.environment(\.insideChangesStack, true)
        .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Runner actions, caught stealing page") {
    NavigationStack { RunnerActionConfirmPage(context: DemoMoments.midCount, reason: .caughtStealing, runners: ["m3"], suggest: DemoMoments.suggest(in: DemoMoments.midCount), onFinish: ignore) }.environment(\.insideChangesStack, true)
}

#Preview("Runner actions, caught stealing page, dark") {
    NavigationStack { RunnerActionConfirmPage(context: DemoMoments.midCount, reason: .caughtStealing, runners: ["m3"], suggest: DemoMoments.suggest(in: DemoMoments.midCount), onFinish: ignore) }.environment(\.insideChangesStack, true)
        .preferredColorScheme(.dark)
}

#Preview("Runner actions, caught stealing page, largest text") {
    NavigationStack { RunnerActionConfirmPage(context: DemoMoments.midCount, reason: .caughtStealing, runners: ["m3"], suggest: DemoMoments.suggest(in: DemoMoments.midCount), onFinish: ignore) }.environment(\.insideChangesStack, true)
        .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Error, nobody moved") {
    ErrorSheet(context: DemoMoments.midCount, onFinish: ignore)
}

#Preview("Error, nobody moved, dark") {
    ErrorSheet(context: DemoMoments.midCount, onFinish: ignore)
        .preferredColorScheme(.dark)
}

#Preview("Error, nobody moved, largest text") {
    ErrorSheet(context: DemoMoments.midCount, onFinish: ignore)
        .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Manual adjustment") {
    ManualAdjustmentSheet(context: DemoMoments.basesLoaded, onFinish: ignore)
}

#Preview("Manual adjustment, dark") {
    ManualAdjustmentSheet(context: DemoMoments.basesLoaded, onFinish: ignore)
        .preferredColorScheme(.dark)
}

#Preview("Manual adjustment, largest text") {
    ManualAdjustmentSheet(context: DemoMoments.basesLoaded, onFinish: ignore)
        .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Their batter by number") {
    BatterSheet(context: DemoMoments.theirHitterByNumber, onFinish: ignore)
}

#Preview("Their batter by number, dark") {
    BatterSheet(context: DemoMoments.theirHitterByNumber, onFinish: ignore)
        .preferredColorScheme(.dark)
}

#Preview("Their batter by number, largest text") {
    BatterSheet(context: DemoMoments.theirHitterByNumber, onFinish: ignore)
        .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Our batter") {
    BatterSheet(context: DemoMoments.basesLoaded, onFinish: ignore)
}

#Preview("Our batter, dark") {
    BatterSheet(context: DemoMoments.basesLoaded, onFinish: ignore)
        .preferredColorScheme(.dark)
}

#Preview("Our batter, largest text") {
    BatterSheet(context: DemoMoments.basesLoaded, onFinish: ignore)
        .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Time limit") {
    TimeLimitSheet(context: DemoMoments.midCount, now: DemoMoments.now(for: DemoMoments.midCount), onFinish: ignore)
}

#Preview("Time limit, dark") {
    TimeLimitSheet(context: DemoMoments.midCount, now: DemoMoments.now(for: DemoMoments.midCount), onFinish: ignore)
        .preferredColorScheme(.dark)
}

#Preview("Time limit, largest text") {
    TimeLimitSheet(context: DemoMoments.midCount, now: DemoMoments.now(for: DemoMoments.midCount), onFinish: ignore)
        .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Is the game over? Time limit") {
    GameOverSheet(context: DemoMoments.timeLimitQuestion, onFinish: ignore)
}

#Preview("Is the game over? Time limit, dark") {
    GameOverSheet(context: DemoMoments.timeLimitQuestion, onFinish: ignore)
        .preferredColorScheme(.dark)
}

#Preview("Is the game over? Time limit, largest text") {
    GameOverSheet(context: DemoMoments.timeLimitQuestion, onFinish: ignore)
        .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Is the game over? Mercy rule") {
    GameOverSheet(context: DemoMoments.mercyRuleQuestion, onFinish: ignore)
}

#Preview("Is the game over? Mercy rule, dark") {
    GameOverSheet(context: DemoMoments.mercyRuleQuestion, onFinish: ignore)
        .preferredColorScheme(.dark)
}

#Preview("Is the game over? Mercy rule, largest text") {
    GameOverSheet(context: DemoMoments.mercyRuleQuestion, onFinish: ignore)
        .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Game menu") {
    GameMenuSheet(context: DemoMoments.midCount, walkUpSongSeconds: .constant(12), now: DemoMoments.now(for: DemoMoments.midCount), onFinish: ignore)
}

#Preview("Game menu, dark") {
    GameMenuSheet(context: DemoMoments.midCount, walkUpSongSeconds: .constant(12), now: DemoMoments.now(for: DemoMoments.midCount), onFinish: ignore)
        .preferredColorScheme(.dark)
}

#Preview("Game menu, largest text") {
    GameMenuSheet(context: DemoMoments.midCount, walkUpSongSeconds: .constant(12), now: DemoMoments.now(for: DemoMoments.midCount), onFinish: ignore)
        .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Demo screen") {
    GameChangesDemo()
}
