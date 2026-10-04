# Walk-up audio: handoff

**Job:** walk-up audio (audio builder).

**Branch:** `codex/walk-up-audio`, in the task folder `/Users/mikey/projects/.worktrees/baseball/walk-up-audio`.

## What exists now

Everything is in `app/Packages/ScorebookUI/Sources/WalkUpAudio/`. Nothing outside that folder changed except this note.

- **`StadiumAudioPlayer`**, the real version of Model’s `WalkUpAudioPlayer` promise. Make it once with `StadiumAudioPlayer(audioFolder: storage.audioFolder, library: savedLibrary)` and share it. It runs on the main thread; copying files in runs in the background.
- **Walk-ups.** One call plays the walk-up. With no introduction, the song starts at its start point at full volume (that song’s own loudness) and is silent exactly when the walk-up length runs out (12 seconds unless changed); the fade takes the last 2 of those seconds.
- **The song fading in under the announcer**, the way stadiums do it. When the player has an introduction (recorded, imported, pieced together, or the phone’s voice) and introductions are on, the song starts at the same moment as the voice, from the start point less the introduction’s length, so it reaches the start point (the hook) just as the announcer finishes. It starts silent, rises gently to about a third of full volume over the first 2 seconds, stays there under the voice, and rises to full volume over the last second. The usual 12 seconds then play: 10 at full volume and the 2-second fade. With a 4-second introduction and the hook at 0:20, the song starts at 0:16 and the walk-up lasts 16 seconds. A song whose start point is closer to the top than the introduction is long starts at 0:00 and fades in the same way, so it reaches full volume a little past its start point. The introduction’s length is known before the tap because `cue` makes it ahead (the phone’s voice is spoken into memory, then measured). `WalkUpMath.walkUpPlan` and `fadeInVolume` hold the timing and the volume curve. `fadeOut()` fades over 2 seconds when tapped; `stop()` stops at once. Playing anything new stops what is playing. The introduction and the song are lined up on the audio clock together, so there is no gap or stutter between them.
- **The countdown.** `playback`, the reading main added to the audio promise, gives the phase (introduction, song, warm-up or nothing), the song, and `fadesAt`: the moment the walk-up song’s fade begins, which with 12 seconds of song is 10 seconds after the song starts (Mikey’s choice: 10 seconds at full volume, then a 2-second fade). `timeLeft` is also there: the seconds until the whole walk-up goes quiet, counted from the tap, the introduction included, then the rest of the fade once one starts. It updates ten times a second and is missing for previews and warm-ups, which play until stopped. `isPlayingIntroduction` and `isFadingOut` say which part is playing.
- **Loading ahead.** `cue(for:)` opens the batter’s song file and turns their introduction into sound in memory, so the button starts at once. Measured on the simulator: about a tenth of a second from tap to sound, including switching the iPhone’s audio on. Only one introduction is made per player at a time: a tap while `cue` is still making it waits for that job. If the introduction is still not ready 3 seconds after the tap, the song plays without it, `lastProblem` says so, and the introduction is ready for next time.
- **Pitcher warm-ups.** `playWarmUp(for:)` plays from the song’s start point to the end of the track and loops back to the start point, with no gap, until stopped or faded. If nobody stops it, it fades by itself after five minutes (`longestWarmUp`).
- **The stadium announcer.** Three sources, as in the brief:
  - *Recorded in the app:* `startRecordingIntroduction()`, then `stopRecordingIntroduction()` returns the new introduction. To listen before keeping it, call `playIntroduction(for:)` with a copy of the player holding the new introduction. To redo, call `discardIntroduction(_:)`, which deletes the file. A take that ends by itself, at the 30-second limit or because a call or Siri cut it off, is finished at once: the phone goes back to ordinary playback, the take appears in `pendingRecording` with a note in `lastProblem`, and `stopRecordingIntroduction()` collects it. Anything under half a second is deleted. Starting a new take throws away an uncollected one. If recording cannot start, the phone goes straight back to playback and `RecordingProblem.message` says why. The very first tap, while iOS is still asking about the microphone, gets “Answer the iPhone’s question about the microphone, then tap record again.”
  - *Imported:* `importIntroduction(from:)` copies a file in, named `intro-…`. Anything over 30 seconds (a whole song picked by mistake) is refused and its copy deleted.
  - *The phone’s voice:* reads “Now batting, number two, Derek Jeter. Number two.” slowly and low, with pauses of about half a second, half a second and nearly a second between the parts. A player with only a name gets “Now batting, Derek Jeter.”; only a number gets the number twice; “00” is read “double zero” and “07” “oh seven”. It uses the best American English voice on the phone, a male one if there is a choice. The voices are looked up in the background when the player is made, because the first lookup on a new phone can take a long time (minutes on a freshly set-up simulator) and would otherwise freeze the screen. A phrase the voice does not finish within six seconds makes the whole introduction fail, and nothing clipped is kept.
  - *Stadium echo:* a bounce off the far stands plus a big-hall reverb (an effect that makes a sound ring like a large room), both set by `setAnnouncerEcho(_:)` from 0 to 1, once for all players. It is added at the moment of playing and the files stay as recorded, so changing the setting changes every introduction.
