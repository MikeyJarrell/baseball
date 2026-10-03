# Architecture

The technical skeleton every builder works inside. The plain-English version of the plan is in [README.md](README.md); the standing orders for builders are in [rules-for-agents.md](rules-for-agents.md).

## Platform

A native iPhone app written in Swift with SwiftUI (Apple’s current toolkit for building screens), minimum iOS 18. It runs on iPad too, using the iPhone layout until an iPad layout is built. It works with no internet connection, because ballfields often have none. All data lives on the phone.

## Project layout

Almost all code lives in two local Swift packages: folders of code modules the app imports. Adding a file to a package module changes nothing outside that module’s folder, so builders working in parallel do not collide in Xcode’s project file, which merges badly.

The two packages split along one line. `ScorebookCore` holds everything that involves no screen and no sound, uses only Apple’s basic Foundation library, and builds and tests on a Mac with `swift test` and no Xcode. `ScorebookUI` holds everything that draws or plays audio, and needs Xcode and the iPhone simulator.

```
app/
  Scorebook.xcodeproj            Thin app shell. Owned by the lead builder.
  Scorebook/                     App entry point, navigation, wiring, app icon, settings.
  Packages/
    ScorebookCore/
      Package.swift              Written once by the foundation job.
      Sources/
        Model/                   Shared vocabulary. Owned by the lead builder.
        SampleData/              Made-up teams, situations and games for building, previews and tests. Owned by the lead builder.
        GameEngine/              Events in, situation out.
        Stats/                   Games in, box scores and season totals out.
        BoxScoreText/            Box score in, newspaper-style text out.
        Storage/                 Saving and loading.
      Tests/
        Scenarios/               Game situations with known right answers, as JSON files.
        TestSupport/             Loads the scenario files for any test module. Written by the foundation job.
        GameEngineTests/
        StatsTests/
        BoxScoreTextTests/
        StorageTests/
    ScorebookUI/
      Package.swift              Written once by the foundation job. Depends on ScorebookCore.
      Sources/
        DesignSystem/            Colors, type, buttons, the field drawing.
        WalkUpAudio/             Song library and playback.
        BoxScorePicture/         Box score in, newspaper-style picture out.
        TeamScreens/             Teams, rosters, song assignment.
        PregameScreens/          Game setup and lineups.
        AtBatScreen/             The batting screen.
        PlayEntry/               The in-play sequence and runner confirmation.
        GameChanges/             Substitutions, pitching changes, added hitters, runner moves between pitches.
        GameOverview/            Game so far, batter history.
        PostgameScreens/         End of game, box score sharing, season stats.
```

Who depends on whom:

- `Model` depends on nothing.
- `SampleData`, `GameEngine`, `Stats`, `BoxScoreText` and `Storage` depend on `Model` only. Stats reads the rules engine’s play log, whose shape is defined in `Model`, so the two can be built at the same time.
- `StatsTests` also uses `GameEngine`, to turn scenario files into play logs; until the engine lands, stats tests use the hand-written play log in `SampleData`.
- `DesignSystem` and `WalkUpAudio` depend on `Model`.
- `BoxScorePicture` depends on `Model`, `BoxScoreText` and `DesignSystem`.
- Every screen module depends on `Model`, `SampleData` and `DesignSystem`, and on nothing else. The field drawing’s interface is stubbed by the foundation job, so screens can use it before the designer finishes it. Screens never import `GameEngine`, `Stats`, `Storage` or `WalkUpAudio`.
- The app shell depends on everything and is the only place the pieces meet.

## The shared vocabulary

This is the agreement between builders. The foundation job writes it as real Swift in `Model/`; the sketch below gives the intent, and the code in `Model/` is the final word. Every type is `Codable` (can be saved as JSON), `Equatable` and `Sendable`. The packages use the Swift 6 language mode. Changes after the foundation lands go through the lead builder (see [rules-for-agents.md](rules-for-agents.md)).

**People and teams.** `Player` has an id, name, optional jersey number, optional batting side (right, left, switch), optional throwing hand, an optional walk-up song id, and an optional announcer introduction (a recording made in the app or imported, or a setting to use the phone’s speech voice). `Team` has an id, name, whether it is our team, and a roster. Opponent teams are saved too, so their rosters can be reused the next time we play them. A player can be created mid-game with only a number, or nothing at all (“Batter 4”), and filled in later.

**Positions.** The standard scorebook numbers: 1 pitcher, 2 catcher, 3 first base, 4 second base, 5 third base, 6 shortstop, 7 left field, 8 center field, 9 right field. Also “extra hitter” for a batter in the order who does not play the field, which our league’s long lineups need.

**Game setup.** Date, our team, opponent, whether we are home, scheduled innings (nine by default), an optional time limit, each team’s starting batting order, starting fielding positions and starting pitcher, and which hitters are designated non-runners (declared before the game; when one reaches base, the player who made their team’s most recent out may run for them, or they can run themselves).

**Batting order.** A list of slots, always of known length. Each slot holds the history of who has batted there (the last one is current) and that player’s fielding position. A team whose hitters are unknown gets placeholder players in each slot (“Batter 1” to “Batter 9” by default), named later. The list can grow during the game: adding a hitter appends a slot. The order wraps from the last slot to the first, however many slots there are. A player can appear in the history of a slot more than once, for leagues that allow re-entry.

**Events.** A game is its setup plus an ordered list of events. Each event carries an id and the time it was entered. The kinds:

| Event | Meaning |
|---|---|
| Pitch | Ball, called strike, swinging strike, foul, foul tip (a strike, and strike three with two strikes), foul bunt, hit by pitch. A third strike can carry a dropped-third-strike play: the batter thrown out at first (K 2-3) or reaching base. |
| Intentional walk | Batter awarded first with no pitches thrown |
| Ball in play | One complete play: see below. Counts as a pitch. |
| Runner action | Between pitches: one or more runners each with a reason (stolen base, caught stealing, pickoff, wild pitch, passed ball, balk, advance on error, defensive indifference, out on appeal), the fielders who made any out, and any error. A double steal is one event. |
| Error with no advance | An error charged to a fielder with nobody moving, such as a dropped foul pop-up |
| Substitution | Pinch hitter, pinch runner, defensive replacement, position switch. Several fielding changes made at once are one event. |
| Defense confirmed | The scorer checked our fielders at the start of a half-inning and nothing had changed. Changes found during the check are recorded as a substitution. |
| Runner for a designated non-runner | A runner who takes the base when a designated non-runner reaches and chooses not to run, without a substitution. By league rule it is the player who made the team’s most recent out. The designated non-runner stays in the batting order and is credited with the run if the runner scores. Stolen bases and caught stealing go to whoever actually ran. A pinch runner is an ordinary substitution. |
| Pitching change | New pitcher for the fielding team |
| Add hitter | Appends a slot to a team’s batting order |
| Manual adjustment | Set outs, score, runners or count directly, for when the field and the book disagree and nobody can say why |
| End of game | Marks the game final |

**A play** records what happened to the batter (out, single, double, triple, home run, reached on error, fielder’s choice, sacrifice fly, sacrifice bunt, reached on dropped third strike, catcher’s interference), the kind of batted ball if known (ground ball, fly ball, line drive, pop-up, bunt), the fielders in the order they handled the ball, optionally where the ball went on the field (for a spray chart later), and where every runner, batter included, ended up: which base, scored, or out, with the fielders who made the out and any error that let a runner move, including a batter who takes an extra base on an error after a hit (a single plus an error, “1B 7, E7”). Runners are identified by player id, so a play still means the same thing if an earlier event is edited. It records whether it was a double or triple play, and the final count of runs batted in, as confirmed by the scorer.

**The situation** is what the rules engine works out from the events: inning and half, outs, balls and strikes, score, who is on each base and which pitcher is responsible for each of those runners, the batter and on-deck hitter, which team is batting, each team’s current pitcher and fielders, every pitcher’s pitches and strikes, the last play in scorebook notation, and whether regulation is complete.

**The play log** is the rules engine’s other output: one record per event, saying what that event meant in context. Batter, pitcher charged, fielders on the field, bases and outs before and after, runs scored and the pitcher responsible for each, scorebook notation, whether a plate appearance ended and how, and a “needs review” flag when an event no longer makes sense after an earlier one was edited. Stats are computed from the play log, so the rules of the game live in one place. `SampleData` includes a hand-written play log for the complete sample game, so stats can be built before the engine exists.

**Service interfaces.** These are declared in `Model` as protocols (a list of functions a piece promises to provide), so screens and tests can use stand-ins while the real piece is being built:

- Rules engine: situation and play log after a list of events; suggested runner outcomes and runs batted in for a play given the current situation; suggested runner outcomes for a runner action between pitches (a steal, a pickoff, a wild pitch or balk that moves every runner); the runner to offer first when a designated non-runner reaches base (the teammate who made the team’s most recent out); a preview of a play in progress (its notation so far, the outs and runs it would produce, whether it ends the inning); scorebook notation for an event (“6-3”, “F8”, “E6”, “1B 7” for a single to left, “K”, “ꓘ” for called strike three, “BB”).
- Stats: box score for a game from its play log; season totals for a list of play logs; one player’s plate appearances in a game, in scorebook notation.
- Storage: list, load and save teams, games, songs and app settings; save one new event; find the game in progress. Lists come back with the files that read cleanly plus any damaged files, so one broken game never hides the others. Its functions are asynchronous (they finish in the background).
- Walk-up audio, which runs on the main thread except for copying files in, which runs in the background: import a file, list songs, set a start point, cue, play (with or without the announcer introduction first), fade out, stop, play and stop the between-innings playlist, whether something is playing, and a signal when playback ends on its own. Screens can watch it and redraw when it changes.

## How screens talk to the rest

A screen receives plain data (a situation, a lineup, a list of plate appearances) and returns what the scorer did as a value: a new event, or a request such as “open the in-play sequence.” It holds no game state of its own beyond what is on screen, and never computes anything about baseball. Where a screen needs baseball worked out while the scorer is still tapping, as the in-play sequence does, it is handed a function that does the work, and uses a stand-in from `SampleData` until wiring.

During the build, each screen runs with the made-up data in `SampleData`. During wiring, the app shell feeds it real data from the rules engine and stats.

## Saving

Each game is a JSON file of its setup and events, rewritten after every event so a dead battery loses nothing. Teams and the song list are JSON files; song audio is copied into the app’s own storage on import. The app’s files show up in the iPhone Files app so a backup can be copied off the phone. Song files never go into Git.

## Rules the app follows

The app records what happened. It counts balls, strikes and outs, advances forced runners, switches sides after the third out, and suggests what most likely happened to the runners on a play. It never decides whether a run counts, whether a substitution is legal, or whether a batter batted out of order; the scorer decides, and the manual adjustment event is there for anything else. Any rule the engine applies can be overridden.
