# Box score printer

**Role:** box score printer.

**Waits on:** foundation for the text. The picture also waits on the designer’s newspaper look.

**Owns:** `ScorebookCore/Sources/BoxScoreText/`, `ScorebookCore/Tests/BoxScoreTextTests/` and `ScorebookUI/Sources/BoxScorePicture/`.

**Reads:** `Model/` (the box score type), `SampleData/` (the finished game’s box score), `DesignSystem/`.

## Deliver

1. **Text.** Given a box score, lay it out the way a newspaper sports page did: headline with the final score, each team’s batting lines in columns (ab r h bi), totals, the line score by inning, the notes paragraph (“E—Ruiz 2. DP—Mudcats 1. LOB—Mudcats 6, Cardinals 4. 2B—Ortiz, Hale. HR—Diaz. SB—Kim.”), then the pitching lines (ip h r bb so). Names shortened to last names, with a first initial only when two players share one.
2. **Picture.** The same layout drawn as an image in the newspaper look, sized for a phone screen, for texting to the group, rendered at three times screen resolution so it stays sharp when zoomed. Use fonts that come with iOS. A text message shows plain text in a font where letters have different widths, so the columns only line up in the picture.
3. **Share.** Hand both to the iPhone share sheet: the picture as the main item, the text as a fallback.

## Finish line

The text for the `SampleData` game matches a hand-checked expected output, character for character, in a test. Lineups of nine and of fourteen both fit. The picture has previews in light and dark mode; the picture itself always uses the newsprint colors regardless of mode.
