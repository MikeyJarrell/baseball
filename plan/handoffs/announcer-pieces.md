# Handoff: announcer introductions pieced together from recordings

Mikey records the announcer on the Mac with a good microphone, in pieces, and the phone stitches each player’s introduction together when it plays: “Now batting,” … “number twenty-two,” … “Aidan Kurt.” … “Number twenty-two.” Every number is recorded once for the whole team, so numbers assigned or changed during the season need nothing new recorded.

## What was built

- **`tools/record_intros.py`**: records “Now batting,” each roster player’s name, and the numbers 0 to 99 and 00 from the ATR2100x (or `--mic`), one take at a time with playback, keep, redo, skip and quit, carrying on where it stopped. Each take is high-pass filtered at 70 Hz, trimmed to 0.05 s before the first sound and 0.15 s after the last, set to an average spoken level of −18 dB with peaks under −1 dB, given 10 ms and 30 ms edge fades, and saved as 48 kHz mono AAC in `~/Dropbox/baseball/intros/`; the untouched WAV goes to `intros/raw/`. A take is held aside until kept, so redoing a piece never loses the old one. It warns about a distorted, very quiet or silent take. An optional `closing` set records the numbers again with a falling, sentence-ending voice.
- **`AnnouncerIntroduction.Source.pieced`** (Model): its `fileName` is the player’s name recording. The shared pieces’ names in the app’s audio folder are fixed: `nowBattingFile`, `numberFile(_:)`, `closingNumberFile(_:)` and `nameFile(_:)`.
- **`PiecedIntroduction`** (WalkUpAudio): picks the pieces for a player and joins them with the phone voice’s pauses (0.55, 0.5 and 0.9 s). No number, or a number with no recording, gives “Now batting, … Aidan Kurt.” A closing take ends the introduction when there is one; otherwise the mid-sentence take is repeated. A missing name or “Now batting” recording, or a piece in a different sound format, gives no introduction and a message to load the team again, never a clipped one. The player’s number is part of the cached introduction’s recipe, so a new number rebuilds it at the next cue.
- **`discardIntroduction(_:)`** leaves a pieced introduction’s name file alone: the loader owns it and copies it in on every load.
- **TeamImport and TeamLoader**: `load` takes the intros folder as an optional fourth argument, checks every piece plays, copies each one into `songs/audio/` under its app name (skipping identical files), and gives each roster player with a name recording a pieced introduction, unless they have one recorded or imported in the app. Without a “Now batting” recording no pieced introductions are set. `check` prints each player’s introduction, flags missing pieces, notes a number with no recording, and counts the numbers on the phone. `tools/load_team.sh` passes `~/Dropbox/baseball/intros/`.
- **Wording**: the player page reads “Your voice, pieced together with their number”, the roster row “intro recorded”, the audio test screen “Pieced together”.

## Checks

- `swift test` in `app/Packages/ScorebookCore`: every test passes, including `piecedIntroductions` (a recorded name gets a pieced introduction, an in-app recording is kept, a player with no recording gets none) and `fileStems` (the Swift file stem matches the Mac scripts’, accents dropped).
- `xcodebuild test -scheme ScorebookUI-Package -only-testing:WalkUpAudioTests -only-testing:TeamScreensTests` on the iPhone 17 simulator: all pass, including `PiecedIntroductionTests` (the order and pauses match the phone voice; the closing take; no number and an unrecorded “07” fall back to name only; a missing piece gives nothing; four 0.1 s pieces join to 2.35 s).
- The Scorebook app builds.
- The loader, run on a copy of the phone’s latest backup with stand-in recordings of “Now batting,” “Aidan Kurt” and “Number twenty-two”: copied the three pieces, gave Aidan the pieced introduction and nobody else, and a second run changed nothing.
- `record_intros.py`’s clean-up on a spoken test phrase padded with 1.5 s of silence before and 2 s after: trimmed from 4.8 s to 1.3 s, average level −18.8 dB, peak −4.9 dB.

## Not yet checked

- The pieced introduction heard on the phone with Mikey’s real recordings: load the team after recording and tap “Test: introduction, then song” on a player with a number.
