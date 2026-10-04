// OverviewWording: the words the game overview puts on screen.
//
// Everything here turns facts the rules engine and stats already decided into words: "3rd",
// "Bottom 3rd", "2⅓", "Diaz doubled to left", "Diamond Dogs 3, Mudcats 2". Nothing here
// decides anything about baseball. They are plain functions, so tests can check them
// without drawing a screen.

import Foundation
import Model

/// The words on the game overview.
public enum OverviewWording {

    // MARK: Innings

    /// An inning as people say it: 1 is "1st", 2 is "2nd", 11 is "11th", 21 is "21st".
    public static func ordinal(_ n: Int) -> String {
        let lastTwo = n % 100
        if (11...13).contains(lastTwo) { return "\(n)th" }
        switch n % 10 {
        case 1: return "\(n)st"
        case 2: return "\(n)nd"
        case 3: return "\(n)rd"
        default: return "\(n)th"
        }
    }

    /// "Top 3rd" or "Bottom 3rd".
    public static func halfInning(_ half: HalfInning, _ inning: Int) -> String {
        "\(half == .top ? "Top" : "Bottom") \(ordinal(inning))"
    }

    /// The short heading over a half-inning in the play-by-play, as in the mockup: "▲ 3rd"
    /// for the top, "▼ 3rd" for the bottom.
    public static func halfInningHeading(_ half: HalfInning, _ inning: Int) -> String {
        "\(half == .top ? "▲" : "▼") \(ordinal(inning))"
    }

    // MARK: Numbers

    /// Innings pitched the old-time way, matching the newspaper box score: 9 outs is "3",
    /// 7 outs is "2⅓", 2 outs is "⅔", none is "0".
    public static func inningsPitched(outs: Int) -> String {
        let whole = outs / 3
        let thirds = ["", "⅓", "⅔"][outs % 3]
        if whole == 0 && !thirds.isEmpty { return thirds }
        return "\(whole)\(thirds)"
    }

    /// A count with an en dash, the way the batting screen writes it: "1–1".
    public static func count(_ count: Count) -> String {
        "\(count.balls)–\(count.strikes)"
    }

    /// "1 out", "2 outs", "0 outs".
    public static func outs(_ n: Int) -> String {
        n == 1 ? "1 out" : "\(n) outs"
    }

    /// "1 run", "2 runs".
    static func plural(_ n: Int, _ word: String) -> String {
        n == 1 ? "1 \(word)" : "\(n) \(word)s"
    }

    // MARK: Teams and the score

    /// The team listed first wherever both teams share a line: ours when we know which team
    /// is ours, else the visitors.
    public static func firstSide(_ setup: GameSetup) -> TeamSide {
        setup.ourSide ?? .away
    }

    /// The score with our team first: "Diamond Dogs 3, Mudcats 2".
    public static func score(_ score: Score, setup: GameSetup) -> String {
        let first = firstSide(setup)
        let second = first.opponent
        return "\(setup[first].name) \(score[first]), \(setup[second].name) \(score[second])"
    }

    /// The batting line under a hitter's name in the box so far: "2 for 3 · 1 run · 2 RBI · cf".
    public static func battingSummary(_ line: BattingLine) -> String {
        let s = line.stats
        var parts: [String] = []
        if s.atBats > 0 {
            parts.append("\(s.hits) for \(s.atBats)")
        } else if s.plateAppearances > 0 {
            parts.append("no at-bats")
        } else {
            parts.append("has not batted")
        }
        if s.runs > 0 { parts.append(plural(s.runs, "run")) }
        if s.runsBattedIn > 0 { parts.append("\(s.runsBattedIn) RBI") }
        if s.stolenBases > 0 { parts.append("\(s.stolenBases) SB") }
        if !line.positions.isEmpty {
            parts.append(line.positions.map(\.rawValue).joined(separator: "-"))
        }
        return parts.joined(separator: " · ")
    }

