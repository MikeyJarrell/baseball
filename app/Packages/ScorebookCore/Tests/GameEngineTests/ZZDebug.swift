import Testing
import Foundation
import Model
import GameEngine
@Test func zzDebug() throws {
    let (game, _) = try NineInningGameTests.game()
    var events = game.events
    var t = events.last!.enteredAt
    while events.count < 300 { t = t.addingTimeInterval(20); events.append(GameEvent(id: EventID(rawValue: "p\(events.count)"), enteredAt: t, kind: .pitch(Pitch(.foul)))) }
    let g = Game(id: "x", setup: game.setup, events: events)
    let c = ContinuousClock()
    let d = c.measure { for _ in 0..<20 { _ = ScorebookRulesEngine().replay(g) } }
    print("DBG one replay of 300 events:", d / 20)
}
