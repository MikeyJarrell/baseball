// Made-up teams and songs for building screens, previews and tests.
//
// The Diamond Dogs are our team. The Mudcats are an opponent with a full roster; the Bombers
// are an opponent known only by jersey numbers. Player ids are short and readable ("d3",
// "m1", "b4") and match the scenario files in Tests/Scenarios/setups/.

import Foundation
import Model

/// The sample teams.
public enum SampleTeams {
    /// Our team: twelve players, walk-up songs for ten of them, warm-up songs for the two
    /// pitchers (Sky Barros and Taylor Voss), right- and left-handed hitters
    /// and one switch hitter (Riley Shaw).
    public static let diamondDogs = Team(
        id: "diamond-dogs",
        name: "Diamond Dogs",
        isOurs: true,
        roster: [
            Player(id: "d1", name: "Alex Moreno", number: "3", bats: .right, throwsWith: .right, walkUpSongID: "song-01",
                   introduction: AnnouncerIntroduction(source: .recorded, fileName: "intro-d1.m4a")),
            Player(id: "d2", name: "Chris Tate", number: "6", bats: .left, throwsWith: .right, walkUpSongID: "song-02",
                   introduction: AnnouncerIntroduction(source: .phoneVoice)),
            Player(id: "d3", name: "Jordan Webb", number: "22", bats: .right, throwsWith: .right, walkUpSongID: "song-03"),
            Player(id: "d4", name: "Pat Quinn", number: "33", bats: .left, throwsWith: .left, walkUpSongID: "song-04"),
            Player(id: "d5", name: "Riley Shaw", number: "12", bats: .switchHitter, throwsWith: .right, walkUpSongID: "song-05"),
            Player(id: "d6", name: "Casey Ford", number: "9", bats: .right, throwsWith: .right, walkUpSongID: "song-06"),
            Player(id: "d7", name: "Drew Lang", number: "17", bats: .left, throwsWith: .right, walkUpSongID: "song-07"),
            Player(id: "d8", name: "Morgan Fisk", number: "10", bats: .right, throwsWith: .right),
            Player(id: "d9", name: "Sky Barros", number: "21", bats: .right, throwsWith: .right, walkUpSongID: "song-08",
                   warmUpSongID: "song-11"),
            Player(id: "d10", name: "Jamie Cole", number: "14", bats: .left, throwsWith: .left, walkUpSongID: "song-09"),
            Player(id: "d11", name: "Robin Nash", number: "27", bats: .right, throwsWith: .right, walkUpSongID: "song-10"),
            Player(id: "d12", name: "Taylor Voss", number: "44", bats: .left, throwsWith: .left, warmUpSongID: "song-12"),
        ]
    )

    /// An opponent with a full roster of names and numbers.
    public static let mudcats = Team(
        id: "mudcats",
        name: "Mudcats",
        roster: [
            Player(id: "m1", name: "Luis Ortiz", number: "1", bats: .right, throwsWith: .right),
            Player(id: "m2", name: "Danny Ruiz", number: "2", bats: .right, throwsWith: .right),
            Player(id: "m3", name: "Marcus Hale", number: "24", bats: .left, throwsWith: .left),
            Player(id: "m4", name: "Tommy Diaz", number: "7", bats: .right, throwsWith: .right),
            Player(id: "m5", name: "Sam Kim", number: "5", bats: .switchHitter, throwsWith: .right),
            Player(id: "m6", name: "Eddie Park", number: "11", bats: .left, throwsWith: .left),
            Player(id: "m7", name: "Joe Varga", number: "8", bats: .right, throwsWith: .right),
            Player(id: "m8", name: "Nate Bell", number: "4", bats: .right, throwsWith: .right),
            Player(id: "m9", name: "Ray Collins", number: "31", bats: .right, throwsWith: .right),
            Player(id: "m10", name: "Kyle Moss", number: "15", bats: .left, throwsWith: .right),
            Player(id: "m11", name: "Ben Ash", number: "19", bats: .right, throwsWith: .right),
            Player(id: "m12", name: "Gus Reyes", number: "40", bats: .left, throwsWith: .left),
        ]
    )

    /// An opponent known only by jersey numbers: nobody has names yet.
    public static let bombers = Team(
        id: "bombers",
        name: "Bombers",
        roster: ["2", "5", "7", "9", "12", "16", "21", "23", "31", "35", "44"].enumerated().map { i, number in
            Player(id: PlayerID(rawValue: "b\(i + 1)"), number: number)
        }
    )

    /// A team with nobody on it yet, for the empty roster screen.
    public static let emptyTeam = Team(id: "new-team", name: "New Team", roster: [])

    /// Every saved team: ours first, then the opponents.
    public static let all: [Team] = [diamondDogs, mudcats, bombers]

    /// A team we know nothing about: placeholder hitters "Batter 1" to "Batter N" and a
    /// placeholder pitcher, the way the pregame screen fills in an unknown lineup.
    public static func unknown(name: String = "Riverhawks", hitters: Int = 9) -> Team {
        var roster = (1...hitters).map { Player(id: PlayerID(rawValue: "r\($0)"), placeholder: "Batter \($0)") }
        roster.append(Player(id: "rp", placeholder: "Pitcher"))
        return Team(id: "riverhawks", name: name, roster: roster)
    }
}

/// The sample song library: fifteen songs, ten of them assigned to Diamond Dogs players.
public enum SampleSongs {
    /// Made-up song titles, so the library looks real in previews.
    static let titles = [
        "Dugout Fever", "Big Game Stomp", "Gravel and Chalk", "Sunday Doubleheader", "Night Game Lights",
        "Rally Cap", "Seventh Inning Stretch", "Bleacher Bums", "Hit the Gap", "Can of Corn",
        "Squeeze Play", "Rain Delay Blues", "Walk-Off Waltz", "Infield Fly", "Golden Sombrero",
    ]

    /// Every song, with start points and volumes as if the library had been evened out.
    public static let all: [Song] = titles.enumerated().map { i, title in
        let n = String(format: "%02d", i + 1)
        return Song(
            id: SongID(rawValue: "song-\(n)"),
            title: title,
            fileName: "song-\(n).m4a",
            startTime: Double((i * 7) % 45),
            volume: [1.0, 0.85, 0.7][i % 3],
            duration: Double(150 + i * 11)
        )
    }

    /// The library as the app would save it.
    public static let library = SongLibrary(
        songs: all,
        announcerEcho: 0.6
    )

    /// An empty library, for the first time the app opens.
    public static let emptyLibrary = SongLibrary()
}
