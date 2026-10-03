# Foundation review

**Verdict: accept after fixes.**

**Reviewer:** a fresh agent that did not build the foundation, reviewing branch `codex/foundation` (commit 4b3dbaa) against `plan/briefs/foundation.md`, with Mikey’s two league corrections applied: no courtesy runners, and fielding stats kept per player with a defense check each time our team takes the field.

**What was run:** `swift test` in `app/Packages/ScorebookCore` (30 tests in 4 suites, all pass, no warnings). `xcodebuild` for the `ScorebookUI-Package` scheme and for the `Scorebook` app on the iPhone 17 simulator (both build, no warnings). The commit changes nothing outside `app/` except the allowed handoff note.

**Baseball checked by hand:** all twenty-two hard scenario files and the pattern file. For each I replayed outs, count, runners, score, runs batted in, the pitcher charged with each run, pitches, strikes, batters faced, putouts, assists and errors against the official scoring rules, including the walk at 3-1 charged to the earlier pitcher (rule 9.16(h)), the inherited runner (rule 9.16(g)), the walk-off single that scores only the winning run, and the runner for a designated non-runner (run to the non-runner, stolen base to the runner). Every expected answer is right. I also replayed the whole sample game, plate appearance by plate appearance: the play log agrees with the events, and every number in the box score (line score, R H E, every batting, pitching and fielding line, left on base, double plays and the notes) agrees with the play log. No wrong count or wrong score was found.

The findings below are gaps in the vocabulary that later jobs will hit. They are cheap to fix now and expensive once several builders have started, so they come first even though none of them is a wrong answer today.

## Findings, most severe first

### 1. The runner for a designated non-runner has no place in the box score

**Where:** `app/Packages/ScorebookCore/Sources/Model/BoxScore.swift:100–131` (`BattingLine`, especially `batterIndex` at line 107, which cannot be left empty); scenario files `hard-runner-for-non-runner-scores.json` and `hard-designated-non-runner-singles.json`.

**What is wrong:** Both scenarios expect a batting line for Jamie Cole (`m10`), who ran for Alex Moreno and stole third. Cole never held a spot in the batting order, but a `BattingLine` must name one. Nothing says where Cole’s line goes, what position it prints, or what happens when the runner is a teammate who already has a line of his own. The stats builder and the box score printer will each guess, and the guesses will not match.

**Fix:** Write the rule into the comment on `BattingLine` and into the handoff: a runner who already has a batting line keeps their stolen bases and caught stealing on it; a runner with no line gets one listed right under the designated non-runner’s spot, with that spot’s `batterIndex`, `isSubstitute: true`, no plate appearances, and a position of `pr` (or add a new `BoxPosition` case for it). Add the case to the sample data so the printer has an example.

### 2. A manual adjustment to the score leaves the box score unable to add up

**Where:** `Sources/Model/Events.swift:471–507` (`ManualAdjustment.score` at line 479); `Sources/Model/BoxScore.swift:181–198` (`LineScore`) and line 59 (`TeamBoxScore.runs`).

**What is wrong:** When the scorer fixes the score by hand, no event says which inning the missing or extra runs belong to, and no player scored them. The line score and the team’s runs, which stats build from runs in the play log, will then disagree with the scoreboard and the final score. The walk-off scenario shows it: it starts tied 3-3 by adjustment, so a box score built from its play log reads 1 run for the Mudcats against a final score of 4. A shared box score that does not add up to the final score is exactly the kind of error the group will notice.

**Fix:** Decide the rule and write it on `ManualAdjustment`: stats add the difference in each team’s score to that half-inning’s cell in the line score and to the team’s runs, credited to no player and charged to no pitcher. Add a scenario expectation that checks team runs after an adjustment.

### 3. Runners left on base are only defined for innings that end on a third out

**Where:** `Sources/Model/BoxScore.swift:62`; `Sources/Model/PlayLog.swift:66–68`; the left-on-base test in `Tests/ModelTests/SampleGameTests.swift:87–93`.