- **Import.** `importSongsWithReport(from:)` copies each file in the background: it opens the file picker’s temporary permission for that file and closes it after, starts an iCloud Drive or Dropbox download if the file is not on the phone yet and waits for it for at most about a minute (then: “It is still downloading from iCloud Drive or Dropbox. Try again when the phone is online.”), reads it through Apple’s file coordination (the polite way to read a file iCloud may be writing) on its own background queue within the same minute, copies it into the audio folder under a free name (a second “Intro.mp3” becomes “Intro 2.mp3”), then opens the copy to check it plays. It returns the songs plus a plain message for each file that failed, so every good file comes in even when one fails. Apple Music files are refused as copy-protected. `WalkUpAudioError.message` gives a sentence for each problem, such as “‘notes.txt’ could not be copied in. It is not a sound file the app can play. Use an MP3, M4A, WAV or AAC file.”
- **Phone behavior.** Plays with the silent switch on, with the screen locked or the app in the background, through a Bluetooth speaker, and stops other apps’ music while it plays, then hands the speaker back so their music can carry on. A phone call or Siri stops the song and resets the button; the next tap plays normally. A Bluetooth speaker or headphones disconnecting stops the song at once and sets `lastProblem` to “The speaker disconnected, so the song stopped.” Any other speaker change that makes iOS restart the audio engine mid-play (a speaker connecting, or the phone switching its sound settings to suit one, which can happen just after the tap) picks the song up where it was with the same time left; a walk-up still in its introduction starts over. If that fails, or happens three times in one play, it stops with “The speaker changed. Tap again.” It never ends silently. A late notice about the app having been paused in the background is ignored. If iOS resets its whole audio system, the player rebuilds itself.
- **Missing songs.** A batter whose song is gone from the library gets “Derek Jeter’s walk-up song is no longer in the song library. Pick a song for them again.” A song whose file is gone gets “The sound file for ‘Thunderstruck’ is missing or damaged. Import the song again.” The same goes for a pitcher’s warm-up song.
- **Library edits.** `rename`, `setStartPoint` (kept at least a second before the end of the track), `setPlayLength`, `setVolume` (takes effect at once if that song is playing), `setAnnouncerEcho`. `onLibraryChanged` is called after every change, for saving.
- **Timing sums in one place.** `WalkUpMath` holds the arithmetic (when the fade begins, the fade’s volume curve, the countdown, where a repeating warm-up is, which slice of a file plays, start points), used by the player and checked by the tests.
- **The test screen.** `WalkUpAudioTestScreen(player:)`, with previews in light, dark and the largest text size: list and import songs, make three test songs, play from the top or the start point, “Start here” while previewing, a loudness slider per song, a walk-up with or without its introduction, a countdown, fade and stop, record, listen, keep or redo, import a recording, the echo slider, the walk-up length, the warm-up song, and a level meter. One Files picker serves both import buttons (SwiftUI may ignore a second picker on one screen). It is public, so the app shell can also open it from a hidden menu to check the audio on Mikey’s phone. `TestSongMaker` writes the three test songs: 40 seconds of tones in WAV, M4A and AAC, a click every second and a new note every five seconds, so you can hear where you are.

## What the lead builder must switch on in the app shell

Both checked in a copy of the app shell outside the repository: the built app’s Info.plist held both entries.

