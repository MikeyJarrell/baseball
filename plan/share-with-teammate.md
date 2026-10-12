# Putting the Scorebook on a teammate’s iPhone

**Goal:** Erick Rosas Lopez scores Diamond Dogs games on his own iPhone while Mikey is out of town, with the team, songs and announcer introductions already in the app, and without his phone ever being plugged into Mikey’s Mac.

**Status:** October 10, 2026. Erick (erickrosaslopez6@gmail.com) accepted his App Store Connect invitation and is in the internal testing group “Team,” which holds build 202610061426 (uploaded October 6 with the team from the phone backup of 14:14 that day; it expires 90 days after upload) and build 202610101443 (uploaded October 10, same team). Apple has emailed him the install button; his status reads “Invited” until he installs. The group has automatic distribution on, so every later upload reaches him with no further step. He has [his instructions](teammate-instructions.md). Mikey is out of town from October 6.

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
| 4 | Mikey or Claude | Add Erick as a user with the Marketing role, limited to the Scorebook, and add him to an internal test group. Done October 10 |
| 5 | Mikey | Text him [teammate-instructions.md](teammate-instructions.md) |
| 6 | Teammate | Follows the instructions; Mikey checks he can see the Diamond Dogs and hear a walk-up song |

Allow a day between steps 3 and 6: Apple takes anywhere from minutes to a few hours to process a new upload before it can be tested.

## The season’s games on a teammate’s phone

Since October 11, 2026 the TestFlight copy also carries the games saved on Mikey’s phone, taken from the same phone backup as the team. Each time the app opens, every finished game the phone has not been offered before is copied in, so the games list, box scores and season stats show the season so far. A phone that got its team from an earlier copy gets the games on its first opening of the new one. The rules (`StarterGames.swift` in Storage, with tests):

- A game the phone already has is left exactly as it is. On Mikey’s own phone nothing changes.
- A game deleted on a phone stays deleted. The phone keeps a small list of the games it has been offered (`starter-games.json` beside its saved files).
- When a later copy carries a corrected version of a game, it replaces the one copied in before, unless that game was changed on the phone.
- Games still in progress are never copied.

A game only reaches the testers through an upload, and an upload takes its games from the newest phone backup. After a game: plug the phone in, run `tools/publish_stats.sh` for the website as before, make a backup (any run of `tools/load_team.sh` makes one), then `tools/upload_to_testflight.sh`.

The October 4 game in build BUILD_NUMBER_HERE comes from the backup of 14:14 on October 6, made just before Jackson Cleary was moved into the starting order. Testers therefore see him indented like a substitute in that box score; every stat is the same. The next upload made after a fresh phone backup corrects it on their phones by itself.

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

What Claude can and cannot do in App Store Connect, when Mikey is signed in to it in Chrome: it can read every page, add an accepted person to the test group, and expire a build. It is blocked from inviting a new person to the account, so Mikey fills in that form (Users and Access, +, Marketing role).

## Uploading a new copy

`tools/upload_to_testflight.sh` on the Mac mini builds the app with the team inside and uploads it, with no Xcode sign-in. From October 6 to 10 the command-line upload was refused (“App Store Connect access for 2U9RH88978 is required”) although Xcode’s Organizer window could still upload; Mikey’s password change on October 6 is the likely cause, never confirmed. Since October 10 the script uses an App Store Connect key instead, and signs with its own distribution certificate, so Xcode’s sign-in no longer matters. What it uses, all in `~/.appstoreconnect/` on the mini and outside Git:

- `private_keys/AuthKey_6X6QWG95X7.p8`: Mikey’s App Store Connect key (issuer 7e8e45fc-8082-464c-bd53-f51f2f45f798). It has no access to Apple’s cloud-managed signing, which is why the certificate below exists.
- `distribution/signing.keychain-db`: the Apple Distribution certificate (made through the API on October 10, runs to October 10, 2027) and its private key, in a keychain of their own that the script unlocks with `distribution/keychain-password`. In the login keychain, signing stopped for a permission dialog on the mini’s screen.
- The “Scorebook App Store” provisioning profile, made through the API and installed in Xcode’s profiles folder.

The internal group “Team” has access to every build, so a processed upload reaches Erick with no further step.

Build 202610101443 (“Scorebook WITH TEAM”) went up this way on October 10 at 16:11, finished processing that evening, and is open to the “Team” group. Mikey was added to the group the same evening; Matthew Glatt’s TestFlight invitation was resent twice, since he had not received it (an AOL address).

Two traps met on October 10:

- **Never upload an archive made with Xcode’s Product, Archive.** It has no team inside (31 MB against 275 MB), so a tester opens an empty app, and its build number is 1. One went up as build 1 on October 10 and was expired the same hour. Only the script puts the team in.
- **The script could not be run over a remote login to the mini.** Signing failed there because the signing key was locked to the logged-in desktop, and a background job started in the desktop session cannot read Dropbox. The signing key now sits in its own keychain that the script unlocks, which may lift the first problem; not tried. Run it from a Claude session on the mini itself, or from a Terminal window there.

Reaching the mini’s screen from the laptop works through Screen Sharing (`vnc://192.168.0.21`, no password asked), and Claude can click there, but only while the laptop is unlocked and on the home network or its VPN.

A second copy waits in Xcode’s Organizer on the mini: version 0.1 (202610101536), built by the script on October 10 with the team inside and the seven-step game setup (the opponent on its own screen). It has not been uploaded, and it is the one to send if testers should get the new setup screens; running the script again builds a fresh copy with the same code.

The script did build and sign that copy over a remote login, with two workarounds: it was started as a one-time background job in the desktop session (`launchctl bootstrap gui/501` with a small job file), and the newest phone backup’s `Library/Application Support/Scorebook` folder was first copied to a plain folder, which the script was handed as the backup to use. The upload step was then refused with the account error that the key has since fixed.
