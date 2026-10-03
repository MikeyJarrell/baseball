# Scorebook app — the plan

An iPhone app for the Diamond Dogs’ bench (San Diego Adult Baseball League, 18A division): it keeps the book pitch by pitch, plays each of our hitters’ walk-up songs, and turns every game into a box score and season stats. “Scorebook” is a working name.

The other files in this folder hold the detail. [architecture.md](architecture.md) is the technical skeleton the builders share, [rules-for-agents.md](rules-for-agents.md) is the standing orders every builder follows, and [briefs/](briefs/) holds one set of marching orders per job. The league rules the app depends on, with rule numbers, are in [notes/league-rules.md](../notes/league-rules.md).

## What the app does

**Walk-up songs.** Song clips live on the phone, imported from the Files app. Each player on our roster has a song, with a start point so a full track can begin at the hook. When one of our hitters comes up, that player’s song is cued on the batting screen: one tap plays it, and it fades out by itself after 12 seconds of song, or sooner with a second tap. The phone ignores the silent switch and plays through a Bluetooth speaker, including with the screen locked.

**Stadium announcer.** Before the song, an optional introduction in the old Yankee Stadium style: “Now batting, number two, Derek Jeter. Number two.” Mikey records each player’s introduction in his own impression, straight into the app from that player’s page, and the app adds a stadium echo. A player without a recording yet can use the iPhone’s built-in voice, slowed to that cadence. One tap plays the introduction with the song fading in underneath it, reaching full volume at the hook as the announcer finishes. This is a nice-to-have, built after the walk-up songs work.

**Pitcher warm-up music.** Each of our pitchers can pick a warm-up song. When we take the field, the music button plays the current pitcher’s song until it is stopped or the first pitch is recorded. Nothing plays while the other team warms up.

**Keeping the book.** The main screen is the batter at the plate. Four big buttons do most of the work: ball, strike, foul, in play. Four balls and three strikes take care of themselves. Tapping “in play” opens a short sequence that starts from the batter: batter out, a hit, reached on error, or fielder’s choice (batter safe, someone else out), then for an out, the fielders tapped on a drawing of the field in the order they touched the ball, so tapping the shortstop and then the first baseman writes “6-3.” The app then shows where it thinks every runner ended up, using the obvious default (runners forced along on a walk, runners moving up as far as the batter on a hit), and the scorer fixes anything that went differently by tapping that runner. A single where the batter takes second on an error is entered as a single; moving the batter to second then asks whether it was on the throw or on an error, and by whom, and the book reads “1B 7, E7.” A 5-4-3 with a runner on first is three taps on the field and a confirm.

After the play is saved, the next batter appears. After the third out, the screen flips to the other team’s next hitter. Undo is always one tap away, because the scorer will hit the wrong button with a beer in the other hand.

**Checking the situation.** The top of the batting screen always shows the inning, score, outs, count, runners on base, who is up and who is on deck, the pitcher with throwing hand and pitch count, and what this batter has done earlier today (“6-3, walk, single to left”). A second screen, a swipe away, shows the full box score so far.

**Lineups and changes.** Before the game: pick the opponent, whether we are home or away, the number of innings (nine unless changed), the scheduled start (9:00 AM unless changed), both batting orders, our fielders, and both starting pitchers. The batting order and the fielders are separate lists, because the league lets batters skip defense and fielders skip batting: any number of hitters, nine fielders, everyone else on the bench. Up to two designated non-runners are marked in the batting order. Our lineup comes from our roster. Their lineup can be names and numbers, numbers alone, or nothing, in which case their hitters are filled in as they come up. During the game, one substitution button on the batting screen opens every kind of change: new pitcher, fielders moved or replaced, pinch hitter, pinch runner, a runner for a designated non-runner, and a hitter added to the bottom of the batting order. When a designated non-runner reaches base, the app asks who is running, offering first the runner the league rule names (the last recorded out, or in the first inning before any out, the last batter in the order); the non-runner can also choose to run. The pinch-hit list shows which starters are eligible to re-enter under the league rule. Batters and pitchers can be marked right- or left-handed.

**Fielders.** Each time our team takes the field, a quick check lists who is at each position; one tap confirms it, or tap a position to fix it. Errors, putouts and assists are kept for each player, so the app always knows who is standing where. **Time limit and mercy rule.** No new inning starts three hours after the first pitch. Before the game the limit shows as 12:00 PM for a 9:00 AM start; at the first pitch it becomes three hours after that pitch, and the scorer can correct it, since the umpire keeps the official time. When the limit passes, the batting screen says to finish the inning; when that inning is over, or after the top half if the home team leads, the app says the game is over and offers to end it. A tie at the time limit stays a tie. The app also says when the mercy rule ends the game: a 12-run lead after seven innings, or six and a half with the home team ahead.

**Stats.** Every finished game becomes a box score and joins the season totals: batting average, on-base percentage, slugging, and the counting stats behind them, for every player on our team, plus pitching lines. At the end of a game the app produces an old-newspaper-style box score as a picture, ready to text to the group. A public stats website comes later.

## How it fits together

Every game is stored as a running list of everything that happened, in order: this pitch was a ball, this one was a foul, this ball in play was a 6-3, this pitcher came in. Nothing else is saved. The score, the count, the runners and every stat are worked out fresh from that list whenever they are needed.

Three things follow from that. Undo means deleting the last entry. A mistake from three innings ago is fixed by correcting that one entry, and everything after it recalculates. And the pieces of the app can be built separately, because each one only has to understand the list: the part that tracks the game situation, the part that computes stats, and the part that prints a box score all read the same list and never talk to each other.

The app is built as a set of separate pieces, each owned by one builder:

