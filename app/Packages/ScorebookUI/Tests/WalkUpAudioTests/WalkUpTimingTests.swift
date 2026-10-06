// Tests for walk-up timing: when the song starts fading, how the fade sounds, the countdown
// on the song button, where a repeating warm-up song is, and which slice of a file plays.

import Model
import Testing
@testable import WalkUpAudio

@Suite("Walk-up timing")
struct WalkUpTimingTests {

    @Test("A 12-second walk-up plays 10 seconds at full volume, then fades for 2 and is silent at 12")
    func twelveSecondWalkUp() {
        #expect(WalkUpMath.fadeBegins(songLength: 12, fadeLength: 2) == 10)
        // Silent exactly when the countdown reaches zero.
        #expect(WalkUpMath.secondsLeft(now: 12, songStart: 0, songLength: 12) == 0)
    }

    @Test("A song’s own play length wins over the walk-up length setting")
    func ownPlayLength() {
        let usual = Song(title: "Thunderstruck", fileName: "t.mp3")
        let short = Song(title: "Hells Bells", fileName: "h.mp3", playLength: 8)
        #expect(WalkUpMath.songLength(for: usual, walkUpLength: 12) == 12)
        #expect(WalkUpMath.songLength(for: short, walkUpLength: 12) == 8)
    }

    @Test("A song shorter than the fade fades from its first moment")
    func shortSongFadesAtOnce() {
        #expect(WalkUpMath.fadeBegins(songLength: 1.5, fadeLength: 2) == 0)
    }

    @Test("The fade starts at full volume, is at a quarter halfway, and ends silent")
    func fadeCurve() {
        #expect(WalkUpMath.fadeVolume(progress: 0, startingFrom: 1) == 1)
        #expect(WalkUpMath.fadeVolume(progress: 0.5, startingFrom: 1) == 0.25)
        #expect(WalkUpMath.fadeVolume(progress: 1, startingFrom: 1) == 0)
        // A tap partway through a quieter moment fades from where it was.
        #expect(WalkUpMath.fadeVolume(progress: 0.5, startingFrom: 0.4) == 0.1)
        // Past the end stays silent; never louder than the start.
        #expect(WalkUpMath.fadeVolume(progress: 3, startingFrom: 1) == 0)
        #expect(WalkUpMath.fadeVolume(progress: -1, startingFrom: 1) == 1)
    }

    @Test("A tapped fade counts down its own 2 seconds")
    func fadeCountdown() {
        #expect(WalkUpMath.fadeSecondsLeft(now: 5.5, fadeStart: 5, fadeSeconds: 2) == 1.5)
        #expect(WalkUpMath.fadeSecondsLeft(now: 9, fadeStart: 5, fadeSeconds: 2) == 0)
    }

    @Test("A warm-up started at 30 seconds of a 40-second track goes back to 30 at the end")
    func warmUpLoopsToStartPoint() {
        let position = { (into: Double) in
            WalkUpMath.trackPosition(intoSong: into, offset: 30, firstPass: 10, loopStart: 30, loopLength: 10)
        }
        #expect(position(5) == 35)
        #expect(position(13) == 33)
        #expect(position(25) == 35)
    }

    @Test("A warm-up picked up mid-track after a speaker change finishes the track, then loops from the start point")
    func warmUpPickedUpMidTrack() {
        // Picked up at 37 seconds; the start point is 30; the track is 40 seconds.
        let position = WalkUpMath.trackPosition(intoSong: 5, offset: 37, firstPass: 3, loopStart: 30, loopLength: 10)
        #expect(position == 32)
    }

    @Test("A walk-up that does not repeat just counts up from where it started")
    func walkUpPosition() {
        #expect(WalkUpMath.trackPosition(intoSong: 4, offset: 10) == 14)
    }

    @Test("The slice played is 12 seconds from the start point, cut short at the end of the track")
    func slices() {
        let rate = 44_100.0
        let forty = Int64(40 * rate)
        let fromTen = WalkUpMath.slice(from: 10, length: 12, sampleRate: rate, fileFrames: forty)
        #expect(fromTen.firstFrame == 441_000)
        #expect(fromTen.frameCount == 529_200)
        // Starting at 35 seconds, only 5 seconds are left.
        let nearEnd = WalkUpMath.slice(from: 35, length: 12, sampleRate: rate, fileFrames: forty)
        #expect(nearEnd.frameCount == 220_500)
        // No length: to the end of the track.
        let toEnd = WalkUpMath.slice(from: 30, length: nil, sampleRate: rate, fileFrames: forty)
        #expect(toEnd.frameCount == 441_000)
        // A start point past the end never plays beyond the file.
        let beyond = WalkUpMath.slice(from: 99, length: 12, sampleRate: rate, fileFrames: forty)
        #expect(beyond.firstFrame == forty - 1)
        #expect(beyond.frameCount == 1)
    }

    @Test("A start point stays between the top of the track and a second before its end")
    func startPoints() {
        #expect(WalkUpMath.startPoint(-3, trackLength: 200) == 0)
        #expect(WalkUpMath.startPoint(45.5, trackLength: 200) == 45.5)
        #expect(WalkUpMath.startPoint(500, trackLength: 200) == 199)
        #expect(WalkUpMath.startPoint(500, trackLength: nil) == 500)
    }
}

@Suite("The stadium announcer’s words")
struct AnnouncerWordsTests {

    @Test("Number and name: “Now batting, number two, Derek Jeter.”")
    func numberAndName() {
        let jeter = Player(name: "Derek Jeter", number: "2")
        let words = AnnouncerVoice.phrases(for: jeter)?.map(\.words)
        #expect(words == ["Now batting,", "number 2,", "Derek Jeter."])
        // Long pauses between the parts, and none after the name, which ends it.
        let pauses = AnnouncerVoice.phrases(for: jeter)?.map(\.pauseAfter) ?? []
        #expect(pauses.dropLast().allSatisfy { $0 >= 0.5 })
        #expect(pauses.last == 0)
    }

    @Test("Name only, number only, and neither")
    func partialPlayers() {
        #expect(AnnouncerVoice.phrases(for: Player(name: "Derek Jeter"))?.map(\.words)
                == ["Now batting,", "Derek Jeter."])
        #expect(AnnouncerVoice.phrases(for: Player(number: "22"))?.map(\.words)
                == ["Now batting,", "number 22."])
        #expect(AnnouncerVoice.phrases(for: Player(placeholder: "Batter 4")) == nil)
        #expect(AnnouncerVoice.phrases(for: Player(name: "  ", number: "")) == nil)
    }

    @Test("“00” is “double zero”, “07” is “oh seven”, other numbers as they are")
    func jerseyNumbers() {
        #expect(AnnouncerVoice.spokenNumber("00") == "double zero")
        #expect(AnnouncerVoice.spokenNumber("07") == "oh 7")
        #expect(AnnouncerVoice.spokenNumber("0") == "0")
        #expect(AnnouncerVoice.spokenNumber("42") == "42")
    }
}
