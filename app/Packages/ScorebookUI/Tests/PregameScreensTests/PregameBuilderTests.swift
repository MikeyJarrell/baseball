// Tests for the pregame screens' setup building: where our lineup starts (last game, or the
// roster before the first game), the three lists and how players move between them, designated
// non-runners past the league's limit, positions shared by turns, their lineup three ways,
// starting pitchers most recent first, the time limit as a clock time, and the finished setup.
//
// The sample data is in PregameSamples: our last game was at the Bombers on May 9, the one
// before it the Mudcats at home on May 2, and today is Saturday, May 23.

import Foundation
import Testing
import Model
import SampleData
@testable import PregameScreens

/// Pacific time and American English, so dates and clock times read the same on any Mac.
private let pacific: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
    calendar.locale = Locale(identifier: "en_US")
    return calendar
}()

private let roster = SampleTeams.diamondDogs.roster

/// A clock time with Apple's narrow no-break space before "AM" turned into an ordinary space.
private func clock(_ date: Date) -> String {
    PregameWording.clock(date, calendar: pacific).replacingOccurrences(of: "\u{202F}", with: " ")
}

// MARK: - Where our lineup starts

@Suite("Our lineup starts from last game or the roster")
struct LineupStartTests {
    @Test("Last game's batting order, fielders, non-runner and shared first base carry over")
    func fromLastGame() {
        let last = SampleSetups.mudcatsAtDiamondDogsAlternatingFirstBase.home
        let lineup = OurLineup.fromLastGame(last, roster: roster)
        #expect(lineup.battingOrder == (1...10).map { PlayerID(rawValue: "d\($0)") })
        #expect(lineup.defense[.pitcher] == "d9")
        #expect(lineup.defense[.firstBase] == "d4")
        #expect(lineup.nonRunners == ["d4"])
        #expect(lineup.alternates[.firstBase] == "d11")
        // Nash only takes turns at first, and Voss does nothing: both start on the bench.
        #expect(lineup.bench.map(\.id) == ["d11", "d12"])
    }

    @Test("A player gone from the roster drops out; a new player starts on the bench")
    func rosterChangedSinceLastGame() {
        let last = SampleSetups.mudcatsAtDiamondDogs.home
        var today = roster.filter { $0.id != "d3" }   // Webb, the center fielder batting third, is gone
        today.append(Player(id: "d13", name: "Sam New", number: "50"))
        let lineup = OurLineup.fromLastGame(last, roster: today)
        #expect(!lineup.battingOrder.contains("d3"))
        #expect(lineup.battingOrder.count == 9)
        #expect(lineup.defense[.centerField] == nil)
        #expect(lineup.emptyPositions == [.centerField])
        #expect(lineup.bench.map(\.id).contains("d13"))
    }

    @Test("Before the first game: usual positions, the leadoff hitter first, the usual bench on the bench")
    func fromRoster() {
        let lineup = OurLineup.fromRoster(PregameSamples.diamondDogsWithUsuals.roster)
        #expect(lineup.battingOrder.first == "d1")
        #expect(lineup.battingOrder.count == 10)
        #expect(!lineup.battingOrder.contains("d11"))
        #expect(!lineup.battingOrder.contains("d12"))
        #expect(lineup.bench.map(\.id) == ["d11", "d12"])
        // Quinn and Nash both usually play first; Nash starts on the bench, so Quinn has it.
        #expect(lineup.defense[.firstBase] == "d4")
        #expect(lineup.defense[.pitcher] == "d9")
        #expect(lineup.emptyPositions.isEmpty)
        // Cole bats only.
        #expect(lineup.position(of: "d10") == nil)
    }

