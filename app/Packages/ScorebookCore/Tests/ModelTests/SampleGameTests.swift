// Cross-checks the hand-written sample game: the play log and the hand-written box score
// were each worked out separately, so adding up the play log here must give the same
// numbers as the box score. These are plain tallies, not the stats engine: they only
// count what each play log entry already says.

import Foundation
import Testing
import Model
import SampleData

@Suite("The sample game")
struct SampleGameTests {
    let log = SampleGame.playLog
    let box = SampleGame.boxScore

    @Test("One play log entry per event, in the same order")
    func entriesMatchEvents() {
        #expect(log.entries.map(\.event) == SampleGame.game.events)
        #expect(SampleGame.game.isFinished)
        #expect(SampleGame.game.ending?.finalScore == Score(away: 3, home: 5))
    }

    @Test("The play log adds up to the final box score")
    func finalBoxScore() {
        #expect(boxScoreProblems(log: log, box: box) == [])
        #expect(SampleGame.finalSituation.score == Score(away: 3, home: 5))
    }

    @Test("The play log through three innings adds up to the box score so far")
    func boxScoreSoFar() {
        let soFar = SampleGame.throughThreeInnings
        #expect(soFar.log.entries.allSatisfy { $0.inning <= 3 })
        #expect(soFar.log.entries.last?.endsHalfInning == true)
        #expect(boxScoreProblems(log: soFar.log, box: SampleGame.boxScoreThroughThree) == [])
    }

    @Test("Every batter's hand-written history matches the play log")
    func plateAppearanceHistories() {
        let fromLog = Dictionary(grouping: log.entries.filter { $0.plateAppearance != nil }) { $0.plateAppearance!.batter }
        #expect(Set(fromLog.keys) == Set(SampleGame.plateAppearances.keys))
        for (player, history) in SampleGame.plateAppearances {
            let entries = fromLog[player] ?? []
            #expect(history.map(\.notation) == entries.map(\.notation), "notation for \(player)")
            #expect(history.map(\.inning) == entries.map(\.inning), "innings for \(player)")
            #expect(history.map(\.outcome) == entries.map { $0.plateAppearance!.outcome }, "outcomes for \(player)")
            #expect(history.map(\.rbi) == entries.map { $0.plateAppearance!.rbi }, "runs batted in for \(player)")
        }
        #expect(SampleGame.plateAppearancesThroughThree["d1"]?.map(\.notation) == ["BB", "6-3"])
        #expect(SampleGame.plateAppearancesThroughThree["m10"] == nil)
    }

    @Test("The last out runs for a designated non-runner and keeps their own stats")
    func runnerForNonRunner() {
        // Webb, the last out, ran for Quinn, so the caught stealing is on Webb's own line and
        // nobody has a line under Quinn.
        let lines = box.home.batting
        let quinn = lines.firstIndex { $0.player == "d4" }!
        #expect(lines[quinn + 1].player == "d5")
        #expect(lines.first { $0.player == "d3" }?.stats.caughtStealing == 1)
        #expect(lines[quinn].stats.caughtStealing == 0)
    }

    @Test("Substitutes are in the final batting orders under the players they replaced")
    func finalOrders() {
        #expect(log.awayOrder.slots[8].players == ["m9", "m10", "m12"])
        #expect(log.homeOrder.slots[8].players == ["d9", "d12"])
        #expect(log.homeOrder.count == 10)
    }

    @Test("Season totals list all twelve of our players, including two with no at-bats")
    func season() {
        #expect(SampleSeason.totals.batting.count == 12)
        let nash = SampleSeason.totals.batting.first { $0.player == "d11" }
        #expect(nash?.games == 0 && nash?.stats.atBats == 0 && nash?.stats.battingAverage == nil)
        let voss = SampleSeason.totals.batting.first { $0.player == "d12" }
        #expect(voss?.games == 1 && voss?.stats.plateAppearances == 0)
    }

    @Test("Sample situations cover the plan's list")
    func situations() {
        #expect(SampleSituations.all.count >= 8)
        #expect(SampleSituations.basesLoadedTwoOutsFullCount.situation.runners.count == 3)
        #expect(SampleSituations.tenthHitterUpAfterAddingOne.situation.batter == "d10")
        #expect(SampleSituations.tenthHitterUpAfterAddingOne.situation.onDeck == "d11")
        #expect(SampleSituations.extraInnings.situation.inning == 10)
        #expect(SampleSituations.theirHitterKnownByNumber.player(SampleSituations.theirHitterKnownByNumber.situation.batter)?.displayName == "#5")
    }

