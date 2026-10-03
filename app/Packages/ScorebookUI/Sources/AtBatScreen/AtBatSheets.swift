// The two sheets the batting screen opens itself: the game menu (manual adjustment, an error
// with nobody moving, the time limit, editing the batter, the walk-up song length, end game)
// and the "Is the game over?" pop-up. Neither records anything itself: each hands its choice
// back to the screen as an `AtBatAction`.

import SwiftUI
import Model
import DesignSystem

/// The game menu, from the button at the top left of the band.
struct GameMenuSheet: View {
    var info: AtBatInfo
    /// Called with the scorer's choice, which also closes the menu; nothing means just close.
    var choose: (AtBatAction?) -> Void

    /// Whether the end-game choices are showing.
    @State private var confirmingEnd = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    row("Manual adjustment", detail: "Set outs, count, score or runners", icon: "slider.horizontal.3") {
                        choose(.openManualAdjustment)
                    }
                    row("Error, nobody moved", detail: "Like a dropped foul pop-up", icon: "xmark.circle") {
                        choose(.openErrorWithNoAdvance)
                    }
                    if let line = AtBatWording.limitLine(info.clock) {
                        row("Time limit", detail: line, icon: "clock") { choose(.openTimeLimit) }
                    }
                    row("Edit this batter", detail: "Name, number, batting side", icon: "pencil") {
                        choose(.openBatterOptions)
                    }
                    row("Walk-up song length",
                        detail: "\(Int(info.settings.walkUpSongSeconds.rounded())) seconds of song, then it fades",
                        icon: "speaker.wave.2") {
                        choose(.openSongSettings)
                    }
                }
                Section {
                    Button(role: .destructive) { confirmingEnd = true } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("End game").font(ScorebookFont.headline)
                                Text("Time limit reached, or the last out").font(ScorebookFont.caption)
                            }
                        } icon: {
                            Image(systemName: "flag.checkered")
                        }
                        .foregroundStyle(ScorebookColor.out)
                        .frame(minHeight: Spacing.minimumTapSize)
                    }
                }
            }
            .navigationTitle("Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { choose(nil) }
                }
            }
            .confirmationDialog("End the game?", isPresented: $confirmingEnd, titleVisibility: .visible) {
                ForEach(endReasons, id: \.self) { reason in
                    Button(AtBatWording.endGameChoice(reason), role: .destructive) {
                        choose(.record(GameEvent(kind: .endOfGame(EndOfGame(reason: reason, finalScore: info.situation.score)))))
                    }
                }
            } message: {
                Text(AtBatWording.scoreLine(info.setup, info.situation.score))
            }
        }
        .presentationDetents([.medium, .large])
    }

    /// The reasons to offer, the one the rules engine is asking about first.
    private var endReasons: [EndOfGame.Reason] {
        var reasons: [EndOfGame.Reason] = [.regulation, .timeLimit, .runRule, .called]
        if let asked = info.gameOverQuestion, let i = reasons.firstIndex(of: asked) {
            reasons.remove(at: i)
            reasons.insert(asked, at: 0)
        }
        return reasons
    }

    /// One menu row: an icon, a title over a smaller line, and a chevron.
    private func row(_ title: String, detail: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.medium) {
                Image(systemName: icon)
                    .font(.body.weight(.semibold))
                    .frame(width: 28)
                    .foregroundStyle(ScorebookColor.inPlay)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(ScorebookFont.headline)
                    Text(detail).font(ScorebookFont.caption).foregroundStyle(ScorebookColor.textSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(ScorebookColor.textSecondary)
            }
            .foregroundStyle(ScorebookColor.textPrimary)
            .frame(minHeight: Spacing.minimumTapSize)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// "Is the game over?": asked when the time limit or the run rule says the game could be over.
/// The app never ends a game by itself. End game records the end; Keep playing records the
/// answer, and the same reason is not asked again.
struct GameOverSheet: View {
    var info: AtBatInfo
    var reason: EndOfGame.Reason
    var choose: (AtBatAction) -> Void

    var body: some View {
        VStack(spacing: Spacing.large) {
            Text("Is the game over?")
                .font(ScorebookFont.title)
            Text(AtBatWording.scoreLine(info.setup, info.situation.score))
                .font(ScorebookFont.scoreboardSmall)
                .multilineTextAlignment(.center)
            Text("\(AtBatWording.gameOverReason(reason, setup: info.setup, clock: info.clock)) The umpire makes the call; the app only asks.")
                .font(ScorebookFont.body)
                .foregroundStyle(ScorebookColor.textSecondary)
                .multilineTextAlignment(.leading)
                .padding(Spacing.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ScorebookColor.surfaceSecondary, in: RoundedRectangle(cornerRadius: Spacing.cornerRadius, style: .continuous))
            Spacer(minLength: 0)
            Button {
                choose(.record(GameEvent(kind: .endOfGame(EndOfGame(reason: reason, finalScore: info.situation.score)))))
            } label: {
                Text("End game").frame(maxWidth: .infinity)
            }
            .buttonStyle(TeamButtonStyle(.ours))
            Button {
                choose(.record(GameEvent(kind: .keepPlaying(KeepPlaying(reason: reason)))))
            } label: {
                Text("Keep playing").frame(maxWidth: .infinity)
            }
            .buttonStyle(PlainActionButtonStyle())
        }
        .foregroundStyle(ScorebookColor.textPrimary)
        .padding(Spacing.large)
        .presentationDetents([.medium, .large])
        // Only the two buttons close it: the scorer has to answer.
        .interactiveDismissDisabled()
    }
}
