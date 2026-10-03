// One complete made-up game, start to finish: Cardinals at Mudcats, May 2, 2026.
// Five innings, then the time limit ran out with the Mudcats ahead 5-3.
//
// Written out by hand, plate appearance by plate appearance, with the play log alongside
// (see GameScript.swift for the helper). The box score in SampleBoxScore.swift was then
// worked out by hand from this account. Pitch letters: B ball, C called strike,
// S swinging strike, F foul.
//
// Who is who: Cardinals c1 Ortiz cf, c2 Ruiz ss, c3 Hale 1b, c4 Diaz lf, c5 Kim 3b,
// c6 Park rf, c7 Varga c, c8 Bell 2b, c9 Collins p; Moss (c10) pinch-hits and Reyes (c12)
// relieves. Mudcats m1 Moreno 2b, m2 Tate ss, m3 Webb cf, m4 Quinn 1b (a designated
// non-runner), m5 Shaw 3b, m6 Ford lf, m7 Lang rf, m8 Fisk c, m9 Barros p, m10 Cole extra
// hitter; Nash (m11) runs for Quinn, and Voss (m12) relieves.

import Foundation
import Model

/// The complete sample game.
public enum SampleGame {
    /// The game's id.
    public static let id: GameID = "sample-game"

    /// The game: its setup and every event.
    public static var game: Game { script.game }

    /// The rules engine's account of every event, written by hand.
    public static var playLog: PlayLog { script.playLog(isFinal: true) }

    /// Where the game stood at the end.
    public static var finalSituation: Situation { script.situation(isFinal: true) }

    /// The game cut off at the end of the third inning, for "game in progress" previews.
    /// Its box score so far is `boxScoreThroughThree`.
    public static var throughThreeInnings: (game: Game, log: PlayLog) {
        let cut = script.entries.firstIndex { $0.inning == 4 } ?? script.entries.count
        var game = script.game
        game.events = Array(game.events[..<cut])
        var log = script.playLog(isFinal: false)
        log.entries = Array(log.entries[..<cut])
        // Nobody had been substituted by then, so the batting orders are the starting ones.
        let start = Situation(startOf: game.setup)
        log.awayOrder = start.away.battingOrder
        log.homeOrder = start.home.battingOrder
        return (game, log)
    }

