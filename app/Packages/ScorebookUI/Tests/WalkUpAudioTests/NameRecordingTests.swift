// Tests of a player's name recorded in the app: the take is trimmed and leveled like the Mac's
// announcer pieces, saved at the same sound format so the pieces join, and kept as the
// player's name recording; a pieced introduction with no jersey number still plays.

import AVFoundation
import Foundation
import Model
import Testing
@testable import WalkUpAudio

@Suite("Recording a player's name in the app")
struct NameRecordingTests {
    /// Half a second of silence, half a second of a 300 Hz tone at a quiet level, then a
    /// second of silence, at `rate` samples a second.
    static func take(rate: Double) -> [Float] {
        let silence = [Float](repeating: 0, count: Int(rate / 2))
        let tone = (0..<Int(rate / 2)).map { Float(0.05 * sin(2 * Double.pi * 300 * Double($0) / rate)) }
        return silence + tone + silence + silence
    }

    @Test("Silence is trimmed to just before and after the voice, and the level is raised")
    func trimsAndLevels() throws {
        let rate = NameTake.rate
        let cleaned = try NameTake.clean(Self.take(rate: rate))
        // The tone's half second, plus 0.05 s kept before and 0.15 s after, give or take a step.
        let seconds = Double(cleaned.count) / rate
        #expect(abs(seconds - 0.70) < 0.03)
        // Louder than the quiet take, and never past the peak limit (-1 dB is 0.891).
        let peak = cleaned.map(abs).max() ?? 0
        #expect(peak > 0.1)
        #expect(peak <= 0.892)
    }

    @Test("A take with no voice says so")
    func silenceIsRefused() {
        #expect(throws: NameTakeProblem.noVoice) { try NameTake.clean([Float](repeating: 0, count: 48_000)) }
        #expect(throws: NameTakeProblem.nothingRecorded) { try NameTake.clean([0, 0, 0]) }
    }

    @Test("A take recorded on the phone becomes the player's name piece, at the Mac pieces' format")
    @MainActor
    func keepsANamePiece() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "name-recording-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        // A raw take as the phone records it: 44,100 samples a second, compressed.
        let raw = folder.appending(path: "intro-take.m4a")
        let samples = Self.take(rate: 44_100)
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44_100, channels: 1, interleaved: false)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))!
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { buffer.floatChannelData![0].update(from: $0.baseAddress!, count: samples.count) }
        do {
            let file = try AVAudioFile(forWriting: raw, settings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44_100,
                                                                    AVNumberOfChannelsKey: 1],
                                       commonFormat: .pcmFormatFloat32, interleaved: false)
            try file.write(from: buffer)
        }

        let player = StadiumAudioPlayer(audioFolder: folder)
        let candidate = try player.makeNameCandidate(from: AnnouncerIntroduction(source: .recorded, fileName: raw.lastPathComponent))
        #expect(candidate.source == .pieced)
        #expect(!FileManager.default.fileExists(atPath: raw.path), "the raw take is deleted")
        let kept = try player.keepNameRecording(candidate, stem: "jackson-cleary")
        #expect(kept == AnnouncerIntroduction(source: .pieced, fileName: "announcer-name-jackson-cleary.m4a"))
        let saved = try AVAudioFile(forReading: folder.appending(path: kept.fileName!))
        #expect(saved.fileFormat.sampleRate == 48_000)
        #expect(saved.fileFormat.channelCount == 1)
        let seconds = Double(saved.length) / saved.fileFormat.sampleRate
        #expect(seconds > 0.6 && seconds < 0.85)
        #expect(!FileManager.default.fileExists(atPath: folder.appending(path: candidate.fileName!).path))
    }

    @Test("With no jersey number, the pieced introduction is “Now batting,” then the name")
    func noNumber() {
        let name = AnnouncerIntroduction.nameFile("jackson-cleary")
        let jackson = Player(name: "Jackson Cleary", introduction: AnnouncerIntroduction(source: .pieced, fileName: name))
        let pieces = PiecedIntroduction.pieces(for: jackson) { _ in true }
        #expect(pieces?.map(\.fileName) == [AnnouncerIntroduction.nowBattingFile, name])
    }
}
