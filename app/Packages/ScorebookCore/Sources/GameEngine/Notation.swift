// Notation: turns events into scorebook shorthand, the way a scorer writes in the little
// box for each plate appearance: "6-3", "F8", "1B 7", "K", "ꓘ", "BB", "SB2", "CS2 2-6".
//
// Nothing here changes the game. It only reads an event (and, for pitches, the count just
// before it) and writes the matching text.

import Foundation
import Model

/// Scorebook shorthand for events and plays.
enum Notation {
    /// The notation for one event, given the situation just before it. `name` turns a player
    /// id into the name to print for lineup changes ("PH Moss for Collins").
    static func event(_ event: GameEvent, before s: Situation, name: (PlayerID) -> String) -> String {
        switch event.kind {
        case .pitch(let pitch):
            return self.pitch(pitch, count: s.count)
        case .intentionalWalk:
            return "IBB"
        case .ballInPlay(let play):
            return self.play(play)
        case .runnerAction(let action):
            return runnerAction(action)
        case .errorWithNoAdvance(let error):
            return "E\(error.fielder.number)"
        case .substitution(let sub):
            return substitution(sub, name: name)
        case .defenseConfirmed:
            // The sample game leaves the defense check blank in the scorebook.
            return ""
        case .runnerForNonRunner(let r):
            return "R \(name(r.runner)) for \(name(r.replacing))"
        case .pitchingChange(let change):
            return "P \(name(change.newPitcher))"
        case .addHitter(let add):
            return "Added \(name(add.player))"
        case .battingHole(let hole):
            // Spots are counted from 0 in the code; people count from 1.
            return "Hole in spot \(hole.spotIndex + 1)"
        case .automaticOut:
            return "Auto out"
        case .timeLimitChange:
            return "Time limit"
        case .keepPlaying:
            return "Keep playing"
        case .manualAdjustment:
            return "Adjusted"
        case .endOfGame:
            return "Final"
        }
    }

    /// One pitch. A pitch that does not end the plate appearance is one letter, as in a
    /// pitch-by-pitch line: B ball, C called strike, S swinging strike, F foul, T foul tip,
    /// L foul bunt. Ball four is "BB", strike three "K" (or "ꓘ" when called), hit by pitch "HBP".
    static func pitch(_ pitch: Pitch, count: Count) -> String {
        let twoStrikes = count.strikes >= 2
        switch pitch.result {
        case .ball:
            return count.balls >= 3 ? "BB" : "B"
        case .calledStrike:
            return twoStrikes ? strikeout("ꓘ", dropped: pitch.droppedThirdStrike) : "C"
        case .swingingStrike:
            return twoStrikes ? strikeout("K", dropped: pitch.droppedThirdStrike) : "S"
        case .foul:
            return "F"
        case .foulTip:
            return twoStrikes ? "K" : "T"
        case .foulBunt:
            return twoStrikes ? "K" : "L"
        case .hitByPitch:
            return "HBP"
        }
    }

    /// Strike three, with what happened if the catcher did not hold it: "K 2-3" when the
    /// batter was thrown out, "K WP", "K PB" or "K E2" when the batter reached.
    static func strikeout(_ mark: String, dropped: Play?) -> String {
        guard let dropped else { return mark }
        let batter = dropped.batterMove
        if dropped.batterResult == .out || batter?.to == .out {
            let fielders = (batter?.outBy.isEmpty == false ? batter!.outBy : dropped.fielders)
            return fielders.isEmpty ? mark : "\(mark) \(joined(fielders))"
        }
        if let error = dropped.errors.first { return "\(mark) E\(error.fielder.number)" }
        switch batter?.reason {
        case .wildPitch: return "\(mark) WP"
        case .passedBall: return "\(mark) PB"
        default: return "\(mark), safe"
        }
    }

    /// A ball in play: "6-3", "F8", "L4-3 DP", "1B 7", "1B 7, E7", "E6", "FC 4-6", "SF 8".
    static func play(_ play: Play) -> String {
        var text: String
        switch play.batterResult {
        case .single, .double, .triple, .homeRun:
            let mark = hitMark(play.batterResult)
            // The fielding area the ball went to; the first fielder to touch it if the scorer
            // tapped no area.
            if let spot = play.hitLocation ?? play.fielders.first {
                text = "\(mark) \(spot.number)"
            } else {
                text = mark
            }
        case .out:
            text = outMark(fielders: play.fielders, battedBall: play.battedBall)
        case .reachedOnError:
            if let first = play.errors.first?.fielder ?? play.fielders.last {
                text = "E\(first.number)"
            } else {
                text = "E"
            }
        case .fieldersChoice:
            text = play.fielders.isEmpty ? "FC" : "FC \(joined(play.fielders))"
        case .sacrificeFly:
            text = play.fielders.isEmpty ? "SF" : "SF \(joined(play.fielders))"
        case .sacrificeBunt:
            text = play.fielders.isEmpty ? "SH" : "SH \(joined(play.fielders))"
        case .reachedOnDroppedThirdStrike:
            text = strikeout("K", dropped: play)
        case .catchersInterference:
            text = "CI"
        }
        switch play.multiOut {
        case .doublePlay: text += " DP"
        case .triplePlay: text += " TP"
        case nil: break
        }
        // Errors the main mark does not already show: a single plus a throwing error by the
        // left fielder is "1B 7, E7".
        var errors = play.errors
        if play.batterResult == .reachedOnError, !errors.isEmpty { errors.removeFirst() }
        for error in errors { text += ", E\(error.fielder.number)" }
        return text
    }

