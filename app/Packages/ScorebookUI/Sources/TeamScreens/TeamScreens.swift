// TeamScreens: the teams list, rosters, each player's page (walk-up song, pitcher warm-up song,
// announcer introduction), the song library, a song's start point and volume, and the song
// picker. They match the approved mockup (plan/mockups/index.html: SCREENS.teams, roster,
// player, songs, song; SHEETS.record, songpick).
//
// Like every screen in the app, these hold nothing of their own beyond what is on screen. They
// are handed plain data (`TeamScreensData`: the saved teams, the song library, and what the
// audio is doing) and hand back every change as a `TeamScreensRequest`: "save this team",
// "import these files", "play this song from 0:42", "start recording". The app shell does the
// saving and the playing; the audio itself belongs to the WalkUpAudio module, connected during
// wiring.
//
// The files in this folder:
//   TeamScreens.swift          this file: what the screens are handed and what they hand back,
//                              and the navigation between them
//   TeamScreensWording.swift   the words and sums the screens show, and the team edits, as
//                              plain functions with no screen
//   Parts.swift                cards, section labels, buttons and other shared pieces
//   TeamsListScreen.swift      our team on top, opponents below, add and rename
//   RosterScreen.swift         a team's players
//   PlayerEditSheet.swift      add or edit one player
//   QuickEntrySheet.swift      type a whole roster in a row
//   PlayerPage.swift           one of our players: songs and the announcer introduction
//   RecordIntroductionSheet.swift  record, listen, keep or redo
//   SongLibraryScreen.swift    every imported song and the Import button
//   SongPage.swift             one song: start point, volume, who uses it
//   SongPickerSheet.swift      pick a song for a player, or players for a song
//   Previews.swift             previews, and a demo that acts on every request

import SwiftUI
import Model
import SampleData
import DesignSystem

// MARK: - What the screens are handed

/// Everything the teams and songs screens show. The app shell builds it from storage and the
/// audio player, and hands in a fresh copy whenever something changes.
public struct TeamScreensData: Equatable, Sendable {
    /// Every saved team: ours and the opponents.
    public var teams: [Team]
    /// The walk-up song library.
    public var library: SongLibrary
    /// Each player's usual position and role. A stand-in until `Player` carries them itself
    /// (requested in plan/handoffs/screen-teams-and-songs.md).
    public var usuals: [PlayerID: PlayerUsuals]
    /// What the audio player is doing.
    public var audio: TeamScreensAudio

    public init(
        teams: [Team],
        library: SongLibrary,
        usuals: [PlayerID: PlayerUsuals] = [:],
        audio: TeamScreensAudio = TeamScreensAudio()
    ) {
        self.teams = teams
        self.library = library
        self.usuals = usuals
        self.audio = audio
    }

    /// Our team, if one has been set up.
    public var ourTeam: Team? { teams.first { $0.isOurs } }

    /// Finds a team by id.
    public func team(_ id: TeamID) -> Team? { teams.first { $0.id == id } }

    /// A player's usual position and role, empty when none is set.
    public func usuals(for player: PlayerID) -> PlayerUsuals { usuals[player] ?? PlayerUsuals() }
}

/// What the audio player is doing, in the terms these screens need.
public struct TeamScreensAudio: Equatable, Sendable {
    /// What is playing now (from `WalkUpAudioPlayer.playback`).
    public var playback: AudioPlayback
    /// Seconds into the playing track (from `WalkUpAudioPlayer.playbackPosition`), so the
    /// scorer can set a start point by listening.
    public var position: TimeInterval?
    /// Where an announcer recording stands.
    public var recording: IntroductionRecording
    /// True while picked song files are being copied in.
    public var isImporting: Bool
    /// Messages to show the scorer, such as a file that could not be copied in or a speaker
    /// that disconnected. Cleared by `.dismissProblems`.
    public var problems: [String]

