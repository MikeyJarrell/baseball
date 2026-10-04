# Pregame screens: review

**Reviewer:** a fresh builder who did not build the pregame screens.

**Reviewed:** `git diff origin/main...HEAD` on `codex/screen-pregame`, against the brief, the handoff, the approved mockup and `notes/league-rules.md`.

**Verdict:** Not ready yet. Two things to fix first: a shared position can quietly leave a position with nobody on it in even innings, and the batting order can’t be read at the largest text size. Everything else in the setup handed back checked out.

## What was checked

- `xcodebuild test -scheme ScorebookUI-Package` on the iPhone 17 simulator: the build succeeded with no compiler warnings, and all 33 pregame tests pass.
- Throwaway checks run outside the repository, in a copy with its own simulator (since deleted) and its own bundle id:
  - We bat first when away.
  - The time limit, an edited clock time, carries into the setup correctly after the start is moved.
  - Three non-runners are kept after a drag.
  - Nobody is both on the bench and in the batting order.
  - All nine fielders are handed back.
  - An unknown lineup gets nine “Batter” placeholders, and a “Pitcher” placeholder starts.
- The under-a-minute claim holds. A UI test tapped Mudcats, Next four times and Play ball, starting from last game’s lineup: 6 taps, 11.5 seconds, on both runs.
- Nothing outside `Sources/PregameScreens`, `Tests/PregameScreensTests` and the handoff changed.
- The comments are plain and easy for a beginner to follow.

## Findings, worst first

1. **A fielder goes missing in even innings.** `OurLineupStep.swift:228-236`, `OurLineup.swift:156-159`, `PitchersStep.swift:31`.

   - **Problem:** The “Takes turns by inning” chips list everyone, and nothing stops a choice that overlaps another position. Each of these cases was run through `GameTeam.defense(forInning: 2, …)` and handed back only 8 fielders, with no note on the review step:
     - Ford, who starts in left field, picked to play first base in even innings: left field is empty in even innings.
     - Nash picked for even innings at two different positions: one of them is empty.
     - Nash, who takes first base in even innings, picked as our starting pitcher on the pitchers step: nobody pitches in even innings.

     A real flip-flop still works (Ford in left in odd innings and first in even, Quinn the reverse).
   - **Fix:** In `setAlternate`, clear the player’s other even-inning turns. Add a review note when any inning’s defense is short (check innings 1 and 2 with `defense(forInning:)`). On the chips, show where each player starts (“Ford lf”).

2. **Our batting order can’t be read at the largest text size.** `OurLineupStep.swift:101-133`.

   - **Problem:** Names break into pieces a few letters long (“Ale / x / Mo / ren / o”), and the Runs chip reads “R / un / s”. The header splits into “BAT-” and “Non-”. The handoff’s `ours-big.png` shows only the info box, so this was missed.
   - **Fix:** At accessibility text sizes, put the name on its own line and the chip and minus button below it, the way `ReviewStep` stacks its two cards. Put the header on two lines.

3. **A hitter who doesn’t field is labeled “bench” on the fielder chips.** `OurLineupStep.swift:145-148, 210`.

   - **Problem:** Cole bats but doesn’t field, and his chip reads “bench”. The mockup shows nothing after the name.
   - **Fix:** Show “bench” only for players who are actually on the bench.

4. **The time limit the scorer sets as a clock time is saved as a length of time.** `GameStep.swift:76-79, 95`.

   - **Problem:** If the scorer sets 12:10 for a 9:00 start, the setup saves “3 hours 10 minutes”. A first pitch at 9:20 then makes the limit 12:30. That follows rule 9.1 G and the `Model`, but the screen shows a clock time and the footer doesn’t say this.
   - **Fix:** Add one sentence to the footer explaining it.

5. **Should `Player` get usual position and usual role? Yes.** `PregameInput.swift:80-96`.

   - `plan/architecture.md` and the teams brief already call for both fields on `Player`.
   - **Fix:** Add both as optional fields in the next vocabulary pass, and file the request in `notes/vocabulary-requests.md`. Add “fields but doesn’t bat” (for a pitcher who doesn’t hit) to the usual role.
