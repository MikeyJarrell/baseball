// The season stats screen: our hitters and pitchers, in sortable tables.
//
// As in the approved mockup: a large "Season" title, the team, games played and the record,
// a Batting / Pitching switch, and a chip that hides averages below a number of plate
// appearances (for pitchers, per-inning rates below a number of innings). The table's names
// stay pinned on the left while the numbers scroll sideways. Tapping a column heading sorts by
// it (biggest first; tap again to flip). Tapping a player asks for their page.

import SwiftUI
import Model
import SampleData
import DesignSystem

/// Our team's season stats.
///
/// - Parameters:
///   - totals: The season totals from the stats engine, with the season record ("9 wins,
///     5 losses") and each pitcher's wins and losses.
///   - minimumPlateAppearances: Where the hitters' filter starts: hitters with fewer plate
///     appearances show a dash for their averages. 10, as in the mockup; 0 shows everyone's.
///     Pass back the last choice the screen handed back, so it is remembered.
///   - minimumInnings: Where the pitchers' filter starts: pitchers with fewer innings show a
///     dash for walks and hits, strikeouts and walks per inning. 3 unless remembered.
///   - onRequest: Called with the player the scorer taps, and with each new minimum the scorer
///     picks (`setMinimumPlateAppearances`, `setMinimumInnings`) for the app to keep.
public struct SeasonStatsScreen: View {
    public var totals: SeasonTotals
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
    @State private var minimumInnings: Int

    public init(totals: SeasonTotals, minimumPlateAppearances: Int = 10,
                minimumInnings: Int = 3, onRequest: @escaping (PostgameRequest) -> Void) {
        self.totals = totals
        self.onRequest = onRequest
        _minimumPlateAppearances = State(initialValue: minimumPlateAppearances)
        _minimumInnings = State(initialValue: minimumInnings)
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
                switch table {
                case .batting:
                    MinimumFilterChip(
                        minimum: $minimumPlateAppearances, choices: MinimumPlateAppearances.choices,
                        label: MinimumPlateAppearances.label, choiceLabel: MinimumPlateAppearances.choiceLabel,
                        besideText: "for averages", spokenName: "Averages filter",
                        spokenValue: { $0 == 0 ? "showing averages for everyone"
                            : "showing averages for players with at least \($0) plate appearances" })
                case .pitching:
                    MinimumFilterChip(
                        minimum: $minimumInnings, choices: MinimumInnings.choices,
                        label: MinimumInnings.label, choiceLabel: MinimumInnings.choiceLabel,
                        besideText: "for rates", spokenName: "Pitching rates filter",
                        spokenValue: { $0 == 0 ? "showing rates for everyone"
                            : "showing rates for pitchers with at least \(PostgameWording.counted($0, "inning", "innings"))" })
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
        // Hand each new minimum back, so the app can remember it for next time.
        .onChange(of: minimumPlateAppearances) { _, minimum in onRequest(.setMinimumPlateAppearances(minimum)) }
        .onChange(of: minimumInnings) { _, minimum in onRequest(.setMinimumInnings(minimum)) }
    }

    /// "Diamond Dogs · 14 games · 9 wins, 5 losses".
    private var subtitle: String {
        var parts = [totals.teamName, PostgameWording.counted(totals.games, "game", "games")]
        if let record = PostgameWording.record(totals) { parts.append(record) }
        return parts.joined(separator: " · ")
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
        let minimum = minimumInnings
        let rows = StatSorting.pitching(totals.pitching, by: pitchingSort, minimumInnings: minimum)
        let columns = PitchingColumn.allCases.map { column in
            StatsTableColumn<SeasonPitchingLine>(
                id: column.id, title: column.title, spokenName: column.spokenName,
                width: column.isRate ? 54 : pitchingWidth(column),
                text: { line in
                    if column.isRate && StatSorting.hidesRates(line, minimumInnings: minimum) { return "—" }
                    return column.text(line)
                },
                isDimmed: { line in column.isRate && StatSorting.hidesRates(line, minimumInnings: minimum) }
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

    /// How wide a pitching count column is: room for "58.1" innings, three-digit batters
    /// faced and pitches, and "10-10" wins and losses.
    private func pitchingWidth(_ column: PitchingColumn) -> CGFloat {
        switch column {
        case .innings, .battersFaced, .pitches, .hitBatters, .winsAndLosses: 44
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

/// The filter chip over a season table: "At least 10 plate appearances ⌄" with "for averages"
/// beside it, dark when a minimum is set. Tapping it opens the choices.
private struct MinimumFilterChip: View {
    @Binding var minimum: Int
    var choices: [Int]
    /// The words on the chip for a minimum.
    var label: (Int) -> String
    /// The words in the menu for a minimum.
    var choiceLabel: (Int) -> String
    /// The small words beside the chip when a minimum is set: "for averages".
    var besideText: String
    var spokenName: String
    var spokenValue: (Int) -> String

    var body: some View {
        let isOn = minimum > 0
        HStack(spacing: Spacing.small) {
            Menu {
                Picker(spokenName, selection: $minimum) {
                    ForEach(choices, id: \.self) { Text(choiceLabel($0)).tag($0) }
                }
            } label: {
                HStack(spacing: Spacing.extraSmall) {
                    Text(label(minimum))
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
            .accessibilityLabel(spokenName)
            .accessibilityValue(spokenValue(minimum))
            if isOn {
                Text(besideText)
                    .font(ScorebookFont.caption)
                    .foregroundStyle(ScorebookColor.textSecondary)
                    .lineLimit(1)
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }
}
