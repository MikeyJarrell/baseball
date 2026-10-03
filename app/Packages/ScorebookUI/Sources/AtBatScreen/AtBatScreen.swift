// AtBatScreen: the batting screen, the screen the scorer looks at for nearly the whole game.
//
// Layout A from the approved mockup (plan/mockups/index.html), the field view, top to bottom:
//   1. the band: game menu, which team is batting, the time limit, a Box score button, then
//      the scoreboard (inning, score, a big count, outs);
//   2. the field drawing with the runners, a changeover or time-limit banner across its top,
//      the on-deck hitter in one corner and the pitcher in the other;
//   3. the batter, with what they have done today, and a big Subs button beside them;
//   4. a row of small buttons led by Undo (HBP, IBB, and Foul tip or, after strike three, "Dropped K");
//   5. the 2×2 block of Ball, Strike (with a small Called button), Foul and In play;
//   6. the song button across the bottom edge.
//
// The screen holds no game state. It is handed plain data (the situation, the batter's earlier
// plate appearances, the song library, the settings, what the audio is doing, the undo label)
// and hands back every tap as an `AtBatAction`: an event to record, or a request such as
// "open the in-play sequence". The app shell does the recording and the opening.
//
// The pieces are in the other files of this folder: AtBatBand (the top band), AtBatField (the
// field and its banners), AtBatControls (the batter, the buttons and the song button),
// AtBatSheets (the game menu and "Is the game over?"), AtBatWording (the words on screen) and
// AtBatPreviews.

import SwiftUI
import Model
import SampleData
import DesignSystem

// MARK: - What the screen hands back

/// Everything the scorer can do on the batting screen. The app shell acts on each one.
public enum AtBatAction: Equatable, Sendable {
    /// Record this event in the game: a pitch, an intentional walk, "keep playing" or the end of
    /// the game.
    case record(GameEvent)
    /// Take back the last event (the Undo button).
    case undo
    /// Put back the event just undone (the Redo button, shown only after an undo).
    case redo

    /// Open the in-play sequence: `.ballInPlay` from the In play button, or
    /// `.droppedThirdStrike` from the "Dropped K" button after strike three.
    case openInPlay(PlayDraft.Context)
    /// Open the runner actions (steal, caught stealing, pickoff, wild pitch, passed ball, balk,
    /// advance on error) for the runner the scorer tapped on the field drawing.
    case openRunnerActions(PlayerID)
    /// Open the pitching change: the scorer tapped the pitcher.
    case openPitchingChange
    /// Open the batter's options: pinch hitter, batting side, and the name and number of one of
    /// their hitters.
    case openBatterOptions
    /// Open every kind of change (the big Subs button).
    case openSubstitutions
    /// Open the game overview (the Box score button, or a swipe to the left).
    case openBoxScore
    /// Open the time limit, to match it to the plate umpire's clock.
    case openTimeLimit
    /// Open the defense check for our team at the start of a half-inning.
    case openDefenseCheck
    /// Open the manual adjustment: set outs, count, score or runners directly.
    case openManualAdjustment
    /// Open the sheet for an error with nobody moving, such as a dropped foul pop-up.
    case openErrorWithNoAdvance
    /// Open the walk-up song length setting.
    case openSongSettings
    /// Open the song picker for one of our hitters who has no walk-up song.
    case pickSong(for: PlayerID)

    /// Play our hitter's walk-up song, with the announcer introduction first when asked.
    case playWalkUp(Player, withIntroduction: Bool)
    /// Play our pitcher's warm-up song at the changeover when our team takes the field.
    case playWarmUp(Player)
    /// Stop whatever is playing now (a tap on a playing song button).
    case stopSong
    /// Fade out whatever is playing: a pitch was recorded while the warm-up song played, or
    /// while a walk-up song played with "fade on the first pitch" switched on.
    case fadeOutSong
}

/// What the walk-up audio is doing, so the song button can show it. The app shell reads it
/// from the audio player.
public enum SongPlayback: Equatable, Sendable {
    /// Nothing is playing.
    case idle
    /// The announcer introduction is playing; the song comes next.
    case introduction
    /// The walk-up song is playing and fades out by itself at `endsAt`. The button counts down.
    case song(endsAt: Date)
    /// Our pitcher's warm-up song is playing. It plays until stopped or the first pitch.
    case warmUp
}

// MARK: - The screen

