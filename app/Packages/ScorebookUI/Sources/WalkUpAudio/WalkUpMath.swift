// The arithmetic behind walk-up timing, kept apart from the sound so it can be tested on its
// own: when the automatic fade begins, how loud the music is partway through a fade, how
// long until silence (the countdown), where a repeating warm-up song is in its track, and
// which slice of a sound file to play.

import Foundation
import Model

/// Walk-up timing sums. No sound, no clock: every answer depends only on what it is given.
enum WalkUpMath {
    /// Seconds of song a walk-up plays: the song's own play length if it has one, otherwise
    /// the walk-up length from the settings (12 seconds unless changed).
    static func songLength(for song: Song, walkUpLength: TimeInterval) -> TimeInterval {
        song.playLength ?? walkUpLength
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
