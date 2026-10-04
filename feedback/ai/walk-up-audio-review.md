# Walk-up audio: review

**Reviewer:** a fresh builder who did not do the job, reading the brief, the handoff note and `git diff origin/main...HEAD`.

**Verdict:** Solid and close to done; fix the silent stop when the speaker changes and the lost 30-second recording before accepting, and the rest are small.

## What checks out

- Only `app/Packages/ScorebookUI/Sources/WalkUpAudio/` and the handoff note changed.
- `xcodebuild -scheme ScorebookUI-Package -destination 'platform=iOS Simulator,name=iPhone 17' build`: succeeded, no warnings, in Swift 6 mode.
- The sound setting is “playback” with no extra options. That is what the brief wants: it ignores the silent switch, plays through a Bluetooth speaker, and stops other apps’ music while it plays. After each song the app lets go of the speaker and tells other apps they can resume.
- A new song cannot inherit an old fade. Stopping resets the volume and the timing, and every message about an older song is ignored because each play carries its own number.
- The song is cut to exactly the walk-up length when it is lined up, so it goes quiet on time even if the screen is busy and the fade steps late.
- A speaker disconnecting stops the song. A reset of the iPhone’s audio system rebuilds the player.
- Importing opens the file picker’s permission and always closes it, refuses Apple Music files, and never overwrites a file with the same name.
- The instructions for the lead builder are right. Background audio is the `UIBackgroundModes` array holding `audio`, merged in through `INFOPLIST_FILE`. The file sits in `app/`, outside the `Scorebook/` folder that Xcode bundles by itself. The microphone text goes in `INFOPLIST_KEY_NSMicrophoneUsageDescription`.
- The comments are plain and explain the baseball reason for each step.

## Findings, worst first

1. **A speaker change can stop a walk-up with no message.** `StadiumAudioPlayer.swift:787-793`. The player lets go of the speaker after every song and claims it again on every tap. If claiming it switches the sound to a Bluetooth speaker that runs at a different quality setting, iOS restarts the audio engine just after the tap. The player then quietly ends the play: the button flips back to idle and `lastProblem` stays empty. This is most likely on the first tap after the speaker connects. **Fix:** when the engine stops by itself mid-play, start it again and pick the song back up where it was. At the least, set `lastProblem` to “The speaker changed. Tap again.” Check this first on the phone.
2. **A recording that reaches 30 seconds, or is cut off by a call, is lost and leaves recording mode switched on.** `StadiumAudioPlayer.swift:342`, `569-573`, `797-803`, `328`. The recorder stops by itself, `isRecording` turns false, and the screen offers “Record” again, so `stopRecordingIntroduction()` is never called. The take is never returned. The next recording replaces the old recorder (line 328 checks `isRecording`, not `recorder`), which leaves the old file behind. Until something calls stop, the phone stays in “play and record” mode. In that mode `finish()` never switches the engine off or hands the speaker back (line 653), so other apps’ music does not resume, the engine runs on, and the 20-times-a-second timer never stops. **Fix:** when the recorder stops by itself, finish the recording and publish the result (for example a `pendingRecording` property). Change line 328 to `if recorder != nil`.
3. **Importing a song that is not yet on the phone can hang with no message.** `SoundFileImporter.swift:91`. The coordinated read waits for the iCloud Drive or Dropbox download with no time limit, and it blocks one of Swift’s shared background threads while it waits. With no signal at the field, the import may never return. **Fix:** check the download status and wait no more than about 60 seconds. Then report “still downloading from iCloud Drive; try again when the phone is online.” Run the blocking read on its own background queue.
4. **Imported introductions have no length limit and are read whole into memory.** `StadiumAudioPlayer.swift:379-382`, `724-733`, `715`. A whole song picked by mistake as an introduction takes about 85 MB, and up to 30 introductions are kept ready at once. **Fix:** refuse imported introductions longer than 30 seconds, the same limit recordings have.
5. **The phone’s voice can be cut short and stay that way.** In `AnnouncerVoice.swift:107-111`, each phrase is given up on after six seconds and whatever has arrived is used. The result is kept (`StadiumAudioPlayer.swift:714-719`), so a clipped introduction plays every time until the player’s name changes. Separately, `cue` (line 251) and a tap before the voice has finished (line 266) both start making the same introduction on one speech engine, which doubles the wait. **Fix:** do not keep a result that timed out. Keep one in-progress job per player and have the tap wait for that job.
6. **A warm-up song has no limit.** `StadiumAudioPlayer.swift:299-307`. If the first-pitch fade is missed, the song loops for as long as the phone allows, including with the screen locked. **Fix:** fade by itself after a generous limit, such as five minutes.
7. **An old interruption notice could stop a new song.** `StadiumAudioPlayer.swift:748-756`. iOS sometimes delivers an “interruption began” notice late, when the app comes back after being paused in the background. **Fix:** ignore the notice when its reason is `.appWasSuspended`.
8. **The first tap on Record shows the wrong message.** `StadiumAudioPlayer.swift:321-324`. It throws `microphoneNotAllowed`, whose message says to turn the microphone on in Settings, while iOS is still asking the question for the first time. **Fix:** wait for the answer inside the call, or give this case its own message.
9. **The test screen has two file pickers attached to one view.** `WalkUpAudioTestScreen.swift:50-56`. SwiftUI often honors only one of them, so “Import songs from Files” or “Import a recording” may do nothing. The handoff’s import evidence came from a script that skipped the picker. **Fix:** use one `.fileImporter` with a mode that records whether a song or an introduction is being picked. Tap both buttons to confirm.
10. **A tap does nothing, with no message, when the player’s song is missing from the library** and there is no introduction. `StadiumAudioPlayer.swift:260`. **Fix:** set `lastProblem`.
11. **A failed recording start leaves the phone in “play and record” mode.** `StadiumAudioPlayer.swift:331`, `341`. **Fix:** switch back to playback whenever starting the recording throws.

## Still to check on a real iPhone

- Finding 1: connect a Bluetooth speaker while the app is idle, then tap a walk-up. Also turn the speaker on and off between songs.
- Play with the silent switch on, and with the screen locked through a full walk-up and a two-minute warm-up.
- Turn the Bluetooth speaker off mid-song: the song must stop, and nothing should come out of the phone’s own speaker.
- A real call and a real Siri request mid-song, then tap again.
- Import from iCloud Drive and Dropbox, including a file not yet downloaded and the same file with no signal (finding 3), plus the Apple Music message.
- Recording: grant microphone permission, refuse it, and change it later in Settings; let a take run to 30 seconds (finding 2); take a call while recording.
- How the delay from tap to sound, the phone’s voice and the stadium echo actually sound through the speaker at the field.
