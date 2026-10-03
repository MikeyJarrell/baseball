// Made-up teams and songs for building screens, previews and tests.
//
// The Mudcats are our team. The Cardinals are an opponent with a full roster; the Bombers
// are an opponent known only by jersey numbers. Player ids are short and readable ("m3",
// "c1", "b4") and match the scenario files in Tests/Scenarios/setups/.

import Foundation
import Model

/// The sample teams.
public enum SampleTeams {
    /// Our team: twelve players, songs for ten of them, right- and left-handed hitters
    /// and one switch hitter (Riley Shaw).
    public static let mudcats = Team(
        id: "mudcats",
        name: "Mudcats",
        isOurs: true,
        roster: [
            Player(id: "m1", name: "Alex Moreno", number: "3", bats: .right, throwsWith: .right, walkUpSongID: "song-01",
                   introduction: AnnouncerIntroduction(source: .recorded, fileName: "intro-m1.m4a")),
            Player(id: "m2", name: "Chris Tate", number: "6", bats: .left, throwsWith: .right, walkUpSongID: "song-02",
                   introduction: AnnouncerIntroduction(source: .phoneVoice)),
            Player(id: "m3", name: "Jordan Webb", number: "22", bats: .right, throwsWith: .right, walkUpSongID: "song-03"),
            Player(id: "m4", name: "Pat Quinn", number: "33", bats: .left, throwsWith: .left, walkUpSongID: "song-04"),
            Player(id: "m5", name: "Riley Shaw", number: "12", bats: .switchHitter, throwsWith: .right, walkUpSongID: "song-05"),
            Player(id: "m6", name: "Casey Ford", number: "9", bats: .right, throwsWith: .right, walkUpSongID: "song-06"),
            Player(id: "m7", name: "Drew Lang", number: "17", bats: .left, throwsWith: .right, walkUpSongID: "song-07"),
            Player(id: "m8", name: "Morgan Fisk", number: "10", bats: .right, throwsWith: .right),
            Player(id: "m9", name: "Sky Barros", number: "21", bats: .right, throwsWith: .right, walkUpSongID: "song-08"),
            Player(id: "m10", name: "Jamie Cole", number: "14", bats: .left, throwsWith: .left, walkUpSongID: "song-09"),
            Player(id: "m11", name: "Robin Nash", number: "27", bats: .right, throwsWith: .right, walkUpSongID: "song-10"),
            Player(id: "m12", name: "Taylor Voss", number: "44", bats: .left, throwsWith: .left),
        ]
    )

    /// An opponent with a full roster of names and numbers.
    public static let cardinals = Team(
        id: "cardinals",
        name: "Cardinals",
        roster: [
            Player(id: "c1", name: "Luis Ortiz", number: "1", bats: .right, throwsWith: .right),
            Player(id: "c2", name: "Danny Ruiz", number: "2", bats: .right, throwsWith: .right),
            Player(id: "c3", name: "Marcus Hale", number: "24", bats: .left, throwsWith: .left),
            Player(id: "c4", name: "Tommy Diaz", number: "7", bats: .right, throwsWith: .right),
            Player(id: "c5", name: "Sam Kim", number: "5", bats: .switchHitter, throwsWith: .right),
            Player(id: "c6", name: "Eddie Park", number: "11", bats: .left, throwsWith: .left),
            Player(id: "c7", name: "Joe Varga", number: "8", bats: .right, throwsWith: .right),
            Player(id: "c8", name: "Nate Bell", number: "4", bats: .right, throwsWith: .right),
            Player(id: "c9", name: "Ray Collins", number: "31", bats: .right, throwsWith: .right),
            Player(id: "c10", name: "Kyle Moss", number: "15", bats: .left, throwsWith: .right),
            Player(id: "c11", name: "Ben Ash", number: "19", bats: .right, throwsWith: .right),
            Player(id: "c12", name: "Gus Reyes", number: "40", bats: .left, throwsWith: .left),
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
    public static let all: [Team] = [mudcats, cardinals, bombers]

    /// A team we know nothing about: placeholder hitters "Batter 1" to "Batter N" and a
    /// placeholder pitcher, the way the pregame screen fills in an unknown lineup.
    public static func unknown(name: String = "Riverhawks", hitters: Int = 9) -> Team {
        var roster = (1...hitters).map { Player(id: PlayerID(rawValue: "r\($0)"), placeholder: "Batter \($0)") }
        roster.append(Player(id: "rp", placeholder: "Pitcher"))
        return Team(id: "riverhawks", name: name, roster: roster)
    }
}

/// The sample song library: fifteen songs, ten of them assigned to Mudcats players.
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
            playLength: i % 3 == 0 ? 20 : nil,
            volume: [1.0, 0.85, 0.7][i % 3],
            duration: Double(150 + i * 11)
        )
    }

    /// The library as the app would save it, with a five-song between-innings playlist.
    public static let library = SongLibrary(
        songs: all,
        betweenInningsPlaylist: ["song-11", "song-12", "song-13", "song-14", "song-15"],
        shufflePlaylist: true,
        announcerEcho: 0.6
    )

    /// An empty library, for the first time the app opens.
    public static let emptyLibrary = SongLibrary()
}
