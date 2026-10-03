# Game rules engine: handoff

**Job:** game rules engine.

**Branch:** `codex/game-rules-engine`, in the task folder `/Users/mikey/projects/.worktrees/baseball/game-rules-engine`.

## What exists now

`ScorebookRulesEngine` in `app/Packages/ScorebookCore/Sources/GameEngine/` is the real version of the `RulesEngine` promise in `Model/`. Create one with `ScorebookRulesEngine()`; it remembers nothing between calls, so one copy serves the whole app from any thread.

- **Replay** (`Replay.swift`): the situation after the last event and one play log entry per event. Undo and edits need nothing special: replay the changed event list. A 300-event game replays in about 8 milliseconds in a test build and 1.5 in an optimized one, so replaying after every tap is fine.
- **Suggestions** (`Suggestions.swift`): suggested runner outcomes and runs batted in for a ball in play, the play preview, suggested runner moves between pitches, and who runs for a designated non-runner.
- **Is the game over?** (`GameEndRules.swift`): the regulation, run-rule and time-limit questions, and the live clock between events.
- **Notation** (`Notation.swift`): scorebook shorthand for every event.

The engine reproduces the hand-written sample game in `SampleData` exactly: every play log entry, the final situation, and both final batting orders.

## Choices the vocabulary left open

These are the engine’s answers where `Model/` and the plan were silent. Each can change if Mikey or the lead builder wants it otherwise.

- **An unanswered “Is the game over?” lapses when play goes on.** The question stays open through lineup changes and other bookkeeping, and closes without being recorded as declined at the next pitch, ball in play, intentional walk, runner move, error or automatic out. It is asked again at the next point where a rule applies. Only a `keepPlaying` event stops a reason for good.
- **An inning started after the time limit with no answer is a last inning.** Its walk-off works as in the ninth, and the time-limit question comes back when it ends. Between innings after the limit, `isLastInning` is false and `clock(for:at:)` sets `askIfOverOnTime`.
- **When several reasons apply at once**, regulation is asked first, then the run rule, then the time limit.
- **The defense check stops being due** when our team confirms its defense, when our team makes a fielding change during the check, or at the first piece of play in the half-inning, so a skipped check does not reopen on every pitch.
- **A manual adjustment** that moves the inning or half starts the new half with no outs, a fresh count and nobody on, unless it sets those too. Runners it lists who were already on base keep their responsible pitcher; only runners newly put on base are charged to the pitcher on the mound. The `ManualAdjustment` comment says runners “placed this way are charged to the pitcher on the mound”; the engine reads that as newly placed runners, so a run scored by a runner the adjustment only moved stays with the pitcher who put them on.
- **The dropped-third-strike button** is offered after every called or swinging strike three, whatever the outs and whoever is on first, since the app does not enforce the rule. A foul tip or foul bunt for strike three never offers it.
- **The runner suggested for a designated non-runner** also skips anyone already on base, not only the batter now at bat.
- **Batters faced** are counted when a plate appearance ends, so a batter who was up when a runner made the third out is not counted until they finish next inning.
- **The walk-off limit** (only the winning run scores, nobody moves further than that runner) is applied to singles, doubles and triples. Home runs, errors and the rest get their ordinary suggestion.
- **Default runs batted in** count every run that scores on the play, except none on an error, a dropped third strike or a ground-ball double play, and none for a runner marked as advancing on an error. The scorer confirms the number.
- **Notation**, beyond what the sample game fixes: a foul tip is `T` and a foul bunt `L` mid-count; a dropped third strike reads `K 2-3`, `K WP`, `K PB`, `K E2` or `K, safe`; runner moves read `SB2`, `SBH`, `CS2 2-6`, `PO1 1-3`, `WP`, `PB`, `BK`, `DI`, and a double steal on a throwing error `SB3, SB2, E2`; an out with no batted-ball type and one fielder is just the number (`8`); lineup changes read `PH Moss for Ortiz`, `PR …`, `Ortiz for Moss`, `Moss to cf`, `P Voss`, `R Webb for Quinn`, `Added Moss`, `Hole in spot 2`, `Auto out`, `Final`, and the defense check is blank.

