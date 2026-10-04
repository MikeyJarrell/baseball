# In-play sequence: handoff

**Job:** screen builder, in-play sequence (`plan/briefs/screen-play-entry.md`).

**Branch:** `codex/screen-play-entry`, in the task folder `/Users/mikey/projects/.worktrees/baseball/screen-play-entry`.

**Owns and touched:** `app/Packages/ScorebookUI/Sources/PlayEntry/` and `app/Packages/ScorebookUI/Tests/PlayEntryTests/`, plus this note and its screenshots in `plan/handoffs/screen-play-entry/`.

**Review round:** the fresh review is `feedback/ai/screen-play-entry-review.md`. The section “After the review” below says what changed.

## What exists now

The sequence that opens on “In play” (or “Dropped 3rd strike”) and ends in one ball-in-play event, the dropped-third-strike play, or a cancel. It matches the approved mockup, with Mikey’s changes:

- **Step one** is headed “What happened to the batter?”: Batter out, Single, Double, Triple, Home run, Reached on error, Fielder’s choice (“batter safe, runner out”), and More for sacrifice fly, sacrifice bunt and catcher’s interference. A dropped third strike opens only from the batting screen’s chip after strike three.
- **Fielders.** Tap fielders in order on the field drawing; the notation builds as they tap and the throws are drawn. Tapping the last fielder again, or the arrow beside the notation, takes it back. On a batter out, chips for ground, fly, line, pop-up and bunt, with Double play and Triple play beside them. The kind of ball is the rules engine’s guess (`suggestedBattedBall`) and shows as a dashed chip; a tap on another chip replaces the guess. With nobody on, Save is right there; with runners on, the button is Runners.
- **Hit:** tap where it landed (a dot, and “1B 7”), or go straight on. With nobody on, Save and Runners sit side by side.
- **Error:** tap the fielder who made it; Fielding or Throwing is optional.
- **Fielder’s choice, sacrifices, a dropped third strike thrown out:** tap the fielders in order, each with its own hint.
- **Runners.** The infield drawing shows every runner, batter included, at the base the rules engine suggests, with arrows (red and dashed with a cross for an out). Under it, a row of base buttons per runner (1st, 2nd, 3rd, Home, Out, starting from the runner’s own base; a batter who is out on the play gets only Out); a solid dot marks the rules engine’s guess. Tapping a runner’s tag on the drawing also moves them to their next outcome, as the brief described. The card at the top shows the notation, the outs and runs on the play, “Inning over” at three outs, and the runs batted in with − and +. The bottom bar says the outs after the play, and “Saving switches sides” at three outs.
- **A runner moved past where the play carried them, on any kind of play,** gets “How did they get there?”: On the throw (for the batter) or On the hit (On the play when it was not a hit, for a runner already on base), or On an error, then whose (nine fielder buttons). The batter starts with no answer, which saves as on the throw; a runner already on base starts at On the hit, so sending a runner home costs no extra tap. An error answer marks that runner’s move `advancedOnError` and lists the error once in the play’s `errors`, which is how “1B 7, E7” and “F9, E9” come about. Save waits until “On an error” says whose.
- **A runner the scorer puts out who was not suggested out** gets “Who put them out?”: tap the fielders in order (8-4 for a runner doubled off second). Save waits for it; the fielders go in that runner’s `outBy`.
- **Save refuses two runners ending on one base, or a runner passing the runner ahead,** and the bottom bar says why in red (“Webb and Quinn can’t both end on 2nd”), as it does for an unanswered question.
- **Dropped third strike:** Thrown out at first (then the fielders: K 2-3) or Batter safe at first (then the runners).
- **Back** on every step; on the first step it closes the sequence like Cancel. **Cancel** records nothing.

The screen does no baseball arithmetic. Notation, outs, runs, runs batted in, “inning over”, the kind of batted ball and where the runners went all come from the three functions it is handed. After every runner change it asks the rules engine again with only the runners the scorer has placed in `draft.runners`, so the engine can move the others along, and shows its answer with the scorer’s placements kept. A placed runner is the engine’s own move with only the base changed, so its other details survive (the batter’s error mark on a reached-on-error); a runner taken off Out loses who put them out. On a game-ending hit the engine’s credited hit (`RunnerSuggestion.batterResult`) is saved.

