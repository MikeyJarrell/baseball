# Game overview: handoff

**Job:** screen builder, the game overview.

**Branch:** `codex/screen-game-overview`, in the task folder `/Users/mikey/projects/.worktrees/baseball/screen-game-overview`. `origin/main` was merged in (for the `GameOverviewTests` target, and again after the review fixes).

**Owns:** `app/Packages/ScorebookUI/Sources/GameOverview/` and `app/Packages/ScorebookUI/Tests/GameOverviewTests/`. Nothing else changed except this note and its screenshots.

## What exists now

The approved mockup’s `SCREENS.overview`: a top bar with “‹ At bat” and the score (“Mudcats 2, Diamond Dogs 3 / Top 4th · live”, or “Final”), then four tabs.

- **Score.** The line score by inning with R H E, visitors on top, the inning being played in amber. Then “Right now” (“Top 4th, 0 outs, nobody on / Sam Kim batting, count 1–1”, or “End 3rd / Sam Kim leads off the top 4th” between half-innings), runners left on base, and the box score notes so far (“2B: Webb, Cole”, “DP: Diamond Dogs 2”).
- **Box.** Visitors first. Each batter: number badge, name, “2 for 3 · 1 run · 1 RBI · cf”, and today’s plate appearances as notation chips, hits in green. Substitutes are indented under the player they replaced. Anyone who fielded without batting is listed under the team.
- **Pitchers.** Every pitcher, visitors first, in the order they pitched: throwing hand, W or L once the game is final, “pitching now” for the one on the mound, then IP (“2⅓”, the newspaper’s style), P-S, BF, H, R, BB, K.
- **Plays.** Every event, newest first, grouped by half-inning under pinned headings (“▼ 3rd · 6 events”). Each row has the notation chip, the event in words (“Webb was caught stealing second”), and what it led to (“Moreno scored · Mudcats 0, Diamond Dogs 1”, “3 outs”). A pitch in the middle of a plate appearance names its batter (“Ball to Webb”). The batter at the plate is a highlighted “At bat” row at the top (“Kim / Ball, foul · count 1–1”); at the largest text sizes its badge sits above the words. A row the rules engine flagged for review shows its warning in red. Pitches in the middle of a plate appearance are hidden until the scorer switches on “Show every pitch”; the pitch that ends a plate appearance always shows.
- **Fix a play** (`SHEETS.playedit`), opened by tapping any row. A plain pitch gets a button for every other kind of pitch (“It was really: Foul”), which hands back the corrected event right away. Anything with more to it offers “Change this play”, which asks the app to open that event’s own steps filled in. A pitch’s sheet names the batter and the count before it (“to Ford · count 1–2 before it”), and the sheet lists the earlier pitches of that plate appearance. “Delete it” says what deleting does (“Deletes strike three only. Ford is back at the plate with the count at 1–2; the pitches before it stay”). Its question hangs off the Delete button, names the play and half-inning (“Delete “Cole stole second” (Bottom 5th)?”), and has a visible “Keep it” button. Fielder checks, intentional walks, automatic outs, keep-playing answers and the end of the game can only be deleted.
- A swipe to the right on a 16-point strip along the left edge goes back to the batting screen, as do “At bat” and a VoiceOver action. Rows start 24 points in, so the swipe can no longer also open “Fix a play” for the row under the finger (the review’s top finding).
- **Team order** is the visitors first, home second, everywhere: the top bar, the line score, left on base, the Box tab, the pitchers and the score after each play.

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

The screen uses the play log’s own notation for every chip, and the play log’s out base (`OutMade.at`) for where a runner was put out. Four things it still works out itself, each a small fact the rules engine already knows, for the lead builder’s list:

1. **The score after each event** on `PlayLogEntry` (for example `scoreAfter: Score`). Today the play-by-play adds up `runs` and `adjustedRuns` itself.
2. **The base a stolen base was of** (“stole home”, “stole third”), for example `RunnerMove.stolenBase: Base?` or a word on the play log entry. Today the screen takes the base after the runner’s starting base, since a stolen base is always one base.
3. **The base a runner was caught stealing or put out at** when neither the event (`outAt`) nor the play log (`OutMade.at`) records it. Today the screen falls back to the next base.
4. **Which break between half-innings it is** (“Middle 5th”, “End 5th”), for example `Situation.breakLabel` or the half-inning just finished. Today the screen reads it from the half-inning the situation has already moved to.

