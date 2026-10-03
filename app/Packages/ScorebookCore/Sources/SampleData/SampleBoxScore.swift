// The sample game's box score, worked out by hand from the account in SampleGame.swift.
// The stats builder's box score for the sample game must match this exactly.
//
// Cardinals 3, Mudcats 5 (five innings, time limit).
//
//                1 2 3 4 5   R H E
//     Cardinals  0 1 1 1 0   3 7 1
//     Mudcats    2 0 1 1 1   5 9 1

import Foundation
import Model

extension SampleGame {
    /// The finished box score for the sample game.
    public static let boxScore = BoxScore(
        gameID: id,
        date: SampleSetups.gameDay,
        away: TeamBoxScore(
            side: .away, teamID: "cardinals", name: "Cardinals",
            batting: [
                line("c1", "Luis Ortiz", "1", 0, [.cf], BattingCounts(plateAppearances: 3, atBats: 3, runs: 1, hits: 2, triples: 1)),
                line("c2", "Danny Ruiz", "2", 1, [.ss], BattingCounts(plateAppearances: 3, atBats: 2, hits: 1, doubles: 1, runsBattedIn: 1, sacrificeFlies: 1)),
                line("c3", "Marcus Hale", "24", 2, [.firstBase], BattingCounts(plateAppearances: 3, atBats: 3, hits: 1)),
                line("c4", "Tommy Diaz", "7", 3, [.lf], BattingCounts(plateAppearances: 3, atBats: 2, runs: 1, hits: 1, homeRuns: 1, runsBattedIn: 1, walks: 1)),
                line("c5", "Sam Kim", "5", 4, [.thirdBase], BattingCounts(plateAppearances: 3, atBats: 2, runs: 1, hits: 1, walks: 1, strikeouts: 1)),
                line("c6", "Eddie Park", "11", 5, [.rf], BattingCounts(plateAppearances: 3, atBats: 3, stolenBases: 1)),
                line("c7", "Joe Varga", "8", 6, [.c], BattingCounts(plateAppearances: 2, atBats: 1, walks: 1)),
                line("c8", "Nate Bell", "4", 7, [.secondBase], BattingCounts(plateAppearances: 2, atBats: 2, hits: 1, runsBattedIn: 1)),
                line("c9", "Ray Collins", "31", 8, [.p], BattingCounts(plateAppearances: 1, atBats: 1, strikeouts: 1)),
                line("c10", "Kyle Moss", "15", 8, [.ph], BattingCounts(plateAppearances: 1, atBats: 1), sub: true),
                line("c12", "Gus Reyes", "40", 8, [.p], BattingCounts(), sub: true),
            ],
            pitching: [
                PitchingLine(player: "c9", name: "Ray Collins", number: "31", stats: PitchingCounts(
                    outsRecorded: 9, battersFaced: 15, hits: 6, runs: 3, walks: 1, strikeouts: 2, homeRuns: 1, pitches: 47, strikes: 30)),
                PitchingLine(player: "c12", name: "Gus Reyes", number: "40", stats: PitchingCounts(
                    outsRecorded: 6, battersFaced: 9, hits: 3, runs: 2, hitBatters: 1, pitches: 23, strikes: 15)),
            ],
            fielding: [
                field("c1", "Luis Ortiz", FieldingCounts(putouts: 1)),
                field("c2", "Danny Ruiz", FieldingCounts(putouts: 2, assists: 3)),
                field("c3", "Marcus Hale", FieldingCounts(putouts: 6)),
                field("c4", "Tommy Diaz", FieldingCounts(putouts: 2)),
                field("c5", "Sam Kim", FieldingCounts(assists: 1, errors: 1)),
                field("c6", "Eddie Park", FieldingCounts(putouts: 1)),
                field("c7", "Joe Varga", FieldingCounts(putouts: 2, assists: 1)),
                field("c8", "Nate Bell", FieldingCounts(putouts: 1, assists: 3)),
                field("c9", "Ray Collins", FieldingCounts(assists: 1)),
                field("c12", "Gus Reyes", FieldingCounts()),
            ],
            runs: 3, hits: 7, errors: 1, leftOnBase: 6
        ),
        home: TeamBoxScore(
            side: .home, teamID: "mudcats", name: "Mudcats",
            batting: [
                line("m1", "Alex Moreno", "3", 0, [.secondBase], BattingCounts(plateAppearances: 3, atBats: 2, runs: 1, hits: 1, runsBattedIn: 1, walks: 1)),
                line("m2", "Chris Tate", "6", 1, [.ss], BattingCounts(plateAppearances: 3, atBats: 2, runs: 1, hits: 1, homeRuns: 1, runsBattedIn: 1, sacrificeBunts: 1)),
                line("m3", "Jordan Webb", "22", 2, [.cf], BattingCounts(plateAppearances: 3, atBats: 3, runs: 1, hits: 1, doubles: 1, runsBattedIn: 1, strikeouts: 1)),
                line("m4", "Pat Quinn", "33", 3, [.firstBase], BattingCounts(plateAppearances: 3, atBats: 3, hits: 1)),
                // Ran for Quinn, a designated non-runner, and was caught stealing.
                line("m11", "Robin Nash", "27", 3, [.pr], BattingCounts(caughtStealing: 1), sub: true),
                line("m5", "Riley Shaw", "12", 4, [.thirdBase], BattingCounts(plateAppearances: 2, atBats: 2, hits: 1, runsBattedIn: 1)),
                line("m6", "Casey Ford", "9", 5, [.lf], BattingCounts(plateAppearances: 2, atBats: 1, runs: 1, strikeouts: 1, hitByPitch: 1)),
                line("m7", "Drew Lang", "17", 6, [.rf], BattingCounts(plateAppearances: 2, atBats: 2, hits: 1)),
                line("m8", "Morgan Fisk", "10", 7, [.c], BattingCounts(plateAppearances: 2, atBats: 1, runsBattedIn: 1, sacrificeFlies: 1)),
                line("m9", "Sky Barros", "21", 8, [.p], BattingCounts(plateAppearances: 2, atBats: 2, hits: 1)),
                line("m12", "Taylor Voss", "44", 8, [.p], BattingCounts(), sub: true),
                line("m10", "Jamie Cole", "14", 9, [.eh], BattingCounts(plateAppearances: 2, atBats: 2, runs: 1, hits: 2, doubles: 1, stolenBases: 1)),
            ],
            pitching: [
                PitchingLine(player: "m9", name: "Sky Barros", number: "21", stats: PitchingCounts(
                    outsRecorded: 12, battersFaced: 19, hits: 6, runs: 3, walks: 2, strikeouts: 1, homeRuns: 1, pitches: 57, strikes: 35)),
                PitchingLine(player: "m12", name: "Taylor Voss", number: "44", stats: PitchingCounts(
                    outsRecorded: 3, battersFaced: 5, hits: 1, walks: 1, strikeouts: 1, pitches: 13, strikes: 9)),
            ],
            fielding: [
                field("m1", "Alex Moreno", FieldingCounts(putouts: 2, assists: 5)),
                field("m2", "Chris Tate", FieldingCounts(putouts: 3, assists: 1, errors: 1)),
                field("m3", "Jordan Webb", FieldingCounts(putouts: 2)),
                field("m4", "Pat Quinn", FieldingCounts(putouts: 5)),
                field("m5", "Riley Shaw", FieldingCounts()),
                field("m6", "Casey Ford", FieldingCounts()),
                field("m7", "Drew Lang", FieldingCounts(putouts: 1)),
                field("m8", "Morgan Fisk", FieldingCounts(putouts: 2)),
                field("m9", "Sky Barros", FieldingCounts()),
                field("m12", "Taylor Voss", FieldingCounts()),
            ],
            runs: 5, hits: 9, errors: 1, leftOnBase: 4
        ),
        lineScore: LineScore(away: [0, 1, 1, 1, 0], home: [2, 0, 1, 1, 1]),
        notes: BoxScoreNotes(
            errors: [tally("c5", "Sam Kim", .away), tally("m2", "Chris Tate", .home)],
            doubles: [tally("c2", "Danny Ruiz", .away), tally("m3", "Jordan Webb", .home), tally("m10", "Jamie Cole", .home)],
            triples: [tally("c1", "Luis Ortiz", .away)],
            homeRuns: [tally("c4", "Tommy Diaz", .away), tally("m2", "Chris Tate", .home)],
            runsBattedIn: [
                tally("c2", "Danny Ruiz", .away), tally("c4", "Tommy Diaz", .away), tally("c8", "Nate Bell", .away),
                tally("m1", "Alex Moreno", .home), tally("m2", "Chris Tate", .home), tally("m3", "Jordan Webb", .home),
                tally("m5", "Riley Shaw", .home), tally("m8", "Morgan Fisk", .home),
            ],
            stolenBases: [tally("c6", "Eddie Park", .away), tally("m10", "Jamie Cole", .home)],
            caughtStealing: [tally("m11", "Robin Nash", .home)],
            sacrificeFlies: [tally("c2", "Danny Ruiz", .away), tally("m8", "Morgan Fisk", .home)],
            sacrificeBunts: [tally("m2", "Chris Tate", .home)],
            hitByPitch: [tally("m6", "Casey Ford", .home)],
            doublePlays: [TeamTally(team: .away, name: "Cardinals", count: 2), TeamTally(team: .home, name: "Mudcats", count: 2)],
            triplePlays: [],
            leftOnBase: [TeamTally(team: .away, name: "Cardinals", count: 6), TeamTally(team: .home, name: "Mudcats", count: 4)]
        ),
        isFinal: true
    )

    /// A batting line. `spot` counts from 0 for the leadoff spot.
    static func line(_ id: PlayerID, _ name: String, _ number: String, _ spot: Int, _ positions: [BoxPosition],
                             _ stats: BattingCounts, sub: Bool = false) -> BattingLine {
        BattingLine(player: id, name: name, number: number, batterIndex: spot, positions: positions, isSubstitute: sub, stats: stats)
    }

    /// A fielding line.
    static func field(_ id: PlayerID, _ name: String, _ stats: FieldingCounts) -> FieldingLine {
        FieldingLine(player: id, name: name, stats: stats)
    }

    /// One player's entry in a box score note, once.
    static func tally(_ id: PlayerID, _ name: String, _ team: TeamSide, _ count: Int = 1) -> PlayerTally {
        PlayerTally(player: id, name: name, team: team, count: count)
    }
}
