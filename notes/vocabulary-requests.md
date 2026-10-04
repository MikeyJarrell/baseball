# Requests to change the shared vocabulary

Builders may not edit `Model/` or `SampleData/`. They write requests in their handoff notes, and the lead builder collects them here and makes them in one pass before the wiring job.

## Open

- **Box score printer:** print the new box score data: the winning and losing pitcher on their pitching lines, “HBP—by Reyes (Ford)” from `notes.hitBatters`, “Webb ran for Quinn in the 3rd.” from `notes.ranForNonRunners`, “T—3:12” from `gameLength`, and pinch-hitter footnotes (“a-popped out for Collins in the 4th”) from each substitute’s `BattingLine.entered`. The data is in `BoxScore`; the printer does not print it yet. Won-lost records and saves are not kept.
- **In-play sequence:** delete `DemoRulesEngine.swift` and point `PlayEntryRules.demo` at `SampleRulesEngine`, which is now the real rules engine; take the batted-ball default from `RulesEngine.suggestedBattedBall(for:)`.
- **In-game changes:** the runner-action sheet must offer “same pitch as the strikeout” (sets `RunnerAction.completesStrikeoutDoublePlay`, for a runner thrown out stealing or picked off on strike three) and “picked off while stealing” (sets `RunnerMove.wasStealing` on a pickoff). Without them real games undercount double plays and caught stealing. The rules engine accepts the double-play mark only on a runner action right after a strikeout in the same half-inning; anywhere else it is ignored and the event is flagged for review.
- **Batting screen:** take the count hints from `RulesEngine.countAfter(_:in:)`, the song countdown from `WalkUpAudioPlayer.playback.fadesAt`, and short team names from `Team.displayShortName` and `GameTeam.displayShortName`.

## Done

Made in the vocabulary pass; `plan/handoffs/vocabulary-pass.md` has the details.

- **Storage:** a way to list backups (`ScorebookStorage.listBackups()`); the in-memory stand-in picks the game in progress the way real storage does.
- **Box score printer:** the box score picture’s previews read `SampleData`; the JSON copies and their drift test are gone.
- **Box score printer:** the winning and losing pitcher (`PitchingLine.decision`, official scoring rule 9.17), which pitcher hit each batter (`BoxScoreNotes.hitBatters`), who ran for each designated non-runner (`BoxScoreNotes.ranForNonRunners`), and the game’s length (`BoxScore.gameLength`).
- **Box score printer:** pinch-hitter footnotes: each substitute’s `BattingLine.entered` gives the inning, the kind of change, whose spot, and how their plate appearance then ended.
- **Stats:** “picked off while trying to steal” (`RunnerMove.wasStealing` on a pickoff), counted as caught stealing; scenario checks for batting line order and positions.
- **Stats:** a pinch hitter who enters with two strikes and strikes out: `PlateAppearanceResult.chargedBatter`, filled in by the rules engine, charges the batter replaced.
- **Stats and test scenarios:** a strikeout and a runner put out on the same pitch is one double play (`RunnerAction.completesStrikeoutDoublePlay`); the Mets–Padres game now matches the official box.
- **Mikey (alternating fielders):** `GameTeam.fieldingRotations`; the rules engine suggests each half-inning’s defense in `Situation.suggestedDefense`, for the defense check to start from.
- **Rules engine review:** the hit credited on a game-ending play (`RunnerSuggestion.batterResult`, and the replay corrects a saved play).
- **Test scenarios:** `hard-walk-off-single-bases-loaded` fixed to expect no question once the game is over.
- **Test scenarios:** catcher’s interference charges the catcher an error; scenario added.
- **Lead builder:** the stats scenario tests are switched on.
- **Design:** ScorebookUI has a test target, `DesignSystemTests`, holding the field-drawing tests.
- **App shell:** the app icon is installed.
- **Batting screen:** count hints from the rules engine, the audio player’s playback state with when the song fades, and short team names.
- **In-play sequence:** `SampleRulesEngine` is the real rules engine, so previews get real notation and runs batted in; a batted-ball guess on the rules engine.
- **In-play sequence:** when the scorer moves one runner, the engine’s suggestion leaves the other runners where it first put them, so a scorer who sends the batter to second on a single must also move the runner from first. Let the suggestion take the scorer’s fixed runners and re-suggest the rest.
- **Postgame and season screens:** season pitching totals need wins and losses (from each game’s winning and losing pitcher). Earned runs and ERA stay out, by plan.
