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
| The app on Mikey’s iPhone | Installed; the Diamond Dogs (16 players, 24 songs) and 8 opponents loaded with `tools/load_team.sh`; weekly reinstall with `tools/install_on_phone.sh` ([handoff](plan/handoffs/load-team.md)) |
| Announcer introductions | Built: pieced together from Mikey’s recordings of “Now batting,” every number and each name, recorded on the Mac with `tools/record_intros.py` ([handoff](plan/handoffs/announcer-pieces.md)); all recorded and on the phone with the jersey numbers, not yet heard there |
| Several warm-up songs per pitcher | Built: main song his first inning, extras from `team/warmup_extras.csv` shuffled for later innings; on the phone after the next reinstall and team load. Extra songs listed for Chris, Erick and Gaven |
| Dress rehearsal | Not started: Mikey scores a televised game on his phone |
| Erick’s iPhone | Planned: through TestFlight on Mikey’s paid developer account, with the team and songs built into the app ([plan](plan/share-with-teammate.md), [his instructions](plan/teammate-instructions.md)) |

No deadlines have been assigned.
