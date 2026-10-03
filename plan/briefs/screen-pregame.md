# Pregame screens

**Role:** screen builder.

**Waits on:** foundation; mockup approval. Needs Xcode.

**Owns:** `ScorebookUI/Sources/PregameScreens/`.

**Reads:** `Model/`, `SampleData/`, `DesignSystem/`, the approved mockups.

## Deliver

A short sequence that ends in a game setup, handed back to the app.

1. **The game:** opponent (picked from saved teams or new), date, home or away, scheduled innings (nine by default), scheduled start (9:00 AM by default), and the time limit as a clock time (three hours after the start), editable.
2. **Our lineup:** three lists. The batting order, any number of hitters, dragged into order, with up to two marked designated non-runners. The nine fielders, each position filled by anyone on the roster, whether or not they bat. The bench, everyone else, with a clear way to move a player between lists. Starts from the last game’s lineup.
3. **Their lineup:** three choices: full names and numbers from their saved roster, numbers only, or unknown. Unknown still asks how many hitters they bat (nine by default) and fills each slot with a placeholder (“Batter 1”, “Batter 2”) that the scorer names when that hitter comes up, so the order knows when to go back to the top.
4. **Starting pitchers:** each team’s, with throwing hand. Ours lists whoever pitched most recently first; theirs comes from their saved roster.
5. **Review and play ball.**

## Finish line

Previews for a game against the full-roster opponent, the numbers-only opponent and an unknown lineup. Setting up a game against a saved opponent, starting from last game’s lineup, takes under a minute in the simulator.
