# Putting the Scorebook on a teammate’s iPhone

**Goal:** Erick Rosas Lopez scores Diamond Dogs games on his own iPhone while Mikey is out of town, with the team, songs and announcer introductions already in the app, and without his phone ever being plugged into Mikey’s Mac.

**Status:** October 6, 2026. The first copy (build 202610061426) is uploaded to App Store Connect as “Diamond Dogs Scorebook,” with the team from the phone backup of 14:14 that day. Erick (erickrosaslopez6@gmail.com) is invited to Mikey’s App Store Connect account with the Marketing role, limited to this app, and has been texted [his instructions](teammate-instructions.md). Mikey is out of town from October 6.

**Second tester:** October 10, 2026. Matthew Glatt (biggio330@aol.com) is invited the same way, with the Marketing role, has accepted, and is in the “Team” test group; TestFlight shows him as invited, not yet installed. He follows the same [instructions](teammate-instructions.md). Erick is also in the group, added October 10, and also shows as invited, not yet installed. Adding a tester does not need a new copy of the app: both have the October 6 copy (202610061426).

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
| 4 | Mikey or Claude | Add Erick as a user with the Marketing role, limited to the Scorebook, and add him to an internal test group. Needs his name and the email address of his Apple account |
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

What remains once Erick has accepted his App Store Connect invitation:

1. Mikey, in App Store Connect from any browser: Apps, Diamond Dogs Scorebook, TestFlight tab; click + beside Internal Testing, name the group “Team,” add Erick, and add build 202610061426 if the group lacks it. That sends Erick the email with the install button.
2. If Erick is not offered in the group, he has not accepted the invitation yet. If the build shows “Processing,” Apple is not done with it.
3. Erick opens the app and should see the Diamond Dogs logo, 9 teams, and hear a walk-up song.

What Claude can and cannot do in App Store Connect, when Mikey is signed in to it in Chrome: it can read every page, add an accepted person to the test group, and expire a build. It is blocked from inviting a new person to the account, so Mikey fills in that form (Users and Access, +, Marketing role).

## Uploading a new copy: broken from the command line since October 10

`tools/upload_to_testflight.sh` builds fine on the Mac mini, but its last step is refused: “exportArchive Failed to Use Accounts: App Store Connect access for 2U9RH88978 is required.” It worked on October 6. Xcode’s own Organizer window on the mini still uploads, so the account is signed in there; only the command-line tool cannot use it. The cause is not known. The likely one is that Mikey’s Apple password changed on October 6 after that day’s upload. Things to try at the mini: remove and re-add the account under Xcode, Settings, Accounts; watch for a keychain permission dialog during a command-line upload and click Always Allow.

Until that is fixed, a copy goes up by hand on the mini: Xcode, Window, Organizer, select the archive, Distribute App, TestFlight Internal Only, Distribute.

A ready copy is waiting there: “Scorebook WITH TEAM,” version 0.1 (202610101443), same app and same team as the October 6 copy. It has not been uploaded. Nothing depends on it: it only restarts the 90 days.

Two traps met on October 10:

- **Never upload an archive made with Xcode’s Product, Archive.** It has no team inside (31 MB against 275 MB), so a tester opens an empty app, and its build number is 1. One went up as build 1 on October 10 and was expired the same hour. Only the script puts the team in.
- **The script cannot be run over a remote login to the mini.** Signing fails there because the signing key is locked to the logged-in desktop, and a background job started in the desktop session cannot read Dropbox. Run it from a Claude session on the mini itself, or from a Terminal window there.

Reaching the mini’s screen from the laptop works through Screen Sharing (`vnc://192.168.0.21`, no password asked), and Claude can click there, but only while the laptop is unlocked and on the home network or its VPN.
