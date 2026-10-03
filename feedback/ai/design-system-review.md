# Design system review (commit f8d95a5)

**Reviewer:** a fresh builder who did not do the design job.

**Checked:** the brief’s items 3, 4 and 6, both handoffs, the approved mockup, and the diff. The UI package builds for the iPhone 17 simulator with no warnings; `swift test` in ScorebookCore passes 41 tests.

**Verdict:** accept after fixing findings 1 and 2. Nothing public was removed or renamed, but two stub names now behave differently in ways that hurt during a game.

## Findings, worst first

1. **A strike button built the stub’s way is unreadable.** `Colors.swift:68` turned `strike` from red to amber, and `Buttons.swift:22` still defaults the words to white. `CountButtonStyle(color: ScorebookColor.strike)`, the only form the stub offered, now gives white on amber at a contrast of 2.0 to 1, far below the 4.5 needed in sun. The comment at `Buttons.swift:3–4` says both forms give the same button, which is false for Strike. Any screen writing a strike “S” in `ScorebookColor.strike` on white has the same problem. Fix: default the words to `onStrike` when the fill is `strike`, correct the comment, and name the change in the handoff.

2. **A fly out draws the batter thrown out at first.** For a fly out the batter’s move has no `outAt` (`SampleGame.swift:80`, the sacrifice-fly scenario), so `endBase` (`FieldDrawing.swift:65`) picks first, and the drawing (`:346–353`, `:371`) adds a red path from home to first, a cross at first and the tag there. The mockup puts “out” at home with no path or cross. This is the brief’s fly-out-to-center sequence. Fix: when `outAt` is missing, draw no path or cross and put the tag at the starting base; leave `endBase` alone.

3. **Count buttons lost the stub’s height.** The stub promised at least 88 points; the style now fills its parent with a 64-point floor (`Buttons.swift:37–38`), and `Spacing.countButtonHeight` (84) is never used. Inside a scroll view the buttons drop to 64. Fix: use 84 as the floor, or say in the handoff that the parent must set the height.

4. **`notation` gives letters different widths** (`Typography.swift:38`): it fixes the width of digits only, so “BCFB” and “F8” do not line up in columns. Tell the box score printer and the game-overview builder, or keep a fixed-width style under its own name.

5. **Runner step bases stay dark.** Bases light only from `occupiedBases` and `baseRunners` (`FieldDrawing.swift:237`); the mockup also lights the base where each marker ends. Light those bases from `runnerMarkers`, or tell the in-play builder to pass them.

6. **Lit and empty bases are close in light mode:** our blue against white is 2.3 to 1, neutral amber against white about 2 to 1, and the black outline does most of the work. Thicker outline or a darker lit fill would help in sun.

7. **Taps off the field** (`FieldDrawing.swift:225–229`) give hit spots outside 0 to 1 (behind home, past the fence), and the batting screen’s infield view sends a spot for every tap on the grass. Limit spots to fair and foul ground, and say in the handoff that the batting screen should ignore `.spot`.

8. **Field text does not follow the phone’s text size.** Tag, number and name sizes are fixed (`:286`, `:304`, `:373`), so the largest-text preview looks the same as the ordinary one. Acceptable for a drawing, but the handoff should say so.

9. **The approved mockup’s colors changed after approval** (`plan/mockups/index.html:28, 42, 55, 151`). In scope, and taken from Mikey’s logo, but Mikey approved #3BB6E6 with black words and will see #62B4E3 with #2C2B2A words.

10. **App icon: correct.** Both files are 1024 by 1024, RGB, no transparency, and the `Contents.json` matches the iOS 18 single-size format with a dark entry. Optional: Apple suggests a transparent background for the dark icon so the system can draw its own dark backdrop. With no tinted icon, iOS makes one itself.

11. **Scope and comments: fine.** Every file is under `DesignSystem/` or `plan/`, and the comments read well for a beginner. A few terms are left unexplained (“modifier-style methods,” “inner shadow,” `Mapper`). The field drawing’s baseball logic (`endBase`, `nearestPosition`) has no tests; finding 2 would have shown up in one.
