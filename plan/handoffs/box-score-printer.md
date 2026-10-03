# Box score printer: handoff

**Job:** box score printer.

**Branch:** `codex/box-score-printer`, in the task folder `/Users/mikey/projects/.worktrees/baseball/box-score-printer`.

## What exists now

- **One layout, two drawings.** `BoxScorePrinter.layout(box, timeZone:)` in `ScorebookCore/Sources/BoxScoreText/` works out every line of the newspaper box score as a `NewspaperBoxScore`: the date, the headline with the leader first, “In progress” for an unfinished game, each team’s batting lines (ab r h bi) with substitutes under the player they replaced and a totals row, the line score in groups of three innings, the notes, the pitching lines (ip h r bb so), and the pitching notes. `BoxScorePrinter.text(box, timeZone:)` prints that as plain text, and `BoxScorePicture` draws it. The text and the picture cannot disagree.
- **Names** (`ShortNames`): last names only; a first initial when two players anywhere in the game share a last name (“L. Ortiz”); both full names when the initials match too. “#22”, “Batter 4” and one-word names print whole; “Jr.” and “III” stay with the last name.
- **Notes**, in the newspaper’s order: E, DP, TP, LOB, 2B, 3B, HR, SB, CS, S (sacrifice bunt), SF. Visitors’ players first. A count prints only when it is more than one (“Ruiz 2”). An empty note is left out. Under the pitching lines: “HBP—by Reyes (Ford).” when only one opposing pitcher hit anybody, otherwise just the batters; then “Pitches-strikes—Collins 47-30, …”. Runs batted in are not repeated in the notes, since the bi column has them.
- **Small choices:** a starter with no fielding position prints “dh”, a substitute with none “ph”; two positions print “ph-2b”; innings pitched print “4⅓”; a ten-run inning prints “(10)” and the other team’s cells stay lined up; the date line is “Saturday, May 2” with no year, as in the mockup.
- **The picture** (`ScorebookUI/Sources/BoxScorePicture/`): the approved mockup’s newspaper look, 375 points wide, in the iPhone’s built-in serif face (New York) at fixed sizes, so the phone’s text-size setting never changes it. Paper `#F3EEE1` and ink `#1A1712` are fixed in `Newsprint.swift`, so the picture is newsprint in light and dark mode. A name too long for its column drops to smaller type, so the numbers stay in their columns.
- **The image:** `BoxScoreRenderer.image(for:)` and `pngData(for:)` draw it at three times screen resolution, 1,125 pixels wide.
- **Sharing:** `BoxScoreShareItem` is the picture first and the plain text as the fallback; a receiving app takes the first it accepts. `BoxScoreShareLink(box)` is a ready-made share button (“Text the box score picture”), or `BoxScoreShareLink(box) { your label }`.
- **Previews** in `Previews.swift`: the finished game in light and dark mode, fourteen hitters, the game in progress, the largest accessibility text size, the share button, and the rendered image as sent.

## For the wiring and postgame screen jobs

- Pass the time zone the game was played in if it ever differs from the phone’s; the default is the phone’s.
- “Copy as text” on the end-of-game screen is `BoxScorePrinter.text(box)`.
- The share item is drawn once when the button appears. Messages and Photos should take the picture. That is checked only in the simulator so far; the dress rehearsal should send one from a real phone.

## Requests for the lead builder

1. **Let `BoxScorePicture` use `SampleData`**, in `ScorebookUI/Package.swift`, as every screen module does. The previews need sample box scores, so for now they read JSON copies in `BoxScorePicture/Resources/`, which ship inside the app (about 50 KB). The test `PreviewFixtureTests` checks the copies still match `SampleData` and says how to rewrite them. With the dependency, delete the two JSON files and that test.
2. **Pitchers’ decisions** (win, loss, save, with records): the mockup shows “Fischer W, 4-1”, but `PitchingLine` has nothing to print it from.
3. **Earned runs:** the mockup has an er column; `PitchingCounts` has no earned runs, so the column is left out, as the brief’s “ip h r bb so” says.
4. **Who hit whom with a pitch:** `hitByPitch` tallies name only the batter. Naming the pitcher on each tally would let every “HBP—by …” note be exact.
5. **The runner for a designated non-runner** (“Brooks ran for Sullivan in the 5th.”) and the game’s length (“T—1:58”) are in the mockup but not in `BoxScore`.
6. **The logo:** the mockup puts the team logo above the date. It goes in once the designer adds the full-size logo to `DesignSystem`.

## Evidence

- `swift test` in `app/Packages/ScorebookCore`: 58 tests, all passing, 17 of them new. “The finished sample game matches the hand-checked box score, character for character” holds the whole expected text, worked out by hand from `SampleBoxScore.swift`. Others cover shared last names across the teams, fourteen hitters with every column lined up, a ten-run inning and extra innings, a tie, innings pitched, note counts and order, empty notes, and two pitchers hitting batters.
- `xcodebuild -scheme ScorebookUI-Package -destination 'platform=iOS Simulator,name=iPhone 17' build`: succeeded with no warnings.
- [box-score-printer-sample.png](box-score-printer-sample.png): the sample game rendered in the iPhone 17 simulator by `BoxScoreRenderer`, 1,125 × 2,614 pixels. A fourteen-hitter render with a very long name was checked the same way.
