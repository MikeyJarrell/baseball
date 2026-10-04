# Requests to change the shared vocabulary

Builders may not edit `Model/` or `SampleData/`. They write requests in their handoff notes, and the lead builder collects them here and makes them in one pass before the wiring job.

## Open

None.

## Done in the second pass (the wiring job)

Made during wiring; `plan/handoffs/wiring.md` has the details.

- **Box score printer:** prints the winning and losing pitcher, “HBP—by Reyes (Ford)”, “Webb ran for Quinn in the 3rd.”, “T—3:12”, and lettered pinch-hitter footnotes (“a-popped out for Collins in the 4th.”).
- **In-play sequence:** `DemoRulesEngine.swift` is gone and the batted-ball default comes from `RulesEngine.suggestedBattedBall(for:)` (done by the in-play job after the first pass).
- **In-play sequence:** moving one runner keeps that runner where the scorer put them and suggests the others again (`RulesEngine.suggestRunners(for:in:keeping:)`, `PlayEntryModel.fixedRunners`).
- **In-game changes:** “same pitch as the strikeout” and “picked off while stealing” are on the runner-action sheet (built by the in-game changes job).
- **Batting screen:** the count hints come from `RulesEngine.countAfter(_:in:)`, the song countdown from `playback.fadesAt`, and the scoreboard’s short team names from `GameTeam.displayShortName`.
- **Postgame and season screens:** `GameSummary.result` (win, loss or tie for us), `SeasonTotals.wins`, `losses` and `ties`, `SeasonPitchingLine.wins` and `losses`, home or away and the result on a player’s game log entry, and the two stats minimums kept in `AppSettings`.
- **Game overview:** the play log supplies the break between half-innings (`Situation.inningBreak`, “Middle 3rd”), the base a runner was put out at (`OutMade.at`, filled in by the replay), and the base stolen (`RunnerMove.baseStolen`).
- **Pregame and teams screens:** `Player.usualPosition`, `Player.usualRole` (bats and fields, bats only, fields only, starts on the bench) and `Player.usuallyLeadsOff`; the first game’s lineup reads them.
- **Teams and songs screens:** an optional `Song.artist`. Mikey’s decision: no fade length per song; the fade is two seconds for every song.
- **Walk-up audio:** the comment on `AudioPlayback.fadesAt` now says the fade starts then and the song is silent two seconds later.

## Done in the first pass

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
