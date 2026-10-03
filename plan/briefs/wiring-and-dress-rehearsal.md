# Wiring and dress rehearsal

**Role:** lead builder.

**Waits on:** every job above, accepted into `main`. It can start as soon as the rules engine, storage, the batting screen and the in-play sequence are in, and add the rest as they land.

**Owns:** the app shell (`app/Scorebook/` and the Xcode project), plus `Model/` and `SampleData/` for any vocabulary changes builders requested.

## Deliver

1. **Vocabulary change requests** from every handoff note: decide each, make the accepted ones, and fix every module they touch.
2. **The game session:** the one place that holds the current game’s events, saves each new event through storage, asks the rules engine for the new situation, asks stats for the batter history, and feeds the screens. Undo and edits go through it.
3. **Walk-up songs:** cue the next batter’s song as soon as our team’s next hitter is known, so it is loaded before anyone reaches for the button.
4. **App settings:** keep the screen from auto-locking while a game is open; let the app’s files show in the iPhone Files app, for backups; switch on background audio; ask for microphone permission, for recording announcer introductions.
5. **Prompts the game raises:** open the defense check each time our team takes the field, and the runner sheet when a designated non-runner reaches base.
6. **Navigation:** home (resume game in progress, new game, teams, songs, season stats), pregame into the batting screen, the batting screen to and from the overview, end of game to the box score.
7. **Resume:** if the app was closed mid-game, it opens to that game.
8. **Installation on Mikey’s phone** with his free Apple account. The phone needs iOS 18 or later and Developer Mode switched on (Settings, Privacy and Security); write Mikey a step-by-step for reinstalling every seven days.
9. **Simulator walkthrough:** drive the app in the iPhone simulator through the complete game in `SampleData`, and through the real Major League games in `Tests/Scenarios/`, and check the final box score against the official one.

## Dress rehearsal

Mikey scores a televised game on his phone. Every problem he notes goes into `notes/dress-rehearsal-<date>.md`, sorted into wrong (fix before the first real game), slow (fix soon) and nice to have. Then the same at a game of ours, with the songs.

## Finish line

A full game scored on the phone with no wrong count, no wrong score and no crash, and a box score texted to Mikey from the app.
