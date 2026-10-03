# Design and mockups

**Role:** designer.

**Waits on:** nothing for the mockups. The `DesignSystem/` code waits on the foundation job.

**Owns:** `plan/mockups/`, `ScorebookUI/Sources/DesignSystem/`, and the app icon artwork (handed to the lead builder to install).

## Deliver

1. **Clickable mockups** of every screen at iPhone size, as a single web page Mikey can open on his phone and tap through: team and roster, song library, pregame setup, the batting screen for our hitter and for theirs, the in-play sequence for a 6-3 groundout, a fly out to center, a single with a runner on second, a 5-4-3 double play and an error, the runner confirmation step, a pitching change, adding a hitter to the bottom of the order, the game-so-far screen, the end-of-game screen and season stats. Publish it as a private web page and give Mikey the link. Save the source in `plan/mockups/`.
2. **The batting screen and in-play sequence first.** These two get approved by Mikey before anything else, and before their builders start. Offer two different layouts for the batting screen.
3. **Design system code** in `DesignSystem/`, filling in the names the foundation job stubbed: colors (including a team color for us and a neutral one for them), text styles, spacing, button styles for the big count buttons, and light and dark mode.
4. **The field drawing,** filling in the interface the foundation job stubbed, as a reusable SwiftUI component: a diamond with the nine fielding positions as tappable spots, bases that light up when occupied, and a way to show a numbered sequence of taps (6, then 3). Used by the batting screen, the in-play sequence and the game overview, at different sizes. Drawn in code, so it is sharp at any size.
5. **The newspaper look** for the box score picture: typeface, rules, layout, sized to read well as a picture in a text message. Use fonts that come with iOS throughout the app, so nothing needs adding to a locked package file.
6. **App icon.**

## Design goals

- Built for one thumb, outdoors, in sun, often in a hurry. Big tap targets for the four count buttons, high contrast, and nothing that needs precise aim.
- The most common actions take one tap: ball, strike, foul, play the song, undo.
- The current situation is always visible without scrolling: inning, score, outs, count, runners, batter, pitcher and pitch count.
- Our hitters and theirs look different at a glance, so nobody plays a walk-up song for the other team.
- The song button sits where the person holding the phone can hit it without looking.

## Finish line

Mikey has approved the mockups. The design system and field drawing compile, have previews in light and dark mode, and the field drawing’s previews show a 6-3, a 5-4-3 and bases loaded.

## Watch out for

Mockups that look good but take three taps where one would do. Count the taps for a full plate appearance (four pitches and a 6-3) and put the number on the mockup.
