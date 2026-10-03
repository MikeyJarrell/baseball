# Scorebook mockups

Clickable mockups of every screen in the scorebook app, in one file: [index.html](index.html). Open it in any browser. On a computer it shows an iPhone-sized frame, with the screen index on the left and notes about the current screen on the right. On a phone it fills the screen, and the dark bar at the top opens the index and counts taps.

Our team is the Diamond Dogs (San Diego Adult Baseball League, 18A), playing the made-up Mudcats; the players are made up too. The taps behave like the real app: Ball changes the count, In play walks through the play, Save moves to the next batter, Undo takes it back. The baseball arithmetic inside the mockup is a rough stand-in; the rules engine does the real work in the app. Rule numbers refer to the league rule book summarized in `notes/league-rules.md`.

## Look

The Diamond Dogs logo (the chihuahua) sits on home, the team page and the end-of-game box score. Our color comes from the logo: powder blue with black text, which stays readable in sun, with black player-number badges and tan as an accent. Their hitters get striped slate with white text, so the two teams look different at a glance, in color and in pattern.

Our blue is #62B4E3 with near-black (#2C2B2A) words on it, sampled from the original logo artwork, the same blue as the approved app icon. It replaced the slightly brighter #3BB6E6 with black words that the mockup showed when Mikey approved it.

The app icon is the dog on the logo’s powder blue, with a near-black version for dark mode; the artwork and a cleaned 1024-pixel logo are in [icon/](icon/).

## Walkthroughs

The index lists nine scripted walkthroughs. Each one starts from the right situation, outlines the next tap in yellow, and counts the taps.

| Walkthrough | Taps |
|---|---|
| Four pitches and a 6-3 | 8 |
| Fly out to center, runner on 2nd | 5 |
| Single, runner on 2nd scores (including tapping where it landed) | 6 |
| Single, batter takes 2nd on the left fielder’s error (1B 7, E7) | 8 |
| 5-4-3 double play, runner on 1st | 8 |
| Error by the shortstop, batter to 2nd | 6 |
| Dropped third strike, batter safe | 4 |
| Designated non-runner walks, and the player who made the last out runs | 3 |
| Third out, changeover, defense check, our pitcher’s warm-up song | 6 |

Four pitches and a 6-3 is Ball, Strike, Foul, In play, Batter out, 6, 3, Save.

## The screens

**Home.** The logo, the game in progress with a resume button, then buttons with words only: new game, teams, songs, season stats, games and the last box score.

**Teams and songs.** The teams list (our team on top, saved opponents below); the Diamond Dogs roster, with what each player does today (a position, bats only, or bench), their songs and introduction status; a player page with the walk-up song, a pitcher warm-up song, the announcer script, a record button and a test that plays the introduction and then the song; the recording sheet; the song library, showing who uses each song as a walk-up or warm-up; a song’s page, where tapping the waveform sets the start point, with nudge buttons, volume and fade length; and the song picker.

**Pregame, five steps.**

- The game: opponent, date, home or away, innings (nine), the scheduled start (9:00 AM) and the time limit as a clock time (12:00 PM, three hours later), both editable.
- Our lineup, as three lists, because hitters can skip the field and fielders can skip batting. The batting order takes any number of hitters, drags to reorder, adds from anyone not batting, and has a minus button to take someone out of it, plus the non-runner switch (two at most, shown as “1 of 2”). The fielders are the nine positions, each filled from anyone on the roster; the pitcher can field without batting. Everyone else is on the bench.
- Their lineup: names and numbers, numbers only, or unknown with a count of hitters.
- Starting pitchers: ours lists the roster with whoever pitched most recently first; theirs comes from their saved roster, plus someone new.
- Review and “Play ball”, which opens the defense check because we take the field first. The first pitch resets the time limit to three hours after that pitch (rule 9.1 G).

