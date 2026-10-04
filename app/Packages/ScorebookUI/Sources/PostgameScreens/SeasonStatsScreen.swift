// The season stats screen: our hitters and pitchers, in sortable tables.
//
// As in the approved mockup: a large "Season" title, the team, games played and the record,
// a Batting / Pitching switch, and for batting a chip that hides averages below a number of
// plate appearances. The table's names stay pinned on the left while the numbers scroll
// sideways. Tapping a column heading sorts by it (biggest first; tap again to flip). Tapping a
// player asks for their page.

import SwiftUI
import Model
import SampleData
import DesignSystem

/// Our team's season stats.
///
/// - Parameters:
///   - totals: The season totals from the stats engine.
///   - games: The games list, for the season record ("9 wins, 5 losses"). Leave it empty to
///     show no record.
///   - minimumPlateAppearances: Where the averages filter starts: hitters with fewer plate
///     appearances show a dash for their averages. 10, as in the mockup; 0 shows everyone's.
///   - onRequest: Called with the player the scorer taps.
public struct SeasonStatsScreen: View {
    public var totals: SeasonTotals
    public var games: [GameSummary]
    public var onRequest: (PostgameRequest) -> Void

    /// Which table is showing.
    enum Table: String, CaseIterable, Identifiable {
        case batting = "Batting"
        case pitching = "Pitching"
        var id: String { rawValue }
    }

    @State private var table: Table = .batting
    /// The batting table starts sorted by batting average, best first, as in the mockup.
    @State private var battingSort = SortChoice(column: BattingColumn.average, descending: true)
    /// The pitching table starts with whoever pitched the most innings on top.
    @State private var pitchingSort = SortChoice(column: PitchingColumn.innings, descending: true)
    @State private var minimumPlateAppearances: Int

    public init(totals: SeasonTotals, games: [GameSummary] = [], minimumPlateAppearances: Int = 10,
                onRequest: @escaping (PostgameRequest) -> Void) {
        self.totals = totals
        self.games = games
        self.onRequest = onRequest
        _minimumPlateAppearances = State(initialValue: minimumPlateAppearances)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                Text(subtitle)
                    .font(ScorebookFont.body)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(ScorebookColor.textSecondary)
                Picker("Table", selection: $table) {
                    ForEach(Table.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                if table == .batting {
                    averagesFilter
                }
            }
            .padding(.horizontal, Spacing.large)

            switch table {
            case .batting: battingTable
            case .pitching: pitchingTable
            }

            Text("Tap a column to sort. The table scrolls sideways; names stay put.")
                .font(ScorebookFont.caption)
                .foregroundStyle(ScorebookColor.textSecondary)
                .padding(.horizontal, Spacing.large)
            Spacer(minLength: 0)
        }
        .padding(.top, Spacing.small)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(ScorebookColor.background)
        // The table needs room for some rows, so the words stop growing at the second
        // accessibility size; the table's own rows still grow up to that size.
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .navigationTitle("Season")
    }

    /// "Diamond Dogs · 14 games · 9 wins, 5 losses".
    private var subtitle: String {
        var parts = [totals.teamName, PostgameWording.counted(totals.games, "game", "games")]
        if let record = PostgameWording.record(games) { parts.append(record) }
        return parts.joined(separator: " · ")
    }

    // MARK: The averages filter

