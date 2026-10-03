# Vocabulary pass: handoff

**Job:** the lead builder’s vocabulary pass, making every request in `notes/vocabulary-requests.md`, plus the batting screen’s and in-play sequence’s requests from their handoffs.

**Branch:** `codex/vocabulary-pass`, in the task folder `/Users/mikey/projects/.worktrees/baseball/vocabulary-pass`.

## For the screen and audio builders working now

Every change is additive: new optional fields, new fields with defaults, new types, and new protocol functions with default answers. **No case was added to any existing enum.** Code written against the earlier `Model/` builds unchanged. Two things change behavior a screen may see:

- **`SampleRulesEngine` is now the real rules engine** (`ScorebookRulesEngine`, wrapped in SampleData so screens still import only Model, SampleData and DesignSystem). Previews get real notation, runner suggestions and runs batted in, and `replay` replays any game. SampleData now depends on GameEngine, and screens keep importing only Model, SampleData and DesignSystem.
- **The sample game’s runner for Quinn is Webb**, unchanged from main; the new box score data (below) is filled in on `SampleGame.boxScore` and `boxScoreThroughThree`.

New protocol requirements, all with defaults so existing conformers build: `RulesEngine.countAfter(_:in:)` (default: the shared counting rules), `RulesEngine.suggestedBattedBall(for:)` (default: no guess), `WalkUpAudioPlayer.playback` (default: a song while playing, else idle). `ScorebookStorage.listBackups()` has no default; the two conformers, `FileStorage` and `InMemoryStorage`, both have it.

## What changed

- **Storage.** `listBackups()` is on the storage promise. `InMemoryStorage.gameInProgress()` makes the real storage’s choice: the unfinished game with the latest event, or, if none has started, the one saved most recently.
- **Box score data** (filled in by the stats engine and in the hand-written sample box scores):
  - `PitchingLine.decision`: win or loss, under official scoring rule 9.17. The win goes to the winning team’s pitcher of record when it took the lead for good; a starter needs five complete innings (four when the team played five innings in the field), otherwise a reliever gets it. Which reliever is the scorer’s judgment under the rule; the stats engine picks the one with the most outs, then the fewest runs charged, then the earliest. The loss goes to the pitcher charged with the go-ahead run. No saves or won-lost records.
  - `BoxScoreNotes.hitBatters`: each hit batter with the pitcher who hit them.
  - `BoxScoreNotes.ranForNonRunners`: who ran for each designated non-runner, and in which innings.
  - `BoxScore.gameLength`: seconds from the first pitch to the end-of-game event, once final.
  - `BattingLine.entered`: for each substitute, the inning they came in, the kind of change, whose spot, and how the plate appearance they finished in that half-inning ended, for the footnotes.
