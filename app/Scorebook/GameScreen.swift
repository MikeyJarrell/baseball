// The game being scored: the batting screen, everything that opens from it, and the
// end-of-game box score.
//
// The batting screen and the sheets hand back what the scorer did; this view passes it to
// the game session (which saves it, then replays the game) or to the audio player, and opens
// the next screen:
//   - the in-play sequence, full screen, for "In play" and "Dropped 3rd strike";
//   - the sheets for runner moves, pitching changes, substitutions, the batter, the time
//     limit, manual adjustments and errors;
//   - two prompts the game raises by itself: the defense check when our team takes the
//     field, and "who runs?" when a designated non-runner reaches base;
//   - the game overview (the Box score button, or a swipe to the left);
//   - and, once the scorer ends the game, the final box score.
//
// It also keeps the walk-up song for our next hitter loaded, plays our pitcher's warm-up
// song when our team takes the field, and keeps the phone from locking while a game is open.

import SwiftUI
import UIKit
import Model
import DesignSystem
import Scoring
import WalkUpAudio
import AtBatScreen
import PlayEntry
import GameChanges
import PostgameScreens
import BoxScoreText

/// A sheet that slides up over the batting screen.
enum GameSheet: Identifiable, Equatable {
    case runnerActions(PlayerID)
    case pitchingChange
    case batter
    case changes
    case timeLimit
    case defenseCheck
    case nonRunner
    case manualAdjustment
    case error
    case songSettings
    case pickSong(PlayerID)

    var id: String {
        switch self {
        case .runnerActions(let id): "runner-\(id.rawValue)"
        case .pickSong(let id): "song-\(id.rawValue)"
        default: String(describing: self)
        }
    }
}

/// A screen that covers the batting screen completely.
enum GameCover: Identifiable, Equatable {
    /// The in-play sequence, opened from this situation.
    case playEntry(PlayEntryStart, Situation)
    /// The game overview.
    case overview

    var id: String {
        switch self {
        case .playEntry(let start, _): "play-\(start)"
        case .overview: "overview"
        }
    }
}

/// The game being scored.
struct GameScreen: View {
    @Environment(AppModel.self) private var app
    var session: GameSession
    /// Called to go back to the home screen.
    var onLeave: () -> Void

    /// The sheet the scorer opened, if any.
    @State private var sheet: GameSheet?
    /// The full-screen page open, if any.
    @State private var cover: GameCover?
    /// True right after Undo or Redo, so stepping back over a changeover does not start the
    /// warm-up song again.
    @State private var lastChangeWasUndo = false

    var body: some View {
        Group {
            if session.isFinished {
                FinalBoxScore(session: session, onLeave: onLeave)
            } else {
                batting
            }
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = app.settings.keepScreenAwakeDuringGames
            cueOurNextHitter()
            // Play ball with our team in the field first: the warm-up song for our pitcher.
            if session.game.events.allSatisfy({ !$0.isScorerPlay }), session.setup.weAreHome { playWarmUp() }
        }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .overlay(alignment: .topLeading) {
            if app.isUITest { TestReadout(session: session) }
        }
        .onChange(of: session.situation) { old, new in
            situationChanged(from: old, to: new)
        }
        .onChange(of: session.isFinished) { _, finished in
            if finished { Task { await app.gameEnded() } }
        }
        .alert("Not saved", isPresented: Binding(get: { session.saveProblem != nil },
                                                 set: { if !$0 { session.saveProblem = nil } })) {
            Button("OK", role: .cancel) { session.saveProblem = nil }
        } message: {
            Text(session.saveProblem ?? "")
        }
    }

    // MARK: The batting screen

    private var batting: some View {
        AtBatScreen(
            setup: session.setup,
            situation: session.situation,
            batterHistory: session.batterHistory,
            songs: app.audio?.library ?? SongLibrary(),
            settings: app.settings,
            songPlayback: songPlayback,
            undoLabel: session.undoLabel,
            redoLabel: session.redoLabel,
            clock: { [session] now in session.clock(at: now) },
            countAfter: { [session] pitch in session.countAfter(pitch) },
            onAction: handle
        )
        .sheet(item: sheetBinding) { shown in
            sheetContent(shown)
        }
        .fullScreenCover(item: $cover) { shown in
            coverContent(shown)
        }
    }

    /// The sheet to show: the one the scorer opened, or else a prompt the game raised.
    private var sheetBinding: Binding<GameSheet?> {
        Binding(
            get: { sheet ?? prompt },
            set: { newValue in
                // Swiped away: a prompt counts as "Later".
                if newValue == nil {
                    if sheet == nil, let prompt { backOut(of: prompt) }
                    sheet = nil
                }
            }
        )
    }

    /// A prompt the game raises by itself, when nothing else is open.
    private var prompt: GameSheet? {
        guard cover == nil, !session.isFinished, session.situation.gameOverQuestion == nil else { return nil }
        if session.showsDefenseCheck, session.setup.ourSide != nil { return .defenseCheck }
        if session.showsNonRunnerPrompt { return .nonRunner }
        return nil
    }