    /// The notation for a play the scorer is still entering: once the result is picked, the
    /// full notation; before that, the fielders tapped so far ("6", then "6-3").
    static func draft(_ draft: PlayDraft, runners: [RunnerMove]) -> String {
        guard let result = draft.batterResult else { return joined(draft.fielders) }
        let play = Play(
            batterResult: result, battedBall: draft.battedBall, fielders: draft.fielders,
            hitLocation: draft.hitLocation, runners: runners, errors: draft.errors, multiOut: draft.multiOut
        )
        if draft.context == .droppedThirdStrike {
            // Strike three is not "K" yet here only because the count is not known; a dropped
            // third strike is always a strikeout.
            return strikeout("K", dropped: play)
        }
        return self.play(play)
    }

    /// Runners moving between pitches: "SB2", "CS2 2-6", "PO1 1-3", "WP", "SB3, SB2, E2".
    static func runnerAction(_ action: RunnerAction) -> String {
        // Lead runner first, as a scorer would read the double steal "SB3, SB2".
        let moves = action.moves.sorted { $0.from > $1.from }
        var parts: [String] = []
        for move in moves {
            // A wild pitch moving three runners is still one "WP".
            let part = runnerMove(move, errors: action.errors)
            if !part.isEmpty, !parts.contains(part) { parts.append(part) }
        }
        for error in action.errors {
            let mark = "E\(error.fielder.number)"
            if !parts.contains(mark) { parts.append(mark) }
        }
        return parts.joined(separator: ", ")
    }

    /// One runner's move between pitches.
    private static func runnerMove(_ move: RunnerMove, errors: [ErrorCharge]) -> String {
        let out = move.to == .out
        let fielders = move.outBy.isEmpty ? "" : " \(joined(move.outBy))"
        switch move.reason {
        case .stolenBase:
            // A stolen base is always one base; anything further came from an error.
            return "SB\(baseMark(after: move.from))"
        case .caughtStealing:
            return "CS\(baseMark(after: move.from))\(fielders)"
        case .pickoff:
            return out ? "PO\(baseMark(move.from))\(fielders)" : "PO\(baseMark(move.from))"
        case .wildPitch: return "WP"
        case .passedBall: return "PB"
        case .balk: return "BK"
        case .defensiveIndifference: return "DI"
        case .advanceOnError:
            return errors.first.map { "E\($0.fielder.number)" } ?? "Adv"
        case .outOnAppeal:
            return "Appeal\(fielders)"
        case .other, nil:
            return out ? "Out\(fielders)" : "Adv"
        }
    }

    /// A batting-order or fielding change, with names: "PH Moss for Collins",
    /// "PR Moss for Ortiz", "Ortiz for Moss", "Moss to cf".
    static func substitution(_ sub: Substitution, name: (PlayerID) -> String) -> String {
        var parts: [String] = []
        for change in sub.batting {
            let prefix: String
            switch change.kind {
            case .pinchHitter: prefix = "PH "
            case .pinchRunner: prefix = "PR "
            case .replacement: prefix = ""
            }
            parts.append("\(prefix)\(name(change.incoming)) for \(name(change.replacing))")
        }
        for assignment in sub.defense {
            parts.append("\(name(assignment.player)) to \(assignment.position.abbreviation)")
        }
        for player in sub.leavesField {
            parts.append("\(name(player)) leaves the field")
        }
        return parts.joined(separator: "; ")
    }

    // MARK: Small pieces

    /// Fielders joined by dashes: "6-4-3".
    static func joined(_ fielders: [Position]) -> String {
        fielders.map { String($0.number) }.joined(separator: "-")
    }

    /// "1B", "2B", "3B" or "HR".
    private static func hitMark(_ result: BatterResult) -> String {
        switch result {
        case .double: "2B"
        case .triple: "3B"
        case .homeRun: "HR"
        default: "1B"
        }
    }

    /// An out on a ball in play: "6-3" or "3U" on the ground, "F8" in the air, "L6" on a line
    /// drive, "P6" on a pop-up, "L4-3" for a line drive with a throw after it.
    private static func outMark(fielders: [Position], battedBall: BattedBallType?) -> String {
        let letter: String
        switch battedBall {
        case .flyBall: letter = "F"
        case .lineDrive: letter = "L"
        case .popUp: letter = "P"
        case .groundBall, .bunt, nil: letter = ""
        }
        if fielders.isEmpty { return letter.isEmpty ? "Out" : letter }
        if fielders.count == 1, letter.isEmpty {
            // One fielder on the ground: unassisted ("3U"). With no batted-ball type, just the number.
            return battedBall == nil ? String(fielders[0].number) : "\(fielders[0].number)U"
        }
        return letter + joined(fielders)
    }

    /// The base after this one, as written in "SB2": 2, 3 or H for home.
    private static func baseMark(after base: Base) -> String {
        switch base {
        case .home: "1"
        case .first: "2"
        case .second: "3"
        case .third: "H"
        }
    }

    /// The base itself, as written in "PO1".
    private static func baseMark(_ base: Base) -> String {
        switch base {
        case .home: "H"
        case .first: "1"
        case .second: "2"
        case .third: "3"
        }
    }
}
