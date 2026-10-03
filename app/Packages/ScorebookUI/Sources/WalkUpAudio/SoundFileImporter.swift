// Copying sound files into the app: songs picked in the Files app, and announcer
// introductions recorded somewhere else.
//
// This all runs in the background, away from the screen, because a long song or an iCloud
// Drive file that still has to download can take a while. The steps for each file:
//
// 1. Check it is a kind of sound file the iPhone can play (MP3, M4A, WAV, AAC and a few
//    others).
// 2. Open the temporary permission the file picker gave the app to read that one file
//    (Apple calls it “security-scoped access”), and close it again when done.
// 3. Ask iCloud Drive to download the file if it is only a placeholder on the phone.
// 4. Read it through Apple's “file coordination,” the polite way to read a file another
//    app or iCloud might be writing at the same moment. It also waits for the download.
// 5. Copy it into the app's own audio folder under a name not already taken.
// 6. Open the copy to make sure it really plays, and refuse copy-protected songs bought or
//    streamed through Apple Music, which no app can play from a file.

import AVFoundation
import Foundation
import Model

/// What `importSongsWithReport` hands back: the songs that came in, and a plain message for
/// each file that did not.
public struct SongImportReport: Sendable, Equatable {
    /// One new song for each file copied in, named after its file. Not yet in the library.
    public var songs: [Song]
    /// One problem for each file that could not be copied.
    public var problems: [WalkUpAudioError]

    public init(songs: [Song] = [], problems: [WalkUpAudioError] = []) {
        self.songs = songs
        self.problems = problems
    }
}

/// The steps above, for one file at a time. Has no state, so it is safe on any thread.
enum SoundFileImporter {
    /// The kinds of file the app accepts, by the ending of the file name.
    static let playableExtensions: Set<String> = ["mp3", "m4a", "wav", "aac", "aif", "aiff", "caf", "m4b"]

    /// Copies one file into `folder` and returns the copy's name and length in seconds.
    /// `prefix` starts the new name, such as “intro-” for announcer introductions.
    static func copyIn(_ source: URL, to folder: URL, prefix: String = "") async throws(WalkUpAudioError)
        -> (fileName: String, duration: TimeInterval) {
        let originalName = source.lastPathComponent
        let ending = source.pathExtension.lowercased()

        // Apple Music downloads end in .m4p and are always copy-protected.
        if ending == "m4p" { throw .copyProtected(fileName: originalName) }
        guard playableExtensions.contains(ending) else {
            throw .cannotImport(
                fileName: originalName,
                reason: "It is not a sound file the app can play. Use an MP3, M4A, WAV or AAC file."
            )
        }

        // Step 2: open the file picker's temporary permission, and close it however we leave.
        let opened = source.startAccessingSecurityScopedResource()
        defer { if opened { source.stopAccessingSecurityScopedResource() } }

        // Step 3: if the file lives in iCloud Drive and is not on the phone yet, start the
        // download. Coordination below waits for it to finish.
        if (try? source.resourceValues(forKeys: [.isUbiquitousItemKey]).isUbiquitousItem) == true {
            try? FileManager.default.startDownloadingUbiquitousItem(at: source)
        }

        // Steps 4 and 5: read the file politely and copy it in.
        let copy: URL
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            copy = try coordinatedCopy(of: source, into: folder, prefix: prefix)
        } catch {
            throw .cannotImport(fileName: originalName, reason: plainReason(for: error))
        }