1. **Background audio.** The generated Info.plist ignores `INFOPLIST_KEY_UIBackgroundModes` (tried: the key was silently dropped). Instead, add a file `app/Scorebook-Info.plist`, outside the `Scorebook/` folder so Xcode does not try to bundle it, holding only this:

   ```xml
   <?xml version="1.0" encoding="UTF-8"?>
   <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
   <plist version="1.0">
   <dict>
   	<key>UIBackgroundModes</key>
   	<array>
   		<string>audio</string>
   	</array>
   </dict>
   </plist>
   ```

   and add `INFOPLIST_FILE = "Scorebook-Info.plist";` to the Scorebook target’s Debug and Release build settings. Xcode merges it with the generated keys. (Xcode’s Signing & Capabilities tab, Background Modes, Audio, does the same thing by hand.)
2. **Microphone permission text.** Add to the Scorebook target’s Debug and Release build settings: `INFOPLIST_KEY_NSMicrophoneUsageDescription = "Records the stadium announcer introductions you make for your players.";` Without it, the app is closed by iOS the moment it asks for the microphone.
3. **The audio session category** (Apple’s word for how an app uses sound): nothing to do. The player sets “playback” itself when it is made, and switches to “play and record” only while recording. Make the player when the app opens, so it is set before the first tap.

## For the wiring job

- Set `audio.walkUpLength = settings.walkUpSongSeconds` at launch and whenever the setting changes.
- The song button: during the announcer the song is already playing underneath, and `playback.phase` stays `introduction` until the voice ends; `playback.fadesAt` arrives with the song phase, as before, so the button’s microphone-then-countdown keeps working unchanged. To count down the whole walk-up from the tap instead, read `timeLeft` on the player; `AudioPlayback` could also carry `fadesAt` during the introduction, which would mean changing its comment in `Model/` (“Missing during the introduction”), so that is left to the lead builder.
- Save the library from `onLibraryChanged`: `audio.onLibraryChanged = { library in Task { try await storage.saveSongLibrary(library) } }`. `addSongs` triggers it too.
- Import with `importSongsWithReport`, then `addSongs(report.songs)`, and show each `problem.message`. Hand the picker’s URLs straight over; do not open them first. SwiftUI’s `.fileImporter(isPresented:allowedContentTypes: [.audio], allowsMultipleSelection: true)` gives the right kind of URL.
- Call `cue(for:)` as soon as our next hitter is known, and again after a song or introduction is changed.
- For the song button: `playback` (or `isPlaying` and `nowPlaying`) for its look, `playback.fadesAt` or `timeLeft` for the countdown, `fadeOut()` for the second tap. “Fade on the first pitch” is also `fadeOut()`, for walk-ups and warm-ups alike.
- Before the first recording, call `requestMicrophoneAccess()` (it asks the scorer once). If permission has not been asked yet, `startRecordingIntroduction()` asks and throws `RecordingProblem.askingForPermission`, so the scorer taps record again.
- On the record screen, watch `pendingRecording`: when it appears, the take ended by itself; call `stopRecordingIntroduction()` to collect it and offer listen, keep or redo, showing `lastProblem` as the reason.
- When a player’s introduction is replaced or removed, call `discardIntroduction(_:)` on the old one so its file does not linger.
- Show `lastProblem` somewhere quiet when it is set (a missing song file, a disconnected speaker).
- Pass `withIntroduction: settings.playIntroductions` to `playWalkUp`.

## Vocabulary requests

None is required; each is worked around with an addition on `StadiumAudioPlayer`, which the app shell holds directly. They would let screens and the silent stand-in use them too.

1. **Reword the comment on `AudioPlayback.fadesAt`.** It says “the moment the song started plus the walk-up length”; with Mikey’s choice the fade *begins* 2 seconds before that and the song is silent at that moment. The real player reports when the fade begins. Suggested wording: “When the walk-up song starts fading out by itself: 2 seconds before the walk-up length is up, so the song is silent exactly at the end of it.” `timeLeft` (seconds until silent) stays on the real player as a convenience; nothing needs it in the promise now.
2. **Have `importSongs` return the songs and the problems together** (the shape of `SongImportReport`), so a failed file among several is reported. As written, the promise can only return songs or throw; the real player throws only when nothing at all came in.
3. **Add `discardIntroduction(_:)`** for “redo”, so the throwaway recording’s file is deleted.
4. **Add `requestMicrophoneAccess() async -> Bool`**, so the record button can ask before the first recording.
5. **Add `onLibraryChanged`**, so saving the library does not depend on the wiring watching `library`.
6. **Add `pendingRecording`**, so a record screen built against the promise can collect a take that ended by itself.
7. **Package.** `WalkUpAudio` may use only `Model`, so the test screen uses plain iPhone styling and its own made-up batter in place of `SampleData`. That is fine for a workbench.

