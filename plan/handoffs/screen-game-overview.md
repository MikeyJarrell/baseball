# Game overview: handoff

**Job:** screen builder, the game overview.

**Branch:** `codex/screen-game-overview`, in the task folder `/Users/mikey/projects/.worktrees/baseball/screen-game-overview`. `origin/main` was merged in for the new `GameOverviewTests` target.

**Owns:** `app/Packages/ScorebookUI/Sources/GameOverview/` and `app/Packages/ScorebookUI/Tests/GameOverviewTests/`. Nothing else changed except this note and its screenshots.

## What exists now

The approved mockup’s `SCREENS.overview`: a top bar with “‹ At bat” and the score (“Diamond Dogs 3, Mudcats 2 / Top 4th · live”, or “Final”), then four tabs.

- **Score.** The line score by inning with R H E, visitors on top, the inning being played in amber. Then “Right now” (“Top 4th, 0 outs, nobody on / Sam Kim batting, count 1–1”, or “End 3rd / Sam Kim leads off the top 4th” between half-innings), runners left on base, and the box score notes so far (“2B: Webb, Cole”, “DP: Diamond Dogs 2”).
- **Box.** Our team first, as in the mockup. Each batter: number badge, name, “2 for 3 · 1 run · 1 RBI · cf”, and today’s plate appearances as notation chips, hits in green. Substitutes are indented under the player they replaced. Anyone who fielded without batting is listed under the team.
- **Pitchers.** Every pitcher, visitors first, in the order they pitched: throwing hand, W or L once the game is final, “pitching now” for the one on the mound, then IP (“2⅓”, the newspaper’s style), P-S, BF, H, R, BB, K.
- **Plays.** Every event, newest first, grouped by half-inning under pinned headings (“▼ 3rd · 6 events”). Each row has the notation chip, the event in words (“Webb was caught stealing second”), and what it led to (“Moreno scored · Diamond Dogs 1, Mudcats 0”, “3 outs”). The batter at the plate is a highlighted “At bat” row at the top (“Kim / Ball, foul · count 1–1”). A row the rules engine flagged for review shows its warning in red. Pitches in the middle of a plate appearance are hidden until the scorer switches on “Show every pitch”; the pitch that ends a plate appearance always shows.
- **Fix a play** (`SHEETS.playedit`), opened by tapping any row. A plain pitch gets a button for every other kind of pitch (“It was really: Foul”), which hands back the corrected event right away. Anything with more to it offers “Change this play”, which asks the app to open that event’s own steps filled in. Everything can be deleted, after one “Delete this play?” question. Fielder checks, intentional walks, automatic outs, keep-playing answers and the end of the game can only be deleted.
- A swipe to the right starting at the left edge goes back to the batting screen, as does “At bat” and a VoiceOver action.

## How the screen talks to the rest

```swift
GameOverview(
    log: PlayLog,                                          // rules engine: replay(game).log
    boxScore: BoxScore,                                    // stats: boxScore(for: log)
    plateAppearances: [PlayerID: [PlateAppearanceSummary]],// stats: plateAppearances(of:in:) for each batter
    situation: Situation?,                                 // rules engine; nil is fine for a finished game
    startingTab: GameOverviewTab = .score,
    onAction: (GameOverviewAction) -> Void
)
```

`GameOverviewAction`:

- `.backToBatting`
- `.edit(EventEdit)`: `.delete(id)` or `.replace(event)` (a pitch changed to another kind of pitch, same id and time). Apply it to the game’s events, replay, and hand the screen the new log, box score and plate appearances.
- `.openEditor(GameEvent)`: open that event’s own steps filled in. A ball in play goes to the in-play steps; a strike-three pitch carrying a dropped third strike to its steps; a runner action to the runner moves; a substitution, runner for a non-runner, pitching change or added hitter to its change sheet; a time limit change or manual adjustment to its sheet. Whatever the scorer saves there should come back as `.replace` with the same event id.

