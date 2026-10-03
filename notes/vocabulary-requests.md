# Requests to change the shared vocabulary

Builders may not edit `Model/` or `SampleData/`. They write requests in their handoff notes, and the lead builder collects them here and makes them in one pass before the wiring job.

## Open

- **Storage:** add a way to list backups to the storage interface, for a restore screen; make the in-memory stand-in pick the game in progress the same way real storage does.
- **Box score printer:** let the box score picture’s previews read `SampleData`, so the app does not ship JSON copies of the sample box scores.
- **Box score printer:** the box score has nothing to print these from: the winning and losing pitcher, which pitcher hit each batter, who ran for a designated non-runner, and how long the game took (first pitch to the end of the game). Earned runs stay out, by plan.
