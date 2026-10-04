# Postgame and season screens: handoff

**Job:** screen builder, postgame and season screens.

**Branch:** `codex/screen-postgame-and-season`, in the task folder `/Users/mikey/projects/.worktrees/baseball/screen-postgame-and-season`.

## What exists now

Everything is in `app/Packages/ScorebookUI/Sources/PostgameScreens/`, with tests in `app/Packages/ScorebookUI/Tests/PostgameScreensTests/` (the placeholder there is replaced). The screens import only Model, SampleData and DesignSystem. Every tap that leaves a screen comes back as a `PostgameRequest`: `done`, `shareBoxScore(GameID)`, `copyBoxScoreText(GameID)`, `openSeasonStats`, `openGame(GameID)`, `openPlayer(PlayerID)`, `setMinimumPlateAppearances(Int)`, `setMinimumInnings(Int)`.

- **End of game** (`EndOfGameScreen`), as in the mockup: Done, the title “Final”, visitors’ runs, FINAL, home runs with our logo over our team, then “Win: Sky Barros · Loss: Gus Reyes · 3 hr 12 min” from the box score’s decisions and game length. Below that, the box score, the big “Text the box score picture” button, and “Copy as text” and “Season stats”. Whatever goes in the share slot gets the big blue button style from the screen. The same screen opens any game from the games list with `showsDoneButton: false`; a box score that is not final is titled “Box score” and says IN PROGRESS. At the largest text sizes the two teams stack one above the other.
- **The box score as a plain table** (`BoxScoreTable`, public), shown until wiring: the line score with R H E (an “x” where the home team did not bat), each team’s batting lines (name, positions as the newspaper prints them, AB R H RBI BB K, substitutes indented, a totals row), pitchers (W or L, IP H R BB K, pitches-strikes), and the notes one per line (E, DP, TP, LOB, 2B, 3B, HR, SB, CS, S, SF, HBP with the pitcher, and “Jordan Webb ran for Pat Quinn in the 3rd.”). Each table scrolls sideways only when it does not fit (extra innings, largest text).
- **Games list** (`GamesListScreen`): newest first, “vs Mudcats” or “at Mudcats”, the date, and “W 7–5” in green, “L 3–5” in red, “T 4–4”, or “In progress”. Tapping a game hands back `openGame`. It takes a count of saved games that could not be read and says so under the list.
- **Season stats** (`SeasonStatsScreen`), as in the mockup: “Season”, “Diamond Dogs · 14 games · 9 wins, 4 losses, 1 tie”, a Batting / Pitching switch, and the table. Names stay pinned on the left while the numbers scroll sideways, and the headings stay pinned along the top while the rows scroll. A short table ends after its last row. Batting columns: G PA AB R H 2B 3B HR RBI BB K AVG OBP SLG. Pitching: G IP BF H R BB K HR HBP P WHIP K/IP BB/IP. Tapping a heading sorts by it, biggest first (lowest first for WHIP and BB/IP); tapping again flips it. The table opens scrolled sideways so the sorted column shows (AVG for batting, IP for pitching). Long names wrap to a second line at full size. Tapping a player hands back `openPlayer`.
- **The averages filter:** the mockup’s chip, “At least 10 plate appearances”, with “for averages” beside it. Hitters below the minimum show a gray dash for AVG, OBP and SLG and sink to the bottom when sorting by an average. One change from the mockup: the chip opens a short menu of minimums (everyone, 5, 10, 20, 30). In the mockup it only switches on and off, and in the first games of a season a fixed 10 would hide every average. The starting minimum is a parameter (10 by default). Each new choice comes back as `setMinimumPlateAppearances`, for the app to keep and pass in next time.
- **The pitchers’ filter:** the same kind of chip on the pitching table, “At least 3 innings” with “for rates” beside it (everyone, 1, 3, 5, 10, 20). Pitchers below it show a gray dash for WHIP, K/IP and BB/IP and sink to the bottom when sorting by one, so a reliever with one out and nobody on no longer tops the WHIP column. The starting value is `minimumInnings` (3 by default); each new choice comes back as `setMinimumInnings`.
- **Player page** (`PlayerSeasonScreen`), which the mockup does not have, drawn in its style: number badge and name, then AVG, OBP and SLG in big type over every batting count, then a game-by-game table (date and opponent pinned, AB R H 2B 3B HR RBI BB K), newest game first, each row handing back `openGame`. A pitcher also gets IP, WHIP and K/IP in big type, every pitching count, and a pitching game log; anyone with a fielding line gets putouts, assists and errors. A player with no at-bats shows dashes for the averages, and “No games yet.” when they never played.

