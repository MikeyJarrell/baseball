#!/bin/bash
# Loads the Diamond Dogs onto the phone: every player from team/roster.csv (with their usual
# position and role, walk-up song and its start point, and a pitcher's warm-up songs, with his
# extra ones from team/warmup_extras.csv), every opponent from team/opponents.csv, every song
# file from ~/Dropbox/baseball/songs/, and the announcer recordings from ~/Dropbox/baseball/intros/
# (made with tools/record_intros.py).
#
# Run it from anywhere, with the iPhone plugged into the Mac and unlocked:
#
#     tools/load_team.sh               # the connected iPhone
#     tools/load_team.sh --simulator   # the "iPhone 17" simulator on the Mac, for a trial run
#
# It is safe to run again after the roster changes: players are matched by name and keep their
# place in the season stats, numbers typed into the app are kept, and nothing on the phone is
# deleted. Games and settings are never touched.
#
# What it does, in order:
#   1. stops the Scorebook app, so nothing is being saved while files are copied;
#   2. copies everything the app has saved to ~/Dropbox/baseball/phone-backups/<date and time>/;
#   3. merges the roster files into a copy of those saved files (the TeamLoader program, which
#      writes them exactly as the app does) and copies the song files in;
#   4. copies the teams and songs back into the app, and starts the app again;
#   5. reads everything back off the phone and checks it: players, opponents, and that every
#      song file is there and plays.

set -euo pipefail

# The repository folder (this script lives in its tools folder).
REPO="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLE_ID="com.mikeyjarrell.scorebook"
SONGS="$HOME/Dropbox/baseball/songs"
INTROS="$HOME/Dropbox/baseball/intros"
STAMP="$(date +%Y-%m-%d-%H%M%S)"
# Where the app keeps its saved files, inside its own folder on the phone.
DATA_PATH="Library/Application Support/Scorebook"

MODE="phone"
if [[ "${1:-}" == "--simulator" ]]; then MODE="simulator"; fi

# Build the loader program (only the first time takes long).
echo "Building the loader…"
swift build -c release --package-path "$REPO/app/Packages/ScorebookCore" --product TeamLoader >/dev/null
LOADER="$(swift build -c release --package-path "$REPO/app/Packages/ScorebookCore" --show-bin-path)/TeamLoader"

# A name recorded on the phone (the Record name button) goes back to Dropbox first, into
# intros/names/, when Dropbox has no recording of that name or an older, different one. The
# load that follows then keeps it, and the Mac and the phone agree. Its arguments: the copy of
# the app's files just taken off the device, and the names folder to copy into.
copy_back_names() {
    local audio="$1/$DATA_PATH/songs/audio" names="$2" file base stem dest
    mkdir -p "$names"
    for file in "$audio"/announcer-name-*.m4a; do
        [[ -e "$file" ]] || continue
        base="$(basename "$file")"; stem="${base#announcer-name-}"; stem="${stem%.m4a}"
        [[ "$stem" == take-* ]] && continue   # a take never kept
        dest="$names/$stem.m4a"
        if [[ ! -e "$dest" ]] || { ! cmp -s "$file" "$dest" && [[ "$file" -nt "$dest" ]]; }; then
            cp -p "$file" "$dest"
            echo "   The name recorded on the device for $stem is now in $names"
        fi
    done
}

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

if [[ "$MODE" == "simulator" ]]; then
    # ---- The simulator: its app folder is an ordinary folder on the Mac. ----
    SIM="iPhone 17"
    xcrun simctl boot "$SIM" 2>/dev/null || true
    CONTAINER="$(xcrun simctl get_app_container "$SIM" "$BUNDLE_ID" data)"
    BACKUP="$WORK/simulator-backup"
    echo "1. Stopping the app on the simulator"
    xcrun simctl terminate "$SIM" "$BUNDLE_ID" 2>/dev/null || true
    echo "2. Copying its saved files aside (simulator copies are not kept)"
    mkdir -p "$BACKUP" && cp -Rp "$CONTAINER/." "$BACKUP/"
    echo "3. Loading the team"
    mkdir -p "$WORK/Scorebook"
    [[ -d "$BACKUP/$DATA_PATH" ]] && cp -Rp "$BACKUP/$DATA_PATH/." "$WORK/Scorebook/"
    # A trial run must not write into Dropbox: names recorded in the simulator are copied
    # aside instead.
    copy_back_names "$BACKUP" "$WORK/names-from-simulator"
    "$LOADER" load "$WORK/Scorebook" "$REPO/team" "$SONGS" "$INTROS"
    echo "4. Copying the teams and songs into the app, and starting it"
    mkdir -p "$CONTAINER/$DATA_PATH"
    cp -R "$WORK/Scorebook/teams" "$WORK/Scorebook/songs" "$CONTAINER/$DATA_PATH/"
    xcrun simctl launch "$SIM" "$BUNDLE_ID" >/dev/null
    echo "5. Checking what the app now has"
    "$LOADER" check "$CONTAINER/$DATA_PATH"
    exit 0
