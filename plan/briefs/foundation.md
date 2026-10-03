# Foundation

**Role:** lead builder.

**Waits on:** nothing. This job goes first, and every other job except design waits on it.

**Owns:** everything under `app/` at the start; afterwards `Model/`, `SampleData/`, both `Package.swift` files and the Xcode project stay with the lead builder.

## Deliver

1. Both packages, `ScorebookCore` and `ScorebookUI`, in the Swift 6 language mode, with every module from [architecture.md](../architecture.md) declared and each holding one placeholder file, so no later job ever needs to edit a `Package.swift`. The same for every test module, including `TestSupport`, which bundles the `Tests/Scenarios/` folder and gives any test a one-line way to load a scenario.
2. The shared vocabulary in `Model/`, written as real Swift from the sketch in architecture.md: players, teams, positions, bases, game setup, batting order, every event kind, a play, the situation, the play log, a box score (batting lines, pitching lines, line score by inning, the notes underneath such as doubles, errors and double plays) and season totals. Every type is `Codable`, `Equatable` and `Sendable`, and commented in baseball terms.
3. The service interfaces in `Model/` as protocols, each with a do-nothing stand-in: rules engine, stats, storage, walk-up audio. Mark which run on the main thread (audio) and which are asynchronous (storage), so the Swift 6 compiler accepts the real versions later.
4. `SampleData/`, written by hand, since the rules engine and stats do not exist yet:
   - Our team with twelve players, songs assigned to most of them, a mix of right- and left-handed hitters, one switch hitter.
   - Two opponents: one with a full roster, one known only by jersey numbers.
   - At least eight situations: top of the first with nobody on; runner on first, one out, 2-1 count; bases loaded, two outs, full count; runners on second and third with nobody out; our tenth batter up after the lineup was extended; a new pitcher just in; the last of the scheduled innings with the home team ahead; extra innings.
   - Plate-appearance histories for a few batters (“6-3”, “BB”, “1B 7”).
   - One complete made-up game, start to finish, as an event list, with its play log and box score written out by hand.
   - A stand-in rules engine that returns canned suggestions and play previews, for the screens to use until wiring.
5. One scenario file in `Tests/Scenarios/` showing the exact JSON format, so the test writer has a pattern to copy.
6. `DesignSystem/` stub: named colors, text styles, spacing values, a plain button style, and the field drawing’s interface (what it is given: occupied bases, highlighted positions, a numbered tap sequence; what it hands back: which position or base was tapped) with a plain placeholder drawing. The names and the interface are the contract; the designer fills them in.
7. The Xcode app shell, if Xcode is installed: an iPhone app that opens to a placeholder screen and imports both packages. If Xcode is not installed yet, the wiring job creates it.
8. A short `app/README.md`: how to build, how to run the tests, where things live.

## Test the vocabulary before anyone builds on it

Before calling the vocabulary done, write these as scenario files, events and expected results, and change the vocabulary until every one can be expressed: a 5-4-3 double play; a 6-3 double play where the shortstop steps on second and throws to first; a triple play; a bases-loaded walk; a strikeout on a dropped third strike with the batter thrown out at first, and one with the batter reaching; a foul tip for strike three; a double steal with a throwing error; a dropped foul pop-up charged as an error; a pitching change in the middle of a 3-1 count followed by a walk; a run scored by a runner the first pitcher put on, after a pitching change; a courtesy runner who scores (the run goes to the player they ran for); a designated non-runner who singles and is replaced on first; a pinch runner; a starter re-entering; the third out made on the bases mid-at-bat; a hitter added to the bottom of the order while the old last hitter is batting; a walk-off single with the bases loaded; a manual adjustment; an opponent with an unknown lineup cycling back to the top; an error on a fly ball letting the batter reach second; a sacrifice fly with a throwing error. Each change made later costs every builder who has started.

## Finish line

`swift test` passes in `ScorebookCore`, and the twenty scenarios above decode. Sample data decodes from and encodes to JSON without loss, checked by a test. Every module compiles. A reviewer who reads only `Model/` can explain how a 5-4-3 double play with a runner on first is recorded.

## Watch out for

Getting the vocabulary right matters more than anything else in this project, because every other job builds on it and changing it later means changing their code. Before writing it, read every brief in this folder and check each one can be done with the vocabulary as designed. Things that are easy to miss: a plate appearance that never finishes because the third out was a runner caught stealing (the same batter leads off the next inning, with a fresh count); a pitcher who is also in the batting order; a batter known only as “their number 22”; a starter who is replaced and later re-enters, which our league allows; fielders who switch positions freely, which our league also allows, while fielding stats stay with the player.
