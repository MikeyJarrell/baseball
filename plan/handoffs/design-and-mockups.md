# Design and mockups: handoff

**Job:** designer.

**Branch:** `codex/design-and-mockups`, in the task folder `/Users/mikey/projects/.worktrees/baseball/design-and-mockups`.

## What exists now

- **The approved mockups** in `plan/mockups/index.html`, with a README listing every screen. They are the reference for every screen builder.
- **The design system** in `app/Packages/ScorebookUI/Sources/DesignSystem/`, filling in the foundation’s stub. Every name the stub declared is still there with the same meaning; new names are additions only.

## Colors (`Colors.swift`)

Every color has a light and a dark value. Light mode is the outdoor default and uses the strongest contrast.

- **Our team** comes from the Diamond Dogs logo: `ourTeam` is powder blue with black text on it (`onOurTeam`), never white. Also `ourTeamDeep` (a playing song button), `ourTeamSoft` (pale backgrounds), `ourTeamText` (our blue as readable text), `ourTeamBadge` (the logo’s black, behind our player numbers) and `ourTeamAccent` (the logo’s tan, used sparingly).
- **Their team** is `theirTeam`, a slate gray with white text (`onTheirTeam`), plus `theirTeamSoft` and `theirTeamText`. Their backgrounds carry faint diagonal stripes, so the teams differ in pattern as well as color.
- **`TeamLook`** (`.ours`, `.theirs`) hands a screen the right fill, text and tint for whichever team is batting, and **`TeamBackground(look)`** draws a team’s band, stripes included. Screens pass the batting team’s `TeamLook` and get the right colors back.
- **Count buttons:** `ball` green, `strike` amber with black text (`onStrike`), `foul` near-black, `inPlay` deep blue. The deep blue is also the main action color (Save, Runners) and `highlight` (a tapped fielder).
- **Signals:** `out` red (outs, runners put out, errors, the time-limit banner), `warning` amber, `sequenceBadge` (the 1, 2, 3 on tapped fielders), `success`, `warmUpMusic` purple.
- **Field:** `fieldGrass`, `fieldGrassInfield`, `fieldDirt`, `fieldChalk`, `fieldOutline`, `baseEmpty`, `baseOccupied`.
- **Newspaper:** `newspaperPaper` and `newspaperInk`, the same in dark mode, since the box score is a picture to text.
- New neutral: `surfaceSecondary`, for chips and segmented controls.

## Type and spacing (`Typography.swift`)

- **Fonts:** San Francisco throughout and New York (the system serif) for the newspaper, both built into iOS. Every style follows the phone’s text size setting. Scoreboard numbers and notation use same-width digits so a changing count does not jiggle.
- **New text styles:** `scoreboardSmall`, `largeTitle`, `batterName`, `chip`, `sectionLabel`, `countButtonHint`, `notationLarge`, `newspaperHeadline`, `newspaperHeading`, `newspaperBody`.
- **Changed text style:** `notation` is now bold San Francisco with same-width digits, matching the mockups, where the stub had a typewriter-style font.
- **New spacing values:** `bigButtonCornerRadius` (18), `screenEdge` (12), `countButtonHeight` (84), `countButtonMinimumHeight` (64), `songButtonHeight` (64), `primaryButtonHeight` (56).

## Buttons and pieces (`Buttons.swift`)

- **`CountButtonStyle`.** `CountButtonStyle(color:)` still works, with an optional `textColor`. Ready-made versions: `CountButtonStyle.ball`, `.strike` (black text), `.foul`, `.inPlay`. Each fills the space its parent gives it, has a darker strip along its bottom edge, and sinks slightly when pressed.
- **`CountButtonLabel("Ball", hint: "makes it 2–1")`.** The two-line label from the mockup; each line stays on one line and its words shrink to fit.
- **`PlainActionButtonStyle`.** Now the gray chip from the mockup: Undo, HBP, IBB, Foul tip, Subs, menu items.
- **New styles:**
  - `PrimaryButtonStyle`: Save, Runners, Next. It dims by itself when disabled.
  - `TeamButtonStyle(look, isActive:)`: the walk-up song button and Play ball; `isActive` is the playing state.
- **New views:**
  - `PlayerNumberBadge("24", look: .ours)`: ours black with blue numbers, theirs slate.
  - `TeamLogo(size:)`: the logo, with the picture itself at `TeamLogo.image` for the box score printer.
