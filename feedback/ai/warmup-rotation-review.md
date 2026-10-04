# Review: several warm-up songs per pitcher (commit 6762e9c)

**Verdict:** the normal path works (main song first inning, extras shuffled after, no repeats), and `swift test` passes. But the game screen’s memory of what each pitcher has heard is fragile: leaving and resuming a game, an Undo over a changeover, or a pitching change at the changeover each break the “main song first, extras later” rule. One data case (the same song listed twice) goes silent for the rest of the game. Fix the first two before a game.

## Findings, most serious first

1. **Resuming a game forgets every song played.** `app/Scorebook/GameScreen.swift:84` keeps `warmUpsPlayed` and `thisWarmUp` only while the game screen is open. Leaving the game to the home screen (or iOS closing the app) and resuming builds a new game screen with an empty memory (`HomeView.swift:95`). Scenario: Chris pitches innings 1–3, the scorer goes home to check a setting and resumes; at the next changeover Chris gets his main song again, and the shuffle starts over, so extras repeat. **Fix:** work the answer out from the game record each time. Count how many changeovers this pitcher has already started from the game record (0 = main song), and shuffle his extras in a fixed order seeded by the game id and pitcher id. Then the pick is the same every time it is asked, which also fixes findings 2 and 3.

2. **Undo over a changeover, then re-entering the out, plays a different song.** `GameScreen.swift:371` and `:405`: the first changeover records the main song; Undo fades it (correctly) but leaves it in the memory; recording the corrected third out calls `playWarmUp` again, which now sees “main already played” and picks an extra. Scenario: away game, scorer records the third out in the top of the 1st by mistake, Chris’s main song starts, scorer undoes and records the real out: Chris’s first inning gets an extra song. Later innings likewise burn a song from the pass. **Fix:** the fix in finding 1; or, at minimum, drop the last entry from the pitcher’s list when Undo or a fix steps back over the changeover (the branch at `:375` already detects this).

3. **A new pitcher brought in at the changeover hears his main song twice.** The changeover auto-plays for the old pitcher (and uses up one of the old pitcher’s songs). The scorer then makes the pitching change; nothing auto-plays, and the song button shows the new pitcher’s main song because `thisWarmUp` belongs to the old pitcher (`:413`). The scorer taps it, but the manual tap (`:227`) is not recorded in `warmUpsPlayed`, so at the new pitcher’s next changeover the list is empty and the main song plays again. **Fix:** in the `.playWarmUp` tap handler, record the song in that pitcher’s list when it is not already his latest entry, and set `thisWarmUp`; or pick and play automatically when the pitcher changes during our changeover.

4. **The same song listed twice in a pitcher’s extras means no song at all from about the 4th inning on.** `Model/WarmUpRotation.swift:21–30`. With extras `[a, a, b]` I ran the same logic in a scratch copy: main, b, a, then nothing, every inning after (the “not heard this pass” list comes out empty and `randomElement` returns nil, so `playWarmUp` quietly returns). Duplicates are easy to get: two CSV rows with the same title get the same file name from the script (finding 6), and the import treats two rows with the same title and artist as one song (`TeamImport.swift:246`). **Fix:** remove repeats from the extras list in `nextSong` (keep first occurrence) and in the import at `:295`; add a test with a repeated extra.

5. **An extra warm-up song can take over a teammate’s walk-up clip.** `TeamImport.swift:243–257`: when no file name matches, the import reuses any library song with the same title and artist, then rewrites its file name and start point. If Moreno walks up to “Thunderstruck” (a clip from 1:06) and Chris lists “Thunderstruck” as an extra, Moreno’s song now points at Chris’s whole-track file from 0:00, and each load flips it back and forth. This was already true for main warm-up songs, but extras make it likelier. **Fix:** match by title and artist only when the found song has no file of its own, or never across a walk-up clip and a whole track (different start point).

6. **The song script’s file names can collide.** `tools/walkup_songs.py:206` names each extra `<player>-warmup-<song>.m4a`. Two rows for one pitcher with the same title (a live and a studio “Thunderstruck” both titled that way), or titles that boil down to nothing (a title in emoji or non-Latin script gives `chris-strong-warmup-.m4a`), share one file: the second cut overwrites the first and both rows point at it. **Fix:** if the name is taken by another row this run, add `-2`, `-3`; fall back to the row number when the song slug is empty.

7. **Smaller loader and import points.**
   - An extras row whose pitcher name has a typo (“Chris Stong”) is silently ignored (`TeamImport.swift:295`). Add an import note listing extras rows that matched no player.
   - `TeamLoader/main.swift:54` uses `try?`, so an extras file that exists but cannot be read (bad encoding) counts as “no file” and wipes every pitcher’s extras. Treat “missing” and “unreadable” differently; fail on unreadable.
   - Replacing the whole list on each load is right, since the file is the only source; confirmed the test covers it.

