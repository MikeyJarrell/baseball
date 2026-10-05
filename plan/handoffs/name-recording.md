# Recording a player’s name in the app: handoff

**Job:** let Mikey record a player’s name on the phone, during a game or from the team pages, so a player added mid-game (Jackson Cleary) gets the pieced announcer introduction straight away.

**Branch:** `codex/handedness-and-name-recording`, in the task folder `/Users/mikey/projects/.worktrees/baseball/handedness-and-name-recording` (it also carries the roster’s handedness commit for Jackson Cleary and the GWW Whales).

## What exists now

- **Three ways in:** “Record name” on the batter sheet (the game menu’s Edit this batter; our hitters with a name only), “Add and record name” on the add-a-hitter sheet (our team, once the hitter has a name: it adds them to the order, then opens the recorder), and “Record name” (or “Record name again”) on a player’s page under Teams. The two game sheets hand back new results, `GameChangeResult.recordName(PlayerEdit)` and `.recordThenRecordName(EnteredEvent, PlayerID)`; the player page sends `TeamScreensRequest.recordName(PlayerID)`. The app shell opens the recorder for all three.
- **The recorder** (`app/Scorebook/NameRecordingSheet.swift`): the name to say in big letters, the line it makes (“Now batting, number 3, Alex Moreno.”, or “Now batting, Jackson Cleary.” with no number), a big round record button that stops on a second tap (or by itself after 30 seconds), then Listen (the whole introduction as it will play), Redo and Keep. Cancel throws the take away. Keep asks first when the player has a full introduction recorded or imported, and that old file is deleted only once no team and no game in progress uses it. It says so when the phone has no “Now batting” recording yet.
- **Cleaning the take** (`WalkUpAudio/NameTake.swift`): the same steps as `tools/record_intros.py`: a 70 Hz high-pass, silence trimmed to 0.05 s before the first sound and 0.15 s after the last, the spoken part leveled to −18 dB with peaks under −1 dB, 10 ms and 30 ms edge fades, saved as 48 kHz mono AAC. The matching format matters: the pieces are only joined when they share one. A take with no voice gets “No voice was heard…”.
- **The audio player:** `makeNameCandidate(from:)` (raw take to a trial file), `keepNameRecording(_:stem:)` (the trial becomes `AnnouncerIntroduction.nameFile(stem)`, replacing an earlier one, and any introduction already made from the old file is forgotten so the next walk-up uses the new one), `discardNameCandidate(_:)`, `hasNowBattingRecording`.
- **Saving:** the player’s introduction becomes `.pieced` with that file, on the saved team and on the game in progress, and our next hitter is cued again. The file stem is `AnnouncerIntroduction.nameStem(_:)` (moved into Model from the loader, the same rule as the Mac script: “Jackson Cleary” is `jackson-cleary`).
- **No jersey number:** `PiecedIntroduction` already plays “Now batting, … Jackson Cleary.” when a player has no number (or one with no recording); a test now checks it for a player with a name recording and no number.

## The loader and Dropbox

- **Copied back first:** `tools/load_team.sh` now copies every name recorded on the phone (`announcer-name-<stem>.m4a`) to `~/Dropbox/baseball/intros/names/<stem>.m4a` before loading, when Dropbox has none for that name or an older, different one. The backup and work copies keep file times (`cp -Rp`) so “older” can be told. A trial run on the simulator copies them aside instead of into Dropbox.
- **Kept on the phone:** the loader replaces a name recording on the phone with Dropbox’s only when Dropbox’s is newer (`TeamImport.keepsAppRecording`); otherwise it prints “Kept the name recorded on the phone”. A player whose introduction was set in the app keeps it, as before.
- **To bring a name recorded on the phone to Dropbox:** run `tools/load_team.sh` with the phone plugged in; step 3 lists each name it copied back.

## Also fixed

- **The delete-a-game smoke test** failed on main because the test tapped the game menu while the batting screen was still sliding up at launch, and the tap was lost (the app was fine: Mikey deletes games on the phone). The test now taps again until the menu opens; the batter-sheet name test does the same.
- **Lineups, “Empty spot”:** the row’s minus icon was being passed as the row’s tap action, so no icon showed. It now shows (`GameChanges/LineupsSheet.swift`).
- **Merged main’s text cleanup** and kept its shorter text; the new text here follows it (“Record name”, “Add and record name”, “Tap to record”).

## Tests

- `swift test` in `app/Packages/ScorebookCore`: every test passes, including the new “A name recorded in the app is kept over Dropbox’s copy only when it is newer” and the name stems.
- `xcodebuild test -scheme ScorebookUI-Package`: every test passes, including `NameRecordingTests`: a quiet tone between silences trimmed to 0.70 s and raised under the peak limit; silence refused; a 44.1 kHz take made into `announcer-name-jackson-cleary.m4a` at 48 kHz mono with the raw take and the trial file gone; “Now batting,” then the name with no number.
- `xcodebuild test -scheme Scorebook` on the iPhone 17 simulator: both full-game walkthroughs and every smoke test pass, including `NameRecordingSmokeTests`: the recorder opens with the right name from the batter sheet (Alex Moreno), after adding Jackson Cleary as a new hitter (“Now batting, Jackson Cleary.”, and he was added), and from Alex Moreno’s player page.

## Not checked

- Speaking into the recorder: the simulator has no voice to record, so the take, Listen and Keep were checked through the tests above with a made-up take, not a real one. Mikey’s first real name recording on the phone is the check: record Jackson Cleary’s name, tap Listen, then Keep, and he is introduced the next time he bats.
