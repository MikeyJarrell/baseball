// The arithmetic behind walk-up timing, kept apart from the sound so it can be tested on its
// own: how the song rises under the announcer, when the automatic fade begins, how loud the
// music is partway through a fade, how long until silence (the countdown), where a repeating
// warm-up song is in its track, and which slice of a sound file to play.

import Foundation
import Model

/// Walk-up timing sums. No sound, no clock: every answer depends only on what it is given.
enum WalkUpMath {
    /// Seconds of song a walk-up plays: the song's own play length if it has one, otherwise
    /// the walk-up length from the settings (12 seconds unless changed).
    static func songLength(for song: Song, walkUpLength: TimeInterval) -> TimeInterval {
        song.playLength ?? walkUpLength
    }

    /// How a walk-up is laid out when the announcer introduces the batter. The song starts at
    /// the same moment as the introduction and plays quietly under the voice. Only once the
    /// announcer has finished does it rise to full volume, over `finalRiseLength` seconds, so
    /// the end of the player's name is never covered. It starts early enough to reach its
    /// start point (the hook) just as it reaches full volume: the introduction plus the rise
    /// before the start point, but never before the top of the track. Then the usual length
    /// of song plays. With no introduction (length 0), the song simply starts at its start
    /// point.
    struct WalkUpPlan: Equatable {
        /// Seconds into the track where the song starts playing.
        var startsAt: TimeInterval
        /// Seconds after the tap's moment when the song reaches full volume: the end of the
        /// introduction plus the rise after it (0 with no introduction).
        var fullVolumeAfter: TimeInterval
        /// Seconds from the start of the walk-up until it is silent: the introduction, the
        /// rise after it, and the walk-up length. The countdown counts this down.
        var totalLength: TimeInterval
    }

    /// Lays out a walk-up: see `WalkUpPlan`. With 12 seconds of song, a start point at
    /// 0:20 and a 4-second introduction, the song starts at 0:14.5, rises from 0:18.5 as the
    /// announcer finishes, is at full volume at 0:20, and goes silent 17.5 seconds after the tap.
    static func walkUpPlan(startPoint: TimeInterval, introductionLength: TimeInterval,
                           songLength: TimeInterval) -> WalkUpPlan {
        let intro = max(0, introductionLength)
        let lead = intro > 0 ? intro + finalRiseLength : 0
        return WalkUpPlan(startsAt: max(0, startPoint - lead),
                          fullVolumeAfter: lead,
                          totalLength: lead + songLength)
    }

    /// About a third of full volume: how loud the song is under the announcer's voice.
    static let underVoiceLevel: Float = 0.33
    /// Seconds the song takes to rise from silence to `underVoiceLevel` at the start.
    static let gentleRiseLength: TimeInterval = 2
    /// Seconds the song takes to rise from `underVoiceLevel` to full volume, starting when
    /// the announcer finishes.
    static let finalRiseLength: TimeInterval = 1.5

    /// The song's volume, 0 to 1, `elapsed` seconds into a walk-up whose introduction is
    /// `introductionLength` seconds long: silent at first, rising gently to about a third
    /// under the voice, holding there until the announcer has finished, then rising to full
    /// volume over the next `finalRiseLength` seconds.
    static func fadeInVolume(elapsed: TimeInterval, introductionLength: TimeInterval) -> Float {
        let intro = max(0, introductionLength)
        guard intro > 0 else { return 1 }
        guard elapsed > 0 else { return 0 }
        let gentleRise = min(gentleRiseLength, intro)
        if elapsed < gentleRise {
            return underVoiceLevel * smoothStep(elapsed / gentleRise)
        }
        if elapsed < intro { return underVoiceLevel }
        return underVoiceLevel + (1 - underVoiceLevel) * smoothStep((elapsed - intro) / finalRiseLength)
    }