## Decisions

- **After a call or Siri, nothing restarts by itself.** A walk-up song coming back mid-at-bat would be wrong; the button is simply ready again.
- **Mikey’s two choices stand as built**: 10 seconds at full volume plus a 2-second fade, and the echo on every introduction.

## Evidence

Checked on the iPhone 17 simulator (iOS 27) with a throwaway harness app outside the repository, which ran a scripted check and logged what the player reported. It used the three test songs, two of Mikey’s songs from `~/Dropbox/baseball/songs/` (played quietly), and three bad files.

- **Import:** the WAV, M4A and AAC test songs and both real M4A songs came in with their lengths (40, 40, 40.05, 271.3 and 50 seconds). A text file renamed `.mp3`, a `.txt` file and a missing file each gave its own plain message. Importing the same file twice gave “Test song - climbing 2.wav”.
- **Introduction, then song** (in the first build, before the fade-in): the phone’s voice read the introduction in 6.2 seconds; the song started after it and went silent 12 seconds later, with the loudness steady until the last 2 seconds and then falling to nothing. First sound came 0.11 seconds after the tap.
- **Start point:** a song with its start point at 10 seconds began at 10.
- **Playing another:** starting a second song stopped the first at once and reported it ended.
- **Fade:** a tapped fade took 2.05 seconds and left the button reset.
- **Warm-up:** started at 30 seconds of a 40-second track, it looped back to 30 and was still playing after 13 seconds (at 33.1).
- **Introduction alone:** 8.2 seconds including the echo dying away; a number-only introduction (“00”) 7.1 seconds.
- **Interruption and speaker loss** (the simulator cannot make a call or lose a speaker, so the harness sent the iPhone’s own notices by hand): a call stopped the song and reset the button, and the next play started at once; a speaker disconnecting stopped the song and set the message.
- **Background:** with Settings opened over the app mid-song, the walk-up still faded and ended on time (8.4 seconds for an 8-second length, the extra being the check’s half-second sampling), and a warm-up kept playing.
- **Recording:** recorded 3 seconds from the simulator’s microphone, played it back with the echo, and “redo” deleted the file. A song played straight after recording started in 0.13 seconds.
- **The test screen** opens and draws in the harness. Xcode’s preview canvas was not opened; the previews are the same screen. The single file picker was not tapped by hand (the harness imports without the picker).

After the review, the same harness checked each fix (the speaker change was acted out with a debug-only hook, `actOutSpeakerChangeForTesting()`, which stops the engine the way iOS does and sends its notice):

- **Speaker change mid-song:** 3 seconds into a 10-second walk-up, the song picked up where it was and played its remaining 7 seconds (7.6 measured), with no message.
- **Speaker change during the introduction:** the walk-up started over and played normally.
- **Three speaker changes in one play:** it stopped with “The speaker changed. Tap again.”
- **Recording cut off by a call:** the take was finished and handed back with its note, and the phone was back in playback mode. **Recording left running:** it stopped at 30 seconds, the take was handed back with “The recording stopped at the 30-second limit…”, the phone was back in playback mode, and a song played straight after it in 0.12 seconds.
- **Warm-up limit:** with the limit set to 6 seconds for the check, the warm-up faded and ended at 6.1.
- **Missing song:** the message above, and nothing played.
- **A 40-second file as an introduction:** refused with “…an introduction can be at most 30 seconds…”, its copy deleted.
- **The phone’s voice not ready yet** (a freshly wiped simulator, whose voices take minutes to set up): the song started 3 seconds after the tap and played its full 12 seconds, and the screen never froze. Before the background voice lookup, this froze the screen for about two and a half minutes.

The song fading in under the announcer, checked with a test song whose start point is 0:20 (the harness logged the song’s position and the loudness every tenth of a second):

