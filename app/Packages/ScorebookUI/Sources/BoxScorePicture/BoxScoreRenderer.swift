// Turning the box score picture into an image file, for sending in a text message.
//
// The picture is drawn at three times screen resolution, the same as the sharpest iPhone
// screens, so it stays crisp when someone zooms in on it.

import SwiftUI
import UIKit
import Model
import BoxScoreText

/// Draws box score pictures as images.
@MainActor
public enum BoxScoreRenderer {
    /// Three image pixels for every point on screen.
    public static let scale: CGFloat = 3

    /// The picture as an image, 1,125 pixels wide.
    public static func image(for layout: NewspaperBoxScore) -> UIImage? {
        let picture = BoxScorePicture(layout: layout)
            .environment(\.colorScheme, .light)
        let renderer = ImageRenderer(content: picture)
        renderer.scale = scale
        renderer.isOpaque = true
        // Fixed width, and as tall as the box score needs.
        renderer.proposedSize = ProposedViewSize(width: Newsprint.width, height: nil)
        return renderer.uiImage
    }

    /// The picture as a PNG file's contents, ready to share or save.
    public static func pngData(for layout: NewspaperBoxScore) -> Data? {
        image(for: layout)?.pngData()
    }
}
