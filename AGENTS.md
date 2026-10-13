# Baseball

Mikey Jarrell’s personal baseball project.

## Start here

Read [README.md](README.md) for the folder map and [PROJECT_INDEX.md](PROJECT_INDEX.md) for current status.

## Working rules

- Use a separate Git worktree for each editing task; finish reviewed work with `/done`.
- Follow the shared writing guide at `~/.claude/writing-style-guide.md`.
- Preserve Mikey’s prose unless he requests an edit or a factual correction is needed.
- Keep project knowledge in this repository. File working notes in `notes/`, research reports in `deep-research/`, and AI reviews in `feedback/ai/`.
- Keep credentials, bulky datasets, and recordings out of Git. Song files and other bulk files for the app live in `~/Dropbox/baseball/` (see its README).
- Leave delivered or frozen documents unchanged unless explicitly asked.
- The laptop has no Xcode, so `swift test` fails there. Build, test and upload on the Mac mini over `ssh mini-ip` (`ssh mini` does not resolve away from home), from a throwaway copy; long jobs go in the background there, since the VPN drops. The remote upload steps are in [plan/share-with-teammate.md](plan/share-with-teammate.md).
- Run `tools/install_on_phone.sh`, `tools/load_team.sh` and `tools/publish_stats.sh` yourself once Mikey says the phone is plugged in; never hand him those commands. Only what he must do in person (recording with `tools/record_intros.py`, listening) gets a command for him.

## Current focus

Building the scorebook iPhone app. Start with [plan/README.md](plan/README.md); builders follow [plan/rules-for-agents.md](plan/rules-for-agents.md) and their brief in `plan/briefs/`. Track scope and status in [PROJECT_INDEX.md](PROJECT_INDEX.md). Shared deadlines, when assigned, live in `~/.claude-assistant/config/goals.yaml`.
