// The sample game part way through, and every batter's plate appearances, for the game
// overview and the batting screen's history line. Worked out by hand from SampleGame.swift.
//
// Through three innings: Cardinals 2, Mudcats 3.
//
//                1 2 3   R H E
//     Cardinals  0 1 1   2 4 0
//     Mudcats    2 0 1   3 6 1

import Foundation
import Model

extension SampleGame {
    /// The box score at the end of the third inning.
    public static let boxScoreThroughThree = BoxScore(
        gameID: id,
        date: SampleSetups.gameDay,
        away: TeamBoxScore(
            side: .away, teamID: "cardinals", name: "Cardinals",
            batting: [
                line("c1", "Luis Ortiz", "1", 0, [.cf], BattingCounts(plateAppearances: 2, atBats: 2, runs: 1, hits: 2, triples: 1)),
                line("c2", "Danny Ruiz", "2", 1, [.ss], BattingCounts(plateAppearances: 2, atBats: 1, runsBattedIn: 1, sacrificeFlies: 1)),
                line("c3", "Marcus Hale", "24", 2, [.firstBase], BattingCounts(plateAppearances: 2, atBats: 2, hits: 1)),
                line("c4", "Tommy Diaz", "7", 3, [.lf], BattingCounts(plateAppearances: 2, atBats: 2, runs: 1, hits: 1, homeRuns: 1, runsBattedIn: 1)),
                line("c5", "Sam Kim", "5", 4, [.thirdBase], BattingCounts(plateAppearances: 1, walks: 1)),
                line("c6", "Eddie Park", "11", 5, [.rf], BattingCounts(plateAppearances: 1, atBats: 1, stolenBases: 1)),
                line("c7", "Joe Varga", "8", 6, [.c], BattingCounts(plateAppearances: 1, atBats: 1)),
                line("c8", "Nate Bell", "4", 7, [.secondBase], BattingCounts(plateAppearances: 1, atBats: 1)),
                line("c9", "Ray Collins", "31", 8, [.p], BattingCounts(plateAppearances: 1, atBats: 1, strikeouts: 1)),
            ],
            pitching: [
                PitchingLine(player: "c9", name: "Ray Collins", number: "31", stats: PitchingCounts(
                    outsRecorded: 9, battersFaced: 15, hits: 6, runs: 3, walks: 1, strikeouts: 2, homeRuns: 1, pitches: 47, strikes: 30)),
            ],
            fielding: [
                field("c1", "Luis Ortiz", FieldingCounts()),
                field("c2", "Danny Ruiz", FieldingCounts(putouts: 1, assists: 1)),
                field("c3", "Marcus Hale", FieldingCounts(putouts: 4)),
                field("c4", "Tommy Diaz", FieldingCounts(putouts: 1)),
                field("c5", "Sam Kim", FieldingCounts(assists: 1)),
                field("c6", "Eddie Park", FieldingCounts(putouts: 1)),
                field("c7", "Joe Varga", FieldingCounts(putouts: 2, assists: 1)),
                field("c8", "Nate Bell", FieldingCounts(assists: 1)),
                field("c9", "Ray Collins", FieldingCounts(assists: 1)),
            ],
            runs: 2, hits: 4, errors: 0, leftOnBase: 2
        ),
        home: TeamBoxScore(
            side: .home, teamID: "mudcats", name: "Mudcats",
            batting: [
                line("m1", "Alex Moreno", "3", 0, [.secondBase], BattingCounts(plateAppearances: 2, atBats: 1, runs: 1, walks: 1)),
                line("m2", "Chris Tate", "6", 1, [.ss], BattingCounts(plateAppearances: 2, atBats: 1, runs: 1, hits: 1, homeRuns: 1, runsBattedIn: 1, sacrificeBunts: 1)),
                line("m3", "Jordan Webb", "22", 2, [.cf], BattingCounts(plateAppearances: 2, atBats: 2, runs: 1, hits: 1, doubles: 1, runsBattedIn: 1, strikeouts: 1)),
                line("m4", "Pat Quinn", "33", 3, [.firstBase], BattingCounts(plateAppearances: 2, atBats: 2, hits: 1)),
                line("m11", "Robin Nash", "27", 3, [.pr], BattingCounts(caughtStealing: 1), sub: true),
                line("m5", "Riley Shaw", "12", 4, [.thirdBase], BattingCounts(plateAppearances: 2, atBats: 2, hits: 1, runsBattedIn: 1)),
                line("m6", "Casey Ford", "9", 5, [.lf], BattingCounts(plateAppearances: 1, atBats: 1, strikeouts: 1)),
                line("m7", "Drew Lang", "17", 6, [.rf], BattingCounts(plateAppearances: 1, atBats: 1)),
                line("m8", "Morgan Fisk", "10", 7, [.c], BattingCounts(plateAppearances: 1, atBats: 1)),
                line("m9", "Sky Barros", "21", 8, [.p], BattingCounts(plateAppearances: 1, atBats: 1, hits: 1)),
                line("m10", "Jamie Cole", "14", 9, [.eh], BattingCounts(plateAppearances: 1, atBats: 1, hits: 1, doubles: 1)),
            ],
            pitching: [
                PitchingLine(player: "m9", name: "Sky Barros", number: "21", stats: PitchingCounts(
                    outsRecorded: 9, battersFaced: 13, hits: 4, runs: 2, walks: 1, strikeouts: 1, homeRuns: 1, pitches: 41, strikes: 25)),
            ],
            fielding: [
                field("m1", "Alex Moreno", FieldingCounts(putouts: 2, assists: 3)),
                field("m2", "Chris Tate", FieldingCounts(putouts: 2, assists: 1, errors: 1)),
                field("m3", "Jordan Webb", FieldingCounts(putouts: 2)),
                field("m4", "Pat Quinn", FieldingCounts(putouts: 2)),
                field("m5", "Riley Shaw", FieldingCounts()),
                field("m6", "Casey Ford", FieldingCounts()),
                field("m7", "Drew Lang", FieldingCounts()),
                field("m8", "Morgan Fisk", FieldingCounts(putouts: 1)),
                field("m9", "Sky Barros", FieldingCounts()),
            ],
            runs: 3, hits: 6, errors: 1, leftOnBase: 3
        ),
        lineScore: LineScore(away: [0, 1, 1], home: [2, 0, 1]),
        notes: BoxScoreNotes(
            errors: [tally("m2", "Chris Tate", .home)],
            doubles: [tally("m3", "Jordan Webb", .home), tally("m10", "Jamie Cole", .home)],
            triples: [tally("c1", "Luis Ortiz", .away)],
            homeRuns: [tally("c4", "Tommy Diaz", .away), tally("m2", "Chris Tate", .home)],
            runsBattedIn: [
                tally("c2", "Danny Ruiz", .away), tally("c4", "Tommy Diaz", .away),
                tally("m2", "Chris Tate", .home), tally("m3", "Jordan Webb", .home), tally("m5", "Riley Shaw", .home),
            ],
            stolenBases: [tally("c6", "Eddie Park", .away)],
            caughtStealing: [tally("m11", "Robin Nash", .home)],
            sacrificeFlies: [tally("c2", "Danny Ruiz", .away)],
            sacrificeBunts: [tally("m2", "Chris Tate", .home)],
            hitByPitch: [],
            doublePlays: [TeamTally(team: .home, name: "Mudcats", count: 2)],
            triplePlays: [],
            leftOnBase: [TeamTally(team: .away, name: "Cardinals", count: 2), TeamTally(team: .home, name: "Mudcats", count: 3)]
        ),
        isFinal: false
    )

