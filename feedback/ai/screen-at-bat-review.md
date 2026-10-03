# Batting screen review

**Reviewer:** a fresh Claude session that did not build the screen.

**Reviewed:** `git diff origin/main...HEAD` on `codex/screen-at-bat` (commit 1f609c4), the brief, the handoff, the approved mockup and all nine screenshots. ScorebookUI builds for the iPhone 17 simulator with no warnings.

**Verdict:** Close to the mockup and safe to wire; two gaps could record the wrong thing and need Mikey’s call (findings 1 and 2), the rest are small.

## Findings, worst first

1. **HBP and IBB vanish for the next batter after a strikeout.** `AtBatControls.swift:129–146`. After strike three, the amber “Dropped 3rd strike” chip replaces HBP, IBB and Foul tip until the next event, while the screen already shows the next batter at 0–0. If that batter is hit by the first pitch or walked intentionally, there is no button for it; the scorer has to go through the menu’s manual adjustment, or taps Ball and records the wrong thing. The mockup does the same, so this is a design question for Mikey. Fix: keep HBP and IBB, and let the amber chip take only Foul tip’s place.

2. **No way to record a foul bunt, and Foul says “stays 3–2” for one.** `AtBatControls.swift:209–215`, `AtBatWording.swift:197–200`. The model has a foul bunt pitch (strike three with two strikes), but the screen offers no button for it. With two strikes, a scorer who taps Foul on a bunt keeps the batter alive when he struck out. The brief does not list it, so this is also Mikey’s call. Fix: a “Foul bunt” choice, for example a long press on Foul or a chip.

3. **Undo is one stray tap from losing a whole play, and its label shrinks first.** `AtBatControls.swift:120–127`. Undo sits right above Ball with no redo, so a slip after a long in-play sequence throws the play away. At the largest text size, “Undo: ball” becomes the smallest words on screen (`largest.png`), which defeats the point of the label. Fix: stop that chip shrinking below caption size; for wiring, a short “Undone: … · Redo” notice.

4. **Count hints worked out on the screen: an acceptable stopgap.** `AtBatWording.swift:187–200`, plus the “first pitch” test `count == .fresh` at `AtBatScreen.swift:305`. They are labels only, the rules engine records the real count, the league uses the standard four balls and three strikes, and the handoff already asks for `countAfter`. Keep for now; wiring should swap them for the engine’s answer. Finding 2 shows the risk: the hint rules already miss a case.

5. **“Time’s up” hides the changeover banner and its Defense button.** `AtBatField.swift:61–88`. When the limit passes in the top half and we take the field, the red banner wins and the Defense button disappears. Fix: show the Defense button on the red banner too.

6. **Play asks for an introduction the player does not have.** `AtBatControls.swift:315` sends `withIntroduction: settings.playIntroductions` while the label (line 312) says “12 seconds, then fades”. Fix: send `withIntro`.

7. **Largest text shortens our team to “DO…”** on the scoreboard (`AtBatBand.swift:150–153`, `largest.png`). Everything else on the “always visible” list fits on the iPhone 17e at the largest size. The batter’s “Today” line (`AtBatControls.swift:57–65`) was never tried with five or more plate appearances. Fix: keep short names whole; preview a long history.

8. **Every preview and screenshot says “Undo: ball”**, even right after strike three (`AtBatPreviews.swift:18`). Harmless in code, misleading as evidence. Fix: pass a matching label per sample.

9. **VoiceOver labels are complete and plainly worded**, but nobody has tried them with VoiceOver on.

Scope and comments: nothing outside `Sources/AtBatScreen/` and the handoff changed; comments are clear for a beginner.
