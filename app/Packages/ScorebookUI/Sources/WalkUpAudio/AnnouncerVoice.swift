// The phone's built-in speech voice as the stadium announcer, for players without a
// recording of their own yet.
//
// It reads “Now batting, number two, Derek Jeter.” slowly and low, with long
// pauses between the parts, in the old Yankee Stadium style. Instead of speaking out loud
// directly, it turns the words into sound in memory, so the introduction can go through
// the same stadium echo as a recording and be ready before the button is tapped.

import AVFoundation
import Model

/// One phrase the announcer says, and how long to wait after it.
struct AnnouncerPhrase: Equatable, Sendable {
    var words: String
    /// Seconds of silence after the phrase.
    var pauseAfter: TimeInterval
}

/// Turns a player's number and name into the announcer's words, then into sound.
@MainActor
final class AnnouncerVoice {
    /// Apple's speech engine. Kept alive while it works.
    private let synthesizer = AVSpeechSynthesizer()

    /// What the announcer says for this player, phrase by phrase, or nothing when the
    /// player has neither a name nor a number.
    ///
    /// - Number and name: “Now batting, … number two, … Derek Jeter.”
    /// - Name only: “Now batting, … Derek Jeter.”
    /// - Number only: “Now batting, … number twenty-two.”
    nonisolated static func phrases(for player: Player) -> [AnnouncerPhrase]? {
        let name = player.name?.trimmingCharacters(in: .whitespaces)
        let number = player.number?.trimmingCharacters(in: .whitespaces)
        let hasName = !(name ?? "").isEmpty
        let hasNumber = !(number ?? "").isEmpty
        guard hasName || hasNumber else { return nil }

        var phrases = [AnnouncerPhrase(words: "Now batting,", pauseAfter: 0.55)]
        if hasNumber, let number {
            let spoken = spokenNumber(number)
            if hasName, let name {
                phrases.append(AnnouncerPhrase(words: "number \(spoken),", pauseAfter: 0.5))
                phrases.append(AnnouncerPhrase(words: "\(name).", pauseAfter: 0))
            } else {
                phrases.append(AnnouncerPhrase(words: "number \(spoken).", pauseAfter: 0))
            }
        } else if let name {
            phrases.append(AnnouncerPhrase(words: "\(name).", pauseAfter: 0))
        }
        return phrases
    }

    /// Jersey numbers as an announcer says them: “00” is “double zero”, “07” is “oh seven”,
    /// anything else is read as an ordinary number.
    nonisolated static func spokenNumber(_ number: String) -> String {
        if number == "00" { return "double zero" }
        if number.count == 2, number.hasPrefix("0") { return "oh \(number.dropFirst())" }
        return number
    }

    /// The chosen voice's identifier, looked up once in the background (see `findVoice`).
    private var voiceLookup: Task<String?, Never>?

    /// Starts choosing the voice in the background. The player calls it when it is made:
    /// the first time an iPhone lists its voices it can take a long while (minutes, on a
    /// freshly set-up simulator), and doing that on the main thread would freeze the screen.
    func findVoice() {
        _ = voiceLookupTask()
    }

    private func voiceLookupTask() -> Task<String?, Never> {
        if let voiceLookup { return voiceLookup }
        let lookup = Task.detached(priority: .utility) { Self.bestVoiceIdentifier() }
        voiceLookup = lookup
        return lookup
    }

    /// The voice to use: the best-quality American English voice on the phone, a male one
    /// if there is a choice, skipping Apple's novelty voices (the ones that sing or whisper).
    /// Slow the first time, so it runs in the background.
    nonisolated static func bestVoiceIdentifier() -> String? {
        let candidates = AVSpeechSynthesisVoice.speechVoices().filter { voice in
            voice.language == "en-US"
                && !voice.identifier.contains("speech.synthesis.voice")   // novelty voices
                && !voice.identifier.contains("eloquence")                // robotic voices
        }
        let ranked = candidates.sorted { a, b in
            if a.quality != b.quality { return a.quality.rawValue > b.quality.rawValue }
            return (a.gender == .male ? 1 : 0) > (b.gender == .male ? 1 : 0)
        }
        return ranked.first?.identifier
    }

    /// Makes the whole introduction as one piece of sound, pauses included. Returns nothing
    /// if the player has no name or number, or the phone could not make all of the speech
    /// (a clipped introduction is worse than none, and would otherwise be kept and replayed).
    func render(for player: Player) async -> AVAudioPCMBuffer? {
        guard let phrases = Self.phrases(for: player) else { return nil }
        // Wait (without blocking the screen) for the background voice lookup.
        let identifier = await voiceLookupTask().value
        let voice = identifier.flatMap { AVSpeechSynthesisVoice(identifier: $0) }
            ?? AVSpeechSynthesisVoice(language: "en-US")
        var pieces: [AVAudioPCMBuffer] = []
        for phrase in phrases {
            let utterance = AVSpeechUtterance(string: phrase.words)
            utterance.voice = voice
            // Slower and lower than everyday speech: the announcer takes his time.
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.82
            utterance.pitchMultiplier = 0.82
            utterance.prefersAssistiveTechnologySettings = false
            guard let spoken = await speak(utterance) else { return nil }
            pieces.append(spoken)
            if phrase.pauseAfter > 0, let silence = Self.silence(phrase.pauseAfter, like: spoken) {
                pieces.append(silence)
            }
        }
        return Self.joined(pieces)
    }

