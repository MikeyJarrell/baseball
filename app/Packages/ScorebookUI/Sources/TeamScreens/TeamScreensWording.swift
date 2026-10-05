// The words and sums the teams and songs screens show, and the edits they make to a team, as
// plain functions with no screen, so they can be tested on their own: the announcer's script
// ("Now batting, number twenty-two, Jordan Webb."), a team's summary line,
// who uses a song, times like "0:42.0", reading "22 Jordan Webb" typed in quick entry, and
// assigning songs and introductions.

import Foundation
import Model

/// The words on the teams and songs screens.
public enum TeamWording {
    // MARK: The stadium announcer

    /// The announcer's script for a player, the way the phone's voice reads it:
    /// “Now batting, number twenty-two, Jordan Webb.” A player with only a name gets
    /// “Now batting, Jordan Webb.”, and only a number “Now batting, number twenty-two.”
    public static func announcerScript(for player: Player) -> String {
        let name = player.name?.trimmingCharacters(in: .whitespaces).nilIfEmpty
        let number = player.number?.trimmingCharacters(in: .whitespaces).nilIfEmpty.map(spokenNumber)
        switch (number, name) {
        case let (number?, name?): return "Now batting, number \(number), \(name)."
        case let (nil, name?): return "Now batting, \(name)."
        case let (number?, nil): return "Now batting, number \(number)."
        case (nil, nil): return "Now batting."
        }
    }

    /// A jersey number in words, the way the announcer says it: "22" is "twenty-two", "00"
    /// "double zero", "07" "oh seven". Anything that is not a one- or two-digit number is read
    /// as written.
    public static func spokenNumber(_ number: String) -> String {
        let ones = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine",
                    "ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen",
                    "seventeen", "eighteen", "nineteen"]
        let tens = ["", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety"]
        guard (1...2).contains(number.count), number.allSatisfy(\.isASCII), let value = Int(number) else {
            return number
        }
        if number == "00" { return "double zero" }
        if number.count == 2, number.first == "0" { return "oh \(ones[value])" }
        if value < 20 { return ones[value] }
        let unit = value % 10
        return tens[value / 10] + (unit == 0 ? "" : "-\(ones[unit])")
    }

    /// The line under the script saying where the introduction comes from.
    public static func introductionStatus(_ introduction: AnnouncerIntroduction?, echo: Double) -> String {
        let echoWords = echo > 0 ? "stadium echo on" : "no stadium echo"
        switch introduction?.source {
        case .recorded: return "Recorded in your voice · \(echoWords)"
        case .imported: return "Imported recording · \(echoWords)"
        case .phoneVoice: return "iPhone voice"
        case .pieced: return "Your voice, pieced together with their number · \(echoWords)"
        case nil: return "No introduction yet"
        }
    }

    /// The short version for a roster row: "intro recorded", "iPhone voice intro", "no intro".
    public static func introductionShort(_ introduction: AnnouncerIntroduction?) -> String {
        switch introduction?.source {
        case .recorded: "intro recorded"
        case .imported: "intro imported"
        case .phoneVoice: "iPhone voice intro"
        case .pieced: "intro recorded"
        case nil: "no intro"
        }
    }

    // MARK: Teams and players

    /// "1 player", "12 players".
    public static func playerCount(_ count: Int) -> String {
        count == 1 ? "1 player" : "\(count) players"
    }

    /// The line under our team's name: "12 players · 10 with songs".
    public static func ourTeamSummary(_ team: Team) -> String {
        guard !team.roster.isEmpty else { return "No players yet" }
        let withSongs = team.roster.filter { $0.walkUpSongID != nil }.count
        return "\(playerCount(team.roster.count)) · \(withSongs) with songs"
    }

    /// The line under an opponent's name: "12 players, names and numbers", "11 players,
    /// numbers only", "10 players, some unnamed", "10 players, not named yet".
    public static func opponentSummary(_ team: Team) -> String {
        let roster = team.roster
        guard !roster.isEmpty else { return "No players yet" }
        let named = roster.filter { $0.name?.nilIfEmpty != nil }.count
        let numbered = roster.filter { $0.number?.nilIfEmpty != nil }.count
        let kind: String
        if named == roster.count {
            kind = numbered == roster.count ? "names and numbers" : "names"
        } else if named == 0 && numbered == roster.count {
            kind = "numbers only"
        } else if named == 0 && numbered == 0 {
            kind = "not named yet"
        } else {
            kind = "some unnamed"
        }
        return "\(playerCount(roster.count)), \(kind)"
    }