/// The batting screen.
///
/// - Parameters:
///   - setup: The game's setup, for names, numbers, songs and the rules.
///   - situation: Where the game stands, from the rules engine.
///   - batterHistory: The batter's earlier plate appearances today, from stats.
///   - songs: The song library, for song titles.
///   - settings: The app settings: walk-up song length, introductions, fade on the first pitch.
///   - songPlayback: What the walk-up audio is doing now.
///   - undoLabel: What Undo would take back ("ball"), or nothing when there is nothing to undo.
///   - redoLabel: What Redo would put back, right after an undo ("6-3"); nothing hides Redo.
///   - clock: The game clock at a moment, from the rules engine (`RulesEngine.clock(for:at:)`).
///     The screen asks it again every few seconds, so the time left and the "Is the game over?"
///     question keep up with the clock between events.
///   - onAction: Called with everything the scorer taps.
public struct AtBatScreen: View {
    public var setup: GameSetup
    public var situation: Situation
    public var batterHistory: [PlateAppearanceSummary]
    public var songs: SongLibrary
    public var settings: AppSettings
    public var songPlayback: SongPlayback
    public var undoLabel: String?
    public var redoLabel: String?
    public var clock: (Date) -> GameClock
    public var onAction: (AtBatAction) -> Void

    public init(
        setup: GameSetup,
        situation: Situation,
        batterHistory: [PlateAppearanceSummary] = [],
        songs: SongLibrary = SongLibrary(),
        settings: AppSettings = AppSettings(),
        songPlayback: SongPlayback = .idle,
        undoLabel: String? = nil,
        redoLabel: String? = nil,
        clock: ((Date) -> GameClock)? = nil,
        onAction: @escaping (AtBatAction) -> Void
    ) {
        self.setup = setup
        self.situation = situation
        self.batterHistory = batterHistory
        self.songs = songs
        self.settings = settings
        self.songPlayback = songPlayback
        self.undoLabel = undoLabel
        self.redoLabel = redoLabel
        // Without a clock, read the stored facts as they are (the stand-in engines' clock).
        self.clock = clock ?? { [situation] now in simpleClock(for: situation, at: now) }
        self.onAction = onAction
    }

    public var body: some View {
        // Ask the clock again every 15 seconds, so "1:12 left" and the time-limit question keep
        // up between events. Nothing else on the screen depends on the time.
        TimelineView(.periodic(from: .now, by: 15)) { context in
            AtBatLayout(info: AtBatInfo(setup: setup, situation: situation, batterHistory: batterHistory,
                                        songs: songs, settings: settings, songPlayback: songPlayback,
                                        undoLabel: undoLabel, redoLabel: redoLabel, clock: clock(context.date)),
                        onAction: onAction)
        }
    }
}

// MARK: - Everything the screen shows, gathered in one place

/// The screen's inputs plus the clock at this moment, with the lookups the pieces share.
/// Only reading: nothing about the game is worked out here.
struct AtBatInfo {
    var setup: GameSetup
    var situation: Situation
    var batterHistory: [PlateAppearanceSummary]
    var songs: SongLibrary
    var settings: AppSettings
    var songPlayback: SongPlayback
    var undoLabel: String?
    var redoLabel: String?
    var clock: GameClock

    /// True when our team is batting.
    var weAreBatting: Bool { setup.ourSide == situation.battingSide }
    /// True when our team is in the field.
    var weAreFielding: Bool { setup.ourSide == situation.fieldingSide }
    /// The batting team's colors.
    var look: TeamLook { weAreBatting ? .ours : .theirs }
    /// The fielding team's colors.
    var fieldingLook: TeamLook { weAreFielding ? .ours : .theirs }

    /// The batter at the plate. A stand-in "Batter" if the situation names nobody.
    var batter: Player {
        situation.batter.flatMap(setup.player) ?? Player(id: "unknown-batter", placeholder: "Batter")
    }
    /// The hitter on deck, if known.
    var onDeck: Player? { situation.onDeck.flatMap(setup.player) }
    /// The pitcher on the mound, if known.
    var pitcher: Player? { situation.pitcher.flatMap(setup.player) }
    /// The pitcher's pitches and strikes today.
    var pitcherTally: PitcherTally? { situation.pitcher.flatMap(situation.tally(for:)) }

    /// True when the batter's spot is held by a declared designated non-runner.
    var batterIsNonRunner: Bool {
        let team = situation[situation.battingSide]
        guard team.battingOrder.slots.indices.contains(team.nextBatterIndex) else { return false }
        return team.battingOrder.slots[team.nextBatterIndex].isDesignatedNonRunner
    }

    /// The question "Is the game over?" to ask now, if any: the rules engine's own question,
    /// or the clock's time-limit question if the scorer has not already said to keep playing.
    var gameOverQuestion: EndOfGame.Reason? {
        if situation.isFinal { return nil }
        if let question = situation.gameOverQuestion { return question }
        if clock.askIfOverOnTime && !situation.declinedEndings.contains(.timeLimit) { return .timeLimit }
        return nil
    }

