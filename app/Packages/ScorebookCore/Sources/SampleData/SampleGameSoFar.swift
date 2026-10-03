// The sample game part way through, and every batter's plate appearances, for the game
// overview and the batting screen's history line. Worked out by hand from SampleGame.swift.
//
// Through three innings: Mudcats 2, Diamond Dogs 3.
//
//                1 2 3   R H E
//     Mudcats  0 1 1   2 4 0
//     Diamond Dogs    2 0 1   3 6 1

import Foundation
import Model

extension SampleGame {
    /// The box score at the end of the third inning.
    public static let boxScoreThroughThree = BoxScore(
        gameID: id,
        date: SampleSetups.gameDay,
        away: TeamBoxScore(
            side: .away, teamID: "mudcats", name: "Mudcats",
            batting: [
                line("m1", "Luis Ortiz", "1", 0, [.cf], BattingCounts(plateAppearances: 2, atBats: 2, runs: 1, hits: 2, triples: 1)),
                line("m2", "Danny Ruiz", "2", 1, [.ss], BattingCounts(plateAppearances: 2, atBats: 1, runsBattedIn: 1, sacrificeFlies: 1)),
                line("m3", "Marcus Hale", "24", 2, [.firstBase], BattingCounts(plateAppearances: 2, atBats: 2, hits: 1)),
                line("m4", "Tommy Diaz", "7", 3, [.lf], BattingCounts(plateAppearances: 2, atBats: 2, runs: 1, hits: 1, homeRuns: 1, runsBattedIn: 1)),
                line("m5", "Sam Kim", "5", 4, [.thirdBase], BattingCounts(plateAppearances: 1, walks: 1)),
                line("m6", "Eddie Park", "11", 5, [.rf], BattingCounts(plateAppearances: 1, atBats: 1, stolenBases: 1)),
                line("m7", "Joe Varga", "8", 6, [.c], BattingCounts(plateAppearances: 1, atBats: 1)),
                line("m8", "Nate Bell", "4", 7, [.secondBase], BattingCounts(plateAppearances: 1, atBats: 1)),
                line("m9", "Ray Collins", "31", 8, [.p], BattingCounts(plateAppearances: 1, atBats: 1, strikeouts: 1)),
            ],
            pitching: [
                PitchingLine(player: "m9", name: "Ray Collins", number: "31", stats: PitchingCounts(
                    outsRecorded: 9, battersFaced: 15, hits: 6, runs: 3, walks: 1, strikeouts: 2, homeRuns: 1, pitches: 47, strikes: 30)),
            ],
            fielding: [
                field("m1", "Luis Ortiz", FieldingCounts()),
                field("m2", "Danny Ruiz", FieldingCounts(putouts: 1, assists: 1)),
                field("m3", "Marcus Hale", FieldingCounts(putouts: 4)),
                field("m4", "Tommy Diaz", FieldingCounts(putouts: 1)),
                field("m5", "Sam Kim", FieldingCounts(assists: 1)),
                field("m6", "Eddie Park", FieldingCounts(putouts: 1)),
                field("m7", "Joe Varga", FieldingCounts(putouts: 2, assists: 1)),
                field("m8", "Nate Bell", FieldingCounts(assists: 1)),
                field("m9", "Ray Collins", FieldingCounts(assists: 1)),
            ],
            runs: 2, hits: 4, errors: 0, leftOnBase: 2
        ),
        home: TeamBoxScore(
            side: .home, teamID: "diamond-dogs", name: "Diamond Dogs",
            batting: [
                line("d1", "Alex Moreno", "3", 0, [.secondBase], BattingCounts(plateAppearances: 2, atBats: 1, runs: 1, walks: 1)),
                line("d2", "Chris Tate", "6", 1, [.ss], BattingCounts(plateAppearances: 2, atBats: 1, runs: 1, hits: 1, homeRuns: 1, runsBattedIn: 1, sacrificeBunts: 1)),
                line("d3", "Jordan Webb", "22", 2, [.cf], BattingCounts(plateAppearances: 2, atBats: 2, runs: 1, hits: 1, doubles: 1, runsBattedIn: 1, strikeouts: 1, caughtStealing: 1)),
                line("d4", "Pat Quinn", "33", 3, [.firstBase], BattingCounts(plateAppearances: 2, atBats: 2, hits: 1)),
                line("d5", "Riley Shaw", "12", 4, [.thirdBase], BattingCounts(plateAppearances: 2, atBats: 2, hits: 1, runsBattedIn: 1)),
                line("d6", "Casey Ford", "9", 5, [.lf], BattingCounts(plateAppearances: 1, atBats: 1, strikeouts: 1)),
                line("d7", "Drew Lang", "17", 6, [.rf], BattingCounts(plateAppearances: 1, atBats: 1)),
                line("d8", "Morgan Fisk", "10", 7, [.c], BattingCounts(plateAppearances: 1, atBats: 1)),
                line("d9", "Sky Barros", "21", 8, [.p], BattingCounts(plateAppearances: 1, atBats: 1, hits: 1)),
                line("d10", "Jamie Cole", "14", 9, [], BattingCounts(plateAppearances: 1, atBats: 1, hits: 1, doubles: 1)),
            ],
            pitching: [
                PitchingLine(player: "d9", name: "Sky Barros", number: "21", stats: PitchingCounts(
                    outsRecorded: 9, battersFaced: 13, hits: 4, runs: 2, walks: 1, strikeouts: 1, homeRuns: 1, pitches: 41, strikes: 25)),
            ],
            fielding: [
                field("d1", "Alex Moreno", FieldingCounts(putouts: 2, assists: 3)),
                field("d2", "Chris Tate", FieldingCounts(putouts: 2, assists: 1, errors: 1)),
                field("d3", "Jordan Webb", FieldingCounts(putouts: 2)),
                field("d4", "Pat Quinn", FieldingCounts(putouts: 2)),
                field("d5", "Riley Shaw", FieldingCounts()),
                field("d6", "Casey Ford", FieldingCounts()),
                field("d7", "Drew Lang", FieldingCounts()),
                field("d8", "Morgan Fisk", FieldingCounts(putouts: 1)),
                field("d9", "Sky Barros", FieldingCounts()),
            ],
            runs: 3, hits: 6, errors: 1, leftOnBase: 3
        ),
        lineScore: LineScore(away: [0, 1, 1], home: [2, 0, 1]),
        notes: BoxScoreNotes(
            errors: [tally("d2", "Chris Tate", .home)],
            doubles: [tally("d3", "Jordan Webb", .home), tally("d10", "Jamie Cole", .home)],
            triples: [tally("m1", "Luis Ortiz", .away)],
            homeRuns: [tally("m4", "Tommy Diaz", .away), tally("d2", "Chris Tate", .home)],
            runsBattedIn: [
                tally("m2", "Danny Ruiz", .away), tally("m4", "Tommy Diaz", .away),
                tally("d2", "Chris Tate", .home), tally("d3", "Jordan Webb", .home), tally("d5", "Riley Shaw", .home),
            ],
            stolenBases: [tally("m6", "Eddie Park", .away)],
            caughtStealing: [tally("d3", "Jordan Webb", .home)],
            sacrificeFlies: [tally("m2", "Danny Ruiz", .away)],
            sacrificeBunts: [tally("d2", "Chris Tate", .home)],
            hitByPitch: [],
            doublePlays: [TeamTally(team: .home, name: "Diamond Dogs", count: 2)],
            triplePlays: [],
            leftOnBase: [TeamTally(team: .away, name: "Mudcats", count: 2), TeamTally(team: .home, name: "Diamond Dogs", count: 3)]
        ),
        isFinal: false
    )

