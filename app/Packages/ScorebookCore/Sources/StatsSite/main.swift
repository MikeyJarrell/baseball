// The stats website builder: turns a copy of the app's saved files into the Diamond Dogs'
// public stats pages, served at mikeyjarrell.com/dogs/.
//
// tools/publish_stats.sh copies the saved files off the phone, runs this, and publishes the
// result. It can also be run by hand:
//
//   swift run StatsSite <app data folder> <output folder>
//
// - The app data folder is the app's `Library/Application Support/Scorebook`.
// - The output folder is emptied and filled with the pages:
//     index.html                 the record, the games, season batting and pitching tables
//     games/<date>-<opponent>.html   one game's newspaper box score
//     players/<name>.html        one player's season and game-by-game log
//
// Every number comes from the app's own rules engine and stats code, worked out fresh from
// each finished game's events, so the pages match the Season screen on the phone. Games
// still in progress are left out. Search engines are asked not to list any page.

import Foundation
import Model
import Storage
import GameEngine
import Stats
import BoxScoreText

/// Stops with a message.
func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("Error: \(message)\n".utf8))
    exit(1)
}

// Games are played in San Diego, so dates print in Pacific time.
let pacific = TimeZone(identifier: "America/Los_Angeles")!

// MARK: - Reading the saved games

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    fail("usage: StatsSite <app data folder> <output folder>")
}
let dataFolder = URL(fileURLWithPath: arguments[1])
let outputFolder = URL(fileURLWithPath: arguments[2])

// The loader never makes backups; any it would make go to a scratch folder.
let scratch = FileManager.default.temporaryDirectory.appendingPathComponent("stats-site-\(UUID().uuidString)")
let storage = try FileStorage(dataFolder: dataFolder, backupsFolder: scratch)

let teams = try await storage.loadTeams()
guard let ourTeam = teams.items.first(where: { $0.isOurs }) else {
    fail("no team is marked as ours in \(dataFolder.path)")
}
let finished = try await storage.finishedGames()
for damaged in finished.damaged {
    print("Skipped a game file that would not open: \(damaged.fileName) (\(damaged.reason))")
}
// Oldest game first.
let games = finished.items.sorted { $0.setup.scheduledStart < $1.setup.scheduledStart }

let engine = ScorebookRulesEngine()
let stats = StatsEngine()
let logs = games.map { engine.replay($0).log }
let boxScores = logs.map { stats.boxScore(for: $0) }
let season = stats.seasonTotals(for: logs, team: ourTeam.id)
// The tables list only players who have played: the season totals carry the whole roster.
let batters = season.batting.filter { $0.games > 0 }
    .sorted { ($0.stats.plateAppearances, $1.name) > ($1.stats.plateAppearances, $0.name) }
let pitchers = season.pitching.filter { $0.games > 0 }
    .sorted { ($0.stats.outsRecorded, $1.name) > ($1.stats.outsRecorded, $0.name) }

// MARK: - Small helpers

/// Text made safe to put inside a page.
func esc(_ s: String) -> String {
    s.replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
}

/// "Jackson Cleary" → "jackson-cleary": a name as a file name, letters and digits only.
func slug(_ s: String) -> String {
    let plain = s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US"))
    var out = ""
    for ch in plain.lowercased() {
        if ch.isLetter || ch.isNumber { out.append(ch) } else if !out.hasSuffix("-") { out.append("-") }
    }
    return out.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
}

/// "Sat, Oct 4" for a game date.
func shortDate(_ d: Date) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US")
    f.timeZone = pacific
    f.dateFormat = "EEE, MMM d"
    return f.string(from: d)
}

/// "2026-10-04" for a game's file name.
func fileDate(_ d: Date) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = pacific
    f.dateFormat = "yyyy-MM-dd"
    return f.string(from: d)
}

/// "W 9–4", "L 2–5", "T 3–3", our runs first.
func resultText(_ result: GameResult?, _ score: Score?, weAreHome: Bool?) -> String {
    guard let score, let home = weAreHome else { return "" }
    let ours = home ? score.home : score.away
    let theirs = home ? score.away : score.home
    let letter = switch result { case .win: "W"; case .loss: "L"; case .tie: "T"; case nil: "" }
    return "\(letter) \(ours)–\(theirs)"
}

