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
