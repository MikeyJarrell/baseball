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
- `setup` (the whole game setup written out) or `setupFile` (the name of a shared setup in [setups/](setups/), without `.json`).
- `events`: the event list, each with an `id` (`"e1"`, `"e2"`, …), an `enteredAt` time, and one key naming its kind. `id` and `enteredAt` may be left out, but checkpoints and notation checks need the `id`.
- `checkpoints` (optional): expected values part way through, each checked just after the event named in `afterEvent`.
- `expected`: what should be true after the last event.
- `source` (optional): for a converted real game, where it came from, with the credit line.

Every expected value is optional; leave out anything the scenario does not test. The expected sections are `situation` (inning, half, outs, count, score, runners, batter, pitch counts, batting order spots, fielders, whether the defense check is due, whether the dropped third strike button shows, who the app offers to run for a designated non-runner), `notation` (an event’s scorebook notation), `batting`, `pitching` and `fielding` (box score numbers, named as in `BattingCounts`, `PitchingCounts` and `FieldingCounts`), and `teams` (runs, hits, errors, runners left on base, runs by inning in the line score, double and triple plays). Naming a player the box score has no line for is reported as a problem, even when every number expected is zero.

In `situation`, a `runners` list is the whole set of runners: a base it leaves out must be empty, and `[]` means nobody on.

## Shared setups

- `standard`: Mudcats (visitors, `m1` to `m12`) at Diamond Dogs (home, our team, `d1` to `d12`). Nine-hitter orders; the pitchers, Ray Collins (`m9`) and Sky Barros (`d9`), bat ninth. The bench is `m10` to `m12` and `d10` to `d12`; `m12` and `d12` are relief pitchers.
- `designated-non-runner`: the same, with the Diamond Dogs’ leadoff hitter, Alex Moreno (`d1`), a designated non-runner.
- `unknown-opponent`: the Riverhawks, a team nobody knows, at the Diamond Dogs. Their hitters are placeholders `r1` to `r9` (“Batter 1” to “Batter 9”) with no positions, and their pitcher, `rp`, does not bat.

## Starting mid-game

To start a scenario in the ninth inning or with runners already on, make the first event a `manualAdjustment` that sets the inning, half, outs, score, runners and `batterIndex` (the spot due up, counting from 0). Runners placed that way are charged to the pitcher on the mound.

## The foundation job’s scenarios

The `hard-` files are the twenty-two hard plays the foundation job used to test the vocabulary, with expected values worked out by hand.