The screen computes nothing about baseball. Its only arithmetic is adding up the runs the play log lists, to show the score after each scoring play; a test checks that this matches the box score’s runs.

## For the wiring job

- The screen draws its own top bar. Present it without wrapping it in a second navigation stack (a full-screen cover, or a page beside the batting screen); the sheet brings its own.
- `FixPlaySheet(row:onAction:)` and `PlayByPlay.rows(for:)` are public, so “Fix a play” can also be opened for a play shown elsewhere.
- `GameOverviewSamples` (`completeGame`, `thirdInning`, `fourthInning()`, `longLog(events:)`) and `GameOverview.Inputs` are public for previews and harnesses.
- “Insert a forgotten event” (`EventEdit.insert`) is not offered; the brief asks only for change and delete.

## Choices that differ from the mockup

- **The line score uses short team names** (“MUD”, “DOGS”), so nine innings and R H E fit across the screen. The full names are in the top bar and the Box tab. At large text or in extra innings the table scrolls sideways, starting on the inning being played.
- **No ER column.** The box score keeps no earned runs (the printer left it out too).
- **Pitches are hidden by default** behind “Show every pitch”, so a 300-pitch game stays readable and any single pitch can still be fixed.
- **Delete asks once** before handing back the delete, since nothing on this screen can undo it.

## Vocabulary requests

None needed. One for later: if the rules engine put the score after each event on `PlayLogEntry`, the play-by-play would not need to add up runs itself.

## Tests

`xcodebuild test -scheme ScorebookUI-Package -destination 'platform=iOS Simulator,name=iPhone 17'` in `app/Packages/ScorebookUI`: every test passes, 26 of them in `GameOverviewTests`.

- `PlayByPlayTests`: every event listed exactly once; newest half-inning and newest event first, ten half-innings, the end of the game the newest row; hiding pitches keeps every plate appearance; the score after the last run equals the box score (Diamond Dogs 5, Mudcats 3) and after three innings (3–2); Webb’s double scores Moreno; outs on the rows that made them; events in words (home run, double play lined into, strikeout swinging, walk, sacrifice bunt, runner for a non-runner, caught stealing); steals, wild pitches and pickoffs in words; the batter at the plate with their pitches; nobody at the plate between half-innings or at the end; a flagged event keeps its warning and is never hidden; 400 events build in well under a quarter of a second.
- `FixPlayTests`: a pitch can become any other pitch and keeps its id and time; a dropped third strike and a ball in play go to their own steps; an intentional walk or fielder check can only be deleted.
- `OverviewWordingTests`: ordinals, innings pitched, runners on base, “Right now” at the end of the 3rd and mid-at-bat, batting summaries (Ortiz, Moss as a pinch hitter, Reyes who never batted), our team first in the score, hits in green.

## Evidence

- `xcodebuild … build`: succeeded with no warnings.
- **Previews** in `Previews.swift`: the complete game on every tab, the third inning, a batter at the plate in the 4th, 400 events, dark mode, the largest accessibility text size on every tab, and the fix sheet for a pitch, a ball in play and a runner move.
- **Screenshots** from a throwaway harness app outside the repository, on an iPhone 17 simulator created for this job and deleted afterward, in [screen-game-overview/](screen-game-overview/): `complete-score`, `complete-box`, `complete-pitchers`, `complete-plays`, `third-score`, `third-box`, `fourth-plays` (the “At bat” row), `long-plays` (400 events, the 13th inning at the top), `complete-box-dark`, `fourth-score-dark`, the four `largest-` tabs, `fix-pitch` and `fix-play`.
- Found and fixed by looking: the line score’s E column running off the screen, misaligned table lines, a row with no chip pushing its words to the middle, the back button overlapping the score and chips overlapping words at the largest text size.

## Not checked

- Access to tap in the simulator was not granted. The harness opened the fix sheet directly, and the 400-event list was checked by its build time and screenshots. Tapping a row and scrolling the long list by hand are left for the dress rehearsal.
- No fresh review yet.
