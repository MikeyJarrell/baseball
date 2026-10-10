# Baseball — project dashboard

**Last reviewed:** October 6, 2026

| Item | Status |
|---|---|
| Plan, roles and job briefs | Accepted, in [plan/](plan/README.md); league rules in [notes/league-rules.md](notes/league-rules.md) |
| Foundation, vocabulary pass, app icon | Accepted |
| Rules engine, stats, storage, box score printer, design system, 106 test scenarios | Accepted; 197 game-logic tests pass |
| Batting screen, in-game changes sheets | Accepted |
| In-play sequence, walk-up audio, teams and songs, pregame, game overview, postgame and season screens | Accepted |
| iPad | Batting screen and change sheets checked; batting screen goes side by side when sideways ([notes](notes/ipad-check.md)) |
| Wiring the app together | Accepted: two full games scored through the real screens match their box scores ([handoff](plan/handoffs/wiring.md)); install steps for Mikey in [plan/install-on-iphone.md](plan/install-on-iphone.md) |
| The app on Mikey’s iPhone | Installed; the Diamond Dogs (16 players, 24 songs) and 8 opponents loaded with `tools/load_team.sh`; reinstall with `tools/install_on_phone.sh` (paid developer account, so an install opens for a year) ([handoff](plan/handoffs/load-team.md)) |
| Announcer introductions | Built: pieced together from Mikey’s recordings of “Now batting,” every number and each name, recorded on the Mac with `tools/record_intros.py` ([handoff](plan/handoffs/announcer-pieces.md)); all recorded and on the phone with the jersey numbers. A name can also be recorded on the phone mid-game (batter sheet, add a hitter, player page); heard on the phone and working ([handoff](plan/handoffs/name-recording.md)) |
| Several warm-up songs per pitcher | Built: main song his first inning, extras from `team/warmup_extras.csv` shuffled for later innings; in the installed app; extra songs for Chris, Erick, Gaven, Garrett, Saul, Darin, Allan and Mikey, all loaded onto the phone October 6 |
| Mid-game fixes and box score tidy-up | Built: songs fade out over two seconds when stopped; Lineups and rosters in the Subs menu (late lineup cards, names, numbers, new players); warm-up songs added mid-game; game details (date, start, innings, home and away); the fielders check on the diamond with first initials; players with two last names go by the first (Torres, Rosas); Undo skips the defense check; box score with one team per headline line, capital positions, one note per line, no pinch-hitter or “ran for” notes ([handoff](plan/handoffs/mid-game-editing.md)). On the phone |
| On-screen text | Trimmed: about 125 self-evident or explanatory lines shortened or cut ([handoff](plan/handoffs/trim-app-text.md)); on the phone |
| Stats website | Built: `tools/publish_stats.sh` reads the games off the plugged-in phone and publishes season stats, box scores and player pages to mikeyjarrell.com/dogs/ (full names, hidden from search engines) ([handoff](plan/handoffs/stats-website.md)); published October 6 with the corrected Whales game. Rerun after each game |
| In use at games | Live: the first real game was scored on the phone on October 4, 2026; fixes from it are on the phone |
| Erick’s iPhone | Through TestFlight on Mikey’s paid developer account, with the team and songs built into the app; first copy uploaded October 6; Erick added to the internal testing group October 10 and emailed the install button, waiting on him to install ([plan](plan/share-with-teammate.md), [his instructions](plan/teammate-instructions.md)) |
| Matthew Glatt’s iPhone | Second TestFlight tester (biggio330@aol.com), invited and added to the “Team” test group October 10; waiting on him to install. Uploading a new copy from the command line has been refused since October 10; a ready copy waits in Xcode’s Organizer on the Mac mini ([plan](plan/share-with-teammate.md)) |

No deadlines have been assigned.
