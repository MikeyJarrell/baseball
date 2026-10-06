# Walk-up audio

**Role:** audio builder.

**Waits on:** foundation. Needs Xcode.

**Owns:** `ScorebookUI/Sources/WalkUpAudio/`.

**Reads:** `Model/`, `SampleData/`.

## Deliver

The real version of the walk-up audio interface in `Model/`:

1. **Import.** Given files the scorer picked in the songs screen (MP3, M4A, WAV, AAC), copy them into the app’s own storage and add them to the song library under their file name, which can be renamed. Files from iCloud Drive need the picker’s temporary access permission opened and closed around the copy, may need downloading first, and should be read through the system’s file coordination; report a clear message when a file cannot be copied. Songs bought or streamed through Apple Music are copy-protected and cannot be imported.
2. **Start point.** Each song has a start time, set by playing the song and tapping “start here,” so a full track can begin at the hook. Every walk-up song fades out by itself after a set length of song, 12 seconds by default, counted after any announcer introduction; the length is an app setting.
3. **Volume.** Songs ripped from different places play at different loudness. Each song gets its own volume level, so the whole library can be evened out.
4. **Play and stop.** Play a song from its start point. Stop with a fade of about two seconds, either when tapped or when the set length runs out. Report the time left, for a countdown on the button. Playing a new song stops the current one. Report whether something is playing, for the button’s look.
5. **Sound settings.** Play when the silent switch is on, keep playing with the screen locked or the app in the background, play through a connected Bluetooth speaker, and take over from other music the phone is playing. These need the `.playback` audio session and the background-audio setting in the app shell; write down in the handoff note exactly what the lead builder must switch on.
6. **Pitcher warm-up music.** Play the current pitcher’s warm-up song when our team takes the field, until stopped or the first pitch is recorded, with the same fade.
7. **Stadium announcer, after everything above works.** An introduction that plays before a player’s walk-up song: “Now batting, number two, Derek Jeter. Number two.” Mikey records these himself. Three sources per player: a recording made in the app with the phone’s microphone (record, play back, keep or redo), an imported recording, or the iPhone’s built-in speech voice reading the player’s number and name with long pauses in that cadence. Recordings get a reverb effect for a stadium echo, adjustable, set once for all players. Recording needs microphone permission, which the lead builder switches on in the app shell. The one-tap play button plays the introduction with the song fading in underneath it, quiet while the announcer talks and reaching full volume at its start point as the introduction ends; the song therefore begins playing before its start point by the introduction’s length. Every song gets this same fade-in. When the start point is closer to the beginning of the clip than the introduction is long, the song starts from the beginning of the clip and still fades in over the whole introduction, reaching full volume after its start point; that is fine. The clips Mikey supplies carry about 20 seconds before the start point and 30 after it for this, and their start point is listed in `team/roster.csv`. A player’s name can also be recorded on the phone for a pieced introduction: cleaned up the way tools/record_intros.py cleans the Mac’s pieces (trimmed, leveled, 48 kHz mono) so the pieces join (plan/handoffs/name-recording.md).
8. **A test screen** in the module’s previews: list songs, play, stop, set start point, play an introduction, so the audio can be checked before the batting screen exists.

## Finish line

On the simulator: import three files, play an introduction followed by its song, set a start point on one, play it, play another (the first stops), fade one out. On Mikey’s phone, once the app can be installed: the same with the silent switch on and the screen locked, through a Bluetooth speaker.

## Watch out for

A phone call or a Siri interruption stops audio; after it, the player must be ready to play again. If the Bluetooth speaker disconnects mid-song, stop the song so it does not carry on through the phone’s own speaker. Starting playback must feel instant, so load the next batter’s song before the button is tapped.
