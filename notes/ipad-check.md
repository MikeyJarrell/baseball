# iPad check

**Date:** October 3, 2026

The app has been set to install on iPads since the foundation job. This check ran the two finished screens, the batting screen and the in-game change sheets, on the 13-inch iPad Pro and the iPad mini simulators, upright and sideways.

## What was found

- **Upright, both iPads:** everything fits and works. The in-game change sheets open as cards in the middle of the screen, the iPad’s usual way, and read well.
- **Runner name tags on the big iPad:** the tags grew with the field drawing, so on the 13-inch iPad a runner’s name was the size of a headline and crowded the bases. They now stop growing at about one and a half times their iPhone size. The iPhone is unchanged.
- **Sideways:** on the iPad mini, with a changeover banner showing, the field shrank to a strip a few inches wide, too small to tap a runner. The batting screen now puts the field on the left and the batter and buttons on the right whenever the screen is noticeably wider than it is tall, with the buttons at the bottom of their column, in thumb reach.

Locking the iPad upright, as the iPhone is, would only work for a while: Apple is phasing out the setting that lets an iPad app refuse to turn or to run in a resizable window ([Apple’s developer forum](https://developer.apple.com/forums/thread/793406)). So every screen has to cope with a wide, short window as well as a tall one.

## Screenshots

[ipad-pro-upright.png](ipad-check/ipad-pro-upright.png), [ipad-mini-upright.png](ipad-check/ipad-mini-upright.png), [ipad-pro-sideways.png](ipad-check/ipad-pro-sideways.png), [ipad-mini-sideways.png](ipad-check/ipad-mini-sideways.png), and a change sheet, [ipad-pro-sheet.png](ipad-check/ipad-pro-sheet.png).

The sideways pictures were drawn at the sideways screen size inside an upright simulator, because the simulator could not be turned from the command line. The layout is the same; the status bar along the top is missing.

## Still to check

The screens still being built (in-play sequence, teams and songs, pregame, game overview, postgame and season) get the same check before they are accepted; the standing orders in [plan/rules-for-agents.md](../plan/rules-for-agents.md) now ask for it.