    @Test("Only fielding keeps a player out of the batting order; no role set means bat and field")
    func fieldsOnlyAndNoRole() {
        var roster = PregameSamples.diamondDogsWithUsuals.roster
        // Barros (d9) fields but does not bat; Cole (d10) has no role set and no position.
        roster[8].usualRole = .fieldsOnly
        roster[9].usualRole = nil
        let lineup = OurLineup.fromRoster(roster)
        #expect(!lineup.battingOrder.contains("d9"))
        #expect(lineup.defense[.pitcher] == "d9")
        #expect(lineup.battingOrder.contains("d10"))
        #expect(lineup.position(of: "d10") == nil)
    }

    @Test("The draft starts from last game when there is one, and from the roster when there is not")
    func draftPicksTheStart() {
        let season = PregameDraft(input: PregameSamples.input)
        #expect(season.lineupStartedFrom == SampleSetups.diamondDogsAtBombers)
        #expect(season.ours.nonRunners.isEmpty)   // nobody was a non-runner at the Bombers
        let first = PregameDraft(input: PregameSamples.firstGameInput)
        #expect(first.lineupStartedFrom == nil)
        #expect(first.ours.battingOrder.first == "d1")
    }
}

// MARK: - The three lists

@Suite("Batting order, fielders and bench are separate lists")
struct ThreeListsTests {
    private func lineup() -> OurLineup {
        OurLineup.fromLastGame(SampleSetups.mudcatsAtDiamondDogsAlternatingFirstBase.home, roster: roster)
    }

    @Test("Taking a fielder out of the batting order keeps them in the field and ends their non-runner declaration")
    func removeFromOrder() {
        var lineup = lineup()
        lineup.removeFromOrder("d4")
        #expect(!lineup.isBatting("d4"))
        #expect(lineup.position(of: "d4") == .firstBase)
        #expect(lineup.nonRunners.isEmpty)
        #expect(!lineup.bench.contains { $0.id == "d4" })
        #expect(PregameWording.fieldingLine(for: "d4", in: lineup) == "First base, odd innings")
    }

    @Test("A bench player added to the order bats last; adding twice changes nothing")
    func addToOrder() {
        var lineup = lineup()
        lineup.addToOrder("d12")
        lineup.addToOrder("d12")
        #expect(lineup.battingOrder.last == "d12")
        #expect(lineup.battingOrder.count == 11)
        #expect(PregameWording.fieldingLine(for: "d12", in: lineup) == "DH")
    }

    @Test("Dragging the ninth hitter to leadoff moves everyone else down one")
    func dragToTop() {
        var lineup = lineup()
        lineup.moveInOrder(fromOffsets: [8], toOffset: 0)
        #expect(lineup.battingOrder.prefix(3) == ["d9", "d1", "d2"])
        lineup.moveInOrder(fromOffsets: [0], toOffset: 10)
        #expect(lineup.battingOrder.last == "d9")
        lineup.moveHitter("d1", by: 1)
        #expect(lineup.battingOrder.prefix(2) == ["d2", "d1"])
    }

    @Test("Putting the center fielder at shortstop swaps him with the shortstop")
    func swapFielders() {
        var lineup = lineup()
        lineup.assign("d3", to: .shortstop)
        #expect(lineup.defense[.shortstop] == "d3")
        #expect(lineup.defense[.centerField] == "d2")
    }

    @Test("A bench player at pitcher sends the old pitcher out of the field, still batting")
    func benchPlayerPitches() {
        var lineup = lineup()
        lineup.assign("d12", to: .pitcher)
        #expect(lineup.defense[.pitcher] == "d12")
        #expect(lineup.position(of: "d9") == nil)
        #expect(lineup.isBatting("d9"))
        #expect(!lineup.isBatting("d12"))   // Voss pitches without batting
    }

    @Test("Emptying a position leaves nobody there, and nothing else changes")
    func emptyPosition() {
        var lineup = lineup()
        lineup.assign(nil, to: .leftField)
        #expect(lineup.emptyPositions == [.leftField])
        #expect(lineup.isBatting("d6"))
    }
}

// MARK: - Designated non-runners

