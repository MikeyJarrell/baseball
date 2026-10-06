# Wiring and dress rehearsal: handoff

**Job:** the lead builder’s wiring job (plan/briefs/wiring-and-dress-rehearsal.md), plus the second vocabulary pass.

**Branch:** `codex/wiring`, in the task folder `/Users/mikey/projects/.worktrees/baseball/wiring`.

## What exists now

### The app shell (`app/Scorebook/`)

- **`AppModel`**: made once at launch. It opens the one `FileStorage` (live files in Application Support/Scorebook, backups in Documents/backups), makes the one `StadiumAudioPlayer` with the saved song library and the walk-up length from the settings, saves the library whenever it changes, reads the teams, games and settings, and opens a game in progress. It turns the screens’ requests into storage calls: saving teams (in memory at once, then to the file), starting a game (players typed in during pregame go onto the saved teams through `PregameBuilder.updatedTeam`), the season totals and every box score, the settings, and backups.
- **`GameSession`** (the new `Scoring` module in ScorebookCore, so it is tested without a phone): holds the game, saves each event through storage before the screen changes, replays the game through the rules engine, and works out the box score and batter histories. Undo takes back the scorer’s last event together with any automatic outs after it; Redo puts it back and is cleared by anything new. It records the automatic out whenever a batting hole comes up, replaces the strike-three pitch for a dropped third strike (same id and time), applies the play-by-play’s fixes, and remembers “Later” on the defense check and on the “who runs?” prompt until the next event. A failed save changes nothing and says so.
- **Home screen** (`HomeView`), per the mockup: the date, “Scorebook” and the logo; the game in progress with the inning, both scores (visitors first) and “Resume scoring”; six tiles, words only: New game, Teams, Songs, Season stats, Games, Last box score. A small “Backups” link sits under the tiles: back up now, or put everything back from a backup after a confirmation.
- **Resume:** the app opens straight onto the batting screen when a game is in progress.
- **Pregame into the game:** “New game” opens the pregame screens (refused, with a message, while another game is in progress or before our team exists); “Play ball” saves the game and opens the batting screen.
- **The game screen** (`GameScreen`): the batting screen with every action connected: pitches and the chips, Undo and Redo with their labels, the in-play sequence full screen (and “Dropped 3rd strike” opened from just before the strike-three pitch), runner actions (with the engine’s suggestion and the “same pitch as the strikeout” check), the pitching change, the batter’s sheet, the changes menu, the time limit, manual adjustment, an error with nobody moving, the song settings and a song picker for a hitter with no song. Changed players go into the game’s roster and onto the saved team. The defense check opens by itself each time our team takes the field, and the “who runs?” sheet when a designated non-runner reaches base; swiping either away counts as “Later”. The Box score button opens the game overview, whose “Fix a play” changes and deletes go through the session, and whose “change it” reopens that event’s own steps from where the game stood before it. Ending the game shows the final box score with the newspaper picture and its share button, copy as text, and “Not over” to take the ending back. A backup is written at the end of every game.
- **Teams and songs** (`TeamsWiring.swift`): the pages open from the Teams and Songs tiles on the home screen’s navigation stack, and every request in the teams handoff’s table is connected: teams saved in memory at once, then to the file; usual position and role written onto `Player` (the screens still exchange `PlayerUsuals`, which the shell converts field by field); song import with “Copying songs in…” and its messages; previews with the position fed back for “Start here”; recording with the microphone question the first time, Keep, Redo and Cancel; a recording that stops by itself is collected; imported introductions. Our next hitter is cued again after any change to a song, a start point, a volume or an introduction. A replaced introduction’s file is deleted only once no saved team and no game in progress names it; the list waiting is kept between launches and checked when a game ends and when the app opens.
- **Songs follow the saved team:** during a game, our players’ walk-up songs, warm-up songs and introductions come from the saved team, so a song picked on a player’s page mid-game plays at once.
- **Songs during a game:** our next hitter’s walk-up song (and introduction) is loaded whenever the next hitter changes; our pitcher’s warm-up song plays when our team takes the field (not when Undo steps back over the changeover); the song button counts down to `playback.fadesAt`; the first-pitch fade calls `fadeOut()`.
- **Settings:** the screen stays awake while a game is open (a switch in the song settings sheet turns this off); background audio (`app/Scorebook-Info.plist`); the microphone question, “Records the stadium announcer introductions you make for your players.”; the Files app shows the Documents folder, which holds only the backups folder. The season stats remember the two minimums in `AppSettings`.