## How the app uses it (for the wiring job)

```swift
PlayEntryView(situation: situation, setup: setup, start: .inPlay,
              rules: PlayEntryRules(engine: rulesEngine)) { outcome in
    switch outcome {
    case .ballInPlay(let event): // record the event
    case .droppedThirdStrike(let play): // replace the strike-three pitch with the same pitch carrying `play`
    case .cancelled: break // nothing to record
    }
}
```

- Show it full screen. It calls `onFinish` once.
- `PlayEntryRules` is three functions: `suggestRunners`, `preview` and `suggestBattedBall`. `PlayEntryRules(engine:)` takes them from any `RulesEngine`.
- For `start: .droppedThirdStrike`, hand in the situation from just before the strike-three pitch, so the batter is the one who struck out and the outs do not yet count the strikeout. Only the strike-three chip opens this path, so `.droppedThirdStrike(play)` always replaces a strike-three pitch.
- When the runner step is skipped (nobody on), the saved play’s runners are the rules engine’s suggestion and its runs batted in the suggested number.

## Tap counts

Taps inside the sequence, Save included. Add one for the “In play” (or “Dropped 3rd strike”) tap on the batting screen.

| Play | Taps in the sequence | With “In play” | Taps |
|---|---|---|---|
| 6-3 with nobody on | 4 | 5 | Batter out, 6, 3, Save |
| F8 with a runner on second | 4 | 5 | Batter out, 8, Runners, Save |
| Single, runners on first and second, runner from second sent home | 5 | 6 | Single, tap left field, Runners, Home (runner from 2nd), Save; 4 without tapping where it landed |
| 5-4-3 double play, runner on first | 7 | 8 | Batter out, Double play, 5, 4, 3, Runners, Save |
| Error by the shortstop, batter to second | 5 | 6 | Reached on error, 6, Runners, 2nd (batter), Save; the “how did they get there?” question shows and may be left, which keeps the engine’s error mark |
| Fielder’s choice, lead runner out at second | 5 | 6 | Fielder’s choice, 6, 4, Runners, Save |
| Sacrifice fly | 5 | 6 | More, Sacrifice fly, 8, Runners, Save |
| Single, batter to second on the left fielder’s error (1B 7, E7) | 7 | 8 | Single, tap left field, Runners, 2nd (batter), On an error, 7, Save |
| F9, runner from second scores on the right fielder’s error (F9, E9) | 7 | 8 | Batter out, 9, Runners, Home (runner), On an error, 9, Save |
| F8, runner doubled off second (8-4) | 7 | 8 | Batter out, 8, Runners, Out (runner), 8, 4, Save |
| Dropped third strike, batter safe | 2 | 3 | Batter safe at first, Save |
| Dropped third strike, thrown out (K 2-3) | 4 | 5 | Thrown out at first, 2, 3, Save |

A single with nobody on is Single, Save: two taps. These match the mockup’s walkthroughs (F8 5, single scoring the runner 6, 5-4-3 8, E6 6, 1B 7, E7 8).

## Demos and previews

- `PlayEntryDemos.swift` holds each play above as a script of taps, with where it starts and what the finished play should read (notation, outs, runs, runs batted in). `PlayEntryDemoGallery` (public) lists them for the simulator: each row runs its script, shows a check mark when the play comes out as expected, and gives the tap count; tapping a row opens the sequence to enter the play by hand, and the finished play shows below as JSON. All twelve pass with SampleData’s rules engine, which is now the real one.
- `Previews.swift` has twenty previews built from the same scripts: each step of every brief play, the dropped third strike both ways, dark mode, and the largest text size.
- The scripts call the same `PlayEntryModel.perform(_:)` every button calls, which is also what counts the taps.

## Vocabulary change requests

