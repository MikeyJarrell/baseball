# Storage: handoff

**Job:** storage.

**Branch:** `codex/storage`, in the task folder `/Users/mikey/projects/.worktrees/baseball/storage`.

## What exists now

`FileStorage`, an actor in `app/Packages/ScorebookCore/Sources/Storage/`, is the real version of `ScorebookStorage`. It is made with `try FileStorage(dataFolder:backupsFolder:)` and creates the folders it needs. The live files go in the data folder, which is private: the Files app cannot see it, so nobody can delete or edit a game by mistake (the coordinator’s decision, after the review):

```
teams/<team id>.json
games/<game id>.json
songs/library.json
songs/audio/            created empty, for the walk-up audio import
settings.json
```

Backup files go in the backups folder, the only one the Files app shows.

- **Every write is safe.** `SafeFileWriter` writes into a hidden temporary file beside the real one, pushes it to the disk, then renames it over the real file in one step. A crash at any point leaves either the old file or the new one, never half of one. Leftover temporary files, in the backups folder too, are ignored by every list and deleted the next time a `FileStorage` is made.
- **Saving after every event is fast.** `appendEvent` writes the whole game file before it returns, but keeps the open game in memory with each event already turned into text, so only the new event is encoded each time. Saving a 400-event game one event at a time takes about 0.14 seconds in total on the Mac (0.18 to 0.22 seconds while the other tests run alongside).
- **Game file layout.** The version tag, then `game` (the id and setup, with an empty events list), then `events`, one event per line. Reading joins the two lists, so a game written by hand with its events inside `game` also reads. New fields added to `Game` in `Model/` are saved with no change to storage.
- **Version tag.** Every file, backups included, starts with `"formatVersion" : 1` (from `ScorebookJSON.formatVersion`). A file with no tag, or a newer one, is reported as damaged with a plain reason (“saved by a newer version of the app”). When the format changes, converting older files belongs in `readSavedFile` in `SavedFiles.swift`.
- **Damaged files.** Every list returns the files that read plus a `DamagedFile` for each that did not, with a reason in plain words (“The file is not readable JSON. It may have been cut off or garbled.”). `loadGame` on a damaged file throws `StorageError.damaged`. Saving the game again over it mends it.
- **Lists.** Teams: ours first, then by name. Games: newest first by scheduled start. Finished games: oldest first, as the stand-in does.
- **Game in progress.** A started game (one with at least one event) always beats one not yet started, and started games are ranked by when their last event was entered. Only when no game has been started is an unstarted one offered: the one whose file was saved last. A scheduled start is never used, so a game set up in advance for next Saturday never takes over from today’s game.
- **Backups.** `makeBackup()` writes `backups/backup-<yyyy-MM-dd-HHmmss>.json` holding every team, game, the song library and the settings; never audio. A file that cannot be read goes into the backup byte for byte and comes back with a restore. `restoreBackup(from:)` checks the whole backup first (a damaged one is refused and changes nothing), saves the current state as `before-restore-<date>.json`, writes every file in the backup over the current one, and only then removes the teams, games, song list and settings the backup lacks, so a restore cut off partway leaves every game in place. The audio folder is never touched. `listBackups()` lists backup files newest first by when each file was made, whatever its name.
- **Ids in file names.** Letters, digits, `-` and `_` are kept; anything else is written as a `%` code, so an id such as `../x` can never write outside its folder.

## Decisions

- A damaged `settings.json` or `songs/library.json` throws `StorageError.damaged`, so the scorer can be told. The wiring should catch it, show the message, and carry on with the defaults.
- Deleting a team or game that was never saved does nothing, as in the in-memory stand-in.
- Restoring from a backup file that does not exist throws `StorageError.notFound` with the file name.
- `audioFolder`, `backupsFolder` and `listBackups()` belong to `FileStorage` alone; the protocol does not have them.

## Vocabulary requests

None is required. Two would tidy things for the wiring job:

1. **Add `listBackups() async throws -> [URL]` to `ScorebookStorage`** (the stand-in returns an empty list), so a restore screen can be written against the protocol. Workaround: the wiring calls it on `FileStorage` directly.
2. **Match `InMemoryStorage.gameInProgress()` to the real one**, preferring a started game and choosing by the last event’s time (the stand-in uses the scheduled start), so previews and the app agree. Nothing breaks if it is left.

## For the wiring job

- Make exactly one `FileStorage` and share it; it remembers the open game between events. Pass the app’s Application Support folder as `dataFolder` (`URL.applicationSupportDirectory`, perhaps with a `Scorebook` folder inside) and `Documents/backups` as `backupsFolder` (`URL.documentsDirectory.appending(path: "backups")`).
- Call `appendEvent` for each new event and `saveGame` for anything that changes earlier events (undo, edits, roster edits in the setup).
- The walk-up audio import writes into `storage.audioFolder`.
- Only the backups folder is inside Documents, so once file sharing is switched on the Files app shows the backups and nothing else.

## Evidence

- `swift test` in `app/Packages/ScorebookCore`: 66 tests, all passing: the foundation’s 41 and 25 storage tests in two suites, “Saving and loading files” (17) and “Backups” (8).
- The finish line’s four checks: “One of every kind of event, added one at a time, reads back exactly and in order”, with every sample team, the sample game and every sample setup in their own tests; “A 400-event game saved one event at a time takes under a second in total”; “A corrupted game file is reported as damaged and every other game still loads”; “A backup restored after changes brings back exactly what was saved”.
- `xcodebuild -scheme Storage -destination 'generic/platform=iOS Simulator' build`: succeeded with no warnings.

- After the review: “A game set up in advance for next week never takes over from today’s game in progress”, “Backups are listed newest first by when they were made, whatever their names” (it fails under the old name sort), “A leftover scrap from a backup cut off mid-write is cleared on the next start” and “Live files and backups go in the two separate folders the app gives”.

## Review

The fresh review is in `feedback/ai/storage-review.md`. Fixed as it describes: resuming could open a game set up for next week, a restore deleted everything before writing the backup back, the backups list sorted by name, and scraps in the backups folder were never cleared. Its question about the Files app was settled by the coordinator: the live files are private, and only the backups sit in Documents. Timing the 400-event save on an iPhone is left for the dress rehearsal.

## Not done

- Durability against a sudden power cut goes as far as the operating system’s ordinary flush to disk. The stronger full flush took far too long for saving after every pitch.