### Score lines

Mikey’s decision: every score line lists the visitors first. The resume card, the changeover banner, the “Is the game over?” pop-up (both copies), the game menu and the end-of-game screen now do. The newspaper headline keeps the winner first, as newspapers print it, and the games list keeps “W 7–5”, our runs first, as a result.

### Rules engine fix

A change recorded at the changeover before the defense check (a new pitcher, a substitution) now goes into the check’s suggestion (`Replay.carry`), so the check no longer opens proposing to put the old pitcher back. Found by the walkthrough; checked by `Tests/GameEngineTests/DefenseCheckTests.swift`.

### Second vocabulary pass

All in `notes/vocabulary-requests.md` under “Done in the second pass”. In short: the printer prints decisions, “HBP—by”, runners for non-runners, the game’s length and lettered pinch-hitter footnotes; runner suggestions around the scorer’s fixed runners; results, record and pitchers’ wins and losses from stats; the play log’s inning breaks, out bases and stolen bases; `Player.usualPosition`, `usualRole` and `usuallyLeadsOff`; `Song.artist`; the `fadesAt` comment.

## Screen files changed in this job

- AtBatScreen: `AtBatScreen.swift` (new `countAfter` input), `AtBatControls.swift`, `AtBatBand.swift`, `AtBatWording.swift` (hints from the rules engine, `displayShortName`, visitors first).
- PregameScreens: `OurLineup.swift`, `PregameBuilder.swift`, `PregameInput.swift` (`UsualRole` and `usualRoles` removed; the first lineup reads `Player`), `PregameSamples.swift`.
- PlayEntry: `PlayEntry.swift`, `PlayEntryModel.swift` (fixed runners and re-suggestion); `RunnersStep.swift` (fixed accessibility names on each runner row and its two questions, for the simulator tests).
- GameChanges: `GameOverSheet.swift`, `GameMenuSheet.swift` (visitors first); `BatterSheet.swift` (the note under the edit); `DefenseSheet.swift` (the optional “Dropped third strike instead” link, `onDroppedThirdStrike:`); `PitchingChangeSheet.swift` (the new pitcher can take any batting spot or none, from a menu that lists the old pitcher’s spot first, in place of the switch that offered only the old pitcher’s spot; found by the walkthrough, where a reliever took the spot of the pinch hitter who had batted for the starter).
- GameOverview: `OverviewWording.swift` (reads the play log’s inning break, out base and stolen base); `Tests/GameOverviewTests/MoreLogsTests.swift` (two suites run on the main thread, which clears the build warnings).
- DesignSystemTests: `ScreenImportRulesTests.swift` (`Scoring` added to the modules screens may not import).
- PostgameScreens: `PostgameWording.swift`, `StatColumns.swift`, `SeasonStatsScreen.swift` (the record comes from the totals, so its `games:` input is gone), `PlayerSeasonScreen.swift`, `GamesListScreen.swift`, `PreviewSeason.swift`, `Previews.swift`.
- BoxScorePicture: `BoxScorePicture.swift` (pinch-hitter footnotes).

## Tests

