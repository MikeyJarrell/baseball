# Game setup and game menu rework (October 25, 2026)

Mikey’s list after the October 18 game, done in one session.

## Game setup

- The fielders screens draw each fielder’s name at their spot (`FieldDrawing.fieldersAsNames`), with no numbered circles; an empty position shows its short name in a dashed outline. The catcher’s name used to fall off the bottom of the drawing.
- Tapping a position opens a full-height grid of every player (`PlayerGrid` in DesignSystem), so a pick needs no scrolling. The defense check during the game uses the same grid and drawing.
- Their lineup has no “names and numbers or numbers only” choice: it starts from every name on their saved roster (numbers typed in batting order only for a team with no saved names). Their rows have the non-runner switch. Both batting orders have New player.
- Their fielders get the same screen as ours (`FieldingStep(ours: false)`), starting from where they played against us last; the pitchers step is gone, since our pitcher is whoever is at pitcher on our fielders screen. An unknown throwing hand is set on the fielders screen.
- Skip, top right on every step but the review, starts the game with what is set so far.
- An announcer step follows our fielders when a hitter has no recorded name; Record opens the app’s name recorder (`PregameFlow(recordedNames:onRecordName:)`, wired in `PregameCover`). A player typed in on setup is saved to the team first.
- The “a late first pitch…” footer is gone. The defense check’s button says “Everyone’s in place” in the first inning.

## The game menu

Full screen, in five groups: Game details (and the time limit), Rosters, Manual adjustment (fix a play or a pitch, set outs and the rest, error with nobody moving), Music and PA (warm-up songs; every player’s walk-up song, warm-up songs and recorded name, the song length and switches), Exit game (pause and go home, end game, delete this game with “Do you really want to delete this game? All the data will be lost.”).

- Rosters (`LineupEditorPage`) opens the setup screens for both teams’ starting lineups. `GameSession.editStartingLineup` applies them: every batting and running reference in the recorded events follows the batting spot (`remappingBatters`), fielders follow by position, and the order’s length can change only before it comes around. Lineups was taken out of the Subs menu.
- The Box score button’s play-by-play no longer opens “Fix a play”; Manual adjustment opens it on the Plays tab with fixing on (`GameOverview(canFix:)`).

## Finished games

A finished game’s box score (Games list) has Resume, which takes back the end of the game and makes it the game in progress again (`AppModel.reopenGame`). For the Riptide game of October 18, called after three and a half innings with Riptide ahead 2–1: it counts in the season until resumed.

## Not done

- More than one game left unfinished at once: a resumed game must be ended before a new one starts.
- The in-game Rosters page edits the lineups at the first pitch; changes made during the game stay in Subs.

## Tests

All game-logic tests (`swift test`, with two new ones in `StartingLineupEditTests`), all screen tests and all ten whole-app simulator tests pass. The setup walkthrough now has eight screens.
