// Tests for introductions pieced together from Mikey's recordings: which recordings play, in
// what order, and what happens when a number has not been recorded yet.

import AVFoundation
import Foundation
import Model
import Testing
@testable import WalkUpAudio

@Suite("Introductions pieced together from recordings")
struct PiecedIntroductionTests {
    /// Aidan Kurt with a pieced introduction and the given jersey number.
    func aidan(number: String?) -> Player {
        Player(name: "Aidan Kurt", number: number,
               introduction: AnnouncerIntroduction(source: .pieced, fileName: AnnouncerIntroduction.nameFile("aidan-kurt")))
    }

    /// What is on the phone: "Now batting," Aidan's name, and the numbers 0 to 99.
    func onPhone(_ extra: [String] = []) -> (String) -> Bool {
        let files = Set([AnnouncerIntroduction.nowBattingFile, AnnouncerIntroduction.nameFile("aidan-kurt")]
                        + (0..<100).map { AnnouncerIntroduction.numberFile(String($0)) } + extra)
        return { files.contains($0) }
    }

    @Test("Number and name: “Now batting, number 22, Aidan Kurt.”, with the phone voice’s pauses")
    func numberAndName() {
        let pieces = PiecedIntroduction.pieces(for: aidan(number: "22"), hasFile: onPhone())
        #expect(pieces?.map(\.fileName) == ["announcer-now-batting.m4a", "announcer-number-22.m4a",
                                            "announcer-name-aidan-kurt.m4a"])
        let voicePauses = AnnouncerVoice.phrases(for: aidan(number: "22"))?.map(\.pauseAfter)
        #expect(pieces?.map(\.pauseAfter) == voicePauses)
    }

    @Test("No number yet, or a number never recorded (“07”), leaves the number out")
    func missingNumber() {
        let nameOnly = ["announcer-now-batting.m4a", "announcer-name-aidan-kurt.m4a"]
        #expect(PiecedIntroduction.pieces(for: aidan(number: nil), hasFile: onPhone())?.map(\.fileName) == nameOnly)
        #expect(PiecedIntroduction.pieces(for: aidan(number: "07"), hasFile: onPhone())?.map(\.fileName) == nameOnly)
    }

    @Test("Without “Now batting” or the name recording there is no introduction")
    func missingPieces() {
        let noNowBatting: (String) -> Bool = { $0 != AnnouncerIntroduction.nowBattingFile }
        #expect(PiecedIntroduction.pieces(for: aidan(number: "22"), hasFile: noNowBatting) == nil)
        let noName: (String) -> Bool = { !$0.hasPrefix("announcer-name-") }
        #expect(PiecedIntroduction.pieces(for: aidan(number: "22"), hasFile: noName) == nil)
    }

    @Test("The pieces join end to end with silence between them")
    func joining() throws {
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1))
        // Every piece is a tenth of a second of sound.
        let read: (URL) -> AVAudioPCMBuffer? = { _ in
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4_800)
            buffer?.frameLength = 4_800
            return buffer
        }
        let pieces = try #require(PiecedIntroduction.pieces(for: aidan(number: "22"), hasFile: onPhone()))
        let sound = try #require(PiecedIntroduction.render(pieces, from: URL(fileURLWithPath: "/"), read: read))
        // Three pieces of 0.1 s plus pauses of 0.55 and 0.5 s: 1.35 seconds.
        #expect(abs(Double(sound.frameLength) / 48_000 - 1.35) < 0.001)
        // A missing piece means no introduction at all, never a clipped one.
        #expect(PiecedIntroduction.render(pieces, from: URL(fileURLWithPath: "/"), read: { _ in nil }) == nil)
    }
}
