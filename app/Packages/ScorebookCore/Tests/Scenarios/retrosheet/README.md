# Real games from Retrosheet

Three complete Major League games, every pitch and play, turned into scenario files. The expected stats in each are the official box score.

The information used here was obtained free of charge from and is copyrighted by Retrosheet. Interested parties may contact Retrosheet at “www.retrosheet.org”.

## The games

| File | Game | What it exercises |
|---|---|---|
| `2019-04-21-royals-at-yankees` | Kansas City 6 at New York Yankees 7, ten innings | Extra innings; pitching changes in the middle of the eighth and tenth; a pinch runner picked off and caught stealing; a run on a passed ball; a sacrifice bunt; a hit batter; a walk-off single. Designated hitters bat without fielding. |
| `2019-05-08-mets-at-padres` | New York Mets 2 at San Diego 3 | No designated hitter: pitchers bat, pinch hitters for pitchers, a double switch by each team, a pinch runner. The Padres lead after the top of the ninth and do not bat in it. An error and a wild pitch. |
| `2019-06-23-astros-at-yankees` | Houston 9 at New York Yankees 4 | A pitching change in the middle of the fifth; four ground-ball double plays; defensive indifference; a triple; five home runs. |

## Files

- `convert.py`: the converter. Python 3 with nothing to install. `python3 convert.py NYA201904210 2019-04-21-royals-at-yankees` writes the scenario file. The comments at the top explain how a Retrosheet play line becomes our events.
- `games/<GAME>.txt`: one game’s lines from Retrosheet’s event file for that team and season, copied as they are.
- `games/<GAME>-box.txt`: the official box score, typed in by hand from Retrosheet’s box score page for the game. The format is explained at the top of the first one.

## What the expected values are

The stats come from the official box score: each batter’s plate appearances (at-bats, walks, hit by pitch and sacrifices added up), at-bats, runs, hits, doubles, triples, home runs, runs batted in, walks, strikeouts, stolen bases and caught stealing; each pitcher’s outs, batters faced, hits, runs, walks, strikeouts, home runs and hit batters; each fielder’s putouts, assists and errors; and each team’s runs, hits, errors, runners left on base, line score and double plays. Earned runs are left out, since the scorebook does not keep them. Pitch counts are left out too, since the official box score does not give them.

A batter gets expected numbers only if they held a spot in the batting order, and a fielder only if they played a position, because those are the players our box score has lines for. A designated hitter has no fielding line, and a pitcher who did not bat has no batting line.

## One known difference

In the Mets game, the Mets’ only double play is a strikeout and a pickoff on the same pitch (Retrosheet `K+PO1(23)/DP`). Our events record that as the strike-three pitch and then a pickoff, two separate events, and nothing in the vocabulary can mark them together as one double play. The official box says one double play, so the scenario expects one, and a box score built from these events will show none until the vocabulary can say so. Every other number in all three games matches the official box score when the events are added up by hand.

## What the converter does not handle yet

It stops with a message naming the problem on: dropped third strikes, a walk or hit by pitch with runners taking extra bases on the same pitch, intentional walks thrown as four pitches, pitch-clock violations (from 2023), interference and obstruction, appeals, and anything else it cannot read. All three games here were chosen from 2019, after intentional walks stopped being pitched and before the pitch clock and the extra-inning runner on second.
