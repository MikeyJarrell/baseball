"""Record the stadium announcer's pieces on the Mac, one short clip at a time.

The app builds each player's introduction out of pieces, so a jersey number assigned
mid-season needs no new recording:

    "Now batting,"  +  "number twenty-two,"  +  "Aidan Kurt."  +  "Number twenty-two."

This script records those pieces with the Mac's microphone (the ATR2100x if it is plugged in):

    now-batting.m4a       "Now batting,"
    names/<player>.m4a    each player's name, one per row of team/roster.csv
    numbers/<n>.m4a       "Number twenty-two", for every number 0 to 99 and 00
    closing/<n>.m4a       optional: the same numbers said again to END the introduction,
                          voice falling. Without one, the app repeats the numbers/ clip.

Everything goes to ~/Dropbox/baseball/intros/. Each take is cleaned up before it is saved:
silence trimmed from both ends, low rumble filtered out, and the loudness evened out so
every piece sits at the same level when the app stitches them together. Record them dry:
the app adds the stadium echo when it plays them. The untouched take is kept as a WAV file
in intros/raw/, so a take can be cleaned up again later without re-recording it.

For each piece: press Enter to start, say the line, press Enter to stop. The take plays
back, then Enter keeps it, r redoes it, p plays it again, s skips it, q quits. Pieces that
already have a file are skipped, so quitting and running again carries on where you were.

Run from the repository root:

    python3 tools/record_intros.py                   # everything not recorded yet
    python3 tools/record_intros.py names             # only one kind: now-batting, names,
                                                     #   numbers or closing
    python3 tools/record_intros.py --redo 22 aidan-kurt   # record these pieces again
    python3 tools/record_intros.py --mic "Desk Microphone"   # another microphone
"""

import argparse
import csv
import subprocess
import sys
import tempfile
import unicodedata
from pathlib import Path

import numpy as np

# Where things live.
REPO = Path(__file__).resolve().parent.parent
ROSTER = REPO / "team" / "roster.csv"
INTROS_DIR = Path.home() / "Dropbox" / "baseball" / "intros"
FFMPEG = "ffmpeg"

# How takes are recorded and cleaned up.
RATE = 48000  # samples per second
PREFERRED_MIC = "ATR2100x"  # picked first when several microphones are plugged in
VOICE_BELOW_PEAK_DB = 35  # anything this far below the loudest moment counts as silence
KEEP_BEFORE = 0.05  # seconds of quiet kept before the first sound, so a "p" is not clipped
KEEP_AFTER = 0.15  # seconds kept after the last sound, so a trailing "s" rings out
TARGET_LOUDNESS_DB = -18.0  # average level of the spoken part, in decibels below full scale
PEAK_LIMIT_DB = -1.0  # never louder than this at any instant

ONES = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine",
        "ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen",
        "seventeen", "eighteen", "nineteen"]
