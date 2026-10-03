# Review: the league rule book in the shared vocabulary

**Verdict: accept after fixes.** Every new and changed scenario is right by hand, and nothing blocks a play. But a game that is shortened by the time limit has no walk-off rule, and four gaps would force later jobs to edit `Model/`.

**Reviewer:** a fresh agent that did not build this, reviewing commit 6ec5471 on `codex/foundation`. I checked it against `notes/league-rules.md`, the plan on `main`, and the SDABL rule book text in `~/Dropbox/baseball/reference/`.

**What was run:** `swift test` in `app/Packages/ScorebookCore`: 39 tests in 4 suites, all pass.

**Checked by hand, all correct:** the ten league-rule scenarios. Those are the time limit passing mid-inning, the home team ahead after the top half, a tie at the limit, keep playing, a tie after nine with time left, both run-rule files, the batting hole, and both non-runner files (9.11 D, E and G). I also checked the renamed hard plays that touch the new rules: starter re-entry (9.9), a pinch runner who does not make the starter eligible (9.9 note), and a pitcher eligible to come back (9.12 B). Two more were right: the sample game’s runner for Quinn (Webb, the last out, who was not at bat) and its re-entry list (Collins eligible, because Moss batted).

## Findings, most severe first

### 1. No walk-off in an inning that the time limit made the last one

**Where:** `Sources/Model/Situation.swift:54–58` (the `regulation` and `timeLimit` reasons) and `:79–81` (`scheduledInnings`, which is “so suggestions can tell when a hit in the bottom of the last inning ends the game”). Also `RulesEngineService.swift:149–150` (`PlayPreview.endsGame`).

**Problem:** suppose time runs out during the top of the fifth and the home team, trailing, bats in the bottom. Once they go ahead, no later inning can be played, so the game is over at that moment, the same as a walk-off in the ninth. The vocabulary ties “last inning” only to the scheduled nine innings. So the question is not asked until three outs, the play preview does not say the play ends the game, and the walk-off rule for suggesting runners (only the winning run scores) does not apply. That changes the final score and the runs batted in. Games that end on time are the normal case in this league, and the sample game itself is one.

**Fix:** define it in the `timeLimit` reason, and in the comments on `scheduledInnings` and `endsGame`: when `isLastInning` is true, the home team taking the lead in the bottom half raises the question at once, and the walk-off rule applies. Add a scenario for it. Also ask Mikey whether a home team that reaches a 12-run lead in the bottom of the seventh or later ends the game at once.

### 2. The live clock can ask “Is the game over?” about a finished game, and it duplicates the rules engine

**Where:** `Sources/Model/Situation.swift:174–193` (`clock(at:)`).

**Problem:** `clock(at:)` never checks `isFinal`. Suppose the scorer ends the game on time between innings and the engine leaves the situation as “top of the next inning, between halves.” Then `askIfOverOnTime` comes back true for good. More broadly, this is the time-limit logic written a second time inside `Model/`, apart from the engine’s own `gameOverQuestion` and `isLastInning`. If the two ever disagree, the rules-engine builder cannot fix the `Model/` copy without editing `Model/`.

**Fix:** return no question and no last inning when `isFinal` is true. Say in the comment that the engine’s stored facts are what count and that `clock` only moves them forward in time. Add a round-trip test for a finished game.

### 3. The non-runner prompt disappears on any event, but the rule allows it until the next pitch

**Where:** `Sources/Model/Situation.swift:36–40` (`runnerChoice`).

**Problem:** rule 9.11 A 3 and D allow the runner to be swapped in at any point before the next pitch. A pitching change or a mound visit with a defense change often comes first, and either one would clear the prompt now.

**Fix:** clear `runnerChoice` only on the next pitch, ball in play or intentional walk, on a `runnerForNonRunner`, or on a substitution for that runner. Add a scenario with a pitching change between the hit and the choice.

### 4. A non-runner on the substitute list cannot be declared

**Where:** `Sources/Model/GameSetup.swift:241–252` (`BattingOrderEntry.isDesignatedNonRunner`); `Sources/Model/Events.swift:558–569` (`AddHitter`).

**Problem:** rule 9.4 C lets non-runners be named “either in the batting order or on the eligible substitute list.” The flag exists only on starting batting-order entries. A bench player declared as a non-runner who later pinch-hits, or is added to the bottom of the order, cannot be one, and the engine has nowhere to read it from.

