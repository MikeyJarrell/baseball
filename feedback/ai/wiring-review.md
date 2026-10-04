# Review: wiring and dress-rehearsal job

**Reviewer:** a fresh builder who did not build this job.

**Reviewed:** `git diff origin/main...HEAD` on `codex/wiring`, against `plan/briefs/wiring-and-dress-rehearsal.md`, `plan/handoffs/wiring.md`, every other handoff’s notes for the wiring job, `notes/vocabulary-requests.md` and `plan/install-on-iphone.md`.

**Verdict:** Close to the finish line. Fix findings 1 to 3 (each small) before the dress rehearsal; the rest can follow.

## What I ran

- `swift test` in `app/Packages/ScorebookCore`: every test passes.

- `xcodebuild test -scheme ScorebookUI-Package` on my own iPhone 17 simulator (iOS 27): every test passes, no code warnings.

- `xcodebuild test -scheme Scorebook` (the app’s walkthroughs) on my own simulator: the sample game (229 s) and Astros at Yankees (287 s) pass with identical box scores; both smoke tests pass.

- Throwaway checks, outside the repository:
  - **Killed mid-inning and reopened:** a real (non-test) launch from saved files, three pitches (1–0 to 2–2), app killed straight after the last tap, reopened. It came back at 2–2, same pitcher count, “Undo: foul”. Undo after reopening worked and offered Redo.
  - **Time limit and defense check at the same changeover:** both are due when our team takes the field after time is up. “Is the game over?” shows first; after Keep playing, the defense check opens. Nothing is lost.
  - **Double-tapping Undo in the simulator:** took back two events correctly.
  - The built app’s Info.plist has background audio, the microphone question, Files sharing and iOS 18.0 as the minimum. The audio player sets the playback category.

## Findings, worst first

1. **A player edit during a game can undo a song or introduction change.** `app/Scorebook/AppModel.swift:269-282` (`updateSavedPlayer`), called from `GameScreen.swift:288` (batter sheet Save) and `GameScreen.swift:311` (song picker). The player handed in is the game roster’s copy, whose walk-up song, warm-up song and introduction date from the start of the game. Change a song or re-record an introduction on the team page mid-game (the handoff says this plays at once), then fix that hitter’s number on the batter sheet, and the old song and old introduction are written back onto the saved team. The new recording is left unused. Fix: in `updateSavedPlayer` also keep `walkUpSongID`, `warmUpSongID` and `introduction` from the saved team; in `giveWalkUpSong`, change only `walkUpSongID` on the saved player. Add a test.

2. **Two quick taps on Undo or Redo can save the same pitch twice.** `Packages/ScorebookCore/Sources/Scoring/GameSession.swift:209-230`. `undo()` and `redo()` decide what to change before the save and update the game only after it, so a second tap while the first save is still going works from the same starting point. A throwaway test with real files, calling Undo twice at once: one event was taken back, but it went onto Redo twice. Calling Redo twice at once then saved that same event twice (same id) into the game file, giving one pitch too many. The simulator’s fast saves hid it, but on the phone, late in a long game, every save rewrites the whole game file. Fix: let the session make one change at a time (ignore or queue a tap while a save is running), and test two Undos and two Redos at once.

3. **Reopening does not record a waiting automatic out.** `AppModel.swift:97-99` and `334-336` create `GameSession(game:)` directly, and automatic outs are only recorded after a new event. If the phone dies between saving the scorer’s event and saving the automatic out that follows it, the batting hole is up when the app reopens, and the next pitch is recorded against it. Fix: a public `GameSession.resume(...)` that calls `recordAutomaticOuts()`, used by both. Test it with a game saved just before a hole comes up.

4. **A dropped third strike on the third out.** `GameScreen.swift:155-160` and `340-344`. The strikeout ends our half, so the warm-up song starts and the defense check covers the “Dropped 3rd strike” button. If the batter is then safe, our half goes on, but the warm-up keeps playing over our hitter. The same happens when Undo or a play-by-play fix steps back over the changeover. Fix: in `situationChanged`, stop the warm-up and re-cue our hitter when we stop taking the field. Hold the automatic defense check while `droppedThirdStrikePossible` is true (the Defense button on the banner still opens it).

5. **“Not over” leaves the game counted as finished.** `GameScreen.swift:409`: after the undo, `app.reloadGames()` is not called, so the season stats and games list keep the reopened game until it ends again. Also, `AppModel.swift:232` ignores a failed end-of-game backup without telling anyone. Fix: reload after “Keep scoring”, and set `problem` when the backup fails.

6. **The import guard misses the new module.** `Packages/ScorebookUI/Tests/DesignSystemTests/ScreenImportRulesTests.swift:14`: it still enforces GameEngine, Stats, Storage and WalkUpAudio, but not `Scoring`. Add it.

7. **Install steps** (`plan/install-on-iphone.md`): correct for current iOS and Xcode, plain English, and they cover the seven days, Developer Mode and trusting the developer. Four additions:
   - The Trust step (line 25) needs the phone online.
   - A free account allows only three of your own apps on the phone at once, so the bundle-name workaround can hit the limit.
   - The Backups page lists only files in Scorebook/backups, so a backup kept in iCloud Drive must be copied back there before it can be restored (line 51).
   - Reinstall from the main folder after `/done`, since Xcode builds whatever is checked out.

8. **Comments and documents.** `Packages/ScorebookCore/Tests/StatsTests/ScenarioEngine.swift:3-11` still says the engine has not landed. The batter sheet tells the scorer an edit to our player is “Kept for the whole game” only (`GameChanges/BatterSheet.swift:83`), but the wiring now saves it to our team too. Otherwise the new comments are clear and beginner-readable. The plan and dashboard are updated.
