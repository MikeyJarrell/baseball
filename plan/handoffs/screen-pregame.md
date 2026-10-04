# Pregame screens: handoff

**Job:** screen builder, pregame screens ([brief](../briefs/screen-pregame.md)).

**Branch:** `codex/screen-pregame`, in the task folder `/Users/mikey/projects/.worktrees/baseball/screen-pregame`. Merged with `main` after the lead builder added the screen test targets.

## What exists now

Everything is in `app/Packages/ScorebookUI/Sources/PregameScreens/`. `PregameFlow` is the five-step sequence, matching the approved mockup’s `pg-` screens:

1. **The game** (`GameStep.swift`): saved opponents as one-tap rows (“Saved roster: 12 players”, “numbers only”, “No saved roster yet”) and “New team” with a name field; date; home or away; innings (nine); scheduled start (9:00 AM, 15 minutes a tap); the time limit as a clock time (12:00 PM, 5 minutes a tap), which moves with the start. The setup keeps the time from start to limit, so a late first pitch moves the limit later (rule 9.1 G); the footer says so. Added beyond the mockup: a “Championship game” switch (3 hours 15 minutes and the 15-run rule, from `GameRules.championship`).
2. **Our lineup** (`OurLineupStep.swift`): three lists. The batting order drags into order (VoiceOver gets Move up and Move down), has a minus to take someone out, “Add to batting order” chips, and a Runs / Non-runner switch on each hitter with “Non-runners 1 of 2” in the header. A third non-runner asks “Jordan Webb would be non-runner number 3 … The league allows 2” and allows it on “Make them a non-runner anyway”; the count then shows “3 of 2” in red. The fielders are the nine positions; tapping one opens the whole roster as chips, and picking someone already fielding swaps the two; “Nobody” empties it. Under the chips, “Takes turns by inning” picks a second player for even innings, written to `GameTeam.fieldingRotations`; a player takes only one even-inning turn, so picking a second one ends the first. Chips show where each player is now (“Ford lf”, “Cole bats only”, “Nash 1b even”, “Voss bench”). At the largest text sizes each hitter’s name gets its own line with the Runs and minus buttons under it, and section headers wrap to two lines. The bench lists everyone else with a “Bat” button.
3. **Their lineup** (`TheirLineupStep.swift`): names and numbers (their batting order from the last game against them, else their whole saved roster), numbers only (typed in batting order; a number matching the saved roster is that player, so names and stats carry over; a blank becomes “Batter 4”), or unknown (a count, nine by default, of “Batter 1” placeholders). The default way in follows what their saved roster holds.
4. **Starting pitchers** (`PitchersStep.swift`): ours with whoever pitched most recently first (“Pitched last game, May 9 · throws right”, “Relieved …”, “Hasn’t pitched this season”); theirs with anyone who has pitched against us first, then their lineup and roster, “Not known yet” (a placeholder “Pitcher”), and “Someone new” (number, name, throwing hand). A chosen pitcher with no known throwing hand gets Right and Left buttons.
5. **Review and play ball** (`ReviewStep.swift`): the game line, both lineups side by side (one above the other at accessibility text sizes) with positions, NR tags, fielders who don’t bat, shared positions and pitchers, and amber notes for anything odd (“Nobody is playing right field.”, “Nobody plays left field in even innings.” when a starter takes a turn somewhere else, “3 designated non-runners; the league allows 2.”). Notes never block. “Play ball” is blocked only with no opponent or an empty batting order.

## How it talks to the rest

`PregameFlow(input:onFinish:)` takes a `PregameInput` and hands back one `PregameResult`: `.playBall(GameSetup)` or `.cancel`. The setup carries the rules (`GameRules` with the chosen innings and time limit), `scheduledStart`, both teams’ batting orders, defenses, non-runners, fielding rotations and short names.

The logic is plain code with no screen: `OurLineup` (the three lists, swaps, shared positions, where the lineup starts), `TheirLineup` (the three ways in, placeholders, their pitcher), `GameDetails` and `PregameDraft` (`PregameBuilder.swift`), and `PregameWording`.

## For the wiring job