## Tests

`xcodebuild test -scheme ScorebookUI-Package -destination 'platform=iOS Simulator,name=iPhone 17'` in `app/Packages/ScorebookUI`: every test passes, 37 of them in `GameOverviewTests`.

- `PlayByPlayTests`: every event listed exactly once; newest half-inning and newest event first, ten half-innings, the end of the game the newest row; hiding pitches keeps every plate appearance; the score after the last run equals the box score (Mudcats 3, Diamond Dogs 5) and after three innings (3–2); Webb’s double scores Moreno; outs on the rows that made them; events in words (home run, double play lined into, strikeout swinging, walk, sacrifice bunt, runner for a non-runner, caught stealing); steals, wild pitches and pickoffs in words; the batter at the plate with their pitches; nobody at the plate between half-innings or at the end; a flagged event keeps its warning and is never hidden; 400 events build in well under a quarter of a second.
- `FixPlayTests`: a pitch can become any other pitch and keeps its id and time; a dropped third strike and a ball in play go to their own steps; an intentional walk or fielder check can only be deleted.
- `OverviewWordingTests`: ordinals, innings pitched, runners on base, “Right now” at the end of the 3rd and mid-at-bat, batting summaries (Ortiz, Moss as a pinch hitter, Reyes who never batted), visitors first in the score, hits in green.
- `MoreLogsTests`: the rules engine’s own play log for the sample game (every event once, newest first, ten half-innings, the score matching the box score); hand-written short logs for a half-inning visited twice after a manual adjustment, the end of the game after the sides switch, and an empty game; a pitch naming its batter and counts; deleting strike three (only strike three goes, the earlier pitches listed, the next batter’s list empty); the delete question naming the play and half-inning; caught stealing using the play log’s base; the rows built again only for a new play log.
- `BackSwipeTests`: the swipe strip is narrower than the rows’ inset, and only a long, mostly sideways swipe to the right counts.

## Evidence

- `xcodebuild … build`: succeeded with no warnings.
- **Previews** in `Previews.swift`: the complete game on every tab, the third inning, a batter at the plate in the 4th, 400 events, dark mode, the largest accessibility text size on every tab, and the fix sheet for a pitch, a ball in play and a runner move.
- **Screenshots** from a throwaway harness app outside the repository, on an iPhone 17 simulator created for this job and deleted afterward, in [screen-game-overview/](screen-game-overview/): `complete-score`, `complete-box`, `complete-pitchers`, `complete-plays`, `third-score`, `third-box`, `fourth-plays` (the “At bat” row), `long-plays` (400 events, the 13th inning at the top), `complete-box-dark`, `fourth-score-dark`, the four `largest-` tabs, `fix-pitch`, `fix-play` and `fix-strikeout` (the earlier pitches and what deleting does).
- Found and fixed by looking: the line score’s E column running off the screen, misaligned table lines, a row with no chip pushing its words to the middle, the back button overlapping the score and chips overlapping words at the largest text size.

## Review

A fresh reviewer’s notes are in `feedback/ai/screen-game-overview-review.md`. They hand-tested it: rows map to the right plays and 400 events scroll smoothly. Findings 1 to 4 and 6 to 9 are fixed. For finding 5 (baseball worked out on screen), the screen now uses the play log’s notation and out bases, and the four things it still works out are the vocabulary requests above.

## Not checked

- Access to tap in this builder’s simulator was not granted, so the fixes were checked by tests and screenshots, not by hand. **Manual check for the swipe:** on the Plays tab, start a finger at the very left edge on top of a row and swipe right. The batting screen should come back and no “Fix a play” sheet should open. Then tap the same row a finger’s width in from the edge: “Fix a play” should open for it. Also tap “Delete it” and check the question appears by the button with both “Delete” and “Keep it”.
