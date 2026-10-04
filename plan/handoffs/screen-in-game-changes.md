# In-game changes: handoff

**Job:** screen builder, in-game changes.

**Branch:** `codex/screen-in-game-changes`, in the task folder `/Users/mikey/projects/.worktrees/baseball/screen-in-game-changes`.

## What exists now

Everything is in `app/Packages/ScorebookUI/Sources/GameChanges/`, one file per sheet:

- **`ChangesMenuSheet`**: what the batting screen’s big substitution button opens. Pitching change, fielders, pinch hitter, pinch runner, runner for a non-runner, add a hitter; each opens inside the same sheet, with a back arrow to the list.
- **`PitchingChangeSheet`**: outgoing pitcher’s pitches and strikes; a note when a batter is part way through a count (rule 9.12 B 2, “your call”); “Can pitch again” from `eligibleToPitchAgain`; the bench first, then players already in the game; a new pitcher by number, name and throwing hand; where the old pitcher goes, and whether the new one takes the old one’s batting spot.
- **`PinchHitterSheet`**: “Can re-enter” from `eligibleToReenter` for this spot, then the bench, a new hitter, and “Someone else” with everyone and where they are now. It also offers a batting hole, behind a confirmation that says the current hitter’s turn becomes an out right away, since no other screen records that event.
- **`PinchRunnerSheet`**: tap the runner, choose the replacement; the explanation changes for a designated non-runner (rule 9.11 M) and for the runner already running for one (9.11 N).
- **`NonRunnerSheet`**: the automatic prompt. The rule’s runner from `runnerChoice.suggestedRunner`, then “Quinn runs” (records nothing), “Pinch runner instead” (the bench, then “Someone else”), and “Someone else”. “Later” cancels.
- **`AddHitterSheet`**: roster or new player; says where they bat and how soon they are up.
- **`DefenseSheet`**: the defense check (`.check`, our team, “Later”, one tap on “Everyone’s where they were”) and the fielders sheet (`.changes`, either team). Tap a position for chips of every player; picking someone already in the field swaps the two; “Nobody” leaves a position empty. Changes go back as one substitution touching only the defense.
- **`RunnerActionSheet`**: the eight actions plus defensive indifference and a pinch runner link. Tap more runners for a double steal. The second page starts from the handed-in suggestion, shows every runner with a button for each place they could end up, takes fielder taps on the field drawing for an out, and offers “Add an error” on every action (a steal where the catcher throws the ball away). On save, runners who stayed are left out and each runner gets their own reason from where they ended up: on a double steal with the lead runner thrown out, the trail runner stole and the lead runner was caught stealing, whichever button started it. A pickoff or appeal out defaults to the runner’s own base. An out or error with no fielder tapped saves under “Save without fielders”. On a pickoff, each runner put out has “Picked off while stealing” (`wasStealing`, counted as caught stealing). Right after a strikeout in the same half-inning, “Same pitch as the strikeout” appears once a runner is out and sets `completesStrikeoutDoublePlay`.
- **`GameMenuSheet`**: manual adjustment, error with nobody moving, time limit, edit this batter, the walk-up song length (if a binding is handed in), and end game with a reason.
- **`ManualAdjustmentSheet`**, **`ErrorSheet`**, **`TimeLimitSheet`**, **`BatterSheet`** (name, number, batting side; for our batter it also leads to the pinch hitter sheet), **`GameOverSheet`** (no Cancel; End game or Keep playing).

## How the wiring uses them

Every sheet takes a `GameChangeContext(setup:situation:)` and an `onFinish` closure, and calls it once with a `GameChangeResult`:

- `.record(EnteredEvent)`: add `newPlayers` to the game’s roster, then record the event.
- `.updatePlayer(PlayerEdit)`: replace that player (same id) in the game’s roster. The batter sheet tells the scorer an opponent’s name is “saved to the roster for next time”, so the wiring should also update the saved team.
- `.nothingToRecord`: the designated non-runner runs themselves. Close the prompt and do not reopen it for this runner until the situation changes.
- `.cancel`: close; nothing changed. “Later” on the defense check and the non-runner prompt also comes back as `.cancel`.

Present each one as an ordinary `.sheet`; each brings its own navigation. Notes:

- **Defense check:** open `DefenseSheet(context:)` when `defenseCheckDue` is true. **Alternating positions (Mikey’s addition):** the sheet reads `Situation.suggestedDefense` by itself. `DefenseBuilder.engineSuggestion` turns it into a plan of only the positions that differ from the field, marking each of the team’s `fieldingRotations` “alternating”. The sheet starts from the fielders on the field and lays the plan over them, so every other position keeps its player. It shades each differing position (“First base · alternating (was Quinn)”), and the big button reads “Save 1 change”, so one tap records it. The plan is used only on that team’s defense check, never on the fielders sheet. A `suggestion: DefenseSuggestion(team:fielders:reasons:)` handed in takes its place, for previews. One difference from the engine’s own list: if the player whose turn it is was already fielding elsewhere, the sheet swaps them rather than leaving their old position empty.
- **Non-runner prompt:** open `NonRunnerSheet(context:)` when `runnerChoice` is set.
- **Runner actions:** `RunnerActionSheet(context:runner:suggest:followsStrikeout:onFinish:)`, where `followsStrikeout` is `RunnerActionBuilder.followsStrikeout(log: replay.log, situation: replay.situation)` (the last event was a strikeout in this half-inning; `droppedThirdStrikePossible` does not do, since it is false with first base occupied and fewer than two outs, the usual strike-’em-out, throw-’em-out case), and `suggest` is `{ reason, runners in engine.suggestRunnerAction(reason, runners: runners, in: situation) }`. For a wild pitch, passed ball or balk the sheet passes every runner on base.
- **Game over:** open `GameOverSheet(context:)` when `gameOverQuestion` is set or `clock(for:at:).askIfOverOnTime` turns true. It uses a half-height sheet and refuses to be swiped away.
- **Batting screen taps:** a runner opens `RunnerActionSheet` with that runner, the pitcher opens `PitchingChangeSheet`, the batter opens `BatterSheet`, the menu opens `GameMenuSheet`.

