# In-game changes: handoff

**Job:** screen builder, in-game changes.

**Branch:** `codex/screen-in-game-changes`, in the task folder `/Users/mikey/projects/.worktrees/baseball/screen-in-game-changes`.

## What exists now

Everything is in `app/Packages/ScorebookUI/Sources/GameChanges/`, one file per sheet:

- **`ChangesMenuSheet`**: what the batting screen’s big substitution button opens. Pitching change, fielders, pinch hitter, pinch runner, runner for a non-runner, add a hitter; each opens inside the same sheet, with a back arrow to the list.
- **`PitchingChangeSheet`**: outgoing pitcher’s pitches and strikes; a note when a batter is part way through a count (rule 9.12 B 2, “your call”); “Can pitch again” from `eligibleToPitchAgain`; the bench first, then players already in the game; a new pitcher by number, name and throwing hand; where the old pitcher goes, and whether the new one takes the old one’s batting spot.
- **`PinchHitterSheet`**: “Can re-enter” from `eligibleToReenter` for this spot, then the bench, a new hitter, and “Someone else” with everyone and where they are now. It also offers a batting hole, behind a confirmation, since no other screen records that event.
- **`PinchRunnerSheet`**: tap the runner, choose the replacement; the explanation changes for a designated non-runner (rule 9.11 M) and for the runner already running for one (9.11 N).
- **`NonRunnerSheet`**: the automatic prompt. The rule’s runner from `runnerChoice.suggestedRunner`, then “Quinn runs” (records nothing), “Pinch runner instead”, and “Someone else”. “Later” cancels.
- **`AddHitterSheet`**: roster or new player; says where they bat and how soon they are up.
- **`DefenseSheet`**: the defense check (`.check`, our team, “Later”, one tap on “Everyone’s where they were”) and the fielders sheet (`.changes`, either team). Tap a position for chips of every player; picking someone already in the field swaps the two; “Nobody” leaves a position empty. Changes go back as one substitution touching only the defense.
- **`RunnerActionSheet`**: the eight actions plus defensive indifference and a pinch runner link. Tap more runners for a double steal. The second page starts from the handed-in suggestion, shows every runner with a button for each place they could end up, takes fielder taps on the field drawing for an out, and the fielder for an advance on error.
- **`GameMenuSheet`**: manual adjustment, error with nobody moving, time limit, edit this batter, the walk-up song length (if a binding is handed in), and end game with a reason.
- **`ManualAdjustmentSheet`**, **`ErrorSheet`**, **`TimeLimitSheet`**, **`BatterSheet`** (name, number, batting side; for our batter it also leads to the pinch hitter sheet), **`GameOverSheet`** (no Cancel; End game or Keep playing).

## How the wiring uses them

Every sheet takes a `GameChangeContext(setup:situation:)` and an `onFinish` closure, and calls it once with a `GameChangeResult`:

- `.record(EnteredEvent)`: add `newPlayers` to the game’s roster, then record the event.
- `.updatePlayer(PlayerEdit)`: replace that player (same id) in the game’s roster. The batter sheet tells the scorer an opponent’s name is “saved to the roster for next time”, so the wiring should also update the saved team.
- `.nothingToRecord`: the designated non-runner runs themselves. Close the prompt and do not reopen it for this runner until the situation changes.
- `.cancel`: close; nothing changed. “Later” on the defense check and the non-runner prompt also comes back as `.cancel`.

Present each one as an ordinary `.sheet`; each brings its own navigation. Notes:

- **Defense check:** open `DefenseSheet(context:)` when `defenseCheckDue` is true. **Alternating positions (Mikey’s addition):** pass `suggestion: DefenseSuggestion(fielders:reasons:)` with the planned defense for this half-inning and a reason per differing position (`[.firstBase: "alternating"]`). The sheet opens with the plan filled in, shades each differing position (“First base · alternating (was Quinn)”), and the big button reads “Save 1 change”, so one tap records it. Nothing in `Model` yet says who alternates; the wiring builds the suggestion once the lead builder adds the planned alternations to the setup. `ChangesMenuSheet` takes the same `defenseSuggestion` for its fielders sheet.
- **Non-runner prompt:** open `NonRunnerSheet(context:)` when `runnerChoice` is set.
- **Runner actions:** `RunnerActionSheet(context:runner:suggest:onFinish:)`, where `suggest` is `{ reason, runners in engine.suggestRunnerAction(reason, runners: runners, in: situation) }`. For a wild pitch, passed ball or balk the sheet passes every runner on base.
- **Game over:** open `GameOverSheet(context:)` when `gameOverQuestion` is set or `clock(for:at:).askIfOverOnTime` turns true. It uses a half-height sheet and refuses to be swiped away.
- **Batting screen taps:** a runner opens `RunnerActionSheet` with that runner, the pitcher opens `PitchingChangeSheet`, the batter opens `BatterSheet`, the menu opens `GameMenuSheet`.

## Rules shown as suggestions only

Nothing is blocked. Re-entry (9.9), pitcher re-entry (9.12 B), the non-runner’s runner (9.11) and a mid-count pitching change (9.12 B 2) are labels and orderings; “Someone else” always lists the rest of the roster with a note on where each player is now. “Keep playing” records `keepPlaying` and carries on.

## Left out or stubbed

- The sheets read who has left the game from the batting order’s history (a player who once held a spot and now holds none and is not fielding). A player who only fielded and was replaced looks like a bench player. A `TeamState` list of players out of the game would make the lists exact; not requested, since nothing is blocked either way.
- Setting a throwing hand or batting side for an existing player from the pitching change or add-hitter sheets is not offered; only new players get one there. The batter sheet edits batting side.
- The manual adjustment does not set the inning or half.
- `RadioMark` draws its tick in white and the segmented control’s shadow in black, as the design system’s own primary button does; everything else uses named colors.

## Vocabulary requests

None required. One for later: the planned alternations for the defense suggestion, which the lead builder already has in hand.

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
  - The rest of the sheets, and three at the largest text size.