    @Test("The sample rules engine, the real one, suggests the obvious runner moves")
    func sampleEngine() {
        let engine = SampleRulesEngine()
        let situation = SampleSituations.runnerOnFirstOneOut.situation
        let single = engine.suggestRunners(for: PlayDraft(batterResult: .single), in: situation)
        #expect(single.runners.contains { $0.runner == "m3" && $0.to == .second })
        #expect(single.runners.contains { $0.runner == "m4" && $0.to == .first })
        let doublePlay = PlayDraft(batterResult: .out, fielders: [.thirdBase, .secondBase, .firstBase], multiOut: .doublePlay)
        let preview = engine.preview(doublePlay, in: situation)
        #expect(preview.outsOnPlay == 2 && preview.endsHalfInning && preview.notation == "5-4-3 DP")
        #expect(engine.replay(SampleGame.game).situation == SampleGame.finalSituation)

        // A wild pitch with runners on second and third moves both up one.
        let twoOn = SampleSituations.secondAndThirdNobodyOut.situation
        let wildPitch = engine.suggestRunnerAction(.wildPitch, runners: twoOn.runners.map(\.runner), in: twoOn)
        #expect(wildPitch.contains { $0.runner == "m4" && $0.to == .scored })
        #expect(wildPitch.contains { $0.runner == "m5" && $0.to == .third })
        // The last out runs. Quinn singles in the bottom of the 3rd with Shaw coming up: the
        // Diamond Dogs' last recorded out was Webb's strikeout, so Webb runs.
        var reached = SampleSituations.designatedNonRunnerOnFirst.situation
        reached.home.nextBatterIndex = 4
        let quinnSingle = log.entries.firstIndex { $0.notation == "1B 7" && $0.batter == "d4" }!
        var soFar = log
        soFar.entries = Array(log.entries[...quinnSingle])
        #expect(engine.suggestedRunner(for: "d4", in: soFar, situation: reached) == "d3")
        // If Webb were the one now at bat, the last recorded out before them runs: Moreno.
        reached.home.nextBatterIndex = 2
        #expect(engine.suggestedRunner(for: "d4", in: soFar, situation: reached) == "d1")
        // First inning, no outs yet: the last batter in the order, Cole.
        reached.home.nextBatterIndex = 1
        var noOuts = log
        noOuts.entries = []
        #expect(engine.suggestedRunner(for: "d1", in: noOuts, situation: reached) == "d10")
        #expect(DoNothingRulesEngine().suggestedRunner(for: "d1", in: noOuts, situation: reached) == nil)
        let caught = engine.suggestRunnerAction(.caughtStealing, runners: ["m3"], in: situation)
        #expect(caught == [RunnerMove(runner: "m3", from: .first, to: .out, reason: .caughtStealing, outAt: .second)])
    }

    @Test("The sample game's time limit runs out during the fifth, which began before it")
    func sampleGameClock() {
        let end = SampleGame.finalSituation.timeLimitEndsAt!
        #expect(end == SampleGame.finalSituation.gameStartedAt!.addingTimeInterval(3 * 3600))
        let fifth = log.entries.filter { $0.inning == 5 && $0.pitches > 0 }
        #expect(fifth.first!.event.enteredAt < end)
        #expect(fifth.last!.event.enteredAt >= end)
        #expect(log.entries.filter { $0.pitches > 0 }.allSatisfy { $0.inning <= 5 })
        #expect(SampleGame.game.ending?.reason == .timeLimit)
    }

    @Test("Sample situations put the pitcher with a pitch count on the mound")
    func pitchersOnTheMound() {
        for sample in SampleSituations.all {
            let s = sample.situation
            for side in TeamSide.allCases {
                guard let pitcher = s[side].pitcher, let tally = s.pitchers.last(where: { $0.team == side }) else { continue }
                #expect(tally.pitcher == pitcher, "\(sample.title): \(side) pitcher")
                // Where the starting pitcher batted, the pitcher now on the mound bats.
                let starter = sample.setup[side].startingPitcher
                if let spot = s[side].battingOrder.slots.first(where: { $0.players.first == starter }) {
                    #expect(spot.current == pitcher, "\(sample.title): \(side) pitcher's batting spot")
                }
            }
            #expect((s.timeLimitEndsAt != nil) == (sample.setup.timeLimitMinutes != nil), "\(sample.title): time limit")
        }
    }
}

