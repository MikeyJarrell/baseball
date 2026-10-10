# Putting the Scorebook on a teammate’s iPhone

**Goal:** Erick Rosas Lopez scores Diamond Dogs games on his own iPhone while Mikey is out of town, with the team, songs and announcer introductions already in the app, and without his phone ever being plugged into Mikey’s Mac.

**Status:** October 10, 2026. Erick (erickrosaslopez6@gmail.com) accepted his App Store Connect invitation and is in the internal testing group “Team,” which holds build 202610061426 (uploaded October 6 with the team from the phone backup of 14:14 that day; it expires 90 days after upload). Apple has emailed him the install button; his status reads “Invited” until he installs. The group has automatic distribution on, so every later upload reaches him with no further step. He has [his instructions](teammate-instructions.md). Mikey is out of town from October 6.

## How he gets the app

Through TestFlight, Apple’s app for installing apps that are not in the App Store, on Mikey’s paid Apple Developer account (team 2U9RH88978, Apple account mikey1004@gmail.com).

TestFlight has two kinds of tester:

- **Internal tester:** someone added to Mikey’s developer account with a limited role. Apple does not review the app first, and he can install new copies the moment they are uploaded. He has to accept one extra email invitation.
- **External tester:** anyone with a link. Simpler for him, but Apple reviews the app before he can install it, and the app carries 24 commercial songs, which Apple’s rules on copyrighted music could trip over.

**Choice: internal tester.** Nothing goes through Apple review and nothing is public. He gets the “Marketing” role (the lowest role that can test), limited to the Scorebook alone; it lets him see the app’s App Store Connect page and nothing else of Mikey’s.

Each TestFlight copy opens for 90 days. Uploading a new copy restarts the 90 days, and his games stay on the phone through updates.

## What has to be built first

1. **The team inside the app.** The TestFlight copy carries a copy of the teams, song list, song files and announcer recordings from Mikey’s phone (from the newest copy in `~/Dropbox/baseball/phone-backups/`, about 175 MB). The first time the app opens with no teams saved, it puts them in place. Copying the phone’s own saved files keeps every player’s identity the same on both phones, so his games can later be added to Mikey’s season stats; loading `team/roster.csv` afresh would give each player a new one.
2. **Upload settings.** The app declares that it uses no special encryption (`ITSAppUsesNonExemptEncryption` set to NO), so each upload skips Apple’s export question. The build number rises with each upload.
3. **One command to upload.** `tools/upload_to_testflight.sh` builds the app for distribution and sends it to App Store Connect through the account Xcode already has signed in.

## Steps

| Step | Who | What |
|---|---|---|
| 1 | Claude | Build the three pieces above and check them on the simulator. Done |
| 2 | Mikey, or Claude once Mikey signs in on the Mac mini | Create the app’s page in App Store Connect: name “Diamond Dogs Scorebook” (App Store names must be unique; the phone still shows “Scorebook”), bundle id `com.mikeyjarrell.scorebook`, SKU `scorebook`. Claude cannot enter passwords. Done |
| 3 | Claude, on the Mac mini | Run `tools/upload_to_testflight.sh`, which takes the team from the newest phone backup. Done |
| 4 | Mikey or Claude | Add Erick as a user with the Marketing role, limited to the Scorebook, and add him to an internal test group. Done October 10 |
| 5 | Mikey | Text him [teammate-instructions.md](teammate-instructions.md) |
| 6 | Teammate | Follows the instructions; Mikey checks he can see the Diamond Dogs and hear a walk-up song |

Allow a day between steps 3 and 6: Apple takes anywhere from minutes to a few hours to process a new upload before it can be tested.

## Roster or song changes while Mikey is away

The copy of the team inside the app only fills an empty app, so it cannot change his team later. A roster change while Mikey is away is typed into the app on the teammate’s phone, the way Mikey would on his own.

## Mikey’s own phone

The app on Mikey’s phone is signed with the paid account, whose permission runs until October 2027, so it needs no weekly reinstall. The install script and [install-on-iphone.md](install-on-iphone.md) still describe the free account and get corrected with step 1.

## Not in this plan

Bringing Erick’s games back into Mikey’s season stats. Mikey handles that on his return.

## Picking this up

What remains:

1. Erick installs from the TestFlight email, opens the app, and should see the Diamond Dogs logo, 9 teams, and hear a walk-up song.
2. A new copy of the app can only be uploaded from the Mac mini, where Xcode is signed in to Mikey’s account (`tools/upload_to_testflight.sh`); a copy expires 90 days after upload.

Claude can work the App Store Connect pages through Chrome on whichever Mac Mikey has signed in on, but cannot enter his password. Two Chromes are connected to Claude (the laptop’s and another Mac’s); a signed-out page after Mikey says he signed in means Claude is driving the wrong one.
