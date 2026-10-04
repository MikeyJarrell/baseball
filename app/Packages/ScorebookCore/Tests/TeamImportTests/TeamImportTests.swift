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

    @Test("Extra warm-up songs attach to their pitcher, in order, and a second load replaces the list")
    func extraWarmUps() throws {
        let (roster, opponents) = try realRows()
        let extras = ExtraWarmUpRow.read("""
            player,song,artist,source,file
            Chris Strong,Thunderstruck,AC/DC,https://example.com/a,chris-strong-warmup-2.m4a
            Chris Strong,Eye of the Tiger,Survivor,https://example.com/b,chris-strong-warmup-3.m4a
            Chris Strong,Not Cut Yet,Nobody,https://example.com/c,
            Chris Strong,Thunderstruck,AC/DC,https://example.com/a,chris-strong-warmup-2.m4a
            Kris Strong,Misspelled,Nobody,https://example.com/d,kris.m4a
            """)
        let first = TeamImport.merge(teams: [], library: SongLibrary(), roster: roster, opponents: opponents,
                                     extraWarmUps: extras)
        let ours = try #require(first.teamsToSave.first { $0.isOurs })
        let chris = try #require(ours.roster.first { $0.name == "Chris Strong" })
        let titles = chris.extraWarmUpSongIDs.compactMap { first.library.song($0)?.title }
        #expect(titles == ["Thunderstruck", "Eye of the Tiger"])
        #expect(first.audioFiles.contains("chris-strong-warmup-2.m4a"))
        // His main warm-up song is untouched, and nobody else gets extras.
        #expect(first.library.song(chris.warmUpSongID ?? "")?.title == "Sweet Home Alabama")
        #expect(ours.roster.filter { !$0.extraWarmUpSongIDs.isEmpty }.map(\.name) == ["Chris Strong"])
        // A song listed twice is in his list once; a misspelled name is reported.
        #expect(chris.extraWarmUpSongIDs.count == 2)
        #expect(first.notes.contains { $0.contains("Kris Strong") })
        // Loading again with one row gone drops that song from his list but keeps its id in the library.
        let again = TeamImport.merge(teams: first.teamsToSave, library: first.library, roster: roster,
                                     opponents: opponents, extraWarmUps: Array(extras.prefix(1)))
        let chrisAgain = try #require(again.teamsToSave.first { $0.isOurs }?.roster.first { $0.id == chris.id })
        #expect(chrisAgain.extraWarmUpSongIDs == [chris.extraWarmUpSongIDs[0]])
    }

    @Test("A warm-up track never takes over a teammate's walk-up clip of the same song")
    func sameSongTwoFiles() throws {
        let (roster, opponents) = try realRows()
        // Aidan walks up to Mary Jane; a pitcher lists the whole track as an extra warm-up song.
        let extras = ExtraWarmUpRow.read("player,song,artist,source,file\nChris Strong,Mary Jane,Rick James,x,chris-strong-warmup-mary-jane.m4a\n")
        let first = TeamImport.merge(teams: [], library: SongLibrary(), roster: roster, opponents: opponents)
        let second = TeamImport.merge(teams: first.teamsToSave, library: first.library, roster: roster,
                                      opponents: opponents, extraWarmUps: extras)
        let ours = try #require(second.teamsToSave.first { $0.isOurs })
        let aidan = try #require(ours.roster.first { $0.name == "Aidan Kurt" })
        let chris = try #require(ours.roster.first { $0.name == "Chris Strong" })
        #expect(second.library.song(aidan.walkUpSongID ?? "")?.fileName == "aidan-kurt.m4a")
        #expect(second.library.song(chris.extraWarmUpSongIDs.first ?? "")?.fileName == "chris-strong-warmup-mary-jane.m4a")
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

    @Test("Players whose names were recorded get a pieced introduction; one recorded in the app is kept")
    func piecedIntroductions() throws {
        let (roster, opponents) = try realRows()
        var teams = TeamImport.merge(teams: [], library: SongLibrary(), roster: roster, opponents: opponents).teamsToSave
        let o = try #require(teams.firstIndex { $0.isOurs })
        // Mikey recorded Chris's introduction in the app, and switched Darin to the iPhone voice.
        let chris = try #require(teams[o].roster.firstIndex { $0.name == "Chris Strong" })
        teams[o].roster[chris].introduction = AnnouncerIntroduction(source: .recorded, fileName: "intro-chris.m4a")
        let darin = try #require(teams[o].roster.firstIndex { $0.name == "Darin Dietrich" })
        teams[o].roster[darin].introduction = AnnouncerIntroduction(source: .phoneVoice)

        let result = TeamImport.merge(teams: teams, library: SongLibrary(), roster: roster, opponents: opponents,
                                      recordedNames: ["aidan-kurt", "chris-strong", "darin-dietrich"])
        let ours = try #require(result.teamsToSave.first { $0.isOurs })
        let intro = { (name: String) in ours.roster.first { $0.name == name }?.introduction }
        #expect(intro("Aidan Kurt") == AnnouncerIntroduction(source: .pieced, fileName: "announcer-name-aidan-kurt.m4a"))
        #expect(intro("Chris Strong")?.source == .recorded)
        #expect(intro("Darin Dietrich")?.source == .phoneVoice)
        #expect(intro("Mikey Jarrell") == nil)
    }

    @Test("A number changed in the app is kept over the roster file’s; a blank one is filled in")
    func numbersFromTheApp() throws {
        let (roster, opponents) = try realRows()
        var teams = TeamImport.merge(teams: [], library: SongLibrary(), roster: roster, opponents: opponents).teamsToSave
        let o = try #require(teams.firstIndex { $0.isOurs })
        let aidan = try #require(teams[o].roster.firstIndex { $0.name == "Aidan Kurt" })
        #expect(teams[o].roster[aidan].number == "3")   // from roster.csv
        teams[o].roster[aidan].number = "9"
        let again = TeamImport.merge(teams: teams, library: SongLibrary(), roster: roster, opponents: opponents)
        let ours = try #require(again.teamsToSave.first { $0.isOurs })
        #expect(ours.roster[aidan].number == "9")
        #expect(again.notes.contains { $0.contains("Aidan Kurt wears 9") })
    }

    @Test("File name stems match the Mac scripts: no accents, words joined by dashes")
    func fileStems() {
        #expect(RosterWords.fileStem("Joaquín Cañas") == "joaquin-canas")
        #expect(RosterWords.fileStem("Erick Rosas Lopez") == "erick-rosas-lopez")
        #expect(RosterWords.fileStem("J.T. O'Neil") == "j-t-o-neil")
    }
}
