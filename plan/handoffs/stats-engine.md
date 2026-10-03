# Stats engine: handoff

**Job:** stats engine.

**Branch:** `codex/stats-engine`, in the task folder `/Users/mikey/projects/.worktrees/baseball/stats-engine`.

## What exists now

`StatsEngine` in `app/Packages/ScorebookCore/Sources/Stats/` is the real version of the `StatsCalculator` promise in Model. It reads only the play log and never decides anything about baseball; it adds up what each play log entry already says.

- **Box score for one game** (`boxScore(for:)`, built in `BoxScoreBuilder.swift`): a batting line for everyone who held a batting spot, spot by spot, each substitute under the player they replaced, with every counting stat the brief lists; a pitching line for every pitcher in the order they first pitched; a fielding line with innings by position for everyone who took a position; runs, hits, errors and runners left on base for each team; the line score; and the notes.
- **Season totals** (`seasonTotals(for:team:)`, in `SeasonTotalsBuilder.swift`): our team’s games oldest first, batting, pitching and fielding summed per player by player id, each player’s game-by-game log, and opponents left out. Batting average, on-base, slugging and the per-inning pitching rates are Model’s formulas on these counts, so a player with no at-bats shows “—”, never a crash.
- **A batter’s plate appearances in one game** (`plateAppearances(of:in:)`), in scorebook notation, for the batter history on the batting screen.
- `PlayLogReading.swift` holds the small rules: what counts as an at-bat, a hit, a play on the field, a double or triple play.

## Scoring decisions

- **Credit follows the play log.** A plate appearance goes to the batter and to the pitcher the play log charges (so a walk after a 3-1 pitching change is the first pitcher’s), pitches and strikes to the pitcher on the mound, a run to whoever the log credits and to the pitcher responsible for that runner, and putouts, assists and errors to whoever the log says was at that position. Runs batted in are the scorer’s number on the play, never recomputed.
- **Outs recorded** are the outs listed on each entry, charged to the pitcher on the mound. A batting hole’s automatic out counts; outs set by a manual adjustment do not, since nobody made them.
- **A pitcher who comes back keeps one pitching line**, placed where they first pitched.
- **A pickoff is not caught stealing.** Only moves marked `caughtStealing` count. Official rule 9.07(h) also counts a runner picked off while trying to steal, but the vocabulary cannot tell the two apart; the scorer can mark that case `caughtStealing`.
- **One assist per fielder per out**, even after handling the ball twice in a rundown (rule 9.10).
- **Double and triple plays** are counted when the scorer marked one, or when one event put out two (or three) runners. A batting hole’s automatic out is never part of one.
- **Innings in the field** come only from events where the ball was played (a pitch, a play, a runner move, an error, an automatic out). The end-of-game entry can sit in an inning nobody played, after the switch of sides, so it never counts. A player who took a position at a lineup change and saw no play before the game ended still gets a fielding line, with the inning of that change.
- **Batting line positions** are in the order they happened: “ph” or “pr” when the player came in, then each fielding position once.
- **A substitute** is anyone who took over a batting spot from its starter, so a hitter added mid-game is a substitute.
- **The runner for a designated non-runner** with no batting spot of their own gets a “pr” line right under the non-runner, holding their stolen bases and caught stealing; the run is on the non-runner’s line. A runner with their own spot keeps everything on it.
- **Line score:** the home team’s cell is empty (“x”) only in the last inning, when they did not bat in it. Innings skipped by a manual adjustment show 0 for both teams, as the walk-off scenario expects.
- **Notes** list the visitors first, then the home team, players in box score order. The left-on-base note always lists both teams; the other team notes list only teams with a count.
- **Errors by a fielder nobody named** count in the team’s E column but appear in no note, since there is no name to print.
- **Season lines** list every player on our roster in any of the games, in roster order, even one who never played (as `SampleSeason` does); a player’s games are the games where they had a batting line. A player’s name comes from the latest game, so a name filled in later shows everywhere.
- Earned runs are left out, as the brief says.

