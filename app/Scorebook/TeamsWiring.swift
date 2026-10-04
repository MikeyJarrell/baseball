// Connecting the teams and songs screens (the TeamScreens module) to storage and the audio
// player, following the table in plan/handoffs/screen-teams-and-songs.md.
//
// The screens are handed `TeamScreensData` (the saved teams, the song library, each player's
// usual position and role, and what the audio is doing) and hand back requests: save this
// team, import these songs, play this song from 0:42, start recording. This file turns each
// request into a call on the app model or the audio player, and keeps the little state the
// screens need from the shell: where an announcer recording stands, whether songs are being
// copied in, and messages for the scorer.

import SwiftUI
import Model
import Scoring
import WalkUpAudio
import TeamScreens

/// The shell's side of the teams and songs screens: recording, importing and messages.
@MainActor
@Observable
final class TeamsWiring {
    /// Where a new announcer introduction stands.
    var recording: IntroductionRecording = .idle
    /// True while picked song files are being copied in.
    var isImporting = false
    /// Messages for the scorer from the shell itself (an import problem, the microphone).
    var problems: [String] = []
    /// The audio player's last message once the scorer has dismissed it, so it is not shown again.
    var dismissedAudioProblem: String?
}

extension AppModel {
    // MARK: What the screens are handed

    /// Everything the teams and songs screens show, fresh from the saved teams and the audio player.
    var teamScreensData: TeamScreensData {
        var usuals: [PlayerID: PlayerUsuals] = [:]
        for team in teams where team.isOurs {
            for player in team.roster {
                let usual = PlayerUsuals(position: player.usualPosition, leadsOff: player.usuallyLeadsOff,
                                         startsOnBench: player.usualRole == .startsOnBench)
                if !usual.isEmpty { usuals[player.id] = usual }
            }
        }
        var messages = teamsWiring.problems
        if let audioProblem = audio?.lastProblem, audioProblem != teamsWiring.dismissedAudioProblem {
            messages.append(audioProblem)
        }
        let audioState = TeamScreensAudio(
            playback: audio?.playback ?? AudioPlayback(phase: .idle),
            position: audio?.playbackPosition,
            recording: teamsWiring.recording,
            isImporting: teamsWiring.isImporting,
            problems: messages)
        return TeamScreensData(teams: teams, library: audio?.library ?? SongLibrary(), usuals: usuals, audio: audioState)
    }

    // MARK: What the screens ask for

    /// Acts on one request from the teams and songs screens.
    func handleTeams(_ request: TeamScreensRequest) {
        let wiring = teamsWiring
        switch request {
        case .saveTeam(let team):
            Task {
                await saveTeam(team)
                cueOurNextHitter()
            }
        case .setUsuals(let usual, let id):
            guard var team = teams.first(where: { $0.player(id) != nil }),
                  let i = team.roster.firstIndex(where: { $0.id == id }) else { return }
            team.roster[i].usualPosition = usual.position
            team.roster[i].usuallyLeadsOff = usual.leadsOff
            if usual.startsOnBench {
                team.roster[i].usualRole = .startsOnBench
            } else if team.roster[i].usualRole == .startsOnBench {
                team.roster[i].usualRole = nil
            }
            Task { await saveTeam(team) }
        case .importSongs(let files):
            guard let audio else { return }
            wiring.isImporting = true
            Task {
                let report = await audio.importSongsWithReport(from: files)
                audio.addSongs(report.songs)
                wiring.problems += report.problems.map(\.message)
                wiring.isImporting = false
            }
        case .renameSong(let id, let title):
            audio?.rename(id, to: title)
        case .setStartPoint(let seconds, let id):
            audio?.setStartPoint(seconds, for: id)
            cueOurNextHitter()
        case .setVolume(let volume, let id):
            audio?.setVolume(volume, for: id)
            cueOurNextHitter()
        case .setAnnouncerEcho(let amount):
            audio?.setAnnouncerEcho(amount)
        case .playPreview(let id, let seconds):
            audio?.playPreview(id, from: seconds)
        case .playWalkUp(let player):
            audio?.playWalkUp(for: player, withIntroduction: true)
        case .playIntroduction(let player):
            audio?.playIntroduction(for: player)
        case .stopPlaying:
            audio?.stop()
        case .startRecording(let id):
            startRecording(for: id)
        case .stopRecording:
            guard case .recording(let id, _) = wiring.recording else { return }
            if let take = audio?.stopRecordingIntroduction() {
                wiring.recording = .recorded(id, take)
            } else {
                wiring.recording = .idle
                wiring.problems.append("The recording was too short to keep. Try again.")
            }
        case .cancelRecording:
            switch wiring.recording {
            case .recording:
                if let take = audio?.stopRecordingIntroduction() { audio?.discardIntroduction(take) }
            case .recorded(_, let take):
                audio?.discardIntroduction(take)
            case .idle:
                break
            }
            wiring.recording = .idle
        case .finishRecording:
            wiring.recording = .idle
        case .importIntroduction(let file, let id):
            guard let audio else { return }
            Task {
                do {
                    let introduction = try await audio.importIntroduction(from: file)
                    wiring.recording = .recorded(id, introduction)
                } catch let error as WalkUpAudioError {
                    wiring.problems.append(error.message)
                } catch {
                    wiring.problems.append("That recording could not be copied in. (\(error.localizedDescription))")
                }
            }
        case .introductionReplaced(let introduction):
            deleteWhenUnused(introduction)
        case .dismissProblems:
            wiring.problems = []
            wiring.dismissedAudioProblem = audio?.lastProblem
        }
    }

