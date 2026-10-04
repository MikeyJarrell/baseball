# Teams and songs screens: handoff

**Job:** screen builder, teams and songs.

**Branch:** `codex/screen-teams-and-songs`, in the task folder `/Users/mikey/projects/.worktrees/baseball/screen-teams-and-songs`.

## What exists now

Everything is in `app/Packages/ScorebookUI/Sources/TeamScreens/`, with tests in `Tests/TeamScreensTests/`. Nothing outside those folders changed except this note and its screenshots.

- **Teams list** (`TeamsListScreen`): our team on top with the logo and “12 players · 10 with songs”, opponents below in alphabetical order with “12 players, names and numbers” or “11 players, numbers only”, an Add a team button, and Rename by a long press or a swipe. With no team marked ours, the top card offers “Set up our team”.
- **Roster** (`RosterScreen`): the team’s logo or letter, chips for Quick entry and (ours) Songs, and every player with number, name, usual position and role, and for our players their walk-up song, warm-up song and introduction (“No walk-up song” stands out in our blue). The plus button adds one player; a swipe removes one, after a confirmation. Our players open their page; an opponent opens the edit sheet. The team menu renames the team. An empty team shows Quick entry and Add one player.
- **Edit sheet** (`PlayerEditSheet`): number, name, bats (right, left, switch), throws, usual position, leads off, starts on the bench, and Remove from team. Bats and throws can be left unknown: tapping the chosen one again clears it. A number another player already wears is mentioned, never refused.
- **Quick entry** (`QuickEntrySheet`): one line per player, “22 Jordan Webb”, then Return. The player is saved at once, the line clears and the keyboard stays up. Bats, throws and usual position are one optional tap each beside the line; they start right-handed for our team and unknown for an opponent, and reset after each player.
- **Player page** (`PlayerPage`): the big number badge, name, “Center field, leads off · Bats R · Throws R”, then three cards as in the mockup. Walk-up song: the song with where it starts and its volume, Preview (Stop while it plays) and Change song. Pitcher warm-up song: the song and Pick or Change. Announcer introduction: the script (“Now batting, number twenty-two, Jordan Webb. Number twenty-two.”, worded as the audio player reads it, “00” as “double zero”), where it comes from, a red Record button, Listen, Import, and Use the iPhone voice. At the bottom, “Test: introduction, then song”.
- **Recording sheet** (`RecordIntroductionSheet`): the script, a moving level bar while recording, the time recorded, the big round button (a dot to record, a square to stop), then Listen and Redo, and Keep along the bottom. The stadium echo switch sits below. An imported recording opens the same sheet to listen and keep it.
- **Song library** (`SongLibraryScreen`): every song with a play button, where it starts and who uses it (“walk-up: Moreno · warm-up: Barros”, or “unassigned”), the Import button (the iPhone’s file picker, several files at once), “Copying songs in…” while importing, and any import problems with an OK button.
- **Song page** (`SongPage`): the start point in tenths of a second over a drawing of the track. It is set by listening (play from the top, tap “Start here” at the hook), by tapping or dragging along the drawing, or with −1 s, −0.1 s, +0.1 s, +1 s. “Play from 0:14” checks it. Volume is a slider (40 to 100 percent, lower if a song is already lower). “Used by” lists our players with this song, and Assign to a player opens our roster with a Walk-up or Warm-up choice. Rename is in the top bar.
- **Song picker** (`SongPickerSheet`): from a player, a searchable list of every song with a play button, “No walk-up song” at the top, and a check by the one chosen. Each tap saves at once.

## How the screens talk to the app shell

The screens are handed `TeamScreensData` (the saved teams, the song library, each player’s usual position and role, and `TeamScreensAudio`: what is playing, where in the track, where a recording stands, whether songs are being copied in, and messages) and hand back `TeamScreensRequest`s. They link to each other with `TeamScreensRoute` values. Put `.teamScreenDestinations(data, onRequest:)` on the app’s navigation stack, or use `TeamScreensStack(start: .teams or .songs, data:onRequest:)`.

| Request | What the app shell does |
|---|---|
| `saveTeam(team)` | Replace the team in memory at once, then `storage.saveTeam`. Quick entry sends one per player, each building on the last, so the in-memory copy must update before the next one arrives. |
| `setUsuals(usuals, for:)` | Keep each player’s usual position and role (see the vocabulary request below). |
| `importSongs(urls)` | `importSongsWithReport(from:)`, then `addSongs(report.songs)`; set `isImporting` while it runs and put each `problem.message` in `problems`. |
| `renameSong`, `setStartPoint`, `setVolume`, `setAnnouncerEcho` | The audio player’s functions of the same names; it saves the library through `onLibraryChanged`. |
| `playPreview(song, from:)` | `playPreview(_:from:)`. Pass `playbackPosition` back as `position`, about ten times a second, so “Start here” catches the hook. |
| `playWalkUp(player)` | `playWalkUp(for:withIntroduction: true)`: the test always plays the introduction. |
| `playIntroduction(player)` | `playIntroduction(for:)`. The player may carry a new recording not yet kept. |
| `stopPlaying` | `stop()`. |
| `startRecording(for:)` | `requestMicrophoneAccess()` the first time, then `startRecordingIntroduction()`; set `recording = .recording(player, since: now)`. |
| `stopRecording` | `stopRecordingIntroduction()`; set `.recorded(player, introduction)`, or back to `.idle` with a message if it was too short. |
| `cancelRecording` | Stop the microphone if on, `discardIntroduction(_:)` on the unkept recording, `.idle`. Sent by Redo, Cancel, and closing the sheet without Keep. |
| `finishRecording` | `.idle`, keeping the file. Comes after the `saveTeam` that holds the new introduction. |
| `importIntroduction(url, for:)` | `importIntroduction(from:)`, then `.recorded(player, introduction)`; the player page opens the sheet to listen and keep it. |
| `discardIntroductionFile(intro)` | `discardIntroduction(_:)`: the player’s old recording was replaced, switched to the iPhone voice, or the player was removed. |
| `dismissProblems` | Clear `problems`. |

