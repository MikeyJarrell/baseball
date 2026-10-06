// Cleaning up a player's name recorded on the phone, so it fits with the announcer pieces
// recorded on the Mac ("Now batting," and every jersey number): the same sound format
// (48,000 samples a second, one channel), silence trimmed from both ends, low rumble filtered
// out, and the loudness evened out to the same level. It follows tools/record_intros.py step
// by step, so a name recorded in the app sounds like one recorded on the Mac.

import AVFoundation

/// What went wrong with a recorded name, in words for the scorer.
public enum NameTakeProblem: Error, Equatable, Sendable {
    /// The take is too short to hold anything.
    case nothingRecorded
    /// The take is silence.
    case noVoice

    /// A sentence to show the scorer.
    public var message: String {
        switch self {
        case .nothingRecorded: "Nothing was recorded. Try again."
        case .noVoice: "No voice was heard. Hold the phone closer and say the name again."
        }
    }
}

enum NameTake {
    /// Samples a second, as the Mac's announcer pieces are recorded.
    static let rate: Double = 48_000
    /// Anything this far below the loudest moment counts as silence.
    static let voiceBelowPeakDB: Float = 35
    /// Seconds of quiet kept before the first sound, so a "p" is not clipped.
    static let keepBefore: Double = 0.05
    /// Seconds kept after the last sound, so a trailing "s" rings out.
    static let keepAfter: Double = 0.15
    /// The spoken part's average level, in decibels below full scale.
    static let targetLoudnessDB: Float = -18
    /// Never louder than this at any instant.
    static let peakLimitDB: Float = -1

    /// Trims and levels one take: one channel at `rate` samples a second. Throws when there is
    /// no voice in it.
    static func clean(_ input: [Float], rate: Double = rate) throws -> [Float] {
        guard input.count >= Int(rate / 10) else { throw NameTakeProblem.nothingRecorded }
        let audio = highPass(input, cutoff: 70, rate: rate)

        // Loudness in 10-millisecond steps, to find where the voice starts and stops.
        let step = Int(rate / 100)
        let frameCount = audio.count / step
        let frameDB: [Float] = (0..<frameCount).map { f in
            var power: Float = 0
            for i in (f * step)..<((f + 1) * step) { power += audio[i] * audio[i] }
            return 20 * log10((power / Float(step)).squareRoot() + 1e-9)
        }
        guard let loudest = frameDB.max(), loudest >= -55 else { throw NameTakeProblem.noVoice }
        let voiced = frameDB.indices.filter { frameDB[$0] > loudest - voiceBelowPeakDB }
        guard let first = voiced.first, let last = voiced.last else { throw NameTakeProblem.noVoice }
        let start = max(0, first * step - Int(keepBefore * rate))
        let end = min(audio.count, (last + 1) * step + Int(keepAfter * rate))
        var trimmed = Array(audio[start..<end])

        // Even out the loudness: the spoken part's average level goes to the target, without
        // letting any instant go past the peak limit.
        let spoken = frameDB[first...last]
        let spokenLevel = 10 * log10(spoken.map { pow(10, $0 / 10) }.reduce(0, +) / Float(spoken.count))
        var gain = pow(10, (targetLoudnessDB - spokenLevel) / 20)
        let peak = (trimmed.map(abs).max() ?? 0) * gain
        if peak > 0 { gain *= min(1, pow(10, peakLimitDB / 20) / peak) }
        for i in trimmed.indices { trimmed[i] *= gain }

        // Short fades at both ends so the stitched pieces never click.
        let fadeIn = min(trimmed.count, Int(0.01 * rate)), fadeOut = min(trimmed.count, Int(0.03 * rate))
        for i in 0..<fadeIn { trimmed[i] *= Float(i) / Float(fadeIn) }
        for i in 0..<fadeOut { trimmed[trimmed.count - 1 - i] *= Float(i) / Float(fadeOut) }
        return trimmed
    }

    /// Takes out low rumble (a hand on the phone, wind) below the voice.
    static func highPass(_ samples: [Float], cutoff: Double, rate: Double) -> [Float] {
        let rc = 1 / (2 * Double.pi * cutoff), dt = 1 / rate
        let a = Float(rc / (rc + dt))
        var out = [Float](repeating: 0, count: samples.count)
        for i in 1..<max(1, samples.count) {
            out[i] = a * (out[i - 1] + samples[i] - samples[i - 1])
        }
        return out
    }

    /// Reads a sound file as one channel at `rate` samples a second.
    static func readMono(_ url: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        guard let source = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)) else {
            throw NameTakeProblem.nothingRecorded
        }
        try file.read(into: source)
        guard let target = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: rate, channels: 1, interleaved: false),
              let converter = AVAudioConverter(from: source.format, to: target) else { throw NameTakeProblem.nothingRecorded }
        let capacity = AVAudioFrameCount(Double(source.frameLength) * rate / source.format.sampleRate) + 1024
        guard let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { throw NameTakeProblem.nothingRecorded }
        var handed = false
        var error: NSError?
        converter.convert(to: output, error: &error) { _, status in
            if handed { status.pointee = .endOfStream; return nil }
            handed = true
            status.pointee = .haveData
            return source
        }
        if let error { throw error }
        guard let channel = output.floatChannelData?[0] else { throw NameTakeProblem.nothingRecorded }
        return Array(UnsafeBufferPointer(start: channel, count: Int(output.frameLength)))
    }

    /// Writes samples (one channel at `rate`) as an M4A file, as the Mac pieces are saved.
    static func write(_ samples: [Float], to url: URL) throws {
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: rate, channels: 1, interleaved: false),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)) else {
            throw NameTakeProblem.nothingRecorded
        }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { buffer.floatChannelData![0].update(from: $0.baseAddress!, count: samples.count) }
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: rate,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 192_000,
        ]
        // The file is finished when it goes out of scope at the end of this function.
        let file = try AVAudioFile(forWriting: url, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false)
        try file.write(from: buffer)
    }
}
