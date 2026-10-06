// The rules engine the stats tests use to turn scenario files into play logs: the real one,
// `ScorebookRulesEngine` from GameEngine. Every scenario test in this folder replays its
// scenario through it.
//
// `engine` stays optional so a test run without an engine would show the scenario tests as
// skipped with a reason, never as passed; with the engine plugged in, as now, they always run.

import Model
import GameEngine
import Testing

enum ScenarioEngine {
    /// The rules engine the scenario tests replay through.
    static let engine: (any RulesEngine)? = ScorebookRulesEngine()

    /// True once a rules engine is plugged in. The tests skip only while there is none; with
    /// an engine in place they always run, so a broken engine (a play log with the wrong
    /// number of entries, say) fails them instead of quietly switching them off.
    static let isReady: Bool = engine != nil

    /// The reason shown beside each skipped test.
    static let notReadyReason: Comment = "Skipped: no rules engine is plugged in (see ScenarioEngine.swift)"
}
