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
            sized(HarnessRoot())
                .onAppear {
                    // -landscape: ask iOS to turn the window sideways.
                    guard ProcessInfo.processInfo.arguments.contains("-landscape") else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
                            scene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight))
                        }
                    }
                }
        }
    }
}

/// -size WxH: lay the screen out at that window size, shrunk to fit, to see a sideways layout.
@ViewBuilder func sized<V: View>(_ v: V) -> some View {
    let args = ProcessInfo.processInfo.arguments
    if let i = args.firstIndex(of: "-size"), args.indices.contains(i + 1) {
        let wh = args[i + 1].split(separator: "x").compactMap { Double($0) }
        GeometryReader { geo in
            let scale = min(geo.size.width / wh[0], 1)
            v.frame(width: wh[0], height: wh[1])
                .clipped()
                .border(.red, width: 2)
                .scaleEffect(scale, anchor: .topLeading)
        }
    } else {
        v
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