// Each game's page name, made unique if two games share a date and opponent.
var gamePage: [GameID: String] = [:]
for game in games {
    let summary = GameSummary(game: game)
    var name = "\(fileDate(summary.date))-\(slug(summary.opponentName))"
    var n = 2
    while gamePage.values.contains(name) { name = "\(fileDate(summary.date))-\(slug(summary.opponentName))-\(n)"; n += 1 }
    gamePage[game.id] = name
}

// Each of our players' page name, made unique if two share a name.
var playerPage: [PlayerID: String] = [:]
for (id, name) in batters.map({ ($0.player, $0.name) }) + pitchers.map({ ($0.player, $0.name) }) {
    if playerPage[id] != nil { continue }
    var page = slug(name)
    var n = 2
    while playerPage.values.contains(page) { page = "\(slug(name))-\(n)"; n += 1 }
    playerPage[id] = page
}

/// A player's name linked to their page. `up` is "../" from a page one folder down.
@MainActor func playerLink(_ id: PlayerID, _ name: String, up: String) -> String {
    guard let page = playerPage[id] else { return esc(name) }
    return "<a href=\"\(up)players/\(page).html\">\(esc(name))</a>"
}

// MARK: - The page frame

/// A whole page around its body. `up` is "../" for pages one folder down.
@MainActor func page(title: String, up: String, body: String) -> String {
    """
    <!doctype html>
    <html lang="en">
    <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="robots" content="noindex, nofollow">
    <title>\(esc(title))</title>
    <link rel="stylesheet" href="\(up)style.css">
    </head>
    <body>
    <header class="masthead"><a href="\(up)index.html">\(esc(season.teamName))</a></header>
    <main>
    \(body)
    </main>
    <footer>Kept on the team scorebook app. Updated \(esc(shortDate(Date()))).</footer>
    <script src="\(up)sort.js"></script>
    </body>
    </html>

    """
}

/// One table cell holding a number: the text shown, and the value it sorts by.
func num(_ text: String, _ value: Double?) -> String {
    "<td class=\"n\" data-v=\"\(value.map { String($0) } ?? "-1")\">\(esc(text))</td>"
}
func num(_ n: Int) -> String { num(String(n), Double(n)) }
func rate(_ value: Double?) -> String { num(formattedRate(value), value) }
/// "1.40", for per-inning rates.
func perInning(_ value: Double?) -> String { num(value.map { String(format: "%.2f", $0) } ?? "—", value) }

/// A table that scrolls sideways on a narrow phone, its first column held in place. The first
/// `textColumns` columns hold words and line up on the left; the rest hold numbers.
func table(_ head: [String], _ rows: [String], sortable: Bool = true, textColumns: Int = 1, foot: String? = nil) -> String {
    let headCells = head.enumerated().map { i, h in
        i < textColumns ? "<th>\(h)</th>" : "<th class=\"n\">\(h)</th>"
    }.joined()
    let footRow = foot.map { "<tfoot>\($0)</tfoot>" } ?? ""
    return """
    <div class="scroll"><table\(sortable ? " class=\"sortable\"" : "")>
    <thead><tr>\(headCells)</tr></thead>
    <tbody>
    \(rows.joined(separator: "\n"))
    </tbody>\(footRow)
    </table></div>
    """
}

// MARK: - Batting and pitching rows

let battingHead = ["Player", "G", "PA", "AB", "R", "H", "2B", "3B", "HR", "RBI", "BB", "K", "SB", "AVG", "OBP", "SLG"]

func battingCells(_ s: BattingCounts) -> String {
    [num(s.plateAppearances), num(s.atBats), num(s.runs), num(s.hits), num(s.doubles), num(s.triples),
     num(s.homeRuns), num(s.runsBattedIn), num(s.walks), num(s.strikeouts), num(s.stolenBases),
     rate(s.battingAverage), rate(s.onBasePercentage), rate(s.sluggingPercentage)].joined()
}

