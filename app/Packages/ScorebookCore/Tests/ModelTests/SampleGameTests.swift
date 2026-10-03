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

    @Test("Runs by inning add up to the line score and the final score")
    func lineScore() {
        for (side, half) in [(TeamSide.away, HalfInning.top), (.home, .bottom)] {
            let byInning = (1...5).map { inning in
                log.entries.filter { $0.inning == inning && $0.half == half }.reduce(0) { $0 + $1.runs.count }
            }
            #expect(byInning == box.lineScore[side].map { $0 ?? 0 })
            #expect(byInning.reduce(0, +) == box[side].runs)
        }
        #expect(SampleGame.finalSituation.score == Score(away: 3, home: 5))
    }

    @Test("Every pitcher's pitches, strikes, batters faced and outs match the box score")
    func pitching() {
        for line in box.away.pitching + box.home.pitching {
            let mine = log.entries.filter { $0.pitcher == line.player }
            #expect(mine.reduce(0) { $0 + $1.pitches } == line.stats.pitches, "pitches for \(line.name)")
            #expect(mine.reduce(0) { $0 + $1.strikes } == line.stats.strikes, "strikes for \(line.name)")
            #expect(mine.reduce(0) { $0 + $1.outs.count } == line.stats.outsRecorded, "outs for \(line.name)")
            let faced = log.entries.compactMap(\.plateAppearance).filter { $0.pitcher == line.player }
            #expect(faced.count == line.stats.battersFaced, "batters faced for \(line.name)")
            #expect(faced.filter { [.single, .double, .triple, .homeRun].contains($0.outcome) }.count == line.stats.hits)
            #expect(faced.filter { [.walk, .intentionalWalk].contains($0.outcome) }.count == line.stats.walks)
            #expect(faced.filter { $0.outcome == .strikeout }.count == line.stats.strikeouts)
            let charged = log.entries.flatMap(\.runs).filter { $0.responsiblePitcher == line.player }
            #expect(charged.count == line.stats.runs, "runs charged to \(line.name)")
        }
        // The final situation's tallies agree too.
        for tally in SampleGame.finalSituation.pitchers {
            let line = (box.away.pitching + box.home.pitching).first { $0.player == tally.pitcher }
            #expect(line?.stats.pitches == tally.pitches)
            #expect(line?.stats.strikes == tally.strikes)
            #expect(line?.stats.battersFaced == tally.battersFaced)
        }
    }

    @Test("Every batter's plate appearances, hits, runs and runs batted in match the box score")
    func batting() {
        let appearances = log.entries.compactMap(\.plateAppearance)
        for line in box.away.batting + box.home.batting {
            let mine = appearances.filter { $0.batter == line.player }
            #expect(mine.count == line.stats.plateAppearances, "plate appearances for \(line.name)")
            #expect(mine.filter { [.single, .double, .triple, .homeRun].contains($0.outcome) }.count == line.stats.hits,
                    "hits for \(line.name)")
            #expect(mine.reduce(0) { $0 + $1.rbi } == line.stats.runsBattedIn, "runs batted in for \(line.name)")
            #expect(log.entries.flatMap(\.runs).filter { $0.creditedTo == line.player }.count == line.stats.runs,
                    "runs for \(line.name)")
        }
        #expect(box.away.battingTotals.hits == box.away.hits)
        #expect(box.home.battingTotals.hits == box.home.hits)
    }

    @Test("Putouts, assists and errors tied to players match the box score")
    func fielding() {
        let outs = log.entries.flatMap(\.outs)
        let errors = log.entries.flatMap(\.errors)
        for line in box.away.fielding + box.home.fielding {
            #expect(outs.filter { $0.putout == line.player }.count == line.stats.putouts, "putouts for \(line.name)")
            #expect(outs.reduce(0) { $0 + $1.assists.filter { $0 == line.player }.count } == line.stats.assists,
                    "assists for \(line.name)")
            #expect(errors.filter { $0.player == line.player }.count == line.stats.errors, "errors for \(line.name)")
        }
    }

    @Test("Runners left on base add up for each team")
    func leftOnBase() {
        for (side, half) in [(TeamSide.away, HalfInning.top), (.home, .bottom)] {
            let left = log.entries.filter { $0.half == half && $0.endsHalfInning }.reduce(0) { $0 + $1.after.runners.count }
            #expect(left == box[side].leftOnBase)
        }
    }

    @Test("Substitutes are in the final batting orders under the players they replaced")
    func finalOrders() {
        #expect(log.awayOrder.slots[8].players == ["c9", "c10", "c12"])
        #expect(log.homeOrder.slots[8].players == ["m9", "m12"])
        #expect(log.homeOrder.count == 10)
    }

    @Test("Season totals list all twelve of our players, one with no at-bats")
    func season() {
        #expect(SampleSeason.totals.batting.count == 12)
        let nash = SampleSeason.totals.batting.first { $0.player == "m11" }
        #expect(nash?.stats.atBats == 0 && nash?.stats.battingAverage == nil)
    }

    @Test("Sample situations cover the plan's list")
    func situations() {
        #expect(SampleSituations.all.count >= 8)
        #expect(SampleSituations.basesLoadedTwoOutsFullCount.situation.runners.count == 3)
        #expect(SampleSituations.tenthHitterUpAfterAddingOne.situation.batter == "m10")
        #expect(SampleSituations.tenthHitterUpAfterAddingOne.situation.onDeck == "m11")
        #expect(SampleSituations.extraInnings.situation.inning == 10)
        #expect(SampleSituations.theirHitterKnownByNumber.player(SampleSituations.theirHitterKnownByNumber.situation.batter)?.displayName == "#5")
    }

    @Test("The canned rules engine suggests the obvious runner moves")
    func cannedEngine() {
        let engine = SampleRulesEngine()
        let situation = SampleSituations.runnerOnFirstOneOut.situation
        let single = engine.suggestRunners(for: PlayDraft(batterResult: .single), in: situation)
        #expect(single.runners.contains { $0.runner == "c3" && $0.to == .second })
        #expect(single.runners.contains { $0.runner == "c4" && $0.to == .first })
        let doublePlay = PlayDraft(batterResult: .out, fielders: [.thirdBase, .secondBase, .firstBase], multiOut: .doublePlay)
        let preview = engine.preview(doublePlay, in: situation)
        #expect(preview.outsOnPlay == 2 && preview.endsHalfInning && preview.notation == "5-4-3 DP")
        #expect(engine.replay(SampleGame.game).situation == SampleGame.finalSituation)
    }
}
