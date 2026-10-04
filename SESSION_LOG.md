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