    /// What a player usually does, for the roster and their page: "Center field",
    /// "Shortstop, leads off", "DH, starts on the bench". Empty when nothing is set.
    public static func usualText(_ usuals: PlayerUsuals) -> String {
        guard !usuals.isEmpty else { return "" }
        var parts = [usuals.position.map { $0.name.capitalizedFirst } ?? "DH"]
        if usuals.leadsOff { parts.append("leads off") }
        if usuals.startsOnBench { parts.append("starts on the bench") }
        return parts.joined(separator: ", ")
    }

    /// "Bats L · Throws R", leaving out whatever is unknown. Empty when both are.
    public static func handedness(_ player: Player) -> String {
        var parts: [String] = []
        if let bats = player.bats { parts.append("Bats \(letter(bats))") }
        if let hand = player.throwsWith { parts.append("Throws \(hand == .left ? "L" : "R")") }
        return parts.joined(separator: " · ")
    }

    /// "R", "L" or "S" for a batting side.
    public static func letter(_ side: BattingSide) -> String {
        switch side {
        case .right: "R"
        case .left: "L"
        case .switchHitter: "S"
        }
    }

    /// The whole line under a player's name on their page: "Shortstop · Bats R · Throws R".
    public static func playerLine(_ player: Player, usuals: PlayerUsuals) -> String {
        [usualText(usuals), handedness(player)].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    /// The other player on the team already wearing this number, if any, so quick entry and the
    /// edit sheet can mention it (it never stops the scorer).
    public static func playerWearing(_ number: String?, in team: Team, except id: PlayerID? = nil) -> Player? {
        guard let number = number?.trimmingCharacters(in: .whitespaces).nilIfEmpty else { return nil }
        return team.roster.first { $0.id != id && $0.number == number }
    }

    /// The mark beside a player whose number someone else on the team also wears, "Same number
    /// as Jordan Webb", or nil when nobody does. Two players may share a number; the mark only
    /// makes sure the scorer sees it.
    public static func sharedNumberNote(for player: Player, in team: Team) -> String? {
        playerWearing(player.number, in: team, except: player.id).map { "Same number as \($0.displayName)" }
    }

    // MARK: Songs

    /// The players on a team who use a song, as a walk-up song and as a warm-up song (main or extra).
    public static func users(of song: SongID, in team: Team?) -> (walkUp: [Player], warmUp: [Player]) {
        let roster = team?.roster ?? []
        return (roster.filter { $0.walkUpSongID == song },
                roster.filter { $0.warmUpSongID == song || $0.extraWarmUpSongIDs.contains(song) })
    }

    /// Who uses a song, for the library: "walk-up: Moreno, Tate · warm-up: Barros", or
    /// "unassigned".
    public static func usageText(of song: SongID, in team: Team?) -> String {
        let (walkUp, warmUp) = users(of: song, in: team)
        var parts: [String] = []
        if !walkUp.isEmpty { parts.append("walk-up: " + walkUp.map(\.lastName).joined(separator: ", ")) }
        if !warmUp.isEmpty { parts.append("warm-up: " + warmUp.map(\.lastName).joined(separator: ", ")) }
        return parts.isEmpty ? "unassigned" : parts.joined(separator: " · ")
    }

    /// The details under a song's title on a player's page: "starts at 0:42 · volume 90%".
    public static func songDetails(_ song: Song) -> String {
        "starts at \(clock(song.startTime)) · volume \(percent(song.volume))"
    }

    /// A loudness as a percentage: 0.9 is "90%".
    public static func percent(_ volume: Double) -> String {
        "\(Int((volume * 100).rounded()))%"
    }

    /// Minutes and whole seconds: 42 seconds is "0:42", 232 is "3:52".
    public static func clock(_ seconds: TimeInterval) -> String {
        let whole = Int(max(0, seconds).rounded(.down))
        return "\(whole / 60):" + String(format: "%02d", whole % 60)
    }

    /// Minutes, seconds and tenths, for the start point: 42.3 seconds is "0:42.3".
    public static func clockTenths(_ seconds: TimeInterval) -> String {
        let tenths = Int((max(0, seconds) * 10).rounded())
        return "\(tenths / 600):" + String(format: "%02d", (tenths / 10) % 60) + ".\(tenths % 10)"
    }

    /// How long the start-point timeline is: the whole track if its length is known, otherwise
    /// a guess long enough to show the start point with room after it.
    public static func timelineLength(of song: Song) -> TimeInterval {
        if let duration = song.duration, duration > 0 { return duration }
        return max(song.startTime + 60, 180)
    }

    /// A start point kept on the track: never before the beginning, and at least a second
    /// before the end (the audio player keeps the same margin). Rounded to a tenth of a second.
    public static func clampedStart(_ seconds: TimeInterval, in song: Song) -> TimeInterval {
        let latest = max(0, timelineLength(of: song) - 1)
        return (min(max(0, seconds), latest) * 10).rounded() / 10
    }

    /// How far, in points, a finger must move on the drawing of a track before a drag counts.
    public static let scrubThreshold: CGFloat = 10

    /// True when a drag on the drawing of a track has gone clearly sideways, so it moves the start
    /// point. A drag mostly up or down is the scorer scrolling the page, and moves nothing.
    public static func isSidewaysDrag(width: CGFloat, height: CGFloat) -> Bool {
        abs(width) >= scrubThreshold && abs(width) > abs(height) * 1.5
    }

    /// Bar heights from 0.15 to 1 for the drawing of a song on its page. The app does not read
    /// the sound file, so the shape is made up, but always the same for the same song.
    public static func waveformHeights(seed: String, count: Int) -> [Double] {
        var state = seed.unicodeScalars.reduce(7) { ($0 * 31 + Int($1.value)) % 233_280 }
        return (0..<count).map { i in
            state = (state * 9301 + 49297) % 233_280
            let random = Double(state) / 233_280
            let swell = 0.55 + 0.45 * sin(Double(i) / 7)
            return min(1, 0.15 + random * 0.85 * swell)
        }
    }
}

// MARK: - Quick entry

/// One line typed in quick entry, read into a number and a name: "22 Jordan Webb",
/// "#22 Jordan Webb", "22" (number only) or "Jordan Webb" (name only).
public struct QuickEntryLine: Equatable, Sendable {
    public var number: String?
    public var name: String?

