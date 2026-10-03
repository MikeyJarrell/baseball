# Game overview

**Role:** screen builder.

**Waits on:** foundation; mockup approval. Needs Xcode.

**Owns:** `ScorebookUI/Sources/GameOverview/`.

**Reads:** `Model/`, `SampleData/`, `DesignSystem/`, the approved mockups.

## Deliver

The screen a swipe away from the batting screen, for checking on the game without changing it.

1. **Line score** by inning, with runs, hits and errors.
2. **Box score so far** for both teams, with today’s plate appearances for each batter in scorebook notation.
3. **Pitchers:** every pitcher who has thrown today with pitches, strikes, batters faced and their line so far.
4. **Play-by-play:** every event in order, newest first, grouped by half-inning. Tapping one lets the scorer edit or delete it; the screen hands back the change, and everything after it recalculates.

## Finish line

Previews using the complete game in `SampleData`, and a game in the third inning. The play-by-play stays smooth with 400 events.
