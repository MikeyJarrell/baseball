#!/bin/bash
# Sends a new copy of the Scorebook to TestFlight, with the team built in, for phones that are
# never plugged into this Mac (Erick's). See plan/share-with-teammate.md.
#
#     tools/upload_to_testflight.sh                  # team from the newest phone backup
#     tools/upload_to_testflight.sh <backup folder>  # team from that backup instead
#     tools/upload_to_testflight.sh --stage-only DIR # just lay out the starter team in DIR
#
# The team comes from a copy of Mikey's phone in ~/Dropbox/baseball/phone-backups/ (made by
# tools/load_team.sh): every team, the song list, every song file and announcer recording, and
# the settings. Games are left out. The app puts these in place the first time it opens with
# no team saved; a phone that already has a team keeps its own.
#
# Signing and the upload go through the Apple account Xcode has signed in (team 2U9RH88978).
# Apple then takes from a few minutes to a few hours to process the copy before testers get it.

set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
BACKUPS="$HOME/Dropbox/baseball/phone-backups"
TEAM_ID="2U9RH88978"
WORK="$HOME/Library/Developer/Xcode/DerivedData/Scorebook-testflight"

STAGE_ONLY=""
if [[ "${1:-}" == "--stage-only" ]]; then STAGE_ONLY="${2:?Name a folder to lay the starter team out in}"; shift 2; fi

# The phone backup to take the team from: the one named, or else the newest.
SOURCE="${1:-$(ls -td "$BACKUPS"/*/ | head -1)}"
DATA="${SOURCE%/}/Library/Application Support/Scorebook"
if [[ ! -d "$DATA/teams" ]]; then
    echo "No saved teams in $SOURCE" >&2
    exit 1
fi

# Lay out the starter team: everything the app saves except games.
STARTER="${STAGE_ONLY:-$WORK/StarterTeam}"
rm -rf "$STARTER" && mkdir -p "$STARTER"
cp -R "$DATA/teams" "$STARTER/teams"
cp -R "$DATA/songs" "$STARTER/songs"
[[ -f "$DATA/settings.json" ]] && cp "$DATA/settings.json" "$STARTER/settings.json"
echo "Team from $(basename "$SOURCE"): $(ls "$STARTER/teams" | wc -l | tr -d ' ') teams," \
     "$(ls "$STARTER/songs/audio" | wc -l | tr -d ' ') song and announcer files" \
     "($(du -sh "$STARTER" | cut -f1))."
if [[ -n "$STAGE_ONLY" ]]; then exit 0; fi

# Each upload needs a higher build number than the last: the date and time does that.
BUILD_NUMBER="$(date +%Y%m%d%H%M)"
ARCHIVE="$WORK/Scorebook-$BUILD_NUMBER.xcarchive"

echo "Building copy $BUILD_NUMBER (a few minutes)…"
xcodebuild archive -project "$REPO/app/Scorebook.xcodeproj" -scheme Scorebook -configuration Release \
    -destination "generic/platform=iOS" -archivePath "$ARCHIVE" -allowProvisioningUpdates \
    SCOREBOOK_STARTER_TEAM="$STARTER" CURRENT_PROJECT_VERSION="$BUILD_NUMBER" -quiet

# Check the team made it into the app.
if [[ ! -d "$ARCHIVE/Products/Applications/Scorebook.app/StarterTeam/teams" ]]; then
    echo "The team is missing from the built app; not uploading." >&2
    exit 1
fi

# How to send it: straight to App Store Connect, signed for distribution by Xcode.
OPTIONS="$WORK/ExportOptions.plist"
cat > "$OPTIONS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key><string>app-store-connect</string>
    <key>destination</key><string>upload</string>
    <key>teamID</key><string>$TEAM_ID</string>
    <key>signingStyle</key><string>automatic</string>
    <key>manageAppVersionAndBuildNumber</key><false/>
</dict>
</plist>
PLIST

echo "Uploading to App Store Connect…"
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportOptionsPlist "$OPTIONS" \
    -exportPath "$WORK/export-$BUILD_NUMBER" -allowProvisioningUpdates

echo "Done. Copy $BUILD_NUMBER is uploaded; testers get it once Apple finishes processing it."