@Suite("Designated non-runners: two allowed, more after asking")
struct NonRunnerTests {
    @Test("The third non-runner asks first, then is allowed; a non-runner can be taken back")
    func pastTheLimit() {
        var lineup = OurLineup.fromLastGame(SampleSetups.mudcatsAtDiamondDogs.home, roster: roster)
        #expect(lineup.nonRunnerTap(for: "d1", limit: 2) == .declare)
        lineup.setNonRunner("d1", true)
        #expect(lineup.nonRunnerTap(for: "d2", limit: 2) == .pastLimit(limit: 2))
        lineup.setNonRunner("d2", true)   // the scorer confirmed
        #expect(lineup.nonRunners == ["d4", "d1", "d2"])
        #expect(lineup.nonRunnerTap(for: "d4", limit: 2) == .undeclare)
        // The setup lists them in batting order, the way the lineup card reads.
        #expect(lineup.gameTeam(for: SampleTeams.diamondDogs).designatedNonRunners == ["d1", "d2", "d4"])
    }

    @Test("The review step notes a third non-runner but still lets the game start")
    func reviewNotesIt() throws {
        var draft = PregameSamples.draft(against: "mudcats")
        for id: PlayerID in ["d1", "d2", "d3"] { draft.ours.setNonRunner(id, true) }
        #expect(draft.notes.contains("3 designated non-runners; the league allows 2."))
        #expect(draft.missing == nil)
        let setup = try #require(draft.setup(calendar: pacific))
        #expect(setup.home.designatedNonRunners.count == 3)
    }

    @Test("Only a hitter can be declared")
    func onlyHitters() {
        var lineup = OurLineup(roster: roster, battingOrder: ["d1"])
        lineup.setNonRunner("d12", true)
        #expect(lineup.nonRunners.isEmpty)
    }
}

// MARK: - Positions shared by turns

@Suite("A position shared by turns, odd and even innings")
struct AlternatingTests {
    @Test("Nash takes first base in even innings; the defense check gets the right one each inning")
    func rotationIntoTheSetup() {
        var lineup = OurLineup.fromLastGame(SampleSetups.mudcatsAtDiamondDogs.home, roster: roster)
        lineup.setAlternate("d11", at: .firstBase)
        let team = lineup.gameTeam(for: SampleTeams.diamondDogs)
        #expect(team.fieldingRotations == [FieldingRotation(position: .firstBase, players: ["d4", "d11"])])
        #expect(team.defense(forInning: 1, from: team.defense).first { $0.position == .firstBase }?.player == "d4")
        #expect(team.defense(forInning: 2, from: team.defense).first { $0.position == .firstBase }?.player == "d11")
        #expect(team.defense(forInning: 3, from: team.defense).first { $0.position == .firstBase }?.player == "d4")
    }

    @Test("A new starter at a shared position keeps the turns; the second player starting there ends them")
    func starterChanges() {
        var lineup = OurLineup.fromLastGame(SampleSetups.mudcatsAtDiamondDogsAlternatingFirstBase.home, roster: roster)
        lineup.assign("d10", to: .firstBase)
        #expect(lineup.alternates[.firstBase] == "d11")
        #expect(lineup.gameTeam(for: SampleTeams.diamondDogs).fieldingRotations.first?.players == ["d10", "d11"])
        lineup.assign("d11", to: .firstBase)
        #expect(lineup.alternates[.firstBase] == nil)
    }

    @Test("Ford, who starts in left, takes first in even innings: left is empty then, and the review says so")
    func starterTakesATurnElsewhere() {
        var draft = PregameSamples.draft(against: "mudcats")
        draft.ours.setAlternate("d6", at: .firstBase)
        #expect(draft.ours.emptyPositions(inInning: 1).isEmpty)
        #expect(draft.ours.emptyPositions(inInning: 2) == [.leftField])
        #expect(draft.notes == ["Nobody plays left field in even innings."])
        // Quinn taking left in even innings makes it a real flip-flop: nobody missing.
        draft.ours.setAlternate("d4", at: .leftField)
        #expect(draft.ours.emptyPositions(inInning: 2).isEmpty)
        #expect(draft.notes.isEmpty)
    }

