# In-play sequence: handoff

**Job:** screen builder, in-play sequence (`plan/briefs/screen-play-entry.md`).

**Branch:** `codex/screen-play-entry`, in the task folder `/Users/mikey/projects/.worktrees/baseball/screen-play-entry`.

**Owns and touched:** `app/Packages/ScorebookUI/Sources/PlayEntry/` only, plus this note and its screenshots in `plan/handoffs/screen-play-entry/`.

## What exists now

The sequence that opens on “In play” (or “Dropped 3rd strike”) and ends in one ball-in-play event, the dropped-third-strike play, or a cancel. It matches the approved mockup, with Mikey’s changes:

- **Step one** is headed “What happened to the batter?”: Batter out, Single, Double, Triple, Home run, Reached on error, Fielder’s choice (“batter safe, runner out”), and More for sacrifice fly, sacrifice bunt, dropped 3rd strike and catcher’s interference.
- **Fielders.** Tap fielders in order on the field drawing; the notation builds as they tap and the throws are drawn. Tapping the last fielder again, or the arrow beside the notation, takes it back. On a batter out, chips for ground, fly, line, pop-up and bunt, with Double play and Triple play beside them. The kind of ball is guessed silently (one tap on an outfielder is a fly ball, anything else a ground ball) and shows as a dashed chip; a tap on another chip replaces the guess. With nobody on, Save is right there; with runners on, the button is Runners.
- **Hit:** tap where it landed (a dot, and “1B 7”), or go straight on. With nobody on, Save and Runners sit side by side.
- **Error:** tap the fielder who made it; Fielding or Throwing is optional.
- **Fielder’s choice, sacrifices, a dropped third strike thrown out:** tap the fielders in order, each with its own hint.
- **Runners.** The infield drawing shows every runner, batter included, at the base the rules engine suggests, with arrows (red and dashed with a cross for an out). Under it, a row of base buttons per runner (1st, 2nd, 3rd, Home, Out, starting from the runner’s own base); a dot marks the rules engine’s guess. Tapping a runner’s tag on the drawing also moves them to their next outcome, as the brief described. The card at the top shows the notation, the outs and runs on the play, “Inning over” at three outs, and the runs batted in with − and +. The bottom bar says the outs after the play, and “Saving switches sides” at three outs.
- **On a hit, a runner moved past where the hit carried them** gets “How did they get there?”: On the throw (for the batter) or On the hit (for a runner already on base), or On an error, then whose (nine fielder buttons). The batter starts with no answer, which saves as on the throw; a runner already on base starts at On the hit, so sending a runner home costs no extra tap. An error answer marks that runner’s move `advancedOnError` and lists the error once in the play’s `errors`, which is how “1B 7, E7” comes about.
- **Dropped third strike:** Thrown out at first (then the fielders: K 2-3) or Batter safe at first (then the runners).
- **Back** on every step; on the first step it closes the sequence like Cancel. **Cancel** records nothing.

The screen does no baseball arithmetic. Notation, outs, runs, runs batted in, “inning over” and where the runners went all come from the two functions it is handed. After every runner change it asks the rules engine again with the scorer’s picks in the draft, takes the engine’s answer for every runner the scorer has not touched, and keeps the scorer’s picks for the rest.

## How the app uses it (for the wiring job)

```swift
PlayEntryView(situation: situation, setup: setup, start: .inPlay,
              rules: PlayEntryRules(engine: rulesEngine)) { outcome in
    switch outcome {
    case .ballInPlay(let event): // record the event
    case .droppedThirdStrike(let play): // replace the strike-three pitch with the same pitch carrying `play`
    case .cancelled: break // nothing to record
    }
}
```

- Show it full screen. It calls `onFinish` once.
- `PlayEntryRules` is the two functions: `suggestRunners` and `preview`. `PlayEntryRules(engine:)` takes them from any `RulesEngine`.
- For `start: .droppedThirdStrike`, hand in the situation from just before the strike-three pitch, so the batter is the one who struck out and the outs do not yet count the strikeout. Choosing “Dropped 3rd strike” under More also comes back as `.droppedThirdStrike(play)`, since that play rides on the pitch too.
- When the runner step is skipped (nobody on), the saved play’s runners are the rules engine’s suggestion and its runs batted in the suggested number.

## Tap counts

Taps inside the sequence, Save included. Add one for the “In play” (or “Dropped 3rd strike”) tap on the batting screen.

| Play | Taps in the sequence | With “In play” | Taps |
|---|---|---|---|
| 6-3 with nobody on | 4 | 5 | Batter out, 6, 3, Save |
| F8 with a runner on second | 4 | 5 | Batter out, 8, Runners, Save |
| Single, runners on first and second, runner from second sent home | 5 | 6 | Single, tap left field, Runners, Home (runner from 2nd), Save; 4 without tapping where it landed |
| 5-4-3 double play, runner on first | 7 | 8 | Batter out, Double play, 5, 4, 3, Runners, Save |
| Error by the shortstop, batter to second | 5 | 6 | Reached on error, 6, Runners, 2nd (batter), Save |
| Fielder’s choice, lead runner out at second | 5 | 6 | Fielder’s choice, 6, 4, Runners, Save |
| Sacrifice fly | 5 | 6 | More, Sacrifice fly, 8, Runners, Save |
| Single, batter to second on the left fielder’s error (1B 7, E7) | 7 | 8 | Single, tap left field, Runners, 2nd (batter), On an error, 7, Save |
| Dropped third strike, batter safe | 2 | 3 | Batter safe at first, Save |
| Dropped third strike, thrown out (K 2-3) | 4 | 5 | Thrown out at first, 2, 3, Save |