    /// What the song button shows, from the audio player.
    private var songPlayback: SongPlayback {
        guard let playback = app.audio?.playback else { return .idle }
        switch playback.phase {
        case .idle: return .idle
        case .introduction: return .introduction
        case .warmUp: return .warmUp
        case .song:
            // A walk-up song counts down to its fade; a song preview has no countdown and is
            // never started from this screen.
            if let fadesAt = playback.fadesAt { return .song(endsAt: fadesAt) }
            return .idle
        }
    }

    // MARK: Taps on the batting screen

    private func handle(_ action: AtBatAction) {
        switch action {
        case .record(let event):
            lastChangeWasUndo = false
            Task { await session.record(event) }
        case .undo:
            lastChangeWasUndo = true
            Task { await session.undo() }
        case .redo:
            lastChangeWasUndo = true
            Task { await session.redo() }
        case .openInPlay(.ballInPlay):
            cover = .playEntry(.inPlay, session.situation)
        case .openInPlay(.droppedThirdStrike):
            if let before = session.situationBeforeStrikeThree { cover = .playEntry(.droppedThirdStrike, before) }
        case .openRunnerActions(let runner):
            sheet = .runnerActions(runner)
        case .openPitchingChange:
            sheet = .pitchingChange
        case .openBatterOptions:
            sheet = .batter
        case .openSubstitutions:
            sheet = .changes
        case .openBoxScore:
            cover = .overview
        case .openTimeLimit:
            sheet = .timeLimit
        case .openDefenseCheck:
            sheet = .defenseCheck
        case .openManualAdjustment:
            sheet = .manualAdjustment
        case .openErrorWithNoAdvance:
            sheet = .error
        case .openSongSettings:
            sheet = .songSettings
        case .pickSong(let player):
            sheet = .pickSong(player)
        case .playWalkUp(let player, let withIntroduction):
            app.audio?.playWalkUp(for: player, withIntroduction: withIntroduction && app.settings.playIntroductions)
        case .playWarmUp(let player):
            app.audio?.playWarmUp(for: player)
        case .stopSong:
            app.audio?.stop()
        case .fadeOutSong:
            app.audio?.fadeOut()
        }
    }

    // MARK: Sheets

    /// The setup and situation, as the sheets want them.
    private var context: GameChangeContext {
        GameChangeContext(setup: session.setup, situation: session.situation)
    }

    @ViewBuilder
    private func sheetContent(_ shown: GameSheet) -> some View {
        let done = { (result: GameChangeResult) in finish(result, from: shown) }
        switch shown {
        case .runnerActions(let runner):
            RunnerActionSheet(
                context: context, runner: runner,
                suggest: { [session] reason, runners in
                    session.engine.suggestRunnerAction(reason, runners: runners, in: session.situation)
                },
                followsStrikeout: RunnerActionBuilder.followsStrikeout(log: session.log, situation: session.situation),
                onFinish: done)
        case .pitchingChange:
            PitchingChangeSheet(context: context, onFinish: done)
        case .batter:
            BatterSheet(context: context, onFinish: done)
        case .changes:
            ChangesMenuSheet(context: context, onFinish: done)
        case .timeLimit:
            TimeLimitSheet(context: context, onFinish: done)
        case .defenseCheck:
            DefenseSheet(context: context, purpose: .check, onFinish: done)
        case .nonRunner:
            NonRunnerSheet(context: context, onFinish: done)
        case .manualAdjustment:
            ManualAdjustmentSheet(context: context, onFinish: done)
        case .error:
            ErrorSheet(context: context, onFinish: done)
        case .songSettings:
            SongSettingsSheet()
        case .pickSong(let player):
            SongPickerSheet(player: player) { song in
                sheet = nil
                if let song { Task { await giveWalkUpSong(song, to: player) } }
            }
        }
    }

    /// Acts on what a sheet handed back, then closes it.
    private func finish(_ result: GameChangeResult, from shown: GameSheet) {
        sheet = nil
        switch result {
        case .record(let entered):
            lastChangeWasUndo = false
            Task {
                guard await session.record(entered) else { return }
                // Players typed in on the spot (a new pitcher by number) go on the saved team too.
                for addition in entered.newPlayers {
                    await app.updateSavedPlayer(addition.player, teamID: session.setup[addition.side].teamID)
                }
            }
        case .updatePlayer(let edit):
            Task {
                guard await session.updatePlayer(edit.player, on: edit.side) else { return }
                await app.updateSavedPlayer(edit.player, teamID: session.setup[edit.side].teamID)
            }
        case .nothingToRecord:
            if shown == .nonRunner { session.letNonRunnerRun() }
        case .cancel:
            backOut(of: shown)
        }
    }

    /// The scorer closed a prompt without answering: keep it closed until the next event.
    private func backOut(of shown: GameSheet) {
        switch shown {
        case .defenseCheck: session.postponeDefenseCheck()
        case .nonRunner: session.postponeNonRunnerPrompt()
        default: break
        }
    }