- **Largest text sizes.** Count buttons, chips and the song button stop growing at a set text size, so the batting screen keeps its layout at the largest one: count buttons and the song button at the first accessibility size, chips at the largest ordinary size. Everything else keeps growing.

## The field drawing (`FieldDrawing.swift`)

**What the foundation stubbed, unchanged:** `FieldTap`, `FieldRunnerMarker` with `endBase`, the initializer and its five properties, `spot(for:)` for positions and bases, and `nearestPosition(to:)`.

**What it draws:**

- grass, dirt and foul lines;
- lit bases in the batting team’s color;
- the nine fielders as tappable numbered circles; a tapped fielder turns blue with an amber order badge;
- dashed blue throw arrows between tapped fielders;
- runner markers with solid arrows round the base paths, or a red dashed path and a red cross at the base where a runner was put out;
- a tappable name tag for each runner.

Two tags ending on the same base (two runners scoring) sit side by side, so each can be tapped; a tag hands back `.runner(id)`. Every tap target is at least 44 points, and every tappable part is a real button VoiceOver can reach. With no `onTap`, the drawing only shows.

**Options added as modifier-style methods,** so no existing call changes:

- `.zoom(.infield)`: the batting screen’s larger infield-only view, with no fielders.
- `.showsFielders(_:)`.
- `.fielderNames([.shortstop: "Ortiz"])`: names under the fielders, for when our team is in the field.
- `.baseRunners([.second: FieldBaseRunner(runner:label:)])`: runners standing on base, each with a name tag, for the batting screen.
- `.battingTeam(.ours)`: runners and lit bases in that team’s color; without it they are neutral amber.
- `.hitLocation(_:)`: a dot where a hit landed.
- `.errorPositions([.shortstop])`: the fielder charged with an error, drawn red.

**Field points:** `x` runs 0 to 1 from the left-field side, and `y` from home plate (0) to the deepest part of center field (1), as `Model` describes `FieldPoint`. `spot(for:)` changed its numbers to match the new drawing. `nearestPosition(to:)` never answers the catcher, since no hit lands behind home plate.

## Previews

Every file has previews in light and dark mode and at the largest accessibility text size:

- **Colors:** the full palette, with both team bands.
- **Type:** every text style.
- **Buttons:** the batting screen’s lower half (badges, chips, the 2×2 count buttons, the song button idle and playing, their hitter’s song bar, Save, the logo, both team bands).
- **Field drawing:**
  - 6-3 with nobody on;
  - 5-4-3 with a runner on first and our fielders’ names;
  - bases loaded on the batting screen, ours in light and theirs in dark;
  - runner outcomes: a single with the runner from second scoring, the 5-4-3 double play with both runners out, and two runners scoring on a hit (dark);
  - an error by the shortstop, and where a single landed;
  - the largest text size.

## Not done

- **The app icon** waits for Mikey’s full-size logo.
- **The newspaper box score picture** belongs to the box score printer. The fonts and colors it needs are here (`newspaper*`, `TeamLogo.image`), and the approved layout is the end-of-game screen in the mockups.

## Vocabulary requests

None.

## For the wiring job and screen builders

- The logo is bundled as `Resources/diamond-dogs-logo-150.jpg`, the 150-pixel version from Dropbox. When Mikey supplies the full-size logo, replace the file under the same name and nothing else changes.
- On the batting screen use `FieldDrawing(onTap:).zoom(.infield).battingTeam(look).baseRunners(...)`. In the in-play steps use the whole field with `tapSequence`, and `fielderNames` when we are in the field. On the runners step add `runnerMarkers` from the suggested `RunnerMove`s.

## Evidence

- `xcodebuild -scheme ScorebookUI-Package -destination 'platform=iOS Simulator,name=iPhone 17' build` in `app/Packages/ScorebookUI`: succeeded with no warnings.
- `xcodebuild -project Scorebook.xcodeproj -scheme Scorebook -destination 'platform=iOS Simulator,name=iPhone 17' build` in `app`: succeeded.
- The views were rendered to pictures on the iPhone 17 simulator and checked by eye in light, dark and the largest text size: the field drawing’s 6-3, 5-4-3, bases loaded, runner outcomes, error and hit location, and the buttons. The rendering harness was a throwaway package outside the repository; the same views are the previews in each file.