The screens only sort and filter what they are handed. Two small things are read straight from the data handed in (see vocabulary request 3): whether a finished game was a win, loss or tie (comparing our runs with theirs in the games list’s final score), and the season record, which counts those. Both are in `PostgameWording`.

## For the wiring job

- **Fill the end-of-game screen’s two slots** with the box score printer’s picture and share button:

  ```swift
  EndOfGameScreen(box: box, ourSide: setup.ourSide, onRequest: handle) {
      BoxScorePicture(box)
  } shareButton: {
      BoxScoreShareLink(box)
  }
  ```

  A picture handed in sits on a gray mat and is shrunk evenly to fit the screen’s width (the picture is 375 points wide). This was checked in the harness with the real `BoxScorePicture` and `BoxScoreShareLink`: [final-picture-slot.png](screen-postgame-and-season/final-picture-slot.png).
- `copyBoxScoreText` is `BoxScorePrinter.text(box)` onto the clipboard.
- **Which team is ours** is not in `BoxScore`, so the end-of-game screen takes `ourSide`; pass `setup.ourSide`.
- **The season record** needs the games list: pass `games:` to `SeasonStatsScreen`; without it no record shows.
- **Remember the two minimums.** Keep the last `setMinimumPlateAppearances` and `setMinimumInnings` values (in app settings, say) and pass them back as `minimumPlateAppearances:` and `minimumInnings:`. Without that, the filters go back to 10 plate appearances and 3 innings each time the screen opens.
- Each screen sets its own navigation title and expects to be inside a `NavigationStack`.

## Vocabulary change requests

1. **Wins and losses in season totals.** The mockup’s pitching table has W-L, and the season totals carry no decisions: `SeasonPitchingLine` has no win or loss count and `GameLogEntry` has no decision. Request: `wins` and `losses` on `SeasonPitchingLine`, or a `decision` on each pitching game log entry. Workaround: the column is left out.
2. **Earned runs.** The mockup shows ER and ERA; the app keeps no earned runs, so they are left out, as the box score printer did. WHIP, K/IP and BB/IP (Model’s per-inning rates) stand in.
3. **Each game’s result for us, and the season record, from the stats engine.** The screens work these out themselves for now, which the architecture says screens never do (review finding 2): they compare our runs with theirs in the games list, and the record can disagree with the season totals’ game count. The stats engine should supply, exactly: on `GameSummary`, `result: GameResult?` (win, loss or tie for our team; missing until the game is final); on `SeasonTotals`, `wins`, `losses` and `ties` (the record over the same games as `games`). Then `PostgameWording.outcome(of:)` and `record(_:)` read those values and stop comparing scores. Workaround until then: the screens compare the scores.
4. **Remembered filter minimums in `AppSettings`** (optional): `minimumPlateAppearances` and `minimumInnings`, so the wiring has somewhere to keep them.
5. **Home or away and the result in a game log entry.** `GameLogEntry` has the opponent’s name but not whether we were home, nor the score, so a player’s log says “May 16 Mudcats”; with both it could say “at Mudcats, W 7–5”. Optional.

## Tests

