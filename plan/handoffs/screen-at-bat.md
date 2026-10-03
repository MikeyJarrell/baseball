# Batting screen: handoff

**Job:** screen builder, the batting screen.

**Branch:** `codex/screen-at-bat`, in the task folder `/Users/mikey/projects/.worktrees/baseball/screen-at-bat`.

**Owns:** `app/Packages/ScorebookUI/Sources/AtBatScreen/`. Nothing outside it changed except this note and its screenshots.

## What exists now

Layout A from the approved mockup, the field view, with Mikey’s later changes: the bigger Subs button beside the batter, the Box score button, the empty gray bar for their hitters, the 12-second song countdown, the “Is the game over?” pop-up, the time limit in the band, and the warm-up song at the changeover when we take the field.

Top to bottom, all on one screen with no scrolling:

- **The band**, in the batting team’s color (our powder blue, their striped slate): the game menu, “Diamond Dogs batting”, the time limit as a clock time with the time left (“Limit 12:05 PM · 1:48 left”, “Past the limit (12:05 PM)”, or just the limit before the first pitch; tapping it asks to open the time limit), and the Box score button. Under them the scoreboard: inning with ▲ or ▼, both scores with ▸ by the team at bat, a big count, and the outs as dots.
- **The field drawing**, zoomed to the infield, with a name tag on every runner. Tapping a runner, or a base with a runner on it, asks for the runner actions. The on-deck hitter sits in the bottom-left corner; the pitcher (“Pitching: Collins (R) · 61 pitches, 38 strikes”) in the bottom-right, and tapping it asks for the pitching change.
- **Banners** above the field: “Time’s up — finish this inning” in red while the clock says this is the last inning; otherwise, between half-innings, “Middle 3rd” or “End 3rd” with the score, our team first. Either banner carries the Defense button when our defense check is due at a changeover. The banner sits above the drawing and pushes it down, so a runner on second stays visible.
- **The batter**: number badge, name, “Non-runner” tag for a designated non-runner, “Bats L · Today: 4-3, 1B 7”. On a long day the line keeps the latest plate appearances (“… HR 9, K”). Their hitter known only by number shows “#5 Add name”. Tapping the batter asks for the batter options (pinch hitter, batting side, naming their hitter). The big Subs button sits beside it.
- **Redo**, only right after an undo, when the app hands the screen a redo label: a bar above the batter, “Undone: 6-3” with a Redo button.
- **The chip row**: “Undo: ball” (gray and disabled when there is nothing to undo), HBP, IBB, Foul tip. Right after strike three, an amber “Dropped K” chip takes Foul tip’s place until the next event; HBP and IBB stay, since the next batter is already up (the coordinator’s decision after review). Undo’s words wrap onto two lines rather than shrink; at large text sizes Undo takes a row of its own.
- **Ball, Strike, Foul, In play** in a 2×2 block, each saying what it will do (“makes it 2–1”, “walk”, “strikeout”, “out, hit, error…”). Strike records a swinging strike; the small Called button inside it records a called strike. Holding Foul down records a foul bunt, which is strike three with two strikes; with two strikes, Foul’s line reads “stays 2–2 · hold for bunt”, and VoiceOver offers a “Foul bunt” action. The phone buzzes once for a foul bunt, and lifting the finger afterward records nothing more.
- **The song spot** along the bottom edge:
  - our hitter with a song: the title and “Introduction, then 12 seconds of song” when the player has an introduction and introductions are switched on, else “12 seconds, then fades”; play asks for the introduction on the same terms; while playing, a stop icon, “Introduction · song next” with a microphone, then a seconds countdown with a shrinking bar; a tap stops it;
  - our hitter without a song: a gray bar, “No song for Fisk · Tap to pick one”;
  - our pitcher at the changeover when we take the field: the purple warm-up button (“Warm-up for Barros, our pitcher”; “Playing · stops on the first pitch”), or a gray “No warm-up song” bar;
  - their hitter: an empty gray bar, so a habit tap plays nothing.
- **The game menu** (top left): Manual adjustment, Error with nobody moving, Time limit, Edit this batter, Walk-up song length, and End game, which asks for the reason (innings complete, time limit, run rule, rain or darkness) and records the end with the final score.
- **“Is the game over?”** opens by itself when the situation carries a game-over question, or when the clock says to ask on time and the scorer has not already said to keep playing. It shows the score, why it is asking with the rule number, and “The umpire makes the call; the app only asks.” End game and Keep playing are the only ways out. It closes the moment either is tapped, and comes back if an undo brings the question back.
- **A swipe to the left** asks for the box score, as does the Box score button; VoiceOver users get a “Box score” action too.

