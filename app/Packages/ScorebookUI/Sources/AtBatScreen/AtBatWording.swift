// The words on the batting screen: names, ordinals ("3rd"), the count ("1–1"), the time
// limit ("Limit 12:07 PM · 1:12 left"), the changeover banner and the small line under each
// count button ("makes it 2–1"). Only formatting, kept apart so the views stay readable.

import Foundation
import Model

enum AtBatWording {
    // MARK: Numbers

    /// "1st", "2nd", "3rd", "4th", "11th", "21st".
    static func ordinal(_ n: Int) -> String {
        let lastTwo = n % 100, last = n % 10
        if (11...13).contains(lastTwo) { return "\(n)th" }
        switch last {
        case 1: return "\(n)st"
        case 2: return "\(n)nd"
        case 3: return "\(n)rd"
        default: return "\(n)th"
        }
    }

    /// The count written balls first with a dash: "1–1".
    static func count(_ count: Count) -> String { "\(count.balls)–\(count.strikes)" }

    // MARK: Teams and players

    /// A team's short name for the scoreboard: the last word if it is four letters or fewer
    /// ("DOGS"), else its first three letters ("MUD" for Mudcats).
    static func shortTeamName(_ name: String) -> String {
        let last = name.split(separator: " ").last.map(String.init) ?? name
        return (last.count <= 4 ? last : String(last.prefix(3))).uppercased()
    }

    /// The batter's name as the big line beside their number: ours by name; theirs by
    /// number and name, "#23 Vega", or the number alone when we have no name.
    static func batterName(_ player: Player, ours: Bool) -> String {
        if ours { return player.displayName }
        if let number = player.number, !number.isEmpty {
            if let name = player.name, !name.isEmpty { return "#\(number) \(name)" }
            return "#\(number)"
        }
        return player.displayName
    }

    /// True when one of their hitters has no name yet, so the screen offers "Add name".
    static func needsName(_ player: Player, ours: Bool) -> Bool {
        !ours && (player.name?.isEmpty ?? true)
    }

    /// A short label for a runner's tag or the pitcher: the last name, else "#22", else
    /// the placeholder ("Batter 4").
    static func shortName(_ player: Player?) -> String {
        guard let player else { return "?" }
        if let name = player.name, !name.isEmpty { return player.lastName }
        return player.displayName
    }

    /// The on-deck hitter: ours by last name ("Tate"), theirs by number and last name
    /// ("#8 Boyd"), or the number alone.
    static func onDeckName(_ player: Player?, ours: Bool) -> String {
        guard let player else { return "—" }
        if ours { return shortName(player) }
        if let number = player.number, !number.isEmpty {
            if let name = player.name, !name.isEmpty { return "#\(number) \(player.lastName)" }
            return "#\(number)"
        }
        return player.displayName
    }

    /// The jersey number for the badge: "24", or "?" when unknown.
    static func badgeNumber(_ player: Player) -> String {
        if let number = player.number, !number.isEmpty { return number }
        return "?"
    }

    /// "Bats L", "Bats R", "Bats S", or "Bats ?" when nobody knows.
    static func bats(_ side: BattingSide?) -> String {
        switch side {
        case .left: "Bats L"
        case .right: "Bats R"
        case .switchHitter: "Bats S"
        case nil: "Bats ?"
        }
    }

    /// The same, spelled out for VoiceOver.
    static func batsSpoken(_ side: BattingSide?) -> String {
        switch side {
        case .left: "bats left"
        case .right: "bats right"
        case .switchHitter: "switch hitter"
        case nil: "batting side unknown"
        }
    }

    /// "R" or "L" for the pitcher's throwing hand, "?" when unknown.
    static func hand(_ hand: Hand?) -> String {
        switch hand {
        case .right: "R"
        case .left: "L"
        case nil: "?"
        }
    }

    /// The batter's plate appearances so far today: "6-3, BB, 1B 7", or "first time up".
    static func today(_ history: [PlateAppearanceSummary]) -> String {
        history.isEmpty ? "first time up" : history.map(\.notation).joined(separator: ", ")
    }

    // MARK: The changeover banner

