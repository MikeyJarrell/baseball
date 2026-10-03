# Stats engine review

**Reviewer:** a fresh builder who did not build the stats job, reviewing `git diff origin/main...HEAD` at commit 88eee80.

**Verdict:** Ready to merge. No stat is added up wrong in the stats code; fix the test switch (finding 2) before the rules engine lands.

## What was checked

`swift test` in `app/Packages/ScorebookCore`: 29 stats tests, 26 pass and 3 are skipped until the rules engine lands; the 41 model tests pass. The branch merges cleanly with the current main. Only `Sources/Stats/`, `Tests/StatsTests/` and the handoff changed. The comments are plain and readable.

Checked against the official scoring rules (rule 9): at-bats against plate appearances, sacrifices, fielder’s choice, reaching on an error, the scorer’s runs batted in, runs charged to the pitcher who put the runner on base, the walk after a mid-count pitching change, innings pitched, putouts and assists (one assist per fielder per out), left on base, the run credited to a designated non-runner, and rates with nothing to divide by. All are right, provided the play log is filled in as the handoff asks. Three cases were also worked through by hand: an inherited runner forced out on a fielder’s choice, a K 2-3 double play, and a walk-off with the bases loaded.

The brief’s finish line is met, except for the scenario tests, which cannot run until there is a rules engine.

## Findings

1. **`Model/PlayLog.swift:219` and `plan/handoffs/stats-engine.md:53–58`: a pinch hitter who comes in with two strikes and strikes out.** Rule 9.15(b) charges that strikeout and at-bat to the batter he replaced. Stats gives the plate appearance to whoever `plateAppearance.batter` names. Nothing in the plan says which batter that should be in this case, so the rules engine could easily get it wrong. Fix: add it to the handoff’s list of what stats needs from the play log, and ask the lead to write it into the comment on `batter`, the way the comment on `pitcher` explains the walk rule.

2. **`Tests/StatsTests/ScenarioEngine.swift:26–30`: a broken engine would show up as skipped tests.** The tests run only when the engine gives one play log entry per event and the pattern file loads. So an engine with a bug that drops or adds entries quietly turns off every scenario test. Fix: skip only while `engine` is `nil`. Once an engine is plugged in, always run the tests.

3. **Who flips the switch.** The one-line switch is written down only in the stats handoff. The rules-engine and wiring briefs do not mention it, so whoever merges the engine may never see it. Fix: ask the lead to add “switch on `ScenarioEngine.engine`” to the rules engine’s finish line or the wiring brief.

4. **`Tests/StatsTests/ScoringRulesTests.swift:136`: no one gets the putout on a batting hole’s automatic out.** So the team’s putouts add up to fewer than the outs its pitchers recorded. The closest official case, a batter called out for batting out of turn, gives the putout to the catcher. Question for Mikey: should the catcher get it?

5. **`Sources/Stats/PlayLogReading.swift:134`: a strikeout with the runner thrown out stealing on the same pitch.** Officially that is a double play. The vocabulary records it as two separate events with one out each, so the double-play note misses it. This is the same kind of gap as the “picked off while trying to steal” case (handoff line 21). Fix: add both to `notes/vocabulary-requests.md`.
