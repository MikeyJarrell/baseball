// The app's settings: choices the scorer makes once and the app remembers.
// Saved by storage as `settings.json`. Add new settings here, each with a default, so an
// older settings file still reads.

import Foundation

/// Everything the scorer can switch on or off in the app's settings.
public struct AppSettings: Codable, Equatable, Hashable, Sendable {
    /// Fade out the walk-up song by itself when the first pitch to that batter is recorded.
    /// Off unless the scorer turns it on.
    public var fadeSongOnFirstPitch: Bool
    /// Play the announcer introduction before the walk-up song when the player has one.
    public var playIntroductions: Bool
    /// Keep the screen from locking itself while a game is open.
    public var keepScreenAwakeDuringGames: Bool

    public init(fadeSongOnFirstPitch: Bool = false, playIntroductions: Bool = true, keepScreenAwakeDuringGames: Bool = true) {
        self.fadeSongOnFirstPitch = fadeSongOnFirstPitch
        self.playIntroductions = playIntroductions
        self.keepScreenAwakeDuringGames = keepScreenAwakeDuringGames
    }

    // Reading from JSON: any setting missing from an older file takes its default.
    private enum CodingKeys: String, CodingKey { case fadeSongOnFirstPitch, playIntroductions, keepScreenAwakeDuringGames }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = AppSettings()
        fadeSongOnFirstPitch = try c.decodeIfPresent(Bool.self, forKey: .fadeSongOnFirstPitch) ?? defaults.fadeSongOnFirstPitch
        playIntroductions = try c.decodeIfPresent(Bool.self, forKey: .playIntroductions) ?? defaults.playIntroductions
        keepScreenAwakeDuringGames = try c.decodeIfPresent(Bool.self, forKey: .keepScreenAwakeDuringGames)
            ?? defaults.keepScreenAwakeDuringGames
    }
}
