# Trimming the app’s on-screen text: handoff

**Job:** cut on-screen text that states the self-evident, explains how the app works, restates a rule after the fact or justifies a design. Keep warnings that prevent lost data or a wrong play, first-time instructions at the step that needs them, and plain facts.

**Branch:** `codex/trim-app-text`, in the task folder `/Users/mikey/projects/.worktrees/baseball/trim-app-text`.

**Scope:** every user-facing string in `ScorebookUI/Sources` and `app/Scorebook`, skipping previews, demos and comments. About 580 strings of four words or more were read in context, plus the shorter labels around them. `ScorebookCore` was left alone: its few on-screen strings are error messages for actions the screens already block.

Code touched along with the words: where a deleted line left nothing to show, that line is skipped (song button detail, play-entry bottom bar, song line on the player page, the pitcher’s batting-spot caption, a pinch-runner note for an ordinary runner). `FixPlay.noun(for:)` is gone, since its only use was the deleted fix-sheet box. No identifiers changed.

## Changed

| Screen | Before | After |
|---|---|---|
| Is the game over? (batting screen) | “The time limit, 7:15 PM, has passed and the inning is over. No new inning starts after the limit (rule 9.1 G). The umpire makes the call; the app only asks.” | “Past the time limit, 7:15 PM.” |
| Is the game over? | “A lead of 15 runs or more after 4 innings ends the game under the run rule (rule 9.13). The umpire makes the call; the app only asks.” | “Run rule: 15 or more ahead after 4 innings.” |
| Is the game over? | “The scheduled 7 innings are complete. The umpire makes…” | “7 innings complete.” |
| Is the game over? | “Play has stopped, for rain, darkness or anything else. The umpire makes…” | “Play has stopped.” |
| Game menu | Warm-up songs: “For Sky Barros: add more, or play one” | “Sky Barros” |
| Game menu | Home screen: “Teams, songs, games; the game stays in progress” | “The game stays in progress” |
| Game menu | Walk-up song length: “12 seconds of song, then it fades” | “12 seconds” |
| Song button (warm-up) | “Playing · tap to fade out” / “Warm-up for Barros, our pitcher” | “Playing” / “Warm-up for Barros” |
| Song button (walk-up) | “Tap to fade out” / “Introduction, then 12 seconds of song” / “12 seconds, then fades” | “Playing” / “Introduction, then 12 seconds” / “12 seconds” |
| Changes menu | Lineups and rosters: “Fix names, numbers, who batted where; add players” | “Names, numbers, batting order” |
| Take the field / Fielders | Subtitle “Top 3rd · Diamond Dogs: check who is where” / “Diamond Dogs · move players or bring them in” | “Top 3rd · Diamond Dogs” / “Diamond Dogs” |
| Take the field | “The batter ran on strike three: enter it, and the inning may go on” | “The batter reached on strike three” |
| Take the field | “Set up from the plan for this inning. Check the marked positions, then save.” | “Set from this inning’s plan. Check the marked positions.” |
| Take the field / Fielders | “Tap a position to put someone else there. Picking someone already in the field swaps the two.” | “Picking someone already in the field swaps the two.” |
| Error, nobody moved | “Error on the shortstop (Webb): E6. The count, the outs and the runners stay as they are.” | “Error on the shortstop (Webb): E6.” |
| Game details | “Home and away can switch only before the first pitch. Undo back to before it to switch them.” | “Set before the first pitch only.” |
| Game details | “The time limit runs from the first pitch, so a new start time changes it only before then. Match the time limit itself from the game menu.” | “Once play starts, change the time limit from the game menu.” |
| Lineups and rosters | Footnote “Tap a player to fix their name or number, or to say it was really someone else. Changes save as you make them.” | “Changes save as you make them.” |
| Lineups: “It was really” question | “Every play already recorded for Webb becomes…” | “Every play recorded for Webb becomes…” |
| Lineups: new roster player | “Added to the Mudcats roster for this game and next time. Bring them in with a substitution or Add a hitter.” | “They start on the bench.” |
| Manual adjustment | “This overrides the book. Use it only when the field and the book disagree and nobody can say why. Runs added here go to the team in this inning, credited to no player and charged to no pitcher.” | “Overrides the book. Runs added here count for the team only, not for any player or pitcher.” |
| Runner for a non-runner | “No designated non-runner is on base right now. This sheet opens by itself when one reaches.” | “No designated non-runner is on base.” |
| Runner for a non-runner | “Pat Quinn is a designated non-runner and just reached second. Pick before the next pitch.” | “Pat Quinn just reached second. Pick before the next pitch.” |
| Runner for a non-runner | Suggested runner: “The league rule’s pick: the team’s last recorded out” | “Last recorded out” |
| Runner for a non-runner | Long footnote on who the rule’s runner is | “If the runner scores, the run is Quinn’s.” |
| Pinch hitter | “Started in this spot (rule 9.9)” | “Started in this spot” |
| Pinch hitter | Batting hole: “Webb is lost with nobody to take the spot: an automatic out each time it comes up (rule 9.5 C)” | “An automatic out each time the spot comes up” |
| Pinch hitter: hole question | “Webb’s turn now is an out right away. After that, the 4th spot is an automatic out each time it comes up. Putting someone in the spot later fills it again.” | “Webb’s turn now is an out, and so is every turn of the 4th spot until someone fills it.” |
| Pinch hitter, add a hitter | “Playing shortstop, not batting” / “…not batting yet” | “Playing shortstop” |
| Pinch runner | “The new runner takes Cole’s own spot in the batting order and keeps running for Quinn, who stays in the order (rule 9.11 N).” | “The new runner takes Cole’s batting spot and keeps running for Quinn.” |
| Pinch runner | “Quinn is a designated non-runner. A pinch runner takes them out of the batting order (rule 9.11 M). To keep them in it, use Runner for a non-runner instead.” | “A pinch runner takes Quinn out of the batting order. To keep them in, use Runner for a non-runner.” |
| Pitching change | “Pitched earlier today; may come back once (rule 9.12 B)” | “Pitched earlier today; can return once” |
| Pitching change | “Mid-count: 2–1 to Webb. The league asks a pitcher to finish the batter unless hurt (rule 9.12 B 2). Your call.” | “Mid-count, 2–1 to Webb. League rule: a pitcher finishes the batter unless hurt.” |
| Between pitches | Took the base, no throw: “Defensive indifference: not a stolen base” | “Defensive indifference” |
| Between pitches: runner moves | “Tap a runner’s bases below to change where they ended up.” | “Check where each runner ended up.” |
| Time limit | “No new inning starts after this time (rule 9.1 G). The app set it to three hours after the first pitch; match it to the plate umpire, who keeps the official time.” | “Match it to the plate umpire’s clock.” |
| Fix a play: delete line and question | “Deletes strike three only. Webb is back at the plate with the count at 1–2; the pitches before it stay, and any runners it moved go back.” | “Deletes strike three only. Webb is back up at 1–2; any runners it moved go back.” |
| Fix a play | “Deletes this ball only. The count before it was 0–0; the pitches after it are counted again from there.” | “Deletes this ball only. The count before it was 0–0.” |
| Fix a play | “Deletes the intentional walk. Webb is back at the plate with the count at 0–0.” | “Deletes the intentional walk. Webb is back up at 0–0.” |
| Fix a play | “Deletes the whole play. Webb is back at the plate with the count at 2–1, and the runners go back where they were.” | “Deletes the whole play. Webb is back up at 2–1, and the runners go back.” |
| Fix a play | “Deletes this runner move. The runners go back where they were before it; the count stays 2–1.” | “Deletes this runner move. The runners go back where they were.” |
| Fix a play | “Deletes this substitution. Everything after it is worked out again.” | “Deletes this substitution.” |
| Fix a play: Change this play | “Opens the in-play steps with it filled in” (and six like it) | “In-play steps”, “Dropped third strike steps”, “Runner moves”, “Error”, “The change”, “Time limit”, “Manual adjustment” |
| Pitchers tab | “IP is innings pitched: 2⅓ is two innings and one out. P-S is pitches and strikes. BF is batters faced.” | “P-S is pitches and strikes. BF is batters faced.” |
| Plays tab | “Newest first. Tap any play to fix it; everything after it recalculates.” | “Tap a play to fix it.” |
| Play entry: hit location | “Tap where it landed, or go straight on” | “Tap where it landed” |
| Play entry: runners | “Dot = the app’s guess. Tap any base to change it.” | “Dot = a guess. Tap a base to change it.” |
| Games list | “No games yet. A game shows up here once it starts.” | “No games yet.” |
| Delete a game | “This can’t be undone in the app. A backup of everything is written first.” | “This can’t be undone in the app. A backup is made first.” |
| Season stats | “Tap a column to sort. The table scrolls sideways; names stay put.” | “Tap a column to sort.” |
| Season stats | “No hitters yet. Stats appear here after the first game.” | “No hitters yet.” |
| Season stats (no team) | “Set up your team in Teams, and the season stats will build up game by game.” | “Set up your team first, in Teams.” |
| Pregame: game | Time-limit footer, five sentences | “A late first pitch moves the time limit later by the same amount.” |
| Pregame: fielders | “Tap a position to pick who plays it. Anyone can field, whether or not they bat.” | “Tap a position to pick who plays it.” |
| Pregame: alternating fielder | “Webb plays shortstop in odd innings and the player you pick plays it in even innings. The defense check offers the right one each time we take the field.” | “Webb plays shortstop in odd innings; the player you pick, in even innings.” |
| Pregame: pitchers | Header “Mudcats · from their saved roster” | “Mudcats” |
| Pregame: their lineup | “Hold a row and drag to reorder. Numbers you type are saved to the Mudcats roster.” (and the “Batter 4” version) | “Hold a row and drag to reorder.” |
| Player page | Warm-up song with extras: “Plays at Barros’s first changeover each game” | “First inning” |
| Player page | Extras: “Later innings: one of these at random, each once before any repeats” | “Later innings, shuffled” |
| Player page | “Test: the song as it plays in a game” | “Test the song” |
| Player page | Introduction: “Using the iPhone voice, slowed to stadium pace” | “iPhone voice” |
| Player page | Introduction: “Nothing yet. Until there is, the song plays alone.” | “No introduction yet” |
| Record introduction | “Recording · tap to stop” / “Tap to record. Take your time; silence at the ends is trimmed.” | “Recording” / “Silence at the ends is trimmed.” |
| Roster (empty) | “No players yet. Quick entry is the fastest way to type a whole roster: number and name, then Return, for each player.” | “No players yet.” |
| Songs | “No songs yet. Import MP3, M4A, WAV or AAC files from the Files app, such as the clips in Dropbox.” | “No songs yet. Import MP3, M4A, WAV or AAC files.” |
| Song page | “Play from the top, to find the hook” | “Play from the top” |
| Teams | “No opponents saved yet. They are added here when you set up a game, or with Add a team.” | “No opponents saved yet.” |
| New game, home screen | “Set up your team first: open Teams and add your team and its players.” | “Set up your team first, in Teams.” |
| New game, home screen | “A game is still in progress. Resume it and end it before starting a new one.” | “A game is still in progress. End it first.” |
| In-game song picker (empty) | “No songs yet. Add songs from the home screen’s Songs page.” | “No songs yet. Add them on the Songs page.” |
| Warm-up songs sheet | “His first inning” / header “His warm-up songs” | “First inning” / “Their warm-up songs” |
| Warm-up songs sheet (VoiceOver) | “One of his warm-up songs”, “Not one of his”, “Takes it off his list”, “Adds it to his list” | “their” in each |
| Backups | “A backup is also made at the end of every game. In the Files app, backups are under On My iPhone, Scorebook.” | “A backup is also made after every game. In the Files app: On My iPhone, Scorebook.” |
| Backups: restore question | “Teams, games, songs and settings go back to how they were. What is there now is saved first as its own backup.” | “Teams, games, songs and settings go back to the backup. What is there now is backed up first.” |
| Fix a play, other events | “This kind of event can be deleted from the play-by-play, then entered again.” | “Delete it from the play-by-play, then enter it again.” |