None. The lead builder’s vocabulary pass added `suggestedBattedBall`, which replaced the screen’s own guess, and SampleData’s engine is now the real one, which replaced this folder’s demo wrapper (both deleted).

## After the review

Every finding the coordinator listed is fixed, with a test in `Tests/PlayEntryTests/PlayEntryTests.swift` (14 tests, run through the same tap handler the buttons use, with the real rules engine):

1. A runner the scorer puts out asks who did it, and Save waits (`testRunnerDoubledOffNeedsWhoMadeTheOut`, `testTappingTheLastOutFielderAgainTakesItBack`).
2. Only the scorer’s own placements go to the engine (`testOnlyTheScorersPlacementsGoToTheEngine`); two runners on one base, or a runner passing another, cannot be saved (`testTwoRunnersOnOneBaseCannotBeSaved`, `testARunnerCannotPassTheRunnerAhead`). The real engine keeps the other runners at its first guess, so on a single with a runner on first and the batter sent to second, the scorer moves the runner from first too; the refusal says so.
3. “On an error” needs a fielder before Save (`testOnAnErrorNeedsWhoseError`).
4. A batter out, sacrifice fly or sacrifice bunt offers the batter only Out (`testBatterOutOffersOnlyOut`, `testSacrificeFlyBatterOffersOnlyOut`).
5. Moving a runner changes only the base (`testMovingTheErrorBatterKeepsTheErrorMark`, `testTakingARunnerOffOutClearsWhoPutThemOut`).
6. Mikey’s decision: the extra-base question comes up on every kind of play (`testFlyOutWithThrowingErrorAsksAndChargesTheError`, `testRunnerAlreadyOnBaseStartsAtOnThePlay`).
7. Mikey’s decision: Dropped 3rd strike is gone from More (`testMoreHasNoDroppedThirdStrike`).
8. The guess dot is a solid 7-point dot in full-strength text color, unpicked base labels are dark, and every button on the sequence is at least 44 points tall.

Review finding 8 (Back from the runner step forgets runner changes) was not on the coordinator’s list and is unchanged.

## Not done or not checked

- **No hand taps by me.** The reviewer tapped every brief play by hand in a UI test; after these fixes the plays were checked by the tests and the scripted demos, and by screenshots at every step.

## Evidence

- `xcodebuild test -scheme ScorebookUI-Package` on an iPhone 17 simulator, in `app/Packages/ScorebookUI`: builds with no warnings; every test passes, the 14 in `PlayEntryTests` among them (one runs all twelve demo scripts).
- The app shell project, with its home screen swapped for the demo gallery, built and ran on a simulator of its own (a throwaway copy outside the repository, with its own app id). All twelve demo scripts pass (`gallery.png`).
- Screenshots in `plan/handoffs/screen-play-entry/`, checked by eye:
  - step one, with More open: `step-one.png`, `step-one-more.png`;
  - 6-3: `63-fielders.png`; F8: `f8-runners.png`;
  - single scoring the runner from second: `single-where.png`, `single-runners.png`; a single with nobody on: `single-nobody-on.png`;
  - 5-4-3: `dp-fielders.png`, `dp-runners.png`;
  - error by the shortstop: `e6-who.png`, `e6-runners.png`;
  - fielder’s choice: `fc-runners.png`; sacrifice fly: `sf-runners.png`;
  - 1B 7, E7, before and after whose error: `1b-e7-needs-fielder.png`, `1b-e7-runners.png`;
  - F9, E9: `f9-e9-runners.png`;
  - a runner doubled off, before and after who made the out: `f8-doubled-off-needs-fielders.png`, `f8-doubled-off.png`;
  - dropped third strike: `k3.png`, `k3-out.png`;
  - dark mode: `dark-step-one.png`, `dark-dp-runners.png`, `dark-e6-who.png`, `dark-f8-doubled-off.png`;
  - largest text size: `big-step-one.png`, `big-dp-fielders.png`, `big-1b-e7-runners.png`, `big-k3.png`.
