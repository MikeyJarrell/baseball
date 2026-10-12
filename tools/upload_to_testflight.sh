#!/bin/bash
# Sends a new copy of the Scorebook to TestFlight, with the team and the season's games built
# in, for phones that are never plugged into this Mac (Erick's, Matt's). See
# plan/share-with-teammate.md.
#
#     tools/upload_to_testflight.sh                  # team from the newest phone backup
#     tools/upload_to_testflight.sh <backup folder>  # team from that backup instead
#     tools/upload_to_testflight.sh --stage-only DIR # just lay out the starter team in DIR
#
# The team comes from a copy of Mikey's phone in ~/Dropbox/baseball/phone-backups/ (made by
# tools/load_team.sh): every team, the song list, every song file and announcer recording, the
# settings, and the games. The app puts the team in place the first time it opens with no team
# saved; a phone that already has a team keeps its own. The finished games go onto every phone
# that does not have them, once each: one deleted on a phone stays deleted, and a phone's own
# copy of a game is never replaced (see StarterGames.swift). Games still in progress are
# skipped by the app.
#
# Signing and the upload need no Xcode sign-in (the command-line upload stopped working with it
# after Mikey's password change on October 6). They use what lives in ~/.appstoreconnect/ on the
# Mac mini, outside the repository:
#   private_keys/AuthKey_6X6QWG95X7.p8   Mikey's App Store Connect key (made October 10)
#   distribution/signing.keychain-db     the Apple Distribution certificate and its private key,
#                                        in a keychain of their own, unlocked with the password
#                                        in distribution/keychain-password, so signing never
#                                        stops for a dialog on the Mac's screen
# and the "Scorebook App Store" provisioning profile, installed in Xcode's profiles folder.
# The certificate runs until October 10, 2027.
# Apple then takes from a few minutes to a few hours to process the copy. The internal test
# group "Team" gets every build, so Erick's TestFlight offers it as soon as processing ends.

set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
BACKUPS="$HOME/Dropbox/baseball/phone-backups"
TEAM_ID="2U9RH88978"
KEY_ID="6X6QWG95X7"
ISSUER_ID="7e8e45fc-8082-464c-bd53-f51f2f45f798"
KEY_FILE="$HOME/.appstoreconnect/private_keys/AuthKey_$KEY_ID.p8"
SIGNING="$HOME/.appstoreconnect/distribution"
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

# Lay out the starter team: everything the app saves.
STARTER="${STAGE_ONLY:-$WORK/StarterTeam}"
rm -rf "$STARTER" && mkdir -p "$STARTER/games"
cp -R "$DATA/teams" "$STARTER/teams"
cp -R "$DATA/songs" "$STARTER/songs"
[[ -f "$DATA/settings.json" ]] && cp "$DATA/settings.json" "$STARTER/settings.json"
[[ -d "$DATA/games" ]] && cp -R "$DATA/games/." "$STARTER/games/"
echo "Team from $(basename "$SOURCE"): $(ls "$STARTER/teams" | wc -l | tr -d ' ') teams," \
     "$(ls "$STARTER/songs/audio" | wc -l | tr -d ' ') song and announcer files," \
     "$(ls "$STARTER/games" | wc -l | tr -d ' ') games" \
     "($(du -sh "$STARTER" | cut -f1))."
if [[ -n "$STAGE_ONLY" ]]; then exit 0; fi

# Each upload needs a higher build number than the last: the date and time does that.
BUILD_NUMBER="$(date +%Y%m%d%H%M)"
ARCHIVE="$WORK/Scorebook-$BUILD_NUMBER.xcarchive"

echo "Building copy $BUILD_NUMBER (a few minutes)…"
xcodebuild archive -project "$REPO/app/Scorebook.xcodeproj" -scheme Scorebook -configuration Release \
    -destination "generic/platform=iOS" -archivePath "$ARCHIVE" -allowProvisioningUpdates \
    -authenticationKeyPath "$KEY_FILE" -authenticationKeyID "$KEY_ID" -authenticationKeyIssuerID "$ISSUER_ID" \
    SCOREBOOK_STARTER_TEAM="$STARTER" CURRENT_PROJECT_VERSION="$BUILD_NUMBER" -quiet

# Check the team made it into the app.
if [[ ! -d "$ARCHIVE/Products/Applications/Scorebook.app/StarterTeam/teams" ]]; then
    echo "The team is missing from the built app; not uploading." >&2
    exit 1
fi

# Unlock the signing keychain for this run.
security unlock-keychain -p "$(cat "$SIGNING/keychain-password")" "$SIGNING/signing.keychain-db"

# How to send it: straight to App Store Connect, signed with the distribution certificate.
OPTIONS="$WORK/ExportOptions.plist"
cat > "$OPTIONS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key><string>app-store-connect</string>
    <key>destination</key><string>upload</string>
    <key>teamID</key><string>$TEAM_ID</string>
    <key>signingStyle</key><string>manual</string>
    <key>signingCertificate</key><string>Apple Distribution</string>
    <key>provisioningProfiles</key>
    <dict><key>com.mikeyjarrell.scorebook</key><string>Scorebook App Store</string></dict>
    <key>manageAppVersionAndBuildNumber</key><false/>
</dict>
</plist>
PLIST

echo "Uploading to App Store Connect…"
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportOptionsPlist "$OPTIONS" \
    -exportPath "$WORK/export-$BUILD_NUMBER" \
    -authenticationKeyPath "$KEY_FILE" -authenticationKeyID "$KEY_ID" -authenticationKeyIssuerID "$ISSUER_ID"

echo "Done. Copy $BUILD_NUMBER is uploaded; testers get it once Apple finishes processing it."