    public init(
        playback: AudioPlayback = AudioPlayback(phase: .idle),
        position: TimeInterval? = nil,
        recording: IntroductionRecording = .idle,
        isImporting: Bool = false,
        problems: [String] = []
    ) {
        self.playback = playback
        self.position = position
        self.recording = recording
        self.isImporting = isImporting
        self.problems = problems
    }

    /// True while anything at all is playing.
    public var isPlaying: Bool { playback.phase != .idle }

    /// True while this song is playing as a preview or walk-up song.
    public func isPlayingSong(_ song: SongID?) -> Bool {
        guard let song else { return false }
        return (playback.phase == .song || playback.phase == .warmUp) && playback.song == song
    }
}

/// Where a new announcer introduction stands. The app shell keeps it: it starts and stops the
/// microphone, and holds the new recording until the scorer keeps it or throws it away.
public enum IntroductionRecording: Equatable, Sendable {
    /// Nothing is being recorded.
    case idle
    /// Recording this player's introduction, since this moment.
    case recording(PlayerID, since: Date)
    /// A new introduction for this player, recorded or imported, waiting for Keep or Redo.
    case recorded(PlayerID, AnnouncerIntroduction)

    /// The player the recording is for, if any.
    public var player: PlayerID? {
        switch self {
        case .idle: nil
        case .recording(let id, _), .recorded(let id, _): id
        }
    }
}

/// A player's usual spot on the team: where they usually field, whether they usually lead off,
/// and whether they usually start on the bench. Pregame builds the first game's lineup from it.
/// A stand-in until `Player` carries these itself; it has the same three parts as the pregame
/// screens' `UsualRole`, so the app shell can keep one copy and hand it to both.
public struct PlayerUsuals: Codable, Equatable, Hashable, Sendable {
    /// The position they usually play. Missing means they usually only bat.
    public var position: Position?
    /// True for the usual leadoff hitter.
    public var leadsOff: Bool
    /// True for a player who usually starts on the bench.
    public var startsOnBench: Bool

    public init(position: Position? = nil, leadsOff: Bool = false, startsOnBench: Bool = false) {
        self.position = position
        self.leadsOff = leadsOff
        self.startsOnBench = startsOnBench
    }

    /// True when nothing is set.
    public var isEmpty: Bool { position == nil && !leadsOff && !startsOnBench }
}

/// Which of a player's two songs is meant.
public enum SongSlot: String, CaseIterable, Sendable {
    /// The song that plays when they come up to bat.
    case walkUp
    /// The song that plays while they warm up to pitch.
    case warmUp

    /// "Walk-up" or "Warm-up".
    public var label: String { self == .walkUp ? "Walk-up" : "Warm-up" }
}

// MARK: - What the screens hand back

/// Every change the scorer makes on these screens. The app shell acts on each one.
public enum TeamScreensRequest: Equatable, Sendable {
    // Teams and players

    /// Save this team as it now stands: a new team, a new name, a player added, edited or
    /// removed, a song assigned, an introduction kept. Update the teams handed back in at once,
    /// then save to storage, so a second quick change builds on the first.
    case saveTeam(Team)
    /// Save a player's usual position and role (a stand-in until `Player` carries them).
    case setUsuals(PlayerUsuals, for: PlayerID)

    // The song library

    /// Copy these picked files into the app (`importSongsWithReport`, then `addSongs`). The
    /// URLs come straight from the iPhone's file picker; hand them over unopened.
    case importSongs([URL])
    /// Give a song a new name.
    case renameSong(SongID, to: String)
    /// Start this song's walk-up clip here, in seconds into the track.
    case setStartPoint(TimeInterval, for: SongID)
    /// Set this song's loudness, 0 to 1.
    case setVolume(Double, for: SongID)
    /// Set the stadium echo on introductions, 0 (none) to 1.
    case setAnnouncerEcho(Double)

    // Listening

