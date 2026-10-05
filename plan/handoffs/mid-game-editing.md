# Handoff: fixing things mid-game, and a tidier box score

Mikey’s list after the first phone install, plus his box score notes.

**Songs fade out when stopped.** Tapping a playing walk-up or warm-up song fades it over two seconds; a second tap during the fade stops it at once (`GameScreen`, `.stopSong`). The button says “Tap to fade out.”

**Lineups and rosters.** The first row of the Subs menu (`GameChanges/LineupsSheet.swift`). Both teams’ batting orders, fielders who do not bat, and the rest of the roster. Tap anyone to fix their name, number or batting side, or to say it was really someone else, a teammate or someone typed in. Then the two players trade places in the whole game, including every play already recorded (`GameSession.correctLineup`, `LineupCorrection` in Model), so a hitter who batted as “#22” is credited to the player the card names. Before the first pitch a hitter can also come out of the order. The page stays open while the scorer works through a card (`GameChangeResult.keepOpen`). New players go on the saved team too.

**Warm-up songs mid-game.** A button beside the warm-up song bar, and Warm-up songs in the game menu, open `WarmUpSongsSheet` (`Scorebook/AppSheets.swift`): his songs with checks, the rest of the library to add, and a play button to play any one now. Changes save to the team at once. A team load keeps songs added on the phone (`TeamImport`), file songs first.

**Game details.** Game menu → Game details (`GameDetailsSheet`): date, start time, innings, and which team is home. Home and away switch only before the first pitch (`GameSession.canSwitchHomeAndAway`); lineup changes made before then move with their team.

**Fielders on the diamond.** The defense check and the Fielders sheet show the field drawing, as the pregame fielding step does, with the first initial and last name (`Player.initialAndLastName`, “Y. Teodosio”), and the pregame step uses the same names. Tapping a position opens the roster to pick from.

**Two last names.** A player whose roster last name is two words goes by the first: Jonathan Torres Benitez is “Torres”, Erick Rosas Lopez is “Rosas”, on the diamond, the batting screen and the box score (`Player.surname`, set by the team load from `team/roster.csv`; `BoxScore.surnames` carries it to the printed names). A last name with a small word in front, like “De La Cruz”, stays whole.

**Undo skips the defense check.** “Everyone’s where they were” records nothing worth undoing, so Undo passes over it to the last real entry and takes the check with it; the check opens again when that entry is redone.

**Box score.** The headline puts each team on its own line. Positions are in capitals (“Kurt 2B-RF”). The lettered pinch-hitter and pinch-runner notes under the totals are gone; a substitute still sits pushed in under the player he replaced, marked PH or PR. “Webb ran for Quinn” notes are gone. Each kind of note (E, DP, LOB…, then HBP, pitches-strikes, T) prints on its own line, in the picture and the copied text.

**Checks.** `swift test` in `app/Packages/ScorebookCore` passes, including the new `MidGameFixTests` and the updated box score and team-load tests. The app builds and every new screen was clicked through on the iPhone 17 simulator, including a late-card swap, a home and away switch, adding and removing a warm-up song, and the sample box score picture. Review: [feedback/ai/mid-game-editing-review.md](../../feedback/ai/mid-game-editing-review.md).
