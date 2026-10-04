# In-game changes review

**Reviewer:** a fresh builder who did not build the in-game changes sheets, reviewing `git diff origin/main...HEAD` at commit 2ec7d67.

**Verdict:** Not ready to merge. Two sheets can hand back wrong events: double steals give the wrong stolen bases and caught stealing (finding 1), and a planned defense can land on the wrong team (finding 2). Everything else is small.

## What was checked

`xcodebuild -scheme ScorebookUI-Package -destination 'platform=iOS Simulator,name=iPhone 17' build` succeeds with no warnings. The branch merges cleanly with the current main, which now has the rules engine. Only `Sources/GameChanges/` and the handoff changed. The comments are plain and readable. Read against the brief, the handoff, `notes/league-rules.md`, the mockup’s `SHEETS.*` and all 23 screenshots. Each event-building function was traced through the rules engine and stats now on main (`GameEngine/Replay.swift`, `GameEngine/Suggestions.swift`, `Stats/BoxScoreBuilder.swift`).

These came out right:

- **Pinch hitter:** goes into the spot that is up.
- **Pinch runner:** takes over the runner’s batting spot. The engine handles both non-runner cases (rules 9.11 M and N).
- **Runner for a non-runner:** leaves the batting order alone.
- **Pitching change:** goes to the fielding team. The situation flips to the next half-inning at the third out, so this holds between innings too.
- **Wild pitch, passed ball and balk:** pass every runner.
- **Fielder swaps:** list both positions, so no fielder is lost.
- **Suggestions only:** nothing is blocked, and “Keep playing” records `keepPlaying` and carries on.

Contrast is fine: secondary text is 5.3 to 1 in light mode and 5.5 to 1 in dark.

## Findings

1. **`RunnerActionSheet.swift:202`: every runner gets the one reason the scorer picked.** Stats count a stolen base or a caught stealing from the reason alone (`Stats/BoxScoreBuilder.swift:181–185` on main), so:
   - **Double steal, lead runner thrown out:** the trail runner, who was safe, is charged with a caught stealing.
   - **Same play, entered from “Stole”:** the runner who was thrown out is credited with a stolen base.
   - **A runner left at “Stays” on a steal:** credited with a stolen base.

   Fix: in `save()`, leave out runners who stayed, and set each runner’s reason by where they ended up. On a steal or caught stealing, out means caught stealing and safe at the next base means stolen base.

2. **`DefenseSheet.swift:68–76` with `ChangesMenuSheet.swift:59`: the planned defense says nothing about which team it is for.** The fielders sheet opens on the team in the field and fills it from the plan. If the wiring passes the plan while we are batting, our players go into all nine of the opponent’s positions, and “Save 9 changes” records it. Even when we are fielding, it brings back a plan the scorer turned down at the defense check, and those changes get saved along with whatever else the scorer changed. Fix: add the team to `DefenseSuggestion`, and use it only on the defense check for that team.

3. **`DefenseSheet.swift:75`: the plan replaces the whole field.** Any position the plan leaves out shows as “Nobody”, and saving takes that player off the field. Fix: start from the fielders as they are now and lay the plan over them.

4. **`RunnerActionSheet.swift:231–245, 358–366`: errors can only go on “Advanced on error.”**
   - A steal where the catcher throws the ball away, so the runner takes an extra base, cannot be entered. That play is the model’s own example.
   - Save works with no fielder tapped, which records an error-free advance.
   - Save also works on an out with no fielders tapped, so nobody gets the putout.

   Fix: offer “Add an error” on every reason. When no fielder is tapped, label the button “Save without fielders”, which still saves.

5. **`RunnerActionSheet.swift:328–329`: an out is placed at the next base by default.** That is right for a caught stealing. For a pickoff or an appeal, tapping Out again moves the out to the wrong base. Fix: use the runner’s own base for those two.

6. **`PinchHitterSheet.swift:136–140`: the batting hole is safe enough.** It sits behind a red confirmation and can be undone. The spot is up now, though, so the engine records an out straight away. Fix: add “Reyes’s turn now is an out” to the message.

7. **Known gap, `GameChanges.swift:114–123`: fielders who were replaced look like bench players.** This does little harm:
   - Fielders may change freely at every position but pitcher (rule 9.12 A).
   - Pitchers who have come out are caught by the list of who pitched today.
   - The only cost is a “Bench” label in the pinch hitter and pinch runner lists.

   Fine for now.

8. **`NonRunnerSheet.swift:131–141`: “Pinch runner instead” lists only the bench.** Every other list ends in “Someone else”; this one has none. Fix: add it.

9. **`SheetParts.swift:465`: the segmented buttons are 40 points tall, under the 44-point minimum.** Fix: use `Spacing.minimumTapSize`.

10. **No tests for the code that builds the events.** Findings 1 to 3 live in `RunnerActionConfirmPage.save()` and `DefenseSheet.saveChanges()`. Fix: once fixed, add a few tests that build the event for a double steal with one runner out and for a defense plan.
