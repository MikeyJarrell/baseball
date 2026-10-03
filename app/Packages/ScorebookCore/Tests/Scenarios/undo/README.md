# Undo scenarios

One file for each kind of event, checking that undo gives back exactly what was there before.

Undo in the app means deleting the last event, so in every file here the last event is the one being undone. The file has a checkpoint after the event before it: that checkpoint is what the game should look like once the last event is undone. The `expected` section is what the last event changed. Replaying the events without the last one must match the checkpoint, and replaying all of them must match `expected`.

The checkpoints list the things the undone event touched (the count and the outs for a pitch, the pitcher and who may pitch again for a pitching change, the open question for a “keep playing” answer), including box score numbers where the event changed one, such as the error taken back off a fielder’s line.

| File | Event undone |
|---|---|
| `undo-pitch` | strike three |
| `undo-intentional-walk` | an intentional walk |
| `undo-ball-in-play-third-out` | a groundout that ended the half-inning |
| `undo-runner-action` | a stolen base with a throwing error |
| `undo-error-with-no-advance` | a dropped foul pop-up |
| `undo-substitution` | a pinch hitter |
| `undo-defense-confirmed` | the defense check |
| `undo-runner-for-non-runner` | the runner for a designated non-runner |
| `undo-pitching-change` | a pitching change |
| `undo-add-hitter` | an added hitter |
| `undo-batting-hole` | a batting hole |
| `undo-automatic-out` | the automatic out at a batting hole |
| `undo-time-limit-change` | the umpire’s time limit |
| `undo-keep-playing` | a “keep playing” answer |
| `undo-manual-adjustment` | a manual adjustment |
| `undo-end-of-game` | the end of the game |
