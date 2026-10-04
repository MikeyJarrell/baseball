// One player's season: their number and name, the three averages in big type, every batting
// count, their pitching and fielding if they pitched or fielded, and a game-by-game log for
// each, newest game first. Tapping a game in a log asks for that game's box score.
//
// The mockup has no stats page for a player (its player page is the songs page), so this one
// is drawn in the mockup's style: cards on the gray background, a section label over each.

import SwiftUI
import Model
import SampleData
import DesignSystem

/// One of our players' season.
///
/// - Parameters:
///   - totals: The season totals from the stats engine.
///   - player: Which player to show.
///   - onRequest: Called with the game the scorer taps in a log.
public struct PlayerSeasonScreen: View {
    public var totals: SeasonTotals
    public var player: PlayerID
    public var onRequest: (PostgameRequest) -> Void

    public init(totals: SeasonTotals, player: PlayerID, onRequest: @escaping (PostgameRequest) -> Void) {
        self.totals = totals
        self.player = player
        self.onRequest = onRequest
    }

    private var batting: SeasonBattingLine? { totals.batting.first { $0.player == player } }
    private var pitching: SeasonPitchingLine? { totals.pitching.first { $0.player == player } }
    private var fielding: SeasonFieldingLine? { totals.fielding.first { $0.player == player } }

