// The app's settings: choices the scorer makes once and the app remembers.
// Saved by storage as `settings.json`. Add new settings here, each with a default, so an
// older settings file still reads.

import Foundation

/// Everything the scorer can switch on or off in the app's settings.
public struct AppSettings: Codable, Equatable, Hashable, Sendable {
    /// Seconds of walk-up song before it fades out by itself, counted from when the song starts
    /// (after any announcer introduction). A tap on the song button stops it sooner.
    public var walkUpSongSeconds: TimeInterval
    /// Also fade out the walk-up song when the first pitch to that batter is recorded, if it is
    /// still playing. An extra, off unless the scorer turns it on.
    public var fadeSongOnFirstPitch: Bool
    /// Play the announcer introduction before the walk-up song when the player has one.
    public var playIntroductions: Bool
    /// Keep the screen from locking itself while a game is open.
    public var keepScreenAwakeDuringGames: Bool

    public init(
        walkUpSongSeconds: TimeInterval = 12,
        fadeSongOnFirstPitch: Bool = false,
        playIntroductions: Bool = true,
        keepScreenAwakeDuringGames: Bool = true
    ) {
        self.walkUpSongSeconds = walkUpSongSeconds
        self.fadeSongOnFirstPitch = fadeSongOnFirstPitch
        self.playIntroductions = playIntroductions
        self.keepScreenAwakeDuringGames = keepScreenAwakeDuringGames
    }

    // Reading from JSON: any setting missing from an older file takes its default.
    private enum CodingKeys: String, CodingKey { case walkUpSongSeconds, fadeSongOnFirstPitch, playIntroductions, keepScreenAwakeDuringGames }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = AppSettings()
        walkUpSongSeconds = try c.decodeIfPresent(TimeInterval.self, forKey: .walkUpSongSeconds) ?? defaults.walkUpSongSeconds
        fadeSongOnFirstPitch = try c.decodeIfPresent(Bool.self, forKey: .fadeSongOnFirstPitch) ?? defaults.fadeSongOnFirstPitch
        playIntroductions = try c.decodeIfPresent(Bool.self, forKey: .playIntroductions) ?? defaults.playIntroductions
        keepScreenAwakeDuringGames = try c.decodeIfPresent(Bool.self, forKey: .keepScreenAwakeDuringGames)
            ?? defaults.keepScreenAwakeDuringGames
    }
}