- **A pinch hitter who comes in with two strikes and strikes out:** the rules engine sets `PlateAppearanceResult.chargedBatter` to the batter replaced (Official Baseball Rules 9.15(b)); `batterCharged` reads it. Stats and batter histories use it. Any other result stays with the pinch hitter.
- **A strikeout and a runner out on the same pitch** stay two events; the runner action’s `completesStrikeoutDoublePlay` makes them one double play for the fielding team. The Retrosheet converter now sets it on `K+` plays, and the Mets–Padres game matches the official box score.
- **Picked off while trying to steal:** a pickoff move marked `wasStealing` counts as caught stealing (rule 9.07(h)); `RunnerMove.countsAsCaughtStealing` says so.
- **Catcher’s interference** charges the catcher an error (rule 9.12(c)). The rules engine adds it itself, so the play need not list it; one the play does list is not counted twice. Written on `BatterResult.catchersInterference`.
- **A game-ending hit** is credited only with the bases the winning run needed, home runs excepted (rule 9.06(f)). `RunnerSuggestion.batterResult` offers the corrected hit to the in-play screen, and the replay credits it even when the play was saved as the longer hit.
- **Alternating fielders:** `GameTeam.fieldingRotations` lists positions shared by turns by inning. Each half-inning our team takes the field, `Situation.suggestedDefense` is the current defense with the turns applied for that inning (`GameTeam.defense(forInning:from:)`), for the defense check to start from. Nothing changes until the scorer confirms; a changed defense is recorded as a substitution.
- **Count hints:** `RulesEngine.countAfter(_:in:)` returns a `CountChange` with the count after the pitch, whether it ends the plate appearance, and the words (“makes it 2–1”, “walk”, “strikeout”, “stays 3–2”). One copy of the counting rules, in `CountChange.after(_:from:)`.
- **Walk-up playback state:** `WalkUpAudioPlayer.playback` (`AudioPlayback`): idle, introduction, song or warm-up, the song, and `fadesAt`, when the song will start fading by itself.
- **Short team names:** `Team.shortName` and `GameTeam.shortName`, with `displayShortName` falling back to `ShortTeamName.make(from:)` (the last word if four letters or fewer, else its first three). The sample Diamond Dogs are “DOGS” and the Mudcats “MUD”.
- **Batted-ball guess:** `RulesEngine.suggestedBattedBall(for:)`: one outfielder is a fly ball, a throw a ground ball, a sacrifice fly a fly ball, a sacrifice bunt a bunt, otherwise no guess.
- **Box score picture previews** read `SampleData` (BoxScorePicture now depends on it); the JSON copies and `PreviewFixtureTests` are deleted.
- **ScorebookUI test target** `DesignSystemTests`, holding the designer’s six field-drawing tests. Run with `xcodebuild test -scheme ScorebookUI-Package -destination 'platform=iOS Simulator,name=iPhone 17'` in `app/Packages/ScorebookUI`.
- **App icon** installed from `plan/mockups/icon/`, light and dark.
- **Stats scenario tests** switched on (`Tests/StatsTests/ScenarioEngine.swift` names `ScorebookRulesEngine()`).
- **Scenarios:** `hard-walk-off-single-bases-loaded` now expects no open question after the game ends, and the rules engine’s known-disagreement list is empty. The scenario format can check a team’s batting line order (`battingLines`), a batter’s `positions`, a pitcher’s `decision` or `hasDecision`, and the situation’s `suggestedDefense`. New files: two pinch hitters with two strikes, the strikeout double play, a pickoff while stealing, catcher’s interference, a walk-off double credited as a single, alternating first base (with the `alternating-first-base` setup), and a reliever’s win. The scenarios README describes the test writer’s library, `undo/` and `retrosheet/`; the typo in `tie-at-time-limit` is fixed.
- **Sample data:** `SampleSetups.mudcatsAtDiamondDogsAlternatingFirstBase` and `SampleSituations.defenseCheckWithRotation`, for the defense check’s previews.

Files edited outside `Model/` and `SampleData/`, as the requests required: `GameEngine/Replay.swift`, `Suggestions.swift` and `GameEngine.swift`; `Stats/BoxScoreBuilder.swift`, `PlayLogReading.swift` and `Stats.swift`, plus the new `Stats/BoxScoreExtras.swift`; `BoxScorePicture/Previews.swift`; `Tests/StatsTests/ScenarioEngine.swift`; `Tests/GameEngineTests/ScenarioTests.swift`; the Retrosheet converter and the Mets game’s file. New test files: `Tests/ModelTests/VocabularyPassTests.swift` and `Tests/GameEngineTests/VocabularyPassEngineTests.swift`.

## Owner decision noted

Mikey chose a one-tap Called button inside the Strike button, as in the approved mockup. The batting screen already works that way.

## For the wiring job

- When `Situation.suggestedDefense` is set, open the defense check filled in with it. Confirming an unchanged defense records `defenseConfirmed`; anything different records a `substitution` with those defense assignments.
- Pass `RulesEngine.countAfter` results to the batting screen, and `playback.fadesAt` for the song countdown.
- A restore screen can list backups through the storage promise.

## Not finished or not checked

- The box score printer does not print the new data yet; that is open in `notes/vocabulary-requests.md`.
- The dark app icon did not show when the simulator was switched to dark appearance; iOS shows dark icons only when the home screen’s own icon setting is Dark, which was not changed. The light icon shows on the home screen.
- The audio builder’s `StadiumAudioPlayer` reports `playback` through the default until they fill in `fadesAt`.
- The plan’s brief texts still describe the extra-hitter label and the between-innings playlist; those were listed for Mikey in the foundation handoff.

## Evidence

- `swift test` in `app/Packages/ScorebookCore`: 195 tests, all passing, including the newly switched-on stats scenario tests (every scenario file, the Mets–Padres game included).
- `xcodebuild test -scheme ScorebookUI-Package -destination 'platform=iOS Simulator,name=iPhone 17'`: the six design-system tests pass; the package builds with no warnings.
- `xcodebuild -project Scorebook.xcodeproj -scheme Scorebook -destination 'platform=iOS Simulator,name=iPhone 17' build`: succeeded. Installed on the iPhone 17 simulator, the home screen shows the Diamond Dogs icon above “Scorebook”.
