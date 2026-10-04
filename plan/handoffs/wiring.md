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

### Second vocabulary pass

All in `notes/vocabulary-requests.md` under “Done in the second pass”. In short: the printer prints decisions, “HBP—by”, runners for non-runners, the game’s length and lettered pinch-hitter footnotes; runner suggestions around the scorer’s fixed runners; results, record and pitchers’ wins and losses from stats; the play log’s inning breaks, out bases and stolen bases; `Player.usualPosition`, `usualRole` and `usuallyLeadsOff`; `Song.artist`; the `fadesAt` comment.

## Screen files changed in this job

- AtBatScreen: `AtBatScreen.swift` (new `countAfter` input), `AtBatControls.swift`, `AtBatBand.swift`, `AtBatWording.swift` (hints from the rules engine, `displayShortName`, visitors first).
- PregameScreens: `OurLineup.swift`, `PregameBuilder.swift`, `PregameInput.swift` (`UsualRole` and `usualRoles` removed; the first lineup reads `Player`), `PregameSamples.swift`.
- PlayEntry: `PlayEntry.swift`, `PlayEntryModel.swift` (fixed runners and re-suggestion).
- GameChanges: `GameOverSheet.swift`, `GameMenuSheet.swift` (visitors first).
- GameOverview: `OverviewWording.swift` (reads the play log’s inning break, out base and stolen base); `Tests/GameOverviewTests/MoreLogsTests.swift` (two suites run on the main thread, which clears the build warnings).
- PostgameScreens: `PostgameWording.swift`, `StatColumns.swift`, `SeasonStatsScreen.swift` (the record comes from the totals, so its `games:` input is gone), `PlayerSeasonScreen.swift`, `GamesListScreen.swift`, `PreviewSeason.swift`, `Previews.swift`.
- BoxScorePicture: `BoxScorePicture.swift` (pinch-hitter footnotes).

## Tests

- `swift test` in `app/Packages/ScorebookCore`: every test passes, including the new `ScoringTests`: the sample game and the three Major League games scored event by event through a `GameSession` give their box scores; half a game saved to files, the storage reopened and the rest scored; undo and redo with labels; the automatic out and its undo; the dropped third strike; a failed save; “Later” on the defense check.
- `xcodebuild test -scheme ScorebookUI-Package` in `app/Packages/ScorebookUI`: every test passes.
- `xcodebuild test -project app/Scorebook.xcodeproj -scheme Scorebook` (the new `ScorebookUITests` target, on the iPhone 17 simulator): see the walkthrough below.

## Simulator walkthrough

## Not done or not checked

- On the phone itself: saving time late in a long game, the picture’s sharpness in a text message, songs with the silent switch on and the screen locked. These belong to the dress rehearsal.
