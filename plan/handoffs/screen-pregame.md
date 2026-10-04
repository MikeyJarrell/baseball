# Pregame screens: handoff

**Job:** screen builder, pregame screens ([brief](../briefs/screen-pregame.md)).

**Branch:** `codex/screen-pregame`, in the task folder `/Users/mikey/projects/.worktrees/baseball/screen-pregame`. Merged with `main` after the lead builder added the screen test targets.

## What exists now

Everything is in `app/Packages/ScorebookUI/Sources/PregameScreens/`. `PregameFlow` is a six-step sequence. It started from the approved mockup’s five `pg-` screens; after using it on his phone, Mikey asked for time wheels, a separate fielding step on the field drawing, typeable numbers for their hitters, no “Unknown” lineup, and “DH” for a hitter who does not field.

1. **The game** (`GameStep.swift`): saved opponents as one-tap rows (“Saved roster: 12 players”, “numbers only”, “No saved roster yet”) and “New team” with a name field; date; home or away; innings (nine). The scheduled start (9:00 AM) and the time limit (12:00 PM) are rows showing the clock time; tapping one opens the iOS time wheel under it, to any minute (1:03 PM). The limit starts three hours after the start, moves with it, and stays editable. The setup keeps the time from start to limit, so a late first pitch moves the limit later (rule 9.1 G); the footer says so. Added beyond the mockup: a “Championship game” switch (3 hours 15 minutes and the 15-run rule, from `GameRules.championship`).
2. **Batting order** (`BattingOrderStep.swift`): the batting order drags into order (VoiceOver gets Move up and Move down), has a minus to take someone out, “Add to batting order” chips, and a Runs / Non-runner switch on each hitter with “Non-runners 1 of 2” in the header. A third non-runner asks “Jordan Webb would be non-runner number 3 … The league allows 2” and allows it on “Make them a non-runner anyway”; the count then shows “3 of 2” in red. Under each name is where they field, or “DH” for a hitter who does not. At the largest text sizes each hitter’s name gets its own line with the Runs and minus buttons under it, and section headers wrap. The bench lists everyone who neither bats nor fields, with a “Bat” button.
3. **Fielders** (`FieldingStep.swift`): the field drawing from DesignSystem with each fielder’s name under their position, and the nine positions listed under it. Tapping a position on the diamond (or its row) slides up a list of our whole roster with where each player is now (“Shortstop · bats 2nd”, “Pitcher · doesn’t bat”, “DH · bats 10th”, “Bench”); picking someone puts them there, and picking someone already fielding swaps the two; “Nobody” empties it. Under the players, “Alternate with…” shares the position by turns (the starter in odd innings, the player picked in even ones), written to `GameTeam.fieldingRotations`; a player takes only one even-inning turn. Anyone can field without batting.
4. **Their lineup** (`TheirLineupStep.swift`): names and numbers (their batting order from the last game against them, else their whole saved roster), with each player’s jersey number in a box in their row; tapping the name types in it too. Or numbers only, typed in batting order: a number matching the saved roster is that player, so names and stats carry over, and a blank becomes “Batter 4”. Both lists drag into order (hold a row). The default is names when their saved roster has names, else numbers; a team with no saved roster starts with nine blank numbers. Typed numbers are saved back to that opponent’s roster after “Play ball”.
5. **Starting pitchers** (`PitchersStep.swift`): ours with whoever pitched most recently first (“Pitched last game, May 9 · throws right”, “Relieved …”, “Hasn’t pitched this season”); theirs with anyone who has pitched against us first, then their lineup and roster, “Not known yet” (a placeholder “Pitcher”), and “Someone new” (number, name, throwing hand). A chosen pitcher with no known throwing hand gets Right and Left buttons.
6. **Review and play ball** (`ReviewStep.swift`): the game line, both lineups side by side (one above the other at accessibility text sizes) with positions, NR tags, fielders who don’t bat, shared positions and pitchers, and amber notes for anything odd (“Nobody is playing right field.”, “Nobody plays left field in even innings.” when a starter takes a turn somewhere else, “3 designated non-runners; the league allows 2.”). Notes never block. “Play ball” is blocked only with no opponent or an empty batting order.

## How it talks to the rest

`PregameFlow(input:onFinish:)` takes a `PregameInput` and hands back one `PregameResult`: `.playBall(GameSetup)` or `.cancel`. The setup carries the rules (`GameRules` with the chosen innings and time limit), `scheduledStart`, both teams’ batting orders, defenses, non-runners, fielding rotations and short names.

