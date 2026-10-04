// How a game file is laid out, and the trick that makes saving after every pitch fast.
//
// A game file looks like this:
//
//     {
//       "formatVersion" : 1,
//       "game" : { ...the id and setup, with an empty events list... },
//       "events" : [
//         {"enteredAt":"2026-05-02T16:00:00Z","id":"e1","pitch":{"result":"ball"}},
//         {"enteredAt":"2026-05-02T16:00:20Z","id":"e2","pitch":{"result":"foul"}}
//       ]
//     }
//
// Each event is one line. Storage keeps every line of the open game in memory, already
// turned into text, so recording a new event means turning only that one event into text
// and writing the lines out again. Nothing earlier in the game is re-encoded.

import Foundation
import Model

/// The open game's file, kept in memory as ready-to-write pieces.
struct GameFileLayout {
    /// The game exactly as saved, with every event.
    private(set) var game: Game
    /// Everything before the first event: the version tag and the game's setup.
    private let opening: Data
    /// Each event as one line of JSON, in order.
    private var eventLines: [Data]

    /// Lays out a whole game. Every event is turned into text once, here.
    init(game: Game) throws {
        self.game = game
        var header = game
        header.events = []
        let headerText = try Self.indented(ScorebookJSON.encode(header))
        var opening = Data("{\n  \"formatVersion\" : \(ScorebookJSON.formatVersion),\n  \"game\" : ".utf8)
        opening.append(headerText)
        opening.append(Data(",\n  \"events\" : [".utf8))
        self.opening = opening
        let encoder = Self.lineEncoder()
        self.eventLines = try game.events.map { try encoder.encode($0) }
    }

    /// Adds one event to the end, turning only that event into text.
    mutating func append(_ event: GameEvent) throws {
        eventLines.append(try Self.lineEncoder().encode(event))
        game.events.append(event)
    }

    /// The complete file, ready to write.
    var fileContents: Data {
        var data = opening
        // Reserve room up front so the pieces are copied in once.
        data.reserveCapacity(opening.count + eventLines.reduce(0) { $0 + $1.count + 6 } + 8)
        for (index, line) in eventLines.enumerated() {
            data.append(Data((index == 0 ? "\n    " : ",\n    ").utf8))
            data.append(line)
        }
        data.append(Data((eventLines.isEmpty ? "]\n}\n" : "\n  ]\n}\n").utf8))
        return data
    }

    /// Writes each event on one line: the same as `ScorebookJSON.encoder()` (sorted keys,
    /// dates as text) but without the line breaks and indenting.
    private static func lineEncoder() -> JSONEncoder {
        let encoder = ScorebookJSON.encoder()
        encoder.outputFormatting.remove(.prettyPrinted)
        return encoder
    }

    /// Indents every line after the first by two spaces, so the setup sits neatly inside the
    /// file. Blank lines stay blank.
    private static func indented(_ json: Data) -> Data {
        var result = Data()
        result.reserveCapacity(json.count + json.count / 8)
        let newline = UInt8(ascii: "\n"), space = UInt8(ascii: " ")
        var startOfLine = false
        for byte in json {
            if startOfLine && byte != newline { result.append(contentsOf: [space, space]) }
            result.append(byte)
            startOfLine = byte == newline
        }
        return result
    }
}
