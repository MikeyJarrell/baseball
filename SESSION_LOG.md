# Session log

## October 3, 2026 — Project setup

Created a private baseball repository and the starter project notes. The project’s scope and first substantive task remain unspecified.

---

## [2026-10-03 13:30] Scorebook iPhone app — build plan
SESSLOG:[2026-10-03 13:30]

**Project(s):** baseball

### Decisions
- Native iPhone app in Swift, offline, one phone keeps the book and plays the music; free Apple account for now.
- Each game is stored as an ordered list of events; situation, stats and box score are all derived by replaying it, so undo and edits are cheap and the pieces build independently.
- Two Swift packages: ScorebookCore (no screens or sound, tests with swift test) and ScorebookUI (screens and audio). Sixteen job briefs in plan/briefs/, each owning its own folders.
- League rules: nine innings with a time limit, dropped third strike, re-entry, free defensive substitution with fielding stats kept per player through a defense check each half-inning, courtesy runners and designated non-runners credited with the run, opponents’ hitters silent.
- Announcer introductions are recorded by Mikey in the app with a stadium echo; the real Bob Sheppard voice is not cloned.
- Songs are files Mikey supplies in ~/Dropbox/baseball/songs/, not Apple Music.

### Follow-ups
- [ ] Start the foundation job and the design mockups, each in its own worktree.
- [ ] Mikey approves the batting screen and in-play mockups before those screens are built.

