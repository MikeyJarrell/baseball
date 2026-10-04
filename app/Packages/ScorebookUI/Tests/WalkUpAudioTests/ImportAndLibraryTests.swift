// Tests for copying sound files in and for the song library: which files are accepted, the
// message for each that is not, no file ever overwritten, introductions kept short, and the
// library edits the songs screen makes.

import Foundation
import Model
import Testing
@testable import WalkUpAudio

/// A fresh, empty pair of folders for one test: “picked” plays the Files app, “audio” is the
/// app's own audio folder.
private func freshFolders() throws -> (picked: URL, audio: URL) {
    let base = FileManager.default.temporaryDirectory.appending(path: "WalkUpAudioTests-\(UUID().uuidString)")
    let picked = base.appending(path: "picked")
    let audio = base.appending(path: "audio")
    try FileManager.default.createDirectory(at: picked, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: audio, withIntermediateDirectories: true)
    return (picked, audio)
}

/// The names of the files in a folder.
private func names(in folder: URL) -> Set<String> {
    Set((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? [])
}

@Suite("Importing sound files")
struct ImportTests {

    @Test("WAV, M4A and AAC test songs come in with their lengths, named after their files")
    func goodFilesComeIn() async throws {
        let folders = try freshFolders()
        let files = try TestSongMaker.makeTestSongs(in: folders.picked)
        let player = await StadiumAudioPlayer(audioFolder: folders.audio)
        let report = await player.importSongsWithReport(from: files)
        #expect(report.problems.isEmpty)
        #expect(report.songs.map(\.title) == ["Test song - climbing", "Test song - falling", "Test song - low hum"])
        for song in report.songs {
            let seconds = try #require(song.duration)
            #expect(abs(seconds - 40) < 0.2)
        }
        #expect(names(in: folders.audio).count == 3)
    }

    @Test("Importing the same file twice keeps both, the second as “… 2”")
    func sameNameTwice() async throws {
        let folders = try freshFolders()
        let file = try #require(TestSongMaker.makeTestSongs(in: folders.picked).first)
        let first = try await SoundFileImporter.copyIn(file, to: folders.audio)
        let second = try await SoundFileImporter.copyIn(file, to: folders.audio)
        #expect(first.fileName == "Test song - climbing.wav")
        #expect(second.fileName == "Test song - climbing 2.wav")
    }

    @Test("A text file is refused by its name, with a message saying which files work")
    func notASoundFile() async throws {
        let folders = try freshFolders()
        let notes = folders.picked.appending(path: "lineup.txt")
        try "Jeter SS".write(to: notes, atomically: true, encoding: .utf8)
        await #expect(throws: WalkUpAudioError.cannotImport(
            fileName: "lineup.txt",
            reason: "It is not a sound file the app can play. Use an MP3, M4A, WAV or AAC file."
        )) {
            try await SoundFileImporter.copyIn(notes, to: folders.audio)
        }
        #expect(names(in: folders.audio).isEmpty)
    }

    @Test("A file named .mp3 that is not really sound is refused and its copy removed")
    func fakeMP3() async throws {
        let folders = try freshFolders()
        let fake = folders.picked.appending(path: "Thunderstruck.mp3")
        try "not music".write(to: fake, atomically: true, encoding: .utf8)
        do {
            _ = try await SoundFileImporter.copyIn(fake, to: folders.audio)
            Issue.record("A fake MP3 was accepted")
        } catch {
            guard case .cannotImport(let name, let reason) = error else {
                Issue.record("Wrong problem: \(error)")
                return
            }
            #expect(name == "Thunderstruck.mp3")
            #expect(reason.contains("cannot play"))
        }
        #expect(names(in: folders.audio).isEmpty)
    }

    @Test("An Apple Music download is refused as copy-protected")
    func appleMusic() async throws {
        let folders = try freshFolders()
        let bought = folders.picked.appending(path: "Bought.m4p")
        try Data([0, 1, 2]).write(to: bought)
        await #expect(throws: WalkUpAudioError.copyProtected(fileName: "Bought.m4p")) {
            try await SoundFileImporter.copyIn(bought, to: folders.audio)
        }
        #expect(WalkUpAudioError.copyProtected(fileName: "Bought.m4p").message.contains("Apple Music"))
    }

    @Test("A file that is not there gets a message about finding it")
    func missingFile() async throws {
        let folders = try freshFolders()
        let gone = folders.picked.appending(path: "Gone.m4a")
        do {
            _ = try await SoundFileImporter.copyIn(gone, to: folders.audio)
            Issue.record("A missing file was accepted")
        } catch {
            #expect(error.message.contains("could not be found"))
        }
    }

    @Test("One bad file among good ones is reported, and the good ones still come in")
    func mixedBatch() async throws {
        let folders = try freshFolders()
        var files = try TestSongMaker.makeTestSongs(in: folders.picked)
        let notes = folders.picked.appending(path: "notes.txt")
        try "x".write(to: notes, atomically: true, encoding: .utf8)
        files.insert(notes, at: 1)
        let player = await StadiumAudioPlayer(audioFolder: folders.audio)
        let report = await player.importSongsWithReport(from: files)
        #expect(report.songs.count == 3)
        #expect(report.problems.count == 1)
        // The plain promise hands back the good songs too, rather than failing the lot.
        let songs = try await player.importSongs(from: files)
        #expect(songs.count == 3)
    }

    @Test("A 40-second file is refused as an introduction, and its copy removed")
    func introductionTooLong() async throws {
        let folders = try freshFolders()
        let song = try #require(TestSongMaker.makeTestSongs(in: folders.picked).first)
        let player = await StadiumAudioPlayer(audioFolder: folders.audio)
        do {
            _ = try await player.importIntroduction(from: song)
            Issue.record("A 40-second introduction was accepted")
        } catch let problem as WalkUpAudioError {
            #expect(problem.message.contains("at most 30 seconds"))
        }
        #expect(names(in: folders.audio).isEmpty)
    }
}