## How the screen talks to the rest

```swift
AtBatScreen(
    setup: GameSetup,
    situation: Situation,
    batterHistory: [PlateAppearanceSummary],   // stats: plateAppearances(of:in:)
    songs: SongLibrary,                        // for song titles
    settings: AppSettings,                     // song length, introductions, fade on first pitch
    songPlayback: SongPlayback,                // .idle, .introduction, .song(endsAt:), .warmUp
    undoLabel: String?,                        // "ball"; nil when there is nothing to undo
    redoLabel: String?,                        // "6-3" right after an undo; nil hides Redo
    clock: (Date) -> GameClock,                // rulesEngine.clock(for: situation, at:)
    onAction: (AtBatAction) -> Void
)
```

The screen asks the clock again every 15 seconds, so the time left and the time-limit question keep up between events. It holds no game state; its only memory is whether the menu is open and which game-over answer was just tapped.

Every tap comes back as one `AtBatAction`:

- `.record(GameEvent)`: a pitch (ball, called strike, swinging strike, foul, foul bunt, foul tip, hit by pitch), an intentional walk, `keepPlaying`, or `endOfGame` with the final score.
- `.undo`, `.redo`.
- `.openInPlay(.ballInPlay)` from In play, `.openInPlay(.droppedThirdStrike)` from the dropped-third-strike chip.
- `.openRunnerActions(PlayerID)`, `.openPitchingChange`, `.openBatterOptions`, `.openSubstitutions`, `.openBoxScore`, `.openTimeLimit`, `.openDefenseCheck`, `.openManualAdjustment`, `.openErrorWithNoAdvance`, `.openSongSettings`, `.pickSong(for:)`.
- `.playWalkUp(Player, withIntroduction:)`, `.playWarmUp(Player)`, `.stopSong`, `.fadeOutSong`.

## For the wiring job

- **Fading on the first pitch.** When a pitch, intentional walk or In play is tapped, the screen sends `.fadeOutSong` before the pitch itself if the warm-up song is playing, or if a walk-up song is playing, “fade on the first pitch” is on, and the count is 0–0. Wiring only has to call `fadeOut()` on the audio player.
- **`songPlayback`.** Wiring has to tell the screen when the introduction ends and the song starts, and when the song will fade: `.song(endsAt:)` is the moment the song started plus `walkUpLength` (or the song’s own play length). The audio player has no property for either; see the requests below.
- **The dropped third strike**: on `.openInPlay(.droppedThirdStrike)`, open the in-play sequence in that context; its finished play replaces the strike-three pitch (as the foundation handoff says).
- **The non-runner prompt** (`Situation.runnerChoice`), the defense check opening by itself at the start of our half-inning, and the automatic out at a batting hole are wiring’s to open or record from the situation; the screen shows nothing for them beyond the Defense button on the changeover banner and the Non-runner tag.
- **Undo labels.** The previews use the label the app would most likely show (“Undo: strikeout” right after strike three, “Undo: pitching change” after one). Wiring supplies the real one, and the redo label right after an undo, cleared by the next event.
- **The game menu’s End game** records the end straight away after the scorer picks a reason; it does not ask a second time.
- **Runner actions** are asked for by runner. The runner-actions sheet decides whether a wild pitch or balk moves everyone.

## Owner decision needed

The brief describes called-or-swinging as a small toggle beside Strike, defaulting to swinging, which makes a called strike two taps. The approved mockup puts a small Called button inside the Strike button, which makes it one tap, and its README lists this as Mikey’s open decision 1. The screen follows the mockup. Switching to the toggle is a small change in `CountButtons` in `AtBatControls.swift`.

## Vocabulary requests

