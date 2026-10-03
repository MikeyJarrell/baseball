// One complete made-up game, start to finish: Mudcats at Diamond Dogs, May 2, 2026.
// Five innings, then the time limit ran out with the Diamond Dogs ahead 5-3.
//
// Written out by hand, plate appearance by plate appearance, with the play log alongside
// (see GameScript.swift for the helper). The box score in SampleBoxScore.swift was then
// worked out by hand from this account. Pitch letters: B ball, C called strike,
// S swinging strike, F foul.
//
// Who is who: Mudcats m1 Ortiz cf, m2 Ruiz ss, m3 Hale 1b, m4 Diaz lf, m5 Kim 3b,
// m6 Park rf, m7 Varga c, m8 Bell 2b, m9 Collins p; Moss (m10) pinch-hits and Reyes (m12)
// relieves. Diamond Dogs d1 Moreno 2b, d2 Tate ss, d3 Webb cf, d4 Quinn 1b (a designated
// non-runner), d5 Shaw 3b, d6 Ford lf, d7 Lang rf, d8 Fisk c, d9 Barros p, d10 Cole extra
// hitter; Webb runs for Quinn once, and Voss (d12) relieves Barros.

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

    /// Where the game stood at the end. The time limit ran out during the fifth inning, which
    /// had begun before it; when the fifth was finished the app asked whether the game was over
    /// on time, and the scorer ended it. Five innings make it an official game. Collins may come back to pitch, and may re-enter the
    /// ninth spot since Moss, who batted for them, has batted; Barros may come back to pitch.
    public static var finalSituation: Situation {
        var s = script.situation(isFinal: true)
        s.isRegulationComplete = true
        s.away.eligibleToReenter = [ReentryOption(player: "m9", spotIndex: 8)]
        s.away.eligibleToPitchAgain = ["m9"]
        s.home.eligibleToPitchAgain = ["d9"]
        return s
    }

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
        // One event every 76 seconds, so the three-hour limit runs out during the bottom
        // of the fifth, an inning that began before it.
        var s = GameScript(gameID: id, setup: SampleSetups.mudcatsAtDiamondDogs,
                           firstEventAt: SampleSetups.gameDay.addingTimeInterval(300), secondsBetweenEvents: 76)

        // MARK: Top of the 1st. Barros pitching.
        s.lineupChange(.defenseConfirmed(DefenseConfirmed(team: .home)), notation: "")

        s.plateAppearance("m1", "BC", .inPlay(Play(batterResult: .single, battedBall: .lineDrive, hitLocation: .leftField,
                                                    runners: [move("m1", .home, .first)])),
            Outcome(outs: 0, runners: [on("m1", .first, by: "d9")], result: .single, reached: true, notation: "1B 7"))

        s.plateAppearance("m2", "FB", .inPlay(Play(batterResult: .out, battedBall: .groundBall, fielders: [6, 4, 3].positions,
                                                    runners: [move("m1", .first, .out, outBy: [6, 4].positions, at: .second),
                                                              move("m2", .home, .out, outBy: [4, 3].positions, at: .first)],
                                                    multiOut: .doublePlay)),
            Outcome(outs: 2, outsMade: [out("m1", putout: "d1", assists: ["d2"], at: .second),
                                        out("m2", putout: "d4", assists: ["d1"], at: .first)],
                    result: .out, notation: "6-4-3 DP"))

        s.plateAppearance("m3", "BBS", .inPlay(Play(batterResult: .out, battedBall: .flyBall, fielders: [.centerField],
                                                     runners: [move("m3", .home, .out, outBy: [.centerField])])),
            Outcome(outs: 3, outsMade: [out("m3", putout: "d3")], result: .out, notation: "F8"))

        // MARK: Bottom of the 1st. Collins pitching.
        s.plateAppearance("d1", "BBBC", .pitch(.ball),
            Outcome(outs: 0, runners: [on("d1", .first, by: "m9")], result: .walk, reached: true, notation: "BB"))

        s.plateAppearance("d2", "S", .inPlay(Play(batterResult: .sacrificeBunt, battedBall: .bunt, fielders: [.pitcher, .firstBase],
                                                   runners: [move("d1", .first, .second),
                                                             move("d2", .home, .out, outBy: [.pitcher, .firstBase], at: .first)])),
            Outcome(outs: 1, runners: [on("d1", .second, by: "m9")], outsMade: [out("d2", putout: "m3", assists: ["m9"], at: .first)],
                    result: .sacrificeBunt, notation: "SH 1-3"))

        s.plateAppearance("d3", "C", .inPlay(Play(batterResult: .double, battedBall: .lineDrive, hitLocation: .rightField,
                                                   runners: [move("d1", .second, .scored), move("d3", .home, .second)], rbi: 1)),
            Outcome(outs: 1, runners: [on("d3", .second, by: "m9")], runs: [run("d1", charged: "m9")],
                    result: .double, rbi: 1, reached: true, notation: "2B 9"))

        s.plateAppearance("d4", "BF", .inPlay(Play(batterResult: .out, battedBall: .groundBall, fielders: [.secondBase, .firstBase],
                                                    runners: [move("d3", .second, .third),
                                                              move("d4", .home, .out, outBy: [.secondBase, .firstBase], at: .first)])),
            Outcome(outs: 2, runners: [on("d3", .third, by: "m9")], outsMade: [out("d4", putout: "m3", assists: ["m8"], at: .first)],
                    result: .out, notation: "4-3"))

        s.plateAppearance("d5", "", .inPlay(Play(batterResult: .single, battedBall: .groundBall, hitLocation: .centerField,
                                                  runners: [move("d3", .third, .scored), move("d5", .home, .first)], rbi: 1)),
            Outcome(outs: 2, runners: [on("d5", .first, by: "m9")], runs: [run("d3", charged: "m9")],
                    result: .single, rbi: 1, reached: true, notation: "1B 8"))

        s.plateAppearance("d6", "BSF", .pitch(.swingingStrike),
            Outcome(outs: 3, runners: [on("d5", .first, by: "m9")], outsMade: [out("d6", putout: "m7")],
                    result: .strikeout, notation: "K"))

        // MARK: Top of the 2nd.
        s.lineupChange(.defenseConfirmed(DefenseConfirmed(team: .home)), notation: "")

        s.plateAppearance("m4", "BCFB", .inPlay(Play(batterResult: .homeRun, battedBall: .flyBall, hitLocation: .leftField,
                                                      runners: [move("m4", .home, .scored)], rbi: 1)),
            Outcome(outs: 0, runs: [run("m4", charged: "d9")], result: .homeRun, rbi: 1, reached: true, notation: "HR 7"))

        s.plateAppearance("m5", "BBB", .pitch(.ball),
            Outcome(outs: 0, runners: [on("m5", .first, by: "d9")], result: .walk, reached: true, notation: "BB"))

        s.plateAppearance("m6", "S", .inPlay(Play(batterResult: .fieldersChoice, battedBall: .groundBall, fielders: [.secondBase, .shortstop],
                                                   runners: [move("m5", .first, .out, outBy: [.secondBase, .shortstop], at: .second),
                                                             move("m6", .home, .first)])),
            Outcome(outs: 1, runners: [on("m6", .first, by: "d9")], outsMade: [out("m5", putout: "d2", assists: ["d1"], at: .second)],
                    result: .fieldersChoice, reached: true, notation: "FC 4-6"))

        // Park steals second with Varga up 1-0.
        s.pitches("B", to: "m7")
        s.runnerAction(RunnerAction(moves: [move("m6", .first, .second, reason: .stolenBase)]), batter: "m7",
            Outcome(outs: 1, runners: [on("m6", .second, by: "d9")], notation: "SB2"))
        s.plateAppearance("m7", "C", .inPlay(Play(batterResult: .out, battedBall: .lineDrive, fielders: [.shortstop],
                                                   runners: [move("m7", .home, .out, outBy: [.shortstop])])),
            Outcome(outs: 2, runners: [on("m6", .second, by: "d9")], outsMade: [out("m7", putout: "d2")], result: .out, notation: "L6"))

        s.plateAppearance("m8", "B", .inPlay(Play(batterResult: .reachedOnError, battedBall: .groundBall, fielders: [.shortstop],
                                                   runners: [move("m6", .second, .third), move("m8", .home, .first, onError: true)],
                                                   errors: [ErrorCharge(fielder: .shortstop, type: .throwing)])),
            Outcome(outs: 2, runners: [on("m6", .third, by: "d9"), on("m8", .first, by: "d9")],
                    errors: [ChargedError(fielder: .shortstop, player: "d2")], result: .reachedOnError, reached: true, notation: "E6"))

        s.plateAppearance("m9", "SS", .pitch(.swingingStrike),
            Outcome(outs: 3, runners: [on("m6", .third, by: "d9"), on("m8", .first, by: "d9")],
                    outsMade: [out("m9", putout: "d8")], result: .strikeout, notation: "K"))

        // MARK: Bottom of the 2nd.
        s.plateAppearance("d7", "", .inPlay(Play(batterResult: .out, battedBall: .groundBall, fielders: [.thirdBase, .firstBase],
                                                  runners: [move("d7", .home, .out, outBy: [.thirdBase, .firstBase], at: .first)])),
            Outcome(outs: 1, outsMade: [out("d7", putout: "m3", assists: ["m5"], at: .first)], result: .out, notation: "5-3"))

        s.plateAppearance("d8", "BC", .inPlay(Play(batterResult: .out, battedBall: .flyBall, fielders: [.leftField],
                                                    runners: [move("d8", .home, .out, outBy: [.leftField])])),
            Outcome(outs: 2, outsMade: [out("d8", putout: "m4")], result: .out, notation: "F7"))

        s.plateAppearance("d9", "FFB", .inPlay(Play(batterResult: .single, battedBall: .groundBall, hitLocation: .rightField,
                                                     runners: [move("d9", .home, .first)])),
            Outcome(outs: 2, runners: [on("d9", .first, by: "m9")], result: .single, reached: true, notation: "1B 9"))

        s.plateAppearance("d10", "BBC", .inPlay(Play(batterResult: .double, battedBall: .lineDrive, hitLocation: .leftField,
                                                      runners: [move("d9", .first, .third), move("d10", .home, .second)])),
            Outcome(outs: 2, runners: [on("d9", .third, by: "m9"), on("d10", .second, by: "m9")],
                    result: .double, reached: true, notation: "2B 7"))

        s.plateAppearance("d1", "CSBBF", .inPlay(Play(batterResult: .out, battedBall: .groundBall, fielders: [.shortstop, .firstBase],
                                                       runners: [move("d1", .home, .out, outBy: [.shortstop, .firstBase], at: .first)])),
            Outcome(outs: 3, runners: [on("d9", .third, by: "m9"), on("d10", .second, by: "m9")],
                    outsMade: [out("d1", putout: "m3", assists: ["m2"], at: .first)], result: .out, notation: "6-3"))

        // MARK: Top of the 3rd.
        s.lineupChange(.defenseConfirmed(DefenseConfirmed(team: .home)), notation: "")

        s.plateAppearance("m1", "C", .inPlay(Play(batterResult: .triple, battedBall: .lineDrive, hitLocation: .rightField,
                                                   runners: [move("m1", .home, .third)])),
            Outcome(outs: 0, runners: [on("m1", .third, by: "d9")], result: .triple, reached: true, notation: "3B 9"))

        s.plateAppearance("m2", "B", .inPlay(Play(batterResult: .sacrificeFly, battedBall: .flyBall, fielders: [.centerField],
                                                   runners: [move("m2", .home, .out, outBy: [.centerField]), move("m1", .third, .scored)],
                                                   rbi: 1)),
            Outcome(outs: 1, runs: [run("m1", charged: "d9")], outsMade: [out("m2", putout: "d3")],
                    result: .sacrificeFly, rbi: 1, notation: "SF 8"))

        s.plateAppearance("m3", "BCBF", .inPlay(Play(batterResult: .single, battedBall: .lineDrive, hitLocation: .rightField,
                                                      runners: [move("m3", .home, .first)])),
            Outcome(outs: 1, runners: [on("m3", .first, by: "d9")], result: .single, reached: true, notation: "1B 9"))

        // Diaz lines to second, who throws to first to double off Hale.
        s.plateAppearance("m4", "SB", .inPlay(Play(batterResult: .out, battedBall: .lineDrive, fielders: [.secondBase, .firstBase],
                                                    runners: [move("m4", .home, .out, outBy: [.secondBase]),
                                                              move("m3", .first, .out, outBy: [.secondBase, .firstBase], at: .first)],
                                                    multiOut: .doublePlay)),
            Outcome(outs: 3, outsMade: [out("m4", putout: "d1"), out("m3", putout: "d4", assists: ["d1"], at: .first)],
                    result: .out, notation: "L4-3 DP"))

        // MARK: Bottom of the 3rd.
        s.plateAppearance("d2", "BB", .inPlay(Play(batterResult: .homeRun, battedBall: .flyBall, hitLocation: .rightField,
                                                    runners: [move("d2", .home, .scored)], rbi: 1)),
            Outcome(outs: 0, runs: [run("d2", charged: "m9")], result: .homeRun, rbi: 1, reached: true, notation: "HR 9"))

        s.plateAppearance("d3", "CCB", .pitch(.swingingStrike),
            Outcome(outs: 1, outsMade: [out("d3", putout: "m7")], result: .strikeout, notation: "K"))

        s.plateAppearance("d4", "B", .inPlay(Play(batterResult: .single, battedBall: .groundBall, hitLocation: .leftField,
                                                   runners: [move("d4", .home, .first)])),
            Outcome(outs: 1, runners: [on("d4", .first, by: "m9")], result: .single, reached: true, notation: "1B 7"))

        // Quinn is a designated non-runner, so Webb, who made the last out, runs for them
        // (league rule 9.11 D). Webb is caught stealing with Shaw up 1-0; the caught stealing
        // is Webb's.
        s.runnerForNonRunner("d3", replacing: "d4", notation: "R Webb for Quinn")
        s.pitches("B", to: "d5")
        s.runnerAction(RunnerAction(moves: [move("d3", .first, .out, outBy: [.catcher, .shortstop], at: .second, reason: .caughtStealing)]),
                       batter: "d5",
            Outcome(outs: 2, outsMade: [out("d3", putout: "m2", assists: ["m7"], at: .second)], notation: "CS2 2-6"))
        s.plateAppearance("d5", "C", .inPlay(Play(batterResult: .out, battedBall: .flyBall, fielders: [.rightField],
                                                   runners: [move("d5", .home, .out, outBy: [.rightField])])),
            Outcome(outs: 3, outsMade: [out("d5", putout: "m6")], result: .out, notation: "F9"))

        // MARK: Top of the 4th.
        s.lineupChange(.defenseConfirmed(DefenseConfirmed(team: .home)), notation: "")

        s.plateAppearance("m5", "BF", .inPlay(Play(batterResult: .single, battedBall: .groundBall, hitLocation: .centerField,
                                                    runners: [move("m5", .home, .first)])),
            Outcome(outs: 0, runners: [on("m5", .first, by: "d9")], result: .single, reached: true, notation: "1B 8"))

        s.plateAppearance("m6", "C", .inPlay(Play(batterResult: .out, battedBall: .groundBall, fielders: [.firstBase],
                                                   runners: [move("m5", .first, .second),
                                                             move("m6", .home, .out, outBy: [.firstBase], at: .first)])),
            Outcome(outs: 1, runners: [on("m5", .second, by: "d9")], outsMade: [out("m6", putout: "d4", at: .first)],
                    result: .out, notation: "3U"))

        s.plateAppearance("m7", "BBBC", .pitch(.ball),
            Outcome(outs: 1, runners: [on("m5", .second, by: "d9"), on("m7", .first, by: "d9")],
                    result: .walk, reached: true, notation: "BB"))

        s.plateAppearance("m8", "", .inPlay(Play(batterResult: .single, battedBall: .groundBall, hitLocation: .leftField,
                                                  runners: [move("m5", .second, .scored), move("m7", .first, .second),
                                                            move("m8", .home, .first)], rbi: 1)),
            Outcome(outs: 1, runners: [on("m7", .second, by: "d9"), on("m8", .first, by: "d9")], runs: [run("m5", charged: "d9")],
                    result: .single, rbi: 1, reached: true, notation: "1B 7"))

        // Moss pinch-hits for Collins.
        s.lineupChange(.substitution(Substitution(team: .away, batting: [
            BattingChange(kind: .pinchHitter, incoming: "m10", replacing: "m9"),
        ])), notation: "PH Moss for Collins") { s in
            s.away.battingOrder.slots[8].players.append("m10")
        }

        s.plateAppearance("m10", "SF", .inPlay(Play(batterResult: .out, battedBall: .popUp, fielders: [.shortstop],
                                                     runners: [move("m10", .home, .out, outBy: [.shortstop])])),
            Outcome(outs: 2, runners: [on("m7", .second, by: "d9"), on("m8", .first, by: "d9")],
                    outsMade: [out("m10", putout: "d2")], result: .out, notation: "P6"))

        s.plateAppearance("m1", "B", .inPlay(Play(batterResult: .out, battedBall: .groundBall, fielders: [.secondBase, .firstBase],
                                                   runners: [move("m1", .home, .out, outBy: [.secondBase, .firstBase], at: .first)])),
            Outcome(outs: 3, runners: [on("m7", .second, by: "d9"), on("m8", .first, by: "d9")],
                    outsMade: [out("m1", putout: "d4", assists: ["d1"], at: .first)], result: .out, notation: "4-3"))

        // MARK: Bottom of the 4th. Reyes comes in to pitch and takes Moss's spot in the order.
        s.lineupChange(.pitchingChange(PitchingChange(team: .away, newPitcher: "m12", takesBattingSpotOf: "m10")),
                       notation: "P Reyes") { s in
            s.away.battingOrder.slots[8].players.append("m12")
            s.away.fielders = s.away.fielders.map { $0.position == .pitcher ? FielderAssignment(position: .pitcher, player: "m12") : $0 }
        }

        s.plateAppearance("d6", "BCB", .pitch(.hitByPitch),
            Outcome(outs: 0, runners: [on("d6", .first, by: "m12")], result: .hitByPitch, reached: true, notation: "HBP"))

        s.plateAppearance("d7", "", .inPlay(Play(batterResult: .single, battedBall: .lineDrive, hitLocation: .rightField,
                                                  runners: [move("d6", .first, .third), move("d7", .home, .first)])),
            Outcome(outs: 0, runners: [on("d6", .third, by: "m12"), on("d7", .first, by: "m12")],
                    result: .single, reached: true, notation: "1B 9"))

        s.plateAppearance("d8", "B", .inPlay(Play(batterResult: .sacrificeFly, battedBall: .flyBall, fielders: [.leftField],
                                                   runners: [move("d8", .home, .out, outBy: [.leftField]), move("d6", .third, .scored)],
                                                   rbi: 1)),
            Outcome(outs: 1, runners: [on("d7", .first, by: "m12")], runs: [run("d6", charged: "m12")],
                    outsMade: [out("d8", putout: "m4")], result: .sacrificeFly, rbi: 1, notation: "SF 7"))

        s.plateAppearance("d9", "SSFB", .inPlay(Play(batterResult: .out, battedBall: .groundBall, fielders: [6, 4, 3].positions,
                                                      runners: [move("d7", .first, .out, outBy: [6, 4].positions, at: .second),
                                                                move("d9", .home, .out, outBy: [4, 3].positions, at: .first)],
                                                      multiOut: .doublePlay)),
            Outcome(outs: 3, outsMade: [out("d7", putout: "m8", assists: ["m2"], at: .second),
                                        out("d9", putout: "m3", assists: ["m8"], at: .first)],
                    result: .out, notation: "6-4-3 DP"))

        // MARK: Top of the 5th. Voss comes in to pitch and takes Barros's spot in the order.
        s.lineupChange(.pitchingChange(PitchingChange(team: .home, newPitcher: "d12", takesBattingSpotOf: "d9")),
                       notation: "P Voss") { s in
            s.home.battingOrder.slots[8].players.append("d12")
            s.home.fielders = s.home.fielders.map { $0.position == .pitcher ? FielderAssignment(position: .pitcher, player: "d12") : $0 }
        }
        s.lineupChange(.defenseConfirmed(DefenseConfirmed(team: .home)), notation: "")

        s.plateAppearance("m2", "BB", .inPlay(Play(batterResult: .double, battedBall: .lineDrive, hitLocation: .leftField,
                                                    runners: [move("m2", .home, .second)])),
            Outcome(outs: 0, runners: [on("m2", .second, by: "d12")], result: .double, reached: true, notation: "2B 7"))

        s.plateAppearance("m3", "CBS", .inPlay(Play(batterResult: .out, battedBall: .groundBall, fielders: [.secondBase, .firstBase],
                                                     runners: [move("m2", .second, .third),
                                                               move("m3", .home, .out, outBy: [.secondBase, .firstBase], at: .first)])),
            Outcome(outs: 1, runners: [on("m2", .third, by: "d12")], outsMade: [out("m3", putout: "d4", assists: ["d1"], at: .first)],
                    result: .out, notation: "4-3"))

        s.plateAppearance("m4", "", .intentionalWalk,
            Outcome(outs: 1, runners: [on("m2", .third, by: "d12"), on("m4", .first, by: "d12")],
                    result: .intentionalWalk, reached: true, notation: "IBB"))

        s.plateAppearance("m5", "BCFF", .pitch(.swingingStrike),
            Outcome(outs: 2, runners: [on("m2", .third, by: "d12"), on("m4", .first, by: "d12")],
                    outsMade: [out("m5", putout: "d8")], result: .strikeout, notation: "K"))

        s.plateAppearance("m6", "", .inPlay(Play(batterResult: .out, battedBall: .flyBall, fielders: [.rightField],
                                                  runners: [move("m6", .home, .out, outBy: [.rightField])])),
            Outcome(outs: 3, runners: [on("m2", .third, by: "d12"), on("m4", .first, by: "d12")],
                    outsMade: [out("m6", putout: "d7")], result: .out, notation: "F9"))

        // MARK: Bottom of the 5th.
        s.plateAppearance("d10", "B", .inPlay(Play(batterResult: .single, battedBall: .groundBall, hitLocation: .centerField,
                                                    runners: [move("d10", .home, .first)])),
            Outcome(outs: 0, runners: [on("d10", .first, by: "m12")], result: .single, reached: true, notation: "1B 8"))

        // Cole steals second with Moreno up 1-0, then Moreno singles Cole home.
        s.pitches("B", to: "d1")
        s.runnerAction(RunnerAction(moves: [move("d10", .first, .second, reason: .stolenBase)]), batter: "d1",
            Outcome(outs: 0, runners: [on("d10", .second, by: "m12")], notation: "SB2"))
        s.plateAppearance("d1", "C", .inPlay(Play(batterResult: .single, battedBall: .lineDrive, hitLocation: .rightField,
                                                   runners: [move("d10", .second, .scored), move("d1", .home, .first)], rbi: 1)),
            Outcome(outs: 0, runners: [on("d1", .first, by: "m12")], runs: [run("d10", charged: "m12")],
                    result: .single, rbi: 1, reached: true, notation: "1B 9"))

        s.plateAppearance("d2", "F", .inPlay(Play(batterResult: .out, battedBall: .flyBall, fielders: [.centerField],
                                                   runners: [move("d2", .home, .out, outBy: [.centerField])])),
            Outcome(outs: 1, runners: [on("d1", .first, by: "m12")], outsMade: [out("d2", putout: "m1")], result: .out, notation: "F8"))

        s.plateAppearance("d3", "BS", .inPlay(Play(batterResult: .reachedOnError, battedBall: .groundBall, fielders: [.thirdBase],
                                                    runners: [move("d1", .first, .second), move("d3", .home, .first, onError: true)],
                                                    errors: [ErrorCharge(fielder: .thirdBase, type: .fielding)])),
            Outcome(outs: 1, runners: [on("d1", .second, by: "m12"), on("d3", .first, by: "m12")],
                    errors: [ChargedError(fielder: .thirdBase, player: "m5")], result: .reachedOnError, reached: true, notation: "E5"))

        s.plateAppearance("d4", "", .inPlay(Play(batterResult: .out, battedBall: .groundBall, fielders: [4, 6, 3].positions,
                                                  runners: [move("d1", .second, .third),
                                                            move("d3", .first, .out, outBy: [4, 6].positions, at: .second),
                                                            move("d4", .home, .out, outBy: [6, 3].positions, at: .first)],
                                                  multiOut: .doublePlay)),
            Outcome(outs: 3, runners: [on("d1", .third, by: "m12")],
                    outsMade: [out("d3", putout: "m2", assists: ["m8"], at: .second),
                               out("d4", putout: "m3", assists: ["m2"], at: .first)],
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
