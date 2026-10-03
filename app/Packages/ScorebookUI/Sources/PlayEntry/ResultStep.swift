// Step one, "What happened to the batter?", and the dropped-third-strike step that takes its
// place when the sequence opens after strike three.

import SwiftUI
import Model
import DesignSystem

/// "What happened to the batter?": batter out, the four hits, reached on error, fielder's
/// choice, and "More" for sacrifices, dropped third strike and catcher's interference.
struct ResultStep: View {
    let model: PlayEntryModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            Text("What happened to the batter?")
                .font(ScorebookFont.largeTitle)
                .foregroundStyle(ScorebookColor.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, Spacing.large)
                .accessibilityAddTraits(.isHeader)
            Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                GridRow {
                    answer(.out, "Batter out", detail: "ground, fly, line, pop, bunt", kind: .dark, large: true)
                        .gridCellColumns(2)
                }
                GridRow {
                    answer(.single, "Single", kind: .blue)
                    answer(.double, "Double", kind: .blue)
                }
                GridRow {
                    answer(.triple, "Triple", kind: .blue)
                    answer(.homeRun, "Home run", kind: .blue)
                }
                GridRow {
                    answer(.reachedOnError, "Reached on error", kind: .light)
                    answer(.fieldersChoice, "Fielder’s choice", detail: "batter safe, runner out", kind: .light)
                }
                if model.showsMore {
                    GridRow {
                        answer(.sacrificeFly, "Sacrifice fly", kind: .light)
                        answer(.sacrificeBunt, "Sacrifice bunt", kind: .light)
                    }
                    GridRow {
                        Button { model.perform(.pickDroppedThirdStrike) } label: {
                            BigChoiceLabel(title: "Dropped 3rd strike")
                        }
                        .buttonStyle(BigChoiceButtonStyle(kind: .light))
                        answer(.catchersInterference, "Catcher’s interference", kind: .light)
                    }
                } else {
                    GridRow {
                        Button { model.perform(.showMore) } label: {
                            BigChoiceLabel(title: "More: sacrifice, dropped 3rd strike, interference")
                        }
                        .buttonStyle(BigChoiceButtonStyle(kind: .quiet))
                        .gridCellColumns(2)
                    }
                }
            }
            .padding(.horizontal, Spacing.screenEdge)
            .padding(.bottom, Spacing.small)
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    /// One big answer button.
    private func answer(_ result: BatterResult, _ title: String, detail: String? = nil, kind: BigChoiceKind, large: Bool = false) -> some View {
        Button { model.perform(.pickResult(result)) } label: {
            BigChoiceLabel(title: title, detail: detail, large: large)
        }
        .buttonStyle(BigChoiceButtonStyle(kind: kind))
    }
}

/// After strike three got away from the catcher: was the batter thrown out at first, or safe?
struct DroppedThirdStrikeStep: View {
    let model: PlayEntryModel

    var body: some View {
        VStack(spacing: Spacing.medium) {
            Button { model.perform(.droppedThirdStrikeOut) } label: {
                BigChoiceLabel(title: "Thrown out at first", detail: "Tap the throw next: catcher, then first (K 2-3)", large: true)
            }
            .buttonStyle(BigChoiceButtonStyle(kind: .dark))
            .frame(maxHeight: 170)
            Button { model.perform(.droppedThirdStrikeSafe) } label: {
                BigChoiceLabel(title: "Batter safe at first", detail: "Counts as a strikeout for the pitcher", large: true)
            }
            .buttonStyle(BigChoiceButtonStyle(kind: .blue))
            .frame(maxHeight: 170)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.screenEdge)
        .padding(.top, Spacing.small)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }
}