`PostgameScreensTests`, 27 tests, all passing: sorting by batting average with ties kept in roster order and hitters with no average last in both directions (worked out by hand from the sample box score); the filter hiding every average in a one-game season and sinking Robin Nash’s 1-for-2 below everyone in the fourteen-game preview season; the filter’s edge (exactly 10 plate appearances shows); counting columns untouched by the filter; averages printed “1.000”, “.000” and “—”; innings sorted by outs and printed “58.1”; a pitcher with no outs printing a dash and sorting last; the pitchers’ minimum (one out and nobody on tops WHIP with no minimum and sinks at 3 innings, either direction; exactly 1 inning is 3 outs; innings sorting untouched; the chips’ words); what a tap on a heading does; win, loss and tie read from our side of the score home and away; the record (“9 wins, 4 losses, 1 tie”, “1 win, 0 losses”) leaving out a game still going; newest-first order for games and game logs; the game length (“3 hr 12 min” for the sample game’s 11,552 seconds); and the box score notes, positions and ordinals.

The tests found one trap worth passing on: a `static func` on a SwiftUI view runs on the main thread only, and calling it from a test crashes the test runner. Ordering helpers live in `StatSorting` instead.

## Not finished or not checked

- **Previews** in `Previews.swift`, from `SampleSeason.totals` (the twelve-player team and the one-game season), Robin Nash (did not play) and Taylor Voss (only pitched, no at-bats), plus `PreviewSeason`, a hand-typed fourteen-game season and games list, so bigger numbers and sorting can be seen. Light, dark and the largest accessibility text size for each screen. The previews were not opened one by one in Xcode’s canvas; the same screens were checked in the simulator.
- At the largest text sizes the season screen’s words stop growing at the second accessibility size and the player page’s at the third, so the tables keep room for rows. The season table then shows about two rows at a time, scrolling.
- VoiceOver: each table row reads as one button (“Alex Moreno: games 14, plate appearances 62, … batting average .365”), each heading as “Sort by batting average”, and the final score as one sentence. Checked by reading the code; nobody has tried it with VoiceOver on.
- The harness did not record which request each tap handed back; the requests are one-line closures.
- `PROJECT_INDEX.md` is outside this job’s folders.

## Evidence

- `xcodebuild -scheme ScorebookUI-Package -destination 'platform=iOS Simulator,name=iPhone 17' build` in `app/Packages/ScorebookUI`: succeeded with no warnings.
- `xcodebuild … test`: every test passes, including the other modules’ and the screen-import test.
- Checked on an iPhone 17e simulator (390 by 844 points, the smallest current iPhone) made for this job and deleted afterwards, through a throwaway harness app outside the repository (bundle id `com.mikeyjarrell.postgame-season-harness`). In the first round, swiping the season table sideways kept the names and the headings in place, and tapping K sorted by strikeouts. After the review fixes, the season table opens with AVG in view ([season-fourteen.png](screen-postgame-and-season/season-fourteen.png)), a long name wraps ([season-long-name.png](screen-postgame-and-season/season-long-name.png)), and the real `BoxScoreShareLink` in the slot shows as the big blue button ([final-share-button.png](screen-postgame-and-season/final-share-button.png)). The pitchers’ filter was checked by its tests only: the second simulator was not cleared for taps, so the pitching table has no new screenshot. The rest, in [screen-postgame-and-season/](screen-postgame-and-season/): `final`, `final-dark`, `final-largest-text`, `final-picture-slot`, `box-so-far`, `games`, `games-dark`, `games-largest-text`, `season-fourteen`, `season-dark`, `season-largest-text`, `season-one-game` (filter set to everyone), `season-one-game-filter` (every average hidden), `player`, `player-dark`, `player-largest-text`, `player-no-at-bats`, `pitcher-no-at-bats`.

## Review

A fresh reviewer’s notes are in `feedback/ai/screen-postgame-and-season-review.md` (seven findings, no wrong numbers). Findings 1 and 3 to 7 are fixed: the share slot’s button style, opening at the sorted column, the remembered minimum, a minimum for pitchers, wrapping names, and the chip comment. Finding 2 is vocabulary request 3.