- **A silent 4-second introduction** (so the meter heard only the song): the song started at 0:16, was silent at first, rose to a third of its full loudness by 2 seconds, held there, and reached full loudness at 4.0 seconds, at 0:20. The walk-up lasted 16.1 seconds and the countdown started at 16.
- **The phone’s voice** (“Now batting, number twenty-two, Aidan Kurt.”): the announcer finished at 4.5 seconds with the song at 0:20.1, and the walk-up lasted 16.4 seconds.
- **A 3-second microphone recording:** the announcer finished at 3.2 seconds with the song at 0:20.1; the walk-up lasted 15.1 seconds.
- **A start point of 0:01.5 with the phone’s voice:** the song started at 0:00 and was at 0:03.8 when the announcer finished, as intended.
- **No introduction:** the song started at 0:20 at full volume and lasted 12.1 seconds.
- **Tapping stop during the announcer:** voice and song faded together over 2.08 seconds.

Builds and tests:

- `xcodebuild test -scheme ScorebookUI-Package -only-testing:WalkUpAudioTests` on the iPhone 17 simulator, after the fade-in: 38 tests in 7 suites, all passing, among them “The song fading in under the announcer” (the hook reached as the announcer finishes; a start point near the top starting at 0:00; no introduction unchanged; silent, a third, then full volume; the volume never dips; a very short introduction; the countdown over the whole walk-up). The Scorebook app builds. Before the fade-in: 28 tests in 5 suites, all passing. They cover the fade timing (12 seconds is 10 at full volume and a 2-second fade; a song’s own length wins; the fade curve), the countdown with an introduction, warm-up looping (including after a speaker change mid-track), file slices and start points, the announcer’s words for every kind of player (they caught “number 22,” where a number-only introduction needed “number 22.”), importing (good files with their lengths, the same name twice, a text file, a fake MP3 with its copy removed, an Apple Music file, a missing file, one bad file among good ones, a too-long introduction), library edits being reported for saving, the missing-song and missing-file messages, and the recording messages.
- `xcodebuild -scheme ScorebookUI-Package -destination 'platform=iOS Simulator,name=iPhone 17' build` in `app/Packages/ScorebookUI`, after merging `main`: succeeded with no warnings from this module.
- `swift test` in `app/Packages/ScorebookCore`: every test passes (197).

## Only a real iPhone can confirm

- **A speaker change, first.** Connect a Bluetooth speaker while the app is idle, then tap a walk-up: it should play through the speaker, and if iOS restarts the sound just after the tap, the song should carry on (or, at worst, stop with “The speaker changed. Tap again.”). Also turn the speaker on and off between songs.
- Playing with the silent switch on, and with the screen locked through a full walk-up and a two-minute warm-up.
- A real Bluetooth speaker turned off mid-song: the song stops, with nothing coming out of the phone’s own speaker.
- A real phone call and a real Siri request mid-song, then tap again.
- Importing from iCloud Drive and from Dropbox through the Files app: a file already on the phone, a file not yet downloaded, the same file with no signal (the message should come after about a minute), and the copy-protected message for an Apple Music song.
- Tapping both import buttons on the test screen, since the harness imported without the picker.
- Recording: grant microphone permission, refuse it, and change it later in Settings; let a take run to 30 seconds; take a call while recording. Each take should come back to listen to, keep or redo, and a song should play normally afterward.
- A warm-up left playing: it should fade by itself after five minutes, screen locked or not.
- How the song fading in under the announcer sounds through the speaker at the field: whether a third of full volume is the right level under Mikey’s voice (`WalkUpMath.underVoiceLevel`), and whether the rises feel smooth with the screen locked (the volume is stepped fifty times a second by the player’s own timer).
- How the microphone recording, the phone’s voice and the stadium echo actually sound through a speaker at the field, and what echo setting Mikey likes. Better voices can be downloaded on the phone in Settings, Accessibility, Spoken Content, Voices (an “Enhanced” or “Premium” American English voice); the app picks the best one installed.
- The delay from tap to sound on the phone, which the simulator suggests is about a tenth of a second, and that the phone’s voice is ready by the first at-bat (the voices are looked up in the background when the app opens).

## Not done

- No way to delete a song from the library, and no clean-up of song files nothing points to. The songs screen brief does not ask for deletion; it would need a vocabulary addition.
- The interruption and speaker checks on the simulator sent iOS’s notices by hand; how a real phone sends them is on the list above.
- On the simulator, the very first recording once stalled for a long time while the Mac set up its microphone; later recordings started at once. Starting a recording switches the iPhone’s audio on in one step on the main thread, which Apple warns can briefly freeze the screen; on a phone it normally takes a moment, but it is worth watching the first time Mikey records.