    /// Every batter's plate appearances in the sample game, oldest first, in scorebook notation.
    public static let plateAppearances: [PlayerID: [PlateAppearanceSummary]] = [
        "m1": [pa(1, "1B 7", .single), pa(3, "3B 9", .triple), pa(4, "4-3", .out)],
        "m2": [pa(1, "6-4-3 DP", .out), pa(3, "SF 8", .sacrificeFly, rbi: 1), pa(5, "2B 7", .double)],
        "m3": [pa(1, "F8", .out), pa(3, "1B 9", .single), pa(5, "4-3", .out)],
        "m4": [pa(2, "HR 7", .homeRun, rbi: 1), pa(3, "L4-3 DP", .out), pa(5, "IBB", .intentionalWalk)],
        "m5": [pa(2, "BB", .walk), pa(4, "1B 8", .single), pa(5, "K", .strikeout)],
        "m6": [pa(2, "FC 4-6", .fieldersChoice), pa(4, "3U", .out), pa(5, "F9", .out)],
        "m7": [pa(2, "L6", .out), pa(4, "BB", .walk)],
        "m8": [pa(2, "E6", .reachedOnError), pa(4, "1B 7", .single, rbi: 1)],
        "m9": [pa(2, "K", .strikeout)],
        "m10": [pa(4, "P6", .out)],
        "d1": [pa(1, "BB", .walk), pa(2, "6-3", .out), pa(5, "1B 9", .single, rbi: 1)],
        "d2": [pa(1, "SH 1-3", .sacrificeBunt), pa(3, "HR 9", .homeRun, rbi: 1), pa(5, "F8", .out)],
        "d3": [pa(1, "2B 9", .double, rbi: 1), pa(3, "K", .strikeout), pa(5, "E5", .reachedOnError)],
        "d4": [pa(1, "4-3", .out), pa(3, "1B 7", .single), pa(5, "4-6-3 DP", .out)],
        "d5": [pa(1, "1B 8", .single, rbi: 1), pa(3, "F9", .out)],
        "d6": [pa(1, "K", .strikeout), pa(4, "HBP", .hitByPitch)],
        "d7": [pa(2, "5-3", .out), pa(4, "1B 9", .single)],
        "d8": [pa(2, "F7", .out), pa(4, "SF 7", .sacrificeFly, rbi: 1)],
        "d9": [pa(2, "1B 9", .single), pa(4, "6-4-3 DP", .out)],
        "d10": [pa(2, "2B 7", .double), pa(5, "1B 8", .single)],
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