## Rules shown as suggestions only

Nothing is blocked. Re-entry (9.9), pitcher re-entry (9.12 B), the non-runner’s runner (9.11) and a mid-count pitching change (9.12 B 2) are labels and orderings; “Someone else” always lists the rest of the roster with a note on where each player is now. “Keep playing” records `keepPlaying` and carries on.

## Left out or stubbed

- The sheets read who has left the game from the batting order’s history (a player who once held a spot and now holds none and is not fielding). A player who only fielded and was replaced looks like a bench player. A `TeamState` list of players out of the game would make the lists exact; not requested, since nothing is blocked either way.
- Setting a throwing hand or batting side for an existing player from the pitching change or add-hitter sheets is not offered; only new players get one there. The batter sheet edits batting side.
- The manual adjustment does not set the inning or half.
- `RadioMark` draws its tick in white and the segmented control’s shadow in black, as the design system’s own primary button does; everything else uses named colors.

## Event building and its tests

The decisions that turn taps into events are plain functions in `EventBuilding.swift`: `RunnerActionBuilder` (who goes into a runner action, each runner’s reason, where an out goes by default, the two strikeout and stealing marks, whether a strikeout came just before) and `DefenseBuilder` (laying a plan over the field, the engine’s suggested defense, swaps, the substitution).

18 tests are in `app/Packages/ScorebookUI/Tests/GameChangesTests/EventBuildingTests.swift`: the double steal with the lead runner out (from either button), a runner who stayed, a steal plus the catcher’s throwing error, a wild pitch with a runner thrown out, pickoff and appeal out bases, “picked off while stealing” kept only on a pickoff out, the strikeout double play needing an out, a one-position plan, a swap plan, a plan for the other team, a plan on the fielders sheet, the engine’s alternating first base in the sample situation, no engine suggestion, and an emptied position.

**Request for the lead builder:** that folder needs its own test target in `app/Packages/ScorebookUI/Package.swift`, which builders may not edit. The existing `DesignSystemTests` target cannot hold these tests, since it does not depend on GameChanges. Add, beside `DesignSystemTests`:

```swift
.testTarget(
    name: "GameChangesTests",
    dependencies: ["GameChanges", .product(name: "Model", package: "ScorebookCore"),
                   .product(name: "SampleData", package: "ScorebookCore")]
),
```

Until then, all 18 pass in a scratch package outside the repository that depends on ScorebookUI and compiles this same file (`xcodebuild test` on the iPhone 17 simulator), and `xcodebuild test -scheme ScorebookUI-Package` passes its own seven tests.

## Vocabulary requests

The test target above. The open in-game changes request in `notes/vocabulary-requests.md` (the two runner marks) is now built and can move to Done.

## Evidence

- `xcodebuild -scheme ScorebookUI-Package -destination 'platform=iOS Simulator,name=iPhone 17' build` in `app/Packages/ScorebookUI`: succeeded with no warnings.
- `Previews.swift` has every sheet in light, dark and the largest text size, driven by `SampleData` through the moments in `Demos.swift`. `GameChangesDemo` is a demo screen listing every sheet and showing what each hands back.
- Checked on an iPhone 17 simulator through a throwaway harness app outside the repository, including driving taps. Screenshots are in [screen-in-game-changes/](screen-in-game-changes/):
  - `addTenthHitter-ninth-batting.png` (“Bats 10th, after Barros … they bat right after Barros”) and `addEleventhHitter-after-tenth-added.png` (“Bats 11th, after Cole … after Barros and 1 more”), taken in one session after adding Cole.
  - `pitchingChangeMidCount.png`: Barros coming out at 2–1 to Diaz.
  - `defenseCheck-two-fielders-swapped.png`: Webb and Lang swapped by tapping; Save recorded one substitution (8: Lang, 9: Webb).
  - `defenseCheckAlternating.png`: Nash at first, “alternating (was Quinn)”, “Save 1 change”.
  - `nonRunnerPrompt.png` and the dark version: Quinn on first, Tate suggested.
  - `gameOverTimeLimit.png`, its dark version and `gameOverMercyRule.png`.
  - `runnerAction-caught-stealing-2-6.png`: Hale caught stealing, catcher to shortstop; Save recorded “m3 first→out 2-6”.
  - `defenseCheckRotation.png`: the engine’s suggested defense for the top of the 2nd with first base alternating: Nash at first, “alternating (was Quinn)”, “Save 1 change”.
  - `runnerAction-same-pitch-as-strikeout.png`: Hale thrown out 2-6 right after a strikeout; Save recorded “m3 first→out 2-6, with the strikeout: DP”.
  - `runnerAction-picked-off-while-stealing.png`: Hale picked off at first while stealing; Save recorded “m3 first→out stealing”.
  - `runnerAction-steal-plus-E2.png`: Hale steals second and takes third on the catcher’s throwing error; Save recorded “m3 first→third, E2”.
  - The rest of the sheets, and three at the largest text size.

## Review

A fresh reviewer’s notes are in `feedback/ai/screen-in-game-changes-review.md`. Findings 1 to 6, 8, 9 and 10 are fixed. Finding 7 (fielders who were replaced look like bench players) is left as the reviewer judged it harmless; it is the first item under “Left out or stubbed”.