    /// What goes in the song spot along the bottom edge.
    var songSpot: SongSpot {
        // At the changeover when our team takes the field: our pitcher's warm-up song.
        if situation.isBetweenHalfInnings, weAreFielding, let pitcher {
            if let id = pitcher.warmUpSongID {
                return .warmUp(pitcher, title: songs.song(id)?.title ?? "Warm-up song")
            }
            return .noWarmUp(pitcher)
        }
        // Our hitter: their walk-up song, or a way to pick one.
        if weAreBatting {
            if let id = batter.walkUpSongID {
                let song = songs.song(id)
                return .walkUp(batter, title: song?.title ?? "Walk-up song",
                               length: song?.playLength ?? settings.walkUpSongSeconds)
            }
            return .noSong(batter)
        }
        // Their hitter: an empty gray bar, so a habit tap plays nothing.
        return .theirs
    }
}

/// What the song spot along the bottom edge holds.
enum SongSpot {
    /// Our hitter's walk-up song, with its title and how many seconds play before it fades.
    case walkUp(Player, title: String, length: TimeInterval)
    /// Our hitter has no walk-up song: tap to pick one.
    case noSong(Player)
    /// Our pitcher's warm-up song, at the changeover when we take the field.
    case warmUp(Player, title: String)
    /// Our pitcher has no warm-up song.
    case noWarmUp(Player)
    /// Their hitter: an empty gray bar.
    case theirs
}

// MARK: - The layout

/// The batting screen's layout, top to bottom, at one moment of the clock.
struct AtBatLayout: View {
    var info: AtBatInfo
    var onAction: (AtBatAction) -> Void

    /// Whether the game menu is open. Only what is on screen; no game state.
    @State private var showingMenu = false
    /// The "Is the game over?" question the scorer has just answered, so the pop-up closes at
    /// once instead of waiting for the app to record the answer.
    @State private var answeredQuestion: EndOfGame.Reason?

    var body: some View {
        VStack(spacing: 0) {
            AtBatBand(info: info, onAction: onAction, openMenu: { showingMenu = true })
            AtBatFieldArea(info: info, onAction: onAction)
                // The field takes whatever height is left, so everything else stays on screen.
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(-1)
            AtBatControls(info: info, onAction: recordWithFade)
                .padding(.horizontal, Spacing.screenEdge)
                .padding(.top, Spacing.small)
                .padding(.bottom, Spacing.small)
        }
        .background(ScorebookColor.background.ignoresSafeArea())
        // A swipe to the left opens the game overview, as in the mockup.
        .simultaneousGesture(
            DragGesture(minimumDistance: 30).onEnded { drag in
                if drag.translation.width < -80, abs(drag.translation.height) < 60 { onAction(.openBoxScore) }
            }
        )
        .accessibilityAction(named: Text("Box score")) { onAction(.openBoxScore) }
        .sheet(isPresented: $showingMenu) {
            GameMenuSheet(info: info) { action in
                showingMenu = false
                if let action { onAction(action) }
            }
        }
        .sheet(isPresented: Binding(
            get: { info.gameOverQuestion != nil && info.gameOverQuestion != answeredQuestion },
            set: { _ in }
        )) {
            if let question = info.gameOverQuestion {
                GameOverSheet(info: info, reason: question) { action in
                    answeredQuestion = question
                    onAction(action)
                }
            }
        }
        // Once the question goes away (the answer was recorded), forget the answer, so an undo
        // that brings the question back shows it again.
        .onChange(of: info.gameOverQuestion) { _, question in
            if question == nil { answeredQuestion = nil }
        }
    }

    /// Hands back a tap from the buttons. A pitch, a ball in play or an intentional walk is
    /// the first pitch of the moment, so it also fades the warm-up song, and the walk-up song
    /// when "fade on the first pitch" is switched on and the batter has not had a pitch yet.
    private func recordWithFade(_ action: AtBatAction) {
        if action.isPitchLike {
            switch info.songPlayback {
            case .warmUp:
                onAction(.fadeOutSong)
            case .introduction, .song:
                if info.settings.fadeSongOnFirstPitch && info.situation.count == .fresh { onAction(.fadeOutSong) }
            case .idle:
                break
            }
        }
        onAction(action)
    }
}

extension AtBatAction {
    /// True for the taps that throw a pitch or award the batter first: anything recorded from
    /// the count buttons and chips, and opening the in-play sequence.
    var isPitchLike: Bool {
        switch self {
        case .record(let event):
            switch event.kind {
            case .pitch, .intentionalWalk: return true
            default: return false
            }
        case .openInPlay(.ballInPlay): return true
        default: return false
        }
    }
}
