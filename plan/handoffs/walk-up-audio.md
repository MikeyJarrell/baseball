# Walk-up audio: handoff

**Job:** walk-up audio (audio builder).

**Branch:** `codex/walk-up-audio`, in the task folder `/Users/mikey/projects/.worktrees/baseball/walk-up-audio`.

## What exists now

Everything is in `app/Packages/ScorebookUI/Sources/WalkUpAudio/`. Nothing outside that folder changed except this note.

- **`StadiumAudioPlayer`**, the real version of Model’s `WalkUpAudioPlayer` promise. Make it once with `StadiumAudioPlayer(audioFolder: storage.audioFolder, library: savedLibrary)` and share it. It runs on the main thread; copying files in runs in the background.
- **Walk-ups.** One call plays the announcer introduction (if wanted and the player has one), a short breath, then the song from its start point at that song’s own loudness. The song is silent exactly when the walk-up length runs out (12 seconds of song unless changed, counted after the introduction); the fade takes the last 2 of those seconds. `fadeOut()` fades over 2 seconds when tapped; `stop()` stops at once. Playing anything new stops what is playing. The introduction and the song are lined up on the audio clock together, so there is no gap or stutter between them.
- **The countdown.** `timeLeft` is the seconds until the walk-up goes quiet: the rest of the introduction plus the song’s length, then the rest of the fade once one starts. It updates ten times a second and is missing for previews and warm-ups, which play until stopped. `isPlayingIntroduction` and `isFadingOut` say which part is playing, for the button’s look.
- **Loading ahead.** `cue(for:)` opens the batter’s song file and turns their introduction into sound in memory, so the button starts at once. Measured on the simulator: about a tenth of a second from tap to sound, including switching the iPhone’s audio on.
- **Pitcher warm-ups.** `playWarmUp(for:)` plays from the song’s start point to the end of the track and loops back to the start point, with no gap, until stopped or faded.
- **The stadium announcer.** Three sources, as in the brief:
  - *Recorded in the app:* `startRecordingIntroduction()`, then `stopRecordingIntroduction()` returns the new introduction. To listen before keeping it, call `playIntroduction(for:)` with a copy of the player holding the new introduction. To redo, call `discardIntroduction(_:)`, which deletes the file. Recordings stop by themselves at 30 seconds; anything under half a second is thrown away.
  - *Imported:* `importIntroduction(from:)` copies a file in, named `intro-…`.
  - *The phone’s voice:* reads “Now batting, number two, Derek Jeter. Number two.” slowly and low, with pauses of about half a second, half a second and nearly a second between the parts. A player with only a name gets “Now batting, Derek Jeter.”; only a number gets the number twice; “00” is read “double zero” and “07” “oh seven”. It uses the best American English voice on the phone, a male one if there is a choice.
  - *Stadium echo:* a bounce off the far stands plus a big-hall reverb (an effect that makes a sound ring like a large room), both set by `setAnnouncerEcho(_:)` from 0 to 1, once for all players. It is added at the moment of playing and the files stay as recorded, so changing the setting changes every introduction.
