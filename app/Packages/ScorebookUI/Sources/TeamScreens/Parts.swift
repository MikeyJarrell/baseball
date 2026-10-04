// The pieces the teams and songs pages share, copying the approved mockup's look
// (plan/mockups/index.html: `.card`, `.sec`, `.btn`, `.songline`, `.seg`, `.info`): white
// cards on the gray page, small capital section labels, wide buttons, the song artwork tile,
// a segmented choice that can be left empty, and the box that shows audio problems. Only the
// design system's named colors, type and spacing are used.

import SwiftUI
import Model
import DesignSystem

// MARK: - Cards and labels

/// A white rounded card holding rows or buttons, like the mockup's `.card`.
struct Card<Content: View>: View {
    /// Padding inside the card; zero for a card of full-width rows.
    var padding: CGFloat = Spacing.large - 2
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ScorebookColor.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
    }
}

/// A small capital label above a card: "WALK-UP SONG". An optional second label sits at the right.
struct SectionLabel: View {
    var title: String
    var trailing: String?

    init(_ title: String, trailing: String? = nil) {
        self.title = title
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title.uppercased())
                .font(ScorebookFont.sectionLabel)
                .tracking(0.6)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: Spacing.small)
            if let trailing {
                Text(trailing).font(ScorebookFont.caption.weight(.semibold))
            }
        }
        .foregroundStyle(ScorebookColor.textSecondary)
        .padding(.horizontal, Spacing.extraSmall)
        .padding(.top, 22)
        .padding(.bottom, Spacing.small)
    }
}

/// A list section's header in small capitals, like the mockup's `.sec`: "OUR TEAM".
struct ListHeader: View {
    var title: String

    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title.uppercased())
            .font(ScorebookFont.sectionLabel)
            .tracking(0.6)
            .foregroundStyle(ScorebookColor.textSecondary)
            .lineLimit(1)
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}

/// A gray box of plain information, like the mockup's `.info`.
struct InfoBox: View {
    var text: String

    var body: some View {
        Text(text)
            .font(ScorebookFont.body)
            .foregroundStyle(ScorebookColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Spacing.large - 2)
            .padding(.vertical, Spacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ScorebookColor.surfaceSecondary, in: RoundedRectangle(cornerRadius: Spacing.cornerRadius, style: .continuous))
    }
}

/// Messages from the audio player (a file that would not copy in, a speaker that disconnected),
/// in an amber box with an OK button that clears them.
struct ProblemsBox: View {
    var problems: [String]
    var onDismiss: () -> Void

    var body: some View {
        if !problems.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.small) {
                ForEach(Array(problems.enumerated()), id: \.offset) { _, message in
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(ScorebookFont.body)
                        .foregroundStyle(ScorebookColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button("OK", action: onDismiss)
                    .buttonStyle(PlainActionButtonStyle())
            }
            .padding(Spacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ScorebookColor.warning.opacity(0.22), in: RoundedRectangle(cornerRadius: Spacing.cornerRadius, style: .continuous))
        }
    }
}

// MARK: - Buttons

/// A full-width button in one of the mockup's fills: our blue, the record red, or quiet gray.
struct WideButtonStyle: ButtonStyle {
    enum Kind {
        /// Our team's powder blue with near-black words: "Test: introduction, then song".
        case ours
        /// Red with white words: "Record introduction".
        case record
        /// Gray with ordinary words: "Preview", "Change song".
        case quiet
        /// White with a thin border and blue words: "Add a team".
        case outlined
    }

    var kind: Kind
    /// Shorter, for two buttons side by side.
    var compact = false

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return configuration.label
            .font(compact ? ScorebookFont.chip : ScorebookFont.headline)
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.7)
            .foregroundStyle(foreground)
            .padding(.horizontal, Spacing.large)
            .padding(.vertical, Spacing.small)
            .frame(maxWidth: .infinity, minHeight: compact ? 46 : 52)
            .background(background, in: shape)
            .overlay { if kind == .outlined { shape.strokeBorder(ScorebookColor.divider, lineWidth: 1.5) } }
            .contentShape(shape)
            .opacity(isEnabled ? (configuration.isPressed ? 0.75 : 1) : 0.4)
    }

    private var foreground: Color {
        switch kind {
        case .ours: ScorebookColor.onOurTeam
        case .record: .white
        case .quiet: ScorebookColor.textPrimary
        case .outlined: ScorebookColor.inPlay
        }
    }

    private var background: Color {
        switch kind {
        case .ours: ScorebookColor.ourTeam
        case .record: ScorebookColor.out
        case .quiet: ScorebookColor.surfaceSecondary
        case .outlined: ScorebookColor.surface
        }
    }
}

