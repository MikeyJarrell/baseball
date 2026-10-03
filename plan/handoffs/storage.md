# Storage: handoff

**Job:** storage.

**Branch:** `codex/storage`, in the task folder `/Users/mikey/projects/.worktrees/baseball/storage`.

## What exists now

`FileStorage`, an actor in `app/Packages/ScorebookCore/Sources/Storage/`, is the real version of `ScorebookStorage`. It is made with `try FileStorage(folder:)`, given the app’s Documents folder, and creates the folders it needs:

```
teams/<team id>.json
games/<game id>.json
songs/library.json
songs/audio/            created empty, for the walk-up audio import
settings.json
backups/
```

- **Every write is safe.** `SafeFileWriter` writes into a hidden temporary file beside the real one, pushes it to the disk, then renames it over the real file in one step. A crash at any point leaves either the old file or the new one, never half of one. Leftover temporary files are ignored by every list and deleted the next time a `FileStorage` is made.
- **Saving after every event is fast.** `appendEvent` writes the whole game file before it returns, but keeps the open game in memory with each event already turned into text, so only the new event is encoded each time. Saving a 400-event game one event at a time takes about 0.14 seconds in total on the Mac (0.18 to 0.22 seconds while the other tests run alongside).
- **Game file layout.** The version tag, then `game` (the id and setup, with an empty events list), then `events`, one event per line. Reading joins the two lists, so a game written by hand with its events inside `game` also reads. New fields added to `Game` in `Model/` are saved with no change to storage.
- **Version tag.** Every file, backups included, starts with `"formatVersion" : 1` (from `ScorebookJSON.formatVersion`). A file with no tag, or a newer one, is reported as damaged with a plain reason (“saved by a newer version of the app”). When the format changes, converting older files belongs in `readSavedFile` in `SavedFiles.swift`.
- **Damaged files.** Every list returns the files that read plus a `DamagedFile` for each that did not, with a reason in plain words (“The file is not readable JSON. It may have been cut off or garbled.”). `loadGame` on a damaged file throws `StorageError.damaged`. Saving the game again over it mends it.
- **Lists.** Teams: ours first, then by name. Games: newest first by scheduled start. Finished games: oldest first, as the stand-in does.
- **Game in progress.** The unfinished game whose last event was entered most recently; a game with no events yet counts from its scheduled start. So today’s freshly set-up game wins over last week’s abandoned one.
- **Backups.** `makeBackup()` writes `backups/backup-<yyyy-MM-dd-HHmmss>.json` holding every team, game, the song library and the settings; never audio. A file that cannot be read goes into the backup byte for byte and comes back with a restore. `restoreBackup(from:)` checks the whole backup first (a damaged one is refused and changes nothing), saves the current state as `before-restore-<date>.json`, then replaces teams, games, songs list and settings. The audio folder is never touched. `listBackups()` lists backup files newest first.
- **Ids in file names.** Letters, digits, `-` and `_` are kept; anything else is written as a `%` code, so an id such as `../x` can never write outside its folder.

## Decisions

- A damaged `settings.json` or `songs/library.json` throws `StorageError.damaged`, so the scorer can be told. The wiring should catch it, show the message, and carry on with the defaults.
- Deleting a team or game that was never saved does nothing, as in the in-memory stand-in.
- Restoring from a backup file that does not exist throws `StorageError.notFound` with the file name.
- `audioFolder`, `backupsFolder` and `listBackups()` belong to `FileStorage` alone; the protocol does not have them.

## Vocabulary requests

None is required. Two would tidy things for the wiring job:

1. **Add `listBackups() async throws -> [URL]` to `ScorebookStorage`** (the stand-in returns an empty list), so a restore screen can be written against the protocol. Workaround: the wiring calls it on `FileStorage` directly.
2. **Match `InMemoryStorage.gameInProgress()` to the real one**, choosing by the last event’s time (the stand-in uses the scheduled start), so previews and the app agree. Nothing breaks if it is left.

## For the wiring job

- Make exactly one `FileStorage` for the Documents folder and share it; it remembers the open game between events.
- Call `appendEvent` for each new event and `saveGame` for anything that changes earlier events (undo, edits, roster edits in the setup).
- The walk-up audio import writes into `storage.audioFolder`.
- The backups folder is inside Documents, so backup files show up in the Files app once file sharing is switched on.

## Evidence

- `swift test` in `app/Packages/ScorebookCore`: 63 tests, all passing: the foundation’s 41 and 22 new storage tests in two suites, “Saving and loading files” (16) and “Backups” (6).
- The finish line’s four checks: “One of every kind of event, added one at a time, reads back exactly and in order”, with every sample team, the sample game and every sample setup in their own tests; “A 400-event game saved one event at a time takes under a second in total”; “A corrupted game file is reported as damaged and every other game still loads”; “A backup restored after changes brings back exactly what was saved”.
- `xcodebuild -scheme Storage -destination 'generic/platform=iOS Simulator' build`: succeeded with no warnings.

## Not done

- No fresh review yet.
- Durability against a sudden power cut goes as far as the operating system’s ordinary flush to disk. The stronger full flush took far too long for saving after every pitch.
