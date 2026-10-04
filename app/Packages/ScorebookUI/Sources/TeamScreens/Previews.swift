// Previews of the teams and songs screens, and a demo that acts on every request the way the app
// shell will: saving teams, changing songs, pretending to play (a song's position counts up so
// "Start here" works) and pretending to record. The previews cover the brief's finish line: the
// SampleData teams, the fifteen-song library and an empty team, in light and dark mode and at
// the largest accessibility text size.

import SwiftUI
import Model
import SampleData
import DesignSystem

// MARK: - The demo

/// The demo's saved state, changed by each request as the app shell would change its own.
public struct TeamScreensDemoState: Equatable, Sendable {
    public var data: TeamScreensData
    /// The last request, in words, shown at the top of the demo.
    public var lastRequest: String?

    public init(data: TeamScreensData) {
        self.data = data
    }

    /// The sample teams (with an empty team added) and the fifteen-song library.
    public static let sample = TeamScreensDemoState(data: TeamScreensData(
        teams: SampleTeams.all + [SampleTeams.emptyTeam],
        library: SampleSongs.library,
        usuals: sampleUsuals
    ))

    /// Usual positions and roles for the sample Diamond Dogs, as the scorer might set them.
    public static let sampleUsuals: [PlayerID: PlayerUsuals] = [
        "d1": PlayerUsuals(position: .centerField, leadsOff: true), "d2": PlayerUsuals(position: .shortstop),
        "d3": PlayerUsuals(position: .firstBase), "d4": PlayerUsuals(position: .leftField),
        "d5": PlayerUsuals(position: .thirdBase), "d6": PlayerUsuals(position: .catcher),
        "d7": PlayerUsuals(position: .secondBase), "d8": PlayerUsuals(position: .rightField),
        "d9": PlayerUsuals(position: .pitcher), "d10": PlayerUsuals(),
        "d11": PlayerUsuals(startsOnBench: true), "d12": PlayerUsuals(position: .pitcher, startsOnBench: true),
    ]

    /// Changes the state the way the app shell would for this request.
    public mutating func apply(_ request: TeamScreensRequest, now: Date = .now) {
        lastRequest = Self.describe(request)
        switch request {
        case .saveTeam(let team):
            if let i = data.teams.firstIndex(where: { $0.id == team.id }) {
                data.teams[i] = team
            } else {
                data.teams.append(team)
            }
        case .setUsuals(let usuals, let player):
            data.usuals[player] = usuals.isEmpty ? nil : usuals
        case .importSongs(let urls):
            data.library.songs += urls.map {
                Song(title: $0.deletingPathExtension().lastPathComponent, fileName: $0.lastPathComponent, duration: 200)
            }
        case .renameSong(let id, let title):
            updateSong(id) { $0.title = title }
        case .setStartPoint(let seconds, let id):
            updateSong(id) { $0.startTime = seconds }
        case .setVolume(let volume, let id):
            updateSong(id) { $0.volume = volume }
        case .setAnnouncerEcho(let amount):
            data.library.announcerEcho = amount
        case .playPreview(let id, let seconds):
            data.audio.playback = AudioPlayback(phase: .song, song: id)
            data.audio.position = seconds
        case .playWalkUp(let player):
            if player.introduction != nil {
                data.audio.playback = AudioPlayback(phase: .introduction, song: player.walkUpSongID)
                data.audio.position = nil
            } else if let song = player.walkUpSongID {
                data.audio.playback = AudioPlayback(phase: .song, song: song)
                data.audio.position = data.library.song(song)?.startTime
            }
        case .playIntroduction:
            data.audio.playback = AudioPlayback(phase: .introduction)
            data.audio.position = nil
        case .stopPlaying:
            data.audio.playback = AudioPlayback(phase: .idle)
            data.audio.position = nil
        case .startRecording(let player):
            data.audio.recording = .recording(player, since: now)
        case .stopRecording:
            if case .recording(let player, _) = data.audio.recording {
                data.audio.recording = .recorded(player, AnnouncerIntroduction(source: .recorded, fileName: "intro-\(player.rawValue)-new.m4a"))
            }
        case .cancelRecording, .finishRecording:
            data.audio.recording = .idle
        case .importIntroduction(let url, let player):
            data.audio.recording = .recorded(player, AnnouncerIntroduction(source: .imported, fileName: url.lastPathComponent))
        case .introductionReplaced:
            break
        case .dismissProblems:
            data.audio.problems = []
        }
    }

