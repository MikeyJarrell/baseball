# Test scenarios

**Role:** test writer.

**Waits on:** foundation (for the JSON format and the first twenty hard scenarios). Start this job alongside the rules engine, so the engine has scenarios to check against early.

**Owns:** `ScorebookCore/Tests/Scenarios/`.

**Reads:** `Model/`, `SampleData/`, the scenario file the foundation job wrote as a pattern.

## Deliver

A library of short game situations, each a JSON file holding: a one-line description in plain English, a starting setup, a list of events, the expected situation afterward (outs, count, runners, score, batter up, pitch counts), and where it applies, the expected stats (at-bats, hits, runs batted in, pitcher’s line). The rules engine and stats builders run their code against all of them.

Cover, at least:

- Walk with bases empty; with a runner on first; with runners on first and third (the runner on third holds); bases loaded (a run scores, a run batted in).
- Strikeout swinging, looking, and on a foul bunt; a foul with two strikes leaving the count alone.
- Groundouts 6-3, 4-3, 3 unassisted; fly outs to each outfielder; a pop-up to the catcher.
- Double plays 6-4-3, 5-4-3, 4-6-3; a line-drive double play; a triple play.
- Singles, doubles, triples and home runs with every combination of runners on; a grand slam.
- Sacrifice fly; sacrifice bunt; fielder’s choice with the lead runner out at second; reaching on an error and a runner scoring on it (no run batted in).
- Steals, caught stealing, pickoff, wild pitch, passed ball, balk.
- The third out made on the bases mid-at-bat; the same batter leads off next inning.
- Pitching change mid-at-bat: pitches before and after go to the right pitchers; a walk after a change at 3-1 belongs to the first pitcher.
- Inherited runners: a reliever comes in with a runner on second who later scores; the run is charged to the first pitcher.
- Foul tip for strike three; dropped third strike with the batter thrown out and with the batter reaching.
- The runner for a designated non-runner who scores (the run goes to the designated non-runner) and one who steals second (the steal goes to the runner); a pinch runner who scores (the run goes to the pinch runner); a designated non-runner who chooses to run; the runner for a designated non-runner being the player who made the last out; a single with the batter taking second on an error (a hit, an error, no extra hit); a starter re-entering the game.
- Fielders switching positions mid-game, with a later error charged to the right player.
- An error with no runner moving.
- An opponent with an unknown lineup cycling back to the top.
- A pinch hitter, a pinch runner, a defensive switch.
- A lineup of nine grown to eleven mid-inning, while the ninth hitter is batting; the order cycling through all eleven.
- A walk-off in the bottom of the last inning; extra innings; a home team that does not bat in the last inning.
- Undo after each kind of event.

## Real games

Retrosheet publishes free pitch-by-pitch records of Major League games in a documented text format. Write a converter, a script kept in `Tests/Scenarios/retrosheet/`, that turns one Retrosheet game into our event list, and convert three complete games, including one with a pitching change mid-inning and one with extra innings. Record each official box score as the expected stats. If the official box and our result disagree, the official box is right unless it involves earned runs. Write down the game and source in the scenario’s description.

## Finish line

Each scenario’s expected values are checked by hand, and a second reader has checked ten of them chosen at random. Every file decodes with the `Model` types. When the rules engine disagrees with a scenario, the official rules settle it; when they are unclear, the lead builder decides. Retrosheet’s data is free with a credit line, which goes in the converter’s comments.