**What is wrong:** The vocabulary counts runners left on base from the entry that made the third out. A walk-off, or a game the scorer ends on the time limit in the middle of an inning, has no third out, so any runners still on base fall out of the count without anyone having decided that they should.

**Fix:** Decide whether runners on base when the game ends count as left on base, write it in both comments, and add the left-on-base check to `hard-walk-off-single-bases-loaded.json`.

### 4. The rules engine has no function for suggesting where runners go on a wild pitch or balk

**Where:** `Sources/Model/RulesEngineService.swift:11–27`.

**What is wrong:** The in-game changes brief (item 7) has the runner-action sheet show every runner with a suggested result on a wild pitch or balk. Screens may not work out baseball themselves, and the rules engine’s promise only offers suggestions for a ball in play (`suggestRunners(for: PlayDraft, …)`). The sheet’s builder will either do the arithmetic in the screen or ask for a change after three versions of the rules engine exist (the do-nothing one, the canned one and the real one).

**Fix:** Add something like `suggestRunnerAction(_ reason: RunnerMoveReason, runners: [PlayerID], in: Situation) -> [RunnerMove]` now, with canned answers in `SampleRulesEngine` and an empty one in `DoNothingRulesEngine`.

### 5. Storage cannot report one damaged game and still return the others

**Where:** `Sources/Model/StorageService.swift:14, 22, 32` (`loadTeams`, `listGames`, `finishedGames`).

**What is wrong:** The storage brief’s finish line asks for a deliberately corrupted file to be “reported as damaged without losing the other games.” Each of these functions either returns a full list or throws. A storage builder must choose between hiding the damaged file and losing the whole list, and the games list and season totals cannot show the scorer which file is broken.

**Fix:** Have these return the good items together with a list of damaged files (for example a small result type with `items` and `damaged: [StorageError]`), or give `GameSummary` a damaged flag and reason.

### 6. The field drawing cannot tell the in-play screen which runner was tapped

**Where:** `app/Packages/ScorebookUI/Sources/DesignSystem/FieldDrawing.swift:13–21` (`FieldTap`), `25–39` (`FieldRunnerMarker`), `177–181`.

**What is wrong:** In the in-play sequence’s runner step, the scorer taps a runner to cycle where they ended up. `FieldTap` can only report a position, a base or a spot, and two markers can sit on the same spot (the batter starting at home and a runner who scored both end at home), so the screen cannot tell which runner was meant. Separately, `FieldRunnerMarker` has no base where an out was made, so every runner put out is drawn at second, including the batter thrown out at first and a runner thrown out at home. Adding a case to `FieldTap` later breaks the code of every screen that already handles taps.

**Fix:** Add `case runner(PlayerID)` to `FieldTap` and make the markers tappable, and add `outAt: Base?` to `FieldRunnerMarker` (filled from `RunnerMove.outAt`).

### 7. The game overview screen cannot meet its finish line with the sample data

**Where:** `Sources/SampleData/SampleGame.swift:31–39` (`throughThreeInnings`); `Sources/SampleData/SampleSituations.swift:221–248` (`SamplePlateAppearances`).

**What is wrong:** The game overview brief asks for previews of the complete sample game and of a game in the third inning, showing the box score so far and each batter’s plate appearances in scorebook notation. Screens may not use the stats module, and the sample data has only the final box score, a play log cut after three innings with no box score to match, and plate appearance histories for three batters.

**Fix:** Add a hand-written `SampleGame.boxScoreThroughThree`, and plate appearance histories for every batter in the sample game (full game and through three innings), keyed by player. The sample game tests can check them against the play log the same way they check the final box score.

### 8. A stolen base that turns into more bases on an error does not say which base was stolen

**Where:** `Sources/Model/Events.swift:254–306` (`RunnerMove`) and `309–324` (`RunnerMoveReason`); `hard-double-steal-throwing-error.json`, event `e4`.

**What is wrong:** Ortiz goes from second to home with `reason: stolenBase` and `advancedOnError: true`. The intended reading (stole third, scored on the error) is right, but the vocabulary never says so, and the same fields would also describe a steal of home on which the catcher also threw the ball away. The notation (“SB3” and the error) depends on the reading.