A single with nobody on is Single, Save: two taps. These match the mockup’s walkthroughs (F8 5, single scoring the runner 6, 5-4-3 8, E6 6, 1B 7, E7 8).

## Demos and previews

- `PlayEntryDemos.swift` holds each play above as a script of taps, with where it starts and what the finished play should read (notation, outs, runs, runs batted in). `PlayEntryDemoGallery` (public) lists them for the simulator: each row runs its script, shows a check mark when the play comes out as expected, and gives the tap count; tapping a row opens the sequence to enter the play by hand, and the finished play shows below as JSON. All ten pass.
- `Previews.swift` has eighteen previews built from the same scripts: each step of every brief play, the dropped third strike both ways, dark mode, and the largest text size.
- The scripts call the same `PlayEntryModel.perform(_:)` every button calls, which is also what counts the taps.

## The demo rules engine

`DemoRulesEngine.swift` wraps SampleData’s `SampleRulesEngine` for previews and demos only. Two gaps in the stand-in made the demos look broken: its notation is just the fielders joined by dashes (a single shows nothing, an error “6”), and its runner suggestion ignores runners the scorer moved, so runs batted in never change. The wrapper fills in sample-game-style notation (“1B 7”, “E6”, “FC 6-4”, “SF 8”, “5-4-3 DP”, “K 2-3”, “1B 7, E7”, “3U”) and counts runs batted in from the scorer’s moves. The screen itself never uses it; the app hands in the real engine.

**Request to the lead builder:** fold those two fixes into `SampleRulesEngine` so every screen gets them, then delete `DemoRulesEngine.swift` and point `PlayEntryRules.demo` at the stand-in.

## Vocabulary change requests

None needed. Two things the rules engine job should know:

- **The batted-ball guess lives in this screen** (one outfielder tapped is a fly ball, otherwise a ground ball), because the rules engine promise has no function for it. It is a default for a chip, saved with the play only if the scorer leaves it. If the lead builder would rather the engine guess, it needs a function on `RulesEngine`.
- **A runner the scorer marks out who was not suggested out** is saved with no `outBy` unless the rules engine fills it in when asked again (the screen keeps the engine’s `outBy` and `outAt` whenever the engine agrees on where the runner ended up). The approved mockup does not ask who made that out, so the stats engine should expect it to be missing sometimes.

## Not done or not checked

- **No hand taps in the simulator.** Access to drive the simulator by tapping was not granted during this session, so the flows were checked by running each script through the same tap handler the buttons use and by screenshots at every step. Tapping through by hand in the gallery is the first thing for the reviewer to try.
- ScorebookUI has no test target, so the scripts’ checks run in the gallery and previews. When a test target exists, `PlayEntryDemos.all.map { $0.check() }` is a ready test.
- On the shared booted iPhone 17 simulator, another builder’s harness uses the same app id (`com.mikeyjarrell.scorebook`), so a first round of screenshots caught their app. The screenshots here come from a separate simulator. The shared simulator’s appearance and text size were switched for a few seconds during that first round and set back to light and the default size.

## Evidence

- `xcodebuild -scheme ScorebookUI-Package -destination 'platform=iOS Simulator,name=iPhone 17' build` in `app/Packages/ScorebookUI`: succeeded with no warnings.
- The app shell project, with its home screen swapped for the demo gallery, built and ran on an iPhone 17 simulator (a throwaway copy outside the repository). All ten demo scripts pass (`gallery.png`).
- Screenshots in `plan/handoffs/screen-play-entry/`, checked by eye:
  - step one, with More open: `step-one.png`, `step-one-more.png`;
  - 6-3: `63-fielders.png`; F8: `f8-runners.png`;
  - single scoring the runner from second: `single-where.png`, `single-runners.png`; a single with nobody on (Runners and Save side by side): `single-nobody-on.png`;
  - 5-4-3: `dp-fielders.png`, `dp-runners.png`;
  - error by the shortstop: `e6-who.png`, `e6-runners.png`;
  - fielder’s choice: `fc-runners.png`; sacrifice fly: `sf-runners.png`;
  - 1B 7, E7 with the error question: `1b-e7-runners.png`;
  - dropped third strike: `k3.png`, `k3-out.png`;
  - dark mode: `dark-step-one.png`, `dark-dp-runners.png`, `dark-e6-who.png`;
  - largest text size: `big-step-one.png`, `big-dp-fielders.png`, `big-1b-e7-runners.png`, `big-k3.png`.