The logic is plain code with no screen: `OurLineup` (the three lists, swaps, shared positions, where the lineup starts), `TheirLineup` (the two ways in, typed numbers, placeholders, their pitcher), `GameDetails` and `PregameDraft` (`PregameBuilder.swift`), and `PregameWording`.

## For the wiring job

- **`PregameInput`**: `ourTeam`; `opponents` (saved teams, in the order to list them); `recentGames`, our recent games’ setups, newest first (the first is “last game”, which our lineup starts from; the newest against the chosen opponent gives their batting order); `pitchingHistory`, this season’s pitching appearances for both teams with dates and started-or-relieved, read from box scores (left empty, the starters of `recentGames` stand in); `today`. Before our first game the lineup reads each player’s `usualPosition`, `usualRole` and `usuallyLeadsOff`.
- **After “Play ball”**, save the opponent with `PregameBuilder.updatedTeam(saved:from:)`: new numbers and a new pitcher join their saved roster, a number typed for a saved player replaces the saved one, missing throwing hands are filled in, and placeholders (“Batter 4”, “Pitcher”) are left off. Our team’s game roster may also carry a throwing hand set on the pitchers step; the same function updates our saved team.
- “Play ball” should open the batting screen and, when we take the field first, the defense check, as the mockup says.
- `PregameFlow.sample(against:at:)` opens the flow at any step with the sample data, for a harness.

## Review

A fresh reviewer’s notes are in `feedback/ai/screen-pregame-review.md`. Findings 1 to 4 are fixed; finding 5 (usual position and role on `Player`) went to the lead builder.

## Labels in other modules

“Bats only” still appears outside pregame, on the team screens: `TeamScreens/PlayerEditSheet.swift` (“None (bats only)” in the usual-position picker) and `TeamScreens/TeamScreensWording.swift` (“Bats only” in a player’s usual-spot line). Pregame now says “DH”.

## Left out or stubbed

- Non-runners are declared only from the batting order. The model also allows declaring a bench player [9.4 C]; a hitter taken out of the order loses the declaration.
- Their fielders other than the pitcher are not asked for, as in the mockup.
- A position can take turns between two players only, odd and even innings, as the brief describes; `FieldingRotation` would allow more.
- Choosing a fielder as our starting pitcher swaps them with the old pitcher, the same as on the fielding step.
- Dragging works by holding a row; the time wheels are shown one at a time, opened by tapping the time.

## Evidence

- `xcodebuild -scheme ScorebookUI-Package -destination 'platform=iOS Simulator,name=iPhone 17' build` and `test` in `app/Packages/ScorebookUI`: no warnings; every test passes, including 41 in `Tests/PregameScreensTests/PregameBuilderTests.swift` (9 suites): last game’s lineup carried over with a changed roster; the first game from each player’s usual position and role; the three lists kept separate; dragging; swaps and emptied positions; the third non-runner asking and then allowed; first base taking turns, checked through `GameTeam.defense(forInning:from:)`; the three ways to lose a fielder in even innings; the start and limit set to any minute (1:03 PM start, 4:03 PM limit, then 3:58 PM); a number typed in a Mudcats row used in the game and saved back to the roster; numbers typed for a team with no saved roster; dragging their order both ways; where each player is now (“DH · bats 9th”); pitchers most recent first; championship rules; and the quickest setup. The app builds (`xcodebuild -project app/Scorebook.xcodeproj -scheme Scorebook`).
- `Previews.swift`: every step against the full-roster Mudcats, the numbers-only Bombers and the Riverhawks (no saved roster), our batting order before the first game, in light, dark and the largest text size.
- In a throwaway harness app outside the repository (its own iPhone 17 simulator, since deleted), UI tests drove the real screens: Mudcats, Next five times and Play ball, 7 taps and 13.1 seconds from opening to the finished setup, starting from last game’s lineup; the start wheel turned to 1:03 PM; first base tapped on the fielding step, opening the player list; 23 typed into Marcus Hale’s number box; Ray Collins dragged from ninth to fourth.
- Screenshots in [screen-pregame/](screen-pregame/): `game`, `game-start-wheel`, `game-big`; `ours`, `ours-firstgame`, `ours-big` (the batting order at the largest text size); `fielding`, `fielding-picker`, `fielding-dark`, `fielding-big`; `theirs-number-typed`, `theirs-after-grip-drag`, `theirs-bombers`, `theirs-riverhawks`, `theirs-mudcats-dark`; `pitchers`; `review`; and `quick-result`, the setup the seven-tap run handed back.
