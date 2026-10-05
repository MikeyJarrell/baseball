// TeamImport: turning the roster files in the repository's `team/` folder into the app's
// saved teams and song library.
//
// - `team/roster.csv`: the Diamond Dogs, one row per player: name, the name they go by,
//   number, batting and throwing side, usual position and role, walk-up song and its start
//   point, and a pitcher's warm-up song.
// - `team/warmup_extras.csv`: our pitchers' extra warm-up songs, one row per song.
// - `team/opponents.csv`: every opponent's registered players.
//
// The merge never throws anything away. It matches what is already saved by name: a team by
// its name, a player by their name within the team, a song by its file name. A match keeps
// its id (so season stats carry over) and anything the CSV leaves blank (a jersey number
// typed into the app; a jersey number changed in the app, which wins over the file). A player
// whose name was recorded on the Mac (tools/record_intros.py) and who has no introduction yet
// gets one pieced together from those recordings; one chosen in the app is never touched. Players, teams and songs the CSV
// does not mention stay as they are. Games are never touched.
//
// The command-line loader (Sources/TeamLoader) reads and writes the files; this module only
// works out what the teams and the song library should become, so it can be tested.

import Foundation
import Model

// MARK: - Reading the CSV files

/// A very small CSV reader: commas between fields, double quotes around a field that holds a
/// comma, and two double quotes for a quote mark inside one.
public enum CSV {
    /// Every row after the header, as a dictionary from column name to text.
    public static func rows(_ text: String) -> [[String: String]] {
        let lines = records(text)
        guard let header = lines.first else { return [] }
        return lines.dropFirst().compactMap { fields in
            if fields.allSatisfy({ $0.trimmingCharacters(in: .whitespaces).isEmpty }) { return nil }
            var row: [String: String] = [:]
            for (i, name) in header.enumerated() {
                row[name.trimmingCharacters(in: .whitespaces)] = i < fields.count
                    ? fields[i].trimmingCharacters(in: .whitespaces) : ""
            }
            return row
        }
    }

    /// Splits the text into records and fields, honoring quotes (a quoted field may even hold
    /// a line break).
    static func records(_ text: String) -> [[String]] {
        var records: [[String]] = []
        var fields: [String] = []
        var field = ""
        var inQuotes = false
        var chars = Array(text.replacingOccurrences(of: "\r\n", with: "\n"))
        if chars.first == "\u{FEFF}" { chars.removeFirst() }   // a byte-order mark some editors add
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if inQuotes {
                if c == "\"" {
                    if i + 1 < chars.count, chars[i + 1] == "\"" { field.append("\""); i += 1 } else { inQuotes = false }
                } else {
                    field.append(c)
                }
            } else if c == "\"" {
                inQuotes = true
            } else if c == "," {
                fields.append(field); field = ""
            } else if c == "\n" {
                fields.append(field); field = ""
                records.append(fields); fields = []
            } else {
                field.append(c)
            }
            i += 1
        }
        if !field.isEmpty || !fields.isEmpty { fields.append(field); records.append(fields) }
        return records
    }
}

/// One Diamond Dogs player, as `team/roster.csv` has them.
public struct RosterRow: Equatable, Sendable {
    public var firstName: String
    public var lastName: String
    /// The first name they go by: "Chris" for Christopher Strong.
    public var goesBy: String
    public var number: String
    public var bats: String
    public var throwsWith: String
    /// "P", "C", "1B" … "RF", or "DH" for a player who only bats.
    public var position: String
    /// "Leads off", "Starts on the bench", or blank.
    public var usually: String
    public var song: String
    public var artist: String
    /// The walk-up clip's file name in `~/Dropbox/baseball/songs/`.
    public var clipFile: String
    /// Where the hook falls in the clip: "0:20".
    public var startPoint: String
    public var warmUpSong: String
    public var warmUpArtist: String
    /// The warm-up song's file name: a whole track, played from the start.
    public var warmUpFile: String

    /// The name the app shows and the announcer reads: "Chris Strong".
    public var displayName: String {
        "\(goesBy.isEmpty ? firstName : goesBy) \(lastName)".trimmingCharacters(in: .whitespaces)
    }

