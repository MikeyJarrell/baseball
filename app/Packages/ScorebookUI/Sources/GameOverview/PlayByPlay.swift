// PlayByPlay: turns the play log into the rows of the play-by-play list.
//
// Every event becomes one row, grouped by half-inning, newest half-inning first and newest
// event first inside it, as in the approved mockup. Pitches in the middle of a plate
// appearance can be hidden, since a game has hundreds of them; the pitch that ends a plate
// appearance (ball four, strike three) always shows, as that plate appearance's row.
//
// The only arithmetic here is adding up the runs the play log lists, to show the score after
// each scoring play. Which runs scored, and for which team, is the rules engine's answer.

import Foundation
import Model

/// One row of the play-by-play: one event.
public struct PlayRow: Identifiable, Equatable, Sendable {
    /// The event's id, so the scorer's fix goes to the right event.
    public var id: EventID { event.id }
    /// The event itself, handed back when the scorer fixes it.
    public var event: GameEvent
    /// Where the event sits in the play log, counting from 0.
    public var index: Int
    /// The inning and half it happened in.
    public var inning: Int
    public var half: HalfInning
    /// Scorebook notation for the chip ("6-3", "1B 7", "B"), or empty for none.
    public var notation: String
    /// True for a hit, drawn in green.
    public var isHit: Bool
    /// The event in words: "Diaz doubled to left".
    public var text: String
    /// The small line under it, in pieces: "Moreno scored", "Diamond Dogs 1, Mudcats 0", "1 out".
    public var details: [String]
    /// What looks wrong, when the rules engine flagged this event after an earlier edit.
    public var reviewNote: String?
    /// True for a pitch in the middle of a plate appearance or a fielder check with no
    /// changes: drawn smaller, and pitches can be hidden.
    public var isMinor: Bool
    /// True for a pitch in the middle of a plate appearance, which the "Show every pitch"
    /// switch hides.
    public var isHideablePitch: Bool
    /// The batter at the plate during the event ("Webb"), when there was one.
    public var batter: String?
    /// The count just before the event and just after it.
    public var countBefore: Count
    public var countAfter: Count
    /// For a pitch or a ball in play: the pitches already thrown to this batter in this plate
    /// appearance, oldest first ("Ball", "Called strike"), so the fix sheet can show them.
    public var earlierPitches: [String]
    /// What "Delete it" will do, in plain words.
    public var deleteEffect: String
    /// True when the event is a pitch, so the fix sheet shows the batter and the count.
    public var isPitch: Bool
    /// True when the event ended a plate appearance (ball four, strike three, a ball in play).
    public var endedPlateAppearance: Bool
}

/// One half-inning of the play-by-play.
public struct PlaySection: Identifiable, Equatable, Sendable {
    /// Unique even when a manual adjustment sends the game back to a half-inning already listed.
    public var id: String
    public var inning: Int
    public var half: HalfInning
    /// Newest first.
    public var rows: [PlayRow]

    /// The heading: "▼ 3rd".
    public var heading: String { OverviewWording.halfInningHeading(half, inning) }
    /// The same heading for VoiceOver: "Bottom 3rd".
    public var spokenHeading: String { OverviewWording.halfInning(half, inning) }
}

/// The batter at the plate right now, with the pitches so far: the highlighted "At bat" row.
public struct CurrentAtBat: Equatable, Sendable {
    public var batter: String
    /// The pitches so far, in words: ["Ball", "Called strike"].
    public var pitches: [String]
    public var count: Count

    /// The small line: "Ball, called strike · count 1–1", or "No pitches yet".
    public var summary: String {
        if pitches.isEmpty { return "No pitches yet" }
        let words = pitches.enumerated().map { i, p in i == 0 ? p : p.lowercased() }.joined(separator: ", ")
        return "\(words) · count \(OverviewWording.count(count))"
    }
}