1. **What a pitch would make the count.** The words under the count buttons (“makes it 2–1”, “walk”, “strikeout”, “stays 3–2”) need the counting rules: four balls walk, three strikes strike out, a foul with two strikes leaves the count alone. The screen works them out itself, as labels only, in `AtBatWording.ballHint`, `strikeHint` and `foulHint`. The rules engine should provide them (for example `RulesEngine.countAfter(_ pitch: PitchResult, in: Situation)`), so the counting rules live in one place; the screen would then take the hints as input.
2. **Walk-up playback state on the audio player.** `WalkUpAudioPlayer` has `isPlaying` and `nowPlaying`, but not whether the introduction or the song is playing, nor when the song will fade. Suggested: `var phase: SongPlayback`-like state (introduction, song ending at a time, warm-up). Until then wiring builds `SongPlayback` itself.
3. **Short team names.** The lead builder is adding a short name to `Team` in the vocabulary pass. Until it lands, the scoreboard makes its own (“DOGS”, “MUD”, “BOM”: the last word if it has four letters or fewer, else its first three) in `AtBatWording.shortTeamName`, and shows it whole at every text size; switching to the real one is a one-line change there.

## Left out or stubbed

- The sheets the screen asks for (runner actions, pitching change, substitutions, batter options, time limit, defense check, manual adjustment, song picker) belong to the other screen builders; the screen only asks for them.
- ScorebookUI has no test target, so the wording functions (ordinals, the time-left text, the count hints, short team names) are checked only through the previews and screenshots. They are plain functions in `AtBatWording.swift`, ready for tests when the lead builder adds a target.
- VoiceOver: every control is a button with a spoken label and, where useful, a hint (the scoreboard reads as one sentence: “Bottom of the 4th. Mudcats 3, Diamond Dogs 2. 3 balls, 2 strikes. 2 outs.”). Checked by reading the code and the simulator’s rendering; nobody has yet tried it with VoiceOver switched on.

## Evidence

- `xcodebuild -scheme ScorebookUI-Package -destination 'platform=iOS Simulator,name=iPhone 17' build` in `app/Packages/ScorebookUI`: succeeded with no warnings.
- **Previews** in `AtBatPreviews.swift`, each with a realistic undo label: every situation in `SampleSituations.all`; a long day of six plate appearances; Redo after an undo; our hitter with a song (idle, introduction, counting down); our hitter without one; their hitter known only by number; the warm-up song idle and playing; “Is the game over?”; dark mode; the largest text size. Each preview shows what a tap handed back.
- **Taps, counted on the iPhone 17e simulator** (the smallest current iPhone, 390 by 844 points), in a throwaway harness app outside the repository: Ball, Strike, Called, Foul, then In play. Each pitch is one tap and opening the in-play sequence is one more, so four pitches and opening the in-play sequence is 5 taps (Ball, Strike, Foul, In play is 4, as in the mockup). Every one of them is in the bottom half of the screen, within a thumb’s reach. The game menu opened from its button.
- **Screenshots** in `plan/handoffs/screen-at-bat/`, from the iPhone 17e unless named otherwise:
  - `ours-song.png`: our hitter with a song, bases loaded, full count, Foul reading “stays 3–2 · hold for bunt”;
  - `longday.png`: six plate appearances on the batter’s line;
  - `redo.png`: right after an undo, with Redo;
  - `timeup-changeover.png`: time’s up at a changeover, with the Defense button on the red banner;
  - `songplaying-dark.png`: the same, dark mode, the song counting down;
  - `theirs.png`: their hitter known only by number, before the first pitch, with the empty gray bar;
  - `after-strike-three.png`: “Undo: strikeout”, HBP, IBB and “Dropped K”;
  - `warmup.png`: the changeover when we take the field, with the Defense button and the warm-up song;
  - `timeup.png`: time’s up, last inning, with the runner on second visible below the banner;
  - `question.png`: “Is the game over?”;
  - `largest.png`: the largest text size right after strike three, Undo on its own row and “DOGS” whole;
  - `iphone17-dark.png`: the iPhone 17 in dark mode.
- **Foul bunt, tried on the simulator:** a tap on Foul, then a one-second hold, recorded a foul and then a foul bunt, two events and no extra foul.
- **Review:** `feedback/ai/screen-at-bat-review.md`. Every finding is addressed: HBP and IBB stay after strike three, the foul bunt, Undo’s words and Redo, the Defense button on the red banner, the introduction only when the player has one, whole team names, the long day, and realistic undo labels. The count hints stay as a stopgap until the rules engine provides them (request 1).
- Things found and fixed by looking at the screenshots: the scoreboard stretching to fill the screen; the play icon disappearing on the song button in dark mode; the Strike words running under the Called button at large text sizes; the time-limit banner hiding a runner on second.