- `swift test` in `app/Packages/ScorebookCore`: every test passes, including the new `ScoringTests`: the sample game and the three Major League games scored event by event through a `GameSession` give their box scores; half a game saved to files, the storage reopened and the rest scored; undo and redo with labels; the automatic out and its undo; the dropped third strike; a failed save; “Later” on the defense check.
- `xcodebuild test -scheme ScorebookUI-Package` in `app/Packages/ScorebookUI`: every test passes.
- `xcodebuild test -project app/Scorebook.xcodeproj -scheme Scorebook` (the new `ScorebookUITests` target, on the iPhone 17 simulator): see the walkthrough below.

## Simulator walkthrough

`app/ScorebookUITests/ScoringWalkthroughTests.swift`, driven by `GameDriver.swift`, scores two whole games on the iPhone 17 simulator through the real screens, tap by tap: every pitch on the count buttons and chips, every ball in play through the in-play sequence (fielders tapped on the field drawing, runners set on the runners step), defense checks, pitching changes, runner moves, the runner for a designated non-runner, a pinch hitter and the end of the game. After each event it checks the app’s situation against the rules engine’s replay of the book, and at the end compares the printed box score line by line, leaving out only the game’s length (the app times the test’s taps).

- **The sample game** (154 events): passes, box score identical, about 4 minutes.
- **Astros at Yankees, June 23, 2019** (291 events): passes, box score identical to the book, about 5 minutes. Two plays differ in details that never reach the box score: the app records the base a batter was out at, and its batted-ball guess fills in a type the book left blank.

The first full run found the two problems fixed above (the batting spot on a pitching change, and the defense check after a change at the changeover); both games pass with them fixed. `SmokeTests.swift` also checks that a game in progress opens straight onto the batting screen, and that the home screen’s six tiles and the teams list open.

## After the review

A fresh reviewer’s notes are in `feedback/ai/wiring-review.md`. All eight findings are fixed:

1. **Player edits during a game keep the saved team’s songs.** Saving a name, number or batting side from a game onto the saved team copies only those details (`Player.savedCopy(updating:)` in `Scoring`); songs, the introduction and the usual spot stay as the team has them. The in-game song picker changes only the walk-up song. Test: “A player edited during a game keeps the saved team’s songs, introduction and usual spot”.
2. **One change at a time.** Every change the game session makes waits for the one before it to finish saving, so two quick taps on Undo take back two events, two on Redo put back two, and nothing is saved twice. Test: “Two Undos and two Redos tapped at once…”, on real files.
3. **Reopening records a waiting automatic out.** `GameSession.resume` records the automatic out a batting hole calls for before anything else; the app uses it at launch and after a restore. Test: “Reopening a game saved just before its automatic out records that out first”.
4. **Back at bat after all.** When a dropped third strike turns the third out around, or Undo or a fix steps back over the changeover, the warm-up song fades and our hitter’s song is loaded again. The defense check still opens by itself every time our team takes the field; when the third out was a strikeout it carries a “Dropped third strike instead” link at the top, which closes the check and opens the dropped-third-strike steps. If the inning still ends (thrown out, or the scorer backs out), the check opens again. Test: `SmokeTests.testDefenseCheckAfterAStrikeoutOffersTheDroppedThirdStrike`.
5. **“Not over”** reads the games again, so the season stats and games list drop the reopened game; a failed end-of-game backup now says so.
6. **The import guard** also keeps screens from importing `Scoring`.
7. **Install steps:** the phone needs to be online for Trust; a free account allows three of your own apps at once; a backup kept in iCloud Drive must be copied back into Scorebook’s backups folder before it can be restored; reinstall from the main project folder after bringing it up to date.
8. **Comments:** `StatsTests/ScenarioEngine.swift` now describes the engine in place; the batter sheet says an edit is saved to the team’s roster for our players too (`GameChanges/BatterSheet.swift`).

## Not done or not checked

- On the phone itself: saving time late in a long game, the picture’s sharpness in a text message, songs with the silent switch on and the screen locked. These belong to the dress rehearsal.