The game-over sheet and game menu in `GameChanges` (shown only in the design demos; the app uses the batting screen’s own) got the same cuts, and their time-limit reason keeps “A tie at the time limit stays a tie (rule 9.1 H).”

## Deleted

| Screen | Deleted text |
|---|---|
| Game menu | End game detail “Time limit reached, or the last out” |
| Game menu (demo version) | “Fades by itself after the introduction and this much song” |
| Is the game over? (demo version) | “Keep playing carries on, and the app will not ask again for this reason.” |
| Song button | “Tap to pick one” (under “No song for Webb” and “No warm-up song for Barros”) |
| Time’s up banner | “No new inning after 7:15 PM” (the title already says to finish this inning) |
| Changes menu | “Move players or bring them in”, “Takes over a runner’s spot in the order”, “For a designated non-runner on base”, “To the bottom of the order” |
| Edit this batter | “Kept for the whole game, and saved to the Mudcats roster for next time.” |
| Add a hitter, pinch hitter, pitching change | New player details “Number, name and batting side” / “Number, name and throwing hand” |
| Add a hitter, pinch hitter, pinch runner, pitching change, runner for a non-runner | “your call” and “Your call” |
| Add a hitter | “· your call” after “Left the game” |
| Pinch hitter, pinch runner | “Bench” under players in the bench list |
| Pinch runner | “The runner takes over Cole’s spot in the batting order, and Cole leaves the game.” |
| Runner for a non-runner | Subtitle “A suggestion, by rule 9.11”; “Nobody replaces them” under “Quinn runs” |
| Pitching change | “Tap to put the new pitcher in the batting order” |
| Game details | “The home team bats second, in the bottom of each inning.” |
| Lineups and rosters | Subtitle “Fix names, numbers and who batted where”; “Nobody bats here”; “To the bottom of the order”; “Someone not listed yet”; “Type their number and name”; “Before the first pitch only”; footnote “Everything recorded for Webb moves to the player you pick. If they were in the game too, the two trade places.” (the question that follows says the same) |
| Between pitches | Subtitle “Between pitches”; runner-moves subtitle “Check where each runner ended up” (now the hint under the drawing); “Strike three and this out make one double play”; “Such as the catcher throwing the ball away on a steal” |
| Fix a play | “Changing or deleting a pitch recalculates everything after it: the count, the runners, the score and every stat.” |
| Play entry: result | “ground, fly, line, pop, bunt”; “batter safe, runner out”; “Tap the throw next: catcher, then first (K 2-3)” |
| Play entry | “For a spray chart later”; “Next: where everyone ended up”; “Saving switches sides”; “Home team ahead: the app asks if the game is over”; “Then the next batter is up” |
| Pregame | “Type the numbers in batting order”; “Name them when you find out” |
| Player edit | “A number or a name is enough. Fill in the rest later.”; “A number is enough for their players.”; “Pregame starts the lineup from these.” |
| Player page | “Pick one from the library”; “Plays at the changeover when we take the field with Barros pitching” |
| Roster | Header notes “Songs and intro on each page” / “Tap a player to edit” |
| Songs | “Walk-up songs play when our hitter comes up. A pitcher’s warm-up song plays at the changeover when we take the field.” |
| Song picker (team screens) | “Tap a player to give them “Song”, and again to take it away. A player has one walk-up song, so it replaces theirs.” |
| Song settings | “The last two seconds are the fade. A song’s own length, set on its page, wins.” |
| Warm-up songs sheet | “The first plays his first inning; the others take turns after that. Tap one to take it off.” |

