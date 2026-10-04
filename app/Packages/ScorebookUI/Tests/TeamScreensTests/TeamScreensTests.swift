// Tests of the teams and songs screens' plain functions: what the announcer reads, how a roster
// and a song's users are summed up, reading a quick-entry line, keeping a start point on the
// track, and the team edits behind assigning songs and keeping introductions. Run with
//   xcodebuild test -scheme ScorebookUI-Package -destination 'platform=iOS Simulator,name=iPhone 17'
// in app/Packages/ScorebookUI.

import Foundation
import Testing
@testable import TeamScreens
import Model
import SampleData

@Suite("The stadium announcer’s words")
struct AnnouncerWordingTests {
    @Test("Name and number: the number, the name, then the number again")
    func nameAndNumber() {
        let jeter = Player(name: "Derek Jeter", number: "2")
        #expect(TeamWording.announcerScript(for: jeter) == "Now batting, number two, Derek Jeter. Number two.")
    }

    @Test("Only a name, or only a number")
    func partial() {
        #expect(TeamWording.announcerScript(for: Player(name: "Jordan Webb")) == "Now batting, Jordan Webb.")
        #expect(TeamWording.announcerScript(for: Player(number: "22")) == "Now batting, number twenty-two. Number twenty-two.")
        #expect(TeamWording.announcerScript(for: Player(placeholder: "Batter 4")) == "Now batting.")
    }

    @Test("Jersey numbers in words, the way the audio player reads them")
    func numbers() {
        #expect(TeamWording.spokenNumber("0") == "zero")
        #expect(TeamWording.spokenNumber("13") == "thirteen")
        #expect(TeamWording.spokenNumber("20") == "twenty")
        #expect(TeamWording.spokenNumber("44") == "forty-four")
        #expect(TeamWording.spokenNumber("00") == "double zero")
        #expect(TeamWording.spokenNumber("07") == "oh seven")
        #expect(TeamWording.spokenNumber("100") == "100")
    }

    @Test("Where the introduction comes from")
    func status() {
        let recorded = AnnouncerIntroduction(source: .recorded, fileName: "intro-d1.m4a")
        #expect(TeamWording.introductionStatus(recorded, echo: 0.6) == "Recorded in your voice · stadium echo on")
        #expect(TeamWording.introductionStatus(recorded, echo: 0) == "Recorded in your voice · no stadium echo")
        #expect(TeamWording.introductionStatus(nil, echo: 0.6) == "Nothing yet. Until there is, the song plays alone.")
        #expect(TeamWording.introductionShort(AnnouncerIntroduction(source: .phoneVoice)) == "iPhone voice intro")
    }
}

@Suite("Rosters in words")
struct RosterWordingTests {
    @Test("Our team: players, and how many have walk-up songs")
    func ourTeam() {
        #expect(TeamWording.ourTeamSummary(SampleTeams.diamondDogs) == "12 players · 10 with songs")
        #expect(TeamWording.ourTeamSummary(SampleTeams.emptyTeam) == "No players yet")
    }

    @Test("Opponents: names and numbers, numbers only, some unnamed, or none named")
    func opponents() {
        #expect(TeamWording.opponentSummary(SampleTeams.mudcats) == "12 players, names and numbers")
        #expect(TeamWording.opponentSummary(SampleTeams.bombers) == "11 players, numbers only")
        #expect(TeamWording.opponentSummary(SampleTeams.unknown(hitters: 9)) == "10 players, not named yet")
        let mixed = Team(name: "Mixed", roster: [Player(name: "Al", number: "1"), Player(number: "2")])
        #expect(TeamWording.opponentSummary(mixed) == "2 players, some unnamed")
        let one = Team(name: "Solo", roster: [Player(name: "Al", number: "1")])
        #expect(TeamWording.opponentSummary(one) == "1 player, names and numbers")
    }

