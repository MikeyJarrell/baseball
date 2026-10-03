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
    ],
    targets: [
        // The shared vocabulary: players, teams, events, plays, the situation, box scores.
        // Depends on nothing.
        .target(name: "Model"),

        // Made-up teams, situations and one complete game, for building, previews and tests.
        .target(name: "SampleData", dependencies: ["Model"]),

        // The rules engine: events in, situation and play log out.
        .target(name: "GameEngine", dependencies: ["Model"]),

        // Play logs in, box scores and season totals out.
        .target(name: "Stats", dependencies: ["Model"]),

        // A box score in, newspaper-style text out.
        .target(name: "BoxScoreText", dependencies: ["Model"]),

        // Saving and loading teams, games and the song list as JSON files.
        .target(name: "Storage", dependencies: ["Model"]),

        // Test helper: bundles the Tests/Scenarios folder and loads a scenario in one line.
        // It lives under Tests/ so the scenario files sit beside the tests that use them.
        // The test folders are excluded so this module only picks up its own code.
        .target(
            name: "TestSupport",
            dependencies: ["Model", "SampleData"],
            path: "Tests",
            exclude: [
                "ModelTests", "GameEngineTests", "StatsTests",
                "BoxScoreTextTests", "StorageTests",
            ],
            sources: ["TestSupport"],
            resources: [.copy("Scenarios")]
        ),

        // Tests of the shared vocabulary and sample data. Owned by the lead builder.
        .testTarget(name: "ModelTests", dependencies: ["Model", "SampleData", "TestSupport"]),

        // Tests of the rules engine.
        .testTarget(name: "GameEngineTests", dependencies: ["GameEngine", "Model", "SampleData", "TestSupport"]),

        // Tests of the stats. These also use the rules engine, to turn scenario files into play logs.
        .testTarget(name: "StatsTests", dependencies: ["Stats", "GameEngine", "Model", "SampleData", "TestSupport"]),

        // Tests of the box score text.
        .testTarget(name: "BoxScoreTextTests", dependencies: ["BoxScoreText", "Model", "SampleData", "TestSupport"]),

        // Tests of saving and loading.
        .testTarget(name: "StorageTests", dependencies: ["Storage", "Model", "SampleData", "TestSupport"]),
    ]
)
