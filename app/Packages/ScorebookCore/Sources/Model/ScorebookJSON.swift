// The one agreed way to turn the vocabulary into JSON text and back.
//
// Storage, the scenario files and the tests all use these, so a file written by one
// part of the app reads back in every other part. Dates are written as readable text
// ("2026-05-02T18:31:07Z"), and keys are sorted so saved files change predictably.

import Foundation

public enum ScorebookJSON {
    /// The version of the saved-file format. Storage writes it into every file, so a later
    /// version of the app can tell an old file from a new one and read both.
    public static let formatVersion = 1

    /// Writes JSON: indented, keys in alphabetical order, dates as text.
    public static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    /// Reads JSON written by `encoder()`, or by hand in the same format.
    public static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// Turns any vocabulary value into JSON bytes.
    public static func encode<T: Encodable>(_ value: T) throws -> Data {
        try encoder().encode(value)
    }

    /// Reads any vocabulary value from JSON bytes.
    public static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try decoder().decode(type, from: data)
    }
}
