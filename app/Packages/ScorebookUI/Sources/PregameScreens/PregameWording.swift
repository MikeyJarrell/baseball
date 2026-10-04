// The words the pregame screens show: dates and clock times, what each saved opponent's roster
// holds, when a pitcher last pitched, and where each of our hitters plays. Plain functions, so
// they can be tested with a fixed time zone.

import Foundation
import Model

/// The pregame screens' wording.
public enum PregameWording {
    /// "Sat, Oct 3".
    public static func day(_ date: Date, calendar: Calendar = .current) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .omitted, locale: calendar.locale ?? .current,
                                        calendar: calendar, timeZone: calendar.timeZone)
            .weekday(.abbreviated).month(.abbreviated).day())
    }

    /// "Oct 3", for the pitcher lines.
    public static func shortDay(_ date: Date, calendar: Calendar = .current) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .omitted, locale: calendar.locale ?? .current,
                                        calendar: calendar, timeZone: calendar.timeZone)
            .month(.abbreviated).day())
    }

    /// "9:00 AM".
    public static func clock(_ date: Date, calendar: Calendar = .current) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .omitted, locale: calendar.locale ?? .current,
                                        calendar: calendar, timeZone: calendar.timeZone)
            .hour().minute())
    }

    /// What a saved opponent's roster holds: "Saved roster: 12 players", "Saved roster: numbers
    /// only", or "No saved roster yet".
    public static func rosterSummary(_ team: Team) -> String {
        if team.roster.isEmpty { return "No saved roster yet" }
        if team.roster.contains(where: { !($0.name ?? "").isEmpty }) {
            return "Saved roster: \(team.roster.count) player\(team.roster.count == 1 ? "" : "s")"
        }
        return "Saved roster: numbers only"
    }

    /// "First base": a position's name with a capital letter, for row details.
    public static func positionName(_ position: Position) -> String {
        position.name.prefix(1).uppercased() + position.name.dropFirst()
    }

    /// Where one of our hitters plays, under their name in the batting order: "Shortstop",
    /// "First base, odd innings", or "DH" for a hitter who does not field.
    public static func fieldingLine(for id: PlayerID, in lineup: OurLineup) -> String {
        var parts: [String] = []
        if let position = lineup.position(of: id) {
            parts.append(positionName(position) + (lineup.alternates[position] != nil ? ", odd innings" : ""))
        }
        if let position = lineup.alternatePosition(of: id) {
            parts.append(positionName(position) + ", even innings")
        }
        return parts.isEmpty ? "DH" : parts.joined(separator: " · ")
    }

    /// "1st", "2nd", "3rd", "4th", "11th", "22nd".
    public static func ordinal(_ n: Int) -> String {
        let suffix: String
        switch (n % 100, n % 10) {
        case (11...13, _): suffix = "th"
        case (_, 1): suffix = "st"
        case (_, 2): suffix = "nd"
        case (_, 3): suffix = "rd"
        default: suffix = "th"
        }
        return "\(n)\(suffix)"
    }

    /// Where one of our players is now, for the fielding step's player list: "Shortstop · bats
    /// 2nd", "Pitcher · doesn’t bat", "DH · bats 10th", "First base, even innings", "Bench".
    public static func status(of id: PlayerID, in lineup: OurLineup) -> String {
        var parts: [String] = []
        if let position = lineup.position(of: id) {
            parts.append(positionName(position) + (lineup.alternates[position] != nil ? ", odd innings" : ""))
        }
        if let position = lineup.alternatePosition(of: id) {
            parts.append(positionName(position) + ", even innings")
        }
        if let spot = lineup.battingOrder.firstIndex(of: id) {
            if parts.isEmpty { parts.append("DH") }
            parts.append("bats \(ordinal(spot + 1))")
        } else if !parts.isEmpty {
            parts.append("doesn’t bat")
        }
        return parts.isEmpty ? "Bench" : parts.joined(separator: " · ")
    }

    /// When one of our pitchers last pitched: "Pitched last game, Sep 26", "Relieved Sep 19",
    /// "Hasn’t pitched this season".
    public static func ourPitcherLine(_ appearance: PitchingAppearance?, lastGame: Date?, calendar: Calendar = .current) -> String {
        guard let appearance else { return "Hasn’t pitched this season" }
        let verb = appearance.started ? "Pitched" : "Relieved"
        if let lastGame, calendar.isDate(appearance.date, inSameDayAs: lastGame) {
            return "\(verb) last game, \(shortDay(appearance.date, calendar: calendar))"
        }
        return "\(verb) \(shortDay(appearance.date, calendar: calendar))"
    }

    /// When one of their pitchers last pitched against us: "Started against us Sep 12",
    /// "Relieved against us Sep 12", "Hasn’t pitched against us".
    public static func theirPitcherLine(_ appearance: PitchingAppearance?, calendar: Calendar = .current) -> String {
        guard let appearance else { return "Hasn’t pitched against us" }
        return "\(appearance.started ? "Started" : "Relieved") against us \(shortDay(appearance.date, calendar: calendar))"
    }

    /// "throws right", "throws left", or nothing when unknown.
    public static func throwsLine(_ hand: Hand?) -> String? {
        switch hand {
        case .right: "throws right"
        case .left: "throws left"
        case nil: nil
        }
    }

    /// "R" or "L", for the review step's "Pitching: Barros (R)".
    public static func handLetter(_ hand: Hand?) -> String? {
        switch hand {
        case .right: "R"
        case .left: "L"
        case nil: nil
        }
    }

    /// A player's jersey number for a badge, or "?" when unknown.
    public static func badge(_ player: Player) -> String {
        if let number = player.number, !number.isEmpty { return number }
        return "?"
    }

    /// Their hitter on a lineup line: "#24 Marcus Hale", "#24", "Batter 3".
    public static func theirHitter(_ player: Player) -> String {
        switch (player.number.flatMap { $0.isEmpty ? nil : $0 }, player.name.flatMap { $0.isEmpty ? nil : $0 }) {
        case let (number?, name?): "#\(number) \(name)"
        case let (number?, nil): "#\(number)"
        case let (nil, name?): name
        case (nil, nil): player.displayName
        }
    }
}
