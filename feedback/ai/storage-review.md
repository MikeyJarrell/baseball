# Storage: fresh review

**Verdict:** accept after fixes.

**Reviewed:** commit 2236a52 against `plan/briefs/storage.md`, the handoff note and the `ScorebookStorage` promise in `Model/StorageService.swift`.

**Tests:** `swift test` in `app/Packages/ScorebookCore` passes: 22 storage tests in two suites and the foundation’s 41. The 400-event game saved one event at a time took 0.19 seconds on the Mac.

**What holds up:** every write goes to a hidden temporary file, is pushed to disk, then renamed over the real file, so a crash mid-write leaves the old game or the new one, never half of one. Damaged files are listed with a plain reason and never hide the other games. Every file carries the format version. Only files inside `Sources/Storage/`, `Tests/StorageTests/` and the handoff note changed. The comments are clear enough for a beginner to follow.

## Findings, worst first

1. **Resume can open the wrong game.** `FileStorage.swift:132–136` and `:349–351`. A game with no events is ranked by its scheduled start. The pregame screen lets the coach pick a date, so a game set up in advance for next Saturday outranks today’s game in progress, whose last event was entered this morning. If the app is closed mid-game, the wiring brief has it open straight to the game in progress, which would be next week’s empty one. **Fix:** do not rank an unstarted game by a start time that is still in the future. For example, rank it by the earlier of its scheduled start and the time its file was last saved, or skip unstarted games scheduled after now. Add a test: today’s game with 30 events, next week’s game with none, and resume picks today’s.

2. **Restore deletes everything before writing the backup back.** `FileStorage.swift:201–215`. If the app crashes, or the phone runs out of space, partway through a restore, it reopens with no games or only some of them. The “before-restore” backup is there, but nothing tells the scorer. **Fix:** write the backup’s teams, games, songs and settings first (each save replaces its file safely), then delete only the files the backup does not contain. A cut-off restore then leaves every game in place, plus perhaps a few extra ones.

3. **The list of backups is not newest first.** `FileStorage.swift:226–231` sorts by file name. Every `before-restore-…` file sorts above every `backup-…` file, whatever its date, because “be” comes after “ba”. Two backups made in the same second also come out oldest first, because `-2.json` sorts before `.json`. A restore screen that offers the top entry would offer the wrong backup. The test at `BackupTests.swift:146` only checks that the list matches the same name sort the code uses, so it passes either way. **Fix:** sort by each backup’s `madeAt` (or the file’s creation date). Test it with a backup, a restore, a second backup, and two backups in the same second.

4. **Question for Mikey: should the live game files be visible in the Files app?** Handoff lines 9, 46 and 49. The brief puts everything in Documents. Once file sharing is switched on so the backups can be reached, the live `games/`, `teams/` and `settings.json` files show up in the Files app too, where they can be deleted or edited by mistake. A game file put back by hand would also be overwritten by the copy storage keeps in memory the next time an event is added. **Recommendation:** keep the live files in the app’s private Application Support folder and put only `backups/` in Documents, by letting `FileStorage` take a second folder for backups. This changes the brief, so it is Mikey’s call.

5. **Leftover temporary files in `backups/` are never cleared.** `FileStorage.swift:52`. A crash while a backup is being written leaves a hidden file there for good. **Fix:** add `backupsFolder` to the folders cleared on start.

6. **The speed test runs only on the Mac.** `FileStorageTests.swift:123`. Each event rewrites the whole game file and pushes it to disk, so the time on an older iPhone may be several times the Mac’s. This is fine for one pitch, but it should be timed on the phone during the dress rehearsal.
