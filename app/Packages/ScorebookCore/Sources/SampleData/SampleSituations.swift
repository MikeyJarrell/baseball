// Made-up game situations for building and previewing screens: who is up, the count, the
// outs, the runners. Each comes with the setup it belongs to, so a screen can look up
// names, numbers and songs.

import Foundation
import Model

/// One sample situation with a title for preview lists.
public struct SampleSituation: Identifiable, Sendable {
    public var id: String { title }
    /// What the situation is, in a few words: "Bases loaded, two outs, full count".
    public var title: String
    /// The game it belongs to, for names, numbers and songs.
    public var setup: GameSetup
    public var situation: Situation

    /// A player in this situation's game.
    public func player(_ id: PlayerID?) -> Player? {
        id.flatMap(setup.player)
    }
}

public enum SampleSituations {
    // MARK: The situations the plan asks for

    /// Top of the first, nobody on, nothing happened yet. Ortiz leads off against Barros.
    public static let topOfFirst = SampleSituation(
        title: "Top of the 1st, nobody on",
        setup: SampleSetups.cardinalsAtMudcats,
        situation: Situation(startOf: SampleSetups.cardinalsAtMudcats)
    )

    /// Top of the 3rd, runner on first, one out, 2-1 count on Diaz.
    public static let runnerOnFirstOneOut = make(
        "Runner on first, one out, 2-1 count",
        inning: 3, half: .top, outs: 1, count: Count(balls: 2, strikes: 1), score: Score(away: 1, home: 2),
        runners: [BaseRunner(runner: "c3", base: .first, responsiblePitcher: "m9")],
        awayUp: 3, homeUp: 0,
        pitchers: [tally("m9", .home, 32, 20, 11), tally("c9", .away, 35, 23, 11)]
    )

    /// Bottom of the 4th, bases loaded, two outs, full count on Quinn (who has a walk-up song).
    public static let basesLoadedTwoOutsFullCount = make(
        "Bases loaded, two outs, full count",
        inning: 4, half: .bottom, outs: 2, count: Count(balls: 3, strikes: 2), score: Score(away: 3, home: 2),
        runners: [
            BaseRunner(runner: "m1", base: .third, responsiblePitcher: "c9"),
            BaseRunner(runner: "m2", base: .second, responsiblePitcher: "c9"),
            BaseRunner(runner: "m3", base: .first, responsiblePitcher: "c9"),
        ],
        awayUp: 2, homeUp: 3,
        pitchers: [tally("m9", .home, 55, 34, 18), tally("c9", .away, 61, 38, 19)]
    )

    /// Top of the 6th, runners on second and third, nobody out, Park up.
    public static let secondAndThirdNobodyOut = make(
        "Runners on second and third, nobody out",
        inning: 6, half: .top, outs: 0, score: Score(away: 2, home: 4),
        runners: [
            BaseRunner(runner: "c4", base: .third, responsiblePitcher: "m9"),
            BaseRunner(runner: "c5", base: .second, responsiblePitcher: "m9"),
        ],
        awayUp: 5, homeUp: 6,
        pitchers: [tally("m9", .home, 81, 50, 25), tally("c9", .away, 74, 46, 22)]
    )

    /// Bottom of the 2nd. Our order started with ten and has been extended to eleven
    /// (Robin Nash added at the bottom); Jamie Cole, the tenth hitter, is up and Nash is on deck.
    public static let tenthHitterUpAfterAddingOne: SampleSituation = {
        var s = make(
            "Our tenth hitter up, lineup extended to eleven",
            inning: 2, half: .bottom, outs: 1, score: Score(away: 1, home: 2),
            awayUp: 0, homeUp: 9,
            pitchers: [tally("m9", .home, 29, 17, 9), tally("c9", .away, 24, 15, 8)]
        )
        s.situation.home.battingOrder.slots.append(BattingSlot(players: ["m11"]))
        return s
    }()

    /// Top of the 5th: Voss has just come in to pitch and has not thrown a pitch.
    public static let newPitcherJustIn: SampleSituation = {
        var s = make(
            "New pitcher just in",
            inning: 5, half: .top, outs: 0, score: Score(away: 3, home: 4),
            awayUp: 1, homeUp: 4,
            pitchers: [tally("m9", .home, 57, 35, 19), tally("m12", .home, 0, 0, 0), tally("c9", .away, 47, 30, 15), tally("c12", .away, 12, 7, 4)]
        )
        // Voss replaces Barros for the Mudcats; Reyes already replaced Collins (after Moss
        // pinch-hit) for the Cardinals.
        s.situation.home.battingOrder.slots[8] = BattingSlot(players: ["m9", "m12"], position: .pitcher)
        s.situation.home.fielders = replacing(s.situation.home.fielders, at: .pitcher, with: "m12")
        s.situation.away.battingOrder.slots[8] = BattingSlot(players: ["c9", "c10", "c12"], position: .pitcher)
        s.situation.away.fielders = replacing(s.situation.away.fielders, at: .pitcher, with: "c12")
        s.situation.lastPlayNotation = "6-4-3 DP"
        return s
    }()

