// The sound "wiring" inside the player: which pieces the audio flows through on its way
// to the speaker.
//
//   song player ───────────────────────────────────────────────┐
//                                                               ├─> main mixer ─> speaker
//   announcer player ─> announcer mixer ─> echo ─> stadium hall ┘
//
// Songs go straight to the speaker. Announcer introductions go through two effects that
// make a living-room recording sound like a ballpark public-address system: a short
// bouncing echo (the sound coming back off the far stands) and a big-hall reverb. The
// "announcer echo" setting turns both up or down together.
//
// Fades work on the main mixer's volume, so a fade quiets the announcer and the song alike.

import AVFoundation
import Synchronization

/// The audio engine and the pieces plugged into it. Rebuilt from scratch if iOS resets its
/// audio system (rare, but it happens), which is why it is a separate object.
@MainActor
final class AudioGraph {
    /// Apple's audio engine: runs the chain below.
    let engine = AVAudioEngine()
    /// Plays songs: walk-ups, previews and warm-ups.
    let songNode = AVAudioPlayerNode()
    /// Plays announcer introductions.
    let introNode = AVAudioPlayerNode()
    /// Takes the introduction in whatever shape it was recorded (one channel or two, any
    /// sample rate) and hands the effects a standard stereo signal.
    let introMixer = AVAudioMixerNode()
    /// The bounce off the far stands.
    let echo = AVAudioUnitDelay()
    /// The size of the ballpark.
    let hall = AVAudioUnitReverb()
    /// Measures how loud the output is, for the level meter on the test screen.
    let meter = LevelMeter()

    /// Which input of the main mixer each chain uses. Fixed numbers so reconnecting the song
    /// player for a new file always reuses the same input.
    private let songBus: AVAudioNodeBus = 0
    private let announcerBus: AVAudioNodeBus = 1

    init() {
        for node in [songNode, introNode, introMixer, echo, hall] as [AVAudioNode] {
            engine.attach(node)
        }
        let main = engine.mainMixerNode
        // A standard stereo shape for the effects chain, at the speaker's own sample rate.
        let stereo = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)
        engine.connect(songNode, to: main, fromBus: 0, toBus: songBus, format: stereo)
        engine.connect(introNode, to: introMixer, format: stereo)
        engine.connect(introMixer, to: echo, format: stereo)
        engine.connect(echo, to: hall, format: stereo)
        engine.connect(hall, to: main, fromBus: 0, toBus: announcerBus, format: stereo)

        // The echo: one clear repeat about a quarter second later, fading over a few
        // repeats, with the highs rolled off the way distance does.
        echo.delayTime = 0.26
        echo.feedback = 28
        echo.lowPassCutoff = 3_500
        // The hall: Apple's largest concert-hall setting.
        hall.loadFactoryPreset(.largeHall2)
        setEcho(0.5)

        // Listen to everything leaving the main mixer, to measure loudness. The audio system
        // calls this from its own thread, so it is marked `@Sendable` (safe on any thread)
        // instead of belonging to the main thread like the rest of this class.
        let meter = self.meter
        main.installTap(onBus: 0, bufferSize: 2_048, format: nil) { @Sendable buffer, _ in
            meter.measure(buffer)
        }
    }

    /// Sets the stadium echo from 0 (a dry voice) to 1 (a cavernous ballpark).
    func setEcho(_ amount: Double) {
        let amount = Float(min(max(amount, 0), 1))
        // "Wet/dry mix" is how much of the effect is heard, as a percentage.
        echo.wetDryMix = amount * 35
        hall.wetDryMix = amount * 55
    }

    /// Plugs the song player in with the shape of the file about to play, since songs come
    /// in different sample rates and channel counts.
    func connectSongPlayer(format: AVAudioFormat) {
        engine.disconnectNodeOutput(songNode)
        engine.connect(songNode, to: engine.mainMixerNode, fromBus: 0, toBus: songBus, format: format)
    }

    /// Plugs the announcer player in with the shape of the introduction about to play.
    func connectIntroPlayer(format: AVAudioFormat) {
        engine.disconnectNodeOutput(introNode)
        engine.connect(introNode, to: introMixer, format: format)
    }
}

/// Measures how loud the sound leaving the app is. The measuring happens on the audio
/// system's own thread; the player reads the latest value on the main thread.
final class LevelMeter: Sendable {
    /// The latest loudness, 0 (silence) to about 1 (full scale). Guarded by a lock because
    /// two threads touch it.
    private let level = Mutex<Float>(0)

    /// Works out the average loudness of one slice of sound (its "root mean square").
    nonisolated func measure(_ buffer: AVAudioPCMBuffer) {
        guard let channels = buffer.floatChannelData, buffer.frameLength > 0 else { return }
        let frames = Int(buffer.frameLength)
        var sum: Float = 0
        for i in 0..<frames {
            let sample = channels[0][i]
            sum += sample * sample
        }
        let rms = (sum / Float(frames)).squareRoot()
        level.withLock { $0 = rms }
    }

    /// The most recent loudness measured.
    nonisolated var current: Float { level.withLock { $0 } }

    /// Back to silence, for when the engine stops (it sends no more slices to measure).
    nonisolated func reset() { level.withLock { $0 = 0 } }
}
