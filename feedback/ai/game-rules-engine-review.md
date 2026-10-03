# Game rules engine: review

**Reviewer:** a fresh Claude session that did not build the engine.

**Reviewed:** `git diff origin/main...HEAD` on the game-rules-engine branch (commit 635c75b), against `plan/briefs/game-rules-engine.md`, the handoff, and `notes/league-rules.md`.

**Verdict:** Accept after one fix. The count, outs, runners, score and batter-up held in every case I tried. One real bug can wipe the “Is the game over?” question, and two suggested defaults are wrong against the official scoring rules.

`swift test` in `app/Packages/ScorebookCore`: every test passes.

## Checked by hand and found correct

I ran these through a throwaway test, since deleted:

- A run that crosses home before a third out on a double play off a fly ball counts, because the play says it scored. The half-inning ends.
- A bases-loaded walk after a pinch runner: the run goes to the pinch runner, the original pitcher is still charged, and the batter gets one run batted in.
- Pitching change at 3-1, then ball four: the walk, the batter faced and the runner all belong to the first pitcher. At 2-2, then two balls: they belong to the new pitcher. Pitch counts split correctly.
- A designated non-runner singles in the first inning before any out: the suggested runner is the ninth hitter.
- Time limit passes in the top half with the home team ahead: the question is asked when the top half ends. A tie at the limit: asked after the full inning.
- Run rule: asked after six and a half with the home team up 12. Not asked after six full innings.
- An edit that removes a runner: later plays naming that runner are marked for review, their run is not counted, and nothing crashes.
- Bases-loaded walk-off walk: the question is asked.

## Findings, worst first

1. **Replay.swift:203 (and 211–216).** An automatic out counts as play, so it clears an unanswered “Is the game over?” question and ends the changeover. The handoff tells the wiring job to record that out straight away. So when a batting hole leads off a half-inning, the run-rule or time-limit question raised by the third out disappears before the scorer sees it. I confirmed this: up 12-0 after six and a half, with a hole leading off, the question was gone. **Fix:** do not let an automatic out clear the question, the changeover or the defense check. Either take it out of `isPlay` or skip those three resets for it. Add a test.

2. **Suggestions.swift:201 vs 148.** The engine treats a 6-4-3 ground ball with a runner on first as a double play even when the scorer did not mark it one. But the runs-batted-in default only recognizes a double play the scorer marked. With the bases loaded and nobody out, an unmarked 6-4-3 suggests one run batted in. Official rule 9.04(b)(1) says none. **Fix:** use the same double-play test in both places.

3. **Suggestions.swift:116–118 and 178–192.** On a game-ending double or triple, the batter is moved back to the base the winning run needed, but the play is still saved as a double or triple. Rule 9.06(f) credits only a single in that case, so the box score will show the wrong hit. **Fix:** have the suggestion also return the corrected hit, which needs a new field on `RunnerSuggestion` (the lead builder decides). Or have the replay save the hit to match the batter’s base when the hit ends the game.

4. **Suggestions.swift:199–200.** The default gives no runs batted in on any error. Rule 9.04(a)(3) gives one when there are fewer than two outs and the runner from third would have scored anyway. The scorer can correct it, so this one is minor. **Fix:** count the runner from third when there are fewer than two outs.

5. **Suggestions.swift:134.** On a fly-ball double play, the suggestion always doubles off the lead runner. On an 8-3 double play with runners on first and third, it puts out the runner on third, though the first baseman’s putout means the out was at first. **Fix:** choose the runner whose base the last fielder covers (the first baseman means first base), and otherwise the runner on first.

6. **The hard-walk-off-single-bases-loaded disagreement: the engine is right.** `Model/Situation.swift` says the question is cleared once the game is final, and the screens show any question that is set. The test writer should change that scenario’s final check to `isGameOverQuestionOpen: false`. Its checkpoint after e3 already covers the question.

7. **The handoff’s judgment calls are all sound.** That includes letting an unanswered question lapse, treating an inning started past the limit as the last inning, the order the reasons are asked in, the manual-adjustment runners, counting batters faced, and the notation. The lapse rule should not apply to automatic outs (finding 1).

8. **Minor.** There is no batter’s-interference event. Recorded as an out to the catcher on a ball in play, it counts a pitch and a strike, which is acceptable.

9. **Speed, scope and comments are fine.** A whole game replays in about 1.5 ms in an optimized build, so an older iPhone has plenty of room. Only the engine folders, its tests and its handoff changed. The comments are clear enough for a beginner.
