# Scorebook mockups

Clickable mockups of every screen in the scorebook app, in one file: [index.html](index.html). Open it in any browser. On a computer it shows an iPhone-sized frame, with the screen index on the left and notes about the current screen on the right. On a phone it fills the screen, and the dark bar at the top opens the index and counts taps.

The data is made up: our Cardinals (12 players) against the Mudcats. The taps behave like the real app: Ball changes the count, In play walks through the play, Save moves to the next batter, Undo takes it back. The baseball arithmetic inside the mockup is a rough stand-in; the rules engine does the real work in the app.

## Walkthroughs

The index lists eight scripted walkthroughs. Each one starts from the right situation, outlines the next tap in yellow, and counts the taps.

| Walkthrough | Layout A taps | Layout B taps |
|---|---|---|
| Four pitches and a 6-3 | 8 | 7 |
| Fly out to center, runner on 2nd | 5 | 4 |
| Single, runner on 2nd scores (including tapping where it landed) | 6 | 6 |
| 5-4-3 double play, runner on 1st | 8 | 7 |
| Error by the shortstop, batter to 2nd | 6 | 6 |
| Dropped third strike, batter safe | 4 | 4 |
| Designated non-runner walks, and the app asks who runs | 3 | 3 |
| Third out, changeover, defense check, between-innings music | 6 | 5 |

Four pitches and a 6-3 in layout A is Ball, Strike, Foul, In play, Out, 6, 3, Save. In layout B it is Ball, Strike, Foul, Out, 6, 3, Save.

## The screens

**Home.** The game in progress with a resume button, then new game, teams, songs, season stats, games and the last box score. The layout picker at the bottom exists only in the mockup.

**Teams and songs.** The teams list (our team on top, saved opponents below); the Cardinals roster, with each player’s song and introduction status and the non-runner marked; a player page with the song, the announcer script, a record button and a test that plays the introduction and then the song; the recording sheet; the song library, with a second tab for the between-innings playlist; a song’s page, where tapping the waveform sets the start point, with nudge buttons, volume and fade length; and the song picker.

**Pregame, five steps.** The game (opponent, date, home or away, innings with nine as the default, an optional time limit); our lineup, starting from last game’s, with positions and the designated non-runner; their lineup as names and numbers, numbers only, or unknown with a count of hitters; both starting pitchers with throwing hand; review and “Play ball”, which opens the defense check because we take the field first.

**Batting screen, two layouts,** each shown for our hitter with a song, our hitter without one, and their hitter known only by number.

- Layout A, field view. The inning, clock, score, a large count and the outs sit in a band in the batting team’s color. The field drawing below shows the runners (tap one for steals, wild pitches and the rest), the on-deck hitter and the pitcher with pitches and strikes. Then the batter with what he has done today, a chip row led by Undo, a 2×2 block of Ball, Strike, Foul and In play, and the song button across the full bottom edge.
- Layout B, big buttons. The situation shrinks into a TV-style score bug with a small diamond, which leaves room for larger buttons. The batter gets a full-width color block. In play is split into two buttons, Out and Safe or hit, which saves one tap on every ball in play. Undo and the song button take the two bottom corners.

In both, our hitters are red and theirs are striped slate, and their hitters get a gray, dead song spot so a habit tap plays nothing. Each count button says what it will do (“makes it 2–1”, “walk”, “strikeout”). After strike three, a “Dropped 3rd strike” chip stays up until the next pitch. After the third out, a banner shows the half-inning and score, and the song spot becomes the between-innings music button.

**The in-play sequence.** What happened (out, the four hits, error, fielder’s choice, and “more” for sacrifices, dropped third strike and catcher’s interference); the fielders, tapped on the field drawing with the notation and the throws drawn as you go; where a hit landed (optional); the fielder who made an error; the dropped-third-strike choice; and the runners step, with every runner’s suggested base, arrows, a row of base buttons per runner, the outs and runs on the play, runs batted in, and an “inning over” warning at three outs.

**Changes.** The changes menu (pitcher, fielders, pinch hitter, pinch runner, runner for a designated non-runner, add a hitter), and sheets for the pitching change, pinch hitter, pinch runner, the non-runner prompt that opens by itself, adding a hitter (with where he bats and how soon he is up), the defense check, runner actions, the game menu, and naming their hitter.

**Game and season.** The game overview, a swipe left from the batting screen: line score, box so far with each plate appearance in scorebook notation, pitchers, and play-by-play with any play open to fixing. The end of game, with the newspaper-style box score picture and a button to text it. Season stats, sortable, with the names pinned while the numbers scroll sideways. The games list.

Light and dark mode follow the phone’s setting; the index has a switch to compare them.

## What Mikey decides

1. **Layout A or layout B for the batting screen?** A shows the field large and puts the song button along the bottom edge. B gives the count buttons more room, splits In play into Out and Safe or hit (7 taps for four pitches and a 6-3 against A’s 8), and puts the song button in the bottom-right corner. Parts can be mixed, such as A with B’s split In play button.
2. **Called strike as its own button?** Both layouts have a small “Called” button on the Strike button that records a called strike in one tap. The plan described a switch that defaults to swinging, which makes a called strike two taps.
3. **Guess the kind of batted ball?** One outfielder is guessed as a fly ball and a throw as a grounder, so a 6-3 needs no tap for “ground ball.” A line drive or pop-up to an infielder then needs one tap to correct the guess.
4. **Runners as a row of buttons?** On the runners step, each runner gets a row with every possible base, so any outcome is one tap. The plan described tapping a runner on the drawing to cycle through the bases.
5. **Who is offered to run for a designated non-runner?** The prompt lists the bench first, then the player who made the last out, then the rest of the lineup. If the league has a rule for who may run, the list should follow it.
6. **Song spot for their hitters.** A gray bar that does nothing when tapped. The other option is to hide it, which would move the buttons above it between our hitters and theirs.
