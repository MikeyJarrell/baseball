// Loading scenario files, and checking the rules engine's and stats' answers against them.
//
// In any test module:
//
//     import TestSupport
//     let scenario = try Scenarios.load("hard-5-4-3-double-play")
//     let replay = MyEngine().replay(scenario.game)
//     #expect(scenario.expected.mismatches(situation: replay.situation) == [])
//
// Each `mismatches` function returns a list of plain-English differences, empty when
// everything the scenario checks is right.

import Foundation
import Model

/// Finds and reads the scenario files bundled from Tests/Scenarios/.
public enum Scenarios {
    /// Where the bundled copy of Tests/Scenarios/ is.
    public static var folder: URL {
        guard let url = Bundle.module.resourceURL?.appendingPathComponent("Scenarios", isDirectory: true) else {
            preconditionFailure("The Scenarios folder is missing from the TestSupport bundle.")
        }
        return url
    }

    /// Reads one scenario by name: its path under Tests/Scenarios/ without ".json",
    /// such as "hard-triple-play" or "retrosheet/some-game". Fills in a named setup.
    public static func load(_ name: String) throws -> Scenario {
        let url = folder.appendingPathComponent(name + ".json")
        var scenario = try ScorebookJSON.decode(Scenario.self, from: Data(contentsOf: url))
        scenario.name = name
        if scenario.setup == nil {
            guard let file = scenario.setupFile else {
                throw ScenarioError.noSetup(name)
            }
            scenario.setup = try setup(named: file)
        }
        return scenario
    }

    /// Reads a shared setup from Tests/Scenarios/setups/.
    public static func setup(named name: String) throws -> GameSetup {
        let url = folder.appendingPathComponent("setups/\(name).json")
        return try ScorebookJSON.decode(GameSetup.self, from: Data(contentsOf: url))
    }

    /// The name of every scenario file, in alphabetical order. Shared setups are left out.
    public static func names() -> [String] {
        let root = folder.standardizedFileURL.path
        guard let walker = FileManager.default.enumerator(atPath: root) else { return [] }
        var found: [String] = []
        for case let path as String in walker where path.hasSuffix(".json") && !path.hasPrefix("setups/") {
            found.append(String(path.dropLast(".json".count)))
        }
        return found.sorted()
    }

    /// Every scenario, in alphabetical order by name.
    public static func loadAll() throws -> [Scenario] {
        try names().map(load)
    }
}

/// What can go wrong reading a scenario.
public enum ScenarioError: Error, CustomStringConvertible {
    case noSetup(String)

    public var description: String {
        switch self {
        case .noSetup(let name): "Scenario \(name) has neither a setup nor a setupFile."
        }
    }
}

// MARK: - Checking answers

extension ScenarioExpectation {
    /// Differences between what the scenario expects and the rules engine's situation.
    public func mismatches(situation: Situation) -> [String] {
        self.situation?.mismatches(in: situation) ?? []
    }

    /// Differences between the expected notation and the play log's.
    public func mismatches(log: PlayLog) -> [String] {
        var problems: [String] = []
        for expected in notation ?? [] {
            guard let entry = log.entries.first(where: { $0.event.id == expected.event }) else {
                problems.append("event \(expected.event): not in the play log")
                continue
            }
            if entry.notation != expected.notation {
                problems.append("event \(expected.event) notation: expected \(expected.notation), got \(entry.notation)")
            }
        }
        return problems
    }

    /// Differences between the expected stats and a box score.
    public func mismatches(box: BoxScore) -> [String] {
        var problems: [String] = []
        let teamsBoxes = [box.away, box.home]

        for e in batting ?? [] {
            // A player can have more than one line (batting in two spots); add them up.
            let lines = teamsBoxes.flatMap(\.batting).filter { $0.player == e.player }
            let s = lines.reduce(BattingCounts()) { $0 + $1.stats }
            let p = "batting \(e.player)"
            check(&problems, p, "plateAppearances", e.plateAppearances, s.plateAppearances)
            check(&problems, p, "atBats", e.atBats, s.atBats)
            check(&problems, p, "runs", e.runs, s.runs)
            check(&problems, p, "hits", e.hits, s.hits)
            check(&problems, p, "doubles", e.doubles, s.doubles)
            check(&problems, p, "triples", e.triples, s.triples)
            check(&problems, p, "homeRuns", e.homeRuns, s.homeRuns)
            check(&problems, p, "runsBattedIn", e.runsBattedIn, s.runsBattedIn)
            check(&problems, p, "walks", e.walks, s.walks)
            check(&problems, p, "strikeouts", e.strikeouts, s.strikeouts)
            check(&problems, p, "hitByPitch", e.hitByPitch, s.hitByPitch)
            check(&problems, p, "sacrificeFlies", e.sacrificeFlies, s.sacrificeFlies)
            check(&problems, p, "sacrificeBunts", e.sacrificeBunts, s.sacrificeBunts)
            check(&problems, p, "stolenBases", e.stolenBases, s.stolenBases)
            check(&problems, p, "caughtStealing", e.caughtStealing, s.caughtStealing)
        }

        for e in pitching ?? [] {
            let s = teamsBoxes.flatMap(\.pitching).filter { $0.player == e.pitcher }
                .reduce(PitchingCounts()) { $0 + $1.stats }
            let p = "pitching \(e.pitcher)"
            check(&problems, p, "outsRecorded", e.outsRecorded, s.outsRecorded)
            check(&problems, p, "battersFaced", e.battersFaced, s.battersFaced)
            check(&problems, p, "hits", e.hits, s.hits)
            check(&problems, p, "runs", e.runs, s.runs)
            check(&problems, p, "walks", e.walks, s.walks)
            check(&problems, p, "strikeouts", e.strikeouts, s.strikeouts)
            check(&problems, p, "homeRuns", e.homeRuns, s.homeRuns)
            check(&problems, p, "hitBatters", e.hitBatters, s.hitBatters)
            check(&problems, p, "pitches", e.pitches, s.pitches)
            check(&problems, p, "strikes", e.strikes, s.strikes)
        }

        for e in fielding ?? [] {
            let s = teamsBoxes.flatMap(\.fielding).filter { $0.player == e.player }
                .reduce(FieldingCounts()) { $0 + $1.stats }
            let p = "fielding \(e.player)"
            check(&problems, p, "putouts", e.putouts, s.putouts)
            check(&problems, p, "assists", e.assists, s.assists)
            check(&problems, p, "errors", e.errors, s.errors)
        }

        for e in teams ?? [] {
            let t = box[e.team]
            let p = "team \(e.team.rawValue)"
            check(&problems, p, "runs", e.runs, t.runs)
            check(&problems, p, "hits", e.hits, t.hits)
            check(&problems, p, "errors", e.errors, t.errors)
            check(&problems, p, "leftOnBase", e.leftOnBase, t.leftOnBase)
            let dp = box.notes.doublePlays.filter { $0.team == e.team }.reduce(0) { $0 + $1.count }
            check(&problems, p, "doublePlays", e.doublePlays, dp)
            let tp = box.notes.triplePlays.filter { $0.team == e.team }.reduce(0) { $0 + $1.count }
            check(&problems, p, "triplePlays", e.triplePlays, tp)
        }
        return problems
    }
}

