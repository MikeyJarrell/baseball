# Teams and songs screens: review

**Reviewer:** a fresh Claude session that did not build the screens.

**Reviewed:** `git diff origin/main...HEAD` on `codex/screen-teams-and-songs`, against the brief, the handoff, the walk-up audio handoff and the approved mockup.

**Verdict:** Accept after fixing the first two findings. A swipe meant to scroll the song page moves that song’s start point without the scorer noticing. A jersey number typed twice in quick entry is saved with no warning anyone sees.

## What I ran

- `xcodebuild test -scheme ScorebookUI-Package` on a new iPhone 17 simulator of my own (deleted afterward): every suite passes, the 25 new tests among them, with no warnings.
- A throwaway harness app outside the repository (its own bundle id). It wrote every request the screens handed back to a log, and a UI-test target drove the taps:
  - **Quick entry, run twice:** twelve players on an emptied Diamond Dogs roster, each with a usual position, five left-handed batters, three left-handed throwers, and “22” typed twice. Both runs took about 23 seconds of machine typing. Each player was saved as typed. Each usual position went to the right new player. Bats and throws were correct for all twelve.
  - **Song choices:** picking a walk-up song for Webb changed only Webb’s walk-up song. From a song page, Warm-up for Fisk and then Walk-up for Barros changed only those two slots, and Barros kept his warm-up song.
  - **Recording:** record, stop, listen, redo, record again, then Keep. The screen handed back, in order: start, stop, play the introduction, cancel, start, stop, save the team with the new file, delete the old file `intro-d1.m4a`, finish. Cancel during a recording handed back a cancel.
  - **Removing a player:** the screen asked first, then saved the team without the player and deleted that player’s introduction file.
  - **Largest text size:** the player page, the song page and the roster are readable, and nothing is cut off.

## Findings, worst first

1. **SongPage.swift:270–274: scrolling the song page can move the start point.** The drawing of the track reacts to a drag the moment a finger touches it (a drag that needs zero movement to start). An ordinary upward scroll that began on the drawing moved one song’s start point from 0:14.0 to 1:26.0 in one run and to 0:58.6 in another. Nothing on screen asks the scorer to confirm. **Fix:** let a tap set the start point. Move it by dragging only once the finger has clearly gone sideways (for example, a drag that needs 10 points of movement, ignored when the motion is mostly up or down). Add a UI check that a vertical scroll leaves the start point alone.

2. **QuickEntrySheet.swift:78–81 and 175, RosterScreen.swift:221–269: a repeated jersey number goes unseen.** The line saying “…also wears 22” lasts only while the line is being typed. Return clears it at once, so a fast typist never sees it. The second 22 was saved, and nothing marked it afterward, either under “Added just now” (which sits behind the keyboard anyway) or on the roster. **Fix:** keep mentioning, never refusing. Mark the repeated number on the “Added just now” row and on both roster rows, in our blue, for example “also wears 22”.

3. **SongPage.swift:205: a player with the same song for walk-up and warm-up appears twice under the same name tag.** The “Used by” list labels each row by player alone. SwiftUI then sees two rows labeled the same way, and may draw one row twice or drop one. **Fix:** label each row by player and slot together.

4. **RecordIntroductionSheet.swift:150–151: Redo while the take is playing deletes the file in the middle of playback.** **Fix:** hand back `.stopPlaying` before `.cancelRecording` while listening. Do the same before Keep.

5. **RecordIntroductionSheet.swift:92–94: a swipe down closes the sheet and silently throws away a take that has not been kept.** **Fix:** add `.interactiveDismissDisabled(isRecording || pending != nil)`, so only Cancel or Keep closes the sheet.

6. **plan/handoffs/screen-teams-and-songs.md, the request table: two things the audio player offers are missing from the wiring instructions.**
   - A recording that stops by itself (at the 30-second limit, or when a call cuts it off) arrives in `pendingRecording`. The table never tells the app shell to collect it and set `.recorded`. Until it does, the sheet stays on “Recording” with its clock still counting.
   - The audio handoff asks for `cue(for:)` after a song or introduction changes.

   **Fix:** add a row for each.

7. **RosterScreen.swift:213, PlayerEditSheet.swift:128, RecordIntroductionSheet.swift:188: an old introduction file is deleted at once, but a game in progress may still use it.** A game in progress keeps its own copy of the roster (`GameTeam.roster`), and that copy still names the old file. If Mikey records a new introduction mid-game, or removes a player, that batter loses the introduction for the rest of the game. Pregame already leaves removed players out of the next lineup. **Fix:** the handoff tells the wiring job to play walk-ups from the saved team, or to delete a file only once no game in progress names it.

8. **Minor.**
   - RosterScreen.swift:212: removing a player leaves their usual position behind. Also hand back `setUsuals(PlayerUsuals(), for:)`.
   - RecordIntroductionSheet.swift:164: the echo switch turns any echo level into 0.5. A level set on the audio test screen is lost.

## Checked and sound

- **Requests match the audio player.** Import, preview, start point, volume, rename, recording, keep, redo, importing an introduction, the iPhone voice and the introduction-then-song test each map one to one onto a `StadiumAudioPlayer` function.
- **Usual position matches pregame.** It has the same three parts as pregame’s `UsualRole`, means the same thing (a missing position means the player only bats), and builds the first lineup the same way.
- **Scope.** Edits stay in `Sources/TeamScreens`, `Tests/TeamScreensTests` and the handoff.
- **Comments.** They read well for a beginner.
