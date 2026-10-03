// Makes three short made-up “songs” for the audio test screen, so playback can be checked
// in the simulator without real music. Each is 40 seconds of simple tones with a click on
// every second and a new note every five seconds, so you can hear where you are when
// setting a start point. They come in three file types (WAV, M4A and AAC) so the import
// is checked for each.

import AVFoundation
import Foundation

/// Writes the three test songs.
public enum TestSongMaker {
    /// One test song: its file name and the notes it steps through (in hertz, pitch).
    private struct Recipe {
        var fileName: String
        var notes: [Double]
        var settings: [String: Any]
    }

    /// Writes the test songs into `folder` and returns where they are. The folder plays the
    /// part of the Files app: the songs are then imported from it like any other file.
    public static func makeTestSongs(in folder: URL) throws -> [URL] {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let wav: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: 44_100, AVNumberOfChannelsKey: 2,
            AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false,
        ]
        let aac: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44_100, AVNumberOfChannelsKey: 2,
        ]
        let recipes = [
            Recipe(fileName: "Test song - climbing.wav", notes: [262, 294, 330, 349, 392, 440, 494, 523], settings: wav),
            Recipe(fileName: "Test song - falling.m4a", notes: [523, 494, 440, 392, 349, 330, 294, 262], settings: aac),
            Recipe(fileName: "Test song - low hum.aac", notes: [131, 165, 196, 131, 165, 196, 131, 165], settings: aac),
        ]
        return try recipes.map { try write($0, in: folder) }
    }

    /// Writes one test song: eight five-second notes, a click every second.
    private static func write(_ recipe: Recipe, in folder: URL) throws -> URL {
        let url = folder.appending(path: recipe.fileName)
        try? FileManager.default.removeItem(at: url)
        let rate = 44_100.0
        let seconds = 40
        guard let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(rate) * AVAudioFrameCount(seconds)),
              let channels = buffer.floatChannelData
        else { throw CocoaError(.fileWriteUnknown) }

        let total = Int(rate) * seconds
        for i in 0..<total {
            let time = Double(i) / rate
            let note = recipe.notes[min(recipe.notes.count - 1, Int(time) / 5)]
            // A soft tone, at a fifth of full volume, so the test is not deafening.
            var sample = 0.2 * sin(2 * .pi * note * time)
            // A short click at the top of every second.
            let intoSecond = time - floor(time)
            if intoSecond < 0.01 { sample += 0.3 * sin(2 * .pi * 1_500 * time) }
            channels[0][i] = Float(sample)
            channels[1][i] = Float(sample)
        }
        buffer.frameLength = AVAudioFrameCount(total)

        // The file is finished and closed when `file` goes away at the end of this block.
        do {
            let file = try AVAudioFile(forWriting: url, settings: recipe.settings,
                                       commonFormat: .pcmFormatFloat32, interleaved: false)
            try file.write(from: buffer)
        }
        return url
    }
}
