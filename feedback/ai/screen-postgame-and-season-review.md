# Review: postgame and season screens

**Reviewer:** a fresh Claude session that did not build these screens.

**Verdict:** Accept after one small fix (finding 1). The numbers are right, the work stays in its own folders, and the other findings are minor.

## What was checked

- `git diff origin/main...HEAD`: only `Sources/PostgameScreens/`, `Tests/PostgameScreensTests/` and the handoff (with its pictures) changed.
- `screen-teams-and-songs` has nothing of this job left in it. Its postgame folders match its last commit, and its unsaved changes are all its own TeamScreens files and pictures.
- `xcodebuild test` for ScorebookUI on the iPhone 17 simulator: all 22 postgame tests pass, and the build gives no warnings.
- A throwaway app on my own iPhone 17e simulator, which was deleted afterwards. It showed a made-up season with two tied .333 hitters, a .889 hitter one plate appearance under the minimum, a hitter with walks and no at-bats, and a player with nothing. Every order was right. Ties kept roster order, players with no average went last, and hitters under the minimum sank below the rest.
- Averages print as “.333”, “1.000” and “—”. Innings sort by outs and print “58.1”. The screens only sort and filter, except for finding 2.

## Findings, worst first

1. **EndOfGameScreen.swift:79 (the share slot).** The handoff’s wiring example puts in `BoxScoreShareLink(box)` as it is. On the 17e, that shows a small blue text link where the mockup has a big blue button. **Fix:** in the screen, apply `.buttonStyle(TeamButtonStyle(.ours))` to `shareButton`, so the wiring job cannot get this wrong.
2. **PostgameWording.swift:55–63 and 97–106.** Win, loss, tie and the season record are worked out in the screen by comparing scores, which the architecture says screens never do. The record (from the games list) can also disagree with the “14 games” count (from the season totals). **Fix:** add a vocabulary change request for a result on `GameSummary`, or a win–loss–tie record on `SeasonTotals`.
3. **StatsTable.swift:116.** The table starts sorted by AVG, but on the 17e the AVG column starts scrolled out of view. The rows appear reordered with no visible reason. **Fix:** start the table scrolled so the sorted column shows.
4. **SeasonStatsScreen.swift:40.** The minimum plate appearances menu is a sensible change, but the choice goes back to 10 each time the screen opens. Early in the season, every visit shows only dashes. **Fix:** have the app shell remember the choice and pass it in, and say so in the handoff.
5. **StatColumns.swift:271.** Pitchers have no minimum, so a pitcher with one out shows WHIP 0.00 and tops a WHIP sort. **Fix:** add a minimum number of outs, or note it as known.
6. **StatsTable.swift:199–200.** Long names shrink to small type and still get cut off, while shorter names wrap at full size. **Fix:** remove `minimumScaleFactor` and let names wrap to two lines.
7. **StatColumns.swift:283.** The comment says the chip reads “Everyone”, but the code shows “Averages for everyone.” **Fix:** correct the comment.

Comments throughout are clear enough for a beginner to follow.