    @Test("Usual position and role")
    func usuals() {
        #expect(TeamWording.usualText(PlayerUsuals(position: .centerField)) == "Center field")
        #expect(TeamWording.usualText(PlayerUsuals(position: .shortstop, leadsOff: true)) == "Shortstop, leads off")
        #expect(TeamWording.usualText(PlayerUsuals(leadsOff: true)) == "Bats only, leads off")
        #expect(TeamWording.usualText(PlayerUsuals(position: .pitcher, startsOnBench: true)) == "Pitcher, starts on the bench")
        #expect(TeamWording.usualText(PlayerUsuals()) == "")
    }

    @Test("The line under a player’s name, leaving out what is unknown")
    func playerLine() {
        let shaw = SampleTeams.diamondDogs.player("d5")!
        #expect(TeamWording.playerLine(shaw, usuals: PlayerUsuals(position: .thirdBase)) == "Third base · Bats S · Throws R")
        #expect(TeamWording.playerLine(Player(number: "9"), usuals: PlayerUsuals()) == "")
        #expect(TeamWording.handedness(Player(bats: .left)) == "Bats L")
    }

    @Test("A number already worn is noticed, but not the player’s own")
    func numberTwins() {
        let dogs = SampleTeams.diamondDogs
        #expect(TeamWording.playerWearing("22", in: dogs)?.id == "d3")
        #expect(TeamWording.playerWearing("22", in: dogs, except: "d3") == nil)
        #expect(TeamWording.playerWearing("99", in: dogs) == nil)
        #expect(TeamWording.playerWearing("", in: dogs) == nil)
    }
}

@Suite("Quick entry")
struct QuickEntryTests {
    @Test("Number then name")
    func numberAndName() {
        let line = QuickEntryLine("22 Jordan Webb")
        #expect(line.number == "22")
        #expect(line.name == "Jordan Webb")
        #expect(line.preview == "Number 22 · Jordan Webb")
    }

    @Test("A hash mark, extra spaces and a double zero")
    func messyTyping() {
        let line = QuickEntryLine("  #00   Pat   Quinn ")
        #expect(line.number == "00")
        #expect(line.name == "Pat Quinn")
    }

    @Test("Only a number, or only a name")
    func partial() {
        #expect(QuickEntryLine("44") == QuickEntryLine(number: "44", name: nil))
        #expect(QuickEntryLine("Sky Barros").number == nil)
        #expect(QuickEntryLine("Sky Barros").name == "Sky Barros")
        #expect(QuickEntryLine("   ").isEmpty)
    }

    @Test("A name that starts with digits longer than a jersey number stays a name")
    func notANumber() {
        let line = QuickEntryLine("2024 Rookie")
        #expect(line.number == nil)
        #expect(line.name == "2024 Rookie")
    }

    @Test("Twelve lines typed in a row make twelve players, in order, on the team")
    func twelvePlayers() {
        let lines = ["3 Alex Moreno", "6 Chris Tate", "22 Jordan Webb", "33 Pat Quinn", "12 Riley Shaw", "9 Casey Ford",
                     "17 Drew Lang", "10 Morgan Fisk", "21 Sky Barros", "14 Jamie Cole", "27 Robin Nash", "44 Taylor Voss"]
        var team = SampleTeams.emptyTeam
        for line in lines {
            team = team.saving(QuickEntryLine(line).player(bats: .right, throwsWith: .right))
        }
        #expect(team.roster.count == 12)
        #expect(team.roster.map(\.number) == ["3", "6", "22", "33", "12", "9", "17", "10", "21", "14", "27", "44"])
        #expect(team.roster.last?.name == "Taylor Voss")
        #expect(Set(team.roster.map(\.id)).count == 12)
    }
}

extension QuickEntryLine {
    /// A line already read, for comparing.
    init(number: String?, name: String?) {
        self.init("")
        self.number = number
        self.name = name
    }
}

