# In-play sequence: review

**Reviewer:** a builder who did not build it, reviewing `git diff origin/main...HEAD` on `codex/screen-play-entry` against `plan/briefs/screen-play-entry.md`, the approved mockup and the handoff note.

**Verdict:** every play the brief names saves correctly, typed by hand with the real rules engine, but a runner the scorer marks out is saved with no fielders credited, and a moved runner can end up sharing a base with another, so fix findings 1 and 2 before wiring.

## How it was checked

- `xcodebuild -scheme ScorebookUI-Package` for the iPhone 17 simulator: builds, no warnings.
- A throwaway copy outside the repository: this branch’s `PlayEntry` on top of `origin/main`’s ScorebookCore, so the real rules engine (`ScorebookRulesEngine`) could be used. It compiles unchanged, so rebasing onto main should be clean. App id `com.mikeyjarrell.scorebook.review-playentry`, run on a simulator made for the review and deleted afterwards.
- **Hand taps.** A UI test target in the copy tapped the real buttons and the fielders on the field drawing, the way a thumb would, with the real engine handing back suggestions. The plays checked: 6-3, F8 with a runner on second, a single with runners on first and second sending the runner from second home, 5-4-3, E6 with the batter to second, a fielder’s choice, a sacrifice fly, 1B 7 E7, both dropped-third-strike plays, Back twice to cancel, a single with nobody on, untapping a fielder, and a runner marked out. Every brief play came back right: the notation, the outs, the runs, who made each out (5-4 and 4-3 on the double play, 6-4 on the fielder’s choice, 2-3 on the dropped third strike), the runs batted in, and E7 with the batter’s extra base marked as an error. The tap counts match the handoff note and the mockup’s walkthroughs.
- **Scripted plays.** 26 plays, run through the same tap handler with both the demo stand-in and the real engine. Findings 1 to 6 come from these.

## Findings, worst first

1. **A runner the scorer marks out is saved with no fielders, so nobody gets the putout.** `PlayEntryModel.swift:410` rebuilds the runner as `RunnerMove(runner:from:to:)`, which drops `outBy`. The real engine keeps the scorer’s pick exactly as handed to it (`Suggestions.swift:21`), so `outBy` never comes back filled. Replay credits a runner’s out to `move.outBy` (`Replay.swift:473`), so the out counts but no fielder gets a putout or an assist. Reproduced by hand: F8, then the runner from second marked Out (doubled off) saves `outBy: []`. The same happens on a single with the runner from first thrown out at third, and on a fielder’s choice where the scorer changes which runner was out. The handoff note admits the gap, but fielding stats are per player.
   **Fix:** when a runner is set to Out and the engine did not suggest that out, show “Who made the out?” under that runner’s row, using the same fielder buttons as “Whose error?” and tapped in order, with an optional base. Disable Save until it is answered. Then build the move from the engine’s own move with only `to` changed (see finding 5), and put the scorer’s fielders in `outBy`.

2. **A runner the scorer moves can land on a base someone else is already on, and Save allows it.** `askEngineAboutRunners` (`PlayEntryModel.swift:394–400`) sends every runner, untouched ones included, in `draft.runners`. The real engine treats all of them as the scorer’s choices, so it never moves the runners behind. Example: on 1B 7 E7 with a runner on first, the batter and the runner from first both save at second, with both engines. A runner can also be put behind a runner who started ahead of them.
   **Fix:** send only the runners the scorer has actually placed (`scorerPicks`) in `draft.runners`, so the engine can push the others along. Also, at `save()` (`:454`), refuse two runners ending on one base and a runner passing the runner ahead of them, with a one-line message.

3. **“On an error” with no fielder picked saves as a clean hit.** `canSave` is always true on the runner step (`:170`). Picking On an error but not whose saves `advancedOnError: false` and no error, which reads as “on the throw”: the error the scorer meant to charge is silently lost.
   **Fix:** disable Save, or flag the question in red, until a fielder is picked.

4. **On a batter out, the batter’s row still offers 1st, 2nd, 3rd and Home.** `choices(for:)` (`:206–209`). Picking 1st saves `batterResult: out` with the batter safe and 0 outs on the play: a self-contradicting record.
   **Fix:** on out, sacrifice fly and sacrifice bunt results, offer the batter only Out, or switch the result to “reached on error” when the scorer puts the batter on base.

5. **Moving a runner wipes the engine’s other details.** The same line (`:410`) drops `advancedOnError` and `reason`. On reached-on-error the real engine marks the batter `advancedOnError: true` (`Suggestions.swift:49`). Moving that batter to second (the brief’s E6 play) saves `false`.
   **Fix:** copy the engine’s move and change only `to`. Clear `outBy` and `outAt` only for a runner taken off Out.

6. **An extra base on an error can be charged only on a hit.** `asksHow` stops at `guard isHit` (`:214`). On F9 with the runner from second scoring on a bad throw, the scorer cannot charge E9: the error is lost, and the batter is credited a run batted in by default. The brief asks this question whenever a runner goes further than the play carried them. The mockup shows it only on hits, so this needs a decision from Mikey.
   **Fix:** ask “How did they get there?” for any runner the scorer moves past the engine’s first suggestion, whatever the result.

7. **Choosing Dropped 3rd strike under More hands back the same answer as the strike-three button.** `PlayEntry.swift:70–74`, `PlayEntryModel.swift:241`. The wiring note says to replace the strike-three pitch, but on this path no strike three has been recorded. Following the note would overwrite whatever pitch came before, such as a ball, and the count would be wrong. More also offers it at a 1–1 count.
   **Fix:** return which way the sequence was opened, for example `droppedThirdStrike(play, replacesLastPitch: Bool)`, or hide the choice under More unless there are two strikes.

8. **Back from the runner step throws away every runner change without saying so** (`:445`). Acceptable, but a runner sent home has to be re-entered after a Back to fix the fielders.
   **Fix:** keep `scorerPicks` when going back, and clear them only when the result changes.

9. **Hard to see in sun.** The dot marking the app’s guess is 5 points at 60% opacity in gray (`RunnersStep.swift:169`), almost invisible outdoors. The on-the-throw/on-an-error buttons are 40 points tall (`:229`), under the 44-point minimum. Unpicked base labels are gray on gray.
   **Fix:** make the dot 7 points at full opacity, and set the button heights to `Spacing.minimumTapSize`.

10. **Minor.** The demo stand-in makes a 5-4-3 without the Double play chip one out; the real engine makes it two. This is harmless, since `DemoRulesEngine` is due to be deleted. The batted-ball guess in the screen is acceptable: it only sets the default chip, which the scorer can see and change.

The screen does no other baseball arithmetic. Nothing outside `Sources/PlayEntry/` and the handoff was edited. The comments are clear for a beginner.