    /// The banner's first line after a third out: "Middle 3rd" when the home team comes up,
    /// "End 3rd" when the visitors do. The situation is already the next half-inning.
    static func changeoverTitle(_ situation: Situation) -> String {
        situation.half == .bottom
            ? "Middle \(ordinal(situation.inning))"
            : "End \(ordinal(max(1, situation.inning - 1)))"
    }

    /// The score for banners and the game-over question, our team first:
    /// "Diamond Dogs 4, Mudcats 2". With no team of ours, the visitors first.
    static func scoreLine(_ setup: GameSetup, _ score: Score) -> String {
        let first = setup.ourSide ?? .away
        let second = first.opponent
        return "\(setup[first].name) \(score[first]), \(setup[second].name) \(score[second])"
    }

    // MARK: The time limit

    /// "12:07 PM", in the phone's time zone.
    static func clockTime(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    /// Time left as hours and minutes: "1:12 left", or "12 min left" under an hour.
    static func timeLeft(_ seconds: TimeInterval) -> String {
        let minutes = Int((seconds / 60).rounded(.up))
        if minutes < 60 { return "\(minutes) min left" }
        return "\(minutes / 60):\(String(format: "%02d", minutes % 60)) left"
    }

    /// The time-limit line under the band's title, or nothing when the game has no time limit:
    /// "Limit 12:07 PM · 1:12 left", "Limit 12:00 PM" before the first pitch, or
    /// "Past the limit (12:07 PM)".
    static func limitLine(_ clock: GameClock) -> String? {
        guard let end = clock.timeLimitEndsAt else { return nil }
        guard let left = clock.timeRemaining else { return "Limit \(clockTime(end))" }
        if left <= 0 { return "Past the limit (\(clockTime(end)))" }
        return "Limit \(clockTime(end)) · \(timeLeft(left))"
    }

    // MARK: "Is the game over?"

    /// Why the app is asking, in a sentence, with the league's rule number.
    static func gameOverReason(_ reason: EndOfGame.Reason, setup: GameSetup, clock: GameClock) -> String {
        switch reason {
        case .timeLimit:
            let limit = clock.timeLimitEndsAt.map { "The time limit, \(clockTime($0)), has passed" } ?? "The time limit has passed"
            return "\(limit) and the inning is over. No new inning starts after the limit (rule 9.1 G)."
        case .runRule:
            let margin = setup.rules.runRuleMargin ?? 12
            return "A lead of \(margin) runs or more after \(setup.rules.runRuleInning) innings ends the game under the run rule (rule 9.13)."
        case .regulation:
            return "The scheduled \(setup.scheduledInnings) innings are complete."
        case .called:
            return "Play has stopped, for rain, darkness or anything else."
        }
    }

    /// The end-game choice in the game menu for each reason.
    static func endGameChoice(_ reason: EndOfGame.Reason) -> String {
        switch reason {
        case .regulation: "End game: innings complete"
        case .timeLimit: "End game: time limit"
        case .runRule: "End game: run rule"
        case .called: "End game: rain or darkness"
        }
    }

    // MARK: The small line under each count button

    // These say what a tap will do, as in the approved mockup ("makes it 2–1", "walk",
    // "strikeout"). They are labels only: the rules engine still works out the real count.
    // The handoff asks for the rules engine to provide them, so the count rules live in one place.

    /// Under Ball: "makes it 2–1", or "walk" on ball four.
    static func ballHint(_ count: Count) -> String {
        count.balls >= 3 ? "walk" : "makes it \(count.balls + 1)–\(count.strikes)"
    }

    /// Under Strike: "makes it 1–2", or "strikeout" on strike three.
    static func strikeHint(_ count: Count) -> String {
        count.strikes >= 2 ? "strikeout" : "makes it \(count.balls)–\(count.strikes + 1)"
    }

    /// Under Foul: "makes it 1–2", or "stays 1–2" with two strikes, since a foul is never strike three.
    static func foulHint(_ count: Count) -> String {
        count.strikes >= 2 ? "stays \(count.balls)–\(count.strikes)" : "makes it \(count.balls)–\(count.strikes + 1)"
    }

    /// Under In play.
    static let inPlayHint = "out, hit, error…"
}