extension ExpectedSituation {
    /// Differences between these expected values and a situation.
    public func mismatches(in s: Situation) -> [String] {
        var problems: [String] = []
        check(&problems, "situation", "inning", inning, s.inning)
        check(&problems, "situation", "half", half, s.half)
        check(&problems, "situation", "outs", outs, s.outs)
        check(&problems, "situation", "count", count, s.count)
        check(&problems, "situation", "score", score, s.score)
        check(&problems, "situation", "batter", batter, s.batter)
        check(&problems, "situation", "onDeck", onDeck, s.onDeck)
        check(&problems, "situation", "pitcher", pitcher, s.pitcher)
        check(&problems, "situation", "isRunnerNeeded", isRunnerNeeded, s.runnerNeededFor != nil)
        check(&problems, "situation", "runnerNeededFor", runnerNeededFor, s.runnerNeededFor)
        check(&problems, "situation", "isBetweenHalfInnings", isBetweenHalfInnings, s.isBetweenHalfInnings)
        check(&problems, "situation", "isRegulationComplete", isRegulationComplete, s.isRegulationComplete)
        check(&problems, "situation", "isFinal", isFinal, s.isFinal)

        if let runners {
            for base in Base.occupiable {
                let want = runners.first { $0.base == base }
                let got = s.runner(on: base)
                if want?.runner != got?.runner {
                    problems.append("runner on \(base.rawValue): expected \(want?.runner.rawValue ?? "nobody"), got \(got?.runner.rawValue ?? "nobody")")
                    continue
                }
                guard let want, let got else { continue }
                check(&problems, "runner on \(base.rawValue)", "responsiblePitcher", want.responsiblePitcher, got.responsiblePitcher)
                check(&problems, "runner on \(base.rawValue)", "standingInFor", want.standingInFor, got.standingInFor)
            }
        }

        for e in pitchers ?? [] {
            let t = s.tally(for: e.pitcher)
            let p = "pitcher \(e.pitcher)"
            check(&problems, p, "pitches", e.pitches, t?.pitches ?? 0)
            check(&problems, p, "strikes", e.strikes, t?.strikes ?? 0)
            check(&problems, p, "battersFaced", e.battersFaced, t?.battersFaced ?? 0)
        }

        for e in battingSlots ?? [] {
            let slots = s[e.team].battingOrder.slots
            let p = "\(e.team.rawValue) spot \(e.index)"
            guard slots.indices.contains(e.index) else {
                problems.append("\(p): the order has only \(slots.count) spots")
                continue
            }
            let slot = slots[e.index]
            check(&problems, p, "players", e.players, slot.players)
            check(&problems, p, "position", e.position, slot.position)
            if e.isExtraHitter == true, slot.position != nil {
                problems.append("\(p): expected no fielding position, got \(slot.position!.abbreviation)")
            }
        }

        for e in lineups ?? [] {
            let t = s[e.team]
            let p = "\(e.team.rawValue) lineup"
            check(&problems, p, "length", e.length, t.battingOrder.count)
            check(&problems, p, "nextBatterIndex", e.nextBatterIndex, t.nextBatterIndex)
        }

        for e in fielders ?? [] {
            let got = s[e.team].fielder(at: e.position)
            check(&problems, "\(e.team.rawValue) \(e.position.abbreviation)", "player", e.player, got)
        }
        return problems
    }
}

/// Adds a line to `problems` when an expected value is given and differs from the actual one.
private func check<T: Equatable>(_ problems: inout [String], _ subject: String, _ field: String, _ expected: T?, _ actual: T) {
    guard let expected, expected != actual else { return }
    problems.append("\(subject) \(field): expected \(expected), got \(actual)")
}

/// The same, for an actual value that may itself be missing.
private func check<T: Equatable>(_ problems: inout [String], _ subject: String, _ field: String, _ expected: T?, _ actual: T?) {
    guard let expected, expected != actual else { return }
    problems.append("\(subject) \(field): expected \(expected), got \(actual.map { "\($0)" } ?? "nothing")")
}