/// A round chip with an icon and words: "Quick entry", "Songs".
struct ChipLabel: View {
    var title: String
    var systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(ScorebookFont.chip)
            .foregroundStyle(ScorebookColor.textPrimary)
            .padding(.horizontal, Spacing.large - 2)
            .frame(minHeight: Spacing.minimumTapSize)
            .background(ScorebookColor.surfaceSecondary, in: Capsule())
            .lineLimit(1)
            // Chips sit side by side, so their words stop growing at the largest ordinary size.
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}

/// A play button for a song in a list: a play triangle, or a stop square while it plays.
struct SongPlayButton: View {
    var isPlaying: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(isPlaying ? ScorebookColor.onOurTeam : ScorebookColor.ourTeamText)
                .frame(width: 40, height: 40)
                .background(isPlaying ? ScorebookColor.ourTeam : ScorebookColor.surfaceSecondary,
                            in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                .frame(width: Spacing.minimumTapSize, height: Spacing.minimumTapSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(isPlaying ? "Stop" : "Play")
    }
}

// MARK: - Largest text sizes

/// A row that turns into a column at the accessibility text sizes, so two buttons or a picture
/// and its words never squeeze each other into one letter per line.
struct AdaptiveStack<Content: View>: View {
    var spacing: CGFloat = Spacing.small
    @ViewBuilder var content: Content

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: spacing) { content }
        } else {
            HStack(spacing: spacing) { content }
        }
    }
}

// MARK: - Songs and players

/// The square song artwork from the mockup: a music note on a blue-to-black tile.
struct SongArt: View {
    var size: CGFloat = 52

    var body: some View {
        Image(systemName: "music.note")
            .font(.system(size: size * 0.46, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                LinearGradient(colors: [ScorebookColor.ourTeam, ScorebookColor.ourTeamBadge],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: size * 0.23, style: .continuous)
            )
            .accessibilityHidden(true)
    }
}

/// The song artwork with a title in large type and a line of details under it.
struct SongLine: View {
    var title: String
    var details: String

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        HStack(spacing: Spacing.medium) {
            // At the accessibility text sizes the words need the whole width.
            if !typeSize.isAccessibilitySize { SongArt() }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(ScorebookFont.headline).foregroundStyle(ScorebookColor.textPrimary)
                Text(details).font(ScorebookFont.caption).foregroundStyle(ScorebookColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}

/// A team's badge for lists: our logo, or the first letter of their name on slate.
struct TeamBadge: View {
    var team: Team
    var size: CGFloat = 44

    var body: some View {
        if team.isOurs {
            TeamLogo(size: size)
        } else {
            PlayerNumberBadge(String(team.name.prefix(1)).uppercased(), look: .theirs, size: size * 0.9)
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        }
    }
}

/// A player's number badge, with "?" when the number is unknown.
struct NumberBadge: View {
    var player: Player
    var look: TeamLook
    var size: CGFloat = 40

    var body: some View {
        PlayerNumberBadge(player.number?.nilIfEmpty ?? "?", look: look, size: size)
    }
}

// MARK: - Choices

/// A row of choices like the mockup's `.seg`, where tapping the chosen one again clears it,
/// for details that may be unknown (an opponent's batting side).
struct ClearableSegments<Value: Hashable>: View {
    var options: [(value: Value, label: String)]
    @Binding var selection: Value?
    /// Whether tapping the chosen option again leaves nothing chosen.
    var allowsNone = true

    var body: some View {
        HStack(spacing: 3) {
            ForEach(options, id: \.value) { option in
                let isOn = selection == option.value
                Button {
                    selection = (isOn && allowsNone) ? nil : option.value
                } label: {
                    Text(option.label)
                        .font(ScorebookFont.chip)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(isOn ? ScorebookColor.textPrimary : ScorebookColor.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background {
                            if isOn {
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(ScorebookColor.surface)
                                    .shadow(color: .black.opacity(0.18), radius: 1.5, y: 1)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .padding(3)
        .background(ScorebookColor.surfaceSecondary, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}

/// The choices for batting side and throwing hand, shared by quick entry and the edit sheet.
enum HandChoices {
    static let bats: [(value: BattingSide, label: String)] = [(.right, "Right"), (.left, "Left"), (.switchHitter, "Switch")]
    static let throwsWith: [(value: Hand, label: String)] = [(.right, "Right"), (.left, "Left")]
}

// MARK: - Page background

extension View {
    /// The gray page background every teams and songs page uses, behind the white cards.
    func teamPageBackground() -> some View {
        background(ScorebookColor.background.ignoresSafeArea())
    }

    /// Keeps a page's cards at a comfortable width on an iPad, centered, instead of stretching
    /// across a wide screen. On an iPhone it changes nothing.
    func readableWidth() -> some View {
        frame(maxWidth: 640).frame(maxWidth: .infinity)
    }

    /// The look of a list on these pages: grouped white cards on the gray page.
    func teamListStyle() -> some View {
        listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(ScorebookColor.background.ignoresSafeArea())
    }
}