## Left alone on purpose

- Every delete and replace question, the manual adjustment warning (shortened), the shared-number warning, the non-runner limit question, and every import, recording and save error message.
- The step instructions: “Tap fielders in the order they touched the ball” and its variants, “Tap the fielder who made the error.”, “Double steal? Tap both runners, then pick once.”, “Hold a row and drag to reorder.”, “Number first, then the name. Return adds the player.”
- Scoring facts a ballplayer may not carry: “Counts as a strikeout for the pitcher” (dropped third strike, batter safe), “Counts as caught stealing” (picked off while stealing), “Like a dropped foul pop-up”, “NR marks a designated non-runner.”
- Play-by-play sentences and box score text: they are the record of the game.
- VoiceOver hints and labels, apart from the his-to-their fix.

## Found along the way

- In the lineups sheet, the “Empty spot” row passes its minus icon as the row’s tap action, so the icon never draws (Xcode warns that the `IconBadge` result is unused). This was true before this change too; giving the row an empty `action: {}` would show the icon.

## Tests

- `MoreLogsTests`, `FixPlayAndWordingTests` and `TeamScreensTests` updated to the new delete line, editor description and introduction status. A comment in `SmokeTests` that described the old button detail now matches the button.
- `xcodebuild test -scheme ScorebookUI-Package` on the iPhone 17 simulator: every test passes.
- The app builds for the iPhone 17 simulator, with its UI tests. The walkthroughs find buttons by the start of their labels (“Batter out”, “Thrown out at first”, “Took the base, no throw”, “End game”, “Home screen”), and none of those labels changed.