    /// Gives one of our players a walk-up song, in this game and on the saved team.
    private func giveWalkUpSong(_ song: SongID, to id: PlayerID) async {
        guard let side = session.setup.side(of: id), var player = session.setup.player(id) else { return }
        player.walkUpSongID = song
        guard await session.updatePlayer(player, on: side) else { return }
        await app.updateSavedPlayer(player, teamID: session.setup[side].teamID)
        app.audio?.cue(for: player)
    }

    // MARK: Full-screen pages

    @ViewBuilder
    private func coverContent(_ shown: GameCover) -> some View {
        switch shown {
        case .playEntry(let start, let situation):
            PlayEntryView(situation: situation, setup: session.setup, start: start,
                          rules: PlayEntryRules(engine: session.engine)) { outcome in
                cover = nil
                lastChangeWasUndo = false
                switch outcome {
                case .ballInPlay(let event): Task { await session.record(event) }
                case .droppedThirdStrike(let play): Task { await session.addDroppedThirdStrike(play) }
                case .cancelled: break
                }
            }
        case .overview:
            OverviewPage(session: session, onClose: { cover = nil })
        }
    }

    // MARK: Songs

    /// After every change: load our next hitter's walk-up song, and when our team has just
    /// taken the field, play our pitcher's warm-up song.
    private func situationChanged(from old: Situation, to new: Situation) {
        if old[ourSideOrAway].currentBatter != new[ourSideOrAway].currentBatter { cueOurNextHitter() }
        let tookTheField = takingTheField(new) && !takingTheField(old)
        if tookTheField, !lastChangeWasUndo { playWarmUp() }
    }

    /// Our side, or the visitors in a game between two other teams (no songs are played then).
    private var ourSideOrAway: TeamSide { session.setup.ourSide ?? .away }

    /// True at the changeover when our team is about to take the field.
    private func takingTheField(_ situation: Situation) -> Bool {
        guard let ours = session.setup.ourSide else { return false }
        return situation.isBetweenHalfInnings && situation.fieldingSide == ours && !situation.isFinal
    }

    /// Loads our next hitter's walk-up song (and announcer introduction), so it starts the
    /// moment the scorer taps it.
    private func cueOurNextHitter() {
        guard let ours = session.setup.ourSide,
              let next = session.situation[ours].currentBatter,
              let player = session.setup.player(next) else { return }
        app.audio?.cue(for: player)
    }

    /// Plays our pitcher's warm-up song, if they have one.
    private func playWarmUp() {
        guard let ours = session.setup.ourSide,
              let pitcher = session.situation[ours].pitcher,
              let player = session.setup.player(pitcher), player.warmUpSongID != nil else { return }
        app.audio?.playWarmUp(for: player)
    }
}

extension GameEvent {
    /// True for anything that happened on the field: a pitch, a play, a runner move. False for
    /// lineup business before the first pitch (the defense check, a batting hole).
    var isScorerPlay: Bool {
        switch kind {
        case .defenseConfirmed, .battingHole, .timeLimitChange: false
        default: true
        }
    }
}

/// The final box score, once the scorer ends the game: the newspaper picture, the share
/// button, copy as text, and a way back to scoring if the game was ended by mistake.
struct FinalBoxScore: View {
    @Environment(AppModel.self) private var app
    var session: GameSession
    var onLeave: () -> Void
    /// True while the "go back to scoring?" question is open.
    @State private var askingToReopen = false

    var body: some View {
        NavigationStack {
            BoxScorePage(box: session.boxScore, ourSide: session.setup.ourSide, showsDoneButton: true) { request in
                switch request {
                case .done: onLeave()
                case .copyBoxScoreText:
                    UIPasteboard.general.string = BoxScorePrinter.text(session.boxScore)
                default: break
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Not over") { askingToReopen = true }
                }
            }
            .confirmationDialog("Take back the end of the game and keep scoring?", isPresented: $askingToReopen,
                                titleVisibility: .visible) {
                Button("Keep scoring") { Task { await session.undo() } }
            }
        }
    }
}

/// For simulator tests only: an invisible line of text holding the number of events, the
/// last event, where the game stands and, once it is over, the printed box score, so a test
/// can check every step against the game it is scoring. Never shown on Mikey's phone.
struct TestReadout: View {
    var session: GameSession

    var body: some View {
        Text(readout)
            .font(.system(size: 1))
            .opacity(0.02)
            .frame(width: 1, height: 1)
            .accessibilityIdentifier("test-readout")
            .accessibilityLabel(Text(readout))
    }

    private var readout: String {
        var fields: [String: Any] = [
            "count": session.game.events.count,
            "line": session.situation.checkLine,
        ]
        if let last = session.game.events.last,
           let data = try? ScorebookJSON.encode(last),
           var object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            object["id"] = nil
            object["enteredAt"] = nil
            object["formatVersion"] = nil
            fields["last"] = object
        }
        if session.isFinished { fields["box"] = BoxScorePrinter.text(session.boxScore) }
        guard let data = try? JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys]) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }
}
