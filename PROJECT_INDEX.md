# Baseball — project dashboard

**Last reviewed:** October 4, 2026

| Item | Status |
|---|---|
| Plan, roles and job briefs | Accepted, in [plan/](plan/README.md); league rules in [notes/league-rules.md](notes/league-rules.md) |
| Foundation, vocabulary pass, app icon | Accepted |
| Rules engine, stats, storage, box score printer, design system, 106 test scenarios | Accepted; 197 game-logic tests pass |
| Batting screen, in-game changes sheets | Accepted |
| In-play sequence, walk-up audio, teams and songs, pregame, game overview, postgame and season screens | Accepted |
| iPad | Batting screen and change sheets checked; batting screen goes side by side when sideways ([notes](notes/ipad-check.md)) |
| Wiring the app together | Accepted: two full games scored through the real screens match their box scores ([handoff](plan/handoffs/wiring.md)); install steps for Mikey in [plan/install-on-iphone.md](plan/install-on-iphone.md) |
| The app on Mikey’s iPhone | Installed; the Diamond Dogs (16 players, 24 songs) and 8 opponents loaded with `tools/load_team.sh`; weekly reinstall with `tools/install_on_phone.sh` ([handoff](plan/handoffs/load-team.md)) |
| Announcer introductions | Built: pieced together from Mikey’s recordings of “Now batting,” every number and each name, recorded on the Mac with `tools/record_intros.py` ([handoff](plan/handoffs/announcer-pieces.md)); all recorded and on the phone with the jersey numbers, not yet heard there |
| Several warm-up songs per pitcher | Built: main song his first inning, extras from `team/warmup_extras.csv` shuffled for later innings; on the phone after the next reinstall and team load. Extra songs listed for Chris, Erick and Gaven |
| Mid-game fixes and box score tidy-up | Built: songs fade out over two seconds when stopped; Lineups and rosters in the Subs menu (late lineup cards, names, numbers, new players); warm-up songs added mid-game; game details (date, start, innings, home and away); the fielders check on the diamond with first initials; players with two last names go by the first (Torres, Rosas); Undo skips the defense check; box score with one team per headline line, capital positions, one note per line, no pinch-hitter or “ran for” notes ([handoff](plan/handoffs/mid-game-editing.md)). Not on the phone until the next reinstall |
| Stats website | Built: `tools/publish_stats.sh` reads the games off the plugged-in phone and publishes season stats, box scores and player pages to mikeyjarrell.com/dogs/ (full names, hidden from search engines) ([handoff](plan/handoffs/stats-website.md)); not yet published |
| Dress rehearsal | Not started: Mikey scores a televised game on his phone |

No deadlines have been assigned.
