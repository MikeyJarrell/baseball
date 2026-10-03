// Made-up game setups: the sample game against the Mudcats, a game at the Bombers
// (known only by numbers), and a game against a team nobody knows. Each team's batting
// order and defense are separate lists.

import Foundation
import Model

public enum SampleSetups {
    /// When the sample games are scheduled: Saturday, May 2, 2026, 9:00 in the morning
    /// Pacific time, the league's usual start.
    public static let gameDay = Date(timeIntervalSince1970: 1_777_737_600)

    /// The Mudcats' batting order: nine hitters, pitcher Ray Collins batting ninth.
    static let mudcatsBattingOrder: [BattingOrderEntry] = (1...9).map {
        BattingOrderEntry(player: PlayerID(rawValue: "m\($0)"))
    }

    /// The Mudcats' defense.
    static let mudcatsDefense: [FielderAssignment] = [
        FielderAssignment(position: .pitcher, player: "m9"),
        FielderAssignment(position: .catcher, player: "m7"),
        FielderAssignment(position: .firstBase, player: "m3"),
        FielderAssignment(position: .secondBase, player: "m8"),
        FielderAssignment(position: .thirdBase, player: "m5"),
        FielderAssignment(position: .shortstop, player: "m2"),
        FielderAssignment(position: .leftField, player: "m4"),
        FielderAssignment(position: .centerField, player: "m1"),
        FielderAssignment(position: .rightField, player: "m6"),
    ]

    /// Our batting order: ten hitters, pitcher Sky Barros ninth and Jamie Cole tenth, who
    /// bats only.
    static func diamondDogsBattingOrder(designatedNonRunner: PlayerID? = nil) -> [BattingOrderEntry] {
        (1...10).map {
            let id = PlayerID(rawValue: "d\($0)")
            return BattingOrderEntry(player: id, isDesignatedNonRunner: id == designatedNonRunner)
        }
    }

    /// Our defense.
    static let diamondDogsDefense: [FielderAssignment] = [
        FielderAssignment(position: .pitcher, player: "d9"),
        FielderAssignment(position: .catcher, player: "d8"),
        FielderAssignment(position: .firstBase, player: "d4"),
        FielderAssignment(position: .secondBase, player: "d1"),
        FielderAssignment(position: .thirdBase, player: "d5"),
        FielderAssignment(position: .shortstop, player: "d2"),
        FielderAssignment(position: .leftField, player: "d6"),
        FielderAssignment(position: .centerField, player: "d3"),
        FielderAssignment(position: .rightField, player: "d7"),
    ]

    /// The Diamond Dogs, from the saved roster. Robin Nash and Taylor Voss start on the bench.
    static func diamondDogs(designatedNonRunner: PlayerID? = nil) -> GameTeam {
        GameTeam(teamID: SampleTeams.diamondDogs.id, name: "Diamond Dogs", isOurs: true,
                 roster: SampleTeams.diamondDogs.roster,
                 battingOrder: diamondDogsBattingOrder(designatedNonRunner: designatedNonRunner),
                 defense: diamondDogsDefense)
    }

    /// The sample game: Mudcats at Diamond Dogs, under the league's rules (nine innings, a
    /// three-hour time limit, the 12-run rule after seven). Pat Quinn, our first baseman batting
    /// fourth, is a designated non-runner.
    public static let mudcatsAtDiamondDogs = GameSetup(
        scheduledStart: gameDay,
        away: GameTeam(teamID: SampleTeams.mudcats.id, name: "Mudcats", isOurs: false,
                       roster: SampleTeams.mudcats.roster, battingOrder: mudcatsBattingOrder, defense: mudcatsDefense),
        home: diamondDogs(designatedNonRunner: "d4")
    )

    /// Diamond Dogs at the Bombers, who are known only by jersey numbers. Their fielders are
    /// unknown except their pitcher, number 44, who does not bat.
    public static let diamondDogsAtBombers = GameSetup(
        scheduledStart: gameDay.addingTimeInterval(7 * 24 * 3600),
        away: diamondDogs(),
        home: GameTeam(teamID: SampleTeams.bombers.id, name: "Bombers", isOurs: false,
                       roster: SampleTeams.bombers.roster,
                       battingOrder: (1...9).map { BattingOrderEntry(player: PlayerID(rawValue: "b\($0)")) },
                       defense: [FielderAssignment(position: .pitcher, player: "b11")])
    )

    /// Riverhawks at Diamond Dogs, a championship game where nobody knows the Riverhawks'
    /// lineup: nine placeholder hitters ("Batter 1" to "Batter 9") and a placeholder pitcher
    /// who does not bat.
    public static let unknownAtDiamondDogs: GameSetup = {
        let riverhawks = SampleTeams.unknown()
        return GameSetup(
            scheduledStart: gameDay.addingTimeInterval(14 * 24 * 3600),
            away: GameTeam(teamID: riverhawks.id, name: riverhawks.name, isOurs: false, roster: riverhawks.roster,
                           battingOrder: (1...9).map { BattingOrderEntry(player: PlayerID(rawValue: "r\($0)")) },
                           defense: [FielderAssignment(position: .pitcher, player: "rp")]),
            home: diamondDogs(),
            rules: .championship
        )
    }()
}
