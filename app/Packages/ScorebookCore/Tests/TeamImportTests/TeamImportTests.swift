// Tests of reading the roster files and merging them into the app's saved teams: the real
// files in the repository's team/ folder load whole, and a second load after a change keeps
// every id, every number typed into the app, and every team and song the files do not name.

import Foundation
import Testing
import Model
@testable import TeamImport

@Suite("Loading the team files")
struct TeamImportTests {
    /// The repository's team/ folder, found from this file's place in it.
    static let teamFolder = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("team")

    func realRows() throws -> ([RosterRow], [OpponentRow]) {
        let roster = try String(contentsOf: Self.teamFolder.appendingPathComponent("roster.csv"), encoding: .utf8)
        let opponents = try String(contentsOf: Self.teamFolder.appendingPathComponent("opponents.csv"), encoding: .utf8)
        return (RosterRow.read(roster), OpponentRow.read(opponents))
    }

    @Test("Quoted fields with commas read as one field")
    func csvQuotes() {
        let rows = CSV.rows("a,b,c\n1,\"x, y\",\"say \"\"hi\"\"\"\n")
        #expect(rows == [["a": "1", "b": "x, y", "c": "say \"hi\""]])
    }

    @Test("The real roster: every player, their songs, position and role")
    func realRoster() throws {
        let (roster, opponents) = try realRows()
        let result = TeamImport.merge(teams: [], library: SongLibrary(), roster: roster, opponents: opponents)
        let ours = try #require(result.teamsToSave.first { $0.isOurs })
        #expect(ours.name == "Diamond Dogs")
        #expect(ours.shortName == "DOGS")
        #expect(ours.roster.count == roster.count)
        // Every walk-up clip and warm-up track is one song in the library.
        let files = Set(roster.flatMap { [$0.clipFile, $0.warmUpFile] }.filter { !$0.isEmpty })
        #expect(Set(result.library.songs.map(\.fileName)) == files)
        // Aidan Kurt leads off at second base; Chris Strong goes by Chris.
        let aidan = try #require(ours.roster.first { $0.name == "Aidan Kurt" })
        #expect(aidan.usuallyLeadsOff)
        #expect(aidan.usualPosition == .secondBase)
        #expect(ours.roster.contains { $0.name == "Chris Strong" })
        // Mikey is the designated hitter: bats only, no position.
        let mikey = try #require(ours.roster.first { $0.name == "Mikey Jarrell" })
        #expect(mikey.usualRole == .batsOnly && mikey.usualPosition == nil)
        let mikeySong = try #require(result.library.songs.first { $0.id == mikey.walkUpSongID })
        #expect(mikeySong.startTime == 20)
        #expect(mikeySong.artist == "Todd Rundgren")
        // Every opponent, each with its players and a short name.
        let opponentNames = Set(opponents.map(\.team))
        let saved = result.teamsToSave.filter { !$0.isOurs }
        #expect(Set(saved.map(\.name)) == opponentNames)
        #expect(saved.allSatisfy { $0.shortName != nil })
        #expect(saved.map(\.roster.count).reduce(0, +) == opponents.count)
    }

    @Test("Loading again after a change keeps ids, typed-in numbers and anything not in the files")
    func rerunKeepsWhatIsThere() throws {
        let (roster, opponents) = try realRows()
        let first = TeamImport.merge(teams: [], library: SongLibrary(), roster: roster, opponents: opponents)
        var teams = first.teamsToSave
        var library = first.library
        // On the phone since: a number typed in, an introduction recorded, an extra player and
        // an extra song added, and a team the files do not know.
        let o = try #require(teams.firstIndex { $0.isOurs })
        teams[o].roster[0].number = "7"
        teams[o].roster[0].introduction = AnnouncerIntroduction(source: .recorded, fileName: "intro.m4a")
        teams[o].roster.append(Player(name: "Guest Player"))
        library.songs.append(Song(title: "Phone song", fileName: "phone.m4a"))
        teams.append(Team(name: "Pickup Team"))
        // The roster file changes: a new start point and a new player.
        var changed = roster
        changed[2].startPoint = "0:25"
        changed.append(RosterRow(firstName: "New", lastName: "Player", goesBy: "", number: "", bats: "R", throwsWith: "R",
                                 position: "CF", usually: "", song: "", artist: "", clipFile: "", startPoint: "",
                                 warmUpSong: "", warmUpArtist: "", warmUpFile: ""))
        let second = TeamImport.merge(teams: teams, library: library, roster: changed, opponents: opponents)

        let ours = try #require(second.teamsToSave.first { $0.isOurs })
        #expect(ours.id == teams[o].id)
        #expect(ours.roster.count == roster.count + 2)
        #expect(ours.roster[0].id == teams[o].roster[0].id)
        #expect(ours.roster[0].number == "7")
        #expect(ours.roster[0].introduction?.fileName == "intro.m4a")
        #expect(ours.roster.contains { $0.name == "Guest Player" })
        #expect(Set(ours.roster.prefix(roster.count).map(\.id)) == Set(teams[o].roster.prefix(roster.count).map(\.id)))
        // Songs keep their ids; the changed start point is taken; the phone's own song stays.
        #expect(Set(second.library.songs.map(\.id)) == Set(library.songs.map(\.id)))
        let aidanSong = try #require(second.library.songs.first { $0.id == ours.roster[2].walkUpSongID })
        #expect(aidanSong.startTime == 25)
        #expect(second.library.songs.contains { $0.fileName == "phone.m4a" })
        // Opponents unchanged by a second load are not saved again; the pickup team is untouched.
        #expect(!second.teamsToSave.contains { !$0.isOurs })
    }

    @Test("Times, sides and positions read as the app's words")
    func words() {
        #expect(RosterWords.seconds("1:06") == 66)
        #expect(RosterWords.seconds("0:12.5") == 12.5)
        #expect(RosterWords.battingSide("L") == .left)
        #expect(RosterWords.position("SS") == .shortstop)
        #expect(RosterWords.position("DH") == nil)
        #expect(RosterWords.key("Joaquín  Cañas") == RosterWords.key("joaquin canas"))
    }
}
