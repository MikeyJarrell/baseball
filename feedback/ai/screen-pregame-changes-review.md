# Pregame screens, Mikey’s changes: review

**Reviewer:** a fresh builder who did not build these changes.

**Reviewed:** `git diff origin/main...HEAD` on `codex/screen-pregame` (one commit, “Pregame changes from Mikey’s phone”), against the brief, the handoff, the wiring handoff and the earlier review in `screen-pregame-review.md`.

**Verdict:** Ready once their lineup is fixed at the largest text size; the game that starts is exactly what was set up, and nothing the earlier review fixed has come back.

## What was checked

- `xcodebuild test -scheme ScorebookUI-Package` on a simulator of my own: every test passes, 41 of them pregame, with no compiler warnings. The app builds.
- In a throwaway copy outside the repository, UI tests drove the full app from the home screen’s New game tile, on a simulator of my own (since deleted):
  - The start wheel was turned to 1:03 PM, and the limit followed to 4:03 PM.
  - Three hitters were taken out of the batting order, and Barros was dragged from ninth to leadoff.
  - All nine positions were filled by tapping the diamond, Voss pitching without batting, and Nash alternating at first base.
  - 23 was typed for Marcus Hale, and Mudcats rows were dragged by the name, the number box and the grip, before and after typing. All three ways move the row.
  - Play ball. The saved game file has a 1:03 PM start, a 180-minute limit, our batting order with Barros first and Voss pitching, Quinn and Nash taking turns at first base, and Hale at 23. The Mudcats’ saved roster now has Hale at 23. The defense check opened with all nine fielders.
- The earlier fixes still hold:
  - Ford, who plays left field, picked to take first base in even innings: the review step says “Nobody plays left field in even innings.” Picking Nash for even innings at a second position ends his first turn.
  - Our batting order reads well at the largest text size.
  - The player list says “Bench” only for players who neither bat nor field, and “DH · bats 1st” for a hitter who doesn’t field.
- “The app records whatever you decide.”, the “Starting from the roster…” paragraph, “Bats only” and “Unknown” are all gone from pregame.

## Findings, worst first

1. **Their lineup can’t be read at the largest text size.** `TheirLineupStep.swift:61-71, 81-105, 151-170`.
   - **Problem:** The number box is a fixed 76 points wide. With it, the order number and the grip, the name is left a sliver, so it breaks into pieces a few letters long (“Lui / s / Or- / tiz”). This is the same problem the earlier review found in our batting order. It was missed because `Previews.swift` has no their-lineup preview at the largest text size.
   - **Fix:** At accessibility text sizes, put the name on its own line, with the number box and minus button under it, the way `BattingOrderStep` now does. Add a “4. Mudcats, largest text” preview.
2. **The time limit wraps to “12:00 P / M” at the largest text size.** `GameStep.swift:116-135`.
   - **Fix:** At accessibility sizes, stack the label above the time, or give the time `.fixedSize()` and let the label wrap instead.
3. **The keyboard’s Done button sits on top of the right end of the “Next: starting pitchers” button while a number is being typed.** `TheirLineupStep.swift:46-48`.
   - **Problem:** A slightly low tap on Done moves to the next step. Nothing is lost, but it is confusing.
   - **Fix:** Hide the pinned button while a number box is being typed in, so Done stands alone above the keyboard.