    /// Top of the 9th, the last scheduled inning, home team ahead 5-3 with two outs.
    /// One more out and the game is complete without the Mudcats batting.
    public static let lastInningHomeAhead = make(
        "Top of the 9th, home team ahead",
        inning: 9, half: .top, outs: 2, count: Count(balls: 1, strikes: 1), score: Score(away: 3, home: 5),
        awayUp: 6, homeUp: 2,
        pitchers: [tally("m9", .home, 112, 71, 33), tally("c9", .away, 98, 60, 30)]
    )

    /// Top of the 10th, tied 4-4: extra innings, with both relievers pitching.
    public static let extraInnings: SampleSituation = {
        var s = make(
            "Extra innings, top of the 10th",
            inning: 10, half: .top, outs: 0, score: Score(away: 4, home: 4),
            awayUp: 2, homeUp: 7,
            pitchers: [tally("m9", .home, 98, 61, 30), tally("m12", .home, 18, 12, 5),
                       tally("c9", .away, 90, 55, 29), tally("c12", .away, 30, 19, 9)]
        )
        s.situation.home.battingOrder.slots[8] = BattingSlot(players: ["m9", "m12"], position: .pitcher)
        s.situation.home.fielders = replacing(s.situation.home.fielders, at: .pitcher, with: "m12")
        s.situation.away.battingOrder.slots[8] = BattingSlot(players: ["c9", "c12"], position: .pitcher)
        s.situation.away.fielders = replacing(s.situation.away.fielders, at: .pitcher, with: "c12")
        return s
    }()

    // MARK: More situations screens need

    /// The changeover after the top of the 3rd: three outs made, nobody has pitched to the
    /// Mudcats yet. The between-innings music button shows.
    public static let betweenHalfInnings: SampleSituation = {
        var s = make(
            "Between half-innings, middle of the 3rd",
            inning: 3, half: .bottom, outs: 0, score: Score(away: 2, home: 2),
            awayUp: 4, homeUp: 1,
            pitchers: [tally("m9", .home, 41, 25, 14), tally("c9", .away, 35, 23, 11)]
        )
        s.situation.isBetweenHalfInnings = true
        s.situation.lastPlayNotation = "L4-3 DP"
        return s
    }()

    /// Bottom of the 1st: Pat Quinn, a designated non-runner, has just singled. The app
    /// asks who will run for them.
    public static let designatedNonRunnerOnFirst: SampleSituation = {
        var s = make(
            "Designated non-runner on first",
            inning: 1, half: .bottom, outs: 1,
            runners: [BaseRunner(runner: "m4", base: .first, responsiblePitcher: "c9")],
            awayUp: 3, homeUp: 4,
            pitchers: [tally("m9", .home, 10, 6, 3), tally("c9", .away, 9, 6, 4)]
        )
        s.situation.runnerNeededFor = "m4"
        s.situation.lastPlayNotation = "1B 9"
        return s
    }()

    /// Bottom of the 3rd, Morgan Fisk up: one of our hitters with no walk-up song.
    public static let ourHitterWithoutSong = make(
        "Our hitter with no song",
        inning: 3, half: .bottom, outs: 1, count: Count(balls: 0, strikes: 1), score: Score(away: 2, home: 3),
        awayUp: 4, homeUp: 7,
        pitchers: [tally("m9", .home, 41, 25, 14), tally("c9", .away, 44, 28, 14)]
    )

    /// Bottom of the 1st at the Bombers: their hitter known only as number 2.
    public static let theirHitterKnownByNumber: SampleSituation = {
        let setup = SampleSetups.mudcatsAtBombers
        var situation = Situation(startOf: setup)
        situation.half = .bottom
        situation.outs = 1
        situation.away.nextBatterIndex = 4
        situation.home.nextBatterIndex = 1
        situation.pitchers = [tally("m9", .away, 6, 4, 1), tally("b11", .home, 14, 8, 4)]
        situation.defenseCheckDue = false
        return SampleSituation(title: "Their hitter known only by number", setup: setup, situation: situation)
    }()

