// Made-up game setups: the sample game against the Cardinals, a game at the Bombers
// (known only by numbers), and a game against a team nobody knows.

import Foundation
import Model

public enum SampleSetups {
    /// When the sample games are played: May 2, 2026, 11:30 in the morning Pacific time.
    public static let gameDay = Date(timeIntervalSince1970: 1_777_746_600)

    /// The Cardinals' usual lineup: nine hitters, pitcher Ray Collins batting ninth.
    static let cardinalsLineup: [LineupEntry] = [
        LineupEntry(player: "c1", position: .centerField),
        LineupEntry(player: "c2", position: .shortstop),
        LineupEntry(player: "c3", position: .firstBase),
        LineupEntry(player: "c4", position: .leftField),
        LineupEntry(player: "c5", position: .thirdBase),
        LineupEntry(player: "c6", position: .rightField),
        LineupEntry(player: "c7", position: .catcher),
        LineupEntry(player: "c8", position: .secondBase),
        LineupEntry(player: "c9", position: .pitcher),
    ]

    /// Our usual lineup: ten hitters, pitcher Sky Barros batting ninth and Jamie Cole
    /// tenth as an extra hitter.
    static func mudcatsLineup(designatedNonRunner: PlayerID? = nil) -> [LineupEntry] {
        let entries: [(PlayerID, Position?)] = [
            ("m1", .secondBase), ("m2", .shortstop), ("m3", .centerField), ("m4", .firstBase),
            ("m5", .thirdBase), ("m6", .leftField), ("m7", .rightField), ("m8", .catcher),
            ("m9", .pitcher), ("m10", nil),
        ]
        return entries.map { LineupEntry(player: $0.0, position: $0.1, isDesignatedNonRunner: $0.0 == designatedNonRunner) }
    }

    /// The Mudcats as the home team, from the saved roster.
    static func mudcatsAtHome(designatedNonRunner: PlayerID? = nil) -> GameTeam {
        GameTeam(teamID: SampleTeams.mudcats.id, name: "Mudcats", isOurs: true,
                 roster: SampleTeams.mudcats.roster, lineup: mudcatsLineup(designatedNonRunner: designatedNonRunner))
    }

    /// The sample game: Cardinals at Mudcats, nine innings scheduled, a 100-minute time limit.
    public static let cardinalsAtMudcats = GameSetup(
        date: gameDay,
        away: GameTeam(teamID: SampleTeams.cardinals.id, name: "Cardinals", isOurs: false,
                       roster: SampleTeams.cardinals.roster, lineup: cardinalsLineup),
        home: mudcatsAtHome(),
        scheduledInnings: 9,
        timeLimitMinutes: 100
    )

    /// The same game with our leadoff hitter, Alex Moreno, a designated non-runner.
    public static let cardinalsAtMudcatsWithNonRunner: GameSetup = {
        var setup = cardinalsAtMudcats
        setup.home = mudcatsAtHome(designatedNonRunner: "m1")
        return setup
    }()

    /// Mudcats at the Bombers, who are known only by jersey numbers. Their fielding positions
    /// are unknown except their pitcher, number 44, who does not bat.
    public static let mudcatsAtBombers = GameSetup(
        date: gameDay.addingTimeInterval(7 * 24 * 3600),
        away: GameTeam(teamID: SampleTeams.mudcats.id, name: "Mudcats", isOurs: true,
                       roster: SampleTeams.mudcats.roster, lineup: mudcatsLineup()),
        home: GameTeam(teamID: SampleTeams.bombers.id, name: "Bombers", isOurs: false,
                       roster: SampleTeams.bombers.roster,
                       lineup: (1...9).map { LineupEntry(player: PlayerID(rawValue: "b\($0)")) },
                       fieldersNotBatting: [FielderAssignment(position: .pitcher, player: "b11")]),
        scheduledInnings: 9
    )

    /// Riverhawks at Mudcats, where nobody knows the Riverhawks' lineup: nine placeholder
    /// hitters ("Batter 1" to "Batter 9") and a placeholder pitcher who does not bat.
    public static let unknownAtMudcats: GameSetup = {
        let riverhawks = SampleTeams.unknown()
        return GameSetup(
            date: gameDay.addingTimeInterval(14 * 24 * 3600),
            away: GameTeam(teamID: riverhawks.id, name: riverhawks.name, isOurs: false, roster: riverhawks.roster,
                           lineup: (1...9).map { LineupEntry(player: PlayerID(rawValue: "r\($0)")) },
                           fieldersNotBatting: [FielderAssignment(position: .pitcher, player: "rp")]),
            home: mudcatsAtHome(),
            scheduledInnings: 9
        )
    }()
}
