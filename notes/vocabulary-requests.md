# Requests to change the shared vocabulary

Builders may not edit `Model/` or `SampleData/`. They write requests in their handoff notes, and the lead builder collects them here and makes them in one pass before the wiring job.

## Open

- **Storage:** add a way to list backups to the storage interface, for a restore screen; make the in-memory stand-in pick the game in progress the same way real storage does.
- **Box score printer:** let the box score picture’s previews read `SampleData`, so the app does not ship JSON copies of the sample box scores.
- **Box score printer:** the box score has nothing to print these from: the winning and losing pitcher, which pitcher hit each batter, who ran for a designated non-runner, and how long the game took (first pitch to the end of the game). Earned runs stay out, by plan.
- **Box score printer:** newspaper footnotes for pinch hitters (“a-struck out for Collins in the 4th”) need the box score to record, for each substitute, the inning they entered and what they did there.
- **Stats (optional):** a separate runner-action reason for “picked off while trying to steal,” which official scoring counts as caught stealing; test-file checks for batting order and positions.
- **Stats:** a pinch hitter who enters with two strikes and strikes out: official scoring charges the strikeout and the at-bat to the batter they replaced. The play log should say which batter is charged, and the rules engine fill it in.
- **Stats:** a strikeout with the runner thrown out stealing on the same pitch is officially a double play; today it is two separate events, so the double-play count misses it.
