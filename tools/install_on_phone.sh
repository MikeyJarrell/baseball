#!/bin/bash
# Puts the newest Scorebook on Mikey's iPhone in one command.
#
# Plug the phone into the Mac, unlock it, then run from anywhere:
#
#     tools/install_on_phone.sh
#
# It builds the app from this folder for the phone (signed with Mikey's paid Apple Developer
# account, team 2U9RH88978, which Xcode keeps signed in; each install opens for a year) and installs it over the copy already there.
# Games, teams and songs on the phone are kept: installing over an app keeps its saved files.
#
# Xcode's Play button does the same thing; this is the same steps without opening Xcode.

set -euo pipefail

# The repository folder (this script lives in its tools folder).
REPO="$(cd "$(dirname "$0")/.." && pwd)"
# Where the build goes, out of the way of the repository.
BUILD="$HOME/Library/Developer/Xcode/DerivedData/Scorebook-install"

# The phone: the one named in SCOREBOOK_DEVICE, or else the first iPhone plugged in.
DEVICE="${SCOREBOOK_DEVICE:-}"
if [[ -z "$DEVICE" ]]; then
    LIST="$(mktemp)"
    xcrun devicectl list devices --json-output "$LIST" >/dev/null
    DEVICE="$(python3 - "$LIST" <<'PY'
import json, sys
for d in json.load(open(sys.argv[1]))["result"]["devices"]:
    hw, conn = d.get("hardwareProperties", {}), d.get("connectionProperties", {})
    if hw.get("reality") == "physical" and hw.get("deviceType") == "iPhone" and conn.get("tunnelState") != "unavailable":
        print(hw.get("udid", d["identifier"])); break
PY
)"
    rm -f "$LIST"
fi
if [[ -z "$DEVICE" ]]; then
    echo "No iPhone found. Plug the phone into the Mac, unlock it, and try again." >&2
    exit 1
fi

echo "Building the Scorebook for the phone (a few minutes the first time)…"
# -allowProvisioningUpdates lets Xcode renew the account's permission when it runs out;
# -allowProvisioningDeviceRegistration lets it add the phone to that account if needed.
xcodebuild -project "$REPO/app/Scorebook.xcodeproj" -scheme Scorebook -configuration Debug \
    -destination "id=$DEVICE" -derivedDataPath "$BUILD" \
    -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
    build -quiet

echo "Installing it on the phone…"
xcrun devicectl device install app --device "$DEVICE" "$BUILD/Build/Products/Debug-iphoneos/Scorebook.app" >/dev/null

echo "Done. The newest Scorebook is on the phone."
