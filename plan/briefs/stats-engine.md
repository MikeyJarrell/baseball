# Stats engine

**Role:** stats builder.

**Waits on:** foundation.

**Owns:** `ScorebookCore/Sources/Stats/` and `ScorebookCore/Tests/StatsTests/`.

**Reads:** `Model/`, `SampleData/`, `Tests/Scenarios/`. Stats are computed from the rules engine’s play log. Until the engine lands, build and test against the hand-written play log in `SampleData`; after it lands, run the scenario files through the engine in your tests.

## Deliver

The real version of the stats interface in `Model/`:

1. **Box score for one game.** A batting line for every player who batted, in batting order with substitutes under the player they replaced: plate appearances, at-bats, runs, hits, doubles, triples, home runs, runs batted in, walks, strikeouts, hit-by-pitches, sacrifice flies, sacrifice bunts, stolen bases, caught stealing. A pitching line for every pitcher: innings pitched (as outs recorded, shown as 5.1 for five and a third), hits, runs, walks, strikeouts, home runs, hit batters, batters faced, pitches, strikes. Runs are charged to the pitcher responsible for the runner who scored, which the play log records, so a reliever who inherits a runner is not charged when that runner scores. Errors for each fielder; putouts and assists by position until the league question about free substitution in the field is answered. The line score by inning. The notes underneath: doubles, triples, home runs, runs batted in, stolen bases, errors, double plays, runners left on base.
2. **Season totals** from a list of games: batting and pitching. The same counting stats summed per player, plus batting average, on-base percentage and slugging percentage for hitters, innings pitched, strikeouts and walks per inning, and walks and hits per inning for pitchers, and each player’s game-by-game log.
3. **A player’s plate appearances in one game**, in scorebook notation, for the batter history on the batting screen.

## Scoring rules

Follow the official scoring rules of Major League Baseball (Official Baseball Rules, rule 9). The ones most often gotten wrong:

- At-bats exclude plate appearances that end in a walk, hit-by-pitch, sacrifice fly, sacrifice bunt or catcher’s interference.
- Reaching on an error or a fielder’s choice counts as an at-bat with no hit.
- No run batted in on a ground-ball double play, or for a run that scores on an error that the batter’s play would not otherwise have scored.
- A bases-loaded walk or hit-by-pitch is a run batted in.
- A strikeout is charged to the batter even when the batter reaches on a dropped third strike.
- Runs batted in come from the play, which stores the final number the scorer confirmed. Stats never recompute them.

Earned runs need judgment about which runs errors caused, so pitching lines carry runs only.

Our players are matched across games by player id. Opponent players appear in single-game box scores and are left out of season totals.

## Finish line

Every scenario with stats expectations passes. The box score for the complete game in `SampleData` matches the hand-written one exactly. Batting average, on-base and slugging match hand calculations for a three-game sample, including a player with no at-bats (shown as “.000” or a dash, never a crash from dividing by zero).
