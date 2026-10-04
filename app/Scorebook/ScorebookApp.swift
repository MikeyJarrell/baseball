// TEMPORARY iPad test harness — not to be committed. Opens a screen chosen by launch argument:
//   -demo atbat:<index into SampleSituations.all>
//   -demo changes:<GameChangesDemoSheet raw value>

import SwiftUI
import Model
import SampleData
import AtBatScreen
import GameChanges

@main
struct ScorebookApp: App {
    var body: some Scene {
        WindowGroup {
            HarnessRoot()
        }
    }
}

struct HarnessRoot: View {
    var body: some View {
        let args = ProcessInfo.processInfo.arguments
        let demo = args.firstIndex(of: "-demo").flatMap { args.indices.contains($0 + 1) ? args[$0 + 1] : nil } ?? ""
        let parts = demo.split(separator: ":").map(String.init)
        if parts.first == "atbat", let i = Int(parts.last ?? ""), SampleSituations.all.indices.contains(i) {
            let sample = SampleSituations.all[i]
            let now = (sample.situation.currentInningStartedAt ?? sample.setup.scheduledStart).addingTimeInterval(12 * 60)
            AtBatScreen(setup: sample.setup, situation: sample.situation,
                        batterHistory: SamplePlateAppearances.byPlayer[sample.situation.batter ?? ""] ?? [],
                        songs: SampleSongs.library, undoLabel: "ball",
                        clock: { _ in simpleClock(for: sample.situation, at: now) },
                        onAction: { _ in })
        } else if parts.first == "changes", let sheet = GameChangesDemoSheet(rawValue: parts.last ?? "") {
            GameChangesDemo(start: sheet)
        } else if parts.first == "changes" {
            GameChangesDemo()
        } else {
            HomePlaceholderView()
        }
    }
}
