# Review: announcer introductions pieced together from recordings

**Reviewer:** a fresh Claude session that did not build the work.

**What was read:** `plan/rules-for-agents.md` (the reviewer section), `plan/handoffs/announcer-pieces.md`, and `git diff 03b3e01..HEAD`.

**What was run:** `swift test` in `app/Packages/ScorebookCore`, and `tools/record_intros.py --help` with its slug function on the real roster. Nothing was recorded and nothing was written to Dropbox.

The stitching on the phone is sound: the pieces come out in the right order, a number change rebuilds the introduction, a missing piece gives a clear message and never a clipped introduction, and the app is stopped before every load, so no stale introduction survives a load. The problems are in how loading and the recorder treat what Mikey has already done.

## Findings, most harmful first

### 1. Loading the team undoes a number changed in the app, so the introduction says the old number

`app/Packages/ScorebookCore/Sources/TeamImport/TeamImport.swift:271` (`if !row.number.isEmpty { player.number = row.number }`)

The point of this change is that a number changed mid-season needs nothing new recorded. But the roster file now holds every player’s number (commit ffd2796), and the loader writes the file’s number over the phone’s whenever the file has one. Scenario: Yered switches from 22 to 9 and Mikey types 9 into the app. The next time Mikey loads the team, for a new song or a new player, Yered is back to 22, and the announcer says “number twenty-two.” This line is older than this change, but the change makes it bite.

It also breaks a test. `swift test` fails at `Tests/TeamImportTests/TeamImportTests.swift:86`, which expects a number typed in the app to survive a reload. The handoff says every test passes. That was true before the numbers commit and is not now.

Fix: either keep the phone’s number when it differs from the file’s, or treat the roster file as the one place numbers change and say so in the team README. Then the test has to agree with whichever is chosen.

### 2. Loading the team brings back a pieced introduction Mikey switched away from in the app

`TeamImport.swift:289`

The loader leaves a player’s introduction alone only if it was recorded or imported in the app. Scenario: a name take sounds wrong on the stadium speaker, so Mikey switches that player to the iPhone voice, or removes the introduction. The next load switches it back to the pieced one. The handoff describes this as intended, but it overrides something Mikey chose on the phone. A simple rule: set the pieced introduction only on a player who has no introduction yet, or who already has a pieced one.

### 3. A blank “goes by” makes the Mac and the phone name the file differently, and the player silently gets no introduction

`tools/record_intros.py:79` against `TeamImport.swift:287` (`RosterWords.fileStem(row.displayName)`)

The recorder builds the name from `goes_by` and `last_name` only. The app falls back to the first name when `goes_by` is blank. Every row today has `goes_by` filled in, so nothing is broken yet. Scenario: a new player is added with `goes_by` left empty. The recorder shows the prompt “ Smith” (last name only), saves `names/smith.m4a`, and the app looks for `announcer-name-john-smith.m4a`. The player never gets a pieced introduction, and nothing warns about it: the loader does not report name recordings that match no player. Fix: fall back to `first_name` in `player_slug` the same way, and have the loader list name files that matched nobody.

A smaller mismatch of the same kind: letters that have no plain form, such as “ø” or “ß”, are dropped by the Python script but turned into a word break by the Swift code (“Søren” becomes `sren` on the Mac and `s-ren` on the phone). This is unlikely on this roster.

### 4. The recorder throws away a take when Mikey types anything other than the listed keys

`tools/record_intros.py:252-266`

Only Enter keeps a take. Any other answer, such as “y”, “k” or “keep”, falls through to the clean-up lines, deletes the take, and moves on to the next piece as if he had skipped it, with no message. The cost is time: an earlier kept piece is never touched. Fix: ask again on any answer it does not recognize.

### 5. After a redo, a failed take can replay and save the previous take

`tools/record_intros.py:242-253`

Choosing “r” goes back to record without deleting the last cleaned take (`*.take.m4a`). If the next take comes out empty or silent, the clean-up stops early without writing a new file, the old take is still there, and the script plays it and offers to keep it, right after printing “No voice was heard.” If Mikey keeps it, the saved piece is the earlier take while the raw copy in `intros/raw/` is the silent one. Fix: delete `take` before each recording.

### 6. The recorder crashes with a Python error if nothing was recorded

`tools/record_intros.py:141`

If ffmpeg could not record at all (for example, the Terminal is not allowed to use the microphone), the WAV file does not exist, and `read_audio` stops the script with a long Python error. The script already has a plain message about microphone permission, and this case never reaches it. Fix: check that the WAV exists before cleaning it up.

### 7. One unreadable piece stops the whole team load

`app/Packages/ScorebookCore/Sources/TeamLoader/main.swift:168-170`

Any piece that will not play, including one of the 202 number takes nobody on the team wears, ends the load before anything is copied. Scenario: Dropbox has not finished downloading one closing take onto the Mac on game morning, and Mikey cannot load a new player’s song. The check protects the phone, but for a piece no player uses, a warning and skipping that file would be enough.

## Checked and fine

- The phone looks for the same file names the recorder writes: `now-batting`, `numbers/22`, `numbers/00` and `closing/22` map one to one, and “00” and “0” stay distinct.
- A cached introduction includes the player’s number, so a number change rebuilds it at the next cue. `load_team.sh` stops the app before loading on both the phone and the simulator, so re-recorded pieces cannot be served from memory.
- `--redo`, skip and quit never delete a piece already kept, and keeping replaces it in one step.
- Removing a pieced introduction in the app leaves the shared name file alone, which is correct, because the loader owns it.
- Pieces are read and joined on the main thread. These are a few short files, the same as the existing path for an introduction recorded in the app, so no new concurrency problem appears.