    /// Every batter's plate appearances in the sample game, oldest first, in scorebook notation.
    public static let plateAppearances: [PlayerID: [PlateAppearanceSummary]] = [
        "c1": [pa(1, "1B 7", .single), pa(3, "3B 9", .triple), pa(4, "4-3", .out)],
        "c2": [pa(1, "6-4-3 DP", .out), pa(3, "SF 8", .sacrificeFly, rbi: 1), pa(5, "2B 7", .double)],
        "c3": [pa(1, "F8", .out), pa(3, "1B 9", .single), pa(5, "4-3", .out)],
        "c4": [pa(2, "HR 7", .homeRun, rbi: 1), pa(3, "L4-3 DP", .out), pa(5, "IBB", .intentionalWalk)],
        "c5": [pa(2, "BB", .walk), pa(4, "1B 8", .single), pa(5, "K", .strikeout)],
        "c6": [pa(2, "FC 4-6", .fieldersChoice), pa(4, "3U", .out), pa(5, "F9", .out)],
        "c7": [pa(2, "L6", .out), pa(4, "BB", .walk)],
        "c8": [pa(2, "E6", .reachedOnError), pa(4, "1B 7", .single, rbi: 1)],
        "c9": [pa(2, "K", .strikeout)],
        "c10": [pa(4, "P6", .out)],
        "m1": [pa(1, "BB", .walk), pa(2, "6-3", .out), pa(5, "1B 9", .single, rbi: 1)],
        "m2": [pa(1, "SH 1-3", .sacrificeBunt), pa(3, "HR 9", .homeRun, rbi: 1), pa(5, "F8", .out)],
        "m3": [pa(1, "2B 9", .double, rbi: 1), pa(3, "K", .strikeout), pa(5, "E5", .reachedOnError)],
        "m4": [pa(1, "4-3", .out), pa(3, "1B 7", .single), pa(5, "4-6-3 DP", .out)],
        "m5": [pa(1, "1B 8", .single, rbi: 1), pa(3, "F9", .out)],
        "m6": [pa(1, "K", .strikeout), pa(4, "HBP", .hitByPitch)],
        "m7": [pa(2, "5-3", .out), pa(4, "1B 9", .single)],
        "m8": [pa(2, "F7", .out), pa(4, "SF 7", .sacrificeFly, rbi: 1)],
        "m9": [pa(2, "1B 9", .single), pa(4, "6-4-3 DP", .out)],
        "m10": [pa(2, "2B 7", .double), pa(5, "1B 8", .single)],
    ]

    /// The same, for the game through three innings.
    public static var plateAppearancesThroughThree: [PlayerID: [PlateAppearanceSummary]] {
        plateAppearances.mapValues { $0.filter { $0.inning <= 3 } }.filter { !$0.value.isEmpty }
    }

    /// One plate appearance.
    static func pa(_ inning: Int, _ notation: String, _ outcome: PlateAppearanceOutcome, rbi: Int = 0) -> PlateAppearanceSummary {
        PlateAppearanceSummary(inning: inning, notation: notation, outcome: outcome, rbi: rbi)
    }
}
