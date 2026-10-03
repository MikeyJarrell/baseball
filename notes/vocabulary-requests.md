# Requests to change the shared vocabulary

Builders may not edit `Model/` or `SampleData/`. They write requests in their handoff notes, and the lead builder collects them here and makes them in one pass before the wiring job.

## Open

- **Storage:** add a way to list backups to the storage interface, for a restore screen; make the in-memory stand-in pick the game in progress the same way real storage does.
- **Box score printer:** let the box score picture’s previews read `SampleData`, so the app does not ship JSON copies of the sample box scores.
- **Box score printer:** the box score has nothing to print these from: the winning and losing pitcher, which pitcher hit each batter, who ran for a designated non-runner, and how long the game took (first pitch to the end of the game). Earned runs stay out, by plan.
- **Box score printer:** newspaper footnotes for pinch hitters (“a-struck out for Collins in the 4th”) need the box score to record, for each substitute, the inning they entered and what they did there.
- **Stats (optional):** a separate runner-action reason for “picked off while trying to steal,” which official scoring counts as caught stealing; test-file checks for batting order and positions.
- **Stats:** a pinch hitter who enters with two strikes and strikes out: official scoring charges the strikeout and the at-bat to the batter they replaced. The play log should say which batter is charged, and the rules engine fill it in.
- **Stats:** a strikeout with the runner thrown out stealing on the same pitch is officially a double play; today it is two separate events, so the double-play count misses it.
- **Mikey (alternating fielders):** the game setup records positions that alternate between two players by inning (for example, one first baseman in odd innings and another in even innings, often with only one of them batting). The rules engine suggests the defense for each half-inning our team takes the field, and the defense check pre-fills it.
- **Rules engine review:** on a game-ending hit, official scoring credits the batter only with the bases the winning run needed (a walk-off “double” with the winning run on third is a single). The engine’s suggestion moves the batter to first, but the play still saves as a double. Add a corrected batter result to the suggestion, or have the replay correct it.
- **Test scenarios:** `hard-walk-off-single-bases-loaded` expects the “Is the game over?” question to stay open after the game ends; the shared definitions clear it, and the engine follows them. Fix the scenario.
- **Test scenarios:** a strikeout and a pickoff on the same pitch counts as a double play in the official box score (the 2019 Mets at Padres game comes up one short). Same need as the strikeout plus caught-stealing request above.
- **Test scenarios:** decide whether catcher’s interference charges the catcher with an error (official scoring: it does), then add a scenario.
- **Lead builder:** switch on the stats scenario tests by naming the engine in `Tests/StatsTests/ScenarioEngine.swift` (`ScorebookRulesEngine()`); checked in a scratch copy, every stats scenario then passes except the Mets–Padres double play.
- **Design:** ScorebookUI has no test target; the designer’s field-drawing tests wait in `plan/handoffs/`. Add one.
- **App shell:** install the app icon (instructions in the design handoff).