    /// True when this plate appearance ended in a hit, so its chip is drawn in green.
    public static func isHit(_ outcome: PlateAppearanceOutcome) -> Bool {
        [.single, .double, .triple, .homeRun].contains(outcome)
    }

    /// True when scorebook notation starts with a hit ("1B 7", "HR 9"), for chips that only
    /// have the notation to go on.
    public static func isHitNotation(_ notation: String) -> Bool {
        ["1B", "2B", "3B", "HR"].contains { notation.hasPrefix($0) }
    }

    // MARK: Where the game stands

    /// The "Right now" line: "Bottom 3rd, 1 out, runner on 2nd". Between half-innings it
    /// says which break it is: "Middle 3rd" or "End 3rd".
    public static func rightNow(_ situation: Situation) -> String {
        if situation.isFinal { return "Final" }
        if situation.isBetweenHalfInnings {
            // After the third out the situation is already the next half-inning.
            if situation.half == .bottom { return "Middle \(ordinal(situation.inning))" }
            return "End \(ordinal(max(1, situation.inning - 1)))"
        }
        return "\(halfInning(situation.half, situation.inning)), \(outs(situation.outs)), \(runners(situation.occupiedBases))"
    }

    /// Who is on base, in words: "nobody on", "runner on 2nd", "runners on 1st and 3rd",
    /// "bases loaded".
    public static func runners(_ bases: Set<Base>) -> String {
        let on = Base.occupiable.filter { bases.contains($0) }
        switch on.count {
        case 0: return "nobody on"
        case 3: return "bases loaded"
        case 1: return "runner on \(ordinal(on[0].order))"
        default: return "runners on \(on.map { ordinal($0.order) }.joined(separator: " and "))"
        }
    }

    // MARK: Names

    /// The name to use in a sentence: the player's last name ("Diaz"), "#22" or "Batter 4".
    static func name(_ id: PlayerID?, in setup: GameSetup) -> String {
        guard let id else { return "The batter" }
        return setup.player(id)?.lastName ?? id.rawValue
    }

    /// A fielder by role, for "an error by the shortstop".
    static func fielder(_ position: Position) -> String {
        switch position {
        case .pitcher: "pitcher"
        case .catcher: "catcher"
        case .firstBase: "first baseman"
        case .secondBase: "second baseman"
        case .thirdBase: "third baseman"
        case .shortstop: "shortstop"
        case .leftField: "left fielder"
        case .centerField: "center fielder"
        case .rightField: "right fielder"
        }
    }

    /// Where a batted ball went, for "doubled to left" and "flied out to center".
    static func direction(_ position: Position) -> String {
        switch position {
        case .pitcher: "to the pitcher"
        case .catcher: "to the catcher"
        case .firstBase: "to first"
        case .secondBase: "to second"
        case .thirdBase: "to third"
        case .shortstop: "to short"
        case .leftField: "to left"
        case .centerField: "to center"
        case .rightField: "to right"
        }
    }

    /// A base by name, for "stole second": "first", "second", "third", "home".
    static func baseName(_ base: Base) -> String {
        switch base {
        case .home: "home"
        case .first: "first"
        case .second: "second"
        case .third: "third"
        }
    }

    /// The base one ahead of this one: a runner caught stealing from first was going to second.
    static func nextBase(after base: Base) -> Base {
        switch base {
        case .home: .first
        case .first: .second
        case .second: .third
        case .third: .home
        }
    }

    /// Why the scorer was asked whether the game was over, in words.
    static func reason(_ reason: EndOfGame.Reason) -> String {
        switch reason {
        case .regulation: "innings complete"
        case .timeLimit: "time limit"
        case .runRule: "run rule"
        case .called: "called"
        }
    }

    // MARK: One event in words