fi

# ---- The iPhone, through Xcode's device tool. ----

# The phone: the one named in SCOREBOOK_DEVICE, or else the first iPhone plugged in.
DEVICE="${SCOREBOOK_DEVICE:-}"
if [[ -z "$DEVICE" ]]; then
    xcrun devicectl list devices --json-output "$WORK/devices.json" >/dev/null
    DEVICE="$(python3 - "$WORK/devices.json" <<'EOF'
import json, sys
devices = json.load(open(sys.argv[1]))["result"]["devices"]
for d in devices:
    props, hw = d.get("connectionProperties", {}), d.get("hardwareProperties", {})
    if hw.get("reality") == "physical" and hw.get("deviceType") == "iPhone" and props.get("tunnelState") != "unavailable":
        print(hw.get("udid", d["identifier"])); break
EOF
)"
fi
if [[ -z "$DEVICE" ]]; then
    echo "No iPhone found. Plug the phone into the Mac, unlock it, and try again." >&2
    exit 1
fi
# Every file command below uses the app's own folder on that phone.
ON_PHONE=(--device "$DEVICE" --domain-type appDataContainer --domain-identifier "$BUNDLE_ID")

echo "1. Stopping the app on the phone"
xcrun devicectl device info processes --device "$DEVICE" --json-output "$WORK/processes.json" >/dev/null
PID="$(python3 - "$WORK/processes.json" <<'EOF'
import json, sys
for p in json.load(open(sys.argv[1]))["result"]["runningProcesses"]:
    if p.get("executable", "").endswith("/Scorebook.app/Scorebook"):
        print(p["processIdentifier"]); break
EOF
)"
if [[ -n "$PID" ]]; then
    xcrun devicectl device process terminate --device "$DEVICE" --pid "$PID" >/dev/null
    sleep 2
fi

BACKUP="$HOME/Dropbox/baseball/phone-backups/$STAMP"
echo "2. Copying everything the app has saved to $BACKUP"
# The app's own folders: its saved files, the backups folder the Files app shows, and its
# preferences. (The rest of its folder is the phone's own: screen snapshots and caches, some of
# them locked while the phone writes them.)
for folder in "Library/Application Support" "Documents" "Library/Preferences"; do
    mkdir -p "$BACKUP/$folder"
    xcrun devicectl device copy from "${ON_PHONE[@]}" --source "$folder" --destination "$BACKUP/$folder" >/dev/null
done

echo "3. Loading the team"
mkdir -p "$WORK/Scorebook"
[[ -d "$BACKUP/$DATA_PATH" ]] && cp -Rp "$BACKUP/$DATA_PATH/." "$WORK/Scorebook/"
copy_back_names "$BACKUP" "$INTROS/names"
"$LOADER" load "$WORK/Scorebook" "$REPO/team" "$SONGS" "$INTROS"

echo "4. Copying the teams and songs into the app, and starting it"
# Only the teams and songs folders go back; files already the same are skipped, and nothing
# on the phone is removed.
for folder in teams songs; do
    xcrun devicectl device copy to "${ON_PHONE[@]}" --source "$WORK/Scorebook/$folder" \
        --destination "$DATA_PATH/$folder" >/dev/null
done
if ! xcrun devicectl device process launch --device "$DEVICE" --terminate-existing "$BUNDLE_ID" >/dev/null 2>&1; then
    # A locked phone will not open apps for the Mac; the files are in place all the same.
    echo "   The phone is locked, so the app was not started. Unlock it and open Scorebook."
fi

echo "5. Reading it back off the phone and checking it"
mkdir -p "$WORK/readback"
xcrun devicectl device copy from "${ON_PHONE[@]}" --source "$DATA_PATH" --destination "$WORK/readback" >/dev/null
"$LOADER" check "$WORK/readback"
echo "Done. The phone's earlier files are in $BACKUP"
