// The announcer step, shown only when one of our hitters has no recorded name (a player new
// today, or one never recorded): a Record button beside each, opening the app's recorder, so
// the announcer can say "Now batting, number 27, Ed Hunter." Skipping it is fine; the name
// can be recorded later from the game menu's Music and PA.

import SwiftUI
import Model
import DesignSystem

/// Record names for the announcer before the game.
struct AnnouncerStep: View {
    @Binding var draft: PregameDraft
    /// Players recorded since setup began.
    var recordedNames: Set<PlayerID>
    /// Opens the recorder for one player.
    var onRecord: (Player) -> Void
    var onNext: () -> Void

    /// Everyone who had no recorded name when the step opened, so a row stays after recording.
    @State private var shown: [Player] = []

    var body: some View {
        StepPage(step: .announcer, title: "Announcer", buttonTitle: "Next: \(draft.opponentName) lineup", onButton: onNext) {
            Section {
                ForEach(shown) { player in
                    let done = recordedNames.contains(player.id)
                    HStack(spacing: Spacing.medium) {
                        PlayerNumberBadge(PregameWording.badge(player), look: .ours, size: 36)
                        Text(player.displayName).font(ScorebookFont.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button {
                            onRecord(player)
                        } label: {
                            Label(done ? "Recorded" : "Record", systemImage: done ? "checkmark" : "mic.fill")
                        }
                        .buttonStyle(ChipStyle(isOn: !done))
                    }
                    .frame(minHeight: 44)
                    .cardRow()
                }
            } header: {
                SectionHeader(title: "No announcement recorded yet")
            }
        }
        .onAppear {
            if shown.isEmpty { shown = draft.needsNameRecording([]) }
        }
    }
}
