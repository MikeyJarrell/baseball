# Test scenarios: handoff

**Job:** test writer.

**Branch:** `codex/test-scenarios`, in the task folder `/Users/mikey/projects/.worktrees/baseball/test-scenarios`.

## What exists now

Sixty-seven new scenario files in `app/Packages/ScorebookCore/Tests/Scenarios/`, on top of the foundation’s thirty-nine, for 106 in all:

- **Forty-eight short situations** at the top of the folder, one game situation each.
- **Sixteen undo scenarios** in `undo/`, one for each kind of event. Its README explains the pattern: the last event is the one undone, and a checkpoint after the event before it says what the game must look like once it is gone.
- **Three complete Major League games** in `retrosheet/`, every pitch and play, with the official box scores as the expected stats, plus the converter that made them (`retrosheet/convert.py`, Python 3 with nothing to install) and a README.
- **One new shared setup**, `setups/two-designated-non-runners`: the standard game with Moreno and Quinn both declared designated non-runners.

No existing file was changed. `swift test` in `app/Packages/ScorebookCore` passes: 41 tests in 4 suites, including the ones that decode every scenario file, check every named player is on a roster, and check event ids are unique.

## The brief’s list, and where each item is

| Brief item | Files |
|---|---|
| Walks: bases empty, runner on first, first and third (runner holds), bases loaded | `walk-bases-empty`, `walk-runner-on-first`, `walk-runners-on-first-and-third`; bases loaded was already `hard-bases-loaded-walk` |
| Strikeouts swinging, looking, on a foul bunt; a foul with two strikes | `strikeout-swinging`, `strikeout-looking`, `strikeout-on-foul-bunt`, `foul-with-two-strikes-leaves-count` |
| Groundouts 6-3, 4-3, 3 unassisted; fly outs to each outfielder; pop-up to the catcher | `pattern-6-3-groundout` (existing), `groundout-4-3`, `groundout-first-baseman-unassisted`, `fly-outs-to-each-outfielder`, `pop-up-to-catcher` |
| Double plays 6-4-3, 5-4-3, 4-6-3, line drive; triple play | `double-play-6-4-3`, `double-play-4-6-3`, `line-drive-double-play`; 5-4-3 and the triple play were already there |
| Every hit with every arrangement of runners; a grand slam | `hits-singles-every-base-situation`, `hits-doubles-…`, `hits-triples-…`, `hits-home-runs-…` (eight hits each, one per arrangement, with a checkpoint after each), `grand-slam` |
| Sacrifice fly, sacrifice bunt, fielder’s choice at second, error with a run and no run batted in | `sacrifice-fly`, `sacrifice-bunt`, `fielders-choice-lead-runner-out-at-second`, `error-lets-runner-score-no-rbi` |
| Steal, caught stealing, pickoff, wild pitch, passed ball, balk | `stolen-base-second`, `caught-stealing-second`, `pickoff-at-first`, `wild-pitch-runner-scores`, `passed-ball-runners-move-up`, `balk-moves-every-runner` |
| Pitching change in the middle of a batter | `pitching-change-at-1-2-then-strikeout`, `pitching-change-at-1-1-then-walk`, `pitching-change-at-2-1-then-single`; the 3-1 walk was already there |
| Inherited runners | `inherited-runner-on-second-scores-later`, `fielders-choice-keeps-first-pitchers-runner` (Official Baseball Rules 9.16(g)) |
| Runner for a designated non-runner who steals second; who is the last recorded out; a pinch runner who scores; a designated non-runner replaced by a pinch runner | `designated-non-runner-runner-steals-second`, `designated-non-runner-last-out-runs-and-scores`, `pinch-runner-scores`, `designated-non-runner-pinch-runner-leaves-order` |
| A single with the batter taking second on an error | `single-batter-takes-second-on-error` |
| Fielders switching positions, a later error charged to the right player; a pinch hitter; a defensive replacement | `position-switch-then-error`, `pinch-hitter-then-takes-the-field`, `defensive-replacement-takes-batting-spot` |
| A hit by pitch | `hit-by-pitch-forces-runner` |
| Nine hitters grown to eleven while the ninth bats, cycling through all eleven | `lineup-grows-to-eleven-and-cycles` |
| Walk-off, extra innings, home team not batting in the last inning | `walk-off-home-run`, `extra-innings-visitors-win-in-tenth`, `home-team-does-not-bat-in-last-inning` |
| A batting hole out each time it comes up | `batting-hole-out-each-time-around` |
| Undo after each kind of event | the sixteen files in `undo/` |
| Three real games, one with a pitching change mid-inning and one in extra innings | `retrosheet/2019-04-21-royals-at-yankees` (ten innings, three pitching changes in the middle of an inning), `retrosheet/2019-05-08-mets-at-padres`, `retrosheet/2019-06-23-astros-at-yankees` |

Items already covered by the foundation’s files (the error with nobody moving, foul tip and dropped third strikes, the starter re-entering, the unknown lineup, the time limit and the run rule, the suggested runner in the first inning and when the last out is now batting, the third out on the bases mid-at-bat) were not written again.

## How the expected values were checked

Every value in the forty-eight situations and the sixteen undo files was worked out by hand against the Official Baseball Rules and the league rule book as each file was written. Two further checks followed:

- **A separate tally.** A scratch script outside the repository replays a scenario’s events my own way and compares what it understands (outs, count, score, runners and who is charged with them, batter, pitch counts, batting spots, fielders, and the box score numbers). It agrees with all 106 files, the foundation’s included, apart from the Mets double play described below. One slip of mine, the running score after five home runs in `hits-home-runs-every-base-situation`, was caught on the hand recheck before the tally ran.
- **A second reading of ten files chosen at random** (a fixed random draw from the sixty-four hand-built files): `defensive-replacement-takes-batting-spot`, `stolen-base-second`, `undo/undo-time-limit-change`, `balk-moves-every-runner`, `hits-singles-every-base-situation`, `walk-runner-on-first`, `error-lets-runner-score-no-rbi`, `undo/undo-pitch`, `pitching-change-at-1-1-then-walk` and `hit-by-pitch-forces-runner`. Each was reread from the JSON against the rules, including rule 9.04 on runs batted in after an error, rule 9.16(h) on which pitcher a walk belongs to, and league rules 9.1 G and 9.9. All ten stand as written.

A reviewer who did not write these should still do the review the standing orders ask for; the second reading above was mine.

## The real games

The event text comes from Retrosheet’s event files for the 2019 Yankees and Padres, read as plain text from the Chadwick Bureau’s copy of Retrosheet’s files on GitHub (Retrosheet itself offers event files only as zip archives). One game’s lines were copied into `retrosheet/games/<GAME>.txt`. The box scores were typed in by hand from each game’s page on retrosheet.org into `retrosheet/games/<GAME>-box.txt`. Retrosheet’s credit line is in the converter’s comments, both READMEs, every box file and each scenario’s `source`.

All three games come from 2019, a season with intentional walks awarded without pitches, no pitch clock, and no runner placed on second in extra innings. Each setup turns off the time limit and the run rule (`timeLimitMinutes` and `runRuleMargin` are `null`), and neither team is ours.

The expected stats are the official box score: batting, pitching (outs, batters faced, hits, runs, walks, strikeouts, home runs, hit batters), putouts, assists and errors, and each team’s runs, hits, errors, runners left on base, line score and double plays. Earned runs and pitch counts are left out. The separate tally matches the official box on every number but one, below. It also confirms that official runners left on base include the runners stranded by a walk-off, as Model defines it.

## Vocabulary change requests

- **A strikeout and a runner out on the same pitch, as one double play.** In the Mets game the catcher picks a runner off first right after strike three, and the official box counts a double play (Retrosheet `K+PO1(23)/DP`; the same happens with a strikeout and a runner caught stealing). The vocabulary records it as the strike-three pitch and then a pickoff, two events, and only a ball in play can carry `multiOut`. Request: a way to mark the pair, such as an optional `multiOut` on the runner action that follows a strike three, or on the strike-three pitch. Workaround: none; the scenario keeps the official double play, so `retrosheet/2019-05-08-mets-at-padres` will report one Mets double play missing until this is decided.
- **Catcher’s interference.** `BatterResult.catchersInterference` exists, but nothing says whether the catcher’s error goes in the play’s `errors` (the official rules charge one). I wrote no scenario for it. A sentence in `Model/Play.swift` would settle it.
- **A missed bunt attempt** is recorded as a swinging strike, which counts the same. No change needed; noted because the converter maps Retrosheet’s `M` that way.

## Problems found in the foundation’s files

- **`hard-walk-off-single-bases-loaded` contradicts Model.** Its final expectation has `gameOverQuestion: regulation` together with `isFinal: true`, but `Situation.gameOverQuestion` says the question is “Cleared once the game is final.” My `undo/undo-end-of-game` follows Model and expects the question cleared after the end of the game, so no engine can pass both. The lead builder should decide which is right and change the other file. My other files that end a game check the question only before the end-of-game event.
- **`Tests/Scenarios/README.md`** describes only the foundation’s files. It needs a paragraph on the new ones, the `undo/` pattern and `retrosheet/`; I could not edit it.
- **`tie-at-time-limit`**’s description has a capital letter after a comma (“nobody scores, After the top half”). Cosmetic.

## For the rules engine and stats builders

- **Notation pinned for the first time:** `4-3`, `3U`, `F7`, `F9`, `P2`, `P6`, `6-4-3 DP`, `4-6-3 DP`, `L4-3 DP`, `2B 8`, `3B 9`, `SF 9`, `SH 1-3`, `FC 6-4`, `E6`, `HBP`, `IBB`, `SB2`, `CS2 2-6`, `HR 7`, `ꓘ`, and `1B 7, E7` for a single with the extra base on an error (the form architecture.md and the rules engine brief both give). Pickoffs, wild pitches, passed balls, balks, defensive indifference and a strikeout on a foul bunt have no settled notation, so no file pins one.
- **Conventions followed from the foundation’s files:** a pitcher’s `battersFaced` in the situation counts finished plate appearances charged to them, so a reliever who walks a batter on a count that belongs to the first pitcher shows none; runners placed by a manual adjustment are charged to the pitcher on the mound; runs set by a manual adjustment go in the line score in the inning it leaves the game in.
- The four `hits-…-every-base-situation` files place runners with a manual adjustment before each hit, using players who have already batted, so one player can score several runs in one inning. That is intended.
- The real games are long (276 to 371 events). They are the place to test speed as well as answers.
