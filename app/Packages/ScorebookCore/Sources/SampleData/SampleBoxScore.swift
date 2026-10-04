// The sample game's box score, worked out by hand from the account in SampleGame.swift.
// The stats builder's box score for the sample game must match this exactly.
//
// Mudcats 3, Diamond Dogs 5 (five innings, time limit).
//
//                1 2 3 4 5   R H E
//     Mudcats  0 1 1 1 0   3 7 1
//     Diamond Dogs    2 0 1 1 1   5 9 1

import Foundation
import Model

extension SampleGame {
    /// The finished box score for the sample game.
    public static let boxScore = BoxScore(
        gameID: id,
        date: SampleSetups.gameDay,
        away: TeamBoxScore(
            side: .away, teamID: "mudcats", name: "Mudcats",
            batting: [
                line("m1", "Luis Ortiz", "1", 0, [.cf], BattingCounts(plateAppearances: 3, atBats: 3, runs: 1, hits: 2, triples: 1)),
                line("m2", "Danny Ruiz", "2", 1, [.ss], BattingCounts(plateAppearances: 3, atBats: 2, hits: 1, doubles: 1, runsBattedIn: 1, sacrificeFlies: 1)),
                line("m3", "Marcus Hale", "24", 2, [.firstBase], BattingCounts(plateAppearances: 3, atBats: 3, hits: 1)),
                line("m4", "Tommy Diaz", "7", 3, [.lf], BattingCounts(plateAppearances: 3, atBats: 2, runs: 1, hits: 1, homeRuns: 1, runsBattedIn: 1, walks: 1)),
                line("m5", "Sam Kim", "5", 4, [.thirdBase], BattingCounts(plateAppearances: 3, atBats: 2, runs: 1, hits: 1, walks: 1, strikeouts: 1)),
                line("m6", "Eddie Park", "11", 5, [.rf], BattingCounts(plateAppearances: 3, atBats: 3, stolenBases: 1)),
                line("m7", "Joe Varga", "8", 6, [.c], BattingCounts(plateAppearances: 2, atBats: 1, walks: 1)),
                line("m8", "Nate Bell", "4", 7, [.secondBase], BattingCounts(plateAppearances: 2, atBats: 2, hits: 1, runsBattedIn: 1)),
                line("m9", "Ray Collins", "31", 8, [.p], BattingCounts(plateAppearances: 1, atBats: 1, strikeouts: 1)),
                // Moss popped out to short batting for Collins in the 4th; Reyes took Moss's spot
                // when they came in to pitch in the bottom of the 4th.
                line("m10", "Kyle Moss", "15", 8, [.ph], BattingCounts(plateAppearances: 1, atBats: 1), sub: true,
                     entered: SubstituteEntry(inning: 4, kind: .pinchHitter, replaced: "m9", replacedName: "Ray Collins",
                                              outcome: .out, notation: "P6")),
                line("m12", "Gus Reyes", "40", 8, [.p], BattingCounts(), sub: true,
                     entered: SubstituteEntry(inning: 4, kind: .replacement, replaced: "m10", replacedName: "Kyle Moss")),
            ],
            pitching: [
                PitchingLine(player: "m9", name: "Ray Collins", number: "31", stats: PitchingCounts(
                    outsRecorded: 9, battersFaced: 15, hits: 6, runs: 3, walks: 1, strikeouts: 2, homeRuns: 1, pitches: 47, strikes: 30)),
                PitchingLine(player: "m12", name: "Gus Reyes", number: "40", stats: PitchingCounts(
                    outsRecorded: 6, battersFaced: 9, hits: 3, runs: 2, hitBatters: 1, pitches: 23, strikes: 15),
                    // Charged with Ford's run in the 4th, which put the Diamond Dogs ahead for good.
                    decision: .loss),
            ],
            fielding: [
                field("m1", "Luis Ortiz", .centerField, 1...5, FieldingCounts(putouts: 1)),
                field("m2", "Danny Ruiz", .shortstop, 1...5, FieldingCounts(putouts: 2, assists: 3)),
                field("m3", "Marcus Hale", .firstBase, 1...5, FieldingCounts(putouts: 6)),
                field("m4", "Tommy Diaz", .leftField, 1...5, FieldingCounts(putouts: 2)),
                field("m5", "Sam Kim", .thirdBase, 1...5, FieldingCounts(assists: 1, errors: 1)),
                field("m6", "Eddie Park", .rightField, 1...5, FieldingCounts(putouts: 1)),
                field("m7", "Joe Varga", .catcher, 1...5, FieldingCounts(putouts: 2, assists: 1)),
                field("m8", "Nate Bell", .secondBase, 1...5, FieldingCounts(putouts: 1, assists: 3)),
                field("m9", "Ray Collins", .pitcher, 1...3, FieldingCounts(assists: 1)),
                field("m12", "Gus Reyes", .pitcher, 4...5, FieldingCounts()),
            ],
            runs: 3, hits: 7, errors: 1, leftOnBase: 6
        ),
        home: TeamBoxScore(
            side: .home, teamID: "diamond-dogs", name: "Diamond Dogs",
            batting: [
                line("d1", "Alex Moreno", "3", 0, [.secondBase], BattingCounts(plateAppearances: 3, atBats: 2, runs: 1, hits: 1, runsBattedIn: 1, walks: 1)),
                line("d2", "Chris Tate", "6", 1, [.ss], BattingCounts(plateAppearances: 3, atBats: 2, runs: 1, hits: 1, homeRuns: 1, runsBattedIn: 1, sacrificeBunts: 1)),
                line("d3", "Jordan Webb", "22", 2, [.cf], BattingCounts(plateAppearances: 3, atBats: 3, runs: 1, hits: 1, doubles: 1, runsBattedIn: 1, strikeouts: 1, caughtStealing: 1)),
                line("d4", "Pat Quinn", "33", 3, [.firstBase], BattingCounts(plateAppearances: 3, atBats: 3, hits: 1)),
                line("d5", "Riley Shaw", "12", 4, [.thirdBase], BattingCounts(plateAppearances: 2, atBats: 2, hits: 1, runsBattedIn: 1)),
                line("d6", "Casey Ford", "9", 5, [.lf], BattingCounts(plateAppearances: 2, atBats: 1, runs: 1, strikeouts: 1, hitByPitch: 1)),
                line("d7", "Drew Lang", "17", 6, [.rf], BattingCounts(plateAppearances: 2, atBats: 2, hits: 1)),
                line("d8", "Morgan Fisk", "10", 7, [.c], BattingCounts(plateAppearances: 2, atBats: 1, runsBattedIn: 1, sacrificeFlies: 1)),
                line("d9", "Sky Barros", "21", 8, [.p], BattingCounts(plateAppearances: 2, atBats: 2, hits: 1)),
                line("d12", "Taylor Voss", "44", 8, [.p], BattingCounts(), sub: true,
                     entered: SubstituteEntry(inning: 5, kind: .replacement, replaced: "d9", replacedName: "Sky Barros")),
                line("d10", "Jamie Cole", "14", 9, [], BattingCounts(plateAppearances: 2, atBats: 2, runs: 1, hits: 2, doubles: 1, stolenBases: 1)),
            ],
            pitching: [
                PitchingLine(player: "d9", name: "Sky Barros", number: "21", stats: PitchingCounts(
                    outsRecorded: 12, battersFaced: 19, hits: 6, runs: 3, walks: 2, strikeouts: 1, homeRuns: 1, pitches: 57, strikes: 35),
                    // Pitching when the Diamond Dogs went ahead for good in the 4th, with four complete
                    // innings, enough for a starter when the team plays five innings in the field.
                    decision: .win),
                PitchingLine(player: "d12", name: "Taylor Voss", number: "44", stats: PitchingCounts(
                    outsRecorded: 3, battersFaced: 5, hits: 1, walks: 1, strikeouts: 1, pitches: 13, strikes: 9)),
            ],
            fielding: [
                field("d1", "Alex Moreno", .secondBase, 1...5, FieldingCounts(putouts: 2, assists: 5)),
                field("d2", "Chris Tate", .shortstop, 1...5, FieldingCounts(putouts: 3, assists: 1, errors: 1)),
                field("d3", "Jordan Webb", .centerField, 1...5, FieldingCounts(putouts: 2)),
                field("d4", "Pat Quinn", .firstBase, 1...5, FieldingCounts(putouts: 5)),
                field("d5", "Riley Shaw", .thirdBase, 1...5, FieldingCounts()),
                field("d6", "Casey Ford", .leftField, 1...5, FieldingCounts()),
                field("d7", "Drew Lang", .rightField, 1...5, FieldingCounts(putouts: 1)),
                field("d8", "Morgan Fisk", .catcher, 1...5, FieldingCounts(putouts: 2)),
                field("d9", "Sky Barros", .pitcher, 1...4, FieldingCounts()),
                field("d12", "Taylor Voss", .pitcher, 5...5, FieldingCounts()),
            ],
            runs: 5, hits: 9, errors: 1, leftOnBase: 4
        ),
        lineScore: LineScore(away: [0, 1, 1, 1, 0], home: [2, 0, 1, 1, 1]),
        notes: BoxScoreNotes(
            errors: [tally("m5", "Sam Kim", .away), tally("d2", "Chris Tate", .home)],
            doubles: [tally("m2", "Danny Ruiz", .away), tally("d3", "Jordan Webb", .home), tally("d10", "Jamie Cole", .home)],
            triples: [tally("m1", "Luis Ortiz", .away)],
            homeRuns: [tally("m4", "Tommy Diaz", .away), tally("d2", "Chris Tate", .home)],
            runsBattedIn: [
                tally("m2", "Danny Ruiz", .away), tally("m4", "Tommy Diaz", .away), tally("m8", "Nate Bell", .away),
                tally("d1", "Alex Moreno", .home), tally("d2", "Chris Tate", .home), tally("d3", "Jordan Webb", .home),
                tally("d5", "Riley Shaw", .home), tally("d8", "Morgan Fisk", .home),
            ],
            stolenBases: [tally("m6", "Eddie Park", .away), tally("d10", "Jamie Cole", .home)],
            caughtStealing: [tally("d3", "Jordan Webb", .home)],
            sacrificeFlies: [tally("m2", "Danny Ruiz", .away), tally("d8", "Morgan Fisk", .home)],
            sacrificeBunts: [tally("d2", "Chris Tate", .home)],
            hitByPitch: [tally("d6", "Casey Ford", .home)],
            doublePlays: [TeamTally(team: .away, name: "Mudcats", count: 2), TeamTally(team: .home, name: "Diamond Dogs", count: 2)],
            triplePlays: [],
            leftOnBase: [TeamTally(team: .away, name: "Mudcats", count: 6), TeamTally(team: .home, name: "Diamond Dogs", count: 4)],
            hitBatters: [HitBatterNote(batter: "d6", batterName: "Casey Ford", team: .home,
                                       pitcher: "m12", pitcherName: "Gus Reyes", count: 1)],
            ranForNonRunners: [NonRunnerRunnerNote(runner: "d3", runnerName: "Jordan Webb", nonRunner: "d4",
                                                   nonRunnerName: "Pat Quinn", team: .home, innings: [3])]
        ),
        isFinal: true,
        // The first pitch was the second event and the end of the game the 154th, with 76
        // seconds between events: 152 × 76 = 11,552 seconds, or 3:12.
        gameLength: 11_552
    )

    /// A batting line. `spot` counts from 0 for the leadoff spot.
    static func line(_ id: PlayerID, _ name: String, _ number: String, _ spot: Int, _ positions: [BoxPosition],
                             _ stats: BattingCounts, sub: Bool = false, entered: SubstituteEntry? = nil) -> BattingLine {
        BattingLine(player: id, name: name, number: number, batterIndex: spot, positions: positions, isSubstitute: sub,
                    stats: stats, entered: entered)
    }

    /// A fielding line for a player who played one position for a run of innings.
    static func field(_ id: PlayerID, _ name: String, _ position: Position, _ innings: ClosedRange<Int>,
                      _ stats: FieldingCounts) -> FieldingLine {
        FieldingLine(player: id, name: name,
                     appearances: [FieldingAppearance(position: position, innings: Array(innings))], stats: stats)
    }

    /// One player's entry in a box score note, once.
    static func tally(_ id: PlayerID, _ name: String, _ team: TeamSide, _ count: Int = 1) -> PlayerTally {
        PlayerTally(player: id, name: name, team: team, count: count)
    }
}
