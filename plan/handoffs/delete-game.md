# Deleting a game: handoff

**Job:** let Mikey delete a game (a test game saved on his phone), from the games list and from a game’s box score.

**Branch:** `codex/delete-game`, in the task folder `/Users/mikey/projects/.worktrees/baseball/delete-game`.

## What exists now

- **Games list** (`PostgameScreens/GamesListScreen.swift`): Edit in the top bar puts a red Delete button on every row (Done puts them away); a long press on a row offers “Delete game” too. The screens use a scrolling stack of rows rather than a system list, so a swipe is not offered; Edit and the long press stand in for it. A new `ourTeamName:` input (optional) puts our name in the question.
- **A game’s box score** (`PostgameScreens/EndOfGameScreen.swift`): with the new `canDelete: true`, the top bar has a menu (…) with “Delete game”. The app turns it on for saved games opened from the games list; the end-of-game screen right after a game does not offer it.
- **The question** (`PostgameWording.deleteQuestion`): “Delete Diamond Dogs vs Mudcats, Oct 4?” (“at” for an away game; “Mudcats at Bombers” when neither team is ours), with “This can’t be undone in the app. A backup of everything is written first.” Only the red “Delete game” deletes.
- **`PostgameRequest.deleteGame(GameID)`**: handed back once the scorer confirms.
- **The app** (`app/Scorebook/AppModel.swift`, `HomeDestinations.swift`): writes a backup with the existing backup function first and stops with a message if it cannot; then `storage.deleteGame` removes that game’s file only. Deleting the game in progress closes it, so the home screen’s resume card goes away. The games list, the season stats and “Last box score” read the games again. Deleting from a box score goes back to the games list.
- **Home screen from a game** (`AtBatScreen/AtBatSheets.swift`, `AtBatScreen.swift`; found while testing this): the batting screen had no way back to the home screen while a game was in progress, and the app opens straight onto a game in progress, so a test game left unfinished could never be reached from the games list. The game menu now has “Home screen” (new action `AtBatAction.goHome`); the game stays in progress and Resume scoring brings it back.
- **Storage:** `ScorebookStorage.deleteGame(_:)` was already part of the storage promise, removing the one file in a single step (a removed file is either there or gone, never half there). A new test checks that it leaves every other game’s file byte for byte, and that a deleted game in progress is no longer offered to resume, before and after reopening the files.

## Tests

- `swift test` in `app/Packages/ScorebookCore`: every test passes, including “Deleting one game removes only its file…”.
- `xcodebuild test -scheme ScorebookUI-Package`: every test passes, including the two delete-question tests.
- `xcodebuild test -scheme Scorebook`: both full-game walkthroughs and the smoke tests pass, including `testDeleteAGameFromTheGamesList` (a finished game and a game in progress seeded; the game in progress deleted from the games list through Edit and the question; the list then holds one game and the home screen no longer offers to resume).

## For Mikey

After this is accepted, reinstall on the phone (`tools/install_on_phone.sh` from the main folder), then open Games, tap Edit, and delete the test game. The backup written first is under Backups on the home screen.