    @Test("Nash picked for even innings at a second position gives up the first one")
    func oneEvenTurnEach() {
        var lineup = OurLineup.fromLastGame(SampleSetups.mudcatsAtDiamondDogsAlternatingFirstBase.home, roster: roster)
        lineup.setAlternate("d11", at: .rightField)
        #expect(lineup.alternates == [.rightField: "d11"])
        #expect(lineup.emptyPositions(inInning: 2).isEmpty)
    }

    @Test("Nash, who takes first in even innings, made our starting pitcher: the review notes nobody pitching then")
    func turnTakerPitches() {
        var draft = PregameDraft(input: PregameSamples.input)
        draft.chooseOpponent(.saved("mudcats"))
        draft.ours.setAlternate("d11", at: .firstBase)
        draft.ours.assign("d11", to: .pitcher)
        #expect(draft.ours.emptyPositions(inInning: 2) == [.pitcher])
        #expect(draft.notes == ["Nobody plays pitcher in even innings."])
        #expect(draft.missing == nil)   // a note, never a block
    }

    @Test("Emptying a shared position ends the turns too")
    func emptied() {
        var lineup = OurLineup.fromLastGame(SampleSetups.mudcatsAtDiamondDogsAlternatingFirstBase.home, roster: roster)
        lineup.assign(nil, to: .firstBase)
        #expect(lineup.alternates.isEmpty)
    }
}

// MARK: - Their lineup, three ways

@Suite("Their lineup: names and numbers, or numbers only")
struct TheirLineupTests {
    @Test("The Mudcats: names, their batting order from May 2, their May 2 starter pitching")
    func fullRoster() {
        let draft = PregameSamples.draft(against: "mudcats")
        let mudcats = SampleTeams.mudcats
        #expect(draft.theirs.mode == .names)
        #expect(draft.theirs.battingOrder(for: mudcats) == (1...9).map { PlayerID(rawValue: "m\($0)") })
        // Collins started and Reyes relieved on the same day: the starter comes first.
        #expect(draft.theirs.pitcher == "m9")
        #expect(draft.theirPitcherChoices.prefix(2).map(\.id) == ["m9", "m12"])
    }

    @Test("The Bombers: numbers only, and typed numbers that match the saved roster are those players")
    func numbersOnly() throws {
        var draft = PregameSamples.draft(against: "bombers")
        let bombers = SampleTeams.bombers
        #expect(draft.theirs.mode == .numbers)
        #expect(draft.theirs.numbers.map(\.number) == ["2", "5", "7", "9", "12", "16", "21", "23", "31"])
        #expect(draft.theirs.battingOrder(for: bombers) == (1...9).map { PlayerID(rawValue: "b\($0)") })
        // A new number joins as a new player; a blank number is a placeholder.
        draft.theirs.numbers[8].number = "88"
        draft.theirs.addNumber()
        let team = draft.theirs.gameTeam(for: bombers)
        let eighty8 = try #require(team.player(team.battingOrder[8]))
        #expect(eighty8.number == "88" && eighty8.name == nil)
        #expect(team.player(team.battingOrder[9])?.displayName == "Batter 10")
        #expect(team.startingPitcher == "b11")   // number 44 pitched against us May 9
    }

    @Test("The Riverhawks, with no saved roster: nine blank numbers, placeholders, and a placeholder pitcher who does not bat")
    func noSavedRoster() {
        let draft = PregameSamples.draft(against: "riverhawks")
        let riverhawks = PregameSamples.riverhawks
        #expect(draft.theirs.mode == .numbers)
        let team = draft.theirs.gameTeam(for: riverhawks)
        #expect(team.battingOrder.compactMap { team.player($0)?.displayName } == (1...9).map { "Batter \($0)" })
        let pitcher = team.startingPitcher
        #expect(pitcher.flatMap(team.player)?.displayName == "Pitcher")
        #expect(!team.battingOrder.contains(pitcher ?? ""))
    }

