// Tests for "keep playing": a walk-up song kept going past its length for a delay before the
// at-bat, then faded by hand. These play a made-up test song for real, a few seconds each, so
// they check the player itself and not only the timing sums. Where the sound system will not
// start (a machine with no audio), each test stops early without failing.

import Foundation
import Model
import Testing
@testable import WalkUpAudio

@Suite("Keeping a walk-up song playing", .serialized)
@MainActor
struct KeepPlayingTests {

    /// A player with one 40-second test song, and a batter whose walk-up song it is, starting
    /// 10 seconds in.
    private func playerAndBatter() async throws -> (StadiumAudioPlayer, Player) {
        let base = FileManager.default.temporaryDirectory.appending(path: "KeepPlayingTests-\(UUID().uuidString)")
        let files = try TestSongMaker.makeTestSongs(in: base.appending(path: "picked"))
        let player = StadiumAudioPlayer(audioFolder: base.appending(path: "audio"))
        let report = await player.importSongsWithReport(from: [files[0]])
        let song = try #require(report.songs.first)
        player.addSongs([song])
        player.setStartPoint(10, for: song.id)
        return (player, Player(name: "Derek Jeter", number: "2", walkUpSongID: song.id))
    }

    private func wait(_ seconds: Double) async throws {
        try await Task.sleep(for: .seconds(seconds))
    }

    @Test("Left alone, a 1.5-second walk-up ends by itself")
    func endsByItself() async throws {
        let (player, batter) = try await playerAndBatter()
        player.walkUpLength = 1.5
        player.fadeLength = 0.5
        player.playWalkUp(for: batter, withIntroduction: false)
        guard player.isPlaying else { return }   // no sound system here
        #expect(player.playback.fadesAt != nil)
        #expect(player.playback.keepsPlaying == false)
        try await wait(2.3)
        #expect(player.isPlaying == false)
    }

    @Test("Kept playing, it goes on well past its length, then fades when asked")
    func keepsGoingThenFades() async throws {
        let (player, batter) = try await playerAndBatter()
        player.walkUpLength = 1.5
        player.fadeLength = 0.5
        player.playWalkUp(for: batter, withIntroduction: false)
        guard player.isPlaying else { return }   // no sound system here
        try await wait(0.4)
        player.keepWalkUpPlaying()
        #expect(player.isKeptPlaying)
        #expect(player.playback == AudioPlayback(phase: .song, song: batter.walkUpSongID, keepsPlaying: true))

        // Four seconds in: long past the 1.5 seconds, still playing, not fading, and the
        // song has carried on from where the walk-up's own stretch ended.
        try await wait(3.6)
        #expect(player.isPlaying)
        #expect(player.isFadingOut == false)
        #expect(player.timeLeft == nil)
        let position = try #require(player.playbackPosition)
        #expect(abs(position - 14) < 0.6, "the song was at \(position) seconds, not about 14")

        player.fadeOut()
        #expect(player.isFadingOut)
        try await wait(1)
        #expect(player.isPlaying == false)
        #expect(player.isKeptPlaying == false)
    }

    @Test("Asked for while the song is already fading, the fade is called off and the song plays on")
    func rescuesAFade() async throws {
        let (player, batter) = try await playerAndBatter()
        player.walkUpLength = 2
        player.fadeLength = 1.5      // the automatic fade begins half a second in
        player.playWalkUp(for: batter, withIntroduction: false)
        guard player.isPlaying else { return }   // no sound system here
        try await wait(1.2)
        #expect(player.isFadingOut)
        player.keepWalkUpPlaying()
        #expect(player.isFadingOut == false)
        #expect(player.isKeptPlaying)

        // Past where the walk-up would have ended, and back at full loudness.
        try await wait(2.3)
        #expect(player.isPlaying)
        #expect(player.isFadingOut == false)
        #expect(player.mainVolumeForTesting == 1)
        player.stop()
        #expect(player.isPlaying == false)
    }

    @Test("It does nothing when no walk-up is playing, or for a warm-up song")
    func onlyForWalkUps() async throws {
        let (player, batter) = try await playerAndBatter()
        player.keepWalkUpPlaying()
        #expect(player.isKeptPlaying == false)

        var pitcher = batter
        pitcher.warmUpSongID = batter.walkUpSongID
        player.playWarmUp(for: pitcher)
        guard player.isPlaying else { return }   // no sound system here
        player.keepWalkUpPlaying()
        #expect(player.isKeptPlaying == false)
        player.stop()
    }
}