    /// The name from whichever line has it.
    private var name: String { batting?.name ?? pitching?.name ?? fielding?.name ?? "Player" }
    private var number: String? { batting?.number ?? pitching?.number }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.large) {
                header
                if let batting {
                    battingSection(batting)
                }
                if let pitching {
                    pitchingSection(pitching)
                }
                if let fielding {
                    section("Fielding") {
                        countsGrid([("PO", "putouts", fielding.stats.putouts),
                                    ("A", "assists", fielding.stats.assists),
                                    ("E", "errors", fielding.stats.errors)].map { ($0.0, $0.1, "\($0.2)") })
                    }
                }
                if batting == nil && pitching == nil && fielding == nil {
                    card {
                        Text("No stats for this player this season.")
                            .font(ScorebookFont.body)
                            .foregroundStyle(ScorebookColor.textSecondary)
                    }
                }
            }
            .padding(.horizontal, Spacing.screenEdge)
            .padding(.bottom, Spacing.large)
        }
        .background(ScorebookColor.background)
        // Three averages share one row, so the words stop growing at the third accessibility size.
        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Header

    /// The number badge, the name, and the team.
    private var header: some View {
        HStack(spacing: Spacing.medium) {
            PlayerNumberBadge(number ?? "?", look: .ours, size: 50)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(ScorebookFont.batterName)
                    .foregroundStyle(ScorebookColor.textPrimary)
                Text(totals.teamName)
                    .font(ScorebookFont.caption)
                    .foregroundStyle(ScorebookColor.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, Spacing.small)
        .accessibilityElement(children: .combine)
    }

    // MARK: Batting

    private func battingSection(_ line: SeasonBattingLine) -> some View {
        let s = line.stats
        return VStack(alignment: .leading, spacing: Spacing.large) {
            section("Batting") {
                VStack(alignment: .leading, spacing: Spacing.medium) {
                    // The three averages, big.
                    HStack(spacing: 0) {
                        bigNumber(formattedRate(s.battingAverage), "AVG", spoken: "batting average")
                        bigNumber(formattedRate(s.onBasePercentage), "OBP", spoken: "on-base percentage")
                        bigNumber(formattedRate(s.sluggingPercentage), "SLG", spoken: "slugging percentage")
                    }
                    Rectangle().fill(ScorebookColor.divider).frame(height: 0.5)
                    countsGrid([
                        ("G", "games", line.games), ("PA", "plate appearances", s.plateAppearances),
                        ("AB", "at-bats", s.atBats), ("R", "runs", s.runs), ("H", "hits", s.hits),
                        ("2B", "doubles", s.doubles), ("3B", "triples", s.triples), ("HR", "home runs", s.homeRuns),
                        ("RBI", "runs batted in", s.runsBattedIn), ("BB", "walks", s.walks),
                        ("K", "strikeouts", s.strikeouts), ("HBP", "hit by pitch", s.hitByPitch),
                        ("SF", "sacrifice flies", s.sacrificeFlies), ("SH", "sacrifice bunts", s.sacrificeBunts),
                        ("SB", "stolen bases", s.stolenBases), ("CS", "caught stealing", s.caughtStealing),
                    ].map { ($0.0, $0.1, "\($0.2)") })
                }
            }
            gameLog(title: "Batting game by game", entries: line.gameLog,
                    columns: BattingColumn.gameLog.map { column in
                        StatsTableColumn<GameLogEntry<BattingCounts>>(
                            id: column.id, title: column.title, spokenName: column.spokenName,
                            width: column == .runsBattedIn ? 40 : 34,
                            text: { column.text($0.stats) })
                    })
        }
    }

    // MARK: Pitching

    private func pitchingSection(_ line: SeasonPitchingLine) -> some View {
        let s = line.stats
        return VStack(alignment: .leading, spacing: Spacing.large) {
            section("Pitching") {
                VStack(alignment: .leading, spacing: Spacing.medium) {
                    HStack(spacing: 0) {
                        bigNumber(s.inningsPitchedText, "IP", spoken: "innings pitched")
                        bigNumber(PostgameWording.perInning(s.walksAndHitsPerInning), "WHIP",
                                  spoken: "walks and hits per inning")
                        bigNumber(PostgameWording.perInning(s.strikeoutsPerInning), "K/IP",
                                  spoken: "strikeouts per inning")
                    }
                    Rectangle().fill(ScorebookColor.divider).frame(height: 0.5)
                    countsGrid([
                        ("G", "games", "\(line.games)"), ("BF", "batters faced", "\(s.battersFaced)"),
                        ("H", "hits allowed", "\(s.hits)"), ("R", "runs allowed", "\(s.runs)"),
                        ("BB", "walks", "\(s.walks)"), ("K", "strikeouts", "\(s.strikeouts)"),
                        ("HR", "home runs allowed", "\(s.homeRuns)"), ("HBP", "hit batters", "\(s.hitBatters)"),
                        ("P", "pitches", "\(s.pitches)"), ("S", "strikes", "\(s.strikes)"),
                    ])
                }
            }
            gameLog(title: "Pitching game by game", entries: line.gameLog,
                    columns: PitchingColumn.gameLog.map { column in
                        StatsTableColumn<GameLogEntry<PitchingCounts>>(
                            id: column.id, title: column.title, spokenName: column.spokenName,
                            width: column == .innings ? 44 : 36,
                            text: { column.text($0.stats) })
                    })
        }
    }

    // MARK: Game logs

    /// A game-by-game table, newest game first, with the date and opponent pinned on the left.
    @ViewBuilder
    private func gameLog<Counts>(title: String, entries: [GameLogEntry<Counts>],
                                 columns: [StatsTableColumn<GameLogEntry<Counts>>]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            sectionLabel(title)
            if entries.isEmpty {
                card {
                    Text("No games yet.")
                        .font(ScorebookFont.body)
                        .foregroundStyle(ScorebookColor.textSecondary)
                }
            } else {
                StatsTable(
                    rows: StatSorting.newestFirst(entries), nameTitle: "Game",
                    name: { "\(PostgameWording.shortDate($0.date)) \($0.opponentName)" },
                    columns: columns,
                    onTapRow: { onRequest(.openGame($0.gameID)) },
                    rowHint: "Opens the box score",
                    scrollsVertically: false,
                    // Room for the date and the opponent on two lines.
                    rowHeight: 60
                )
            }
        }
    }

    // MARK: Small parts

    /// A section label over a card: "BATTING".
    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(ScorebookFont.sectionLabel)
            .foregroundStyle(ScorebookColor.textSecondary)
            .padding(.horizontal, Spacing.extraSmall)
            .accessibilityAddTraits(.isHeader)
    }

    /// A section: its label, then its content on a card.
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            sectionLabel(title)
            card(content: content)
        }
    }

    /// White (or dark gray) rounded card.
    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.large)
            .background(ScorebookColor.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    /// One big number with its label under it: ".333" over "AVG".
    private func bigNumber(_ value: String, _ label: String, spoken: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(ScorebookFont.scoreboardSmall)
                .foregroundStyle(ScorebookColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
            Text(label)
                .font(ScorebookFont.sectionLabel)
                .foregroundStyle(ScorebookColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(spoken) \(value)")
    }

    /// A grid of small counts, each a label over a number, as many to a row as fit.
    private func countsGrid(_ counts: [(label: String, spoken: String, value: String)]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: Spacing.small)],
                  alignment: .leading, spacing: Spacing.medium) {
            ForEach(counts.indices, id: \.self) { i in
                let count = counts[i]
                VStack(alignment: .leading, spacing: 2) {
                    Text(count.label)
                        .font(ScorebookFont.sectionLabel)
                        .foregroundStyle(ScorebookColor.textSecondary)
                    Text(count.value)
                        .font(ScorebookFont.headline.monospacedDigit())
                        .foregroundStyle(ScorebookColor.textPrimary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(count.spoken) \(count.value)")
            }
        }
    }
}