    @Test("A number typed in a Mudcats row is used in the game and saved back to their roster")
    func numberTypedInNamesRow() throws {
        var draft = PregameSamples.draft(against: "mudcats")
        #expect(draft.theirs.mode == .names)
        draft.theirs.setNumber("#2a3", for: "m3")   // Marcus Hale, #24 on the saved roster
        let setup = try #require(draft.setup(calendar: pacific))
        #expect(setup.away.player("m3")?.number == "23")
        let saved = PregameBuilder.updatedTeam(saved: SampleTeams.mudcats, from: setup.away)
        #expect(saved.player("m3")?.number == "23")
        #expect(saved.player("m3")?.name == "Marcus Hale")
        #expect(saved.roster.count == SampleTeams.mudcats.roster.count)
        // Erasing the number back to blank keeps the saved one.
        draft.theirs.setNumber("", for: "m3")
        #expect(draft.setup(calendar: pacific)?.away.player("m3")?.number == "24")
    }

    @Test("Numbers typed for a team with no saved roster join it; blanks do not")
    func numbersSavedToNewRoster() throws {
        var draft = PregameSamples.draft(against: "riverhawks")
        let first = try #require(draft.theirs.numbers.first?.id)
        draft.theirs.setNumber("17", forEntry: first)
        let setup = try #require(draft.setup(calendar: pacific))
        let saved = PregameBuilder.updatedTeam(saved: PregameSamples.riverhawks, from: setup.away)
        #expect(saved.roster.map(\.number) == ["17"])
    }

    @Test("Dragging reorders their batting order, both ways in")
    func dragTheirOrder() {
        var draft = PregameSamples.draft(against: "mudcats")
        draft.theirs.namedOrder.move(fromOffsets: [8], toOffset: 0)
        #expect(draft.theirs.battingOrder(for: SampleTeams.mudcats).prefix(2) == ["m9", "m1"])
        var bombers = PregameSamples.draft(against: "bombers")
        bombers.theirs.numbers.move(fromOffsets: [0], toOffset: 9)
        #expect(bombers.theirs.numbers.map(\.number).last == "2")
    }

    @Test("A new pitcher typed in starts, joins their roster, and is saved to the team afterward")
    func someoneNew() throws {
        var draft = PregameSamples.draft(against: "mudcats")
        draft.theirs.pitcher = draft.theirs.addNewPlayer(name: "", number: "55", throwsWith: .left)
        let setup = try #require(draft.setup(calendar: pacific))
        let pitcher = try #require(setup.away.startingPitcher.flatMap(setup.away.player))
        #expect(pitcher.number == "55" && pitcher.throwsWith == .left)
        let saved = PregameBuilder.updatedTeam(saved: SampleTeams.mudcats, from: setup.away)
        #expect(saved.roster.count == 13)
        #expect(saved.roster.last?.number == "55")
    }

    @Test("Saving a lineup of blank numbers adds no placeholders")
    func placeholdersNotSaved() throws {
        let draft = PregameSamples.draft(against: "riverhawks")
        let setup = try #require(draft.setup(calendar: pacific))
        #expect(PregameBuilder.updatedTeam(saved: PregameSamples.riverhawks, from: setup.away).roster.isEmpty)
    }
}

// MARK: - Wording