@Suite("The song library")
@MainActor
struct LibraryTests {

    /// A player with two songs, recording every library change it reports.
    private func playerWithSongs() throws -> (StadiumAudioPlayer, [Song], Changes) {
        let folders = try freshFolders()
        let player = StadiumAudioPlayer(audioFolder: folders.audio)
        let changes = Changes()
        player.onLibraryChanged = { changes.libraries.append($0) }
        let songs = [Song(title: "Thunderstruck", fileName: "t.mp3", duration: 200),
                     Song(title: "Hells Bells", fileName: "h.mp3", duration: 300)]
        player.addSongs(songs)
        return (player, songs, changes)
    }

    /// Library changes reported for saving.
    final class Changes { var libraries: [SongLibrary] = [] }

    @Test("Every library edit is reported so it can be saved")
    func editsAreReported() throws {
        let (player, songs, changes) = try playerWithSongs()
        player.rename(songs[0].id, to: "  Thunderstruck (live)  ")
        player.setStartPoint(31, for: songs[0].id)
        player.setVolume(1.4, for: songs[1].id)
        player.setAnnouncerEcho(-2)
        #expect(changes.libraries.count == 5)   // the add and the four edits
        let saved = try #require(changes.libraries.last)
        #expect(saved.song(songs[0].id)?.title == "Thunderstruck (live)")
        #expect(saved.song(songs[0].id)?.startTime == 31)
        #expect(saved.song(songs[1].id)?.volume == 1)      // kept between 0 and 1
        #expect(saved.announcerEcho == 0)
    }

    @Test("Adding the same songs twice does not list them twice")
    func noDuplicates() throws {
        let (player, songs, _) = try playerWithSongs()
        player.addSongs(songs)
        #expect(player.library.songs.count == 2)
    }

    @Test("A blank new name is ignored")
    func blankRename() throws {
        let (player, songs, _) = try playerWithSongs()
        player.rename(songs[0].id, to: "   ")
        #expect(player.library.song(songs[0].id)?.title == "Thunderstruck")
    }

    @Test("A batter whose song is gone from the library gets a message, and nothing plays")
    func missingSong() throws {
        let (player, _, _) = try playerWithSongs()
        player.playWalkUp(for: Player(name: "Derek Jeter", walkUpSongID: "deleted"), withIntroduction: false)
        #expect(player.isPlaying == false)
        #expect(player.lastProblem == "Derek Jeter’s walk-up song is no longer in the song library. Pick a song for them again.")
        #expect(player.playback == AudioPlayback(phase: .idle))
    }

    @Test("A song in the library whose file is missing says to import it again")
    func missingFile() throws {
        let (player, songs, _) = try playerWithSongs()
        player.playWalkUp(for: Player(name: "Derek Jeter", walkUpSongID: songs[0].id), withIntroduction: false)
        #expect(player.isPlaying == false)
        #expect(player.lastProblem == "The sound file for “Thunderstruck” is missing or damaged. Import the song again.")
    }
}

@Suite("Messages to the scorer")
struct MessageTests {

    @Test("Recording problems say what to do")
    func recordingMessages() {
        #expect(RecordingProblem.askingForPermission.message
                == "Answer the iPhone’s question about the microphone, then tap record again.")
        #expect(WalkUpAudioError.microphoneNotAllowed.message.contains("Settings"))
    }
}
