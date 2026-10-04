// Previews of the box score picture, for Xcode's canvas.
//
// The previews draw the sample game's box scores straight from SampleData.

import SwiftUI
import Model
import SampleData
import DesignSystem
import BoxScoreText

/// The sample box scores the previews draw.
enum PreviewBoxScores {
    /// The sample game was played in San Diego.
    static let pacific = TimeZone(identifier: "America/Los_Angeles")!

    /// The finished sample game: Diamond Dogs 5, Mudcats 3, with nine and ten hitters.
    static var finished: BoxScore { SampleGame.boxScore }

    /// The sample game after three innings, still going.
    static var throughThree: BoxScore { SampleGame.boxScoreThroughThree }

    /// The finished game with the Diamond Dogs batting fourteen, one with a very long name.
    static var fourteenHitters: BoxScore {
        var box = finished
        let names = ["Alex Moreno", "Chris Tate", "Jordan Webb", "Pat Quinn", "Riley Shaw", "Casey Ford",
                     "Drew Lang", "Morgan Fisk", "Sky Barros", "Jamie Cole", "Robin Nash",
                     "Christopher Montgomery-Wallace", "Taylor Voss", "Batter 14"]
        // The sample roster’s own ids, so each player is the same person everywhere in the box score.
        let ids: [PlayerID] = ["d1", "d2", "d3", "d4", "d5", "d6", "d7", "d8", "d9", "d10", "d11", "x12", "d12", "x14"]
        box.home.batting = names.enumerated().map { index, name in
            BattingLine(player: ids[index], name: name, batterIndex: index,
                        positions: index < 9 ? [BoxPosition.allCases[index]] : [],
                        stats: BattingCounts(plateAppearances: 2, atBats: 2, runs: index % 2, hits: 1,
                                             runsBattedIn: index % 3 == 0 ? 1 : 0))
        }
        return box
    }
}

/// The picture on the app's own background, scrolling, as a screen would show it.
private struct PreviewPage: View {
    let box: BoxScore

    var body: some View {
        ScrollView {
            BoxScorePicture(box, timeZone: PreviewBoxScores.pacific)
                .shadow(radius: 4)
                .padding(.vertical, Spacing.large)
        }
        .frame(maxWidth: .infinity)
        .background(ScorebookColor.background)
    }
}

#Preview("Finished game, light") {
    PreviewPage(box: PreviewBoxScores.finished)
        .preferredColorScheme(.light)
}

#Preview("Finished game, dark: the picture stays newsprint") {
    PreviewPage(box: PreviewBoxScores.finished)
        .preferredColorScheme(.dark)
}

#Preview("Fourteen hitters") {
    PreviewPage(box: PreviewBoxScores.fourteenHitters)
}

#Preview("Game in progress") {
    PreviewPage(box: PreviewBoxScores.throughThree)
}

#Preview("Largest text size: the picture does not change") {
    PreviewPage(box: PreviewBoxScores.finished)
        .dynamicTypeSize(.accessibility5)
}

#Preview("Share button") {
    VStack(spacing: Spacing.large) {
        BoxScoreShareLink(PreviewBoxScores.finished, timeZone: PreviewBoxScores.pacific)
            .buttonStyle(PlainActionButtonStyle())
        BoxScoreShareLink(PreviewBoxScores.finished, timeZone: PreviewBoxScores.pacific)
            .buttonStyle(PlainActionButtonStyle())
            .preferredColorScheme(.dark)
    }
    .padding()
}

#Preview("Rendered image, as sent") {
    let layout = BoxScorePrinter.layout(PreviewBoxScores.finished, timeZone: PreviewBoxScores.pacific)
    ScrollView {
        if let image = BoxScoreRenderer.image(for: layout) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
            Text("\(Int(image.size.width * image.scale)) × \(Int(image.size.height * image.scale)) pixels")
                .font(ScorebookFont.caption)
        }
    }
}
