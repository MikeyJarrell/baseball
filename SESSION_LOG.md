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
