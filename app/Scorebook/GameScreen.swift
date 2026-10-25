// The game being scored: the batting screen, everything that opens from it, and the
// end-of-game box score.
//
// The batting screen and the sheets hand back what the scorer did; this view passes it to
// the game session (which saves it, then replays the game) or to the audio player, and opens
// the next screen:
//   - the in-play sequence, full screen, for "In play" and "Dropped 3rd strike";
//   - the sheets for runner moves, pitching changes, substitutions (with lineups and rosters),
//     the batter, the time limit, the game details, manual adjustments, errors and our
//     pitcher's warm-up songs;
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
import PregameScreens
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
    case gameDetails
    case lineups
    case warmUpSongs(PlayerID)
    /// Record one of our players' names for their announcer introduction.
    case recordName(PlayerID)

    var id: String {
        switch self {
        case .runnerActions(let id): "runner-\(id.rawValue)"
        case .pickSong(let id): "song-\(id.rawValue)"
        case .warmUpSongs(let id): "warm-up-\(id.rawValue)"
        case .recordName(let id): "name-\(id.rawValue)"
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
            // Our players' songs and introductions as the saved team has them now.
            setup: withThisWarmUp(app.withSavedSongs(session.setup)),
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
        // The defense check opens by itself every time our team takes the field. After a
        // strikeout for the third out it carries a "Dropped third strike instead" link, since the
        // batter may yet be safe and the half-inning go on.
        if session.showsDefenseCheck, session.setup.ourSide != nil { return .defenseCheck }
        if session.showsNonRunnerPrompt { return .nonRunner }
        return nil
    }

    /// What the song button shows, from the audio player.
    private var songPlayback: SongPlayback {
        guard let playback = app.audio?.playback else { return .idle }
        // A walk-up being kept playing shows that way from the moment it is asked for, the
        // introduction included.
        if playback.keepsPlaying { return .keptPlaying }
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
            openDroppedThirdStrike()
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
        case .openGameDetails:
            sheet = .gameDetails
        case .openLineups:
            sheet = .lineups
        case .deleteGame:
            let id = session.game.id
            app.audio?.stop()
            onLeave()
            Task { await app.deleteGame(id) }
        case .pickWarmUpSongs(let pitcher):
            sheet = .warmUpSongs(pitcher.id)
        case .goHome:
            onLeave()
        case .playWalkUp(let player, let withIntroduction):
            app.audio?.playWalkUp(for: player, withIntroduction: withIntroduction && app.settings.playIntroductions)
        case .playWarmUp(let player):
            app.audio?.playWarmUp(for: player)
        case .keepSongPlaying:
            app.audio?.keepWalkUpPlaying()
        case .stopSong:
            // A two-second fade, the same for walk-up and warm-up songs; a second tap while it
            // fades stops it at once.
            if app.audio?.isFadingOut == true { app.audio?.stop() } else { app.audio?.fadeOut() }
        case .fadeOutSong:
            app.audio?.fadeOut()
        }
    }

    /// Opens the dropped-third-strike steps from just before the strike-three pitch. From the
    /// defense check, the check closes first ("Later" until the next event); if the inning still
    /// ends, the next event brings it back by itself.
    private func openDroppedThirdStrike() {
        guard let before = session.situationBeforeStrikeThree else { return }
        if sheet == nil, prompt == .defenseCheck { session.postponeDefenseCheck() }
        sheet = nil
        // Let the check slide away before the full-screen steps come up.
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            cover = .playEntry(.droppedThirdStrike, before)
        }
    }

    // MARK: Sheets

    /// The setup and situation, as the sheets want them.
    private var context: GameChangeContext {
        GameChangeContext(setup: session.setup, situation: session.situation,
                          startingOrderOpen: Set(TeamSide.allCases.filter(session.canChangeStartingOrder)))
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
            DefenseSheet(context: context, purpose: .check,
                         onDroppedThirdStrike: session.situation.droppedThirdStrikePossible ? { openDroppedThirdStrike() } : nil,
                         onFinish: done)
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
        case .gameDetails:
            GameDetailsSheet(context: context, canSwitchHomeAndAway: session.canSwitchHomeAndAway, onFinish: done)
        case .lineups:
            LineupEditorPage(setup: session.setup, onDone: { away, home in
                sheet = nil
                Task { await applyRosters(away: away, home: home) }
            }, onCancel: { sheet = nil })
            .presentationDetents([.large])
            .interactiveDismissDisabled()
        case .warmUpSongs(let pitcher):
            if let player = session.setup.player(pitcher), let side = session.setup.side(of: pitcher) {
                WarmUpSongsSheet(pitcher: player, teamID: session.setup[side].teamID) { sheet = nil }
            }
        case .recordName(let id):
            if let player = session.setup.player(id) {
                // The saved team's introduction, which may be newer than the game's copy.
                NameRecordingSheet(player: app.withSavedSongs(player)) { kept in
                    sheet = nil
                    if let kept { Task { await app.setNameIntroduction(kept, for: id) } }
                }
            }
        }
    }

    /// Acts on what a sheet handed back, then closes it, unless the sheet asked to stay open
    /// (the lineups page, while the scorer works through a lineup card).
    private func finish(_ result: GameChangeResult, from shown: GameSheet) {
        if case .keepOpen(let change) = result {
            apply(change, from: shown)
            return
        }
        sheet = nil
        apply(result, from: shown)
    }

    /// Acts on what a sheet handed back.
    private func apply(_ result: GameChangeResult, from shown: GameSheet) {
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
        case .correctLineup(let correction):
            Task {
                guard await session.correctLineup(correction) else { return }
                // Someone typed in from a lineup card goes on the saved team too.
                if case .wasReally(let side, _, let really) = correction {
                    await app.updateSavedPlayer(really, teamID: session.setup[side].teamID)
                }
                cueOurNextHitter()
            }
        case .changeDetails(let details):
            Task {
                // A refused switch says why (the "Not saved" message) and changes nothing else.
                if details.switchHomeAndAway { guard await session.switchHomeAndAway() else { return } }
                await session.changeDetails { setup in
                    setup.scheduledStart = details.scheduledStart
                    setup.rules.scheduledInnings = details.innings
                }
                cueOurNextHitter()
            }
        case .keepOpen(let change):
            apply(change, from: shown)
        case .recordName(let edit):
            Task {
                // Any edits first (a name typed in just now), then the recorder.
                if edit.player != session.setup.player(edit.player.id) {
                    guard await session.updatePlayer(edit.player, on: edit.side) else { return }
                    await app.updateSavedPlayer(edit.player, teamID: session.setup[edit.side].teamID)
                }
                await openNameRecorder(for: edit.player.id)
            }
        case .recordThenRecordName(let entered, let player):
            Task {
                lastChangeWasUndo = false
                guard await session.record(entered) else { return }
                for addition in entered.newPlayers {
                    await app.updateSavedPlayer(addition.player, teamID: session.setup[addition.side].teamID)
                }
                await openNameRecorder(for: player)
            }
        }
    }

    /// Puts the lineups fixed on Rosters into the game, one team at a time, and saves anyone
    /// new to their saved team.
    private func applyRosters(away: GameTeam, home: GameTeam) async {
        for (side, team) in [(TeamSide.away, away), (.home, home)] {
            let before = session.setup[side]
            guard team.roster != before.roster || team.battingOrder != before.battingOrder || team.defense != before.defense
                    || team.designatedNonRunners != before.designatedNonRunners || team.fieldingRotations != before.fieldingRotations
            else { continue }
            guard await session.editStartingLineup(team, on: side) else { return }
            for player in team.roster where before.player(player.id) != player && !player.isUnnamed {
                await app.updateSavedPlayer(player, teamID: team.teamID)
            }
        }
        cueOurNextHitter()
    }

    /// Opens the name recorder once the sheet before it has slid away.
    private func openNameRecorder(for id: PlayerID) async {
        try? await Task.sleep(for: .milliseconds(450))
        sheet = .recordName(id)
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
        await app.setWalkUpSong(song, for: id, teamID: session.setup[side].teamID)
        app.cueOurNextHitter()
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
                // Back from the dropped-third-strike steps (saved or not): if our team still
                // takes the field, the defense check opens again.
                if start == .droppedThirdStrike { session.reopenDefenseCheck() }
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
        // Back at bat after all (a dropped third strike that turned the third out around, an
        // Undo or a fix stepping back over the changeover): the warm-up song stops and our
        // hitter's walk-up song is ready again.
        if let ours = session.setup.ourSide, takingTheField(old), new.battingSide == ours {
            if app.audio?.playback.phase == .warmUp { app.audio?.fadeOut() }
            cueOurNextHitter()
        }
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
        app.cueOurNextHitter()
    }

    /// Plays our pitcher's warm-up song for this changeover, if he has one.
    private func playWarmUp() {
        guard let ours = session.setup.ourSide,
              let pitcher = session.situation[ours].pitcher,
              let saved = session.setup.player(pitcher) else { return }
        let player = withThisInningsWarmUp(app.withSavedSongs(saved))
        guard player.warmUpSongID != nil else { return }
        app.audio?.playWarmUp(for: player)
    }

    /// The setup with our pitcher's warm-up song set to the one for this inning, so the song
    /// button names it and plays it.
    private func withThisWarmUp(_ setup: GameSetup) -> GameSetup {
        guard let side = setup.ourSide, let pitcher = session.situation[side].pitcher else { return setup }
        var updated = setup
        switch side {
        case .away: updated.away.roster = setup.away.roster.map { $0.id == pitcher ? withThisInningsWarmUp($0) : $0 }
        case .home: updated.home.roster = setup.home.roster.map { $0.id == pitcher ? withThisInningsWarmUp($0) : $0 }
        }
        return updated
    }

    /// Our pitcher with his warm-up song for the inning about to start: his main song the first
    /// inning he starts, one of his extra songs after that (WarmUpRotation).
    private func withThisInningsWarmUp(_ pitcher: Player) -> Player {
        guard let ours = session.setup.ourSide else { return pitcher }
        let started = WarmUpRotation.inningsStarted(by: pitcher.id, fielding: ours, before: session.situation.inning,
                                                    session.situation.half, in: session.log)
        var updated = pitcher
        updated.warmUpSongID = WarmUpRotation.song(for: pitcher, inningsStarted: started, game: session.game.id)
        return updated
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
                Button("Keep scoring") {
                    Task {
                        await session.undo()
                        // The game is unfinished again: take it out of the season and games list.
                        await app.reloadGames()
                    }
                }
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