    /// The chip that sets the minimum plate appearances for averages, with "for averages"
    /// beside it. Tapping it opens the choices.
    private var averagesFilter: some View {
        let isOn = minimumPlateAppearances > 0
        return HStack(spacing: Spacing.small) {
            Menu {
                Picker("Show averages for", selection: $minimumPlateAppearances) {
                    ForEach(MinimumPlateAppearances.choices, id: \.self) { minimum in
                        Text(minimum == 0 ? "Everyone" : "At least \(minimum) plate appearances").tag(minimum)
                    }
                }
            } label: {
                HStack(spacing: Spacing.extraSmall) {
                    Text(MinimumPlateAppearances.label(minimumPlateAppearances))
                    Image(systemName: "chevron.down").font(ScorebookFont.caption.weight(.bold))
                }
                .font(ScorebookFont.chip)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(isOn ? ScorebookColor.background : ScorebookColor.textPrimary)
                .padding(.horizontal, Spacing.medium)
                .frame(minHeight: Spacing.minimumTapSize)
                .background(isOn ? ScorebookColor.textPrimary : ScorebookColor.surfaceSecondary, in: Capsule())
            }
            .accessibilityLabel("Averages filter")
            .accessibilityValue(minimumPlateAppearances == 0
                                ? "showing averages for everyone"
                                : "showing averages for players with at least \(minimumPlateAppearances) plate appearances")
            if isOn {
                Text("for averages")
                    .font(ScorebookFont.caption)
                    .foregroundStyle(ScorebookColor.textSecondary)
                    .lineLimit(1)
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }

    // MARK: The tables

    private var battingTable: some View {
        let minimum = minimumPlateAppearances
        let rows = StatSorting.batting(totals.batting, by: battingSort, minimumPlateAppearances: minimum)
        let columns = BattingColumn.allCases.map { column in
            StatsTableColumn<SeasonBattingLine>(
                id: column.id, title: column.title, spokenName: column.spokenName,
                width: column.isRate ? 52 : (column == .runsBattedIn ? 40 : 34),
                text: { line in
                    if column.isRate && StatSorting.hidesAverages(line, minimumPlateAppearances: minimum) { return "—" }
                    return column.text(line.stats, games: line.games)
                },
                isDimmed: { line in column.isRate && StatSorting.hidesAverages(line, minimumPlateAppearances: minimum) }
            )
        }
        return Group {
            if rows.isEmpty {
                emptyMessage("No hitters yet. Stats appear here after the first game.")
            } else {
                StatsTable(
                    rows: rows, nameTitle: "Player", name: \.name, columns: columns,
                    sortedColumnID: battingSort.column.id, sortedDescending: battingSort.descending,
                    onSort: { id in
                        if let column = BattingColumn(rawValue: id) { battingSort.choose(column) }
                    },
                    onTapRow: { onRequest(.openPlayer($0.player)) },
                    rowHint: "Opens their season page"
                )
                .padding(.horizontal, Spacing.screenEdge)
            }
        }
    }

    private var pitchingTable: some View {
        let rows = StatSorting.pitching(totals.pitching, by: pitchingSort)
        let columns = PitchingColumn.allCases.map { column in
            StatsTableColumn<SeasonPitchingLine>(
                id: column.id, title: column.title, spokenName: column.spokenName,
                width: column.isRate ? 54 : pitchingWidth(column),
                text: { column.text($0.stats, games: $0.games) }
            )
        }
        return Group {
            if rows.isEmpty {
                emptyMessage("Nobody has pitched yet.")
            } else {
                StatsTable(
                    rows: rows, nameTitle: "Pitcher", name: \.name, columns: columns,
                    sortedColumnID: pitchingSort.column.id, sortedDescending: pitchingSort.descending,
                    onSort: { id in
                        if let column = PitchingColumn(rawValue: id) {
                            pitchingSort.choose(column, firstDescending: !column.smallerIsBetter)
                        }
                    },
                    onTapRow: { onRequest(.openPlayer($0.player)) },
                    rowHint: "Opens their season page"
                )
                .padding(.horizontal, Spacing.screenEdge)
            }
        }
    }

    /// How wide a pitching count column is: room for "58.1" innings and three-digit batters
    /// faced and pitches.
    private func pitchingWidth(_ column: PitchingColumn) -> CGFloat {
        switch column {
        case .innings, .battersFaced, .pitches, .hitBatters: 44
        default: 34
        }
    }

    /// A card with a message, for a table with nobody in it.
    private func emptyMessage(_ text: String) -> some View {
        Text(text)
            .font(ScorebookFont.body)
            .foregroundStyle(ScorebookColor.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.large)
            .background(ScorebookColor.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, Spacing.screenEdge)
    }
}
