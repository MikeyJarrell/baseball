# Game overview: fresh review

**Reviewer:** Claude, fresh context (did not build the screen).

**Reviewed:** `git diff origin/main...HEAD` on `codex/screen-game-overview` (commit 8322d68).

**Verdict:** Not ready. A swipe back to the batting screen also opens “Fix a play” for whichever row the finger started on. Fix that and the delete question, then it can go.

## What I ran

- `xcodebuild test -scheme ScorebookUI-Package` on an iPhone 17 simulator made for this review (deleted afterward): every test passes, including all 28 in the game overview’s three suites. The build gave no compiler warnings.
- A throwaway copy of the app outside the repository, showing the game overview fed by the real rules engine and stats, applying each edit it handed back and showing the last action on screen. I tapped and swiped it by hand in the simulator.

What held up by hand:

- Every tap changed the right event. Deleting “Cole stole second” removed that runner move (`e145`), and the single after it then showed its red warning. Changing Webb’s first ball to a called strike replaced `e150`, and the counts after it moved to 0–1 and 0–2. “Change this play” on Quinn’s double play asked for `e153`.
- Half-innings were grouped correctly and listed newest first, including the end of the game and the pitching change between halves.
- “Show every pitch” stayed on after an edit.
- The 400-event list scrolled from the 13th inning to the 1st without a visible hitch.
- Only files inside `Sources/GameOverview`, `Tests/GameOverviewTests` and the handoff changed.

## Findings, worst first

1. **`GameOverview.swift:125-133`: the swipe back also taps a row.** A swipe right from the left edge across the Plays list sent “back to batting” *and* opened “Fix a play” for the row under the finger. I reproduced it twice, once on Moreno’s single and once on Park’s fly out. In the app, the scorer would land on the batting screen with a fix sheet open for a play they never chose, one tap from deleting it. **Fix:** move the drag onto a narrow strip along the left edge (an overlay about 20 points wide with its own `.gesture`), so it never sits on top of the row buttons.

2. **`FixPlaySheet.swift:102-108`: the delete question does not say what will be deleted.** On this iOS version, “Delete this play?” shows as a bubble pointing at the top of the sheet. It covers the list, never names the play, and has no visible “Keep it” button. **Fix:** attach the question to the “Delete it” button, and name the play in it: “Delete ‘Cole stole second’ (Bottom 5th)?”

3. **`FixPlaySheet.swift:113-127`: a pitch’s sheet does not say whose pitch it was.** Fixing a pitch shows only “Ball · Bottom 5th”, so with several balls in one half-inning the scorer cannot check they picked the right one. The list rows have the same gap. **Fix:** add the batter and the count to the pitch row and to the sheet: “Ball to Webb · count 1–0”.

4. **Deleting the pitch that ended a plate appearance.** A row like “Kim struck out swinging” is the strike-three pitch, so “Delete it” removes only that pitch. Kim goes back to the plate with two strikes, and his earlier pitches stay hidden. Changing a pitch also takes effect on one tap, with no question asked. For example, a stray tap on “Hit by pitch” puts the batter on first. **Fix:** in the sheet, say what deleting will do (“Deletes strike three only; Kim is back up with 2 strikes”). Consider asking once before changing a pitch that ended a plate appearance.

5. **`OverviewWording.swift:117-120, 362, 365, 370`: baseball worked out in the screen.** The screen decides “stole home” or “stole second” from whether the runner scored, guesses which base a runner was out at by taking the next base, and decides whether a break is “Middle” or “End” of an inning. **Fix:** ask the rules engine for these as facts (a vocabulary request), as the handoff already does for the running score.

6. **`PlaysTab.swift:164-190`: the “At bat” row at the largest text size.** The row keeps its badge beside the words, so “No pitches yet” wraps onto three lines. **Fix:** stack the badge above the words at the accessibility sizes, as `PlayRowView` already does.

7. **`ScoreTab.swift:37`: team order changes between parts of the screen.** The top bar lists our team first, while the line score and “Left on base” list the visitors first. **Fix:** list our team first in “Left on base”.

8. **`PlaysTab.swift:10, 28-33`: the rows are rebuilt more often than the comment says.** The comment says the rows are built once per play log; they are built again every time the screen above redraws. It is cheap at 400 events. Correct the comment, or keep the rows until the log changes.

9. **Tests.** The play-by-play tests run only on the hand-written sample log; none uses a log the rules engine produced. Nothing tests the swipe-and-tap clash in finding 1. Add a test on an engine-produced log, and a UI test for the edge swipe once a UI test target exists.

The comments are clear and readable for a beginner throughout.

## Re-check

**Reviewed:** the fix commit 8802a3d and the work-in-progress commit before it. Checked by hand in a throwaway copy of the app on a simulator made for this check (deleted afterward). All 37 game overview tests pass.

1. **Swipe back: pass.** Swipes starting 6 and 13 points from the left edge went back to the batting screen and opened nothing. A sideways swipe starting 22 points in, just past the new strip, opened “Fix a play” for that row and did not go back. That is one action, so the scorer is no longer sent away with a sheet open. Treating a sideways drag across a row as a tap is still a small trap.
2. **Delete question: pass.** It hangs off “Delete it” and reads “Delete ‘Cole stole second’ (Bottom 5th)?”, with what deleting does underneath, and both “Delete” and “Keep it” show. “Keep it” kept the play.
3. **Pitch details: pass.** “Ball to Webb · Bottom 5th · to Webb · count 0–0 before it, 1–0 after”. The batter is named twice.
4. **Largest text size: pass.** The “At bat” badge now sits above the words. The fix sheet still puts its summary in a narrow column beside the chip, but it reads.

**Elsewhere in the diff:** every team now lists the visitors first, the top bar included (“Mudcats 3, Diamond Dogs 5”). The mockup and the earlier handoff put our team first. Only the game overview’s own folders, its handoff and this file changed.
