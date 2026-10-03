// Previews of the in-play sequence, each one a demo play from PlayEntryDemos.swift stopped
// part way through, using the demo rules engine. Light, dark and the largest text size.

import SwiftUI
import Model
import SampleData
import DesignSystem

/// A demo play with its first `taps` taps made.
private struct DemoPreview: View {
    var demo: PlayEntryDemo
    var taps: Int

    var body: some View {
        PlayEntryView(model: demo.model(afterTaps: taps))
    }
}

#Preview("Step one: what happened to the batter?") {
    DemoPreview(demo: PlayEntryDemos.groundOut, taps: 0)
}

#Preview("Step one with More open, dark") {
    DemoPreview(demo: PlayEntryDemos.sacrificeFly, taps: 1)
        .preferredColorScheme(.dark)
}

#Preview("6-3 with nobody on: fielders tapped") {
    DemoPreview(demo: PlayEntryDemos.groundOut, taps: 3)
}

#Preview("F8 with a runner on second: runners") {
    DemoPreview(demo: PlayEntryDemos.flyOut, taps: 3)
}

#Preview("Single: where it landed") {
    DemoPreview(demo: PlayEntryDemos.singleRunnerScores, taps: 2)
}

#Preview("Single: runner from second sent home") {
    DemoPreview(demo: PlayEntryDemos.singleRunnerScores, taps: 4)
}

#Preview("5-4-3 double play: fielders") {
    DemoPreview(demo: PlayEntryDemos.doublePlay, taps: 5)
}

#Preview("5-4-3 double play: runners, dark") {
    DemoPreview(demo: PlayEntryDemos.doublePlay, taps: 6)
        .preferredColorScheme(.dark)
}

#Preview("Error by the shortstop: who made it") {
    DemoPreview(demo: PlayEntryDemos.errorBatterToSecond, taps: 2)
}

#Preview("Error by the shortstop: batter to second") {
    DemoPreview(demo: PlayEntryDemos.errorBatterToSecond, taps: 4)
}

#Preview("Fielder’s choice: runners") {
    DemoPreview(demo: PlayEntryDemos.fieldersChoice, taps: 4)
}

#Preview("Sacrifice fly: runners") {
    DemoPreview(demo: PlayEntryDemos.sacrificeFly, taps: 4)
}

#Preview("Single plus the left fielder’s error: 1B 7, E7") {
    DemoPreview(demo: PlayEntryDemos.singlePlusError, taps: 6)
}

#Preview("Dropped third strike") {
    DemoPreview(demo: PlayEntryDemos.droppedThirdStrikeSafe, taps: 0)
}

#Preview("Dropped third strike: K 2-3") {
    DemoPreview(demo: PlayEntryDemos.droppedThirdStrikeOut, taps: 3)
}

#Preview("Largest text: step one") {
    DemoPreview(demo: PlayEntryDemos.groundOut, taps: 0)
        .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Largest text: runners") {
    DemoPreview(demo: PlayEntryDemos.singlePlusError, taps: 6)
        .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Demo gallery") {
    PlayEntryDemoGallery()
}
