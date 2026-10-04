# Vocabulary pass: review

**Reviewer:** a fresh builder who did not do the pass. Reviewed `git diff origin/main...HEAD` on `codex/vocabulary-pass` (commit 6961b46).

**Verdict:** accept after fixing findings 1 and 2; nothing breaks the other builders, and every test and build passes.

**Checked:** `swift test` in ScorebookCore passes with no failures. The ScorebookUI tests pass (six of six) and the package builds with no warnings. The app builds for the iPhone 17 simulator. Throwaway copies of this branch merged with `codex/screen-play-entry`, `codex/screen-in-game-changes` and the walk-up audio builder’s unsaved work each merged cleanly and built. `codex/screen-at-bat` is already in main.

## Findings, worst first

1. **`GameEngine/Replay.swift:170` and `:372`: a walk-off hit’s notation disagrees with its credit.** The notation is worked out from the saved hit before the credit is cut down. Run on `walk-off-double-credited-as-single`, the last entry reads “2B 8” but counts as a single, so the batter’s history and the footnotes show a double the box score does not count. Fix: build the notation from the credited hit, and test the notation in that scenario.

2. **Nobody is asked to set `completesStrikeoutDoublePlay` or `wasStealing`.** No screen offers either one, and the Open list in `notes/vocabulary-requests.md` does not ask for them, so real games will undercount double plays and caught stealing. The engine also accepts the double-play flag on any runner action, with no check that a strikeout came just before (`Stats/PlayLogReading.swift:138`). Fix: add requests for the in-game changes and batting screens, and count the flag only straight after a strikeout in the same half-inning.

3. **`Stats/BoxScoreExtras.swift:63` and `:92`: a game of three innings or fewer can end with a loser and no winner.** The starter needs 12 outs, and if no reliever pitched, nobody gets the win. Rule 9.17(b) covers only games of five innings, or six or more, in the field. The five-inning requirement for a seven-inning game is correct, and the sample game’s five-inning case is handled right. Fix: if there is no reliever, give the win to the pitcher of record.

4. **Wrong rule number.** Catcher’s interference is an error under 9.12(c), not 9.12(a)(3): `Model/Play.swift:117`, `GameEngine/Replay.swift:381`, the scenario `catchers-interference-error.json`, and the handoff.

5. **`Model/Events.swift:338`: a pickoff while stealing counts as caught stealing only when the runner is out.** Rule 9.07(h) also counts a runner who “would have been put out by errorless play”. This is a rare case; at least note it in the comment.

6. **Screens can now import GameEngine.** A probe `import GameEngine` in `AtBatScreen.swift` built, because SampleData now pulls it in. The rule holds only by convention. Fix: add a test that fails when a screen imports GameEngine, Stats or Storage.

7. **`GameEngine/GameEngine.swift:58-62`: the new batted-ball function is pasted between `notation`’s comment and `notation`.** The notation comment now describes the wrong function. Fix: move it.

8. **Fine as built.** Fielding rotations are suggestions only, and nothing applies them. Both app icons match `plan/mockups/icon/` and are 1024 square with no transparency. The dark icon is filed under the dark appearance.