- **Import.** `importSongsWithReport(from:)` copies each file in the background: it opens the file picker’s temporary permission for that file and closes it after, starts an iCloud Drive download if the file is still in iCloud, reads it through Apple’s file coordination (the polite way to read a file iCloud may be writing, which also waits for the download), copies it into the audio folder under a free name (a second “Intro.mp3” becomes “Intro 2.mp3”), then opens the copy to check it plays. It returns the songs plus a plain message for each file that failed, so every good file comes in even when one fails. Apple Music files are refused as copy-protected. `WalkUpAudioError.message` gives a sentence for each problem, such as “‘notes.txt’ could not be copied in. It is not a sound file the app can play. Use an MP3, M4A, WAV or AAC file.”
- **Phone behavior.** Plays with the silent switch on, with the screen locked or the app in the background, through a Bluetooth speaker, and stops other apps’ music while it plays, then hands the speaker back so their music can carry on. A phone call or Siri stops the song and resets the button; the next tap plays normally. A Bluetooth speaker or headphones disconnecting stops the song at once and sets `lastProblem` to “The speaker disconnected, so the song stopped.” If iOS resets its whole audio system, the player rebuilds itself.
- **Library edits.** `rename`, `setStartPoint` (kept at least a second before the end of the track), `setPlayLength`, `setVolume` (takes effect at once if that song is playing), `setAnnouncerEcho`. `onLibraryChanged` is called after every change, for saving.
- **The test screen.** `WalkUpAudioTestScreen(player:)`, with previews in light, dark and the largest text size: list and import songs, make three test songs, play from the top or the start point, “Start here” while previewing, a loudness slider per song, a walk-up with or without its introduction, a countdown, fade and stop, record, listen, keep or redo, import a recording, the echo slider, the walk-up length, the warm-up song, and a level meter. It is public, so the app shell can also open it from a hidden menu to check the audio on Mikey’s phone. `TestSongMaker` writes the three test songs: 40 seconds of tones in WAV, M4A and AAC, a click every second and a new note every five seconds, so you can hear where you are.

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
- Save the library from `onLibraryChanged`: `audio.onLibraryChanged = { library in Task { try await storage.saveSongLibrary(library) } }`. `addSongs` triggers it too.
- Import with `importSongsWithReport`, then `addSongs(report.songs)`, and show each `problem.message`. Hand the picker’s URLs straight over; do not open them first. SwiftUI’s `.fileImporter(isPresented:allowedContentTypes: [.audio], allowsMultipleSelection: true)` gives the right kind of URL.
- Call `cue(for:)` as soon as our next hitter is known, and again after a song or introduction is changed.
- For the song button: `isPlaying` and `nowPlaying` for its look, `timeLeft` for the countdown, `fadeOut()` for the second tap. “Fade on the first pitch” is also `fadeOut()`.
- Before the first recording, call `requestMicrophoneAccess()` (it asks the scorer once). If permission has not been asked yet, `startRecordingIntroduction()` asks and throws `microphoneNotAllowed`, so the scorer taps record again.
- When a player’s introduction is replaced or removed, call `discardIntroduction(_:)` on the old one so its file does not linger.
- Show `lastProblem` somewhere quiet when it is set (a missing song file, a disconnected speaker).
- Pass `withIntroduction: settings.playIntroductions` to `playWalkUp`.

## Vocabulary requests

None is required; each is worked around with an addition on `StadiumAudioPlayer`, which the app shell holds directly. They would let screens and the silent stand-in use them too.

1. **Add `var timeLeft: TimeInterval? { get }` to `WalkUpAudioPlayer`**, for the song button’s countdown, which the at-bat brief asks for. The silent stand-in would return nothing.
2. **Have `importSongs` return the songs and the problems together** (the shape of `SongImportReport`), so a failed file among several is reported. As written, the promise can only return songs or throw; the real player throws only when nothing at all came in.
3. **Add `discardIntroduction(_:)`** for “redo”, so the throwaway recording’s file is deleted.
4. **Add `requestMicrophoneAccess() async -> Bool`**, so the record button can ask before the first recording.
5. **Add `onLibraryChanged`**, so saving the library does not depend on the wiring watching `library`.
6. **Package.** `WalkUpAudio` may use only `Model`, so the test screen uses plain iPhone styling and its own made-up batter in place of `SampleData`. That is fine for a workbench. A test target, `WalkUpAudioTests`, would let the announcer’s wording and the countdown sums be checked by `swift test`-style tests; today they are checked only through the harness below.

## Decisions to confirm

