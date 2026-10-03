# Storage

**Role:** storage builder.

**Waits on:** foundation.

**Owns:** `ScorebookCore/Sources/Storage/` and `ScorebookCore/Tests/StorageTests/`.

**Reads:** `Model/`, `SampleData/`.

## Deliver

The real version of the storage interface in `Model/`, saving JSON files in a folder it is given (the app passes its Documents folder; tests pass a temporary one):

```
teams/<team id>.json
games/<game id>.json        setup and every event
songs/library.json          song names, start points, file names
songs/audio/                the audio files themselves (written by the audio builder’s import)
backups/
```

1. **Save after every event.** Each new event is written to disk before the call returns, written to a temporary file and then swapped in, so a crash mid-write never leaves a half-written game.
2. **Game in progress.** On launch, find the most recent game that has not ended so the app can offer to resume it.
3. **Lists.** All teams; all games, newest first, with date, opponent and final score; all finished games for the season totals.
4. **Backup.** Write everything except audio into one dated file in `backups/`, and restore from one.
5. **Version tag.** Every file records the format version, so a future version of the app can read old games.

## Finish line

Tests cover: saving and reloading every kind of team, game and event without loss; a game with 400 events saved one event at a time in under a second total; a deliberately corrupted file reported as damaged without losing the other games; backup and restore round trip.
