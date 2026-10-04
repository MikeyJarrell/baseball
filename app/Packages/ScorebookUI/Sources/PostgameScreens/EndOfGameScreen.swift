// The end-of-game screen, as in the approved mockup: the final score with our logo over our
// team, the winning and losing pitchers and how long the game took, the box score, a big
// button to text the box score picture, and buttons to copy it as text or open the season.
//
// The newspaper picture and its share button come from the BoxScorePicture module, which a
// screen may not import. So the screen has two slots for the wiring job to fill:
//
//     EndOfGameScreen(box: box, ourSide: .home, onRequest: handle) {
//         BoxScorePicture(box)                 // the picture
//     } shareButton: {
//         BoxScoreShareLink(box)               // the share sheet
//     }
//
// Left empty (`EndOfGameScreen(box:ourSide:onRequest:)`), the screen shows the box score as a
// plain table and a share button that hands back `.shareBoxScore`.
//
// The same screen shows any finished game's box score from the games list, with
// `showsDoneButton: false` so the navigation bar keeps its Back button.

import SwiftUI
import Model
import SampleData
import DesignSystem

/// The end of a game: final score, decisions, game length, the box score and sharing.
///
/// - Parameters:
///   - box: The game's box score from the stats engine.
///   - ourSide: Which team is ours, for the logo and our color. Leave it out for neither.
///   - showsDoneButton: True for the screen that appears when a game ends (Done goes home);
///     false when opened from the games list.
///   - onRequest: Called with Done, Copy as text, Season stats, and (from the plain share
///     button) Share.
///   - picture: The box score to show. The wiring job puts the newspaper picture here; it is
///     shrunk to fit the screen's width if it is wider.
///   - shareButton: The big share button. The wiring job puts the share link here.
public struct EndOfGameScreen<Picture: View, ShareButton: View>: View {
    public var box: BoxScore
    public var ourSide: TeamSide?
    public var showsDoneButton: Bool
    public var onRequest: (PostgameRequest) -> Void
    private let picture: Picture
    private let shareButton: ShareButton
    /// True when the picture slot holds a picture handed in, which is set on a gray mat and
    /// shrunk to fit; false for the plain table, which handles its own width.
    private let isHandedInPicture: Bool

    public init(
        box: BoxScore,
        ourSide: TeamSide? = nil,
        showsDoneButton: Bool = true,
        onRequest: @escaping (PostgameRequest) -> Void,
        @ViewBuilder picture: () -> Picture,
        @ViewBuilder shareButton: () -> ShareButton
    ) {
        self.box = box
        self.ourSide = ourSide
        self.showsDoneButton = showsDoneButton
        self.onRequest = onRequest
        self.picture = picture()
        self.shareButton = shareButton()
        self.isHandedInPicture = true
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: Spacing.medium) {
                FinalScoreHeader(box: box, ourSide: ourSide)

                if isHandedInPicture {
                    ShrinkToFitWidth { picture }
                        .padding(10)
                        .background(ScorebookColor.surfaceSecondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else {
                    picture
                }

                VStack(spacing: 10) {
                    shareButton
                    HStack(spacing: 10) {
                        Button { onRequest(.copyBoxScoreText(box.gameID)) } label: {
                            Label("Copy as text", systemImage: "doc.on.doc")
                                .frame(maxWidth: .infinity)
                        }
                        Button { onRequest(.openSeasonStats) } label: {
                            Label("Season stats", systemImage: "chart.bar")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(PlainActionButtonStyle())
                }
                .padding(.top, Spacing.extraSmall)
            }
            .padding(.horizontal, Spacing.screenEdge)
            .padding(.bottom, Spacing.large)
        }
        .background(ScorebookColor.background)
        .navigationTitle(box.isFinal ? "Final" : "Box score")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsDoneButton {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { onRequest(.done) }
                }
            }
        }
    }
}

extension EndOfGameScreen where Picture == BoxScoreTable, ShareButton == PlainShareButton {
    /// The screen before wiring: the box score as a plain table, and a share button that hands
    /// back `.shareBoxScore`.
    public init(box: BoxScore, ourSide: TeamSide? = nil, showsDoneButton: Bool = true,
                onRequest: @escaping (PostgameRequest) -> Void) {
        self.box = box
        self.ourSide = ourSide
        self.showsDoneButton = showsDoneButton
        self.onRequest = onRequest
        self.picture = BoxScoreTable(box: box, ourSide: ourSide)
        self.shareButton = PlainShareButton { onRequest(.shareBoxScore(box.gameID)) }
        self.isHandedInPicture = false
    }
}