let pitchingHead = ["Pitcher", "G", "W-L", "IP", "BF", "H", "R", "BB", "K", "HBP", "P", "WHIP", "K/IP"]

func pitchingCells(_ s: PitchingCounts) -> String {
    [num(s.inningsPitchedText, Double(s.outsRecorded)), num(s.battersFaced), num(s.hits), num(s.runs),
     num(s.walks), num(s.strikeouts), num(s.hitBatters), num(s.pitches),
     perInning(s.walksAndHitsPerInning), perInning(s.strikeoutsPerInning)].joined()
}

/// Season totals for the whole team, added up from every player's line.
@MainActor func teamBatting() -> BattingCounts {
    var t = BattingCounts()
    for line in season.batting {
        let s = line.stats
        t.plateAppearances += s.plateAppearances; t.atBats += s.atBats; t.runs += s.runs; t.hits += s.hits
        t.doubles += s.doubles; t.triples += s.triples; t.homeRuns += s.homeRuns
        t.runsBattedIn += s.runsBattedIn; t.walks += s.walks; t.strikeouts += s.strikeouts
        t.hitByPitch += s.hitByPitch; t.sacrificeFlies += s.sacrificeFlies; t.sacrificeBunts += s.sacrificeBunts
        t.stolenBases += s.stolenBases; t.caughtStealing += s.caughtStealing
    }
    return t
}

// MARK: - Writing the pages

let fm = FileManager.default
try? fm.removeItem(at: outputFolder)
try fm.createDirectory(at: outputFolder.appendingPathComponent("games"), withIntermediateDirectories: true)
try fm.createDirectory(at: outputFolder.appendingPathComponent("players"), withIntermediateDirectories: true)

func write(_ text: String, _ path: String) throws {
    try text.write(to: outputFolder.appendingPathComponent(path), atomically: true, encoding: .utf8)
}

// ---- The front page ----

var front = ""
let record = season.ties > 0 ? "\(season.wins)–\(season.losses)–\(season.ties)" : "\(season.wins)–\(season.losses)"
front += "<h1>Season stats</h1>\n<p class=\"record\">\(record) <span>in \(season.games) game\(season.games == 1 ? "" : "s")</span></p>\n"

front += "<h2>Games</h2>\n"
if games.isEmpty {
    front += "<p>No finished games yet.</p>\n"
} else {
    let rows = games.reversed().map { game -> String in
        let s = GameSummary(game: game)
        let at = s.weAreHome ? "vs." : "at"
        let res = resultText(s.result, s.finalScore, weAreHome: s.weAreHome)
        let cls = s.result.map { " class=\"\($0.rawValue)\"" } ?? ""
        return "<li><a href=\"games/\(gamePage[game.id]!).html\"><span class=\"date\">\(esc(shortDate(s.date)))</span> <span class=\"opp\">\(at) \(esc(s.opponentName))</span> <span\(cls)>\(esc(res))</span></a></li>"
    }
    front += "<ul class=\"games\">\n\(rows.joined(separator: "\n"))\n</ul>\n"
}

front += "<h2>Batting</h2>\n"
let battingRows = batters.map { line in
    "<tr><td>\(playerLink(line.player, line.name, up: ""))</td>\(num(line.games))\(battingCells(line.stats))</tr>"
}
let teamLine = "<tr><td>Team</td>\(num(season.games))\(battingCells(teamBatting()))</tr>"
front += table(battingHead, battingRows, foot: teamLine)

if !pitchers.isEmpty {
    front += "<h2>Pitching</h2>\n"
    let rows = pitchers.map { line in
        "<tr><td>\(playerLink(line.player, line.name, up: ""))</td>\(num(line.games))\(num("\(line.wins)-\(line.losses)", Double(line.wins - line.losses)))\(pitchingCells(line.stats))</tr>"
    }
    front += table(pitchingHead, rows)
}
front += "<p class=\"hint\">Tap a column heading to sort.</p>\n"
try write(page(title: "\(season.teamName) stats", up: "", body: front), "index.html")