- **`PregameInput`**: `ourTeam`; `opponents` (saved teams, in the order to list them); `recentGames`, our recent games’ setups, newest first (the first is “last game”, which our lineup starts from; the newest against the chosen opponent gives their batting order); `pitchingHistory`, this season’s pitching appearances for both teams with dates and started-or-relieved, read from box scores (left empty, the starters of `recentGames` stand in); `usualRoles` (see the request below); `today`.
- **After “Play ball”**, save the opponent with `PregameBuilder.updatedTeam(saved:from:)`: numbers typed in and a new pitcher join their saved roster, missing throwing hands are filled in, and placeholders (“Batter 4”, “Pitcher”) are left off. Our team’s game roster may also carry a throwing hand set on the pitchers step; the same function updates our saved team.
- “Play ball” should open the batting screen and, when we take the field first, the defense check, as the mockup says.
- `PregameFlow.sample(against:at:)` opens the flow at any step with the sample data, for a harness.

## Review

A fresh reviewer’s notes are in `feedback/ai/screen-pregame-review.md`. Findings 1 to 4 are fixed; finding 5 (usual position and role on `Player`) went to the lead builder.

## Vocabulary change request

**`Player.usualPosition` and `Player.usualRole` (leads off, starts on the bench).** `plan/architecture.md` and the teams brief list them, and the brief asks the first game’s lineup to start from them, but `Model/People.swift` has neither. Workaround: `PregameInput.usualRoles`, a dictionary from player to a local `UsualRole` (position, leads off, starts on the bench), which the teams screens or the wiring can fill. Once `Player` has the fields, `OurLineup.fromRoster` should read them and `usualRoles` can go.

## Left out or stubbed

- Non-runners are declared only from the batting order. The model also allows declaring a bench player [9.4 C]; a hitter taken out of the order loses the declaration.
- Their fielders other than the pitcher are not asked for, as in the mockup.
- A position can take turns between two players only, odd and even innings, as the brief describes; `FieldingRotation` would allow more.
- Choosing a fielder as our starting pitcher swaps them with the old pitcher, the same as on the fielders list.

## Evidence

- `xcodebuild -scheme ScorebookUI-Package -destination 'platform=iOS Simulator,name=iPhone 17' build` and `test` in `app/Packages/ScorebookUI`: build succeeded with no warnings; every test passes, including 36 new ones in `Tests/PregameScreensTests/PregameBuilderTests.swift` (8 suites): last game’s lineup carried over with a changed roster; the first game from usual roles; the three lists kept separate; dragging; swaps and emptied positions; the third non-runner asking and then allowed; first base taking turns, checked through `GameTeam.defense(forInning:from:)` for innings 1 to 3; the reviewer’s three ways to lose a fielder in even innings (a starter taking a turn elsewhere, one player given two even-inning turns, a turn-taker made our pitcher); Mudcats, Bombers and Riverhawks lineups; a new pitcher saved to their team and placeholders not saved; pitchers most recent first; clock times and championship rules; and the quickest setup.
- `Previews.swift`: every step against the full-roster Mudcats, the numbers-only Bombers and the unknown Riverhawks, our lineup before the first game, in light, dark and the largest text size.
- Under a minute: in a throwaway harness app outside the repository (its own iPhone 17 simulator, since deleted), a UI test tapped Mudcats, Next four times and Play ball: 6 taps, 15.3 seconds from opening to the finished setup, starting from last game’s lineup. That run caught a bug (the review step showed a stale copy and “Pick an opponent first.”), fixed by passing it a binding. A second UI test declared three non-runners through the confirmation and set first base to take turns.
- Screenshots in [screen-pregame/](screen-pregame/): `game`, `ours`, `ours-firstgame`, `ours-third-nonrunner-question`, `ours-first-base-turns`, `theirs-mudcats`, `theirs-bombers`, `theirs-riverhawks`, `pitchers`, `review`, dark versions (`review-dark`, `ours-dark`, `theirs-bombers-dark`), largest text (`game-big`, `ours-big` and `ours-big-2` showing the batting order, `pitchers-big`), and `quick-result`, the setup the six-tap run handed back.