**Batting screen,** shown for our hitter with a song, our hitter without one, and their hitter known only by number. The band at the top holds the time limit as a clock time with the time left (tap it to match the umpire, who keeps official time), the inning, score, a large count and the outs, and a Box score button that opens the game so far. The field drawing below shows the runners (tap one for steals, wild pitches and the rest), the on-deck hitter and the pitcher with pitches and strikes. Then the batter with what they have done today and a large Subs button beside them, a chip row led by Undo, a 2×2 block of Ball, Strike, Foul and In play, and the song button across the full bottom edge.

The song button plays the announcer introduction, if there is one, then 12 seconds of song, then fades by itself, with a countdown on the button; a tap stops it early. Their hitters get an empty gray bar where the song button would be, so a habit tap plays nothing. Each count button says what it will do (“makes it 2–1”, “walk”, “strikeout”). After strike three, a “Dropped 3rd strike” chip stays up until the next pitch. After the third out, a banner shows the half-inning and score; when we take the field, the song spot plays our pitcher’s warm-up song, and when they take the field it stays our next hitter’s walk-up song.

**Time limit and mercy rule.** When the time limit passes mid-inning, a red banner says to finish the inning. When that inning ends (or the top half, with us at home and ahead), or a 12-run lead after seven innings (six and a half with the home team ahead) triggers the mercy rule, a pop-up asks “Is the game over?” with End game and Keep playing. The app never ends a game by itself. Keep playing closes the pop-up for good for that reason, and the clock then reads “Past the limit.”

**The in-play sequence.** “What happened to the batter?” (batter out, the four hits, reached on error, fielder’s choice with the batter safe and a runner out, and “more” for sacrifices, dropped third strike and catcher’s interference); the fielders, tapped on the field drawing with the notation and the throws drawn as you go; where a hit landed (optional); the fielder who made an error; the dropped-third-strike choice; and the runners step, with every runner’s suggested base, arrows, a row of base buttons per runner, the outs and runs on the play, runs batted in, and an “inning over” warning at three outs. On a hit, a runner moved past where the hit alone carries them gets a question: on the throw, or on an error, and whose. A single plus the left fielder’s error reads 1B 7, E7.

**Changes.** The changes menu (pitcher, fielders, pinch hitter, pinch runner, runner for a designated non-runner, add a hitter), and sheets for each. Every rule-based list is a suggestion, never a block:

- The non-runner prompt opens when a designated non-runner reaches base. It suggests the last recorded out (rule 9.11); if that player is batting, the last out before them; in the first inning before any out, the last batter on the lineup card. It also offers “Sullivan runs,” “Pinch runner instead” (Sullivan then leaves the batting order), and “Someone else,” and can be put off with Later.
- The pinch hitter sheet lists, under “Can re-enter,” starters whose substitute has batted, in their original spot (rule 9.9), then the bench, then “Someone else.”
- The defense check can wait (Later), and an unanswered extra-base question saves as “on the throw.”

Also: adding a hitter (with where they bat and how soon they are up), runner actions, the time limit, the game menu (including the walk-up song length), and naming their hitter.

**Game and season.** The game overview, a swipe left from the batting screen: line score, box so far with each plate appearance in scorebook notation, pitchers, and play-by-play with any play open to fixing. The end of game, with the newspaper-style box score picture headed “Diamond Dogs” and a button to text it. Season stats, sortable, with the names pinned while the numbers scroll sideways. The games list.

Light and dark mode follow the phone’s setting; the index has a switch to compare them. Layout B, the rejected batting screen, stays at the bottom of the index for reference.

## What Mikey decides

1. **Called strike as its own button?** A small “Called” button on the Strike button records a called strike in one tap. The plan described a switch that defaults to swinging, which makes a called strike two taps.
2. **Runners as a row of buttons?** On the runners step, each runner gets a row with every possible base, so any outcome is one tap. The plan described tapping a runner on the drawing to cycle through the bases.
3. **Extra base for runners already on base.** When the batter goes further than the hit, the app asks how. When a runner already on base goes further (Diaz scoring from 2nd on a single), the answer starts as “on the hit” so the common play costs no extra tap, and “on an error” is one tap away. The other option is to ask every time.
