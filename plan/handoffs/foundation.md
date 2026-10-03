# Foundation: handoff

**Job:** foundation (lead builder).

**Branch:** `codex/foundation`, in the task folder `/Users/mikey/projects/.worktrees/baseball/foundation`.

## What exists now

- **Two packages, every module declared.** `app/Packages/ScorebookCore` (Model, SampleData, GameEngine, Stats, BoxScoreText, Storage, plus the test modules GameEngineTests, StatsTests, BoxScoreTextTests, StorageTests, ModelTests and the TestSupport helper) and `app/Packages/ScorebookUI` (DesignSystem, WalkUpAudio, BoxScorePicture and the seven screen modules). Swift 6 language mode, iOS 18 minimum. DesignSystem, WalkUpAudio and BoxScorePicture each have a `Resources/` folder already declared, so bundling a file needs no `Package.swift` edit. No job should ever need to edit either `Package.swift`.
- **The shared vocabulary** in `Model/`, one file per topic: `Identifiers`, `FieldBasics` (positions, bases, count, score), `People` (players, teams, songs, introductions), `GameSetup`, `Events`, `Play`, `Situation`, `PlayLog`, `BoxScore`, `SeasonTotals`, `ScorebookJSON`. Every type is `Codable`, `Equatable` and `Sendable`.
- **The four service promises** with stand-ins: `RulesEngine` (stand-in `DoNothingRulesEngine`), `StatsCalculator` (`DoNothingStatsCalculator`), `ScorebookStorage`, asynchronous (`InMemoryStorage`), and `WalkUpAudioPlayer`, main thread only (`SilentAudioPlayer`).
- **Sample data**, all hand-written: the Mudcats (twelve players, ten with songs, one switch hitter), the Cardinals (full roster), the Bombers (numbers only), a placeholder team builder, fifteen songs, four game setups, thirteen situations (`SampleSituations.all`), three batter histories, one complete five-inning game with its play log and box score (`SampleGame`), season totals for a one-game season, and the canned `SampleRulesEngine` for screens.
- **Scenario files**: the pattern file and the twenty-two hard plays in `Tests/Scenarios/`, three shared setups, and a README explaining the format. `TestSupport` loads one with `try Scenarios.load("name")` and checks answers with `scenario.expected.mismatches(situation:)`, `mismatches(log:)` and `mismatches(box:)`.
- **DesignSystem stub**: `ScorebookColor`, `ScorebookFont`, `Spacing`, `CountButtonStyle`, `PlainActionButtonStyle`, and `FieldDrawing` with its interface (`occupiedBases`, `highlightedPositions`, `tapSequence`, `runnerMarkers`, `onTap` handing back a `FieldTap`) and a plain placeholder drawing.
- **The app shell**: `app/Scorebook.xcodeproj` (folder-synchronized, 17 KB) and `app/Scorebook/`, opening to a placeholder screen that imports every module.
- `app/README.md`.

## How a 5-4-3 double play is recorded

One `ballInPlay` event. The play has `batterResult: out`, `fielders: [5, 4, 3]`, `multiOut: doublePlay`, and two runner moves: the runner from first to `out` at second with `outBy: [5, 4]`, and the batter from home to `out` at first with `outBy: [4, 3]`. The last fielder in each `outBy` gets the putout, the others assists. The comment at the top of `Model/Play.swift` walks through it.

## Decisions every builder needs