@Suite("Songs")
struct SongWordingTests {
    @Test("Who uses a song, as walk-up and as warm-up")
    func usage() {
        let dogs = SampleTeams.diamondDogs
        #expect(TeamWording.usageText(of: "song-01", in: dogs) == "walk-up: Moreno")
        #expect(TeamWording.usageText(of: "song-11", in: dogs) == "warm-up: Barros")
        #expect(TeamWording.usageText(of: "song-15", in: dogs) == "unassigned")
        let shared = dogs.assigning("song-01", as: .walkUp, to: "d8").assigning("song-01", as: .warmUp, to: "d12")
        #expect(TeamWording.usageText(of: "song-01", in: shared) == "walk-up: Moreno, Fisk · warm-up: Voss")
        #expect(TeamWording.usageText(of: "song-01", in: nil) == "unassigned")
    }

    @Test("Times on screen")
    func times() {
        #expect(TeamWording.clock(42) == "0:42")
        #expect(TeamWording.clock(232.9) == "3:52")
        #expect(TeamWording.clockTenths(42.34) == "0:42.3")
        #expect(TeamWording.clockTenths(59.96) == "1:00.0")
        #expect(TeamWording.percent(0.85) == "85%")
        #expect(TeamWording.songDetails(Song(title: "x", fileName: "x", startTime: 42, volume: 0.9)) == "starts at 0:42 · volume 90%")
    }

    @Test("A start point stays on the track, a second clear of the end")
    func startPoint() {
        let song = Song(title: "Rally Cap", fileName: "x.m4a", startTime: 10, duration: 120)
        #expect(TeamWording.clampedStart(-3, in: song) == 0)
        #expect(TeamWording.clampedStart(42.36, in: song) == 42.4)
        #expect(TeamWording.clampedStart(500, in: song) == 119)
        // With no known length, the timeline runs at least three minutes and a minute past the start.
        let unknown = Song(title: "x", fileName: "x", startTime: 200)
        #expect(TeamWording.timelineLength(of: unknown) == 260)
        #expect(TeamWording.timelineLength(of: Song(title: "x", fileName: "x")) == 180)
    }

    @Test("The drawing of a song is the same every time, and stays in bounds")
    func waveform() {
        let a = TeamWording.waveformHeights(seed: "song-03", count: 90)
        #expect(a == TeamWording.waveformHeights(seed: "song-03", count: 90))
        #expect(a != TeamWording.waveformHeights(seed: "song-04", count: 90))
        #expect(a.allSatisfy { $0 >= 0.15 && $0 <= 1 })
    }
}

@Suite("Team edits")
struct TeamEditTests {
    @Test("Saving a player changes them in place, or adds them at the end")
    func saving() {
        var webb = SampleTeams.diamondDogs.player("d3")!
        webb.number = "23"
        let edited = SampleTeams.diamondDogs.saving(webb)
        #expect(edited.roster.count == 12)
        #expect(edited.roster[2].number == "23")
        let added = SampleTeams.diamondDogs.saving(Player(name: "New Guy"))
        #expect(added.roster.count == 13)
        #expect(added.roster.last?.name == "New Guy")
        #expect(SampleTeams.diamondDogs.removing("d3").player("d3") == nil)
    }

    @Test("Picking a walk-up song, a warm-up song, and no song")
    func assigning() {
        let dogs = SampleTeams.diamondDogs
        let fisk = dogs.assigning("song-13", as: .walkUp, to: "d8").player("d8")!
        #expect(fisk.walkUpSongID == "song-13")
        #expect(fisk.warmUpSongID == nil)
        let voss = dogs.assigning("song-14", as: .warmUp, to: "d12").player("d12")!
        #expect(voss.warmUpSongID == "song-14")
        #expect(dogs.assigning(nil, as: .walkUp, to: "d1").player("d1")?.walkUpSongID == nil)
        // Someone not on the team changes nothing.
        #expect(dogs.assigning("song-13", as: .walkUp, to: "nobody") == dogs)
    }

    @Test("Keeping a new recording frees the old recording’s file")
    func replacingARecording() {
        let fresh = AnnouncerIntroduction(source: .recorded, fileName: "intro-d1-new.m4a")
        let (team, unused) = SampleTeams.diamondDogs.settingIntroduction(fresh, for: "d1")
        #expect(team.player("d1")?.introduction == fresh)
        #expect(unused == AnnouncerIntroduction(source: .recorded, fileName: "intro-d1.m4a"))
    }

