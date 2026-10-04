// GameOverview: the game so far, a swipe away from the batting screen, for checking on the
// game without changing it.
//
// Matches the approved mockup (plan/mockups/index.html, SCREENS.overview): a top bar with
// "At bat" to go back and the score, then four tabs:
//   1. Score: the line score by inning with runs, hits and errors, where the game stands
//      right now, runners left on base, and the box score notes so far;
//   2. Box: both teams' batters, each with today's plate appearances in scorebook notation;
//   3. Pitchers: everyone who has pitched today, with innings, pitches and strikes, batters
//      faced and their line so far;
//   4. Plays: every event, newest first, grouped by half-inning. Tapping one opens "Fix a
//      play" (FixPlaySheet), which hands back a change or a delete.
//
// The screen computes nothing about baseball. It is handed the box score so far (from stats),
// the play log (from the rules engine), each batter's plate appearances (from stats) and the
// situation, and hands back what the scorer asked for as a `GameOverviewAction`. The app
// applies an edit and hands the screen the recalculated game.
//
// The tabs are in ScoreTab, BoxTab, PitchersTab and PlaysTab; the words in OverviewWording;
// the play-by-play rows in PlayByPlay; the previews in Previews.

import SwiftUI
import Model
import SampleData
import DesignSystem

// MARK: - What the screen hands back

/// Everything the scorer can ask for on the game overview. The app shell acts on each one.
public enum GameOverviewAction: Equatable, Sendable {
    /// Go back to the batting screen (the "At bat" button, or a swipe to the right from the
    /// left edge).
    case backToBatting
    /// Apply this change to the game's event list, then work everything after it out again:
    /// `.delete(id)` from "Delete it", or `.replace(event)` when a pitch was changed to
    /// another kind of pitch in the sheet.
    case edit(EventEdit)
    /// Open this event's own steps filled in, so the scorer can change it: the in-play steps
    /// for a ball in play, the runner moves for a runner action, the change sheet for a
    /// substitution. What the scorer saves there comes back to the app as `.replace`.
    case openEditor(GameEvent)
}

/// The four tabs along the top.
public enum GameOverviewTab: String, CaseIterable, Identifiable, Sendable {
    case score, box, pitchers, plays

    public var id: String { rawValue }

    /// The tab's word, as in the mockup.
    var title: String {
        switch self {
        case .score: "Score"
        case .box: "Box"
        case .pitchers: "Pitchers"
        case .plays: "Plays"
        }
    }
}

// MARK: - The screen

/// The game overview.
///
/// - Parameters:
///   - log: The play log so far, from the rules engine. Its setup has both rosters, for names.
///   - boxScore: The box score so far, from stats (`boxScore(for: log)`).
///   - plateAppearances: Each batter's plate appearances today, oldest first, in scorebook
///     notation, from stats (`plateAppearances(of:in:)` for every batter).
///   - situation: Where the game stands now, from the rules engine, for the "Right now" card,
///     the highlighted inning and the batter at the plate. Leave it out for a finished game.
///   - startingTab: The tab to open on. The Score tab, as in the mockup.
///   - onAction: Called with everything the scorer asks for.
public struct GameOverview: View {
    public var log: PlayLog
    public var boxScore: BoxScore
    public var plateAppearances: [PlayerID: [PlateAppearanceSummary]]
    public var situation: Situation?
    public var onAction: (GameOverviewAction) -> Void

    @State private var tab: GameOverviewTab
    @Environment(\.dynamicTypeSize) private var typeSize

    public init(
        log: PlayLog,
        boxScore: BoxScore,
        plateAppearances: [PlayerID: [PlateAppearanceSummary]],
        situation: Situation? = nil,
        startingTab: GameOverviewTab = .score,
        onAction: @escaping (GameOverviewAction) -> Void
    ) {
        self.log = log
        self.boxScore = boxScore
        self.plateAppearances = plateAppearances
        self.situation = situation
        self.onAction = onAction
        _tab = State(initialValue: startingTab)
    }