    /// Play a song from this point, to preview it or find its start point.
    case playPreview(SongID, from: TimeInterval)
    /// Play a player's walk-up as it will sound in a game: introduction, then song.
    case playWalkUp(Player)
    /// Play a player's introduction on its own. The player may carry a new recording not yet
    /// kept, so it can be checked before keeping it.
    case playIntroduction(Player)
    /// Stop whatever is playing.
    case stopPlaying

    // Announcer introductions

    /// Start recording this player's introduction with the microphone.
    case startRecording(for: PlayerID)
    /// Stop recording, and hand the new introduction back in `IntroductionRecording.recorded`.
    case stopRecording
    /// Throw the new recording away (Redo or Cancel): stop the microphone if it is on, delete
    /// the unkept file, and go back to `.idle`.
    case cancelRecording
    /// The new introduction was kept (a `.saveTeam` comes first): go back to `.idle`, keeping
    /// the file.
    case finishRecording
    /// Copy an introduction recorded elsewhere into the app for this player, and hand it back
    /// in `IntroductionRecording.recorded` so the scorer can listen and keep it.
    case importIntroduction(URL, for: PlayerID)
    /// Delete an introduction's sound file that nothing uses any more, because the player's
    /// introduction was replaced or removed.
    case discardIntroductionFile(AnnouncerIntroduction)

    // Messages

    /// The scorer has read the messages in `TeamScreensAudio.problems`.
    case dismissProblems
}

// MARK: - Navigation

/// The pages of the teams and songs screens. The pages link to each other with these; the app
/// shell's navigation stack shows them through `teamScreenDestinations`.
public enum TeamScreensRoute: Hashable, Sendable {
    /// Our team on top, opponents below.
    case teams
    /// One team's roster.
    case team(TeamID)
    /// One of our players: songs and announcer introduction.
    case player(TeamID, PlayerID)
    /// Every song in the library.
    case songs
    /// One song: start point, volume and who uses it.
    case song(SongID)
}

/// Any one of the pages, by route.
public struct TeamScreen: View {
    public var route: TeamScreensRoute
    public var data: TeamScreensData
    public var onRequest: (TeamScreensRequest) -> Void

    public init(route: TeamScreensRoute, data: TeamScreensData, onRequest: @escaping (TeamScreensRequest) -> Void) {
        self.route = route
        self.data = data
        self.onRequest = onRequest
    }

    public var body: some View {
        switch route {
        case .teams:
            TeamsListScreen(data: data, onRequest: onRequest)
        case .team(let id):
            RosterScreen(teamID: id, data: data, onRequest: onRequest)
        case .player(let team, let player):
            PlayerPage(teamID: team, playerID: player, data: data, onRequest: onRequest)
        case .songs:
            SongLibraryScreen(data: data, onRequest: onRequest)
        case .song(let id):
            SongPage(songID: id, data: data, onRequest: onRequest)
        }
    }
}

extension View {
    /// Lets a navigation stack open the teams and songs pages. Put it on the stack's first page:
    /// the app shell's home screen, or `TeamScreensStack`.
    public func teamScreenDestinations(
        _ data: TeamScreensData,
        onRequest: @escaping (TeamScreensRequest) -> Void
    ) -> some View {
        navigationDestination(for: TeamScreensRoute.self) { route in
            TeamScreen(route: route, data: data, onRequest: onRequest)
        }
    }
}

/// The teams and songs pages in their own navigation stack, starting from the teams list or the
/// song library. For previews, and for an app shell that opens them as a separate stack.
public struct TeamScreensStack: View {
    public var start: TeamScreensRoute
    public var data: TeamScreensData
    public var onRequest: (TeamScreensRequest) -> Void

    public init(start: TeamScreensRoute = .teams, data: TeamScreensData, onRequest: @escaping (TeamScreensRequest) -> Void) {
        self.start = start
        self.data = data
        self.onRequest = onRequest
    }

    public var body: some View {
        NavigationStack {
            TeamScreen(route: start, data: data, onRequest: onRequest)
                .teamScreenDestinations(data, onRequest: onRequest)
        }
    }
}
