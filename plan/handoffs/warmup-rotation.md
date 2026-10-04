# Handoff: several warm-up songs per pitcher

**What it does.** A pitcher has a main warm-up song and may have extra ones. The first inning he starts in a game plays the main song; each later inning plays one of the extras in a shuffled order, each once before any repeats and never the same song two innings running. A reliever who came in mid-inning gets his main song at his first changeover.

**How.** `Player.extraWarmUpSongIDs` (Model/People.swift) holds the extras. `WarmUpRotation` (Model/WarmUpRotation.swift) works out the song from the play log (how many of our half-innings this pitcher threw the first pitch of) and a shuffle seeded by the game and the pitcher, so nothing is remembered between changeovers: Undo and Redo, a pitching change at the changeover, and reopening a game all give the right song. `GameScreen.withThisInningsWarmUp` hands that song to the song button and the auto-play.

**Where the songs come from.** `team/warmup_extras.csv`, one row per song; `tools/walkup_songs.py` cuts each whole track as `<player>-warmup-<song>.m4a`; `TeamImport` and the `TeamLoader` bring them in (a misspelled pitcher name is reported; an unreadable file stops the load). The player page lists the extras; they are not editable in the app.

**Known gaps, left on purpose.** A half-inning with no pitch (a pickoff for the third out first) does not count as started, so that pitcher hears the same song once more. Changing pitchers while a warm-up song plays leaves the old song playing; the scorer taps Stop, then Play (true before this work too).

**Checks.** `swift test` in `app/Packages/ScorebookCore` (new: `WarmUpRotationTests`, two `TeamImportTests`); `xcodebuild test -scheme ScorebookUI-Package` and the app’s UI tests on the iPhone 17 simulator all pass. Review: [feedback/ai/warmup-rotation-review.md](../../feedback/ai/warmup-rotation-review.md), two passes.
