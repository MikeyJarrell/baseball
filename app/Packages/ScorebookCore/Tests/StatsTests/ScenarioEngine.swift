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
import TestSupport
import Testing

enum ScenarioEngine {
    /// The rules engine, once there is one.
    static let engine: (any RulesEngine)? = nil

    /// True when a real rules engine is plugged in. A stand-in that does nothing (an empty play
    /// log for a game with events) does not count, so plugging one in skips the tests rather
    /// than failing them.
    static let isReady: Bool = {
        guard let engine, let pattern = try? Scenarios.load("pattern-6-3-groundout") else { return false }
        let log = engine.replay(pattern.game).log
        return !log.entries.isEmpty && log.entries.count == pattern.events.count
    }()

    /// The reason shown beside each skipped test.
    static let notReadyReason: Comment = "Skipped until the rules engine lands: see ScenarioEngine.swift"
}