    /// One event as a sentence for the play-by-play: "Diaz doubled to left", "Park stole
    /// second", "Reyes now pitching for the Mudcats". Uses only what the event and the play
    /// log entry already say.
    public static func describe(_ entry: PlayLogEntry, setup: GameSetup) -> String {
        let batter = name(entry.batter, in: setup)
        func who(_ id: PlayerID) -> String { name(id, in: setup) }

        switch entry.event.kind {
        case .pitch(let pitch):
            // A pitch that ended the plate appearance: ball four, strike three, hit by pitch.
            if let result = entry.plateAppearance {
                if let dropped = pitch.droppedThirdStrike {
                    return dropped.batterResult == .out
                        ? "\(batter) struck out, thrown out at first"
                        : "\(batter) struck out, safe on the dropped third strike"
                }
                switch result.outcome {
                case .walk: return "\(batter) walked"
                case .hitByPitch: return "\(batter) was hit by a pitch"
                case .strikeout:
                    switch pitch.result {
                    case .calledStrike: return "\(batter) struck out looking"
                    case .foulTip: return "\(batter) struck out on a foul tip"
                    case .foulBunt: return "\(batter) struck out bunting foul"
                    default: return "\(batter) struck out swinging"
                    }
                default: return "\(batter): \(pitch.result.label)"
                }
            }
            // An ordinary pitch in the middle of a plate appearance.
            return pitch.result.label.prefix(1).uppercased() + pitch.result.label.dropFirst()

        case .intentionalWalk:
            return "\(batter) was walked intentionally"

        case .ballInPlay(let play):
            return describe(play, batter: batter)

        case .runnerAction(let action):
            let moves = action.moves.map { describe($0, name: who) }
            var text = moves.isEmpty ? "Runners moved" : moves.joined(separator: "; ")
            if let error = action.errors.first {
                text += ", error by the \(fielder(error.fielder))"
            }
            return text

        case .errorWithNoAdvance(let error):
            return "Error by the \(fielder(error.fielder)), nobody moved"

        case .substitution(let sub):
            var parts: [String] = []
            for change in sub.batting {
                switch change.kind {
                case .pinchHitter: parts.append("\(who(change.incoming)) pinch-hit for \(who(change.replacing))")
                case .pinchRunner: parts.append("\(who(change.incoming)) pinch-ran for \(who(change.replacing))")
                case .replacement: parts.append("\(who(change.incoming)) took \(who(change.replacing))’s batting spot")
                }
            }
            for spot in sub.defense {
                parts.append("\(who(spot.player)) to \(spot.position.name)")
            }
            for player in sub.leavesField {
                parts.append("\(who(player)) left the field")
            }
            return parts.isEmpty ? "\(setup[sub.team].name) lineup change" : parts.joined(separator: "; ")

        case .defenseConfirmed(let check):
            return "\(setup[check.team].name) fielders checked, no changes"

        case .runnerForNonRunner(let swap):
            return "\(who(swap.runner)) ran for \(who(swap.replacing))"

        case .pitchingChange(let change):
            var text = "\(who(change.newPitcher)) now pitching for the \(setup[change.team].name)"
            if let moved = change.previousPitcherMovesTo, let old = entry.pitcher, old != change.newPitcher {
                text += "; \(who(old)) to \(moved.name)"
            }
            return text

        case .addHitter(let add):
            return "\(who(add.player)) added to the \(setup[add.team].name) batting order"

        case .battingHole(let hole):
            return "\(setup[hole.team].name) \(ordinal(hole.spotIndex + 1)) spot left empty: an out each time it comes up"

        case .automaticOut(let out):
            return "Automatic out: the \(setup[out.team].name) \(ordinal(out.spotIndex + 1)) spot is empty"

        case .timeLimitChange(let change):
            guard let endsAt = change.endsAt else { return "Time limit set back to the usual" }
            return "Time limit set to \(endsAt.formatted(date: .omitted, time: .shortened))"

        case .keepPlaying(let keep):
            return "Kept playing (\(reason(keep.reason)))"

        case .manualAdjustment(let adjustment):
            if let note = adjustment.note, !note.isEmpty { return "Manual adjustment: \(note)" }
            return "Manual adjustment"

        case .endOfGame(let end):
            return "Game over (\(reason(end.reason)))"
        }
    }