`TeamScreensDemo` and `TeamScreensDemoState.apply(_:)` act on every request the way the shell should, with a pretend audio clock, and are a working example.

## Vocabulary requests

1. **A usual position and role on `Player`.** The brief and the architecture ask for them; `Player` has neither yet (the pregame builder made the same request in `notes/vocabulary-requests.md`). Workaround: `PlayerUsuals` (position, leads off, starts on the bench), handed in as `TeamScreensData.usuals` and handed back with `setUsuals`. It has the same three parts as the pregame screens’ `UsualRole`, so the shell can keep one copy, saved beside the teams, and convert field by field. A player with no position bats only. When `Player` gains the fields, `setUsuals` becomes part of `saveTeam`.
2. **An artist on `Song`.** The mockup shows “Ozzy Osbourne” under each title; `Song` has a title only, so the screens show the title alone.
3. **A fade length per song**, if Mikey wants the mockup’s 1 s, 2 s, 3 s choice on the song page. The audio player fades over a fixed two seconds and `Song` has nowhere to keep it, so the choice is left off.

## Decisions to confirm

- **Quick entry reads one line**, number then name, so a player is about fifteen keystrokes and a Return. A first word of one to three digits is the number; “2024 Rookie” stays a name.
- **Our team’s new players start right-handed; an opponent’s start unknown.**
- **Switching to the iPhone voice deletes a recording**, after asking. Closing the recording sheet without Keep throws the new recording away.
- **The roster shows each player’s usual position and role**, where the mockup shows what they do today; today’s lineup belongs to pregame.

## Not done

- No way to delete a team or a song (not in the brief; deleting a song needs an audio function to remove its file).
- The drawing of a track is a made-up shape, the same every time for the same song; reading the real sound would need the audio player. The level bar moves whenever recording is on, whatever the microphone hears.
- The mockup’s league line under the team name (“San Diego Adult Baseball League · 18A”) is not in `Team`, so the summary line takes its place.

## Evidence

- `xcodebuild test -scheme ScorebookUI-Package -destination 'platform=iOS Simulator,name=iPhone 17'` in `app/Packages/ScorebookUI`: builds with no warnings and every test passes, including 25 new tests in six suites: the announcer’s words, rosters in words, quick entry (twelve lines make twelve players in order), songs (who uses a song, times, a start point kept on the track), team edits (keeping a new recording frees the old file; the iPhone voice leaves none), and the demo acting on requests.
- **Finish line, twelve players in under three minutes.** A UI test in a throwaway harness app outside the repository ([QuickEntryTimingTests.swift](screen-teams-and-songs/QuickEntryTimingTests.swift)) opens the empty team, taps Quick entry, and types twelve players, tapping Left for five batters and three throwers, without touching the typing field again between players. It passed three times, in 19 to 32 seconds of machine typing: 177 taps and keystrokes in all. At two keystrokes a second, a person would take about a minute and a half. [Midway](screen-teams-and-songs/quick-entry-midway.png) and [done](screen-teams-and-songs/quick-entry-twelve-players-done.png).
- **Screenshots** from the harness on an iPhone 17 simulator, in [screen-teams-and-songs/](screen-teams-and-songs/): the teams list, the Diamond Dogs, Mudcats, Bombers (numbers only) and empty-team rosters, a player with a recorded introduction and one with no song, the fifteen-song library and a song page; dark mode for the teams list, a pitcher with a warm-up song and a song page; and the largest accessibility text size for the roster, a player, a song and the library.
- **iPad check** ([notes/ipad-check.md](../../notes/ipad-check.md)), on the 13-inch iPad Pro and iPad mini simulators, upright, plus a 1000 by 640 point window drawn inside the upright iPad Pro for the wide, short shape an iPad takes sideways or beside another app: everything fits and scrolls. The player and song pages keep their cards at a readable width, centered, on a wide screen. Screenshots: `ipad-pro-*.png` and `ipad-mini-*.png`.
- The previews in `Previews.swift` cover the same situations, plus the recording sheet ready, recording and waiting for Keep, the song picker, assigning a song, an empty library, and a library importing with a problem. Xcode’s preview canvas was not opened; the harness shows the same views.

## Not checked

- The iPhone’s file picker was not driven in the simulator; import hands back whatever URLs `.fileImporter` gives, as the audio handoff asks.
- Recording, listening and the test button were checked against the demo alone; the real audio player is connected during wiring.
