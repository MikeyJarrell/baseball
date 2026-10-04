// An introduction in Mikey's own voice, put together at play time from short recordings:
// "Now batting, … number twenty-two, … Aidan Kurt."
// "Now batting," and every jersey number are shared by the whole team, and each player has a
// recording of their name. Changing a player's number in the app changes their introduction
// with nothing new to record.
//
// The pieces are recorded on the Mac with tools/record_intros.py and copied onto the phone by
// tools/load_team.sh. Their file names are in `AnnouncerIntroduction` (the Model module).

import AVFoundation
import Model

/// One recorded piece of the introduction, and how long to wait after it.
struct IntroductionPiece: Equatable, Sendable {
    /// The file's name in the app's audio folder.
    var fileName: String
    /// Seconds of silence after the piece.
    var pauseAfter: TimeInterval
}

enum PiecedIntroduction {
    /// Which recordings make this player's introduction, in order, with the same pauses the
    /// phone's voice uses. `hasFile` says whether a recording is on the phone.
    ///
    /// - Number and name: "Now batting, … number twenty-two, … Aidan Kurt."
    /// - No number, or no recording of that number: "Now batting, … Aidan Kurt."
    ///
    /// Returns nothing when the name recording or "Now batting" is missing.
    static func pieces(for player: Player, hasFile: (String) -> Bool) -> [IntroductionPiece]? {
        guard let introduction = player.introduction, introduction.source == .pieced,
              let nameFile = introduction.fileName, hasFile(nameFile),
              hasFile(AnnouncerIntroduction.nowBattingFile) else { return nil }

        let number = player.number?.trimmingCharacters(in: .whitespaces) ?? ""
        let numberFile = AnnouncerIntroduction.numberFile(number)
        guard !number.isEmpty, hasFile(numberFile) else {
            return [IntroductionPiece(fileName: AnnouncerIntroduction.nowBattingFile, pauseAfter: 0.55),
                    IntroductionPiece(fileName: nameFile, pauseAfter: 0)]
        }
        return [IntroductionPiece(fileName: AnnouncerIntroduction.nowBattingFile, pauseAfter: 0.55),
                IntroductionPiece(fileName: numberFile, pauseAfter: 0.5),
                IntroductionPiece(fileName: nameFile, pauseAfter: 0)]
    }

    /// Reads the pieces and joins them, pauses included, into one piece of sound. Returns
    /// nothing if any piece is missing, will not read, or is in a different sound format from
    /// the others (the Mac script records them all alike).
    static func render(_ pieces: [IntroductionPiece], from folder: URL,
                       read: (URL) -> AVAudioPCMBuffer?) -> AVAudioPCMBuffer? {
        var sounds: [AVAudioPCMBuffer] = []
        for piece in pieces {
            guard let sound = read(folder.appending(path: piece.fileName)) else { return nil }
            if let first = sounds.first, first.format != sound.format { return nil }
            sounds.append(sound)
            if piece.pauseAfter > 0, let silence = AnnouncerVoice.silence(piece.pauseAfter, like: sound) {
                sounds.append(silence)
            }
        }
        return AnnouncerVoice.joined(sounds)
    }
}