@Suite("What the lists say about our players")
struct OurWordingTests {
    @Test("Where each player is now, on the fielding step's list")
    func status() {
        var lineup = OurLineup.fromLastGame(SampleSetups.mudcatsAtDiamondDogsAlternatingFirstBase.home, roster: roster)
        lineup.assign("d12", to: .pitcher)   // Voss pitches without batting
        #expect(PregameWording.status(of: "d2", in: lineup) == "Shortstop · bats 2nd")
        #expect(PregameWording.status(of: "d12", in: lineup) == "Pitcher · doesn’t bat")
        #expect(PregameWording.status(of: "d9", in: lineup) == "DH · bats 9th")
        #expect(PregameWording.status(of: "d4", in: lineup) == "First base, odd innings · bats 4th")
        #expect(PregameWording.status(of: "d11", in: lineup) == "First base, even innings · doesn’t bat")
        lineup.removeFromOrder("d10")
        #expect(PregameWording.status(of: "d10", in: lineup) == "Bench")
        #expect(PregameWording.ordinal(11) == "11th" && PregameWording.ordinal(22) == "22nd" && PregameWording.ordinal(3) == "3rd")
    }
}

// MARK: - Starting pitchers

@Suite("Starting pitchers, most recent first")
struct PitcherTests {
    @Test("Ours: Barros started last game and Voss relieved him, then everyone else in roster order")
    func ourOrder() {
        let draft = PregameDraft(input: PregameSamples.input)
        let choices = draft.ourPitcherChoices
        #expect(choices.prefix(3).map(\.id) == ["d9", "d12", "d1"])
        #expect(choices.count == roster.count)
        let last = PregameSamples.input.lastGame?.scheduledStart
        #expect(PregameWording.ourPitcherLine(choices[0].lastPitched, lastGame: last, calendar: pacific) == "Pitched last game, May 9")
        #expect(PregameWording.ourPitcherLine(choices[1].lastPitched, lastGame: last, calendar: pacific) == "Relieved last game, May 9")
        let older = PitchingAppearance(player: "d9", date: SampleSetups.gameDay)
        #expect(PregameWording.ourPitcherLine(older, lastGame: last, calendar: pacific) == "Pitched May 2")
        #expect(PregameWording.ourPitcherLine(nil, lastGame: last) == "Hasn’t pitched this season")
    }

    @Test("With no box scores handed in, the starters of recent games stand in")
    func fromSetups() {
        var input = PregameSamples.input
        input.pitchingHistory = []
        let draft = PregameDraft(input: input)
        #expect(draft.ourPitcherChoices.first?.id == "d9")   // Barros started both sample games
    }

    @Test("Their line says when they pitched against us")
    func theirLine() {
        let appearance = PitchingAppearance(player: "m12", date: SampleSetups.gameDay, started: false)
        #expect(PregameWording.theirPitcherLine(appearance, calendar: pacific) == "Relieved against us May 2")
    }

    @Test("A throwing hand set on the pitchers step goes into the setup")
    func handEdit() throws {
        var draft = PregameSamples.draft(against: "riverhawks")
        draft.handEdits[draft.theirs.placeholderPitcherID] = .right
        let setup = try #require(draft.setup(calendar: pacific))
        #expect(setup.away.startingPitcher.flatMap(setup.away.player)?.throwsWith == .right)
    }
}

// MARK: - The game's details

@Suite("Date, start and the time limit as a clock time")
struct DetailsTests {
    @Test("9:00 AM start, time limit 12:00 PM; the wheels take any minute and the limit moves with the start")
    func clockTimes() throws {
        var details = GameDetails(day: PregameSamples.today)
        #expect(clock(details.scheduledStart(calendar: pacific)) == "9:00 AM")
        #expect(clock(details.timeLimitEnd(calendar: pacific)) == "12:00 PM")
        // The start wheel set to 1:03 PM: the limit stays three hours later, 4:03 PM.
        let oneOhThree = try #require(pacific.date(bySettingHour: 13, minute: 3, second: 0, of: details.day))
        details.setStart(oneOhThree, calendar: pacific)
        #expect(clock(details.scheduledStart(calendar: pacific)) == "1:03 PM")
        #expect(clock(details.timeLimitEnd(calendar: pacific)) == "4:03 PM")
        // The limit wheel set to 3:58 PM: two hours fifty-five after the start.
        let threeFiftyEight = try #require(pacific.date(bySettingHour: 15, minute: 58, second: 0, of: details.day))
        details.setTimeLimitEnd(threeFiftyEight, calendar: pacific)
        #expect(details.timeLimitMinutes == 175)
        #expect(details.rules.timeLimitMinutes == 175)
        #expect(PregameWording.day(details.day, calendar: pacific) == "Sat, May 23")
    }

