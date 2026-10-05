// Handing the box score to the iPhone share sheet: the picture first, the plain text as a
// fallback for anywhere that cannot take a picture.
//
// The share sheet offers whatever the receiving app accepts first: Messages and Photos take
// the picture; an app that only accepts text, such as some notes apps, gets the text.

import SwiftUI
import UniformTypeIdentifiers
import Model
import BoxScoreText

/// One box score, ready to share: the rendered picture and the plain text.
public struct BoxScoreShareItem: Transferable, Sendable {
    /// The picture as a PNG file's contents.
    public let png: Data
    /// The same box score as plain text.
    public let text: String
    /// "Diamond Dogs 5, Mudcats 3", for the share sheet's title.
    public let headline: String

    /// Draws the picture and prints the text for a box score. Missing only if the phone
    /// could not draw the picture.
    @MainActor
    public init?(_ box: BoxScore, timeZone: TimeZone = .current) {
        let layout = BoxScorePrinter.layout(box, timeZone: timeZone)
        guard let png = BoxScoreRenderer.pngData(for: layout) else { return nil }
        self.png = png
        self.text = BoxScorePrinter.text(box, timeZone: timeZone)
        self.headline = layout.headline.replacingOccurrences(of: "\n", with: ", ")
    }

    /// The picture first, then the text: a receiving app takes the first one it accepts.
    public static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { item in item.png }
            .suggestedFileName("Box score.png")
        ProxyRepresentation { (item: BoxScoreShareItem) in item.text }
    }

    /// The picture, for the small preview at the top of the share sheet.
    var previewImage: Image {
        UIImage(data: png).map { Image(uiImage: $0) } ?? Image(systemName: "newspaper")
    }
}

/// A share button for a box score. It draws the picture when it first appears, then opens
/// the share sheet with the picture and the text.
public struct BoxScoreShareLink<Label: View>: View {
    let box: BoxScore
    let timeZone: TimeZone
    let label: Label
    @State private var item: BoxScoreShareItem?

    /// A share button with your own label.
    public init(_ box: BoxScore, timeZone: TimeZone = .current, @ViewBuilder label: () -> Label) {
        self.box = box
        self.timeZone = timeZone
        self.label = label()
    }

    public var body: some View {
        Group {
            if let item {
                ShareLink(item: item, preview: SharePreview(item.headline, image: item.previewImage)) {
                    label
                }
            } else {
                // Shown for the moment it takes to draw the picture.
                ProgressView()
            }
        }
        .task(id: box) {
            item = BoxScoreShareItem(box, timeZone: timeZone)
        }
    }
}

extension BoxScoreShareLink where Label == SwiftUI.Label<Text, Image> {
    /// A share button labeled "Text the box score picture" with the share icon.
    public init(_ box: BoxScore, timeZone: TimeZone = .current) {
        self.init(box, timeZone: timeZone) {
            SwiftUI.Label("Text the box score picture", systemImage: "square.and.arrow.up")
        }
    }
}
