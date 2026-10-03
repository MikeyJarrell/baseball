"""Download and cut every player's walk-up song.

Reads team/roster.csv. For each player with a song source and a hook time, and no clip
yet, it downloads the audio with the yt-dlp copy that Stacher installs, cuts a clip that
runs from LEAD_IN seconds before the hook to TAIL seconds after it, evens out its loudness,
and saves it to ~/Dropbox/baseball/songs/ as an M4A file named after the player. It then
writes the clip's file name, and where the hook falls inside the clip, back into the roster.

Run from the repository root:

    python3 tools/walkup_songs.py            # only players who have no clip yet
    python3 tools/walkup_songs.py --redo     # cut every clip again
"""

import csv
import subprocess
import sys
import tempfile
import unicodedata
from pathlib import Path

# Where things live.
REPO = Path(__file__).resolve().parent.parent
ROSTER = REPO / "team" / "roster.csv"
SONGS_DIR = Path.home() / "Dropbox" / "baseball" / "songs"
YT_DLP = Path.home() / ".stacher" / "youtube-dl"  # the yt-dlp copy Stacher keeps up to date
FFMPEG = "ffmpeg"

# Clip shape, in seconds. The song fades in under the announcer before the hook, and plays
# about 12 seconds past it before fading out, so the clip carries room on both sides.
LEAD_IN = 20  # audio kept before the hook (less if the hook is near the start of the track)
TAIL = 30  # audio kept after the hook
EDGE_FADE_IN = 0.5  # short fades at the clip's own edges so it never starts or stops with a click
EDGE_FADE_OUT = 2.0


def seconds(text):
    """Turn "2:30" or "0:04" or "45" into a number of seconds."""
    parts = [float(p) for p in text.strip().split(":")]
    total = 0.0
    for p in parts:
        total = total * 60 + p
    return total


def clock(secs):
    """Turn a number of seconds into "m:ss"."""
    secs = int(round(secs))
    return f"{secs // 60}:{secs % 60:02d}"


def file_name(row):
    """A plain file name from the player's name: "bobby-yabumoto.m4a"."""
    name = f"{row['goes_by']} {row['last_name']}".lower()
    # Drop accents and anything that is not a letter or digit.
    name = unicodedata.normalize("NFKD", name).encode("ascii", "ignore").decode()
    words = "".join(c if c.isalnum() else " " for c in name).split()
    return "-".join(words) + ".m4a"


def download(url, folder):
    """Download the best audio stream for one song into folder; return its path. YouTube
    sometimes refuses one stream, so try a few times, then the plain YouTube address."""
    template = str(folder / "source.%(ext)s")
    addresses = [url, url, url.replace("music.youtube.com", "www.youtube.com")]
    for attempt, address in enumerate(addresses, start=1):
        result = subprocess.run(
            [str(YT_DLP), "--quiet", "--no-warnings", "--no-playlist", "--retries", "5",
             "-f", "bestaudio", "-o", template, address],
        )
        found = list(folder.glob("source.*"))
        if result.returncode == 0 and found:
            return found[0]
        for leftover in found:
            leftover.unlink()  # clear a partial download before trying again
    raise RuntimeError(f"could not download {url}")


def cut(source, hook, out_path, row):
    """Cut the clip around the hook, even out loudness, and save it as M4A. Return the hook's
    position inside the clip."""
    start = max(0.0, hook - LEAD_IN)
    length = (hook - start) + TAIL
    fade_out_at = length - EDGE_FADE_OUT
    filters = ",".join(
        [
            f"afade=t=in:st=0:d={EDGE_FADE_IN}",
            f"afade=t=out:st={fade_out_at}:d={EDGE_FADE_OUT}",
            # Bring every clip to the same loudness, so the per-song volume in the app
            # starts from an even library.
            "loudnorm=I=-14:TP=-1.5:LRA=11",
        ]
    )
    subprocess.run(
        [
            FFMPEG, "-hide_banner", "-loglevel", "error", "-y",
            "-ss", f"{start}", "-t", f"{length}", "-i", str(source),
            "-af", filters,
            "-ar", "44100", "-c:a", "aac", "-b:a", "256k",
            "-metadata", f"title={row['goes_by']} {row['last_name']}: {row['song']}",
            "-metadata", f"artist={row['artist']}",
            str(out_path),
        ],
        check=True,
    )
    return hook - start


def main():
    redo = "--redo" in sys.argv
    SONGS_DIR.mkdir(parents=True, exist_ok=True)

    with ROSTER.open(newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        columns = reader.fieldnames
        rows = list(reader)

    for row in rows:
        who = f"{row['goes_by']} {row['last_name']}"
        if not row["source"] or not row["hook"]:
            continue  # no song chosen yet
        out_path = SONGS_DIR / file_name(row)
        if out_path.exists() and row["clip_file"] and not redo:
            print(f"skip   {who}: {out_path.name} already cut")
            continue
        print(f"fetch  {who}: {row['song']} from {row['hook']}")
        try:
            with tempfile.TemporaryDirectory() as tmp:
                source = download(row["source"], Path(tmp))
                hook_in_clip = cut(source, seconds(row["hook"]), out_path, row)
        except (RuntimeError, subprocess.CalledProcessError) as problem:
            # One bad song should not stop the rest; report it and move on.
            print(f"FAILED {who}: {problem}")
            continue
        row["clip_file"] = out_path.name
        row["start_point_in_clip"] = clock(hook_in_clip)
        print(f"saved  {out_path.name}, hook at {clock(hook_in_clip)} in the clip")

    # Write the clip names and start points back into the roster.
    with ROSTER.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=columns)
        writer.writeheader()
        writer.writerows(rows)


if __name__ == "__main__":
    main()