    @Test("A championship game is three hours fifteen and the 15-run rule")
    func championship() {
        var details = GameDetails(day: PregameSamples.today)
        details.setChampionship(true)
        #expect(details.rules.timeLimitMinutes == 195)
        #expect(details.rules.runRuleMargin == 15)
        details.setChampionship(false)
        #expect(details.rules == GameRules.league)
    }

    @Test("Innings stay between one and fifteen")
    func innings() {
        var details = GameDetails(day: PregameSamples.today, innings: 1)
        details.changeInnings(by: -1)
        #expect(details.innings == 1)
        details.changeInnings(by: 6)
        #expect(details.rules.scheduledInnings == 7)
    }
}

// MARK: - The finished setup

@Suite("Play ball: the finished game setup")
struct SetupTests {
    @Test("A saved opponent and last game's lineup make a full setup with no other taps")
    func quickestPath() throws {
        let draft = PregameSamples.draft(against: "mudcats")
        let setup = try #require(draft.setup(calendar: pacific))
        #expect(setup.home.isOurs && setup.away.name == "Mudcats")
        #expect(setup.scheduledStart == SampleSetups.gameDay.addingTimeInterval(21 * 24 * 3600))
        #expect(setup.rules == GameRules.league)
        #expect(setup.home.battingOrder == SampleSetups.diamondDogsAtBombers.away.battingOrder)
        #expect(setup.home.defense == SampleSetups.diamondDogsAtBombers.away.defense)
        #expect(setup.home.shortName == "DOGS" && setup.away.shortName == "MUD")
        #expect(setup.away.defense == [FielderAssignment(position: .pitcher, player: "m9")])
    }

    @Test("Away puts us in the top of the inning")
    func away() throws {
        var draft = PregameSamples.draft(against: "bombers")
        draft.details.weAreHome = false
        let setup = try #require(draft.setup(calendar: pacific))
        #expect(setup.away.isOurs && setup.home.name == "Bombers")
        #expect(setup.ourSide == .away)
    }

    @Test("Nothing to set up without an opponent or with an empty batting order")
    func missing() {
        var draft = PregameDraft(input: PregameSamples.input)
        #expect(draft.missing == "Pick an opponent first.")
        draft.chooseOpponent(.saved("mudcats"))
        for id in draft.ours.battingOrder { draft.ours.removeFromOrder(id) }
        #expect(draft.missing == "Our batting order is empty.")
        #expect(draft.setup() == nil)
    }

    @Test("A new opponent gets the name typed and nine blank numbers")
    func newOpponent() throws {
        var draft = PregameDraft(input: PregameSamples.input, newOpponentID: "sharks")
        draft.chooseOpponent(.new)
        draft.newOpponentName = "  Sharks "
        #expect(draft.theirs.mode == .numbers)
        let setup = try #require(draft.setup(calendar: pacific))
        #expect(setup.away.name == "Sharks" && setup.away.teamID == "sharks")
        #expect(setup.away.battingOrder.count == 9)
    }

    @Test("An empty position is a note, never a block")
    func emptyPositionNote() {
        var draft = PregameSamples.draft(against: "mudcats")
        draft.ours.assign(nil, to: .rightField)
        #expect(draft.notes == ["Nobody is playing right field."])
        #expect(draft.missing == nil)
    }
}
