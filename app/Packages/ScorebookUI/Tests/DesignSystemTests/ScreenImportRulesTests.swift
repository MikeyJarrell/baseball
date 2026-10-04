// Checks the rule from plan/architecture.md that screens use only Model, SampleData and
// DesignSystem. SampleData itself uses the rules engine, so the compiler would let a screen
// import GameEngine too; this test reads every screen's source files and fails if one does.
// The simulator can read the Mac's files, so the test finds the sources from its own path.

import XCTest

final class ScreenImportRulesTests: XCTestCase {
    /// The modules that hold screens.
    static let screenModules = ["TeamScreens", "PregameScreens", "AtBatScreen", "PlayEntry",
                                "GameChanges", "GameOverview", "PostgameScreens"]

    /// Modules no screen may import: the app shell connects screens to these.
    static let forbidden = ["GameEngine", "Stats", "Storage", "WalkUpAudio"]

    func testScreensImportOnlyWhatTheyMay() throws {
        // This file is in ScorebookUI/Tests/DesignSystemTests; the sources are in ScorebookUI/Sources.
        let sources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources")
        var checked = 0
        for module in Self.screenModules {
            let folder = sources.appendingPathComponent(module)
            let files = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil)?
                .compactMap { $0 as? URL }
                .filter { $0.pathExtension == "swift" } ?? []
            XCTAssertFalse(files.isEmpty, "No source files found for \(module) at \(folder.path)")
            for file in files {
                checked += 1
                let lines = try String(contentsOf: file, encoding: .utf8).split(separator: "\n")
                for line in lines {
                    let words = line.split(separator: " ").map(String.init)
                    guard let i = words.firstIndex(of: "import"), i + 1 < words.count else { continue }
                    // "import X", "@testable import X", "@_exported import X", "import struct X.Y"
                    guard words[..<i].allSatisfy({ $0.hasPrefix("@") }) else { continue }
                    let imported = words.dropFirst(i + 1).first { !["struct", "class", "enum", "func", "protocol", "var", "let", "typealias"].contains($0) }
                    let module = imported?.split(separator: ".").first.map(String.init) ?? ""
                    XCTAssertFalse(Self.forbidden.contains(module),
                                   "\(file.lastPathComponent) imports \(module); screens may use only Model, SampleData and DesignSystem")
                }
            }
        }
        XCTAssertGreaterThan(checked, 0)
    }
}