/// Adds up a play log and lists every way it disagrees with a hand-written box score.
/// Plain tallies of what each entry already says, so the two hand-written accounts check
/// each other: runs by inning (manual score changes included), pitching, batting, stolen
/// bases, fielding and runners left on base.
func boxScoreProblems(log: PlayLog, box: BoxScore) -> [String] {
    var problems: [String] = []
    func check(_ what: String, _ got: Int, _ want: Int) {
        if got != want { problems.append("\(what): play log says \(got), box score says \(want)") }
    }
    let entries = log.entries
    let appearances = entries.compactMap(\.plateAppearance)
    let runs = entries.flatMap(\.runs)
    let hitOutcomes: [PlateAppearanceOutcome] = [.single, .double, .triple, .homeRun]

    // Runs by inning, with any manual score changes, add up to the line score and team runs.
    for (side, half) in [(TeamSide.away, HalfInning.top), (.home, .bottom)] {
        let innings = box.lineScore[side].count
        for inning in 1...max(innings, 1) where innings > 0 {
            let inInning = entries.filter { $0.inning == inning && $0.half == half }
            let scored = inInning.reduce(0) { $0 + $1.runs.count } + inInning.reduce(0) { $0 + ($1.adjustedRuns?[side] ?? 0) }
            check("\(side) runs in inning \(inning)", scored, box.lineScore[side][inning - 1] ?? 0)
        }
        check("\(side) runs", box.lineScore[side].reduce(0) { $0 + ($1 ?? 0) }, box[side].runs)

        // Runners left on base: whenever a half-inning ended, and when the game ended.
        let left = entries.filter { $0.half == half && $0.endsHalfInning }.reduce(0) { $0 + $1.after.runners.count }
            + entries.filter { entry in
                guard case .endOfGame = entry.event.kind else { return false }
                return entry.half == half
            }.reduce(0) { $0 + $1.after.runners.count }
        check("\(side) left on base", left, box[side].leftOnBase)
        check("\(side) hits", box[side].battingTotals.hits, box[side].hits)
    }

    for line in box.away.pitching + box.home.pitching {
        let mine = entries.filter { $0.pitcher == line.player }
        let faced = appearances.filter { $0.pitcher == line.player }
        check("pitches for \(line.name)", mine.reduce(0) { $0 + $1.pitches }, line.stats.pitches)
        check("strikes for \(line.name)", mine.reduce(0) { $0 + $1.strikes }, line.stats.strikes)
        check("outs for \(line.name)", mine.reduce(0) { $0 + $1.outs.count }, line.stats.outsRecorded)
        check("batters faced by \(line.name)", faced.count, line.stats.battersFaced)
        check("hits off \(line.name)", faced.filter { hitOutcomes.contains($0.outcome) }.count, line.stats.hits)
        check("walks by \(line.name)", faced.filter { [.walk, .intentionalWalk].contains($0.outcome) }.count, line.stats.walks)
        check("strikeouts by \(line.name)", faced.filter { $0.outcome == .strikeout }.count, line.stats.strikeouts)
        check("runs charged to \(line.name)", runs.filter { $0.responsiblePitcher == line.player }.count, line.stats.runs)
    }

    // Stolen bases and caught stealing, by whoever ran.
    let moves = entries.compactMap { entry -> RunnerAction? in
        if case .runnerAction(let action) = entry.event.kind { return action }
        return nil
    }.flatMap(\.moves)

    for line in box.away.batting + box.home.batting {
        let mine = appearances.filter { $0.batter == line.player }
        check("plate appearances for \(line.name)", mine.count, line.stats.plateAppearances)
        check("hits for \(line.name)", mine.filter { hitOutcomes.contains($0.outcome) }.count, line.stats.hits)
        check("runs batted in for \(line.name)", mine.reduce(0) { $0 + $1.rbi }, line.stats.runsBattedIn)
        check("runs for \(line.name)", runs.filter { $0.creditedTo == line.player }.count, line.stats.runs)
        check("stolen bases for \(line.name)",
              moves.filter { $0.runner == line.player && $0.reason == .stolenBase }.count, line.stats.stolenBases)
        check("caught stealing for \(line.name)",
              moves.filter { $0.runner == line.player && $0.reason == .caughtStealing }.count, line.stats.caughtStealing)
    }

    // Where each fielder played, by inning, from the fielders the play log lists for each pitch.
    for (side, half) in [(TeamSide.away, HalfInning.bottom), (.home, .top)] {
        var played: [PlayerID: [Position: Set<Int>]] = [:]
        for entry in entries where entry.half == half && entry.pitches > 0 {
            for f in entry.fielders { played[f.player, default: [:]][f.position, default: []].insert(entry.inning) }
        }
        let lines = box[side].fielding
        check("\(side) fielders with lines", lines.count, played.count)
        for line in lines {
            for appearance in line.appearances {
                let innings = (played[line.player]?[appearance.position] ?? []).sorted()
                if innings != appearance.innings {
                    problems.append("\(line.name) at \(appearance.position.abbreviation): play log says \(innings), box score says \(appearance.innings)")
                }
            }
        }
    }

    let outs = entries.flatMap(\.outs)
    let errors = entries.flatMap(\.errors)
    for line in box.away.fielding + box.home.fielding {
        check("putouts for \(line.name)", outs.filter { $0.putout == line.player }.count, line.stats.putouts)
        check("assists for \(line.name)", outs.reduce(0) { $0 + $1.assists.filter { $0 == line.player }.count }, line.stats.assists)
        check("errors for \(line.name)", errors.filter { $0.player == line.player }.count, line.stats.errors)
    }
    return problems
}