    /// An S-shaped step from 0 to 1: starts and ends gently, so a volume change has no bump.
    static func smoothStep(_ x: Double) -> Float {
        let t = Float(min(max(x, 0), 1))
        return t * t * (3 - 2 * t)
    }

    /// Seconds into the song when the automatic fade begins, chosen so the fade ends exactly
    /// when the walk-up length is up. With 12 seconds and a 2-second fade: at 10 seconds.
    /// A song shorter than the fade fades from the start.
    static func fadeBegins(songLength: TimeInterval, fadeLength: TimeInterval) -> TimeInterval {
        max(0, songLength - min(fadeLength, songLength))
    }

    /// The volume partway through a fade. `progress` runs from 0 (fade just started) to 1
    /// (silent). The curve drops gently at first and faster at the end, which sounds smoother
    /// than a straight line: halfway through, the volume is a quarter of where it started.
    static func fadeVolume(progress: Double, startingFrom start: Float) -> Float {
        let remaining = Float(1 - min(max(progress, 0), 1))
        return start * remaining * remaining
    }

    /// Seconds the music takes to come back to full volume when a fade is called off (the
    /// scorer asked to keep the song playing while it was fading).
    static let comeBackLength: TimeInterval = 0.4

    /// The volume partway through coming back from a called-off fade. `progress` runs from 0
    /// (the fade was just called off, at volume `start`) to 1 (full volume again).
    static func comeBackVolume(progress: Double, startingFrom start: Float) -> Float {
        start + (1 - start) * smoothStep(progress)
    }

    /// Seconds until a walk-up song goes quiet, for the countdown: from `now` to the song's
    /// start plus its length. Before the song starts (during the introduction) this includes
    /// the rest of the introduction. Never below zero.
    static func secondsLeft(now: Double, songStart: Double, songLength: TimeInterval) -> TimeInterval {
        max(0, songStart + songLength - now)
    }

    /// Seconds left in a fade that started at `fadeStart` and lasts `fadeSeconds`.
    static func fadeSecondsLeft(now: Double, fadeStart: Double, fadeSeconds: TimeInterval) -> TimeInterval {
        max(0, fadeSeconds - (now - fadeStart))
    }

    /// Where in the track a song is after playing for `intoSong` seconds from `offset`. A
    /// repeating warm-up first plays `firstPass` seconds (from the offset to the end of the
    /// track), then goes back to `loopStart` and plays `loopLength` seconds each time round.
    /// Leave `firstPass` out for a song that does not repeat.
    static func trackPosition(intoSong: TimeInterval, offset: TimeInterval, firstPass: TimeInterval? = nil,
                              loopStart: TimeInterval = 0, loopLength: TimeInterval? = nil) -> TimeInterval {
        guard let firstPass, let loopLength, loopLength > 0, intoSong >= firstPass else {
            return offset + intoSong
        }
        return loopStart + (intoSong - firstPass).truncatingRemainder(dividingBy: loopLength)
    }

    /// Which slice of a sound file to play: the first sample (“frame”) and how many, starting
    /// `seconds` into the track for `length` seconds (or to the end when `length` is missing),
    /// never running past the end of the file or starting beyond it.
    static func slice(from seconds: TimeInterval, length: TimeInterval?, sampleRate: Double,
                      fileFrames: Int64) -> (firstFrame: Int64, frameCount: UInt32) {
        let lastFrame = max(0, fileFrames - 1)
        let first = min(max(0, Int64(seconds * sampleRate)), lastFrame)
        let available = UInt32(clamping: fileFrames - first)
        let count = length.map { min(UInt32(clamping: Int64($0 * sampleRate)), available) } ?? available
        return (first, count)
    }

    /// A start point the scorer asked for, kept between the top of the track and one second
    /// before its end, so there is always some song to play.
    static func startPoint(_ seconds: TimeInterval, trackLength: TimeInterval?) -> TimeInterval {
        var start = max(0, seconds)
        if let trackLength { start = min(start, max(0, trackLength - 1)) }
        return start
    }
}
