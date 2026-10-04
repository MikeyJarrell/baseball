# Loading the team onto the phone: handoff

**Job:** put the real Diamond Dogs, every opponent and every song onto Mikey’s iPhone, with a loader that can be run again after the roster changes; keep Mikey’s signing team in the project; a one-command weekly reinstall.

**Branch:** `codex/load-team`, in the task folder `/Users/mikey/projects/.worktrees/baseball/load-team`.

## What exists now

- **`TeamImport`** (a new module in `app/Packages/ScorebookCore`): reads `team/roster.csv` and `team/opponents.csv` and works out what the saved teams and the song library should become. It matches what is already saved by name (a team by its name, a player by the name they go by or their full name, accents and capitals ignored; a song by its file name, then by title and artist), so a match keeps its id and season stats. A blank in the CSV never erases what the app has (a jersey number typed in, a batting side); a recorded introduction is never touched; players, teams and songs the CSV does not mention stay. The roster file wins for what it does name, including each song’s start point.
  - Our team: “Diamond Dogs”, short name DOGS, marked as ours (which is what gives it the logo on screen). Each player’s name is the name they go by and their last name (“Chris Strong”, “Bobby Yabumoto”), with batting and throwing side, usual position, usual role (“Leads off” sets leads off; “Starts on the bench” sets starts on the bench; DH means bats only, no position), walk-up song with its start point (`start_point_in_clip`) and artist, and warm-up song (whole track, from the start).
  - Opponents, with short names: Cannonballers CAN, Clairemont Swingers SWG, Compadres COMP, El Cajones ELC, GWW Whales GWW, Jaguares JAG, Lemon Grove Athletics LGA, Riptide RIP.
- **`TeamLoader`** (a Mac command in the same package): `load` merges the CSVs into a copy of the app’s saved files through the app’s own Storage module, so files are written exactly as the app writes them, and copies each song file into `songs/audio`, after checking every file is there and plays. `check` lists what a copy of the saved files holds and fails if any song’s file is missing or will not play.
- **`tools/load_team.sh`**: stops the app; copies the app’s own folders (Application Support, Documents, Preferences) to `~/Dropbox/baseball/phone-backups/<date-time>/`; runs `TeamLoader load` on a copy; copies only the `teams` and `songs` folders back into the app (files already the same are skipped; nothing on the phone is removed; games and settings are never sent); starts the app (a locked phone only gets a message); reads the saved files back off the phone and runs `check`. `--simulator` does the same on the iPhone 17 simulator.
- **`tools/install_on_phone.sh`**: the weekly reinstall in one command: `xcodebuild` for the connected iPhone with `-allowProvisioningUpdates -allowProvisioningDeviceRegistration`, then `devicectl device install app`.
- **The Xcode project** keeps `DEVELOPMENT_TEAM = 2U9RH88978` on the app’s Debug and Release settings. `app/Scorebook-Info.plist` keeps its comments; its DTD address is corrected to Apple’s (`PropertyList-1.0.dtd`), the one change Xcode made there that was right.
- **Documents:** `plan/install-on-iphone.md` (the trust step may not appear; the one-command reinstall as the easy way, Xcode’s Play button as the other; loading and reloading the team), `team/README.md` (a section pointing at the loader).

## What is on the phone

Read back off the phone after the load and again after a reinstall with `install_on_phone.sh`:

- **Diamond Dogs (DOGS), 16 players**, every one with a walk-up song: Jonathan Torres Benitez (LF), Joaquin Canas (RF, starts on the bench), Aidan Kurt (2B, leads off), Darin Dietrich (1B), Erick Rosas Lopez (P), Jon Marianowits (SS), Mikey Jarrell (bats only), Chris Strong (P), Allan Nojadera (C), Gaven Lejano (CF), Garrett Seidlitz (P, starts on the bench), Saul Teodosio (P, starts on the bench), Yered Teodosio (3B), Esteban Higuera (1B), Bobby Yabumoto (C), Kalid Teodosio (RF). Eight have a warm-up song: Darin, Erick, Mikey, Chris, Allan, Gaven, Garrett, Saul. Numbers are blank, as in the roster.
- **24 songs** (16 walk-up clips, 8 warm-up tracks), every file present and read through as playable.
- **8 opponents, 117 players:** Cannonballers 12, Clairemont Swingers 19, Compadres 15, El Cajones 14, GWW Whales 12, Jaguares 18, Lemon Grove Athletics 15, Riptide 12.
- **No games** (there were none before).

## Checks

- `swift test` in `app/Packages/ScorebookCore`: every test passes, including `TeamImportTests`: quoted CSV fields; the real roster and opponents load whole (16 players, every song file once, Aidan leads off at second, Mikey bats only, start points and artists); a second load after a change keeps every id, a typed-in number, a recorded introduction, an extra player, an extra song and a team the files do not know, takes a changed start point, and saves no unchanged opponent again; times, sides and positions.
- **Simulator:** `tools/load_team.sh --simulator` loaded everything; a throwaway UI test (not kept) opened Teams, the Diamond Dogs roster (“16 players · 16 with songs”, positions and roles, songs) and Aidan Kurt’s page (Mary Jane, starts at 0:20). A second run said “Nothing changed”.
- **Phone:** the phone had no saved teams, songs or games before (its first backup is `phone-backups/2026-10-04-101833-first-look`). The load ran, the read-back check passed, and a rerun said “Nothing changed”. `install_on_phone.sh` reinstalled the app and the read-back afterward still showed everything.

## Notes

- The first phone run stopped while backing up: the phone’s own screen snapshots in the app’s folder are locked while it writes them. The backup now copies only the app’s own folders. That partial copy is kept as `phone-backups/2026-10-04-102329-incomplete`; it holds nothing the later backups lack.
- The phone was locked during the later runs, so the app was not restarted by the script; it opens with the team the next time Mikey taps it.
- I did not see the phone’s screen; the read-back shows the files are in place in the app’s own format, and the simulator shows the same files on screen.