    /// Moves a pretend song along by a tenth of a second, and lets a pretend introduction run
    /// into its song, as the audio player would.
    public mutating func tick() {
        switch data.audio.playback.phase {
        case .song, .warmUp:
            data.audio.position = (data.audio.position ?? 0) + 0.1
        case .introduction:
            if let song = data.audio.playback.song {
                data.audio.playback = AudioPlayback(phase: .song, song: song)
                data.audio.position = data.library.song(song)?.startTime
            } else {
                data.audio.playback = AudioPlayback(phase: .idle)
            }
        case .idle:
            break
        }
    }

    /// Changes one song in the library.
    private mutating func updateSong(_ id: SongID, _ change: (inout Song) -> Void) {
        guard let i = data.library.songs.firstIndex(where: { $0.id == id }) else { return }
        change(&data.library.songs[i])
    }

    /// A request in a few words, for the demo's caption.
    static func describe(_ request: TeamScreensRequest) -> String {
        switch request {
        case .saveTeam(let team): "Save team: \(team.name), \(TeamWording.playerCount(team.roster.count))"
        case .setUsuals(let usuals, _): "Usual spot: \(TeamWording.usualText(usuals))"
        case .importSongs(let urls): "Import \(urls.count) file\(urls.count == 1 ? "" : "s")"
        case .renameSong(_, let title): "Rename song: \(title)"
        case .setStartPoint(let seconds, _): "Start point \(TeamWording.clockTenths(seconds))"
        case .setVolume(let volume, _): "Volume \(TeamWording.percent(volume))"
        case .setAnnouncerEcho(let amount): amount > 0 ? "Stadium echo on" : "Stadium echo off"
        case .playPreview(_, let seconds): "Play from \(TeamWording.clockTenths(seconds))"
        case .playWalkUp(let player): "Test walk-up: \(player.displayName)"
        case .playIntroduction(let player): "Play introduction: \(player.displayName)"
        case .stopPlaying: "Stop"
        case .startRecording: "Start recording"
        case .stopRecording: "Stop recording"
        case .cancelRecording: "Throw the recording away"
        case .finishRecording: "Recording kept"
        case .importIntroduction(let url, _): "Import introduction: \(url.lastPathComponent)"
        case .introductionReplaced(let intro): "No longer used: \(intro.fileName ?? "file")"
        case .dismissProblems: "Messages read"
        }
    }
}

/// The teams and songs screens running on the demo state, acting on every request. Public so a
/// test harness can open it; the app itself uses the real screens with real data.
public struct TeamScreensDemo: View {
    public var start: TeamScreensRoute
    @State private var state: TeamScreensDemoState

    public init(start: TeamScreensRoute = .teams, state: TeamScreensDemoState = .sample) {
        self.start = start
        _state = State(initialValue: state)
    }

    public var body: some View {
        TeamScreensStack(start: start, data: state.data) { state.apply($0) }
            .overlay(alignment: .bottom) {
                if let last = state.lastRequest {
                    Text(last)
                        .font(ScorebookFont.caption.weight(.bold))
                        .padding(.horizontal, Spacing.medium)
                        .padding(.vertical, Spacing.small)
                        .background(ScorebookColor.surface, in: Capsule())
                        .shadow(radius: 4)
                        .padding(.bottom, Spacing.small)
                        .allowsHitTesting(false)
                }
            }
            .task {
                // A pretend audio clock: a tenth of a second at a time.
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(100))
                    state.tick()
                }
            }
    }
}

// MARK: - Previews

#Preview("Teams") {
    TeamScreensDemo()
}

#Preview("Teams, dark") {
    TeamScreensDemo().preferredColorScheme(.dark)
}

#Preview("Teams, largest text") {
    TeamScreensDemo().dynamicTypeSize(.accessibility5)
}

#Preview("First time: no teams") {
    TeamScreensDemo(state: TeamScreensDemoState(data: TeamScreensData(teams: [], library: SampleSongs.emptyLibrary)))
}

#Preview("Diamond Dogs roster") {
    TeamScreensDemo(start: .team(SampleTeams.diamondDogs.id))
}

#Preview("Diamond Dogs roster, dark") {
    TeamScreensDemo(start: .team(SampleTeams.diamondDogs.id)).preferredColorScheme(.dark)
}