/// The big "Text the box score picture" button in our blue, used until the wiring job puts the
/// real share link in its place.
public struct PlainShareButton: View {
    var action: () -> Void

    public init(action: @escaping () -> Void) {
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Label("Text the box score picture", systemImage: "square.and.arrow.up")
        }
        .buttonStyle(TeamButtonStyle(.ours))
    }
}

// MARK: - The final score

/// The top of the screen: visitors' runs, "FINAL", home runs, with our logo over our team;
/// under it the winning and losing pitchers and how long the game took.
struct FinalScoreHeader: View {
    var box: BoxScore
    var ourSide: TeamSide?

    var body: some View {
        VStack(spacing: Spacing.small) {
            HStack(alignment: .bottom, spacing: Spacing.large) {
                teamScore(.away)
                Text(box.isFinal ? "FINAL" : "IN PROGRESS")
                    .font(ScorebookFont.chip)
                    .foregroundStyle(ScorebookColor.textSecondary)
                    .padding(.bottom, Spacing.large)
                teamScore(.home)
            }
            if let line = decisionsLine {
                Text(line)
                    .font(ScorebookFont.body)
                    .foregroundStyle(ScorebookColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.small)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenSummary)
    }

    /// One team: our logo if it is us, the runs in big numbers, the name under them.
    private func teamScore(_ side: TeamSide) -> some View {
        let team = box[side]
        let isOurs = side == ourSide
        return VStack(spacing: 2) {
            if isOurs { TeamLogo(size: 40) }
            Text("\(team.runs)")
                .font(ScorebookFont.scoreboard)
                .foregroundStyle(isOurs ? ScorebookColor.ourTeamText : ScorebookColor.textSecondary)
            Text(team.name)
                .font(ScorebookFont.caption)
                .foregroundStyle(ScorebookColor.textSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(minWidth: 90)
    }

    /// The pitchers the stats engine marked as winning and losing, from both teams.
    private var decisions: (win: String?, loss: String?) {
        let pitchers = box.away.pitching + box.home.pitching
        return (pitchers.first { $0.decision == .win }?.name,
                pitchers.first { $0.decision == .loss }?.name)
    }

    /// "Win: Sky Barros · Loss: Gus Reyes · 3 hr 12 min". Nothing when there is nothing to say.
    private var decisionsLine: String? {
        var parts: [String] = []
        if let win = decisions.win { parts.append("Win: \(win)") }
        if let loss = decisions.loss { parts.append("Loss: \(loss)") }
        if let length = box.gameLength { parts.append(PostgameWording.gameLength(length)) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// "Final. Mudcats 4, Diamond Dogs 7. Winning pitcher Sky Barros. Losing pitcher Gus Reyes.
    /// Game length 3 hours 12 minutes."
    private var spokenSummary: String {
        var words = (box.isFinal ? "Final. " : "In progress. ")
            + "\(box.away.name) \(box.away.runs), \(box.home.name) \(box.home.runs)."
        if let win = decisions.win { words += " Winning pitcher \(win)." }
        if let loss = decisions.loss { words += " Losing pitcher \(loss)." }
        if let length = box.gameLength { words += " Game length \(PostgameWording.gameLengthSpoken(length))." }
        return words
    }
}

// MARK: - Shrinking a picture to fit

/// Shows its content at its natural size, shrunk evenly when it is wider than the space it is
/// given. The newspaper picture is 375 points wide, which is wider than the space beside the
/// screen edges on most iPhones.
struct ShrinkToFitWidth<Content: View>: View {
    @ViewBuilder var content: Content

    /// The content's own size, before any shrinking.
    @State private var naturalSize: CGSize = .zero
    /// The width there is room for.
    @State private var availableWidth: CGFloat = 0

    private var scale: CGFloat {
        guard naturalSize.width > 0, availableWidth > 0 else { return 1 }
        return min(1, availableWidth / naturalSize.width)
    }

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: naturalSize.height * scale)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { availableWidth = $0 }
            .overlay(alignment: .top) {
                content
                    .fixedSize()
                    .onGeometryChange(for: CGSize.self) { $0.size } action: { naturalSize = $0 }
                    .scaleEffect(scale, anchor: .top)
            }
    }
}