    /// Asks for the microphone the first time, then starts recording.
    private func startRecording(for id: PlayerID) {
        guard let audio else { return }
        let wiring = teamsWiring
        Task {
            guard await audio.requestMicrophoneAccess() else {
                wiring.problems.append("The Scorebook is not allowed to use the microphone. Turn it on in the Settings app, under Scorebook, then Microphone.")
                return
            }
            do {
                try audio.startRecordingIntroduction()
                wiring.recording = .recording(id, since: .now)
            } catch let problem as RecordingProblem {
                wiring.problems.append(problem.message)
            } catch let problem as WalkUpAudioError {
                wiring.problems.append(problem.message)
            } catch {
                wiring.problems.append("The recording could not start. (\(error.localizedDescription))")
            }
        }
    }

    /// A recording that stopped by itself (the 30-second limit, or a phone call): collect the
    /// take, so the sheet stops counting and offers Listen and Keep.
    func collectRecordingThatStopped() {
        guard let audio, case .recording(let id, _) = teamsWiring.recording, !audio.isRecording else { return }
        if let take = audio.stopRecordingIntroduction() {
            teamsWiring.recording = .recorded(id, take)
        } else {
            teamsWiring.recording = .idle
        }
    }

    // MARK: Songs follow the saved team

    /// One of our players with their songs and introduction as the saved team has them now,
    /// so a song picked or an introduction recorded during a game is used at once.
    func withSavedSongs(_ player: Player) -> Player {
        guard let saved = ourTeam?.player(player.id) else { return player }
        var updated = player
        updated.walkUpSongID = saved.walkUpSongID
        updated.warmUpSongID = saved.warmUpSongID
        updated.introduction = saved.introduction
        return updated
    }

    /// A game's setup with our players' songs and introductions from the saved team.
    func withSavedSongs(_ setup: GameSetup) -> GameSetup {
        guard let side = setup.ourSide else { return setup }
        var updated = setup
        switch side {
        case .away: updated.away.roster = setup.away.roster.map(withSavedSongs)
        case .home: updated.home.roster = setup.home.roster.map(withSavedSongs)
        }
        return updated
    }

    /// Loads the walk-up song and introduction of our next hitter in the game in progress.
    func cueOurNextHitter() {
        guard let session, !session.isFinished, let ours = session.setup.ourSide,
              let next = session.situation[ours].currentBatter,
              let player = session.setup.player(next) else { return }
        audio?.cue(for: withSavedSongs(player))
    }

    // MARK: Introduction files waiting to be deleted

    /// Where the list of introduction files waiting to be deleted is kept between launches.
    private static let waitingKey = "introductionsWaitingToBeDeleted"

    /// Introduction files no team uses any more, kept until no game in progress names them.
    private var introductionsWaiting: [AnnouncerIntroduction] {
        get {
            guard let data = UserDefaults.standard.data(forKey: Self.waitingKey) else { return [] }
            return (try? JSONDecoder().decode([AnnouncerIntroduction].self, from: data)) ?? []
        }
        set {
            UserDefaults.standard.set(try? JSONEncoder().encode(newValue), forKey: Self.waitingKey)
        }
    }

    /// Deletes an introduction file the team no longer uses: now, if no game in progress
    /// names it; otherwise once that game ends, so the batter keeps their introduction for
    /// the rest of the game.
    func deleteWhenUnused(_ introduction: AnnouncerIntroduction) {
        introductionsWaiting.append(introduction)
        deleteIntroductionsNoLongerUsed()
    }

    /// Deletes every waiting introduction file that neither a saved team nor the game in
    /// progress uses. Runs when one is replaced, when a game ends and when the app opens.
    func deleteIntroductionsNoLongerUsed() {
        var inUse = Set(teams.flatMap(\.roster).compactMap(\.introduction))
        if let session, !session.isFinished {
            inUse.formUnion((session.setup.away.roster + session.setup.home.roster).compactMap(\.introduction))
        }
        var stillWaiting: [AnnouncerIntroduction] = []
        for introduction in introductionsWaiting {
            if inUse.contains(introduction) {
                stillWaiting.append(introduction)
            } else {
                audio?.discardIntroduction(introduction)
            }
        }
        introductionsWaiting = stillWaiting
    }
}