    /// Turns one phrase into sound in memory. Gives up after a few seconds, so a phone with
    /// no voices installed never leaves the play button waiting forever; a phrase that did
    /// not finish in time counts as failed.
    private func speak(_ utterance: AVSpeechUtterance) async -> AVAudioPCMBuffer? {
        let collector = SpeechCollector()
        let pieces = await withCheckedContinuation { (continuation: CheckedContinuation<SpeechPieces, Never>) in
            collector.whenDone { continuation.resume(returning: $0) }
            // The speech engine calls this from its own thread, hence `@Sendable`.
            synthesizer.write(utterance) { @Sendable buffer in
                collector.add(buffer)
            }
            // The safety net: give up after six seconds.
            Task {
                try? await Task.sleep(for: .seconds(6))
                collector.finish(complete: false)
            }
        }
        guard pieces.complete else { return nil }
        return pieces.joinedAsFloat()
    }

    /// A stretch of silence the same shape as `buffer`.
    nonisolated static func silence(_ seconds: TimeInterval, like buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        let frames = AVAudioFrameCount(seconds * buffer.format.sampleRate)
        guard let silent = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: frames) else { return nil }
        silent.frameLength = frames   // new buffers start out filled with zeros: silence
        return silent
    }

    /// Glues pieces of sound of the same shape end to end.
    nonisolated static func joined(_ pieces: [AVAudioPCMBuffer]) -> AVAudioPCMBuffer? {
        guard let format = pieces.first?.format else { return nil }
        let matching = pieces.filter { $0.format == format }
        let total = matching.reduce(AVAudioFrameCount(0)) { $0 + $1.frameLength }
        guard total > 0, let whole = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: total),
              let target = whole.floatChannelData else { return nil }
        var written = 0
        for piece in matching {
            guard let source = piece.floatChannelData else { continue }
            let count = Int(piece.frameLength)
            for channel in 0..<Int(format.channelCount) {
                (target[channel] + written).update(from: source[channel], count: count)
            }
            written += count
        }
        whole.frameLength = AVAudioFrameCount(written)
        return whole
    }
}

/// The slices of sound the speech engine hands back for one phrase. The engine delivers
/// them on its own thread, so this is passed between threads by hand.
struct SpeechPieces: @unchecked Sendable {
    var buffers: [AVAudioPCMBuffer] = []
    /// True when the speech engine said it had finished; false when the safety net fired.
    var complete = false

    /// Joins the slices into one piece of sound in the standard floating-point shape the
    /// audio engine expects (the speech engine often delivers whole numbers instead).
    func joinedAsFloat() -> AVAudioPCMBuffer? {
        guard let first = buffers.first(where: { $0.frameLength > 0 }) else { return nil }
        let source = first.format
        guard let floatFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32, sampleRate: source.sampleRate,
            channels: source.channelCount, interleaved: false
        ) else { return nil }
        var converted: [AVAudioPCMBuffer] = []
        for buffer in buffers where buffer.frameLength > 0 && buffer.format == source {
            if source == floatFormat { converted.append(buffer); continue }
            guard let converter = AVAudioConverter(from: source, to: floatFormat),
                  let out = AVAudioPCMBuffer(pcmFormat: floatFormat, frameCapacity: buffer.frameLength)
            else { continue }
            do {
                try converter.convert(to: out, from: buffer)
                converted.append(out)
            } catch { continue }
        }
        return AnnouncerVoice.joined(converted)
    }
}

/// Collects speech slices as they arrive and reports once, when the last one comes (an
/// empty slice, meaning complete) or the safety net fires (incomplete), whichever is first.
private final class SpeechCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var pieces = SpeechPieces()
    private var done: ((SpeechPieces) -> Void)?
    private var finished = false

    func whenDone(_ handler: @escaping (SpeechPieces) -> Void) {
        lock.withLock { done = handler }
    }

    func add(_ buffer: AVAudioBuffer) {
        guard let pcm = buffer as? AVAudioPCMBuffer else { return }
        if pcm.frameLength == 0 { finish(complete: true); return }   // an empty slice means "that's all"
        lock.withLock { if !finished { pieces.buffers.append(pcm) } }
    }

    func finish(complete: Bool) {
        let report: ((SpeechPieces) -> Void)? = lock.withLock {
            guard !finished else { return nil }
            finished = true
            pieces.complete = complete
            return done
        }
        report?(lock.withLock { pieces })
    }
}
