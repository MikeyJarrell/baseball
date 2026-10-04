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
    /// "First base, odd innings", "Bats only".
    public static func fieldingLine(for id: PlayerID, in lineup: OurLineup) -> String {
        var parts: [String] = []
        if let position = lineup.position(of: id) {
            parts.append(positionName(position) + (lineup.alternates[position] != nil ? ", odd innings" : ""))
        }
        if let position = lineup.alternatePosition(of: id) {
            parts.append(positionName(position) + ", even innings")
        }
        return parts.isEmpty ? "Bats only" : parts.joined(separator: " · ")
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

    /// Where our lineup started: "Starting from last game’s lineup (Sat, May 2 vs Mudcats)." or
    /// the roster's usual positions before our first game.
    public static func lineupSource(_ game: GameSetup?, calendar: Calendar = .current) -> String {
        guard let game, let side = game.ourSide else {
            return "Starting from the roster: everyone at their usual position, the leadoff hitter first, and the usual bench on the bench."
        }
        let opponent = game[side.opponent].name
        let preposition = side == .home ? "vs" : "at"
        return "Starting from last game’s lineup (\(day(game.scheduledStart, calendar: calendar)) \(preposition) \(opponent))."
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