/// Builds the play-by-play from the play log.
public enum PlayByPlay {
    /// Every event as a row, without grouping, oldest first.
    public static func rows(for log: PlayLog) -> [PlayRow] {
        let setup = log.setup
        var score = Score()
        var rows: [PlayRow] = []
        rows.reserveCapacity(log.entries.count)
        // The pitches thrown so far in the plate appearance going on, and to whom.
        var pitchesSoFar: [String] = []
        var pitchesBatter: PlayerID?
        var pitchesHalf: (Int, HalfInning)?

        for (index, entry) in log.entries.enumerated() {
            // A new batter, or a new half-inning, starts a new list of pitches.
            if entry.batter != pitchesBatter || pitchesHalf.map({ $0 != (entry.inning, entry.half) }) ?? true {
                pitchesSoFar = []
                pitchesBatter = entry.batter
                pitchesHalf = (entry.inning, entry.half)
            }
            let earlier = pitchesSoFar
            // Keep the running score: each run counts for the team at bat, and a manual
            // adjustment adds (or takes away) the runs the rules engine says it did.
            let side = entry.battingSide
            score[side] += entry.runs.count
            if let adjusted = entry.adjustedRuns {
                score.away += adjusted.away
                score.home += adjusted.home
            }

            var details: [String] = []
            for run in entry.runs {
                let runner = OverviewWording.name(run.runner, in: setup)
                if run.creditedTo != run.runner {
                    details.append("\(runner) scored for \(OverviewWording.name(run.creditedTo, in: setup))")
                } else {
                    details.append("\(runner) scored")
                }
            }
            if !entry.runs.isEmpty || entry.adjustedRuns != nil {
                details.append(OverviewWording.score(score, setup: setup))
            }
            if !entry.outs.isEmpty || entry.endsHalfInning {
                details.append(OverviewWording.outs(entry.after.outs))
            }

            let isPitch: Bool
            var isDroppedThirdStrike = false
            if case .pitch(let pitch) = entry.event.kind {
                isPitch = true
                isDroppedThirdStrike = pitch.droppedThirdStrike != nil
            } else {
                isPitch = false
            }
            // A pitch that changed nothing but the count: ball one, strike two, a foul.
            let quietPitch = isPitch && entry.plateAppearance == nil && entry.outs.isEmpty
                && entry.runs.isEmpty && !isDroppedThirdStrike && !entry.needsReview
            if quietPitch {
                details.append("count \(OverviewWording.count(entry.after.count))")
            }
            var isCheck = false
            if case .defenseConfirmed = entry.event.kind { isCheck = true }

            let outcome = entry.plateAppearance?.outcome
            rows.append(PlayRow(
                event: entry.event,
                index: index,
                inning: entry.inning,
                half: entry.half,
                notation: entry.notation,
                isHit: outcome.map(OverviewWording.isHit) ?? OverviewWording.isHitNotation(entry.notation),
                text: OverviewWording.describe(entry, setup: setup),
                details: details,
                reviewNote: entry.needsReview
                    ? (entry.reviewNote ?? "This no longer fits the plays before it.")
                    : nil,
                isMinor: quietPitch || isCheck,
                isHideablePitch: quietPitch,
                batter: entry.batter.map { OverviewWording.name($0, in: setup) },
                countBefore: entry.before.count,
                countAfter: entry.after.count,
                earlierPitches: (isPitch || isBallInPlay(entry)) ? earlier : [],
                deleteEffect: OverviewWording.deleteEffect(entry, setup: setup),
                isPitch: isPitch,
                endedPlateAppearance: entry.plateAppearance != nil
            ))

            // Keep the list of pitches for the next event: a pitch that did not end the plate
            // appearance joins it; anything that ended the plate appearance starts it again.
            if entry.plateAppearance != nil {
                pitchesSoFar = []
            } else if case .pitch(let pitch) = entry.event.kind {
                pitchesSoFar.append(OverviewWording.capitalized(pitch.result.label))
            }
        }
        return rows
    }

    /// True for a ball in play.
    private static func isBallInPlay(_ entry: PlayLogEntry) -> Bool {
        if case .ballInPlay = entry.event.kind { return true }
        return false
    }

    /// The rows grouped by half-inning, newest half-inning first and newest event first in
    /// each. With `showPitches` off, pitches in the middle of a plate appearance are left out.
    public static func sections(for log: PlayLog, showPitches: Bool) -> [PlaySection] {
        sections(from: rows(for: log), showPitches: showPitches)
    }

    /// The same, from rows already built, so switching pitches on and off does not rebuild them.
    public static func sections(from rows: [PlayRow], showPitches: Bool) -> [PlaySection] {
        var oldestFirst: [PlaySection] = []
        for row in rows {
            if !showPitches && row.isHideablePitch { continue }
            // The end-of-game event can land in the half-inning after the last one played
            // (the sides switch before the scorer ends the game), so it joins the last one.
            var isEnd = false
            if case .endOfGame = row.event.kind { isEnd = true }
            if let last = oldestFirst.last,
               isEnd || (last.inning == row.inning && last.half == row.half) {
                oldestFirst[oldestFirst.count - 1].rows.append(row)
            } else {
                oldestFirst.append(PlaySection(id: "\(row.inning)-\(row.half.rawValue)-\(oldestFirst.count)",
                                               inning: row.inning, half: row.half, rows: [row]))
            }
        }
        return oldestFirst.reversed().map { section in
            var s = section
            s.rows.reverse()
            return s
        }
    }

    /// The batter at the plate now and the pitches they have seen, for the highlighted
    /// "At bat" row. Missing when the game is over or the teams are changing sides.
    public static func currentAtBat(log: PlayLog, situation: Situation?) -> CurrentAtBat? {
        guard let situation, !situation.isFinal, !situation.isBetweenHalfInnings,
              let batter = situation.batter else { return nil }
        // Walk back from the newest event while the events are this batter's pitches.
        var pitches: [String] = []
        for entry in log.entries.reversed() {
            guard entry.inning == situation.inning, entry.half == situation.half,
                  entry.batter == batter, entry.plateAppearance == nil else { break }
            if case .pitch(let pitch) = entry.event.kind {
                pitches.append(OverviewWording.capitalized(pitch.result.label))
            }
        }
        return CurrentAtBat(batter: OverviewWording.name(batter, in: log.setup),
                            pitches: pitches.reversed(), count: situation.count)
    }
}