- **Ids are readable text** (`"m3"`, `"c1"`; random codes for things made in the app). Batting spots are counted from 0 everywhere (`batterIndex`, `nextBatterIndex`).
- **Rosters live in the game setup and change without events.** Naming “Batter 4”, or giving their number 22 a name, edits the player in `GameSetup` and holds for the whole game. A sheet that creates a player on the spot hands back an `EnteredEvent`: the event plus `newPlayers`, which the app adds to the roster before recording the event.
- **Designated non-runners are marked per lineup entry** (`LineupEntry.isDesignatedNonRunner`). The runner who replaces one on base is the `runnerForNonRunner` event. There are no courtesy runners. An ordinary pinch runner is a `substitution`.
- **A dropped third strike rides on the strike-three pitch** (`Pitch.droppedThirdStrike`, a `Play`). When the scorer taps the dropped-third-strike button, the wiring replaces the strike-three event with the same pitch carrying the play. `Situation.droppedThirdStrikePossible` says when to show the button.
- **A dropped foul pop-up** is two events: the foul pitch, then `errorWithNoAdvance`.
- **After a third out, the situation is already the next half-inning** with no outs and `isBetweenHalfInnings` true. In the play log, the entry that made the third out keeps the runners still on base in `after`, which is how runners left on base are counted.
- **An error is listed once per play or runner action**, in `errors`; each runner it helped has `advancedOnError` set.
- **A pitching change** puts the new pitcher at position 1. `takesBattingSpotOf` names whose spot in the order they take, such as the pinch hitter who just batted for the old pitcher. See the comment on `PitchingChange`.
- **Rate stats are formulas in Model** (`BattingCounts.battingAverage`, `onBasePercentage`, `sluggingPercentage`; `PitchingCounts.inningsPitchedText` and the per-inning rates) and print with `formattedRate`, so every screen and the printer show the same numbers. Stats fills in the counts.
- **Box score lines**: the sample box score lists every player who held a batting spot, even with no plate appearances (the relief pitchers), and a fielding line for every player who played a position. The stats builder’s box score must match.
- **Notation** in the sample game and scenarios: `1B 7`, `2B 9`, `HR 7`, `6-3`, `F8`, `L6`, `P6`, `3U`, `5-4-3 DP`, `L4-3 DP`, `FC 4-6`, `E6`, `SF 8`, `SH 1-3`, `K`, `ꓘ`, `K 2-3`, `BB`, `IBB`, `HBP`, `SB2`, `CS2 2-6`. The scenario files pin `1B 7`, `5-4-3 DP`, `6-3`, `BB`, `K`, `K 2-3` and `E7`.
- **JSON**: always through `ScorebookJSON`. Dates are written as text and event times are kept to the whole second, so files read back exactly. `ScorebookJSON.formatVersion` is the version tag storage writes. The end-of-game event carries a copy of the final score so the games list needs no replay.
- **Game clock**: `GameSetup.timeLimitMinutes` and `Situation.gameStartedAt`.

## Where the architecture sketch changed

- **Courtesy runner** became `runnerForNonRunner`, per Mikey’s correction that the league has no courtesy runners. The hard scenario “a courtesy runner who scores” became `hard-runner-for-non-runner-scores` (the run goes to the designated non-runner, the stolen base to the runner). `plan/architecture.md` and the briefs on this branch still say “courtesy runner”; Mikey’s update on `main` covers them.
- **Starting pitcher and starting positions** are not separate fields: each lineup entry carries its position, and fielders who do not bat (a pitcher in a designated-hitter game, an unknown opponent’s pitcher) go in `fieldersNotBatting`. The starting pitcher is whoever starts at position 1.
- **Pitching change** gained `takesBattingSpotOf` and `previousPitcherMovesTo`.
- **Situation** gained `scheduledInnings`, `isBetweenHalfInnings`, `defenseCheckDue`, `runnerNeededFor` and `droppedThirdStrikePossible`, which the screens and wiring need.
- **Added**: `EventEdit` (what the play-by-play hands back), `EnteredEvent`, `GameSummary`, `PlateAppearanceSummary`, `PlayDraft`, `RunnerSuggestion`, `PlayPreview`, `GameReplay`, and the `ModelTests` test module.

## For the wiring job

- Bundle id `com.mikeyjarrell.scorebook`, automatic signing with no team set. The app settings the walk-up audio and wiring briefs ask for (background audio, microphone permission, files visible in the Files app, keep the screen awake) are not switched on yet.
- The app icon slot is empty until the designer hands over artwork.
- Xcode makes the `Scorebook` scheme by itself; there is no shared scheme file.

## Not finished or not checked

- The scenario expected values were worked out by hand and have not met a rules engine. The engine builder will be the first to run them; where an engine and a scenario disagree, the official rules settle it.
- `SampleRulesEngine` is rough by design. It knows nothing about the score, the walk-off rule or runs batted in beyond counting runners home.
- The design system and field drawing are placeholders for the designer.

## Evidence

- `swift test` in `app/Packages/ScorebookCore`: 30 tests in 4 suites, all passing (one of them runs 23 cases, one per scenario file). The sample-game suite adds up the hand-written play log and checks it against the hand-written box score: runs by inning, pitches, strikes, batters faced, outs, hits, walks, strikeouts, runs charged, plate appearances, runs batted in, putouts, assists, errors and runners left on base.
- `xcodebuild -scheme ScorebookUI-Package -destination 'platform=iOS Simulator,name=iPhone 17' build`: succeeded with no warnings.
- `xcodebuild -project Scorebook.xcodeproj -scheme Scorebook -destination 'platform=iOS Simulator,name=iPhone 17' build`: succeeded; installed and launched in the iPhone 17 simulator, it opens to the placeholder screen with the sample score and the field drawing.