    /// Reads a typed line. A first word of one to three digits (with or without "#") is the
    /// number; everything after it is the name.
    public init(_ text: String) {
        var words = text.split(whereSeparator: \.isWhitespace).map(String.init)
        if let first = words.first {
            let digits = first.hasPrefix("#") ? String(first.dropFirst()) : first
            if (1...3).contains(digits.count), digits.allSatisfy({ $0.isASCII && $0.isNumber }) {
                number = digits
                words.removeFirst()
            }
        }
        name = words.joined(separator: " ").nilIfEmpty
    }

    /// True when the line holds nothing to add.
    public var isEmpty: Bool { number == nil && name == nil }

    /// What will be added, for the line under the typing field: "Number 22 · Jordan Webb".
    public var preview: String {
        [number.map { "Number \($0)" }, name].compactMap { $0 }.joined(separator: " · ")
    }

    /// The new player, with the batting side and throwing hand chosen beside the field.
    public func player(bats: BattingSide?, throwsWith: Hand?) -> Player {
        Player(name: name, number: number, bats: bats, throwsWith: throwsWith)
    }
}

// MARK: - Team edits

extension Team {
    /// The team with this player changed, or added at the end if they are new.
    func saving(_ player: Player) -> Team {
        var team = self
        if let i = team.roster.firstIndex(where: { $0.id == player.id }) {
            team.roster[i] = player
        } else {
            team.roster.append(player)
        }
        return team
    }

    /// The team without this player.
    func removing(_ player: PlayerID) -> Team {
        var team = self
        team.roster.removeAll { $0.id == player }
        return team
    }

    /// The team with a player's walk-up or warm-up song set (or cleared with `nil`).
    func assigning(_ song: SongID?, as slot: SongSlot, to player: PlayerID) -> Team {
        var team = self
        guard let i = team.roster.firstIndex(where: { $0.id == player }) else { return team }
        switch slot {
        case .walkUp: team.roster[i].walkUpSongID = song
        case .warmUp: team.roster[i].warmUpSongID = song
        }
        return team
    }

    /// The team with a player's introduction replaced (or removed with `nil`), plus the old
    /// introduction when its sound file is no longer used and should be deleted.
    func settingIntroduction(
        _ introduction: AnnouncerIntroduction?,
        for player: PlayerID
    ) -> (team: Team, unusedFile: AnnouncerIntroduction?) {
        var team = self
        guard let i = team.roster.firstIndex(where: { $0.id == player }) else { return (team, nil) }
        let old = team.roster[i].introduction
        team.roster[i].introduction = introduction
        let unused = (old?.fileName != nil && old?.fileName != introduction?.fileName) ? old : nil
        return (team, unused)
    }
}

// MARK: - Small helpers

extension String {
    /// Nil for an empty string, so "no name" and "" mean the same.
    var nilIfEmpty: String? { isEmpty ? nil : self }

    /// The first letter in capitals: "center field" becomes "Center field".
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