    /// A ball in play as a sentence: "Ruiz grounded into a double play", "Kim singled to center".
    static func describe(_ play: Play, batter: String) -> String {
        let firstFielder = play.fielders.first
        let toward = (play.hitLocation ?? firstFielder).map { " " + direction($0) } ?? ""
        switch play.batterResult {
        case .single: return "\(batter) singled\(toward)"
        case .double: return "\(batter) doubled\(toward)"
        case .triple: return "\(batter) tripled\(toward)"
        case .homeRun: return "\(batter) homered\(toward)"
        case .out:
            if let multi = play.multiOut {
                let kind = multi == .doublePlay ? "double play" : "triple play"
                switch play.battedBall {
                case .groundBall: return "\(batter) grounded into a \(kind)"
                case .lineDrive: return "\(batter) lined into a \(kind)"
                default: return "\(batter) hit into a \(kind)"
                }
            }
            let verb: String
            switch play.battedBall {
            case .groundBall: verb = "grounded out"
            case .flyBall: verb = "flied out"
            case .lineDrive: verb = "lined out"
            case .popUp: verb = "popped out"
            case .bunt: verb = "bunted out"
            case nil: verb = "was out"
            }
            let where_ = firstFielder.map { " " + direction($0) } ?? ""
            return "\(batter) \(verb)\(where_)"
        case .reachedOnError:
            let charged = play.errors.first?.fielder ?? firstFielder
            return "\(batter) reached on an error" + (charged.map { " by the \(fielder($0))" } ?? "")
        case .fieldersChoice: return "\(batter) reached on a fielder’s choice"
        case .sacrificeFly: return "\(batter) hit a sacrifice fly\(toward)"
        case .sacrificeBunt: return "\(batter) laid down a sacrifice bunt"
        case .reachedOnDroppedThirdStrike: return "\(batter) struck out, safe on the dropped third strike"
        case .catchersInterference: return "\(batter) reached on catcher’s interference"
        }
    }

    /// One runner's move between pitches: "Park stole second", "Webb was caught stealing
    /// second", "Bell to third on a wild pitch".
    static func describe(_ move: RunnerMove, name: (PlayerID) -> String) -> String {
        let runner = name(move.runner)
        let destination: String = {
            switch move.to {
            case .scored: return "scored"
            case .out: return "was out"
            default: return "to \(move.to.base.map(baseName) ?? "")"
            }
        }()
        let outAt = baseName(move.outAt ?? nextBase(after: move.from))
        switch move.reason {
        case .stolenBase:
            let stolen = move.to == .scored && !move.advancedOnError ? "home" : baseName(nextBase(after: move.from))
            return "\(runner) stole \(stolen)" + (move.advancedOnError ? ", \(destination) on the error" : "")
        case .caughtStealing:
            return "\(runner) was caught stealing \(outAt)"
        case .pickoff:
            if move.to == .out { return "\(runner) was picked off \(baseName(move.outAt ?? move.from))" }
            return "\(runner) \(destination) on a pickoff throw"
        case .wildPitch: return "\(runner) \(destination) on a wild pitch"
        case .passedBall: return "\(runner) \(destination) on a passed ball"
        case .balk: return "\(runner) \(destination) on a balk"
        case .advanceOnError: return "\(runner) \(destination) on an error"
        case .defensiveIndifference: return "\(runner) \(destination), nobody threw"
        case .outOnAppeal: return "\(runner) was out on appeal"
        case .other, nil:
            if move.to == .out { return "\(runner) was out at \(outAt)" }
            return "\(runner) \(destination)"
        }
    }
}
