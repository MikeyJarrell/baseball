# Stats website: handoff

**Job:** the public stats website from [the brief](../briefs/stats-website.md), at mikeyjarrell.com/dogs/ instead of /baseball/.

**Mikey’s answers to the brief’s questions:** full names, as on the roster; unlisted (search engines asked not to list it).

## What exists now

- **`StatsSite`** (a Mac command in `app/Packages/ScorebookCore`): reads a copy of the app’s saved files and writes the pages. Every number comes from the app’s own rules engine and stats code, worked out fresh from each finished game’s events, so the pages match the Season screen. Games still in progress are left out.
  - `index.html`: the record, the games (newest first, linked to their box scores), season batting with a team totals row, and season pitching. Only players who have played are listed. Tap a heading to sort.
  - `games/<date>-<opponent>.html`: the newspaper box score, the same text the app shares.
  - `players/<name>.html`: a player’s season line and game-by-game log, batting and pitching.
  - Every page carries `noindex`, and `robots.txt` turns all search engines away.
- **`tools/publish_stats.sh`**: reads only the `games` and `teams` folders off the plugged-in phone (the app keeps running; nothing on the phone changes), builds the pages, and pushes them to the public repository `MikeyJarrell/dogs`, which holds nothing but the built pages. GitHub Pages serves that repository at mikeyjarrell.com/dogs/ because the personal site carries the custom domain. The first publish creates the repository and turns Pages on. `--preview` builds without publishing; `--from <folder>` uses a saved copy instead of the phone.
- No export button in the app: the brief’s export step is unnecessary, since the Mac can read the phone’s saved games directly, as `tools/load_team.sh` already does.

## Checks

- Built from the October 4 phone copy (`phone-backups/2026-10-04-173202-just-before-game-edits`, before that game’s corrections): 1 game, 11 player pages; record 1–0, Diamond Dogs 9, GWW Whales 4. Looked at in a browser at phone width: tables scroll sideways with names held in place, sorting works, the box score fits without sideways scrolling.

## Published

- First published October 6, 2026, from the phone, with the corrected October 4 game: 1 game, 11 player pages, live at https://mikeyjarrell.com/dogs/. Rerun `tools/publish_stats.sh` with the phone plugged in after each game.
