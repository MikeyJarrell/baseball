# Batting screen

**Role:** screen builder.

**Waits on:** foundation; Mikey’s approval of the batting screen mockup. Needs Xcode.

**Owns:** `ScorebookUI/Sources/AtBatScreen/`.

**Reads:** `Model/`, `SampleData/`, `DesignSystem/` (including the field drawing), the approved mockup in `plan/mockups/`.

## Deliver

Mikey chose layout A, the field view, in the approved mockup.


The screen the scorer looks at for nearly the whole game. It takes a situation, the batter’s plate appearances earlier in the game, the on-deck hitter, and the batter’s song if the batter is ours with one assigned, and hands back what was tapped.

**Always visible, no scrolling:** inning and half, both teams’ scores, outs, balls and strikes, runners on the field drawing, batter (name, number, batting side, earlier today in scorebook notation), on-deck hitter, current pitcher (name, throwing hand, pitches and strikes so far).

**Big buttons:** ball, strike, foul, in play. Strike asks nothing more; called or swinging is a small toggle beside it, defaulting to swinging.

**One tap away:** undo (with what it will undo shown, “Undo: ball”), hit by pitch, intentional walk, foul tip, the song button. After strike three, a “dropped third strike” button stays up until the next pitch, and opens that version of the in-play sequence.

**Tapping things on screen:**

- A runner on the field drawing opens the runner actions (steal, caught stealing, pickoff, wild pitch, passed ball, balk, advance on error), handled by the in-game changes builder’s sheet.
- The pitcher opens the pitching change.
- The batter opens pinch-hit and batting-side options.
- One large, clearly labeled substitution button opens every kind of change (see the in-game changes brief).
- A “Box score” button opens the game overview; a swipe does the same.
- A menu holds the rest: manual adjustment, end game.

**Game clock.** The time limit and time left show beside the inning. When the limit passes, a banner says to finish the inning; when the time limit or the mercy rule says the game could be over, a pop-up asks “Is the game over?” with End game and Keep playing; Keep playing carries on and is not asked again for the same reason.

**The song button** shows only for our hitters with a song assigned. It shows the song name, and toggles between play and stop; play runs the announcer introduction first when the player has one. When our team takes the field, the same spot holds the pitcher’s warm-up music button. The song fades out by itself after 12 seconds of song (the length is a setting), with a small countdown on the button; tapping stops it early. A second setting, off by default, also fades it when the first pitch is recorded. For their hitters, the same spot is an empty gray bar.

**Changeovers.** After a third out, the screen shows a short banner (“Middle 3rd — Cardinals 4, Mudcats 2”) and the next team’s batter.

## Finish line

Previews for every situation in `SampleData`, for our hitter with a song, our hitter without one, and their hitter known only by number. One full plate appearance (four pitches and opening the in-play sequence) works one-handed on the smallest current iPhone screen in the simulator. Every button can be reached with VoiceOver, Apple’s screen reader.
