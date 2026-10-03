# Walk-up audio

**Role:** audio builder.

**Waits on:** foundation. Needs Xcode.

**Owns:** `ScorebookUI/Sources/WalkUpAudio/`.

**Reads:** `Model/`, `SampleData/`.

## Deliver

The real version of the walk-up audio interface in `Model/`:

1. **Import.** Given files the scorer picked in the songs screen (MP3, M4A, WAV, AAC), copy them into the app’s own storage and add them to the song library under their file name, which can be renamed. Files from iCloud Drive need the picker’s temporary access permission opened and closed around the copy, may need downloading first, and should be read through the system’s file coordination; report a clear message when a file cannot be copied. Songs bought or streamed through Apple Music are copy-protected and cannot be imported.
2. **Start point.** Each song has a start time, set by playing the song and tapping “start here,” so a full track can begin at the hook. Optionally a length after which it fades out by itself.
3. **Play and stop.** Play a song from its start point. Stop with a fade of about two seconds. Playing a new song stops the current one. Report whether something is playing, for the button’s look.
4. **Sound settings.** Play when the silent switch is on, keep playing with the screen locked or the app in the background, play through a connected Bluetooth speaker, and take over from other music the phone is playing. These need the `.playback` audio session and the background-audio setting in the app shell; write down in the handoff note exactly what the lead builder must switch on.
5. **Between-innings music.** A playlist of imported songs, played in order or shuffled during changeovers, with the same play and fade.
6. **Stadium announcer, after everything above works.** An introduction that plays before a player’s walk-up song: “Now batting, number two, Derek Jeter. Number two.” Two sources per player: an imported recording, or the iPhone’s built-in speech voice reading the player’s number and name with long pauses in that cadence, run through a reverb effect for a stadium echo. Offer a few built-in voices to choose from, and a test button. The one-tap play button plays the introduction, then the song from its start point.
7. **A test screen** in the module’s previews: list songs, play, stop, set start point, play an introduction, so the audio can be checked before the batting screen exists.

## Finish line

On the simulator: import three files, play an introduction followed by its song, set a start point on one, play it, play another (the first stops), fade one out. On Mikey’s phone, once the app can be installed: the same with the silent switch on and the screen locked, through a Bluetooth speaker.

## Watch out for

A phone call or a Siri interruption stops audio; after it, the player must be ready to play again. If the Bluetooth speaker disconnects mid-song, stop the song so it does not carry on through the phone’s own speaker. Starting playback must feel instant, so load the next batter’s song before the button is tapped.