    /// Writes the whole game. Built once, the first time it is used.
    static let script: GameScript = {
        var s = GameScript(gameID: id, setup: SampleSetups.cardinalsAtMudcats,
                           firstEventAt: SampleSetups.gameDay.addingTimeInterval(300))

        // MARK: Top of the 1st. Barros pitching.
        s.lineupChange(.defenseConfirmed(DefenseConfirmed(team: .home)), notation: "")

        s.plateAppearance("c1", "BC", .inPlay(Play(batterResult: .single, battedBall: .lineDrive, hitLocation: .leftField,
                                                    runners: [move("c1", .home, .first)])),
            Outcome(outs: 0, runners: [on("c1", .first, by: "m9")], result: .single, reached: true, notation: "1B 7"))

        s.plateAppearance("c2", "FB", .inPlay(Play(batterResult: .out, battedBall: .groundBall, fielders: [6, 4, 3].positions,
                                                    runners: [move("c1", .first, .out, outBy: [6, 4].positions, at: .second),
                                                              move("c2", .home, .out, outBy: [4, 3].positions, at: .first)],
                                                    multiOut: .doublePlay)),
            Outcome(outs: 2, outsMade: [out("c1", putout: "m1", assists: ["m2"], at: .second),
                                        out("c2", putout: "m4", assists: ["m1"], at: .first)],
                    result: .out, notation: "6-4-3 DP"))

        s.plateAppearance("c3", "BBS", .inPlay(Play(batterResult: .out, battedBall: .flyBall, fielders: [.centerField],
                                                     runners: [move("c3", .home, .out, outBy: [.centerField])])),
            Outcome(outs: 3, outsMade: [out("c3", putout: "m3")], result: .out, notation: "F8"))

        // MARK: Bottom of the 1st. Collins pitching.
        s.plateAppearance("m1", "BBBC", .pitch(.ball),
            Outcome(outs: 0, runners: [on("m1", .first, by: "c9")], result: .walk, reached: true, notation: "BB"))

        s.plateAppearance("m2", "S", .inPlay(Play(batterResult: .sacrificeBunt, battedBall: .bunt, fielders: [.pitcher, .firstBase],
                                                   runners: [move("m1", .first, .second),
                                                             move("m2", .home, .out, outBy: [.pitcher, .firstBase], at: .first)])),
            Outcome(outs: 1, runners: [on("m1", .second, by: "c9")], outsMade: [out("m2", putout: "c3", assists: ["c9"], at: .first)],
                    result: .sacrificeBunt, notation: "SH 1-3"))

        s.plateAppearance("m3", "C", .inPlay(Play(batterResult: .double, battedBall: .lineDrive, hitLocation: .rightField,
                                                   runners: [move("m1", .second, .scored), move("m3", .home, .second)], rbi: 1)),
            Outcome(outs: 1, runners: [on("m3", .second, by: "c9")], runs: [run("m1", charged: "c9")],
                    result: .double, rbi: 1, reached: true, notation: "2B 9"))

        s.plateAppearance("m4", "BF", .inPlay(Play(batterResult: .out, battedBall: .groundBall, fielders: [.secondBase, .firstBase],
                                                    runners: [move("m3", .second, .third),
                                                              move("m4", .home, .out, outBy: [.secondBase, .firstBase], at: .first)])),
            Outcome(outs: 2, runners: [on("m3", .third, by: "c9")], outsMade: [out("m4", putout: "c3", assists: ["c8"], at: .first)],
                    result: .out, notation: "4-3"))

        s.plateAppearance("m5", "", .inPlay(Play(batterResult: .single, battedBall: .groundBall, hitLocation: .centerField,
                                                  runners: [move("m3", .third, .scored), move("m5", .home, .first)], rbi: 1)),
            Outcome(outs: 2, runners: [on("m5", .first, by: "c9")], runs: [run("m3", charged: "c9")],
                    result: .single, rbi: 1, reached: true, notation: "1B 8"))

        s.plateAppearance("m6", "BSF", .pitch(.swingingStrike),
            Outcome(outs: 3, runners: [on("m5", .first, by: "c9")], outsMade: [out("m6", putout: "c7")],
                    result: .strikeout, notation: "K"))

        // MARK: Top of the 2nd.
        s.lineupChange(.defenseConfirmed(DefenseConfirmed(team: .home)), notation: "")

        s.plateAppearance("c4", "BCFB", .inPlay(Play(batterResult: .homeRun, battedBall: .flyBall, hitLocation: .leftField,
                                                      runners: [move("c4", .home, .scored)], rbi: 1)),
            Outcome(outs: 0, runs: [run("c4", charged: "m9")], result: .homeRun, rbi: 1, reached: true, notation: "HR 7"))

        s.plateAppearance("c5", "BBB", .pitch(.ball),
            Outcome(outs: 0, runners: [on("c5", .first, by: "m9")], result: .walk, reached: true, notation: "BB"))

        s.plateAppearance("c6", "S", .inPlay(Play(batterResult: .fieldersChoice, battedBall: .groundBall, fielders: [.secondBase, .shortstop],
                                                   runners: [move("c5", .first, .out, outBy: [.secondBase, .shortstop], at: .second),
                                                             move("c6", .home, .first)])),
            Outcome(outs: 1, runners: [on("c6", .first, by: "m9")], outsMade: [out("c5", putout: "m2", assists: ["m1"], at: .second)],
                    result: .fieldersChoice, reached: true, notation: "FC 4-6"))

        // Park steals second with Varga up 1-0.
        s.pitches("B", to: "c7")
        s.runnerAction(RunnerAction(moves: [move("c6", .first, .second, reason: .stolenBase)]), batter: "c7",
            Outcome(outs: 1, runners: [on("c6", .second, by: "m9")], notation: "SB2"))
        s.plateAppearance("c7", "C", .inPlay(Play(batterResult: .out, battedBall: .lineDrive, fielders: [.shortstop],
                                                   runners: [move("c7", .home, .out, outBy: [.shortstop])])),
            Outcome(outs: 2, runners: [on("c6", .second, by: "m9")], outsMade: [out("c7", putout: "m2")], result: .out, notation: "L6"))

        s.plateAppearance("c8", "B", .inPlay(Play(batterResult: .reachedOnError, battedBall: .groundBall, fielders: [.shortstop],
                                                   runners: [move("c6", .second, .third), move("c8", .home, .first, onError: true)],
                                                   errors: [ErrorCharge(fielder: .shortstop, type: .throwing)])),
            Outcome(outs: 2, runners: [on("c6", .third, by: "m9"), on("c8", .first, by: "m9")],
                    errors: [ChargedError(fielder: .shortstop, player: "m2")], result: .reachedOnError, reached: true, notation: "E6"))

        s.plateAppearance("c9", "SS", .pitch(.swingingStrike),
            Outcome(outs: 3, runners: [on("c6", .third, by: "m9"), on("c8", .first, by: "m9")],
                    outsMade: [out("c9", putout: "m8")], result: .strikeout, notation: "K"))

        // MARK: Bottom of the 2nd.
        s.plateAppearance("m7", "", .inPlay(Play(batterResult: .out, battedBall: .groundBall, fielders: [.thirdBase, .firstBase],
                                                  runners: [move("m7", .home, .out, outBy: [.thirdBase, .firstBase], at: .first)])),
            Outcome(outs: 1, outsMade: [out("m7", putout: "c3", assists: ["c5"], at: .first)], result: .out, notation: "5-3"))

        s.plateAppearance("m8", "BC", .inPlay(Play(batterResult: .out, battedBall: .flyBall, fielders: [.leftField],
                                                    runners: [move("m8", .home, .out, outBy: [.leftField])])),
            Outcome(outs: 2, outsMade: [out("m8", putout: "c4")], result: .out, notation: "F7"))

        s.plateAppearance("m9", "FFB", .inPlay(Play(batterResult: .single, battedBall: .groundBall, hitLocation: .rightField,
                                                     runners: [move("m9", .home, .first)])),
            Outcome(outs: 2, runners: [on("m9", .first, by: "c9")], result: .single, reached: true, notation: "1B 9"))

        s.plateAppearance("m10", "BBC", .inPlay(Play(batterResult: .double, battedBall: .lineDrive, hitLocation: .leftField,
                                                      runners: [move("m9", .first, .third), move("m10", .home, .second)])),
            Outcome(outs: 2, runners: [on("m9", .third, by: "c9"), on("m10", .second, by: "c9")],
                    result: .double, reached: true, notation: "2B 7"))

        s.plateAppearance("m1", "CSBBF", .inPlay(Play(batterResult: .out, battedBall: .groundBall, fielders: [.shortstop, .firstBase],
                                                       runners: [move("m1", .home, .out, outBy: [.shortstop, .firstBase], at: .first)])),
            Outcome(outs: 3, runners: [on("m9", .third, by: "c9"), on("m10", .second, by: "c9")],
                    outsMade: [out("m1", putout: "c3", assists: ["c2"], at: .first)], result: .out, notation: "6-3"))

        // MARK: Top of the 3rd.
        s.lineupChange(.defenseConfirmed(DefenseConfirmed(team: .home)), notation: "")

        s.plateAppearance("c1", "C", .inPlay(Play(batterResult: .triple, battedBall: .lineDrive, hitLocation: .rightField,
                                                   runners: [move("c1", .home, .third)])),
            Outcome(outs: 0, runners: [on("c1", .third, by: "m9")], result: .triple, reached: true, notation: "3B 9"))

        s.plateAppearance("c2", "B", .inPlay(Play(batterResult: .sacrificeFly, battedBall: .flyBall, fielders: [.centerField],
                                                   runners: [move("c2", .home, .out, outBy: [.centerField]), move("c1", .third, .scored)],
                                                   rbi: 1)),
            Outcome(outs: 1, runs: [run("c1", charged: "m9")], outsMade: [out("c2", putout: "m3")],
                    result: .sacrificeFly, rbi: 1, notation: "SF 8"))

        s.plateAppearance("c3", "BCBF", .inPlay(Play(batterResult: .single, battedBall: .lineDrive, hitLocation: .rightField,
                                                      runners: [move("c3", .home, .first)])),
            Outcome(outs: 1, runners: [on("c3", .first, by: "m9")], result: .single, reached: true, notation: "1B 9"))

        // Diaz lines to second, who throws to first to double off Hale.
        s.plateAppearance("c4", "SB", .inPlay(Play(batterResult: .out, battedBall: .lineDrive, fielders: [.secondBase, .firstBase],
                                                    runners: [move("c4", .home, .out, outBy: [.secondBase]),
                                                              move("c3", .first, .out, outBy: [.secondBase, .firstBase], at: .first)],
                                                    multiOut: .doublePlay)),
            Outcome(outs: 3, outsMade: [out("c4", putout: "m1"), out("c3", putout: "m4", assists: ["m1"], at: .first)],
                    result: .out, notation: "L4-3 DP"))

        // MARK: Bottom of the 3rd.
        s.plateAppearance("m2", "BB", .inPlay(Play(batterResult: .homeRun, battedBall: .flyBall, hitLocation: .rightField,
                                                    runners: [move("m2", .home, .scored)], rbi: 1)),
            Outcome(outs: 0, runs: [run("m2", charged: "c9")], result: .homeRun, rbi: 1, reached: true, notation: "HR 9"))

        s.plateAppearance("m3", "CCB", .pitch(.swingingStrike),
            Outcome(outs: 1, outsMade: [out("m3", putout: "c7")], result: .strikeout, notation: "K"))

        s.plateAppearance("m4", "B", .inPlay(Play(batterResult: .single, battedBall: .groundBall, hitLocation: .leftField,
                                                   runners: [move("m4", .home, .first)])),
            Outcome(outs: 1, runners: [on("m4", .first, by: "c9")], result: .single, reached: true, notation: "1B 7"))

        // Quinn is a designated non-runner, so Nash runs for them, and is caught stealing
        // with Shaw up 1-0. The caught stealing is Nash's.
        s.runnerForNonRunner("m11", replacing: "m4", notation: "R Nash for Quinn")
        s.pitches("B", to: "m5")
        s.runnerAction(RunnerAction(moves: [move("m11", .first, .out, outBy: [.catcher, .shortstop], at: .second, reason: .caughtStealing)]),
                       batter: "m5",
            Outcome(outs: 2, outsMade: [out("m11", putout: "c2", assists: ["c7"], at: .second)], notation: "CS2 2-6"))
        s.plateAppearance("m5", "C", .inPlay(Play(batterResult: .out, battedBall: .flyBall, fielders: [.rightField],
                                                   runners: [move("m5", .home, .out, outBy: [.rightField])])),
            Outcome(outs: 3, outsMade: [out("m5", putout: "c6")], result: .out, notation: "F9"))

        // MARK: Top of the 4th.
        s.lineupChange(.defenseConfirmed(DefenseConfirmed(team: .home)), notation: "")

        s.plateAppearance("c5", "BF", .inPlay(Play(batterResult: .single, battedBall: .groundBall, hitLocation: .centerField,
                                                    runners: [move("c5", .home, .first)])),
            Outcome(outs: 0, runners: [on("c5", .first, by: "m9")], result: .single, reached: true, notation: "1B 8"))

        s.plateAppearance("c6", "C", .inPlay(Play(batterResult: .out, battedBall: .groundBall, fielders: [.firstBase],
                                                   runners: [move("c5", .first, .second),
                                                             move("c6", .home, .out, outBy: [.firstBase], at: .first)])),
            Outcome(outs: 1, runners: [on("c5", .second, by: "m9")], outsMade: [out("c6", putout: "m4", at: .first)],
                    result: .out, notation: "3U"))

        s.plateAppearance("c7", "BBBC", .pitch(.ball),
            Outcome(outs: 1, runners: [on("c5", .second, by: "m9"), on("c7", .first, by: "m9")],
                    result: .walk, reached: true, notation: "BB"))

        s.plateAppearance("c8", "", .inPlay(Play(batterResult: .single, battedBall: .groundBall, hitLocation: .leftField,
                                                  runners: [move("c5", .second, .scored), move("c7", .first, .second),
                                                            move("c8", .home, .first)], rbi: 1)),
            Outcome(outs: 1, runners: [on("c7", .second, by: "m9"), on("c8", .first, by: "m9")], runs: [run("c5", charged: "m9")],
                    result: .single, rbi: 1, reached: true, notation: "1B 7"))

        // Moss pinch-hits for Collins.
        s.lineupChange(.substitution(Substitution(team: .away, changes: [
            LineupChange(kind: .pinchHitter, incoming: "c10", replacing: "c9"),
        ])), notation: "PH Moss for Collins") { s in
            s.away.battingOrder.slots[8].players.append("c10")
            s.away.battingOrder.slots[8].position = nil
        }

        s.plateAppearance("c10", "SF", .inPlay(Play(batterResult: .out, battedBall: .popUp, fielders: [.shortstop],
                                                     runners: [move("c10", .home, .out, outBy: [.shortstop])])),
            Outcome(outs: 2, runners: [on("c7", .second, by: "m9"), on("c8", .first, by: "m9")],
                    outsMade: [out("c10", putout: "m2")], result: .out, notation: "P6"))

        s.plateAppearance("c1", "B", .inPlay(Play(batterResult: .out, battedBall: .groundBall, fielders: [.secondBase, .firstBase],
                                                   runners: [move("c1", .home, .out, outBy: [.secondBase, .firstBase], at: .first)])),
            Outcome(outs: 3, runners: [on("c7", .second, by: "m9"), on("c8", .first, by: "m9")],
                    outsMade: [out("c1", putout: "m4", assists: ["m1"], at: .first)], result: .out, notation: "4-3"))

        // MARK: Bottom of the 4th. Reyes comes in to pitch and takes Moss's spot in the order.
        s.lineupChange(.pitchingChange(PitchingChange(team: .away, newPitcher: "c12", takesBattingSpotOf: "c10")),
                       notation: "P Reyes") { s in
            s.away.battingOrder.slots[8].players.append("c12")
            s.away.battingOrder.slots[8].position = .pitcher
            s.away.fielders = s.away.fielders.map { $0.position == .pitcher ? FielderAssignment(position: .pitcher, player: "c12") : $0 }
        }

        s.plateAppearance("m6", "BCB", .pitch(.hitByPitch),
            Outcome(outs: 0, runners: [on("m6", .first, by: "c12")], result: .hitByPitch, reached: true, notation: "HBP"))

        s.plateAppearance("m7", "", .inPlay(Play(batterResult: .single, battedBall: .lineDrive, hitLocation: .rightField,
                                                  runners: [move("m6", .first, .third), move("m7", .home, .first)])),
            Outcome(outs: 0, runners: [on("m6", .third, by: "c12"), on("m7", .first, by: "c12")],
                    result: .single, reached: true, notation: "1B 9"))

        s.plateAppearance("m8", "B", .inPlay(Play(batterResult: .sacrificeFly, battedBall: .flyBall, fielders: [.leftField],
                                                   runners: [move("m8", .home, .out, outBy: [.leftField]), move("m6", .third, .scored)],
                                                   rbi: 1)),
            Outcome(outs: 1, runners: [on("m7", .first, by: "c12")], runs: [run("m6", charged: "c12")],
                    outsMade: [out("m8", putout: "c4")], result: .sacrificeFly, rbi: 1, notation: "SF 7"))

        s.plateAppearance("m9", "SSFB", .inPlay(Play(batterResult: .out, battedBall: .groundBall, fielders: [6, 4, 3].positions,
                                                      runners: [move("m7", .first, .out, outBy: [6, 4].positions, at: .second),
                                                                move("m9", .home, .out, outBy: [4, 3].positions, at: .first)],
                                                      multiOut: .doublePlay)),
            Outcome(outs: 3, outsMade: [out("m7", putout: "c8", assists: ["c2"], at: .second),
                                        out("m9", putout: "c3", assists: ["c8"], at: .first)],
                    result: .out, notation: "6-4-3 DP"))

        // MARK: Top of the 5th. Voss comes in to pitch and takes Barros's spot in the order.
        s.lineupChange(.pitchingChange(PitchingChange(team: .home, newPitcher: "m12")), notation: "P Voss") { s in
            s.home.battingOrder.slots[8].players.append("m12")
            s.home.fielders = s.home.fielders.map { $0.position == .pitcher ? FielderAssignment(position: .pitcher, player: "m12") : $0 }
        }
        s.lineupChange(.defenseConfirmed(DefenseConfirmed(team: .home)), notation: "")

        s.plateAppearance("c2", "BB", .inPlay(Play(batterResult: .double, battedBall: .lineDrive, hitLocation: .leftField,
                                                    runners: [move("c2", .home, .second)])),
            Outcome(outs: 0, runners: [on("c2", .second, by: "m12")], result: .double, reached: true, notation: "2B 7"))

        s.plateAppearance("c3", "CBS", .inPlay(Play(batterResult: .out, battedBall: .groundBall, fielders: [.secondBase, .firstBase],
                                                     runners: [move("c2", .second, .third),
                                                               move("c3", .home, .out, outBy: [.secondBase, .firstBase], at: .first)])),
            Outcome(outs: 1, runners: [on("c2", .third, by: "m12")], outsMade: [out("c3", putout: "m4", assists: ["m1"], at: .first)],
                    result: .out, notation: "4-3"))

        s.plateAppearance("c4", "", .intentionalWalk,
            Outcome(outs: 1, runners: [on("c2", .third, by: "m12"), on("c4", .first, by: "m12")],
                    result: .intentionalWalk, reached: true, notation: "IBB"))

        s.plateAppearance("c5", "BCFF", .pitch(.swingingStrike),
            Outcome(outs: 2, runners: [on("c2", .third, by: "m12"), on("c4", .first, by: "m12")],
                    outsMade: [out("c5", putout: "m8")], result: .strikeout, notation: "K"))

        s.plateAppearance("c6", "", .inPlay(Play(batterResult: .out, battedBall: .flyBall, fielders: [.rightField],
                                                  runners: [move("c6", .home, .out, outBy: [.rightField])])),
            Outcome(outs: 3, runners: [on("c2", .third, by: "m12"), on("c4", .first, by: "m12")],
                    outsMade: [out("c6", putout: "m7")], result: .out, notation: "F9"))

        // MARK: Bottom of the 5th.
        s.plateAppearance("m10", "B", .inPlay(Play(batterResult: .single, battedBall: .groundBall, hitLocation: .centerField,
                                                    runners: [move("m10", .home, .first)])),
            Outcome(outs: 0, runners: [on("m10", .first, by: "c12")], result: .single, reached: true, notation: "1B 8"))

        // Cole steals second with Moreno up 1-0, then Moreno singles Cole home.
        s.pitches("B", to: "m1")
        s.runnerAction(RunnerAction(moves: [move("m10", .first, .second, reason: .stolenBase)]), batter: "m1",
            Outcome(outs: 0, runners: [on("m10", .second, by: "c12")], notation: "SB2"))
        s.plateAppearance("m1", "C", .inPlay(Play(batterResult: .single, battedBall: .lineDrive, hitLocation: .rightField,
                                                   runners: [move("m10", .second, .scored), move("m1", .home, .first)], rbi: 1)),
            Outcome(outs: 0, runners: [on("m1", .first, by: "c12")], runs: [run("m10", charged: "c12")],
                    result: .single, rbi: 1, reached: true, notation: "1B 9"))

        s.plateAppearance("m2", "F", .inPlay(Play(batterResult: .out, battedBall: .flyBall, fielders: [.centerField],
                                                   runners: [move("m2", .home, .out, outBy: [.centerField])])),
            Outcome(outs: 1, runners: [on("m1", .first, by: "c12")], outsMade: [out("m2", putout: "c1")], result: .out, notation: "F8"))

        s.plateAppearance("m3", "BS", .inPlay(Play(batterResult: .reachedOnError, battedBall: .groundBall, fielders: [.thirdBase],
                                                    runners: [move("m1", .first, .second), move("m3", .home, .first, onError: true)],
                                                    errors: [ErrorCharge(fielder: .thirdBase, type: .fielding)])),
            Outcome(outs: 1, runners: [on("m1", .second, by: "c12"), on("m3", .first, by: "c12")],
                    errors: [ChargedError(fielder: .thirdBase, player: "c5")], result: .reachedOnError, reached: true, notation: "E5"))

        s.plateAppearance("m4", "", .inPlay(Play(batterResult: .out, battedBall: .groundBall, fielders: [4, 6, 3].positions,
                                                  runners: [move("m1", .second, .third),
                                                            move("m3", .first, .out, outBy: [4, 6].positions, at: .second),
                                                            move("m4", .home, .out, outBy: [6, 3].positions, at: .first)],
                                                  multiOut: .doublePlay)),
            Outcome(outs: 3, runners: [on("m1", .third, by: "c12")],
                    outsMade: [out("m3", putout: "c2", assists: ["c8"], at: .second),
                               out("m4", putout: "c3", assists: ["c2"], at: .first)],
                    result: .out, notation: "4-6-3 DP"))

        // MARK: Time limit. The scorer ends the game after five innings.
        s.endGame(EndOfGame(reason: .timeLimit, finalScore: Score(away: 3, home: 5)))
        return s
    }()
}

extension Array where Element == Int {
    /// Scorebook numbers as positions: `[6, 4, 3].positions`.
    var positions: [Position] { compactMap(Position.init(rawValue:)) }
}