    /// Bottom of the 3rd just after Webb struck out swinging: the dropped third strike button shows.
    public static let rightAfterStrikeThree: SampleSituation = {
        var s = make(
            "Right after strike three",
            inning: 3, half: .bottom, outs: 1, score: Score(away: 2, home: 3),
            awayUp: 4, homeUp: 3,
            pitchers: [tally("m9", .home, 41, 25, 14), tally("c9", .away, 41, 26, 13)]
        )
        s.situation.droppedThirdStrikePossible = true
        s.situation.lastPlayNotation = "K"
        return s
    }()

    /// Every sample situation, for preview lists.
    public static let all: [SampleSituation] = [
        topOfFirst, runnerOnFirstOneOut, basesLoadedTwoOutsFullCount, secondAndThirdNobodyOut,
        tenthHitterUpAfterAddingOne, newPitcherJustIn, lastInningHomeAhead, extraInnings,
        betweenHalfInnings, designatedNonRunnerOnFirst, ourHitterWithoutSong, theirHitterKnownByNumber,
        rightAfterStrikeThree,
    ]

    // MARK: Building blocks

    /// A situation in the sample game (Cardinals at Mudcats) with the usual lineups and fielders.
    /// `awayUp` and `homeUp` are the spots due up for each team, counting from 0.
    static func make(
        _ title: String,
        setup: GameSetup = SampleSetups.cardinalsAtMudcats,
        inning: Int, half: HalfInning, outs: Int, count: Count = Count(), score: Score = Score(),
        runners: [BaseRunner] = [], awayUp: Int, homeUp: Int, pitchers: [PitcherTally]
    ) -> SampleSituation {
        var situation = Situation(startOf: setup)
        situation.inning = inning
        situation.half = half
        situation.outs = outs
        situation.count = count
        situation.score = score
        situation.runners = runners
        situation.away.nextBatterIndex = awayUp
        situation.home.nextBatterIndex = homeUp
        situation.pitchers = pitchers
        situation.defenseCheckDue = false
        situation.gameStartedAt = setup.date.addingTimeInterval(300)
        return SampleSituation(title: title, setup: setup, situation: situation)
    }

    /// A pitcher's tally so far.
    static func tally(_ pitcher: PlayerID, _ team: TeamSide, _ pitches: Int, _ strikes: Int, _ faced: Int) -> PitcherTally {
        PitcherTally(pitcher: pitcher, team: team, pitches: pitches, strikes: strikes, battersFaced: faced)
    }

    /// The fielders with someone new at one position.
    static func replacing(_ fielders: [FielderAssignment], at position: Position, with player: PlayerID) -> [FielderAssignment] {
        fielders.map { $0.position == position ? FielderAssignment(position: position, player: player) : $0 }
    }
}

/// Earlier-today plate appearances for a few batters, for the batting screen's history line.
public enum SamplePlateAppearances {
    /// Jordan Webb: grounded out short to first, walked, singled to left.
    public static let webb: [PlateAppearanceSummary] = [
        PlateAppearanceSummary(inning: 1, notation: "6-3", outcome: .out),
        PlateAppearanceSummary(inning: 3, notation: "BB", outcome: .walk),
        PlateAppearanceSummary(inning: 5, notation: "1B 7", outcome: .single),
    ]

    /// Pat Quinn: struck out looking, then a two-run double to right.
    public static let quinn: [PlateAppearanceSummary] = [
        PlateAppearanceSummary(inning: 1, notation: "ꓘ", outcome: .strikeout),
        PlateAppearanceSummary(inning: 4, notation: "2B 9", outcome: .double, rbi: 2),
    ]

    /// Luis Ortiz: reached on an error by the shortstop, flied out to center, homered to left.
    public static let ortiz: [PlateAppearanceSummary] = [
        PlateAppearanceSummary(inning: 1, notation: "E6", outcome: .reachedOnError),
        PlateAppearanceSummary(inning: 3, notation: "F8", outcome: .out),
        PlateAppearanceSummary(inning: 6, notation: "HR 7", outcome: .homeRun, rbi: 1),
    ]

    /// Nothing yet: a batter's first time up.
    public static let none: [PlateAppearanceSummary] = []

    /// The histories above, by player.
    public static let byPlayer: [PlayerID: [PlateAppearanceSummary]] = ["m3": webb, "m4": quinn, "c1": ortiz]
}
