# Game rules engine

**Role:** rules engine builder.

**Waits on:** foundation.

**Owns:** `ScorebookCore/Sources/GameEngine/` and `ScorebookCore/Tests/GameEngineTests/`.

**Reads:** `Model/`, `SampleData/`, `Tests/Scenarios/`.

## Deliver

The real version of the rules-engine interface in `Model/`:

1. **Situation and play log from events.** Given a game’s setup and its events, return the situation after the last one and the play log (one record per event; see [architecture.md](../architecture.md)). It must be fast enough to replay a whole game after every tap; a nine-inning game is about 300 events. When an event no longer makes sense after an earlier one was edited (a runner who is no longer on base), mark it as needing review in the play log and carry on; never crash.
2. **Suggested runner outcomes.** Given the situation and what happened to the batter, propose where every runner ends up and how many runs batted in, for the in-play screen to show the scorer. A runner the scorer moves past the suggestion advanced on the throw or on an error; on a hit, the batter keeps the hit and the extra base is charged as an error (“1B 7, E7”).
3. **Play preview.** For a play the scorer is still entering, its notation so far and the outs and runs it would produce, and whether it ends the inning or the game.
4. **Scorebook notation** for any event, including the hit location when the scorer gave one (“1B 7” for a single to left).

## Rules to apply

- Four balls is a walk; three strikes is a strikeout. A foul with two strikes leaves the count alone, except a foul bunt or a foul tip, which is strike three.
- Walks, hit-by-pitches, intentional walks and catcher’s interference move the batter to first and push forced runners up one base, and no one else.
- A third out ends the half-inning: clear the bases, reset the count, switch sides. Each team picks up its batting order where it left off.
- If the third out is a runner (caught stealing, pickoff) while a batter is mid-count, that batter leads off the next inning with a fresh count.
- The batting order wraps after its last slot, whatever the number of slots. When a hitter is added to the bottom mid-game, the order includes them from that point on; if the last hitter in the old order just batted, the new hitter is up next.
- Pitches and strikes count against the pitcher on the mound at the moment. Fouls and balls in play count as strikes; a hit-by-pitch counts as a pitch and not a strike; an intentional walk counts no pitches.
- Every runner carries the pitcher responsible for putting them on base. A runner who reaches on a fielder’s choice that retires a runner takes over the retired runner’s responsible pitcher (Official Baseball Rules 9.16(g)). A batter who walks after a pitching change made with the count at 2-0, 2-1, 3-0, 3-1 or 3-2 belongs to the earlier pitcher (rule 9.16(h)).
- The runner for a designated non-runner takes the base without changing the batting order; the original player stays in the slot and is credited with the run if the runner scores.
- The engine always knows which of our players is at each fielding position, from the starting positions plus every substitution, so every out and error is tied to a player. The situation flags when a designated non-runner has just reached base, with a suggested runner: the batting team’s player who made the most recent out. The non-runner may also run themselves, which records nothing.
- Runs come only from what the play says scored; the engine never decides on its own whether a run counted.
- The manual adjustment event overrides whatever it sets.
- Time limit (league rule 9.1): no new inning begins once the limit passes. The limit is three hours after the first pitch unless the scorer sets it. The situation reports time left, “finish this inning” once the limit passes mid-inning, and “game over on time” when that inning ends, or after its top half if the home team leads. A tie at the limit stays a tie; a tie after nine with time left goes to extra innings. The scorer ends the game.
- Mercy rule (9.13): a 12-run lead at the end of seven innings, or after six and a half with the home team ahead, is reported as game over (15 runs in a championship game).
- A batting hole is an automatic out each time its spot comes up.
- The suggested runner for a designated non-runner (9.11) is the last recorded out; in the first inning before any out, the last batter in the order; when the last recorded out is now batting, the last recorded out before them.
- Re-entry eligibility (9.6, 9.9, 9.12): a starter may re-enter in the original spot once their substitute has batted; a removed substitute may not; a removed pitcher may pitch again once per game. The engine reports eligibility and blocks nothing.
- See [notes/league-rules.md](../../notes/league-rules.md) for every league rule and its number.
- Regulation is complete when the scheduled innings are done and the score is not tied, or when the home team leads after the top half of the last scheduled inning, or when the home team goes ahead in the bottom of the last inning or later. The engine reports it; the scorer ends the game.

## Suggested runner outcomes

- Single, double, triple: every runner moves up as many bases as the batter, a runner who would pass home scores. Home run: everyone scores.
- Ground out marked by the scorer as a double play, or with three or more fielders and a runner on first: the lead forced runner out at second, the batter out at first. Otherwise forced runners move up one and the batter is out.
- Fly out or line out: runners hold. Sacrifice fly: the runner on third scores.
- Fielder’s choice: the lead forced runner is out, the batter is on first.
- Error: batter safe at first, runners up one.
- Anything else: runners hold.
- A game-ending hit in the bottom of the last inning or later: only the winning run scores, and the batter gets only as many bases as that took, except on a home run.
- Runs batted in: the default follows the official scoring rules (see the stats brief); the scorer can change it, and the play stores the final number.

The scorer confirms or corrects every one of these.

## Finish line

Every scenario in `Tests/Scenarios/` that covers the situation passes. When a scenario and the engine disagree, check the official rules; if the scenario is wrong, tell the test writer, and if the rules are unclear, the lead builder decides. Tests also cover: a complete nine-inning game whose final score and pitch counts are checked by hand; a lineup of eleven that grows to thirteen in the fifth; an inning ending on a caught stealing; undo (dropping the last event gives back the earlier situation); and editing an event in the middle of a game.
