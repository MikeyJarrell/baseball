import Testing
import Model
import GameEngine
@Test func zzDebug() throws {
    let (game, _) = try NineInningGameTests.game()
    let log = ScorebookRulesEngine().replay(game).log
    for e in log.entries where e.needsReview || e.plateAppearance != nil {
        print("DBG", e.event.id, e.inning, e.half, e.batter ?? "-", e.notation, e.after.outs, e.needsReview ? (e.reviewNote ?? "") : "")
    }
}
