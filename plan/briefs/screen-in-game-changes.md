# In-game changes

**Role:** screen builder.

**Waits on:** foundation; mockup approval. Needs Xcode.

**Owns:** `ScorebookUI/Sources/GameChanges/`.

**Reads:** `Model/`, `SampleData/`, `DesignSystem/`, the approved mockups.

## Deliver

The sheets that slide up from the batting screen for anything other than a pitch or a ball in play. Each one is handed the situation and the relevant team’s batting order and roster, and hands back one event or a cancel.

1. **Pitching change.** Choose the new pitcher from the fielding team’s roster or add a new player, with throwing hand. Shows the outgoing pitcher’s pitch count.
2. **Pinch hitter.** Choose who bats in the current slot. Players already taken out of the game appear too, marked as re-entering, since our league allows re-entry.
3. **Pinch runner and courtesy runner.** Tap the runner, choose the replacement. A courtesy runner leaves the batting order as it was.
4. **Defensive changes.** Move players between positions and bring players in from the bench, as one batch.
5. **Add a hitter.** Pick a player from the roster or add a new one, and a position or “extra hitter.” Shows where in the order they will bat and when they will next be up.
6. **Runner actions.** For one or more runners at once (a double steal is one entry): stolen base, caught stealing, pickoff, wild pitch, passed ball, balk, advance on error, out on appeal. Where a fielder made the out, tap the fielders, as in the in-play sequence. A wild pitch or balk moves every runner, so it shows every runner with the suggested result and lets the scorer change any of them.
7. **Error with no advance.** Tap the fielder; nothing else changes.
8. **Manual adjustment.** Set outs, count, score and runners directly, with a warning that it overrides the book.
9. **Their batter.** Name, number and batting side for an opposing hitter, editable at any point.

## Finish line

Previews and simulator demos for each sheet using `SampleData`, including adding a tenth and eleventh hitter while the ninth is batting, and a pitching change mid-count.
