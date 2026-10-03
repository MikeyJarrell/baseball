// Writing a file so that a crash can never leave it half-written.
//
// The new contents go into a hidden temporary file beside the real one. Once every byte is
// on disk, the temporary file is renamed over the real one in a single step. Renaming is
// all-or-nothing: if the phone dies before it, the old file is still whole; if it dies
// after it, the new file is whole. Either way the game reads back.

import Foundation

enum SafeFileWriter {
    /// Temporary files end with this, so they are never mistaken for saved files and can be
    /// cleared away the next time the app starts.
    static let temporarySuffix = ".partial"

    /// Writes `data` to `file`, replacing whatever was there, without ever leaving a
    /// half-written file behind.
    static func write(_ data: Data, to file: URL) throws {
        let folder = file.deletingLastPathComponent()
        // A hidden name (starting with a dot) with a random part, so two writes never share one.
        let temporary = folder.appendingPathComponent(
            ".\(file.lastPathComponent).\(UUID().uuidString)\(temporarySuffix)")

        // 1. Write every byte into the temporary file.
        guard FileManager.default.createFile(atPath: temporary.path, contents: nil) else {
            throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: temporary.path])
        }
        do {
            let handle = try FileHandle(forWritingTo: temporary)
            defer { try? handle.close() }
            try handle.write(contentsOf: data)
            // 2. Ask the system to push the bytes out of memory and onto the disk itself.
            try handle.synchronize()
        } catch {
            try? FileManager.default.removeItem(at: temporary)
            throw error
        }

        // 3. Swap the finished file in under the real name, in one step.
        if rename(temporary.path, file.path) != 0 {
            let code = errno
            try? FileManager.default.removeItem(at: temporary)
            throw POSIXError(POSIXErrorCode(rawValue: code) ?? .EIO)
        }
    }

    /// True for a leftover temporary file from a write that never finished.
    static func isLeftover(_ name: String) -> Bool {
        name.hasPrefix(".") && name.hasSuffix(temporarySuffix)
    }

    /// Deletes leftover temporary files in a folder. The real files beside them are whole,
    /// because a temporary file is only ever renamed over a real one once it is complete.
    static func clearLeftovers(in folder: URL) {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        for name in names where isLeftover(name) {
            try? FileManager.default.removeItem(at: folder.appendingPathComponent(name))
        }
    }
}
