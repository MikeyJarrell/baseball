# Standing orders for every builder

Read this, then [architecture.md](architecture.md), then your brief in [briefs/](briefs/). The plain-English plan is [README.md](README.md).

## Before you start

1. Work in your own Git worktree on a branch named after your brief, for example `game-rules-engine`. Start it with the Claude app’s Worktree option or `project start baseball <brief-name>`, and run `project prepare baseball <folder>` before the first edit.
2. Confirm the jobs your brief waits on have been accepted into `main`. If they have not, stop and say so.
3. Read the `Model/` code itself. Where it differs from the sketch in architecture.md, the code wins.

## While you work

**Stay in your folders.** Your brief lists the folders you own. Edit nothing else. In particular, never edit `Model/`, `SampleData/`, either `Package.swift`, the Xcode project, or another builder’s folder. Adding new files inside your own folders is always fine.

**Need a change to the shared vocabulary?** Do not make it. Work around it with a local type or extension in your own module, and write the request in your handoff note: what you need, why, and the workaround you used. The lead builder decides and makes the change for everyone.

**Comment the code.** Mikey reads it and is a beginner. Every file opens with a short comment saying what it is for. Every type and every function that is not obvious gets a one-line comment saying what it does in baseball terms (“Moves every forced runner up one base”).

**Test what has no screen.** Anything in `ScorebookCore` comes with tests that pass under `swift test` in `app/Packages/ScorebookCore`. Use the scenario files in `Tests/Scenarios/` where they apply.

**Preview what has a screen.** Every screen has SwiftUI previews driven by `SampleData`, covering at least the situations your brief lists, in light and dark mode and at the largest accessibility text size.

**Keep it plain.** Use the names in the design system for colors, type and spacing. No outside code libraries without the lead builder’s approval. No images downloaded from the internet: icons come from Apple’s built-in SF Symbols set, and anything else is drawn in code by the designer.

## Finishing

1. The package builds, and every test passes, including tests you did not write.
2. Write a handoff note at `plan/handoffs/<brief-name>.md`: what you built, what is stubbed or left out, any vocabulary change requests, anything the wiring job needs to know, and the screenshots or test names that show it works.
3. Ask for a review. A fresh reviewer, who did not build the work, reads the brief, the handoff note and the changes, and checks: the brief’s finish line is met, nothing outside the owned folders changed, the code is commented, and the tests test the baseball and not only the code. The reviewer’s notes go in `feedback/ai/`.
4. Mikey accepts with `/done`.

## The reviewer

A reviewer is always a builder who did not do the job. Review against the brief. Report problems in order of how much they would hurt during a game: wrong score or wrong count first, slow or confusing screens second, style last.