TENS = ["", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety"]


def number_words(number):
    """How a jersey number is said: "22" is "twenty-two", "00" is "double zero"."""
    if number == "00":
        return "double zero"
    n = int(number)
    if n < 20:
        return ONES[n]
    tens, ones = divmod(n, 10)
    return TENS[tens] + ("" if ones == 0 else "-" + ONES[ones])


def player_slug(row):
    """A plain file name stem from the player's name, matching their song: "bobby-yabumoto"."""
    name = f"{row['goes_by']} {row['last_name']}".lower()
    # Drop accents and anything that is not a letter or digit.
    name = unicodedata.normalize("NFKD", name).encode("ascii", "ignore").decode()
    words = "".join(c if c.isalnum() else " " for c in name).split()
    return "-".join(words)


def all_pieces():
    """Every piece to record, in recording order: (kind, short name, file, what to say)."""
    pieces = [("now-batting", "now-batting", INTROS_DIR / "now-batting.m4a", "Now batting,")]
    with open(ROSTER, newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            slug = player_slug(row)
            spoken = f"{row['goes_by']} {row['last_name']}"
            pieces.append(("names", slug, INTROS_DIR / "names" / f"{slug}.m4a", spoken))
    numbers = [str(n) for n in range(100)] + ["00"]
    for n in numbers:
        said = f"Number {number_words(n)}   ({n})"
        pieces.append(("numbers", n, INTROS_DIR / "numbers" / f"{n}.m4a", said))
    for n in numbers:
        said = f"Number {number_words(n)}.   ({n}, voice falling: the end of the introduction)"
        pieces.append(("closing", n, INTROS_DIR / "closing" / f"{n}.m4a", said))
    return pieces


def find_microphone(wanted):
    """The name of the microphone to record from, as macOS lists it."""
    listing = subprocess.run(
        [FFMPEG, "-hide_banner", "-f", "avfoundation", "-list_devices", "true", "-i", ""],
        capture_output=True, text=True).stderr
    # The audio devices come after the "AVFoundation audio devices:" line, one per line,
    # each looking like "[AVFoundation ...] [0] ATR2100x-USB Microphone".
    audio_part = listing.split("audio devices:", 1)[-1]
    mics = [line.split("] ", 2)[-1].strip() for line in audio_part.splitlines()
            if "] [" in line]
    for mic in mics:
        if (wanted or PREFERRED_MIC).lower() in mic.lower():
            return mic
    if wanted:
        sys.exit(f"No microphone called “{wanted}”. These are plugged in: {', '.join(mics)}")
    if not mics:
        sys.exit("No microphone found.")
    print(f"The {PREFERRED_MIC} is not plugged in, so recording from “{mics[0]}”.")
    return mics[0]


def record(mic, wav_path):
    """Records from the microphone until Enter is pressed again."""
    recorder = subprocess.Popen(
        [FFMPEG, "-hide_banner", "-loglevel", "error", "-y", "-f", "avfoundation",
         "-i", f":{mic}", "-ac", "1", "-ar", str(RATE), str(wav_path)],
        stdin=subprocess.PIPE)
    input("  ● Recording… press Enter to stop.")
    recorder.communicate(b"q")  # "q" tells ffmpeg to finish the file and stop


def read_audio(path, filters=None):
    """The sound in a file as a list of samples between -1 and 1, optionally filtered first."""
    command = [FFMPEG, "-hide_banner", "-loglevel", "error", "-i", str(path)]
    if filters:
        command += ["-af", filters]
    command += ["-ac", "1", "-ar", str(RATE), "-f", "f32le", "-"]
    raw = subprocess.run(command, capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).copy()


def clean_up(raw_wav, out_path):
    """Trims, filters and levels one take, saves it as M4A, and returns a warning or None."""
    # Take out low rumble (desk bumps, air conditioning) below the voice.
    audio = read_audio(raw_wav, filters="highpass=f=70")
    if len(audio) < RATE // 10:
        return "Nothing was recorded."
    clipped = np.max(np.abs(read_audio(raw_wav))) >= 0.99  # the microphone was overloaded

    # Loudness in 10-millisecond steps, to find where the voice starts and stops.
    step = RATE // 100
    frames = audio[: len(audio) // step * step].reshape(-1, step)
    frame_db = 20 * np.log10(np.sqrt(np.mean(frames ** 2, axis=1)) + 1e-9)
    loudest = frame_db.max()
    if loudest < -55:
        return ("No voice was heard. Check the microphone is the right one and that the "
                "Terminal is allowed to use it (System Settings → Privacy & Security → Microphone).")
    voiced = np.where(frame_db > loudest - VOICE_BELOW_PEAK_DB)[0]
    start = max(0, voiced[0] * step - int(KEEP_BEFORE * RATE))
    end = min(len(audio), (voiced[-1] + 1) * step + int(KEEP_AFTER * RATE))
    audio = audio[start:end]

    # Even out the loudness: the spoken part's average level goes to the target, without
    # letting any instant go past the peak limit.
    spoken = frame_db[voiced[0]: voiced[-1] + 1]
    spoken_level = 10 * np.log10(np.mean(10 ** (spoken / 10)))
    gain = 10 ** ((TARGET_LOUDNESS_DB - spoken_level) / 20)
    peak = np.max(np.abs(audio)) * gain
    gain *= min(1.0, 10 ** (PEAK_LIMIT_DB / 20) / peak)
    audio = audio * gain

    # Short fades at both ends so the stitched pieces never click.
    fade_in, fade_out = int(0.01 * RATE), int(0.03 * RATE)
    audio[:fade_in] *= np.linspace(0, 1, fade_in)
    audio[-fade_out:] *= np.linspace(1, 0, fade_out)

    subprocess.run(
        [FFMPEG, "-hide_banner", "-loglevel", "error", "-y", "-f", "f32le", "-ar", str(RATE),
         "-ac", "1", "-i", "-", "-c:a", "aac", "-b:a", "192k", str(out_path)],
        input=audio.astype(np.float32).tobytes(), check=True)

    if clipped:
        return "The take was too loud for the microphone and is distorted. Back off a little and redo it."
    if loudest < -40:
        return "The take is very quiet. Move closer to the microphone or turn its gain up."
    return None


def play(path):
    """Plays a file through the Mac's speakers and waits until it ends."""
    subprocess.run(["afplay", str(path)])


def main():
    parser = argparse.ArgumentParser(description="Record the announcer's pieces.")
    parser.add_argument("kind", nargs="?", choices=["now-batting", "names", "numbers", "closing"],
                        help="record only this kind of piece")
    parser.add_argument("--redo", nargs="+", metavar="PIECE",
                        help="record these pieces again, by short name: 22, 00, aidan-kurt, now-batting")
    parser.add_argument("--mic", help="part of the microphone's name, if not the ATR2100x")
    args = parser.parse_args()

    pieces = all_pieces()
    if args.redo:
        pieces = [p for p in pieces if p[1] in args.redo]
        if args.kind:
            pieces = [p for p in pieces if p[0] == args.kind]
        elif any(p[0] == "closing" for p in pieces):
            # "--redo 22" means the main number clip; the closing one only when asked for.
            pieces = [p for p in pieces if p[0] != "closing"]
        if not pieces:
            sys.exit("None of those pieces exist. Use 22, 00, now-batting or a name like aidan-kurt.")
    else:
        if args.kind:
            pieces = [p for p in pieces if p[0] == args.kind]
        else:
            # The closing numbers are optional, so they are only recorded when asked for.
            pieces = [p for p in pieces if p[0] != "closing"]
        pieces = [p for p in pieces if not p[2].exists()]
        if not pieces:
            print("Every piece is already recorded. Use --redo to record one again.")
            return

    mic = find_microphone(args.mic)
    print(f"Recording from “{mic}”. {len(pieces)} piece(s) to record. Say each line as you"
          " would over the stadium speakers. Ctrl-C stops at any time.\n")

    raw_dir = INTROS_DIR / "raw"
    raw_dir.mkdir(parents=True, exist_ok=True)
    for done, (kind, name, out_path, spoken) in enumerate(pieces, 1):
        # A new take is held in these two files until it is kept, so redoing a piece
        # never loses the old take until the new one is accepted.
        take_wav = raw_dir / f"{kind}-{name}.take.wav"
        take = raw_dir / f"{kind}-{name}.take.m4a"
        print(f"[{done}/{len(pieces)}]  Say:  {spoken}")
        while True:
            input("  Press Enter to start recording.")
            record(mic, take_wav)
            warning = clean_up(take_wav, take)
            if warning:
                print(f"  ! {warning}")
            if not take.exists():
                continue  # nothing usable came out of that take: record again
            play(take)
            choice = input("  Enter keeps it · r redo · p play again · s skip · q quit: ").strip().lower()
            while choice == "p":
                play(take)
                choice = input("  Enter keeps it · r redo · p play again · s skip · q quit: ").strip().lower()
            if choice == "r":
                continue
            if choice == "":
                # Keep: the cleaned take becomes the piece, and the untouched take its raw copy.
                out_path.parent.mkdir(parents=True, exist_ok=True)
                take.replace(out_path)
                take_wav.replace(raw_dir / f"{kind}-{name}.wav")
            take.unlink(missing_ok=True)
            take_wav.unlink(missing_ok=True)
            if choice == "s":
                print("  Skipped.")
            if choice == "q":
                print("Stopped. Run the script again to carry on from this piece.")
                return
            break
        print()
    print(f"Done. The pieces are in {INTROS_DIR}.")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nStopped. Run the script again to carry on from where you were.")