#Preview("Diamond Dogs roster, largest text") {
    TeamScreensDemo(start: .team(SampleTeams.diamondDogs.id)).dynamicTypeSize(.accessibility5)
}

#Preview("Mudcats roster") {
    TeamScreensDemo(start: .team(SampleTeams.mudcats.id))
}

#Preview("Bombers: numbers only") {
    TeamScreensDemo(start: .team(SampleTeams.bombers.id))
}

#Preview("Empty team") {
    TeamScreensDemo(start: .team(SampleTeams.emptyTeam.id))
}

#Preview("Empty team, dark") {
    TeamScreensDemo(start: .team(SampleTeams.emptyTeam.id)).preferredColorScheme(.dark)
}

#Preview("Quick entry") {
    QuickEntrySheet(team: SampleTeams.emptyTeam) { _ in }
}

#Preview("Player: recorded introduction") {
    TeamScreensDemo(start: .player(SampleTeams.diamondDogs.id, "d1"))
}

#Preview("Player: iPhone voice, dark") {
    TeamScreensDemo(start: .player(SampleTeams.diamondDogs.id, "d2")).preferredColorScheme(.dark)
}

#Preview("Player: no song, no introduction") {
    TeamScreensDemo(start: .player(SampleTeams.diamondDogs.id, "d8"))
}

#Preview("Player: pitcher with warm-up song, largest text") {
    TeamScreensDemo(start: .player(SampleTeams.diamondDogs.id, "d9")).dynamicTypeSize(.accessibility5)
}

#Preview("Player: a problem to show") {
    var state = TeamScreensDemoState.sample
    state.data.audio.problems = ["The speaker disconnected, so the song stopped."]
    return TeamScreensDemo(start: .player(SampleTeams.diamondDogs.id, "d3"), state: state)
}

#Preview("Record: ready") {
    RecordIntroductionSheet(playerID: "d3", team: SampleTeams.diamondDogs,
                            data: TeamScreensDemoState.sample.data) { _ in }
}

#Preview("Record: recording, dark") {
    var data = TeamScreensDemoState.sample.data
    data.audio.recording = .recording("d3", since: .now.addingTimeInterval(-3))
    return RecordIntroductionSheet(playerID: "d3", team: SampleTeams.diamondDogs, data: data) { _ in }
        .preferredColorScheme(.dark)
}

#Preview("Record: recorded, keep or redo") {
    var data = TeamScreensDemoState.sample.data
    data.audio.recording = .recorded("d3", AnnouncerIntroduction(source: .recorded, fileName: "intro-d3.m4a"))
    return RecordIntroductionSheet(playerID: "d3", team: SampleTeams.diamondDogs, data: data) { _ in }
}

#Preview("Song library: fifteen songs") {
    TeamScreensDemo(start: .songs)
}

#Preview("Song library, dark") {
    TeamScreensDemo(start: .songs).preferredColorScheme(.dark)
}

#Preview("Song library, largest text") {
    TeamScreensDemo(start: .songs).dynamicTypeSize(.accessibility5)
}

#Preview("Song library: empty") {
    TeamScreensDemo(start: .songs, state: TeamScreensDemoState(data: TeamScreensData(
        teams: SampleTeams.all, library: SampleSongs.emptyLibrary)))
}

#Preview("Song library: importing, with a problem") {
    var state = TeamScreensDemoState.sample
    state.data.audio.isImporting = true
    state.data.audio.problems = ["‘notes.txt’ could not be copied in. It is not a sound file the app can play. Use an MP3, M4A, WAV or AAC file."]
    return TeamScreensDemo(start: .songs, state: state)
}

#Preview("Song: start point and volume") {
    TeamScreensDemo(start: .song("song-03"))
}

#Preview("Song, dark") {
    TeamScreensDemo(start: .song("song-11")).preferredColorScheme(.dark)
}

#Preview("Song, largest text") {
    TeamScreensDemo(start: .song("song-03")).dynamicTypeSize(.accessibility5)
}

#Preview("Song picker") {
    SongPickerSheet(slot: .walkUp, playerID: "d8", team: SampleTeams.diamondDogs,
                    data: TeamScreensDemoState.sample.data) { _ in }
}

#Preview("Assign a song to players") {
    AssignSongSheet(song: SampleSongs.all[2], data: TeamScreensDemoState.sample.data) { _ in }
}