- **The 12 seconds include the fade.** The song is at full volume for 10 seconds and fades over the last 2, so the countdown reaches zero as the sound does. The other reading, 12 seconds at full volume and then a 2-second fade, is a one-line change.
- **The echo goes on every introduction:** in-app recordings, imported files and the phone’s voice. The phone’s voice sounds much more like a ballpark with it. Setting the echo to zero turns it off for all.
- **After a call or Siri, nothing restarts by itself.** A walk-up song coming back mid-at-bat would be wrong; the button is simply ready again.
- **Connecting a Bluetooth speaker mid-song also stops the song**, because iOS restarts the audio engine when the speaker changes. Tap again to play through the new speaker.

## Evidence

Checked on the iPhone 17 simulator (iOS 27) with a throwaway harness app outside the repository, which ran a scripted check and logged what the player reported. It used the three test songs, two of Mikey’s songs from `~/Dropbox/baseball/songs/` (played quietly), and three bad files.

- **Import:** the WAV, M4A and AAC test songs and both real M4A songs came in with their lengths (40, 40, 40.05, 271.3 and 50 seconds). A text file renamed `.mp3`, a `.txt` file and a missing file each gave its own plain message. Importing the same file twice gave “Test song - climbing 2.wav”.
- **Introduction, then song:** the phone’s voice read the introduction in 6.2 seconds; the song started after it and went silent 12 seconds later, with the loudness steady until the last 2 seconds and then falling to nothing. The countdown ran smoothly from 18.2 to 0. First sound came 0.11 seconds after the tap.
- **Start point:** a song with its start point at 10 seconds began at 10.
- **Playing another:** starting a second song stopped the first at once and reported it ended.
- **Fade:** a tapped fade took 2.05 seconds and left the button reset.
- **Warm-up:** started at 30 seconds of a 40-second track, it looped back to 30 and was still playing after 13 seconds (at 33.1).
- **Introduction alone:** 8.2 seconds including the echo dying away; a number-only introduction (“00”) 7.1 seconds.
- **Interruption and speaker loss** (the simulator cannot make a call or lose a speaker, so the harness sent the iPhone’s own notices by hand): a call stopped the song and reset the button, and the next play started at once; a speaker disconnecting stopped the song and set the message.
- **Background:** with Settings opened over the app mid-song, the walk-up still faded and ended on time (8.4 seconds for an 8-second length, the extra being the check’s half-second sampling), and a warm-up kept playing.
- **Recording:** recorded 3 seconds from the simulator’s microphone, played it back with the echo, and “redo” deleted the file. A song played straight after recording started in 0.13 seconds.
- **The test screen** opens and draws in the harness. Xcode’s preview canvas was not opened; the previews are the same screen.
- `xcodebuild -scheme ScorebookUI-Package -destination 'platform=iOS Simulator,name=iPhone 17' build` in `app/Packages/ScorebookUI`: succeeded with no warnings.
- `swift test` in `app/Packages/ScorebookCore`: every test passes (114).

## Only a real iPhone can confirm

- Playing with the silent switch on, and with the screen locked (the simulator has neither).
- A real Bluetooth speaker: that sound goes to it, and that turning the speaker off mid-song stops the song with nothing coming out of the phone’s own speaker.
- A real phone call and a real Siri request mid-song, and that the button works straight after.
- Importing from iCloud Drive and from Dropbox through the Files app, including a song not yet downloaded to the phone, and the copy-protected message for an Apple Music song.
- How the microphone recording, the phone’s voice and the stadium echo actually sound through a speaker at the field, and what echo setting Mikey likes. Better voices can be downloaded on the phone in Settings, Accessibility, Spoken Content, Voices (an “Enhanced” or “Premium” American English voice); the app picks the best one installed.
- The delay from tap to sound on the phone, which the simulator suggests is about a tenth of a second.

## Not done

- No way to delete a song from the library, and no clean-up of song files nothing points to. The songs screen brief does not ask for deletion; it would need a vocabulary addition.
- On the simulator, the very first recording once stalled for a long time while the Mac set up its microphone; later recordings started at once. Starting a recording switches the iPhone’s audio on in one step on the main thread, which Apple warns can briefly freeze the screen; on a phone it normally takes a moment, but it is worth watching the first time Mikey records.
