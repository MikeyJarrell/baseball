# Review: mid-game fixes and box score tidy-up

A fresh reviewer read the changes against Mikey’s list. Found no way to give a wrong score or to corrupt a saved game: the player swap covers the whole setup and every event and can be undone by swapping back; the home and away switch moves each pregame entry to the right team; Undo passing over a confirmed defense check takes the check with the real entry and asks it again on Redo.

## Problems found, and what was done

1. **Taking a hitter out of the order could shift a batting hole or leave an automatic out on the wrong spot.** Fixed: only allowed before the first pitch while nothing but a defense check is recorded for that team (`GameSession.canChangeStartingOrder`), with a message when refused. Test: `noRemovalAfterABattingHole`.
2. **Innings could be set below the inning being played, ending the game partway through the record.** Fixed: the stepper starts at the current inning.
3. **Changing game details kept Redo.** Fixed: Redo is cleared. Test: `detailsClearRedo`.
4. **The lineups page and the game session disagreed on “before the first pitch”, and a refused change was silent.** Fixed: the page asks the session (`GameChangeContext.startingOrderOpen`); refusals show the “Not saved” message.
5. **Warm-up songs did nothing for a pitcher typed in by number mid-game.** Fixed: he goes on the saved team first.
6. **A refused home and away switch still saved the other details silently.** Fixed: it stops and says why.
7. **The picture’s spoken label read the headline’s line break.** Fixed.
8. **An unused duplicate of `isScorerPlay`.** Removed.
9. **A stale opening comment in `DefenseSheet.swift`.** Fixed.
