# In-play sequence

**Role:** screen builder.

**Waits on:** foundation; Mikey’s approval of the in-play mockup. Needs Xcode.

**Owns:** `ScorebookUI/Sources/PlayEntry/`.

**Reads:** `Model/`, `SampleData/`, `DesignSystem/` (including the field drawing), the approved mockup in `plan/mockups/`.

## Deliver

The sequence that opens when the scorer taps “in play,” ending in one ball-in-play event or a cancel that records nothing. It is handed the situation and two functions from the rules engine: one that returns the suggested runner outcomes and runs batted in for whatever the scorer has picked so far, and one that previews the play in progress (its notation, the outs and runs it would produce, whether it ends the inning). The screen shows what those functions return and does no baseball arithmetic itself. Until wiring, it uses the stand-in rules engine in `SampleData`. It hands back the finished play.

**Step one, what happened to the batter:** the screen is titled that way, and the choices say so: batter out, single, double, triple, home run, reached on error, fielder’s choice (batter safe, someone else out), and “more” for sacrifice fly, sacrifice bunt, dropped third strike and catcher’s interference.

**Step two, the fielders:**

- Out: pick the kind of batted ball (ground ball, fly ball, line drive, pop-up, bunt), with double play and triple play as one-tap options alongside, then tap fielders on the field drawing in the order they handled the ball. The notation builds as they tap (“6”, then “6-3”). One tap for a fly out (“F8”). A tapped fielder can be untapped.
- Hit: tap where the ball landed on the field drawing, or skip.
- Error: tap the fielder who made it.
- Fielder’s choice: tap the fielders in order.

**Step three, the runners:** the field drawing shows each runner, batter included, at the base the rules engine suggests, with an arrow from where they started. Tapping a runner cycles them through the possible outcomes (each base ahead of where they started, scored, out). The outs and runs this play would produce show at the top, and if it reaches three outs, the screen says the inning is over. A run-batted-in count shows, and can be changed. When the scorer moves a runner, batter included, further than the play carried them, the screen asks how: on the throw, or on an error (tap the fielder). A single with the batter taking second on a bad throw from left is entered as single, then batter to second on an error by the left fielder, and reads “1B 7, E7.”

**Save.** One tap. Back steps anywhere along the way.

**Dropped third strike.** The same sequence, started from the batting screen after strike three, with the batter’s result fixed as a strikeout: the scorer taps the fielders if the batter was thrown out (2-3) or marks the batter safe, then confirms the runners.

Common plays must stay short: a 6-3 with nobody on is out, ground ball, 6, 3, save. A single with nobody on is single, skip, save. When the suggested runner outcomes need no change, step three is a glance and a save.

## Finish line

Previews and working demos in the simulator, using the stand-in rules engine, for: 6-3 with nobody on; F8 with a runner on second; single with runners on first and second, where the scorer moves the runner from second home; 5-4-3 double play with a runner on first; an error by the shortstop with the batter reaching second; a fielder’s choice with the lead runner out at second; a sacrifice fly. Tap counts for each written in the handoff note.
