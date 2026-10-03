# Scorebook app

The iPhone scorebook. The plan is in [../plan/README.md](../plan/README.md); builders follow [../plan/rules-for-agents.md](../plan/rules-for-agents.md).

## Where things live

- `Scorebook.xcodeproj` and `Scorebook/`: the thin app shell (entry point, home screen, app icon, settings). Files added to `Scorebook/` join the app automatically.
- `Packages/ScorebookCore/`: everything with no screen and no sound. Builds and tests on the Mac without Xcode.
  - `Sources/Model/`: the shared vocabulary (players, events, plays, the situation, the play log, box scores) and the service promises (`RulesEngine`, `StatsCalculator`, `ScorebookStorage`, `WalkUpAudioPlayer`) with stand-ins.
  - `Sources/SampleData/`: made-up teams, songs, situations, one complete game with its play log and box score, and a canned rules engine for screens.
  - `Sources/GameEngine/`, `Stats/`, `BoxScoreText/`, `Storage/`: one module per job.
  - `Tests/Scenarios/`: game situations with known right answers, as JSON. Its README explains the format.
  - `Tests/TestSupport/`: loads a scenario in one line and checks answers against it.
- `Packages/ScorebookUI/`: everything that draws or plays sound. Needs Xcode.
  - `Sources/DesignSystem/`: colors, type, spacing, buttons and the field drawing.
  - `Sources/WalkUpAudio/`, `BoxScorePicture/` and one folder per group of screens.

## Running the tests

```sh
cd app/Packages/ScorebookCore
swift test
```

## Building

The screens package, for the iPhone simulator:

```sh
cd app/Packages/ScorebookUI
xcodebuild -scheme ScorebookUI-Package -destination 'platform=iOS Simulator,name=iPhone 17' build
```

The app:

```sh
cd app
xcodebuild -project Scorebook.xcodeproj -scheme Scorebook -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Or open `Scorebook.xcodeproj` in Xcode, pick an iPhone simulator, and press Run.

## Rules of the road

Each module has one owner; the briefs in `../plan/briefs/` say who. `Model/`, `SampleData/`, both `Package.swift` files and the Xcode project belong to the lead builder: every module is already declared, so adding files inside your own folder is all a job needs. Read and write JSON with `ScorebookJSON` so every saved file uses the same format.
