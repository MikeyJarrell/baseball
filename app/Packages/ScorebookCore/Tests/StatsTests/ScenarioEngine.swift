// The rules engine the stats tests use to turn scenario files into play logs.
//
// The rules engine (GameEngine) is being built on another branch. Until it lands there is no
// engine to plug in here, so `engine` is nil and every test that needs one is skipped: it
// shows as skipped in the test run, never as failed.
//
// WHEN THE RULES ENGINE LANDS: replace `nil` below with the engine, for example
//
//     static let engine: (any RulesEngine)? = GameRulesEngine()
//
// using whatever name the engine's type has. That one line switches on every scenario test
// in this folder. Nothing else needs to change.

import Model
import GameEngine
import Testing

enum ScenarioEngine {
    /// The rules engine, once there is one.
    static let engine: (any RulesEngine)? = ScorebookRulesEngine()

    /// True once a rules engine is plugged in. The tests skip only while there is none; with
    /// an engine in place they always run, so a broken engine (a play log with the wrong
    /// number of entries, say) fails them instead of quietly switching them off.
    static let isReady: Bool = engine != nil

    /// The reason shown beside each skipped test.
    static let notReadyReason: Comment = "Skipped until the rules engine lands: see ScenarioEngine.swift"
}
