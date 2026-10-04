# Team

The Diamond Dogs roster, kept here until the app has its own saved team, the [fall schedule](schedule.md), and [every opponent’s registered players](opponents.csv).

[roster.csv](roster.csv) lists every player, the name they go by, their jersey number once known, which side they bat and throw from (R or L), their usual position (P, C, 1B, 2B, 3B, SS, LF, CF, RF, DH), their usual role (leads off, starts on the bench), and their walk-up song: the song, the artist, the time in the full track where it should hit (`hook`), and where the audio came from (`source`). The last two columns are filled in by the song script: the clip’s file name in `~/Dropbox/baseball/songs/`, and where the hook falls inside that clip, which is the start point to set in the app.

To add a song, fill in `song`, `artist`, `hook` and `source` (a YouTube Music or YouTube address) for the player, then run from the repository root:

```bash
python3 tools/walkup_songs.py
```

It only cuts players who have no clip yet; `--redo` cuts them all again. Each clip runs from 20 seconds before the hook to 30 seconds after it, so the song can fade in under the announcer and play about 12 seconds past the hook before fading out. A hook near the start of a track leaves less room before it; the app still gives that song the same fade-in as the rest, so it reaches full volume a few seconds after its hook.

A pitcher’s warm-up song goes in the `warmup_` columns: the song, the artist and its source. It plays until the first pitch, so the script keeps the whole track rather than a clip, saved as `<player>-warmup.m4a`.

A pitcher can also have extra warm-up songs, listed in [warmup_extras.csv](warmup_extras.csv), one row per song: the pitcher (the name he goes by and his last name, “Chris Strong”), the song, the artist and its source. The script keeps each whole track, saved as `<player>-warmup-<song>.m4a`, and fills in `file`. In a game his main warm-up song plays his first inning; each later inning plays one of his extra songs at random, each once before any repeats.

Prefer the album audio on YouTube Music over a music video: video intros shift the timings players read off Spotify.

To find the album audio for a request, search YouTube Music from the command line; each result’s album shows with `--print "%(album)s"`:

```bash
~/.stacher/youtube-dl --flat-playlist --playlist-end 3 --print "%(id)s | %(title)s" "https://music.youtube.com/search?q=low+rider+war#songs"
```

When a player wants a particular line heard, find when it is sung with `mlx_whisper` (installed in Anaconda) on the first minute of the track, using `--word-timestamps True`, and set the hook just before the line. The announcer finishes as the song reaches its hook, so the line then comes in clear.

## Putting the team on the phone

`tools/load_team.sh` puts this roster, every opponent in `opponents.csv` and every song file named in the roster onto the phone, with each walk-up song starting at its `start_point_in_clip` and each warm-up song from the top of the track. Plug the phone in, unlock it, and run from the repository root:

```bash
tools/load_team.sh
```

Run it again whenever this folder changes. It backs up what the phone has to `~/Dropbox/baseball/phone-backups/` first, matches players and teams by name so everyone keeps their id and season stats, keeps anything typed into the app that the roster leaves blank (a jersey number, a recorded introduction), and never touches a game. `tools/load_team.sh --simulator` does a trial run on the Mac’s iPhone simulator. The program it runs, `TeamLoader`, is in `app/Packages/ScorebookCore/Sources/TeamLoader/`; the handoff is [plan/handoffs/load-team.md](../plan/handoffs/load-team.md).
