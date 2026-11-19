// The two sheets the batting screen opens itself: the game menu, full screen, in five groups
// (game details, rosters, manual adjustment, music and PA, exit game)
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
    /// Whether "Delete this game?" is showing.
    @State private var confirmingDelete = false

    var body: some View {
        NavigationStack {
            List {
                Section("Game details") {
                    row("Date, start, innings, home and away", detail: nil, icon: "calendar") {
                        choose(.openGameDetails)
                    }
                    if let line = AtBatWording.limitLine(info.clock) {
                        row("Time limit", detail: line, icon: "clock") { choose(.openTimeLimit) }
                    }
                }
                Section("Rosters") {
                    row("Lineups and rosters", detail: "Both teams: names, numbers, batting order", icon: "list.number") {
                        choose(.openLineups)
                    }
                    row("Edit this batter", detail: "Name, number, batting side", icon: "pencil") {
                        choose(.openBatterOptions)
                    }
                }
                Section("Manual adjustment") {
                    row("Fix a play or a pitch", detail: "Every play so far", icon: "list.bullet.rectangle") {
                        choose(.openPlayFixing)
                    }
                    row("Set outs, count, score or runners", detail: nil, icon: "slider.horizontal.3") {
                        choose(.openManualAdjustment)
                    }
                }
                Section("Music and PA") {
                    if let pitcher = ourPitcher {
                        row("Warm-up songs", detail: pitcher.displayName, icon: "music.note.list") {
                            choose(.pickWarmUpSongs(pitcher))
                        }
                    }
                    row("Walk-up songs, length and introductions",
                        detail: "\(Int(info.settings.walkUpSongSeconds.rounded())) seconds of song",
                        icon: "speaker.wave.2") {
                        choose(.openSongSettings)
                    }
                }
                Section("Exit game") {
                    row("Pause and go to the home screen", detail: "Resume it from there any time", icon: "pause.circle") {
                        choose(.goHome)
                    }
                    Button(role: .destructive) { confirmingEnd = true } label: {
                        Label("End game", systemImage: "flag.checkered")
                            .font(ScorebookFont.headline)
                            .foregroundStyle(ScorebookColor.out)
                            .frame(minHeight: Spacing.minimumTapSize)
                    }
                    Button(role: .destructive) { confirmingDelete = true } label: {
                        Label("Delete this game", systemImage: "trash")
                            .font(ScorebookFont.headline)
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
            .alert("Do you really want to delete this game?", isPresented: $confirmingDelete) {
                Button("Delete game", role: .destructive) { choose(.deleteGame) }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("All the data will be lost.")
            }
        }
    }

    /// Our pitcher now, when our team has one in the game.
    private var ourPitcher: Player? {
        guard let ours = info.setup.ourSide else { return nil }
        return info.situation[ours].pitcher.flatMap(info.setup.player)
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
    private func row(_ title: String, detail: String?, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.medium) {
                Image(systemName: icon)
                    .font(.body.weight(.semibold))
                    .frame(width: 28)
                    .foregroundStyle(ScorebookColor.inPlay)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(ScorebookFont.headline)
                    if let detail { Text(detail).font(ScorebookFont.caption).foregroundStyle(ScorebookColor.textSecondary) }
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
            Text(AtBatWording.gameOverReason(reason, setup: info.setup, clock: info.clock))
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
