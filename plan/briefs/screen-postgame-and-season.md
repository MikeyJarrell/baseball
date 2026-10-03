# Postgame and season screens

**Role:** screen builder.

**Waits on:** foundation; mockup approval. Needs Xcode.

**Owns:** `ScorebookUI/Sources/PostgameScreens/`.

**Reads:** `Model/`, `SampleData/`, `DesignSystem/`, the approved mockups.

## Deliver

1. **End of game:** final score, the box score, and a share button. The picture and the share sheet come from the box score printer’s module during wiring; until then, show the box score data in a plain table.
2. **Games list:** every game, newest first, with date, opponent and result. Tapping one opens its box score.
3. **Season stats:** our players in a table with games, plate appearances, at-bats, hits, doubles, triples, home runs, runs batted in, walks, strikeouts, batting average, on-base and slugging. Sort by any column. A minimum plate appearances filter for the rate stats. Pitching table alongside.
4. **Player page:** season line and game-by-game log.

## Finish line

Previews using `SampleData` totals for a twelve-player team, a player with no at-bats, and a season with one game. The season table reads well on the smallest current iPhone, scrolling sideways with the name column fixed.