**Fix:** keep the declaration per player on the team, for example `GameTeam.designatedNonRunners: [PlayerID]`, drawn from the batting order and the bench. Have the engine set `BattingSlot.isDesignatedNonRunner` from whoever holds the spot now.

### 5. Players who field but do not bat have no record of where they played

**Where:** `Sources/Model/BoxScore.swift:166` (`FieldingLine`).

**Problem:** now that defense is a separate list, a pitcher who does not bat, or a fielder who never bats, has no `BattingLine`, and `BattingLine` is the only place positions are kept. A fielder with no putouts, assists or errors may get no line at all. Rule 3.5 B 2 makes managers prove that defense-only players took part, for playoff eligibility.

**Fix:** add `positions: [BoxPosition]` to `FieldingLine`, and say that every player who took a position gets a fielding line, even with all zeros.

### 6. A substitution cannot leave a position empty

**Where:** `Sources/Model/Events.swift:391–395` (`Substitution.defense`).

**Problem:** a player can leave a position only when someone else is put there. A team that loses a fielder and plays with eight (rule 9.4 E expects short-handed teams) cannot be recorded. The defense check would keep showing the departed player.

**Fix:** add a way to clear a position, for example `leavesField: [PlayerID]`.

### 7. The automatic out at a batting hole is underspecified

**Where:** `Sources/Model/Events.swift:140–142` and `:462–475` (`AutomaticOut`).

**Problem:** four things are undefined:

- Who `OutMade.runner` names, and who if anyone gets the putout. A catcher’s fielding stats depend on it.
- Whether the out counts as the “last recorded out” for a non-runner’s runner. It must not, because that player has left the game.
- What happens if a saved game’s event list contains an `automaticOut`. It is a normal event kind, so it could be counted twice.
- Whether the play-by-play screen may offer to edit or delete that entry. Its id is not in the game, so an edit would do nothing.

**Fix:** state each answer on `AutomaticOut`. Suggested answers: it names the hole’s last player, no putout, never counted as a recorded out for rule 9.11, ignored and flagged for review if found among the events, and not editable.

### 8. The championship preset conflicts with the playoff rules

**Where:** `Sources/Model/GameSetup.swift:151–152`.

**Problem:** rule 8.1 C 2 says championship games have no time limit, and their run rule is announced before the playoffs. That contradicts rule 9.1 J (3 hours 15 minutes), which is what the preset uses. Rule 8.1 C 1 says a playoff game tied at the limit keeps going. Since these rules only ask a question, nothing breaks, but the preset may be wrong.

**Fix:** ask Mikey which rule holds, and note playoff ties on `GameRules`.

### 9. Gaps in what the scenarios test

**Problem:**

- `tie-at-time-limit.json` never checks that no question is asked after the top half (a tie, so the home team bats).
- No file checks that nothing is asked when the visitors lead by 12 after six and a half innings, or when the lead is only 11.
- No file checks that a pitcher who has already pitched a second time drops off the eligible list (9.12 B).
- `hard-pitching-change-at-3-1-then-walk.json` removes a pitcher in the middle of a batter. Rule 9.12 B 2 allows that only for an injury.

**Fix:** add those checkpoints and files, and mention the injury in that file’s description.

### 10. Leftover names and a crash risk

**Where:** `Sources/Model/Play.swift:3–14` (the `Model/` example of a 5-4-3 double play still uses “c1” and “c2”, while the scenario uses `m1` and `m2`); `Tests/Scenarios/hard-hitter-added-while-last-hitter-bats.json:2` (“the ninth and last Cardinal”); `ScorebookUI/Sources/DesignSystem/FieldDrawing.swift:243–244`; `BoxScore.swift:192` (a force unwrap that crashes if `Position` ever gains a case).

**Fix:** rename the leftovers, and give the box position a safe fallback.

## Enforcement

Nothing enforces a league rule. The time limit and run rule only set `gameOverQuestion`, re-entry and pitcher re-entry are lists, and the non-runner’s runner is a suggestion. The automatic out at a batting hole is applied without asking, which matches the rule book, and the scorer can still undo it by filling the hole.

## Regressions

None found in the fixes from the earlier review: the runner for a non-runner gets a `pr` line, score adjustments go into the line score, runners left on base are counted at the end of the game, and the storage, field-drawing and audio changes still hold. The rename to Diamond Dogs is complete apart from finding 10.
