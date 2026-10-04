// swift-tools-version: 6.0
//
// ScorebookUI: every part of the scorebook that draws on screen or plays sound.
// It needs Xcode and the iPhone simulator to build.
//
// This file is written once by the foundation job and owned by the lead builder.
// Every module the plan calls for is declared here already, so no other builder
// ever needs to edit it: adding files inside your own folder is enough.
//
// Who may use whom:
// - DesignSystem and WalkUpAudio use only Model.
// - BoxScorePicture uses Model, SampleData (for its previews), BoxScoreText and DesignSystem.
// - Every screen module uses Model, SampleData and DesignSystem, and nothing else.
//   Screens never use GameEngine, Stats, Storage or WalkUpAudio; the app shell
//   connects them.

import PackageDescription

/// The three modules every screen is allowed to use.
let screenDependencies: [Target.Dependency] = [
    .product(name: "Model", package: "ScorebookCore"),
    .product(name: "SampleData", package: "ScorebookCore"),
    "DesignSystem",
]

let package = Package(
    name: "ScorebookUI",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .library(name: "WalkUpAudio", targets: ["WalkUpAudio"]),
        .library(name: "BoxScorePicture", targets: ["BoxScorePicture"]),
        .library(name: "TeamScreens", targets: ["TeamScreens"]),
        .library(name: "PregameScreens", targets: ["PregameScreens"]),
        .library(name: "AtBatScreen", targets: ["AtBatScreen"]),
        .library(name: "PlayEntry", targets: ["PlayEntry"]),
        .library(name: "GameChanges", targets: ["GameChanges"]),
        .library(name: "GameOverview", targets: ["GameOverview"]),
        .library(name: "PostgameScreens", targets: ["PostgameScreens"]),
    ],
    dependencies: [
        // The no-screen half of the app, next door in app/Packages/ScorebookCore.
        .package(path: "../ScorebookCore"),
    ],
    targets: [
        // Colors, type, spacing, buttons and the field drawing. The Resources folder
        // is there for anything the designer wants to bundle, such as an asset catalog.
        .target(
            name: "DesignSystem",
            dependencies: [.product(name: "Model", package: "ScorebookCore")],
            resources: [.process("Resources")]
        ),

        // Song library, walk-up songs, the announcer and pitchers' warm-up songs.
        // The Resources folder holds any sound the module itself ships with.
        .target(
            name: "WalkUpAudio",
            dependencies: [.product(name: "Model", package: "ScorebookCore")],
            resources: [.process("Resources")]
        ),

        // The newspaper-style box score picture and the share sheet.
        .target(
            name: "BoxScorePicture",
            dependencies: [
                .product(name: "Model", package: "ScorebookCore"),
                .product(name: "SampleData", package: "ScorebookCore"),
                .product(name: "BoxScoreText", package: "ScorebookCore"),
                "DesignSystem",
            ],
            resources: [.process("Resources")]
        ),

        // Teams, rosters, the song library screen and song assignment.
        .target(name: "TeamScreens", dependencies: screenDependencies),

        // Game setup and lineups.
        .target(name: "PregameScreens", dependencies: screenDependencies),

        // The batting screen.
        .target(name: "AtBatScreen", dependencies: screenDependencies),

        // The in-play sequence and runner confirmation.
        .target(name: "PlayEntry", dependencies: screenDependencies),

        // Substitutions, pitching changes, added hitters, runner moves between pitches.
        .target(name: "GameChanges", dependencies: screenDependencies),

        // The game-so-far screen and batter history.
        .target(name: "GameOverview", dependencies: screenDependencies),

        // End of game, box score sharing, season stats.
        .target(name: "PostgameScreens", dependencies: screenDependencies),

        // Tests of the design system's plain functions, such as the field drawing's baseball
        // logic. Run on an iPhone simulator:
        //   xcodebuild test -scheme ScorebookUI-Package -destination 'platform=iOS Simulator,name=iPhone 17'
        // Screen builders may add their own test folders here through the lead builder.
        .testTarget(
            name: "DesignSystemTests",
            dependencies: ["DesignSystem", .product(name: "Model", package: "ScorebookCore")]
        ),

        // One test target per screen module and the audio module, so each builder can test
        // the plain functions behind their screens without editing this file.
        .testTarget(
            name: "AtBatScreenTests",
            dependencies: ["AtBatScreen", .product(name: "Model", package: "ScorebookCore"),
                           .product(name: "SampleData", package: "ScorebookCore")]
        ),
        .testTarget(
            name: "PlayEntryTests",
            dependencies: ["PlayEntry", .product(name: "Model", package: "ScorebookCore"),
                           .product(name: "SampleData", package: "ScorebookCore")]
        ),
        .testTarget(
            name: "GameChangesTests",
            dependencies: ["GameChanges", .product(name: "Model", package: "ScorebookCore"),
                           .product(name: "SampleData", package: "ScorebookCore")]
        ),
        .testTarget(
            name: "TeamScreensTests",
            dependencies: ["TeamScreens", .product(name: "Model", package: "ScorebookCore"),
                           .product(name: "SampleData", package: "ScorebookCore")]
        ),
        .testTarget(
            name: "PregameScreensTests",
            dependencies: ["PregameScreens", .product(name: "Model", package: "ScorebookCore"),
                           .product(name: "SampleData", package: "ScorebookCore")]
        ),
        .testTarget(
            name: "GameOverviewTests",
            dependencies: ["GameOverview", .product(name: "Model", package: "ScorebookCore"),
                           .product(name: "SampleData", package: "ScorebookCore")]
        ),
        .testTarget(
            name: "PostgameScreensTests",
            dependencies: ["PostgameScreens", .product(name: "Model", package: "ScorebookCore"),
                           .product(name: "SampleData", package: "ScorebookCore")]
        ),
        .testTarget(
            name: "WalkUpAudioTests",
            dependencies: ["WalkUpAudio", .product(name: "Model", package: "ScorebookCore"),
                           .product(name: "SampleData", package: "ScorebookCore")]
        ),
    ]
)