// ---- One page per game ----

for (game, box) in zip(games, boxScores) {
    let s = GameSummary(game: game)
    let text = BoxScorePrinter.text(box, timeZone: pacific)
    let at = s.weAreHome ? "vs." : "at"
    let body = """
    <h1>\(esc(shortDate(s.date))) \(at) \(esc(s.opponentName))</h1>
    <pre class="box">\(esc(text))</pre>
    """
    try write(page(title: "\(season.teamName) \(at) \(s.opponentName), \(shortDate(s.date))", up: "../", body: body),
              "games/\(gamePage[game.id]!).html")
}

// ---- One page per player ----

/// A game log row's first cells: the date (linked to the game) and the opponent and result.
@MainActor func gameCells<C>(_ entry: GameLogEntry<C>) -> String {
    let date = gamePage[entry.gameID].map { "<a href=\"../games/\($0).html\">\(esc(shortDate(entry.date)))</a>" } ?? esc(shortDate(entry.date))
    let at = entry.weAreHome == true ? "vs." : "at"
    return "<td>\(date)</td><td>\(at) \(esc(entry.opponentName))</td><td>\(esc(resultText(entry.result, entry.finalScore, weAreHome: entry.weAreHome)))</td>"
}

for (id, pageName) in playerPage {
    let batting = batters.first { $0.player == id }
    let pitching = pitchers.first { $0.player == id }
    let name = batting?.name ?? pitching?.name ?? ""
    let number = batting?.number ?? pitching?.number
    var body = "<h1>\(esc(name))\(number.map { " <span class=\"num\">#\(esc($0))</span>" } ?? "")</h1>\n"

    if let b = batting {
        body += "<h2>Batting</h2>\n"
        body += table([""] + battingHead.dropFirst(),
                      ["<tr><td>Season</td>\(num(b.games))\(battingCells(b.stats))</tr>"], sortable: false)
        let rows = b.gameLog.reversed().map { e in
            "<tr>\(gameCells(e))\(num(e.stats.atBats))\(num(e.stats.runs))\(num(e.stats.hits))\(num(e.stats.doubles))\(num(e.stats.triples))\(num(e.stats.homeRuns))\(num(e.stats.runsBattedIn))\(num(e.stats.walks))\(num(e.stats.strikeouts))\(num(e.stats.stolenBases))</tr>"
        }
        body += "<h3>Game by game</h3>\n"
        body += table(["Date", "Opponent", "Result", "AB", "R", "H", "2B", "3B", "HR", "RBI", "BB", "K", "SB"], rows, sortable: false, textColumns: 3)
    }
    if let p = pitching {
        body += "<h2>Pitching</h2>\n"
        body += table([""] + pitchingHead.dropFirst(),
                      ["<tr><td>Season</td>\(num(p.games))\(num("\(p.wins)-\(p.losses)", nil))\(pitchingCells(p.stats))</tr>"], sortable: false)
        let rows = p.gameLog.reversed().map { e in
            "<tr>\(gameCells(e))\(num(e.stats.inningsPitchedText, nil))\(num(e.stats.battersFaced))\(num(e.stats.hits))\(num(e.stats.runs))\(num(e.stats.walks))\(num(e.stats.strikeouts))\(num(e.stats.pitches))</tr>"
        }
        body += "<h3>Game by game</h3>\n"
        body += table(["Date", "Opponent", "Result", "IP", "BF", "H", "R", "BB", "K", "P"], rows, sortable: false, textColumns: 3)
    }
    try write(page(title: "\(name), \(season.teamName)", up: "../", body: body), "players/\(pageName).html")
}

// ---- The style, the sorting script, and the no-search-engines file ----

try write(style, "style.css")
try write(sortScript, "sort.js")
try write("User-agent: *\nDisallow: /\n", "robots.txt")
// GitHub Pages serves the files as they are, without its own page builder.
try write("", ".nojekyll")

print("Wrote \(games.count) game page\(games.count == 1 ? "" : "s") and \(playerPage.count) player pages to \(outputFolder.path)")
