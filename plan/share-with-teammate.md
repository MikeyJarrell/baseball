# Putting the Scorebook on a teammate’s iPhone

**Goal:** a teammate scores Diamond Dogs games on his own iPhone while Mikey is out of town, with the team, songs and announcer introductions already in the app, and without his phone ever being plugged into Mikey’s Mac.

**Status:** planned, October 6, 2026. Nothing below is built yet.

## How he gets the app

Through TestFlight, Apple’s app for installing apps that are not in the App Store, on Mikey’s paid Apple Developer account (team 2U9RH88978, Apple account mikey1004@gmail.com).

TestFlight has two kinds of tester:

- **Internal tester:** someone added to Mikey’s developer account with a limited role. Apple does not review the app first, and he can install new copies the moment they are uploaded. He has to accept one extra email invitation.
- **External tester:** anyone with a link. Simpler for him, but Apple reviews the app before he can install it, and the app carries 24 commercial songs, which Apple’s rules on copyrighted music could trip over.

**Choice: internal tester.** Nothing goes through Apple review and nothing is public. He gets the “Marketing” role (the lowest role that can test), limited to the Scorebook alone; it lets him see the app’s App Store Connect page and nothing else of Mikey’s.

Each TestFlight copy opens for 90 days. Uploading a new copy restarts the 90 days, and his games stay on the phone through updates.

## What has to be built first

1. **The team inside the app.** The TestFlight copy carries a copy of the teams, song list, song files and announcer recordings from Mikey’s phone (from the newest copy in `~/Dropbox/baseball/phone-backups/`, about 175 MB). The first time the app opens with no teams saved, it puts them in place. Copying the phone’s own saved files keeps every player’s identity the same on both phones, which the next step depends on; loading `team/roster.csv` afresh would give each player a new one.
2. **Getting his games back to Mikey.** A “Send games” button that makes one file of the games on his phone and hands it to the share sheet (text, AirDrop or email), and an “Add games from a file” button on Mikey’s phone that adds any game it does not already have, without touching anything else. His games then count in Mikey’s season stats.
3. **Upload settings.** The app declares that it uses no special encryption (`ITSAppUsesNonExemptEncryption` set to NO), so each upload skips Apple’s export question. The build number rises with each upload.
4. **One command to upload.** `tools/upload_to_testflight.sh` builds the app for distribution and sends it to App Store Connect through the account Xcode already has signed in.

## Steps

| Step | Who | What |
|---|---|---|
| 1 | Claude | Build the three pieces above; check them on the simulator, including a game sent from one simulator and added on another |
| 2 | Mikey | Sign in at appstoreconnect.apple.com in the browser pane and accept any agreements Apple shows (Claude cannot enter passwords) |
| 3 | Claude | Create the Scorebook’s App Store Connect page (bundle id `com.mikeyjarrell.scorebook`) and upload the first copy |
| 4 | Claude | Add the teammate as a user with the Marketing role, limited to the Scorebook, and add him to an internal test group. Needs his name and the email address of his Apple account |
| 5 | Mikey | Text him [teammate-instructions.md](teammate-instructions.md) |
| 6 | Teammate | Follows the instructions; Mikey checks he can see the Diamond Dogs and hear a walk-up song |
| 7 | Mikey, on return | Opens the file of games he sends and taps “Add games” |

Allow a day between steps 3 and 6: Apple takes anywhere from minutes to a few hours to process a new upload before it can be tested.

## Roster or song changes while Mikey is away

The copy of the team inside the app only fills an empty app, so it cannot change his team later. A roster change while Mikey is away is typed into the app on the teammate’s phone, the way Mikey would on his own.

## Mikey’s own phone

The app on Mikey’s phone is signed with the paid account, whose permission runs until October 2027, so it needs no weekly reinstall. The install script and [install-on-iphone.md](install-on-iphone.md) still describe the free account and get corrected with step 1.