## Tests

`swift test` in `app/Packages/ScorebookCore`: every test passes. The stats suites have 29 tests: 26 run and pass, and 3 are skipped until the rules engine lands. The foundation’s 41 model tests still pass.

- **The sample game’s stats** (`SampleGameStatsTests.swift`): the final box score and the box score after three innings equal the hand-written ones exactly, every batter’s history matches, and a one-game season equals `SampleSeason.totals`.
- **Scoring rules** (`ScoringRulesTests.swift`), each on a short play log written by hand with `LogBuilder.swift`: what counts as an at-bat (all twelve ways a plate appearance ends, with average, on-base and slugging worked out by hand), an inherited runner who scores, a strikeout on a dropped third strike (batter reaches; batter thrown out 2-3), a walk after a 3-1 pitching change, a batting hole, runs from a manual adjustment, a walk-off with runners left on base, the home team not batting in the last inning, a triple play, a rundown, a pitcher who comes back, a pinch hitter’s positions, a “pr” line for a runner with no batting spot, and an empty game.
- **Season totals** (`SeasonTotalsTests.swift`): three games (the sample game, a game at the Bombers, a second Mudcats game) handed over out of order. Batting average, on-base and slugging match hand calculations for Moreno, Webb and Ford; Nash, with a walk and no at-bats, shows “—” for average and slugging and 1.000 on base; Voss, with no plate appearances, shows “—” for all three. Pitching rates, game logs, and the empty season are checked too.
- **Scenario stats** (`ScenarioStatsTests.swift`): for each of the 27 scenario files with stats expectations, replays the events through the rules engine and checks the box score at the end and at every checkpoint, then checks every batter’s history against their line. A last test runs the sample game itself through the engine and compares it with the hand-written box score. One test runs now and checks that all 27 files are found, so the scenario tests can never pass by checking nothing.

## Switching on the scenario tests

The rules engine is being built on another branch, and its type has no name yet. `Tests/StatsTests/ScenarioEngine.swift` holds one line:

```swift
static let engine: (any RulesEngine)? = nil
```

While it is `nil`, the three scenario tests are skipped with the reason “Skipped until the rules engine lands”, and show as skipped in the test run. **When the engine is merged, whoever merges it changes `nil` to the engine (for example `GameRulesEngine()`).** That one line switches the tests on. A stand-in that returns an empty play log is treated as no engine, so plugging one in also skips the tests. Swift cannot look up a type that may not exist without naming it, so this one edit cannot be avoided.

## What the stats engine needs from the rules engine’s play log

All of this is already in the play log’s comments. A gap here shows up quietly, as a wrong box score.

- `fielders` on every entry: the fielding team’s players, after any change the entry itself makes (the sample game does it this way; stats also copes with before).
- `plateAppearance.pitcher` for every finished plate appearance, `responsiblePitcher` on every run, `creditedTo` on a run scored by the runner for a designated non-runner.
- `outs` with `putout` and `assists` as players, and `errors` with the player at that position.
- `endsHalfInning` on every third out, with the stranded runners in `after`; the end-of-game entry’s `after` runners are the runners still on base when the game ended.
- `adjustedRuns` on a manual adjustment that changes the score.

## Vocabulary change requests

None needed. Two small suggestions for the lead builder, neither blocking:

1. A move reason for “picked off while trying to steal”, which official scoring counts as caught stealing. Workaround now: the scorer marks it `caughtStealing`.
2. The scenario format cannot yet check batting line order, positions (“ph”, “pr”) or an empty line score cell. Those are covered by the hand-written tests in `ScoringRulesTests.swift` instead.

## Not finished or not checked

- The scenario tests have never run, since there is no rules engine yet. When they first run, a failure may be the engine, the stats, or a hand-worked scenario value; the official rules settle it.
- `PROJECT_INDEX.md` is outside this job’s folders and still shows the stats job as not done.
- No review yet. A fresh reviewer should read the brief, this note and the changes.