        // Step 6: make sure the copy plays. If not, remove it and say why.
        do {
            let duration = try await checkPlayable(copy, originalName: originalName)
            return (copy.lastPathComponent, duration)
        } catch {
            try? FileManager.default.removeItem(at: copy)
            throw error
        }
    }

    /// Copies the file while holding the system's read lock on it, under a free name.
    private static func coordinatedCopy(of source: URL, into folder: URL, prefix: String) throws -> URL {
        var coordinationError: NSError?
        var copyError: Error?
        var result: URL?
        NSFileCoordinator().coordinate(readingItemAt: source, options: .withoutChanges,
                                       error: &coordinationError) { readableURL in
            do {
                result = try copyUnderFreeName(readableURL, into: folder, prefix: prefix,
                                               originalName: source.lastPathComponent)
            } catch {
                copyError = error
            }
        }
        if let coordinationError { throw coordinationError }
        if let copyError { throw copyError }
        guard let result else { throw CocoaError(.fileReadUnknown) }
        return result
    }

    /// Copies `file` into `folder`, adding “ 2”, “ 3”… to the name if it is taken, so a
    /// second song called “Intro.mp3” never overwrites the first.
    private static func copyUnderFreeName(_ file: URL, into folder: URL, prefix: String,
                                          originalName: String) throws -> URL {
        let base = prefix + (originalName as NSString).deletingPathExtension
        let ending = (originalName as NSString).pathExtension
        for attempt in 1...500 {
            let name = attempt == 1 ? base : "\(base) \(attempt)"
            let target = folder.appending(path: ending.isEmpty ? name : "\(name).\(ending)")
            if FileManager.default.fileExists(atPath: target.path) { continue }
            do {
                try FileManager.default.copyItem(at: file, to: target)
                return target
            } catch CocoaError.fileWriteFileExists {
                continue   // another import took this name a moment ago; try the next
            }
        }
        throw CocoaError(.fileWriteFileExists)
    }

    /// Opens the copied file as sound. Returns its length in seconds, or throws a clear
    /// problem: copy-protected, or not playable at all.
    private static func checkPlayable(_ file: URL, originalName: String) async throws(WalkUpAudioError) -> TimeInterval {
        let asset = AVURLAsset(url: file)
        if (try? await asset.load(.hasProtectedContent)) == true {
            throw .copyProtected(fileName: originalName)
        }
        do {
            let audio = try AVAudioFile(forReading: file)
            let seconds = Double(audio.length) / audio.processingFormat.sampleRate
            guard seconds > 0 else {
                throw WalkUpAudioError.cannotImport(fileName: originalName, reason: "The file has no sound in it.")
            }
            return seconds
        } catch let problem as WalkUpAudioError {
            throw problem
        } catch {
            throw .cannotImport(
                fileName: originalName,
                reason: "The iPhone cannot play it. It may be damaged, or not really a sound file."
            )
        }
    }

    /// Turns a file-system error into words the scorer can act on.
    static func plainReason(for error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain {
            switch nsError.code {
            case CocoaError.fileReadNoPermission.rawValue:
                return "The app was not allowed to read it. Pick it again in the Files app."
            case CocoaError.fileReadNoSuchFile.rawValue, CocoaError.fileNoSuchFile.rawValue:
                return "The file could not be found. If it is in iCloud Drive, check the phone is online so it can download."
            case CocoaError.fileWriteOutOfSpace.rawValue:
                return "The iPhone is out of storage space."
            case CocoaError.ubiquitousFileUnavailable.rawValue, CocoaError.ubiquitousFileNotUploadedDueToQuota.rawValue:
                return "iCloud Drive could not download it. Check the phone is online and try again."
            default:
                break
            }
        }
        return nsError.localizedDescription
    }
}

extension WalkUpAudioError {
    /// A sentence to show the scorer, such as
    /// ““Thunderstruck.mp3” could not be copied in. The iPhone is out of storage space.”
    public var message: String {
        switch self {
        case .cannotImport(let fileName, let reason):
            return "“\(fileName)” could not be copied in. \(reason)"
        case .copyProtected(let fileName):
            return "“\(fileName)” is copy-protected. Songs bought or streamed through Apple Music cannot be used; import an MP3 or M4A file instead."
        case .microphoneNotAllowed:
            return "The app is not allowed to use the microphone. Turn it on in the Settings app, under Scorebook."
        }
    }
}