    /// Reads every player in `team/roster.csv`.
    public static func read(_ text: String) -> [RosterRow] {
        CSV.rows(text).map { r in
            RosterRow(firstName: r["first_name"] ?? "", lastName: r["last_name"] ?? "", goesBy: r["goes_by"] ?? "",
                      number: r["number"] ?? "", bats: r["bats"] ?? "", throwsWith: r["throws"] ?? "",
                      position: r["position"] ?? "", usually: r["usually"] ?? "", song: r["song"] ?? "",
                      artist: r["artist"] ?? "", clipFile: r["clip_file"] ?? "", startPoint: r["start_point_in_clip"] ?? "",
                      warmUpSong: r["warmup_song"] ?? "", warmUpArtist: r["warmup_artist"] ?? "",
                      warmUpFile: r["warmup_file"] ?? "")
        }
    }
}

/// One extra warm-up song for one of our pitchers, as `team/warmup_extras.csv` has them.
public struct ExtraWarmUpRow: Equatable, Sendable {
    /// The pitcher, by the name he goes by and his last name: "Chris Strong".
    public var player: String
    public var song: String
    public var artist: String
    /// The song's file name in `~/Dropbox/baseball/songs/`: a whole track, played from the start.
    public var file: String

    /// Reads every row of `team/warmup_extras.csv`.
    public static func read(_ text: String) -> [ExtraWarmUpRow] {
        CSV.rows(text).map { r in
            ExtraWarmUpRow(player: r["player"] ?? "", song: r["song"] ?? "", artist: r["artist"] ?? "",
                           file: r["file"] ?? "")
        }.filter { !$0.player.isEmpty }
    }
}

/// One opponent's registered player, as `team/opponents.csv` has them.
public struct OpponentRow: Equatable, Sendable {
    public var team: String
    public var name: String
    public var number: String
    public var bats: String
    public var throwsWith: String

    /// Reads every row of `team/opponents.csv`.
    public static func read(_ text: String) -> [OpponentRow] {
        CSV.rows(text).map { r in
            OpponentRow(team: r["team"] ?? "", name: r["name"] ?? "", number: r["number"] ?? "",
                        bats: r["bats"] ?? "", throwsWith: r["throws"] ?? "")
        }.filter { !$0.team.isEmpty && !$0.name.isEmpty }
    }
}

// MARK: - Turning text into the app's words

public enum RosterWords {
    /// The last name a player goes by on its own, when the roster's last name is two words
    /// and not one name with a small word in front ("De La Cruz", "Van Dyke"): the first of
    /// the two, as is usual with two Spanish last names. "Torres Benitez" gives "Torres".
    /// Missing for a one-word last name.
    public static func surname(fromLastName lastName: String) -> String? {
        let words = lastName.split(whereSeparator: \.isWhitespace).map(String.init)
        let smallWords: Set<String> = ["de", "la", "del", "van", "von", "da", "di", "du", "le", "st", "st.", "mc", "dos", "das", "do", "san", "santa"]
        guard words.count >= 2, !smallWords.contains(words[0].lowercased()) else { return nil }
        return words[0]
    }

    /// "R", "L", "S" (or "B" for both) as a batting side; blank is unknown.
    public static func battingSide(_ text: String) -> BattingSide? {
        switch text.uppercased() {
        case "R": .right
        case "L": .left
        case "S", "B": .switchHitter
        default: nil
        }
    }

    /// "R" or "L" as a throwing hand; blank is unknown.
    public static func hand(_ text: String) -> Hand? {
        switch text.uppercased() {
        case "R": .right
        case "L": .left
        default: nil
        }
    }

    /// "SS" as a fielding position. "DH" and blank have none.
    public static func position(_ text: String) -> Position? {
        let wanted = text.lowercased()
        return Position.allCases.first { $0.abbreviation == wanted }
    }

    /// "0:20", "1:06" or "0:12.5" as seconds. Blank or unreadable is 0.
    public static func seconds(_ text: String) -> TimeInterval {
        let parts = text.split(separator: ":").map { Double($0.trimmingCharacters(in: .whitespaces)) ?? 0 }
        return parts.reduce(0) { $0 * 60 + $1 }
    }

    /// A plain file name stem from a player's name, as the Mac scripts make them:
    /// "Joaquín Cañas" is "joaquin-canas".
    public static func fileStem(_ name: String) -> String {
        let plain = name.lowercased().folding(options: .diacriticInsensitive, locale: nil)
        let words = plain.map { $0.isASCII && ($0.isLetter || $0.isNumber) ? $0 : " " }
        return String(words).split(separator: " ").joined(separator: "-")
    }