| Piece | What it does | Needs a screen? |
|---|---|---|
| Shared vocabulary | The agreed definitions every other piece uses: what a player is, what a pitch is, what a play is | No |
| Rules engine | Reads the list of events and works out the situation: count, outs, runners, score, who is up | No |
| Stats | Turns games into box scores and box scores into season totals | No |
| Box score printer | Lays out a finished box score as a newspaper-style picture and as text | No |
| Storage | Saves every event the moment it is entered, and reopens a game in progress if the app closes | No |
| Walk-up audio | Imports songs, stores start points, plays and fades | No |
| Look and graphics | Colors, type, buttons, the drawing of the field, the app icon | Yes |
| Screens | One builder per group of screens | Yes |

The screens never do baseball arithmetic. A screen is handed a situation to display and hands back whatever the scorer tapped. That is what lets the batting screen be built and tested with made-up game situations while the rules engine is still being written.

The pieces that need no screen build and test on the Mac with or without Xcode, Apple’s app-building program. The screens and audio need Xcode and its iPhone simulator, both installed.

## Build order

**Foundation.** One builder sets up the empty project, writes the shared vocabulary, and writes a set of made-up teams and game situations for everyone else to build against. Before finishing, it writes out twenty of the hardest plays in baseball scoring (a dropped third strike, a run scored by a runner the previous pitcher put on base, a double steal with a throwing error) in that vocabulary, and fixes the vocabulary until every one fits. This is the one job that has to finish before the rest start. At the same time, the designer starts on screen mockups, since those need no code.

**Mockup approval.** The designer publishes clickable mockups of every screen as a private web page Mikey can open on his phone. Mikey approves or marks up the batting screen and the in-play sequence before anyone builds them, because those two screens are the app.

**Building in parallel.** Once the foundation lands, every other job runs at the same time, each in its own copy of the project: rules engine, stats, box score printer, storage, walk-up audio, test scenarios, look and graphics, and the screen groups. No two jobs edit the same files.

**Wiring.** One builder connects the screens to the rules engine, storage and audio, so tapping “ball” actually changes the count and the song actually plays. At the end of this stage the app works end to end in the iPhone simulator on the Mac.

**Dress rehearsal.** Mikey scores a televised game with the app on his phone, start to finish, and writes down everything that was slow, confusing or wrong. Then the same thing at a real game of ours.

**Later.** The stats website, an iPad layout, and two phones sharing one game. The first version runs on one phone, which both keeps the book and plays the music.

## The team

Each job below has its own brief in [briefs/](briefs/). A brief says what the job delivers, which files it owns, what it may read but not change, and how to tell it is finished.

| Job | Brief | Starts when |
|---|---|---|
| Lead builder: foundation, then wiring the pieces together and merging everyone’s work | [foundation](briefs/foundation.md), [wiring and dress rehearsal](briefs/wiring-and-dress-rehearsal.md) | First; wiring after the parallel build |
| Designer: mockups, colors and type, the field drawing, the app icon, the newspaper look | [design and mockups](briefs/design-and-mockups.md) | Right away |
| Rules engine builder | [game rules engine](briefs/game-rules-engine.md) | After foundation |
| Stats builder | [stats engine](briefs/stats-engine.md) | After foundation |
| Box score printer | [box score printer](briefs/box-score-printer.md) | After foundation |
| Storage builder | [storage](briefs/storage.md) | After foundation |
| Audio builder | [walk-up audio](briefs/walk-up-audio.md) | After foundation |
| Test writer: a library of game situations with known right answers, used to check the rules engine and stats | [test scenarios](briefs/test-scenarios.md) | After foundation |
| Screen builder: teams, rosters and song assignments | [teams and songs screens](briefs/screen-teams-and-songs.md) | After foundation and mockup approval |
| Screen builder: pregame lineups | [pregame screens](briefs/screen-pregame.md) | After foundation and mockup approval |
| Screen builder: the batting screen | [batting screen](briefs/screen-at-bat.md) | After foundation and mockup approval |
| Screen builder: the in-play sequence | [in-play sequence](briefs/screen-play-entry.md) | After foundation and mockup approval |
| Screen builder: substitutions, pitching changes, added hitters, steals and other runner moves | [in-game changes](briefs/screen-in-game-changes.md) | After foundation and mockup approval |
| Screen builder: the game-so-far screen and batter history | [game overview](briefs/screen-game-overview.md) | After foundation and mockup approval |
| Screen builder: end of game and season stats | [postgame and season screens](briefs/screen-postgame-and-season.md) | After foundation and mockup approval |
| Reviewer: a fresh reader who checks each job before it is accepted | [rules-for-agents.md](rules-for-agents.md) | As each job finishes |
| Website builder | [stats website](briefs/stats-website.md) | Later |

Four to six jobs at a time is a sensible pace, so Mikey is not reviewing ten things at once. A good first wave is foundation and design together; then the rules engine and test scenarios together, with stats, storage and the box score printer; then audio and the screens once the mockups are approved.

## What Mikey has to do

1. Plug the phone into the Mac when the first version is ready to install. The app goes on with Mikey’s free Apple account, so it stops opening after seven days and needs reinstalling from the Mac. The Apple Developer Program, $99 a year, removes that limit and lets a coach install it through TestFlight, Apple’s system for testing apps before release; that waits until someone else needs the app.
2. Send the full-size Diamond Dogs logo, for the app icon, to the Dropbox folder `baseball/branding/`.
3. Collect each player’s song and the time it should start, into [team/roster.csv](../team/roster.csv). On the Mac, `python3 tools/walkup_songs.py` downloads each song, cuts a clip around the hook, evens out the loudness, and saves it to the Dropbox folder `baseball/songs/`; on the phone, the app imports them from Dropbox through the Files app.
4. Record the announcer introductions in the app, once it can record.
5. Score a televised game as the dress rehearsal.