## Scenario the engine disagrees with

`hard-walk-off-single-bases-loaded` expects `gameOverQuestion: "regulation"` after the `endOfGame` event. `Model/Situation.swift` says the question is “cleared once the game is final,” and the wiring brief shows the question whenever it is set, so keeping it would ask “Is the game over?” about a finished game. The engine clears it. The scenario should check `isGameOverQuestionOpen: false` there (its checkpoint after `e3` already checks the question while the game is still open). Until the test writer changes it, `ScenarioTests.knownDisagreements` lists this one mismatch, and a test fails once the scenario no longer disagrees, so the entry gets removed. Every other expected value in all 39 scenario files passes.

## Vocabulary change requests

- **Names for lineup notation.** `RulesEngine.notation(for:in:)` gets only a situation, which has no rosters, so it names players by id in lineup changes (`P d12`). The play log from `replay` uses last names (`P Voss`), and screens that show history read the play log, so nothing needs it now. If a screen ever needs lineup notation outside the play log, the function needs the game setup or a name lookup.
- **A pinch hitter who takes over with two strikes.** Official Baseball Rules 9.15(b) charges a strikeout to the original batter in that case. The vocabulary has no place to say so, and the engine credits the plate appearance to whoever is batting when it ends. Worth a field on `PlateAppearanceResult` only if Mikey wants that rule.

## For the wiring job

- `replay(game)` after every event; `clock(for:at:)` on a timer for time left, the last-inning warning, and asking between innings.
- When `Situation.isBattingHoleUp` is true, record the `automaticOut` event. An automatic out that no longer lines up with the hole after an edit is flagged and does not count, so the hole comes up again.
- `Situation.runnerChoice` opens when a designated non-runner reaches and closes on the next pitch, ball in play or intentional walk, a `runnerForNonRunner` event, a pinch runner for them, or when they are no longer on base.
- Entries with `needsReview` carry a plain-English `reviewNote` (“Ruiz is not on base.”, “The play names Kim as the batter, but Ford is up.”) for the play-by-play screen.

## For the stats job

- `outs` and `runs` on an entry are in the order the play lists its runners.
- An automatic out’s `OutMade` names the player who held the spot, with no putout.
- A walk after a pitching change at 2-0, 2-1, 3-0, 3-1 or 3-2 has the earlier pitcher on `plateAppearance.pitcher`; the pitch itself is on `entry.pitcher`.
- A batter who reaches on a fielder’s choice that retires a runner takes over that runner’s responsible pitcher (rule 9.16(g)).
- A manual adjustment that changes the score puts the difference in `adjustedRuns`.

## Not finished or not checked

- Nothing in the brief is left out.
- Scenario files the test writer adds on their own branch have not met this engine. `ScenarioTests` picks up every file in `Tests/Scenarios/` by itself.

## Evidence

`swift test` in `app/Packages/ScorebookCore`: 106 tests, all passing (41 from the foundation, 65 for the engine; the three scenario tests run once per scenario file, 39 files each). The engine’s tests, in `Tests/GameEngineTests/`:

- `ScenarioTests`: every scenario’s expected situation, notation and checkpoints, and nothing flagged for review.
- `SampleGameReplayTests`: the hand-written sample game, entry by entry.
- `NineInningGameTests`: a nine-inning game written pitch by pitch. The final score (5-6), line scores, runners left on base (3 and 3) and every pitcher’s pitches, strikes and batters faced were worked out by hand and by a separate counting script. The sixth inning ends on a caught stealing.
- `LineupTests`: eleven hitters grow to thirteen in the fifth; a hitter added after the last hitter batted; pinch hitters, fielding changes, re-entry, a filled batting hole.
- `PlayLogTests`: putouts, assists, errors, runs, responsible pitchers and plate appearances on the hard plays.
- `EditAndUndoTests`: undo after every event of the nine-inning game, edits and deletions mid-game, 3,000 random events that never crash, and speed.
- `SuggestionTests`, `NotationTests`, `GameEndTests`: the brief’s suggestion rules, notation for every kind of event, the time limit, run rule, regulation and clock.