    /// A name for matching: lower case, no accents, single spaces. "Cañas" matches "Canas".
    public static func key(_ name: String) -> String {
        name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// The short name for each opponent on the scoreboard: three letters that read as the team.
    public static let opponentShortNames: [String: String] = [
        "Cannonballers": "CAN",
        "Clairemont Swingers": "SWG",
        "Compadres": "COMP",
        "El Cajones": "ELC",
        "GWW Whales": "GWW",
        "Jaguares": "JAG",
        "Lemon Grove Athletics": "LGA",
        "Riptide": "RIP",
    ]
}

// MARK: - The merge

/// What the teams and the song library become, and what changed, in words.
public struct ImportResult: Sendable {
    /// Every team to save (changed or new). Teams not listed are left as they are.
    public var teamsToSave: [Team]
    /// The song library to save.
    public var library: SongLibrary
    /// The song files to copy into the app's audio folder: the file name both in the songs
    /// folder and in the app.
    public var audioFiles: [String]
    /// What happened, a line each, for the person running the loader.
    public var notes: [String]
}

public enum TeamImport {
    /// Our team's name and scoreboard name.
    public static let ourTeamName = "Diamond Dogs"
    public static let ourShortName = "DOGS"

    /// Works out the saved teams and song library after loading the CSV rows.
    ///
    /// - Parameters:
    ///   - teams: Every team already saved in the app.
    ///   - library: The app's song library now.
    ///   - roster: Our players, from `team/roster.csv`.
    ///   - opponents: Every opponent's players, from `team/opponents.csv`.
    ///   - extraWarmUps: Our pitchers' extra warm-up songs, from `team/warmup_extras.csv`.
    ///   - durations: Each song file's length in seconds, by file name, where known.
    ///   - recordedNames: The players whose names were recorded for a pieced introduction,
    ///     by their file name stem ("aidan-kurt").
    public static func merge(teams: [Team], library: SongLibrary, roster: [RosterRow], opponents: [OpponentRow],
                             extraWarmUps: [ExtraWarmUpRow] = [], durations: [String: TimeInterval] = [:],
                             recordedNames: Set<String> = []) -> ImportResult {
        var notes: [String] = []
        var library = library
        var audioFiles: [String] = []

        // Every file the roster files name. A song matched by title and artist (one imported on
        // the phone by hand) must not be one of these, or a whole warm-up track could take over a
        // teammate's walk-up clip of the same song.
        let namedFiles = Set(roster.flatMap { [$0.clipFile, $0.warmUpFile] } + extraWarmUps.map(\.file))

        // Songs first, so players can point at them.
        func song(file: String, title: String, artist: String, start: TimeInterval) -> SongID? {
            guard !file.isEmpty else { return nil }
            audioFiles.append(file)
            if let i = library.songs.firstIndex(where: { $0.fileName == file })
                ?? library.songs.firstIndex(where: { !namedFiles.contains($0.fileName)
                    && RosterWords.key($0.title) == RosterWords.key(title) && RosterWords.key($0.artist ?? "") == RosterWords.key(artist) }) {
                var s = library.songs[i]
                s.fileName = file
                s.title = title.isEmpty ? s.title : title
                s.artist = artist.isEmpty ? s.artist : artist
                s.startTime = start
                s.duration = durations[file] ?? s.duration
                if s != library.songs[i] { notes.append("Song updated: \(s.title)") }
                library.songs[i] = s
                return s.id
            }
            let new = Song(title: title.isEmpty ? file : title, fileName: file, startTime: start,
                           duration: durations[file], artist: artist.isEmpty ? nil : artist)
            library.songs.append(new)
            notes.append("Song added: \(new.title)")
            return new.id
        }

        // Our team.
        var ours = teams.first { $0.isOurs } ?? teams.first { RosterWords.key($0.name) == RosterWords.key(ourTeamName) }
            ?? Team(name: ourTeamName, isOurs: true, shortName: ourShortName)
        let oursBefore = teams.first { $0.id == ours.id }
        ours.isOurs = true
        if ours.shortName == nil { ours.shortName = ourShortName }
        for row in roster {
            let walkUp = song(file: row.clipFile, title: row.song, artist: row.artist, start: RosterWords.seconds(row.startPoint))
            let warmUp = song(file: row.warmUpFile, title: row.warmUpSong, artist: row.warmUpArtist, start: 0)
            let names = [row.displayName, "\(row.firstName) \(row.lastName)"].map(RosterWords.key)
            let index = ours.roster.firstIndex { names.contains(RosterWords.key($0.name ?? "")) }
            var player = index.map { ours.roster[$0] } ?? Player()
            player.name = row.displayName
            player.surname = RosterWords.surname(fromLastName: row.lastName)
            // A number changed in the app during the season wins over the roster file; the
            // file only fills in a player with no number yet.
            let phoneNumber = player.number?.trimmingCharacters(in: .whitespaces) ?? ""
            if phoneNumber.isEmpty, !row.number.isEmpty {
                player.number = row.number
            } else if !row.number.isEmpty, phoneNumber != row.number {
                notes.append("\(row.displayName) wears \(phoneNumber) in the app and \(row.number) in roster.csv; the app’s number was kept")
            }
            player.bats = RosterWords.battingSide(row.bats) ?? player.bats
            player.throwsWith = RosterWords.hand(row.throwsWith) ?? player.throwsWith
            player.usualPosition = RosterWords.position(row.position)
            let usually = RosterWords.key(row.usually)
            player.usuallyLeadsOff = usually.contains("leads off")
            if usually.contains("bench") {
                player.usualRole = .startsOnBench
            } else if row.position.uppercased() == "DH" {
                player.usualRole = .batsOnly
            } else {
                player.usualRole = .batsAndFields
            }
            if let walkUp { player.walkUpSongID = walkUp }
            if let warmUp { player.warmUpSongID = warmUp }
            // The pieced introduction for a player with none yet. One chosen in the app (a
            // recording, an import, the iPhone voice) is kept.
            let stem = RosterWords.fileStem(row.displayName)
            if recordedNames.contains(stem), player.introduction == nil || player.introduction?.source == .pieced {
                player.introduction = AnnouncerIntroduction(source: .pieced, fileName: AnnouncerIntroduction.nameFile(stem))
            }
            // Extra warm-up songs: the file's, in its order, then any added on the phone (during
            // a game, say) that the file does not list, so a team load never loses them. A row
            // whose song is not cut yet is skipped.
            var extras: [SongID] = []
            for extra in extraWarmUps where names.contains(RosterWords.key(extra.player)) {
                if let id = song(file: extra.file, title: extra.song, artist: extra.artist, start: 0),
                   !extras.contains(id), id != player.warmUpSongID { extras.append(id) }
            }
            for id in player.extraWarmUpSongIDs where !extras.contains(id) && id != player.warmUpSongID {
                extras.append(id)
            }
            player.extraWarmUpSongIDs = extras
            if let index {
                if ours.roster[index] != player { notes.append("Player updated: \(row.displayName)") }
                ours.roster[index] = player
            } else {
                ours.roster.append(player)
                notes.append("Player added: \(row.displayName)")
            }
        }
        var toSave: [Team] = []
        if ours != oursBefore { toSave.append(ours) }
        // An extra warm-up song for a name not on the roster (a misspelling) is said, not lost quietly.
        let rosterNames = Set(roster.flatMap { [RosterWords.key($0.displayName), RosterWords.key("\($0.firstName) \($0.lastName)")] })
        for extra in extraWarmUps where !rosterNames.contains(RosterWords.key(extra.player)) {
            notes.append("Not on the roster, so skipped: \(extra.player)’s warm-up song \(extra.song)")
        }

        // Each opponent.
        var opponentNames: [String] = []
        for row in opponents where !opponentNames.contains(row.team) { opponentNames.append(row.team) }
        for name in opponentNames {
            let existing = teams.first { !$0.isOurs && RosterWords.key($0.name) == RosterWords.key(name) }
            var team = existing ?? Team(name: name, shortName: RosterWords.opponentShortNames[name])
            if team.shortName == nil { team.shortName = RosterWords.opponentShortNames[name] }
            for row in opponents where row.team == name {
                let index = team.roster.firstIndex { RosterWords.key($0.name ?? "") == RosterWords.key(row.name) }
                var player = index.map { team.roster[$0] } ?? Player(name: row.name)
                if !row.number.isEmpty { player.number = row.number }
                player.bats = RosterWords.battingSide(row.bats) ?? player.bats
                player.throwsWith = RosterWords.hand(row.throwsWith) ?? player.throwsWith
                if let index { team.roster[index] = player } else { team.roster.append(player) }
            }
            if team != existing {
                toSave.append(team)
                notes.append(existing == nil ? "Opponent added: \(name), \(team.roster.count) players"
                                             : "Opponent updated: \(name)")
            }
        }
        return ImportResult(teamsToSave: toSave, library: library, audioFiles: audioFiles, notes: notes)
    }
}