    public var body: some View {
        VStack(spacing: 0) {
            topBar
            TabPicker(selection: $tab)
                .padding(.horizontal, Spacing.screenEdge)
                .padding(.bottom, Spacing.small)
            Group {
                switch tab {
                case .score:
                    ScoreTab(setup: log.setup, boxScore: boxScore, situation: situation)
                case .box:
                    BoxTab(setup: log.setup, boxScore: boxScore, plateAppearances: plateAppearances)
                case .pitchers:
                    PitchersTab(setup: log.setup, boxScore: boxScore, situation: situation)
                case .plays:
                    PlaysTab(log: log, situation: situation, onAction: onAction)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(ScorebookColor.background)
        .foregroundStyle(ScorebookColor.textPrimary)
        // A swipe to the right that starts near the left edge goes back to the batting screen,
        // as the swipe to the left on the batting screen came here. Starting at the edge keeps
        // it from fighting the tables that scroll sideways.
        .simultaneousGesture(
            DragGesture(minimumDistance: 30)
                .onEnded { drag in
                    if drag.startLocation.x < 40, drag.translation.width > 80,
                       abs(drag.translation.height) < drag.translation.width / 2 {
                        onAction(.backToBatting)
                    }
                }
        )
        .accessibilityAction(named: "Back to the batting screen") { onAction(.backToBatting) }
    }

    /// "‹ At bat" on the left, the score and the game's state in the middle. At the
    /// accessibility text sizes the button gets a line of its own above the score, so the
    /// two never overlap.
    @ViewBuilder private var topBar: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 0) {
                    backButton
                    title.frame(maxWidth: .infinity)
                }
            } else {
                ZStack {
                    title.padding(.horizontal, 96)
                    HStack {
                        backButton
                        Spacer()
                    }
                }
            }
        }
        .padding(.horizontal, Spacing.screenEdge)
        .padding(.vertical, Spacing.extraSmall)
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }

    /// The score and the game's state: "Diamond Dogs 3, Mudcats 2 / Bottom 3rd · live".
    private var title: some View {
        VStack(spacing: 0) {
            Text(OverviewWording.score(Score(away: boxScore.away.runs, home: boxScore.home.runs), setup: log.setup))
                .font(ScorebookFont.headline)
                .monospacedDigit()
                .multilineTextAlignment(.center)
                .lineLimit(typeSize.isAccessibilitySize ? 3 : 1)
                .minimumScaleFactor(0.7)
            Text(status)
                .font(ScorebookFont.caption)
                .foregroundStyle(ScorebookColor.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    /// "‹ At bat": back to the batting screen.
    private var backButton: some View {
        Button {
            onAction(.backToBatting)
        } label: {
            HStack(spacing: 2) {
                Image(systemName: "chevron.left")
                Text("At bat")
            }
            .font(ScorebookFont.body.weight(.semibold))
            .foregroundStyle(ScorebookColor.highlight)
            .frame(minHeight: Spacing.minimumTapSize)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back to the batting screen")
    }

    /// The small line under the score: "Bottom 3rd · live", "Final".
    private var status: String {
        if boxScore.isFinal || situation?.isFinal == true { return "Final" }
        guard let situation else { return "In progress" }
        if situation.isBetweenHalfInnings { return "\(OverviewWording.rightNow(situation)) · live" }
        return "\(OverviewWording.halfInning(situation.half, situation.inning)) · live"
    }
}

// MARK: - The tabs along the top

/// The four tabs as a segmented row, as in the mockup.
struct TabPicker: View {
    @Binding var selection: GameOverviewTab

    var body: some View {
        HStack(spacing: 2) {
            ForEach(GameOverviewTab.allCases) { tab in
                let isOn = tab == selection
                Button {
                    selection = tab
                } label: {
                    Text(tab.title)
                        .font(ScorebookFont.chip)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(isOn ? ScorebookColor.textPrimary : ScorebookColor.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background {
                            if isOn {
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(ScorebookColor.surface)
                                    .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? [.isSelected] : [])
            }
        }
        .padding(3)
        .background(ScorebookColor.surfaceSecondary, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }
}
