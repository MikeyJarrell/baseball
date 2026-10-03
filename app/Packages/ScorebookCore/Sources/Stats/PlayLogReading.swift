// Small helpers for reading the play log the way a scorer reads a scorebook: was this a hit,
// does it count as an at-bat, did the ball actually get played on this event, which runners
// stole or were caught stealing.

import Model

extension PlateAppearanceOutcome {
    /// True for a single, double, triple or home run.
    var isHit: Bool {
        switch self {
        case .single, .double, .triple, .homeRun: true
        default: false
        }
    }

    /// True when the plate appearance counts as an at-bat. Walks, hit-by-pitches, sacrifice
    /// flies, sacrifice bunts and catcher's interference do not (rule 9.02(a)(1)). Reaching
    /// on an error or a fielder's choice does: an at-bat with no hit. So does a strikeout,
    /// even when the batter reached on a dropped third strike.
    var isAtBat: Bool {
        switch self {
        case .walk, .intentionalWalk, .hitByPitch, .sacrificeFly, .sacrificeBunt, .catchersInterference: false
        case .single, .double, .triple, .homeRun, .strikeout, .out, .reachedOnError, .fieldersChoice: true
        }
    }

    /// True for a walk, intentional or not.
    var isWalk: Bool { self == .walk || self == .intentionalWalk }
}

extension BattingCounts {
    /// Adds one finished plate appearance to a batter's line: the plate appearance itself,
    /// the at-bat if it was one, the hit and its kind, the runs batted in the scorer
    /// confirmed, and the walk, strikeout, hit-by-pitch or sacrifice.
    mutating func add(_ result: PlateAppearanceResult) {
        plateAppearances += 1
        if result.outcome.isAtBat { atBats += 1 }
        if result.outcome.isHit { hits += 1 }
        // Runs batted in come straight from the play: the number the scorer confirmed.
        // Stats never work them out again.
        runsBattedIn += result.rbi
        switch result.outcome {
        case .double: doubles += 1
        case .triple: triples += 1
        case .homeRun: homeRuns += 1
        case .walk, .intentionalWalk: walks += 1
        case .strikeout: strikeouts += 1
        case .hitByPitch: hitByPitch += 1
        case .sacrificeFly: sacrificeFlies += 1
        case .sacrificeBunt: sacrificeBunts += 1
        default: break
        }
    }
}

extension PitchingCounts {
    /// Adds one batter the pitcher is charged with: a batter faced, plus the hit, home run,
    /// walk, strikeout or hit batter it ended in.
    mutating func add(_ result: PlateAppearanceResult) {
        battersFaced += 1
        if result.outcome.isHit { hits += 1 }
        switch result.outcome {
        case .homeRun: homeRuns += 1
        case .walk, .intentionalWalk: walks += 1
        case .strikeout: strikeouts += 1
        case .hitByPitch: hitBatters += 1
        default: break
        }
    }
}

extension PlayLogEntry {
    /// True when the ball was live on the field during this event: a pitch, an intentional
    /// walk, a ball in play, runners moving between pitches, an error, or a batting hole's
    /// automatic out. Lineup changes, defense checks, manual adjustments and the end of the
    /// game are not.
    ///
    /// Only these events say who actually played in the field in which inning. That matters
    /// because the end-of-game entry can sit in an inning nobody played (after the third out
    /// of the last inning, the game has already moved on to the next half).
    var isPlayOnField: Bool {
        switch event.kind {
        case .pitch, .intentionalWalk, .ballInPlay, .runnerAction, .errorWithNoAdvance, .automaticOut:
            true
        case .substitution, .defenseConfirmed, .runnerForNonRunner, .pitchingChange, .addHitter,
             .battingHole, .timeLimitChange, .keepPlaying, .manualAdjustment, .endOfGame:
            false
        }
    }

    /// True for a lineup event that puts players on the field without a ball being played:
    /// a substitution, a defense check, a pitching change, a manual adjustment. Used only as a
    /// fallback, so a defensive replacement who came in just before the game ended still gets
    /// a fielding line.
    var isLineupMoment: Bool {
        switch event.kind {
        case .substitution, .defenseConfirmed, .pitchingChange, .manualAdjustment, .runnerForNonRunner,
             .addHitter, .battingHole:
            true
        default:
            false
        }
    }

    /// True for the end-of-game entry.
    var isEndOfGame: Bool {
        if case .endOfGame = event.kind { return true }
        return false
    }

    /// Every runner move in this event, whatever kind of event it was: runners moving between
    /// pitches, runners on a ball in play, and runners on a dropped third strike.
    var runnerMoves: [RunnerMove] {
        switch event.kind {
        case .runnerAction(let action): action.moves
        case .ballInPlay(let play): play.runners
        case .pitch(let pitch): pitch.droppedThirdStrike?.runners ?? []
        default: []
        }
    }

    /// The double or triple play the scorer marked on this event's play, if any.
    var markedMultiOut: MultiOutPlay? {
        switch event.kind {
        case .ballInPlay(let play): play.multiOut
        case .pitch(let pitch): pitch.droppedThirdStrike?.multiOut
        default: nil
        }
    }

    /// Whether the fielding team turned a double or triple play on this event: the scorer
    /// marked it, or two (three) runners were put out on the one play. A batting hole's
    /// automatic out is never part of one.
    var multiOutTurned: MultiOutPlay? {
        if case .automaticOut = event.kind { return nil }
        // A runner put out on the same pitch as the strikeout before is counted by the box
        // score builder, which can see the entry before (`strikeoutDoublePlay`).
        if markedMultiOut == .triplePlay || outs.count >= 3 { return .triplePlay }
        if markedMultiOut == .doublePlay || outs.count == 2 { return .doublePlay }
        return nil
    }
}

/// A list that keeps the order things were first added in and ignores repeats:
/// "pitchers in the order they pitched", "positions in the order they were played".
struct OrderedSet<Element: Hashable> {
    private(set) var items: [Element] = []
    private var seen: Set<Element> = []

    /// Adds an item at the end, unless it is already in the list.
    mutating func add(_ item: Element) {
        if seen.insert(item).inserted { items.append(item) }
    }

    /// True when the item is in the list.
    func contains(_ item: Element) -> Bool { seen.contains(item) }
}
