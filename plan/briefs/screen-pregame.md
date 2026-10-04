# Pregame screens

**Role:** screen builder.

**Waits on:** foundation; mockup approval. Needs Xcode.

**Owns:** `ScorebookUI/Sources/PregameScreens/`.

**Reads:** `Model/`, `SampleData/`, `DesignSystem/`, the approved mockups.

## Deliver

A short sequence that ends in a game setup, handed back to the app.

1. **The game:** opponent (picked from saved teams or new), date, home or away, scheduled innings (nine by default), scheduled start (9:00 AM by default), and the time limit as a clock time (three hours after the start), editable. Both times are set on the iOS time wheel, to any minute.
2. **Our lineup,** in two steps. First the batting order: any number of hitters, dragged into order, with up to two marked designated non-runners, and the bench, everyone else, with a clear way to move a player in or out of the order. Then the fielders, on the field drawing: tap a position on the diamond and pick the player from a list, anyone on the roster, whether or not they bat. On the fielding step, a position can be marked as alternating between two players by inning (one in odd innings, the other in even), and the defense check then pre-fills the right one each time we take the field. Starts from the last game’s lineup. Before the first game, it starts from the roster instead: each player at their usual position, the leadoff hitter first, and players who usually start on the bench on the bench.
3. **Their lineup:** two choices: full names and numbers from their saved roster, or numbers only. With names and numbers, each player’s jersey number can be typed in their row. With numbers only, the scorer types each hitter’s number in batting order; a blank becomes a placeholder (“Batter 4”) named when that hitter comes up. Either way the order drags into place, and typed numbers are saved back to that opponent’s roster.
4. **Starting pitchers:** each team’s, with throwing hand. Ours lists whoever pitched most recently first; theirs comes from their saved roster.
5. **Review and play ball.**

## Finish line

Previews for a game against the full-roster opponent, the numbers-only opponent and an opponent with no saved roster. Setting up a game against a saved opponent, starting from last game’s lineup, takes under a minute in the simulator.
