// Made-up pregame inputs built from SampleData, for the previews, the tests and a harness app.
//
// Our last game was at the Bombers (known only by numbers) on May 9; the game before that was
// the Mudcats at home on May 2, with Pat Quinn and Robin Nash taking turns at first base. The
// saved opponents are the Mudcats (full roster), the Bombers (numbers only) and the Riverhawks
// (no saved roster, so their lineup is unknown). Today is Saturday, May 23.

import Foundation
import Model
import SampleData

/// Sample pregame inputs.
public enum PregameSamples {
    /// The game before last, May 2: Mudcats at Diamond Dogs, first base shared by turns.
    static let mudcatsGame = SampleSetups.mudcatsAtDiamondDogsAlternatingFirstBase
    /// Last game, May 9: Diamond Dogs at the Bombers.
    static let bombersGame = SampleSetups.diamondDogsAtBombers

    /// Today: two weeks after the Bombers game, at 8 in the morning.
    public static let today = SampleSetups.gameDay.addingTimeInterval(21 * 24 * 3600 - 3600)

    /// A saved opponent we know nothing about yet.
    public static let riverhawks = Team(id: "riverhawks", name: "Riverhawks")

    /// Who has pitched lately, as the app shell would read it from box scores.
    public static let pitchingHistory: [PitchingAppearance] = [
        PitchingAppearance(player: "d9", date: mudcatsGame.scheduledStart, started: true),
        PitchingAppearance(player: "d12", date: mudcatsGame.scheduledStart, started: false),
        PitchingAppearance(player: "d9", date: bombersGame.scheduledStart, started: true),
        PitchingAppearance(player: "d12", date: bombersGame.scheduledStart, started: false),
        PitchingAppearance(player: "m9", date: mudcatsGame.scheduledStart, started: true),
        PitchingAppearance(player: "m12", date: mudcatsGame.scheduledStart, started: false),
        PitchingAppearance(player: "b11", date: bombersGame.scheduledStart, started: true),
    ]

    /// A season under way: starting from last game's lineup.
    public static let input = PregameInput(
        ourTeam: SampleTeams.diamondDogs,
        opponents: [SampleTeams.mudcats, SampleTeams.bombers, riverhawks],
        recentGames: [bombersGame, mudcatsGame],
        pitchingHistory: pitchingHistory,
        today: today
    )

    /// Our team before the first game, with each player's usual position and role filled in
    /// as the roster screen would record them: Moreno usually leads off, Cole bats only, and
    /// Nash and Voss usually start on the bench.
    public static let diamondDogsWithUsuals: Team = {
        let usual: [PlayerID: (Position?, UsualRole, Bool)] = [
            "d1": (.secondBase, .batsAndFields, true),
            "d2": (.shortstop, .batsAndFields, false),
            "d3": (.centerField, .batsAndFields, false),
            "d4": (.firstBase, .batsAndFields, false),
            "d5": (.thirdBase, .batsAndFields, false),
            "d6": (.leftField, .batsAndFields, false),
            "d7": (.rightField, .batsAndFields, false),
            "d8": (.catcher, .batsAndFields, false),
            "d9": (.pitcher, .batsAndFields, false),
            "d10": (nil, .batsOnly, false),
            "d11": (.firstBase, .startsOnBench, false),
            "d12": (.pitcher, .startsOnBench, false),
        ]
        var team = SampleTeams.diamondDogs
        for i in team.roster.indices {
            guard let (position, role, leadsOff) = usual[team.roster[i].id] else { continue }
            team.roster[i].usualPosition = position
            team.roster[i].usualRole = role
            team.roster[i].usuallyLeadsOff = leadsOff
        }
        return team
    }()

    /// Before our first game: no games yet, so our lineup starts from the roster.
    public static let firstGameInput = PregameInput(
        ourTeam: diamondDogsWithUsuals,
        opponents: [SampleTeams.mudcats, SampleTeams.bombers, riverhawks],
        today: today
    )

    /// A draft with an opponent already picked, for opening the sequence partway through.
    public static func draft(against opponent: TeamID, input: PregameInput = input) -> PregameDraft {
        var draft = PregameDraft(input: input, newOpponentID: "new-opponent")
        draft.chooseOpponent(.saved(opponent))
        return draft
    }
}

extension PregameFlow {
    /// The sequence opened at one step against one sample opponent, for previews and a harness
    /// app: `PregameFlow.sample(against: "bombers", at: .theirs)`.
    public static func sample(against opponent: TeamID, at step: PregameStep, firstGame: Bool = false,
                              onFinish: @escaping (PregameResult) -> Void = { _ in }) -> PregameFlow {
        let input = firstGame ? PregameSamples.firstGameInput : PregameSamples.input
        return PregameFlow(draft: PregameSamples.draft(against: opponent, input: input), startingAt: step, onFinish: onFinish)
    }
}