**Fix:** State the rule on `RunnerMove`: a stolen base is always one base, and any bases past it came from the error. Also widen the comment on `reason` (line 261–263), which says it is only for moves between pitches; the batter’s move on a dropped third strike is where a wild pitch or passed ball would be recorded.

### 9. Scenario files cannot check the defense check prompt, and a missing batting line passes silently

**Where:** `app/Packages/ScorebookCore/Tests/TestSupport/Scenario.swift:81–109` (`ExpectedSituation`); `Tests/TestSupport/Scenarios.swift:103–105`.

**What is wrong:** `ExpectedSituation` has no `defenseCheckDue` or `droppedThirdStrikePossible`, so the test writer cannot pin the defense check that Mikey asked for each time our team takes the field, or the dropped third strike button. Separately, when a scenario expects batting numbers for a player who has no batting line at all, the check adds up zero lines and compares against zeros, so an expectation such as `"plateAppearances": 0` passes even when the player is missing from the box score.

**Fix:** Add both fields to `ExpectedSituation` and its checker, and make the batting check report “no batting line” when the scenario names a player the box score leaves out. Then add a defense check expectation to a scenario where the Mudcats take the field.

### 10. Two sample situations show the wrong pitcher

**Where:** `Sources/SampleData/SampleSituations.swift:103–109` (`extraInnings`) and `80–92` (`newPitcherJustIn`).

**What is wrong:** In `extraInnings`, the pitch counts are for the relievers Voss (`m12`) and Reyes (`c12`), but both teams still have their starters at pitcher and in the ninth spot, so the batting screen’s preview will show Barros on the mound with no pitch count. In `newPitcherJustIn`, Reyes has a pitch count but the Cardinals still have Collins pitching and batting ninth.

**Fix:** In both, put the relievers at pitcher in `fielders` and in the ninth batting spot, as `newPitcherJustIn` already does for the Mudcats.

### 11. Smaller gaps for the screens, audio and wiring

- **Game clock.** `Situation` copies `scheduledInnings` from the setup but not `timeLimitMinutes` (`Sources/Model/Situation.swift:48–52`), so the batting screen also needs the setup to show time left. Copy it in, or say in the batting screen brief that the screen is handed the setup alongside the situation.
- **The song button cannot learn that a song stopped by itself.** `WalkUpAudioPlayer` (`Sources/Model/WalkUpAudioService.swift:14–23`) exposes `isPlaying` but nothing a screen can watch, so a clip that fades out after its set length leaves the button showing “stop.” Have the promise require Apple’s `Observable`, and mark `SilentAudioPlayer` with `@Observable`.
- **Imports on the main thread.** `importSongs` and `importIntroduction` are on the main thread with the rest of the audio promise; copying a long song or waiting on an iCloud download there would freeze the screen. Say in the comment that the real version must do the copying off the main thread.
- **The “fade the song on the first pitch” setting** from the batting screen brief has nowhere to live. Add it to `SongLibrary` or say in the wiring brief where it goes.

## Code comments

Every Swift file opens with a comment saying what it is for, and the types and functions in `Model/` and `SampleData/` are explained in baseball terms. The walkthrough of a 5-4-3 double play at the top of `Play.swift` meets the finish line: a reader of `Model/` alone can explain how it is recorded. No changes needed.

## Swift 6 and builds

Both packages and the app shell use the Swift 6 language mode and build without warnings. Every vocabulary type is `Codable`, `Equatable` and `Sendable`; storage is asynchronous and the in-memory stand-in is an `actor`; audio is pinned to the main thread. Apart from the audio points in finding 11, nothing here looks likely to trouble later builders.

## Finish line

Met: `swift test` passes, all twenty-two hard scenarios and the pattern file decode, sample data reads back from JSON without loss, every module compiles, and the 5-4-3 double play is explained in `Model/`. Findings 1 to 7 should be fixed before the rules engine, stats, storage and screen jobs start, because each one changes something those jobs will build on. Findings 8 to 11 can follow.
