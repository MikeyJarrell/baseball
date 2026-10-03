# Team

The Diamond Dogs roster, kept here until the app has its own saved team.

[roster.csv](roster.csv) lists every player, the name they go by, their jersey number once known, and their walk-up song: the song, the artist, the time in the full track where it should hit (`hook`), and where the audio came from (`source`). The last two columns are filled in by the song script: the clip’s file name in `~/Dropbox/baseball/songs/`, and where the hook falls inside that clip, which is the start point to set in the app.

To add a song, fill in `song`, `artist`, `hook` and `source` (a YouTube Music or YouTube address) for the player, then run from the repository root:

```bash
python3 tools/walkup_songs.py
```

It only cuts players who have no clip yet; `--redo` cuts them all again. Each clip runs from 20 seconds before the hook to 30 seconds after it, so the song can fade in under the announcer and play about 12 seconds past the hook before fading out. A hook near the start of a track leaves less room before it.

Prefer the album audio on YouTube Music over a music video: video intros shift the timings players read off Spotify.