8. **Player page wording when there is no main song but there are extras.** `PlayerPage.swift:159–162`: shows “No warm-up song” over “Plays at Strong’s first changeover each game”, but the rotation actually plays a random extra in his first inning. Say “Plays his first changeover: one of the songs below” in that case, or let the import require a main song.

## Checked and fine

- **Pitcher whose extras include his main song:** filtered out at `WarmUpRotation.swift:21`; works.
- **Song id missing from the library:** the audio player shows its “no longer in the song library” message and plays nothing. The app has no way to delete songs, so this needs a damaged data folder, and the loader’s `check` flags missing extras.
- **Old saved players:** read with an empty list (`People.swift`, `decodeIfPresent ?? []`), tested. Empty lists are left out when saving. Editing a player during a game (`savedCopy`) starts from the saved player, so it keeps extras.
- **Song button after the changeover:** replays the song picked for this changeover; a manual replay of the same song is (correctly) not counted.
- **Tests:** the rotation tests play whole games and check baseball behavior (first inning main, each extra once per pass, no back-to-back repeat). Missing: duplicates (finding 4), and nothing tests the game screen’s Undo, resume or pitching-change paths, which is where the real risks are. Moving the pick into the model as in finding 1 would make those testable without the simulator.
- **Style:** comments are clear and plain. The `load_team.sh` header comment now breaks mid-sentence across an oddly short line (“extra ones from team/warmup_extras.csv), every”); reflow it.

## Second pass (commit d782ec8)

**Verdict:** all eight findings are fixed. Working the song out from the game record each time is the right fix. I found nothing that blocks a game; three small points remain.

How each finding stands:

1–3. **Resume, Undo, pitching change at the changeover: fixed.** The song now depends only on the play log and a shuffle seeded by the game and the pitcher, so reopening the game, undoing over a changeover or re-entering the third out always gives the same song.
   - **Which half is excluded:** at the changeover, the situation already shows the half about to start. `Replay.swift:834–841` moves `half` and `inning` on before setting `isBetweenHalfInnings`, while each log entry keeps the half it happened in. So `inningsStarted(... before: situation.inning, situation.half ...)` counts every earlier half and leaves out the one about to start.
   - **A new pitcher at the changeover:** he has thrown no first pitch, so his count is 0 and the button shows and plays his main song. The old pitcher’s count does not go up for an inning he never pitched. A reliever who comes in mid-inning also gets his main song at his first changeover. Both cases are tested.
4. **Repeated songs: fixed** in the picker (`distinctExtras`) and in the import, and tested.
5. **Extra song taking over a walk-up clip: fixed.** A title-and-artist match now skips any song whose file a roster row names.
6. **Script file names: fixed.** A title with no plain letters, or a repeated title, gets the row number. A song titled “3” and an untitled row 3 still come out different (`…-3` and `…-3-3`).
7. **Loader: fixed.** A misspelled pitcher name is reported, and an extras file that exists but cannot be read stops the load.
8. **Player page: fixed.** With no main song, his first extra is shown as his song, which matches what plays.

**The recursion in `order(of:pass:seed:)`:** it behaves. Each pass checks only the pass before it, so it goes as many levels deep as there are passes: about 3 for a pitcher with three extras over a 10-inning game. It compares against the previous pass after that pass’s own swap, so the check is right. Swapping the first two songs is enough to avoid a back-to-back repeat whenever there are at least two extras, and the tests check 30 games of 10 innings.

Still open (small, none blocks a game):

- **A half-inning with no pitch is not counted.** If our team’s half ends before any pitch (a pickoff for the third out, or a game ended by the time limit at the changeover), that changeover’s song is not counted, so the same song plays again at his next one. That is rare, and the result is one repeated song. Leave it.
- **After a pitching change during the warm-up song, the button is mislabeled.** The old pitcher’s song keeps playing while the button shows the new pitcher’s main song with the label “Playing”. The scorer has to tap Stop, then Play. This was already true before this feature. A fix would restart the warm-up song automatically on a pitching change while our team is taking the field.
- **The song is recalculated every time the batting screen redraws.** `withThisWarmUp` runs inside `body`, so each redraw reads the whole play log (a few hundred entries) and reshuffles a handful of songs. That is cheap, but if the batting screen ever feels slow, work it out once per situation change.
- **A design choice for Mikey:** a pitcher with no main song and two extras plays the first extra once, then the second every inning after (tested as `["stamp", "takedown", "takedown"]`). If he would rather shuffle both, the first extra should stay in the rotation.