### Files
- [created] plan/README.md, plan/architecture.md, plan/rules-for-agents.md, plan/briefs/*.md
- [modified] AGENTS.md, README.md, PROJECT_INDEX.md
- [created] ~/Dropbox/baseball/README.md and songs/

### Context
The session turned Mikey’s app vision into a plan the agent team can execute in parallel. A fresh-eyes review caught gaps the first draft had (runs charged to the wrong pitcher after a pitching change, no way to record a foul tip for strike three or an error with no runner moving, an unknown opponent lineup that never cycled back to the top, the in-play screen needing baseball arithmetic it was forbidden to do); all are fixed in the briefs. Xcode 27 and the iOS 27 simulator are installed.

## [2026-10-03 14:02] No courtesy runners

Mikey corrected the league rules: there are no courtesy runners. Runner replacements are a pinch runner (an ordinary substitution) or the runner for a designated non-runner, whose runs are credited to the designated non-runner. The plan and the running foundation and design jobs were updated.

## [2026-10-03 15:13] League rules and lineup structure

Read the SDABL rule book (April 21, 2026) and summarized the rules the app depends on in notes/league-rules.md. The plan now separates the batting order from the fielders, runs the time limit from the first pitch with “finish this inning” behavior, adds the mercy rule, batting holes, the rule-book non-runner replacement order and re-entry eligibility, and replaces between-innings music with pitcher warm-up songs. Our team is the Diamond Dogs.

---

## [2026-10-03 16:46] Team roster, walk-up songs, schedule and opponents
SESSLOG:[2026-10-03 16:46]

**Project(s):** baseball

### Decisions
- The team lives in `team/roster.csv` until the app saves teams: 16 players (the 15 registered plus Kalid Teodosio), the name each goes by (Chris, Bobby), batting and throwing hand, usual position, usual role (leads off, starts on the bench), and walk-up and warm-up songs.
- Songs are downloaded with the yt-dlp copy Stacher keeps at `~/.stacher/youtube-dl`, by `tools/walkup_songs.py`. Walk-up clips run from 20 seconds before the hook to 30 after, leveled to the same loudness; warm-up songs are kept whole.
- Prefer album audio from YouTube Music over music videos, whose intros shift the timings players read off Spotify. Jon’s live “Bad” is not on streaming; Mikey picked the YouTube upload.
- The walk-up song fades in under the announcer and reaches full volume at the hook. Every song gets the same fade-in; a hook near the top of a track simply reaches full volume later.
- Players carry a usual position and role, so the first game’s lineup can start from the roster.
- Explicit album versions are fine.
- Compadres’ Joshua and Josh Martinson are one person; kept Josh.

### Follow-ups
- [ ] Collect walk-up songs for Aidan, Darin, Chris, Garrett, Saul, Yered, Esteban and Kalid, then run `python3 tools/walkup_songs.py`.
- [ ] Collect jersey numbers for our players.
- [ ] October 4 game against the GWW Whales starts at 1:00 PM, not 9:00.

### Files
- [created] `team/roster.csv`, `team/schedule.md`, `team/opponents.csv`, `team/README.md`, `tools/walkup_songs.py`
- [modified] `plan/README.md`, `plan/architecture.md`, `plan/briefs/walk-up-audio.md`, `plan/briefs/screen-pregame.md`, `plan/briefs/screen-teams-and-songs.md`, `README.md`, `PROJECT_INDEX.md`
- [created] eight walk-up clips and one warm-up song in `~/Dropbox/baseball/songs/`; [modified] `~/Dropbox/baseball/README.md`

### Context
The real Diamond Dogs team, schedule and opponents are now in the project, and 8 of 16 walk-up songs are cut and in Dropbox. The league site’s roster tab is broken; each team’s player list is on its home page and loads only after the page opens, so read it in a browser rather than by downloading the page.

---

## [2026-10-03 17:33] iPad check of the scorebook app
SESSLOG:[2026-10-03 17:33]

**Project(s):** baseball

### Decisions
- The app stays installable on iPad (it already was). Locking the iPad upright like the iPhone was rejected: Apple is phasing out the setting that lets an iPad app refuse to turn or resize, so every screen must handle any window shape.
- The batting screen puts the field on the left and the batter and buttons on the right whenever the window is more than 1.2 times wider than tall; the buttons sit at the bottom of their column. The iPhone layout is unchanged.
- Runner name tags on the field stop growing at 1.6 times their iPhone size.
- Mikey left the empty space above the buttons in the sideways layout as it is.
- Every screen builder now checks their screen on an iPad, upright and sideways, before acceptance (`plan/rules-for-agents.md`).

### Follow-ups
- [ ] The screens still being built get the iPad check before acceptance.

### Files
- [modified] `app/Packages/ScorebookUI/Sources/AtBatScreen/AtBatScreen.swift` — side-by-side layout when wide
- [modified] `app/Packages/ScorebookUI/Sources/DesignSystem/FieldDrawing.swift` — runner tag size cap
- [created] `notes/ipad-check.md` and `notes/ipad-check/` screenshots
- [modified] `plan/rules-for-agents.md`, `PROJECT_INDEX.md`

### Context
The batting screen and in-game change sheets were run on the 13-inch iPad Pro and iPad mini simulators. Upright they worked; the fixes were oversized runner tags on the big iPad and a squashed field when sideways. The simulator cannot be rotated from the command line here (no Simulator app, and asking iOS to rotate from code did nothing), so sideways was tested by drawing the screen at sideways size in a throwaway harness.

---

## [2026-10-03 19:58] Stopping the simulator permission popups
SESSLOG:[2026-10-03 19:58]

**Project(s):** baseball

### Decisions
- Builders use only the existing `iPhone 17`, `iPhone 17e`, `iPad Pro 13-inch (M5)` and `iPad mini (A17 Pro)` simulators, and never create, clone, rename, delete or erase one (`plan/rules-for-agents.md`).
- Throwaway harness apps get their own bundle id and are uninstalled when the builder finishes; several builders may share one simulator.

### Follow-ups
- [ ] Builders already running when this landed (the teams-and-songs screen) may still make their own simulator; Mikey can click Cancel on popups naming a made-up simulator.

### Files
- [modified] `plan/rules-for-agents.md` — simulator rule

### Context
The app asks Mikey to click Allow the first time Claude controls each simulator. Builders had been making a fresh, uniquely named simulator per job (“GameChanges iPhone 17”, “GOReview2 iPhone 17”, “Overview harness iPhone 17”), so every job set off a new popup. Reusing a fixed set should mean one Allow per simulator, going by the popup’s wording; that it stays allowed across sessions has not been confirmed.

---

## [2026-10-03 20:08] Darin’s and Aidan’s walk-up songs
SESSLOG:[2026-10-03 20:08]

**Project(s):** baseball

### Decisions
- Darin: “Big Poppa” by The Notorious B.I.G., the *Ready to Die* album audio, hook at 1:06.
- Aidan: “Mary Jane” by Rick James, the official upload from a greatest-hits album, the same length as the original album track, hook at 0:20. No official upload of the original album was found.

### Follow-ups
- [ ] Import the two new clips on the phone and set each start point to 0:20.

### Files
- [modified] `team/roster.csv` — the two songs, their sources and clip details
- [created] `aidan-kurt.m4a` and `darin-dietrich.m4a` in `~/Dropbox/baseball/songs/`

### Context
Ten of sixteen players now have walk-up clips. Sources were found with the yt-dlp copy’s own YouTube search, preferring the artist’s official album audio.

## [2026-10-03 22:31] The app is built

Every job in the plan is built, reviewed by a fresh reader, fixed and accepted: the rules engine, stats, storage, box score printer, design system, walk-up audio, every screen, and the wiring. Two full games (the sample game and Astros at Yankees, June 23, 2019) were scored through the real screens in the simulator and their box scores match. Mikey decided along the way: layout A, outs written as words, visitors first in every score line, a powder-blue icon from the original logo, a 12-second walk-up fade, no courtesy runners, the SDABL rule book as the source of league rules (nothing enforced), and alternating fielders by inning. Next: Mikey installs it on his phone and scores a televised game as the dress rehearsal.

---

## [2026-10-04 10:05] Every player’s walk-up and warm-up song
SESSLOG:[2026-10-04 10:05]

**Project(s):** baseball

### Decisions
- All 16 players now have a walk-up clip, and all eight pitchers (Gaven, Chris, Erick, Saul, Darin, Allan, Garrett, Mikey) have a warm-up song.
- Allan keeps “Takedown” for batting; “Stamp on the Ground” is his warm-up song, since he was on the pitchers-without-a-warm-up list.
- Yered’s hook is 0:12: transcribing the track showed “I wish I was a little bit taller” starts at 12.5 seconds, so the announcer finishes just before it.
- Sources are the album audio found by searching YouTube Music; where no official upload of the original album exists (“Mary Jane”), an official greatest-hits upload of the same length.

### Follow-ups
- [ ] Import the new clips and warm-up songs on the phone and set start points: Chris 0:10, Saul 0:14, Yered 0:12, Garrett, Esteban and Kalid 0:00, everyone else 0:20.

### Files
- [modified] `team/roster.csv` — songs, sources and clip details for Chris, Garrett, Saul, Yered, Esteban, Kalid; warm-up songs for Mikey, Chris, Garrett, Saul, Erick, Allan, Darin
- [modified] `team/README.md` — how to search YouTube Music for album audio and time a sung line
- [created] 15 clips and warm-up songs in `~/Dropbox/baseball/songs/`

### Context
The roster’s song list is complete. Searching YouTube Music through the yt-dlp copy returns album tracks directly, which beats ordinary YouTube search for matching Spotify timings, and mlx_whisper gives word-level times when a player cares about a particular line.

---

## [2026-10-04 10:28] Scorebook app on Mikey’s iPhone, with the real team
SESSLOG:[2026-10-04 10:28]

**Project(s):** baseball

### Decisions
- Score lines list the visitors first everywhere.
- Every walk-up song fades over the same two seconds; songs carry an optional artist.
- The defense check opens by itself every time we take the field, with a “Dropped third strike instead” link after a strikeout third out.

### Follow-ups
- [ ] Mikey scores a televised game on the phone as the dress rehearsal; problems go in notes/dress-rehearsal-<date>.md.
- [ ] Record the announcer introductions in the app.
- [ ] Reinstall weekly with tools/install_on_phone.sh (phone plugged in and unlocked).
- [ ] Delete ~/Dropbox/baseball/phone-backups/2026-10-04-102329-incomplete (a partial backup from the loader’s first run).

### Files
- [created] tools/load_team.sh, tools/install_on_phone.sh, plan/handoffs/wiring.md, plan/handoffs/load-team.md
- [modified] plan/install-on-iphone.md, team/README.md, PROJECT_INDEX.md

### Context
Every job in the plan was built, reviewed by a fresh reader, fixed and accepted, then wired into one app; two full games scored through the real screens match their box scores. The app is installed on Mikey’s iPhone 17 Pro with his free Apple account, and the loader put the Diamond Dogs (16 players, 24 songs) and 8 opponents (117 players) onto it. Xcode’s command-line build needs -allowProvisioningDeviceRegistration to register a phone on a free account; the install script does that.

---

## [2026-10-04 11:59] Announcer introductions in Mikey’s voice, pieced together
SESSLOG:[2026-10-04 11:59]

**Project(s):** baseball

### Decisions
- Introductions are stitched on the phone from pieces Mikey recorded on the Mac with the ATR2100x: “Now batting,” every number 0–99 and 00, and each player’s name. A new or changed jersey number needs nothing new recorded (Mikey’s design).
- The introduction ends on the name: “Now batting, number twenty-two, Yered Teodosio.” No repeated number, for the iPhone voice and the player page’s script too; the optional “closing” number set was dropped.
- A jersey number changed in the app now wins over roster.csv, which only fills in a blank; the loader notes any difference.
- The loader gives the pieced introduction only to players with none; one chosen in the app is kept.
- Esteban is said es-te-BAN.
- Claude runs the install and team-load scripts itself (now in AGENTS.md).

### Follow-ups
- [ ] Mikey hears an introduction on the phone (player page, “Test: introduction, then song”).
- [ ] Joaquin Canas needs a jersey number.
- [ ] Mikey’s number sheet lists different positions for some players (Gaven P, not CF); update the roster if those are current.

### Files
- [created] tools/record_intros.py, app/Packages/ScorebookUI/Sources/WalkUpAudio/PiecedIntroduction.swift and its tests, plan/handoffs/announcer-pieces.md, feedback/ai/announcer-pieces-review.md
- [modified] Model/People.swift (pieced introductions), TeamImport, TeamLoader, tools/load_team.sh, AnnouncerVoice, TeamScreensWording, team/roster.csv (15 jersey numbers), team/README.md, PROJECT_INDEX.md, AGENTS.md
- [created] ~/Dropbox/baseball/intros/ (118 recordings and preview.m4a); [modified] ~/Dropbox/baseball/README.md

### Context
Mikey wanted to record introductions with his good Mac microphone rather than the phone, and proposed recording every number once so the app could piece them together. A Python recorder trims, filters and levels each take; the app joins the pieces with the same pauses as its phone voice. A fresh review caught that every team load reset numbers changed in the app and re-applied pieced introductions over ones chosen in the app; both fixed. Everything is installed and loaded on the phone, and the check found every piece present, but the stitched introduction has not yet been heard on the phone itself.

---

## [2026-10-04 12:16] Several warm-up songs per pitcher
SESSLOG:[2026-10-04 12:16]

**Project(s):** baseball

### Decisions
- A pitcher’s main warm-up song plays the first inning he starts; extra songs shuffle for later innings, each once before repeats, never two innings running (Mikey chose main-first).
- Mikey sends the extra songs; they live in `team/warmup_extras.csv`, not editable in the app.
- The song is worked out from the game record each time, not remembered: the first version kept a list in memory, and the review showed reopening a game, undo over a changeover, or a pitching change at the changeover then played the wrong song.
- Extras so far: Chris (4), Erick (3), Gaven (2). Luis Miguel’s “El Rey” is the live *El Concierto* recording; no studio version by him exists.

### Follow-ups
- [ ] Reinstall the app (`tools/install_on_phone.sh`) and load the team (`tools/load_team.sh`) so the phone gets the feature and the songs.
- [ ] More extras for the other pitchers when Mikey sends them.

### Files
- [created] `app/Packages/ScorebookCore/Sources/Model/WarmUpRotation.swift`, its tests, `team/warmup_extras.csv`, `plan/handoffs/warmup-rotation.md`, `feedback/ai/warmup-rotation-review.md`
- [modified] `People.swift`, `TeamImport.swift`, `TeamLoader/main.swift`, `GameScreen.swift`, `TeamsWiring.swift`, player page, `tools/walkup_songs.py`, `team/README.md`, `plan/README.md`, `PROJECT_INDEX.md`
- [created] nine extra warm-up tracks in `~/Dropbox/baseball/songs/`

### Context
The feature is built, reviewed twice and tested, but is not on the phone until the next reinstall and team load. Known gaps left on purpose: a half-inning ended before any pitch does not count as started, and a pitching change during a playing warm-up song needs Stop then Play.

## [2026-10-04 12:56] Changes after the first phone install

Pregame got time wheels, a separate fielding step on the diamond, DH in place of “bats only,” and typeable opponent numbers with only the names-and-numbers and numbers-only choices. First and third base now sit in fair territory. Walk-up songs fade in under the announcer and reach full volume at their start point as the announcer finishes. Games can be deleted from the Games list or a box score (the app backs up first), and the game menu has a way home. Installed on the phone except delete-a-game, which goes on at the next install; a test game is still on the phone, and the phone’s files were backed up to Dropbox before any of this.

## [2026-10-04 17:46] Corrections to the October 4 game

Fixed the first real game on the phone after a backup: our starting fielders (Nojadera catching, Jarrell at first, Jackson Cleary #99 in left, Strong in right; Torres Benitez and Erick Rosas Lopez removed), the GWW Whales lineup matched to their registered names and numbers with Holliday, Fitzpatrick, Nuñez and Lopez added, Ortiz and Holliday as their pitchers, Soler and Carney as designated non-runners with the two runs-for-Carney entries corrected, and the Whales roster cleaned of placeholder players. Replayed before and after: 9-4 both times, nothing flagged. team/opponents.csv and team/roster.csv carry the same corrections. App feedback from the game is being handled in another session.

## [2026-10-04 17:52] Mid-game fixes and box score tidy-up
SESSLOG:[2026-10-04 17:52]

**Project(s):** baseball

### Decisions
- Stopping a song fades it out over two seconds; a second tap stops it at once.
- A late lineup card is handled by saying a player “was really” someone else: the two trade places in the whole game, every recorded play included, so stats go to the right person.
- Home and away switch only before the first pitch; innings never go below the inning being played; a hitter comes out of the order only before the first pitch with nothing recorded for his team.
- Undo passes over a confirmed defense check.
- Box score: one team per headline line, positions in capitals (Mikey’s preference; traditional newspapers use lowercase), no lettered pinch-hitter notes, no “ran for” notes, one note per line.
- Players with two last names go by the first (Torres, Rosas), taken from the roster file’s last-name column.
- Warm-up songs added on the phone survive team loads; a file song removed on the phone returns unless its row is deleted too.

### Follow-ups
- [ ] Reinstall the app and load the team once the phone is plugged in (names with two last names need the team load).

### Files
- [created] `GameChanges/LineupsSheet.swift`, `GameChanges/GameDetailsSheet.swift`, `Model/LineupCorrection.swift`, `ScoringTests/MidGameFixTests.swift`, `plan/handoffs/mid-game-editing.md`, `feedback/ai/mid-game-editing-review.md`
- [modified] `GameSession.swift`, `People.swift`, `BoxScore.swift`, `BoxScoreBuilder.swift`, BoxScoreText, BoxScorePicture, `DefenseSheet.swift`, `FieldingStep.swift`, batting screen controls and menu, `GameScreen.swift`, `AppSheets.swift`, `AppModel.swift`, `TeamImport.swift`, tests, `team/README.md`, `PROJECT_INDEX.md`

### Context
Mikey’s list after the first phone install: easier mid-game fixes to lineups, rosters, game details and warm-up music, the fielders check on the diamond with first initials, song fade-outs, and Undo ignoring the defense check; then a cleaner box score. Everything is built, reviewed by a fresh agent (no way found to corrupt a game; its edge cases fixed and tested), and clicked through on the simulator, but not yet on the phone. A first try at the home and away switch refused silently after a pregame substitution; pregame lineup changes now move with their team.

---

## [2026-10-04 18:15] Stats website for teammates
SESSLOG:[2026-10-04 18:15]

**Project(s):** baseball

### Decisions
- The site lives at mikeyjarrell.com/dogs/, served by GitHub Pages from a separate public repository, `MikeyJarrell/dogs`, holding only the built pages; the app’s code stays private.
- Full names, as on the roster (Mikey’s choice); unlisted: every page asks search engines not to list it, and `robots.txt` turns them away.
- No export button in the app: the Mac reads the games straight off the plugged-in phone, as `tools/load_team.sh` already does, so the brief’s export step was dropped.
- The pages use the app’s own rules engine and stats code, so they match the phone’s Season screen; only players who have played are listed.

### Follow-ups
- [ ] First publish: once Mikey plugs the phone in, run `tools/publish_stats.sh` (the Mac copies predate the October 4 game corrections, so publishing from them would be wrong).

### Files
- [created] `app/Packages/ScorebookCore/Sources/StatsSite/` (the page builder), `tools/publish_stats.sh`, `plan/handoffs/stats-website.md`
- [modified] `Package.swift`, `PROJECT_INDEX.md`, `AGENTS.md`, `plan/README.md`

### Context
Mikey asked whether teammates could see stats; the only sharing was the texted box score picture, and a stats-website brief sat unstarted. The site is built and previewed at phone width (record, games, sortable season batting and pitching, a box score page per game, a page per player) but not yet published, because no copy on the Mac has the corrected October 4 game.