    @Test("Switching from the iPhone voice leaves no file to free; switching to it does")
    func phoneVoice() {
        let voice = AnnouncerIntroduction(source: .phoneVoice)
        let (_, none) = SampleTeams.diamondDogs.settingIntroduction(nil, for: "d2")
        #expect(none == nil)
        let (team, unused) = SampleTeams.diamondDogs.settingIntroduction(voice, for: "d1")
        #expect(team.player("d1")?.introduction == voice)
        #expect(unused?.fileName == "intro-d1.m4a")
    }
}

@Suite("The demo acts on requests as the app shell will")
struct DemoStateTests {
    @Test("A recording goes from recording, to waiting for Keep, to idle")
    @MainActor
    func recording() {
        var state = TeamScreensDemoState.sample
        state.apply(.startRecording(for: "d3"), now: Date(timeIntervalSince1970: 0))
        #expect(state.data.audio.recording == .recording("d3", since: Date(timeIntervalSince1970: 0)))
        state.apply(.stopRecording)
        guard case .recorded("d3", let intro) = state.data.audio.recording else {
            Issue.record("expected a recording waiting for Keep")
            return
        }
        #expect(intro.source == .recorded)
        state.apply(.finishRecording)
        #expect(state.data.audio.recording == .idle)
    }

    @Test("Saving a team replaces it; a new team is added")
    @MainActor
    func savingTeams() {
        var state = TeamScreensDemoState.sample
        let count = state.data.teams.count
        state.apply(.saveTeam(SampleTeams.mudcats.removing("m1")))
        #expect(state.data.teams.count == count)
        #expect(state.data.team("mudcats")?.roster.count == 11)
        state.apply(.saveTeam(Team(name: "River Rats")))
        #expect(state.data.teams.count == count + 1)
    }

    @Test("A preview counts up from where it started, so Start here can catch the hook")
    @MainActor
    func preview() {
        var state = TeamScreensDemoState.sample
        state.apply(.playPreview("song-03", from: 14))
        for _ in 0..<10 { state.tick() }
        #expect(abs((state.data.audio.position ?? 0) - 15) < 0.001)
        state.apply(.setStartPoint(15, for: "song-03"))
        #expect(state.data.library.song("song-03")?.startTime == 15)
    }
}

@Suite("Review fixes")
struct ReviewFixTests {
    @Test("Scrolling up or down over a song’s track never moves its start point; a sideways drag does")
    func sidewaysOnly() {
        #expect(!TeamWording.isSidewaysDrag(width: 2, height: 80))      // an ordinary scroll
        #expect(!TeamWording.isSidewaysDrag(width: 30, height: 40))     // a slanted scroll
        #expect(!TeamWording.isSidewaysDrag(width: 6, height: 0))       // too short to tell
        #expect(TeamWording.isSidewaysDrag(width: 40, height: 5))
        #expect(TeamWording.isSidewaysDrag(width: -25, height: 10))
    }

    @Test("Two players wearing the same number are both marked, and nobody else is")
    func sharedNumbers() {
        let twin = Player(id: "twin", name: "Second Webb", number: "22")
        let team = SampleTeams.diamondDogs.saving(twin)
        #expect(TeamWording.sharedNumberNote(for: twin, in: team) == "Same number as Jordan Webb")
        #expect(TeamWording.sharedNumberNote(for: team.player("d3")!, in: team) == "Same number as Second Webb")
        #expect(TeamWording.sharedNumberNote(for: team.player("d1")!, in: team) == nil)
        #expect(TeamWording.sharedNumberNote(for: Player(name: "No Number"), in: team) == nil)
    }

    @Test("A player with the same song as walk-up and warm-up gets two distinct rows under Used by")
    func usedByRows() {
        let fisk = SampleTeams.diamondDogs.player("d8")!
        let walkUp = SongUser(player: fisk, slot: .walkUp), warmUp = SongUser(player: fisk, slot: .warmUp)
        #expect(walkUp.id != warmUp.id)
    }
}
