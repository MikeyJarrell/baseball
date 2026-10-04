# Scenarios

Short game situations with known right answers, one JSON file each. The rules engine and stats tests run their code against every file here. The test writer owns this folder; the format is defined by `Tests/TestSupport/Scenario.swift`, which the lead builder owns.

## Loading one in a test

```swift
import TestSupport
let scenario = try Scenarios.load("hard-5-4-3-double-play")
let replay = engine.replay(scenario.game)
#expect(scenario.expected.mismatches(situation: replay.situation) == [])
```

`Scenarios.names()` lists every file (including any in subfolders such as `retrosheet/`), and `Scenarios.loadAll()` reads them all. Each `mismatches` function returns a list of plain-English differences, empty when everything matches.

## The format

[pattern-6-3-groundout.json](pattern-6-3-groundout.json) is the example to copy. A file holds:

- `description`: what happens, in one line of plain English.
- `setup` (the whole game setup written out; its `rules` may be left out for the league’s rules) or `setupFile` (the name of a shared setup in [setups/](setups/), without `.json`).
- `events`: the event list, each with an `id` (`"e1"`, `"e2"`, …), an `enteredAt` time, and one key naming its kind. `id` and `enteredAt` may be left out, but checkpoints and notation checks need the `id`.
- `checkpoints` (optional): expected values part way through, each checked just after the event named in `afterEvent`.
- `expected`: what should be true after the last event.
- `source` (optional): for a converted real game, where it came from, with the credit line.

Every expected value is optional; leave out anything the scenario does not test. The expected sections are `situation` (inning, half, outs, count, score, runners, batter, pitch counts, batting order spots, fielders, whether the defense check is due, whether the dropped third strike button shows, who the app offers to run for a designated non-runner), `notation` (an event’s scorebook notation), `batting`, `pitching` and `fielding` (box score numbers, named as in `BattingCounts`, `PitchingCounts` and `FieldingCounts`), and `teams` (runs, hits, errors, runners left on base, runs by inning in the line score, double and triple plays). Naming a player the box score has no line for is reported as a problem, even when every number expected is zero.

In `situation`, a `runners` list is the whole set of runners: a base it leaves out must be empty, and `[]` means nobody on.

## Shared setups

- `standard`: Mudcats (visitors, `m1` to `m12`) at Diamond Dogs (home, our team, `d1` to `d12`), under the league’s rules (nine innings, a three-hour limit, the 12-run rule after seven, two designated non-runners). Each team has a batting order and a separate defense. Nine-hitter orders; the pitchers, Ray Collins (`m9`) and Sky Barros (`d9`), bat ninth. The bench is `m10` to `m12` and `d10` to `d12`; `m12` and `d12` are relief pitchers.
- `designated-non-runner`: the same, with the Diamond Dogs’ leadoff hitter, Alex Moreno (`d1`), a designated non-runner.
- `alternating-first-base`: the same as `standard`, with the Diamond Dogs’ first base shared by turns: Pat Quinn (`d4`) in odd innings, Robin Nash (`d11`) in even ones.
- `unknown-opponent`: the Riverhawks, a team nobody knows, at the Diamond Dogs. Their hitters are placeholders `r1` to `r9` (“Batter 1” to “Batter 9”) whose fielding positions are unknown, and their pitcher, `rp`, fields without batting.

## Starting mid-game

To start a scenario in the ninth inning or with runners already on, make the first event a `manualAdjustment` that sets the inning, half, outs, score, runners and `batterIndex` (the spot due up, counting from 0). Runners placed that way are charged to the pitcher on the mound.

## The foundation job’s scenarios

The `hard-` files are the twenty-two hard plays the foundation job used to test the vocabulary, with expected values worked out by hand. The files on the league’s own rules cover designated non-runners (`designated-non-runner-…`), batting holes (`batting-hole-…`), a pitcher coming back once, the time limit (`time-limit-…`, `tie-…`, `keep-playing-past-time-limit`), the run rule (`run-rule-…`), and a walk-off in an inning the time limit made the last (`time-limit-walk-off`). To make the time limit pass mid-game, a scenario sets the umpire’s time with a `timeLimitChange` event; events are 20 seconds apart.

None of these rules ends a game by itself: when one says the game could be over, the situation’s `gameOverQuestion` is set, and the game goes on until an `endOfGame` event. A `keepPlaying` event answers the question, and the same reason is not asked again.

A batting hole’s automatic out is an ordinary `automaticOut` event in the file, placed where the app would record it: right after the event that brought the hole up.

## The test writer’s library

The other files are the test writer’s library, one situation each, named for what they show: walks, strikeouts, groundouts, fly outs, double plays, hits from every base situation, sacrifices, errors, steals and pickoffs, pitching changes mid-count, inherited runners, designated non-runners, substitutions and re-entry, batting holes, lineups that grow, walk-offs and extra innings. [undo/](undo/) holds one file per kind of event checking that undo gives back exactly what was there before; its README explains the pattern. [retrosheet/](retrosheet/) holds three complete Major League games converted from Retrosheet, with the official box scores as expected stats; its README explains the converter.

## The vocabulary pass’s scenarios

These check rules added to the vocabulary after the first round of jobs: a pinch hitter who comes in with two strikes (`pinch-hitter-two-strikes-…`), a strikeout and a caught stealing on the same pitch as one double play, a pickoff while stealing counted as caught stealing, the catcher’s error on catcher’s interference, a game-ending double credited as a single, first base shared by turns (`alternating-first-base`, with its own setup), and the winning and losing pitchers when the starter is short of innings. They can check a box score’s batting line order (`battingLines` under `teams`), each batter’s `positions`, each pitcher’s `decision`, and the `suggestedDefense` in the situation.

