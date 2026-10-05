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

    /// The outs in words: "0 outs", "1 out", "2 outs".
    static func outs(_ outs: Int) -> String { outs == 1 ? "1 out" : "\(outs) outs" }

    /// The count written balls first with a dash: "1–1".
    static func count(_ count: Count) -> String { "\(count.balls)–\(count.strikes)" }

    // MARK: Teams and players

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

    /// The same, with only the latest few and "…" in front when some are left out:
    /// "… HR 9, K", for a long day that does not fit on one line.
    static func today(_ history: [PlateAppearanceSummary], latest: Int) -> String {
        guard history.count > latest else { return today(history) }
        return "… " + history.suffix(latest).map(\.notation).joined(separator: ", ")
    }

    // MARK: The changeover banner

    /// The banner's first line after a third out: "Middle 3rd" when the home team comes up,
    /// "End 3rd" when the visitors do. The situation is already the next half-inning.
    static func changeoverTitle(_ situation: Situation) -> String {
        situation.half == .bottom
            ? "Middle \(ordinal(situation.inning))"
            : "End \(ordinal(max(1, situation.inning - 1)))"
    }

    /// The score for banners and the game-over question, the visiting team first, as in the
    /// newspaper box score: "Mudcats 2, Diamond Dogs 4" when we are home.
    static func scoreLine(_ setup: GameSetup, _ score: Score) -> String {
        "\(setup.away.name) \(score.away), \(setup.home.name) \(score.home)"
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

    /// Why the app is asking, in a few words.
    static func gameOverReason(_ reason: EndOfGame.Reason, setup: GameSetup, clock: GameClock) -> String {
        switch reason {
        case .timeLimit:
            return clock.timeLimitEndsAt.map { "Past the time limit, \(clockTime($0))." } ?? "Past the time limit."
        case .runRule:
            let margin = setup.rules.runRuleMargin ?? 12
            return "Run rule: \(margin) or more ahead after \(setup.rules.runRuleInning) innings."
        case .regulation:
            return "\(setup.scheduledInnings) innings complete."
        case .called:
            return "Play has stopped."
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
    // "strikeout"). The words come from the rules engine (`RulesEngine.countAfter(_:in:)`), so
    // the count rules live in one place; the screen only adds "hold for bunt" under Foul.

    /// The words under one count button, from the rules engine's answer for that pitch.
    /// Under Foul with two strikes the count stays the same, and the screen adds that holding
    /// the button records a foul bunt, which is strike three: "stays 2–2 · hold for bunt".
    static func hint(_ change: CountChange, isFoul: Bool = false) -> String {
        isFoul && change.isUnchanged ? "\(change.hint) · hold for bunt" : change.hint
    }

    /// Under In play.
    static let inPlayHint = "out, hit, error…"
}
