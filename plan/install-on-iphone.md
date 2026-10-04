# Putting the Scorebook on your iPhone

The app goes on your phone from the Mac, through Xcode, using your ordinary Apple account. There is no App Store step and nothing to pay. The catch: Apple only lets an app installed this way open for seven days, so once a week you plug the phone in and press one button. Your games, teams and songs stay on the phone through every reinstall.

The phone needs iOS 18 or later (Settings, General, About, iOS Version).

## The first time (about 20 minutes)

1. **Sign Xcode in to your Apple account.** On the Mac, open Xcode. In the menu bar choose Xcode, then Settings, then the Accounts tab. Click the + at the bottom left, choose Apple Account, and sign in with your usual Apple account. When it is done, the list shows your name with “Personal Team” under it.

2. **Open the app in Xcode.** In Xcode choose File, then Open, and open `Scorebook.xcodeproj` in the `app` folder of the baseball project (`/Users/mikey/projects/personal/baseball/app/Scorebook.xcodeproj`).

3. **Tell Xcode to use your account.** In the column on the left, click the blue “Scorebook” at the very top. In the middle, under Targets, click “Scorebook”, then the Signing & Capabilities tab. Check “Automatically manage signing”, and set Team to your name (Personal Team). If a red message says the name `com.mikeyjarrell.scorebook` is not available, change that text in the box beside “Bundle Identifier” to `com.mikeyjarrell.scorebook2` and press Return. A free account can have at most three of your own apps on the phone at once, so if Xcode says you have reached that limit, delete one of the others from the phone (never the Scorebook) and try again.

4. **Plug the phone into the Mac** with a cable. Unlock the phone. If it asks “Trust This Computer?”, tap Trust and type your passcode.

5. **Switch on Developer Mode on the phone.** This is a safety switch Apple adds so that only people who mean to can put their own apps on a phone. On the phone open Settings, then Privacy & Security, scroll to the bottom, and tap Developer Mode. (If it is not there, do step 6 once first; the switch appears after Xcode has seen the phone.) Turn it on and tap Restart. When the phone starts again, tap Turn On and type your passcode.

6. **Install.** In Xcode, at the top middle of the window, click the device name next to “Scorebook” and choose your iPhone from the list. Press the Play button (the triangle at the top left), or Command-R. The first time, Xcode spends a few minutes getting the phone ready; the bar at the top of the window says what it is doing. When it finishes, the Scorebook icon appears on the phone.

7. **Trust yourself as the app’s maker, on the phone, if it asks.** This step may not come up at all: on your phone the app opened the first time. If instead the phone says “Untrusted Developer” and will not open it: Open Settings, then General, then VPN & Device Management. Under Developer App, tap your Apple account’s email address, tap Trust, then Trust again. The phone checks with Apple at this step, so it needs to be on Wi-Fi or cellular data. Now the app opens.

8. **Allow what the app asks for.** The first time you record an announcer introduction, the phone asks to use the microphone: tap Allow.

## Every seven days

Seven days after an install, the app shows a message that it is no longer available and will not open. Your games, teams and songs are all still on the phone.

1. Plug the phone into the Mac and unlock it.
2. Make sure the main project folder has the newest version of the app: ask Claude to bring the baseball project’s main folder up to date (in Terminal, the same thing is `git -C /Users/mikey/projects/personal/baseball pull`). The phone gets whatever version that folder holds.
3. **The easy way:** in Terminal, run

   ```bash
   /Users/mikey/projects/personal/baseball/tools/install_on_phone.sh
   ```

   or ask Claude to run it. It builds the app and puts it on the phone, with no clicking in Xcode, and says “Done” when the phone has it.

   **Or with Xcode:** open `/Users/mikey/projects/personal/baseball/app/Scorebook.xcodeproj` (File, then Open Recent usually has it), choose your iPhone at the top middle, and press the Play button.

That is all. It takes a minute or two. Doing it the morning of every game day means it never runs out mid-game.

## Loading the team and songs

The players, their positions, their walk-up and warm-up songs, and every opponent’s players come from the files in the project’s `team` folder and the song files in Dropbox (`baseball/songs`). To put them on the phone, or to update the phone after the roster changes (a new player, a new song, a new start point), plug the phone in, unlock it, and run in Terminal

```bash
/Users/mikey/projects/personal/baseball/tools/load_team.sh
```

or ask Claude to run it. It first copies everything the app has saved into Dropbox (`baseball/phone-backups`, one folder for each time), then adds the roster and songs, keeping every game, every number typed into the app and every recorded introduction, and finally reads it all back and lists what the phone now has. Players keep their season stats through every update. A start point set in the roster file replaces one moved in the app, so set start points in one place: the roster file.

## Keeping your games safe

- **Never delete the Scorebook app from the phone.** Deleting it deletes its games, teams and songs with it. Reinstalling from Xcode, as above, keeps everything.
- **Backups.** The app writes a backup at the end of every game, and the Backups link at the bottom of the home screen makes one any time. To keep a copy off the phone, open the Files app, then On My iPhone, then Scorebook, then backups, and copy the newest file to iCloud Drive. The same Backups link puts everything back from a backup file, but it lists only the files in Scorebook’s own backups folder. To restore a copy kept in iCloud Drive, first copy it in the Files app from iCloud Drive back into On My iPhone, then Scorebook, then backups; then it appears under Backups.

## If something goes wrong

- **Xcode says the phone is not available or “not connected”.** Unplug and plug the cable back in, unlock the phone, and wait half a minute.
- **Xcode says the developer disk image or the phone’s software is too new.** Update Xcode from the App Store on the Mac, then try again.
- **The app opens to “The scorebook’s saved files could not be opened.”** Do not delete the app. Tell Claude what the message says.
