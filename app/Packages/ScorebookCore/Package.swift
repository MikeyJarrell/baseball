// swift-tools-version: 6.0
//
// ScorebookCore: every part of the scorebook that has no screen and makes no sound.
// It uses only Apple's basic Foundation library, so it builds and tests on a Mac
// with `swift test` and no Xcode.
//
// This file is written once by the foundation job and owned by the lead builder.
// Every module and test module the plan calls for is declared here already, so no
// other builder ever needs to edit it: adding files inside your own folder is enough.

import PackageDescription

let package = Package(
    name: "ScorebookCore",
    // iOS 18 is the oldest iPhone software the app supports. macOS 15 lets the
    // package build and run its tests on the Mac.
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        // One library per module, so the app and ScorebookUI can import exactly what they use.
        .library(name: "Model", targets: ["Model"]),
        .library(name: "SampleData", targets: ["SampleData"]),
        .library(name: "GameEngine", targets: ["GameEngine"]),
        .library(name: "Stats", targets: ["Stats"]),
        .library(name: "BoxScoreText", targets: ["BoxScoreText"]),
        .library(name: "Storage", targets: ["Storage"]),
        .library(name: "Scoring", targets: ["Scoring"]),
        .library(name: "TeamImport", targets: ["TeamImport"]),
        .executable(name: "TeamLoader", targets: ["TeamLoader"]),
        .executable(name: "StatsSite", targets: ["StatsSite"]),
    ],
    targets: [
        // The shared vocabulary: players, teams, events, plays, the situation, box scores.
        // Depends on nothing.
        .target(name: "Model"),

        // Made-up teams, situations and one complete game, for building, previews and tests.
        // It also hands screens the real rules engine for previews (`SampleRulesEngine`), so
        // screens never import GameEngine themselves.
        .target(name: "SampleData", dependencies: ["Model", "GameEngine"]),

        // The rules engine: events in, situation and play log out.
        .target(name: "GameEngine", dependencies: ["Model"]),

        // Play logs in, box scores and season totals out.
        .target(name: "Stats", dependencies: ["Model"]),

        // A box score in, newspaper-style text out.
        .target(name: "BoxScoreText", dependencies: ["Model"]),

        // Saving and loading teams, games and the song list as JSON files.
        .target(name: "Storage", dependencies: ["Model"]),

        // One game being scored: saves each event through storage, replays the game through
        // the rules engine and works out the box score. The app shell holds one while a game
        // is open.
        .target(name: "Scoring", dependencies: ["Model", "GameEngine", "Stats"]),

        // Turning the roster files in the repository's team/ folder into saved teams and
        // songs, merged with whatever the app already has.
        .target(name: "TeamImport", dependencies: ["Model"]),

        // The Mac command the loader script (tools/load_team.sh) runs on a copy of the
        // phone's saved files.
        .executableTarget(name: "TeamLoader", dependencies: ["Model", "Storage", "TeamImport"]),

        // The Mac command the stats website script (tools/publish_stats.sh) runs on a copy of
        // the phone's saved files, to write the public stats pages.
        .executableTarget(name: "StatsSite", dependencies: ["Model", "Storage", "GameEngine", "Stats", "BoxScoreText"]),

        // Test helper: bundles the Tests/Scenarios folder and loads a scenario in one line.
        // It lives under Tests/ so the scenario files sit beside the tests that use them.
        // The test folders are excluded so this module only picks up its own code.
        .target(
            name: "TestSupport",
            dependencies: ["Model", "SampleData"],
            path: "Tests",
            exclude: [
                "ModelTests", "GameEngineTests", "StatsTests",
                "BoxScoreTextTests", "StorageTests", "ScoringTests", "TeamImportTests",
            ],
            sources: ["TestSupport"],
            resources: [.copy("Scenarios")]
        ),

        // Tests of the shared vocabulary and sample data. Owned by the lead builder.
        .testTarget(name: "ModelTests", dependencies: ["Model", "SampleData", "TestSupport"]),

        // Tests of the rules engine. A few also build a box score, to check what the engine hands stats.
        .testTarget(name: "GameEngineTests", dependencies: ["GameEngine", "Stats", "Model", "SampleData", "TestSupport"]),

        // Tests of the stats. These also use the rules engine, to turn scenario files into play logs.
        .testTarget(name: "StatsTests", dependencies: ["Stats", "GameEngine", "Model", "SampleData", "TestSupport"]),

        // Tests of the box score text.
        .testTarget(name: "BoxScoreTextTests", dependencies: ["BoxScoreText", "Model", "SampleData", "TestSupport"]),

        // Tests of saving and loading.
        .testTarget(name: "StorageTests", dependencies: ["Storage", "Model", "SampleData", "TestSupport"]),

        // Tests of scoring a game: saving each event, undo and redo, automatic outs, and whole
        // games scored event by event matching their box scores.
        // Tests of reading the roster files and merging them with saved teams.
        .testTarget(name: "TeamImportTests", dependencies: ["TeamImport", "Model"]),

        .testTarget(name: "ScoringTests", dependencies: ["Scoring", "Storage", "GameEngine", "Stats", "Model", "SampleData", "TestSupport"]),
    ]
)
