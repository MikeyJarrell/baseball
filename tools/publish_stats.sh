#!/bin/bash
# Publishes the Diamond Dogs' stats website at https://mikeyjarrell.com/dogs/ from the games
# saved on the phone: the record, every finished game's box score, season batting and pitching,
# and a page per player.
#
# Run it from anywhere, with the iPhone plugged into the Mac and unlocked:
#
#     tools/publish_stats.sh                     # read the phone, build the pages, publish them
#     tools/publish_stats.sh --preview           # read the phone and build, but don't publish
#     tools/publish_stats.sh --from <folder>     # use a copy of the app's saved files instead of
#                                                #   the phone (a folder holding games/ and teams/,
#                                                #   such as one in ~/Dropbox/baseball/phone-backups)
#
# --preview and --from can be combined. A preview prints the folder the pages were written to.
#
# The pages live in their own public repository, github.com/MikeyJarrell/dogs, which holds
# nothing but the built pages; GitHub Pages serves it at mikeyjarrell.com/dogs/. The first
# publish creates that repository and turns Pages on. Search engines are asked not to list it.
#
# Nothing on the phone is changed: the games and teams are only read, and the app keeps running.

set -euo pipefail

# The repository folder (this script lives in its tools folder).
REPO="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLE_ID="com.mikeyjarrell.scorebook"
# Where the app keeps its saved files, inside its own folder on the phone.
DATA_PATH="Library/Application Support/Scorebook"
SITE_REPO="MikeyJarrell/dogs"
SITE_URL="https://mikeyjarrell.com/dogs/"

PREVIEW=0
FROM=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --preview) PREVIEW=1; shift ;;
        --from) FROM="$2"; shift 2 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

WORK="$(mktemp -d)"
# A preview's pages are kept for looking at; everything else is cleaned up.
trap '[[ $PREVIEW == 1 ]] || rm -rf "$WORK"' EXIT

# Build the website builder (only the first time takes long).
echo "Building the website builder…"
swift build -c release --package-path "$REPO/app/Packages/ScorebookCore" --product StatsSite >/dev/null
BUILDER="$(swift build -c release --package-path "$REPO/app/Packages/ScorebookCore" --show-bin-path)/StatsSite"

# ---- 1. The saved games and teams ----

if [[ -n "$FROM" ]]; then
    DATA="$FROM"
    echo "1. Using the saved files in $DATA"
else
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
    echo "1. Reading the games and teams off the phone"
    DATA="$WORK/Scorebook"
    # Only the games and teams: the song files are large and the pages don't need them.
    for folder in games teams; do
        mkdir -p "$DATA/$folder"
        xcrun devicectl device copy from --device "$DEVICE" --domain-type appDataContainer \
            --domain-identifier "$BUNDLE_ID" --source "$DATA_PATH/$folder" --destination "$DATA/$folder" >/dev/null
    done
fi

# ---- 2. The pages ----

echo "2. Building the pages"
SITE="$WORK/site"
"$BUILDER" "$DATA" "$SITE"

if [[ $PREVIEW == 1 ]]; then
    echo "Preview only, nothing published. The pages are in $SITE"
    echo "Open $SITE/index.html in a browser to look at them."
    exit 0
fi

# ---- 3. Publishing ----

echo "3. Publishing to $SITE_URL"
if ! gh repo view "$SITE_REPO" >/dev/null 2>&1; then
    # The first publish: a public repository for the pages, with GitHub Pages serving it.
    gh repo create "$SITE_REPO" --public \
        --description "Diamond Dogs season stats, built from the team scorebook app" >/dev/null
    NEW=1
else
    NEW=0
fi

CHECKOUT="$WORK/checkout"
if [[ $NEW == 1 ]]; then
    mkdir -p "$CHECKOUT" && git -C "$CHECKOUT" init -q -b main
    git -C "$CHECKOUT" remote add origin "https://github.com/$SITE_REPO.git"
else
    git clone -q "https://github.com/$SITE_REPO.git" "$CHECKOUT"
fi
# Replace the old pages with the new ones, keeping only the repository's own history.
find "$CHECKOUT" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
cp -R "$SITE/." "$CHECKOUT/"
git -C "$CHECKOUT" add -A
if git -C "$CHECKOUT" diff --cached --quiet; then
    echo "   The published pages are already up to date."
else
    git -C "$CHECKOUT" commit -q -m "Update stats"
    git -C "$CHECKOUT" push -q -u origin main
fi

if [[ $NEW == 1 ]]; then
    gh api "repos/$SITE_REPO/pages" -X POST -f "source[branch]=main" -f "source[path]=/" >/dev/null
    echo "   GitHub Pages is switched on. The first time, the site takes a few minutes to appear."
fi
echo "Done: $SITE_URL"
