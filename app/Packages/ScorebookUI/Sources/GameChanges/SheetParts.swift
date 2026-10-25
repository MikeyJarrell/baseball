// The building blocks every sheet in this module shares: the frame with its title, Cancel
// button and big button along the bottom; white cards of tappable rows; gray information
// boxes; section labels; chips; and the small segmented choice. They copy the look of the
// approved mockup's sheets (plan/mockups/index.html, `sheetWrap` and the `.opt` rows), using
// only the design system's named colors, type and spacing.

import SwiftUI
import Model
import DesignSystem

// MARK: - The sheet frame

/// True for a sheet that was pushed from a menu inside another sheet, which already has a
/// navigation stack: the sheet then uses that stack's back button instead of starting its own.
private struct InsideChangesStackKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var insideChangesStack: Bool {
        get { self[InsideChangesStackKey.self] }
        set { self[InsideChangesStackKey.self] = newValue }
    }
}

/// The frame around every sheet: a centered title with a smaller line under it, a Cancel
/// button at the top left (or "Later", or none), the scrolling body, and an optional big
/// button area pinned to the bottom edge.
struct SheetFrame<Content: View, Footer: View>: View {
    var title: String
    var subtitle: String?
    /// The words on the top-left button: "Cancel", "Later". Missing means no button, for a
    /// question that must be answered.
    var cancelTitle: String? = "Cancel"
    var onCancel: () -> Void = {}
    @ViewBuilder var content: Content
    @ViewBuilder var footer: Footer

    @Environment(\.insideChangesStack) private var pushedFromMenu

    var body: some View {
        if pushedFromMenu {
            page(isFirstPage: false)
        } else {
            NavigationStack {
                page(isFirstPage: true)
            }
            .environment(\.insideChangesStack, true)
        }
    }

    /// The page itself. The first page of a sheet gets the Cancel button; a page pushed from
    /// a menu gets the usual back arrow instead.
    private func page(isFirstPage: Bool) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(.horizontal, Spacing.large)
            .padding(.top, Spacing.small)
            .padding(.bottom, Spacing.large)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(ScorebookColor.background)
        .foregroundStyle(ScorebookColor.textPrimary)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if Footer.self != EmptyView.self {
                VStack(spacing: Spacing.small) {
                    footer
                }
                .padding(.horizontal, Spacing.large)
                .padding(.top, Spacing.medium)
                .padding(.bottom, Spacing.small)
                .background(ScorebookColor.background)
                .overlay(alignment: .top) {
                    Rectangle().fill(ScorebookColor.divider).frame(height: 1)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text(title)
                        .font(ScorebookFont.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    if let subtitle {
                        Text(subtitle)
                            .font(ScorebookFont.caption)
                            .foregroundStyle(ScorebookColor.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
            }
            if isFirstPage, let cancelTitle {
                ToolbarItem(placement: .topBarLeading) {
                    Button(cancelTitle, action: onCancel)
                }
            }
        }
        .toolbarBackground(ScorebookColor.background, for: .navigationBar)
    }
}

extension SheetFrame where Footer == EmptyView {
    /// A sheet with no big button along the bottom.
    init(title: String, subtitle: String? = nil, cancelTitle: String? = "Cancel",
         onCancel: @escaping () -> Void = {}, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.cancelTitle = cancelTitle
        self.onCancel = onCancel
        self.content = content()
        self.footer = EmptyView()
    }
}

// MARK: - Cards and rows

/// A white card holding rows, with rounded corners, like the mockup's `.card`.
struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(ScorebookColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.cornerRadius + 2, style: .continuous))
    }
}

/// A thin line between two rows in a card.
struct RowDivider: View {
    var body: some View {
        Rectangle()
            .fill(ScorebookColor.divider)
            .frame(height: 1)
            .padding(.leading, Spacing.large)
    }
}

/// What sits at the right-hand end of a row.
enum RowEnd {
    /// A round mark, filled and ticked when chosen.
    case radio(Bool)
    /// An arrow: the row opens something.
    case chevron
    /// A close mark: the row closes what it opened.
    case close
    /// A swap mark: the row lets the scorer swap in another player.
    case swap
    /// Nothing.
    case none
}

/// One tappable row: something on the left (a number badge, an icon), a title, a smaller
/// line under it, and a mark on the right. At least 58 points tall, like the mockup's `.opt`.
struct OptionRow<Leading: View>: View {
    var title: String
    var detail: String?
    var end: RowEnd = .none
    /// Shades the row, for a fielding change the scorer has made but not saved.
    var isChanged: Bool = false
    var action: () -> Void
    @ViewBuilder var leading: Leading

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.medium) {
                leading
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(ScorebookFont.headline)
                        .foregroundStyle(ScorebookColor.textPrimary)
                    if let detail {
                        Text(detail)
                            .font(ScorebookFont.caption)
                            .foregroundStyle(ScorebookColor.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
                endMark
            }
            .padding(.horizontal, Spacing.large - 2)
            .padding(.vertical, Spacing.small)
            .frame(minHeight: 58)
            .background(isChanged ? ScorebookColor.warning.opacity(0.18) : ScorebookColor.surface)
            .contentShape(Rectangle())
        }
        .buttonStyle(RowPressStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var isSelected: Bool {
        if case .radio(true) = end { return true }
        return false
    }

    @ViewBuilder private var endMark: some View {
        switch end {
        case .radio(let on): RadioMark(isOn: on)
        case .chevron: Image(systemName: "chevron.right").foregroundStyle(ScorebookColor.textSecondary)
        case .close: Image(systemName: "xmark").foregroundStyle(ScorebookColor.textSecondary)
        case .swap: Image(systemName: "arrow.left.arrow.right").foregroundStyle(ScorebookColor.textSecondary)
        case .none: EmptyView()
        }
    }
}

extension OptionRow where Leading == EmptyView {
    /// A row with nothing on the left.
    init(title: String, detail: String? = nil, end: RowEnd = .none, isChanged: Bool = false, action: @escaping () -> Void) {
        self.init(title: title, detail: detail, end: end, isChanged: isChanged, action: action) { EmptyView() }
    }
}

/// Dims a row slightly while a finger is on it.
struct RowPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.6 : 1)
    }
}

/// The round mark on a choice row: an empty ring, or filled blue with a tick when chosen.
struct RadioMark: View {
    var isOn: Bool

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(isOn ? ScorebookColor.highlight : ScorebookColor.divider, lineWidth: 2)
                .background(Circle().fill(isOn ? ScorebookColor.highlight : Color.clear))
            if isOn {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 24, height: 24)
        .accessibilityHidden(true)
    }
}

/// A gray rounded square with an icon in it, on the left of a menu row.
struct IconBadge: View {
    var systemName: String
    var tint: Color = ScorebookColor.textPrimary

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 40, height: 40)
            .background(ScorebookColor.surfaceSecondary, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// A fielding position's short name at the left of a row: "SS".
struct PositionCircle: View {
    var position: Position

    var body: some View {
        Text(position.abbreviation.uppercased())
            .font(.system(size: 15, weight: .heavy))
            .foregroundStyle(ScorebookColor.textSecondary)
            .frame(width: 36, alignment: .leading)
            .accessibilityHidden(true)
    }
}

/// A row choosing one player: their number badge, name, a line about them, and a round mark.
struct PlayerChoiceRow: View {
    var context: GameChangeContext
    var player: PlayerID
    var detail: String?
    var look: TeamLook
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        OptionRow(title: context.name(player), detail: detail, end: .radio(isSelected), action: action) {
            PlayerNumberBadge(context.number(player), look: look, size: 36)
        }
    }
}

// MARK: - Text pieces

/// A gray box of explanation, like the mockup's `.info`.
struct InfoBox: View {
    var text: Text

    init(_ text: Text) {
        self.text = text
    }

    var body: some View {
        text
            .font(ScorebookFont.body)
            .foregroundStyle(ScorebookColor.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.large - 2)
            .padding(.vertical, Spacing.medium)
            .background(ScorebookColor.surfaceSecondary, in: RoundedRectangle(cornerRadius: Spacing.cornerRadius, style: .continuous))
            .padding(.vertical, Spacing.small + 2)
    }
}

/// A warning box in amber, for the manual adjustment and anything that overrides the book.
struct WarningBox: View {
    var text: Text

    init(_ text: Text) {
        self.text = text
    }

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.small) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(ScorebookColor.warning)
                .accessibilityHidden(true)
            text
                .font(ScorebookFont.body)
                .foregroundStyle(ScorebookColor.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, Spacing.large - 2)
        .padding(.vertical, Spacing.medium)
        .background(ScorebookColor.warning.opacity(0.18), in: RoundedRectangle(cornerRadius: Spacing.cornerRadius, style: .continuous))
        .padding(.vertical, Spacing.small + 2)
    }
}

/// A small capitalized label above a card: "CAN RE-ENTER", "BENCH".
struct SectionLabel: View {
    var text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text.uppercased())
            .font(ScorebookFont.sectionLabel)
            .tracking(0.6)
            .foregroundStyle(ScorebookColor.textSecondary)
            .padding(.horizontal, Spacing.extraSmall)
            .padding(.top, Spacing.extraLarge - 2)
            .padding(.bottom, Spacing.small)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Small gray words under a card, such as how the league's rule works.
struct FootNote: View {
    var text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(ScorebookFont.caption)
            .foregroundStyle(ScorebookColor.textSecondary)
            .padding(.horizontal, Spacing.extraSmall)
            .padding(.top, Spacing.medium)
    }
}

/// "Nobody on the bench." inside an empty card.
struct EmptyNote: View {
    var text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(ScorebookFont.body)
            .foregroundStyle(ScorebookColor.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.large - 2)
    }
}

// MARK: - Buttons

/// A rounded chip that can be on or off, like the mockup's `.chipbtn`: "Webb on 2nd".
struct ChipStyle: ButtonStyle {
    var isOn: Bool
    /// The chip's color when off: gray, or white on a gray background.
    var fill: Color = ScorebookColor.surfaceSecondary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ScorebookFont.chip)
            .lineLimit(1)
            .foregroundStyle(isOn ? ScorebookColor.background : ScorebookColor.textPrimary)
            .padding(.horizontal, Spacing.large - 2)
            .frame(minHeight: Spacing.minimumTapSize)
            .background(isOn ? ScorebookColor.textPrimary : fill, in: Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(Capsule())
    }
}

/// The outlined "Someone else" button that opens the full list.
struct SomeoneElseButton: View {
    var title: String = "Someone else"
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(ScorebookFont.headline)
                .foregroundStyle(ScorebookColor.highlight)
                .frame(maxWidth: .infinity, minHeight: Spacing.minimumTapSize + 4)
                .background(ScorebookColor.surface, in: RoundedRectangle(cornerRadius: Spacing.cornerRadius + 2, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Spacing.cornerRadius + 2, style: .continuous)
                    .strokeBorder(ScorebookColor.divider, lineWidth: 1.5))
        }
        .buttonStyle(RowPressStyle())
        .padding(.top, Spacing.small + 2)
    }
}

/// A big gray button, for the second choice under a primary one ("Keep playing").
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ScorebookFont.headline)
            .foregroundStyle(ScorebookColor.textPrimary)
            .frame(maxWidth: .infinity, minHeight: Spacing.primaryButtonHeight)
            .background(ScorebookColor.surfaceSecondary.opacity(configuration.isPressed ? 0.6 : 1),
                        in: RoundedRectangle(cornerRadius: Spacing.cornerRadius + 2, style: .continuous))
    }
}

/// A row of equal buttons where one is chosen, like the mockup's `.seg`: Left | Right | Switch.
struct SegmentedChoice<Value: Hashable>: View {
    var options: [(value: Value, label: String)]
    @Binding var selection: Value?

    var body: some View {
        HStack(spacing: 3) {
            ForEach(options, id: \.value) { option in
                let isOn = selection == option.value
                Button {
                    selection = option.value
                } label: {
                    Text(option.label)
                        .font(ScorebookFont.chip)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .foregroundStyle(isOn ? ScorebookColor.textPrimary : ScorebookColor.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: Spacing.minimumTapSize)
                        .background(isOn ? ScorebookColor.surface : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .shadow(color: isOn ? .black.opacity(0.15) : .clear, radius: 1.5, y: 1)
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

/// A labeled text box, like the mockup's `.field-in`: "NUMBER" over a box.
struct LabeledField: View {
    var label: String
    var placeholder: String = ""
    @Binding var text: String
    var keyboard: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.extraSmall) {
            Text(label.uppercased())
                .font(ScorebookFont.sectionLabel)
                .tracking(0.6)
                .foregroundStyle(ScorebookColor.textSecondary)
            TextField(placeholder, text: $text)
                .font(ScorebookFont.headline)
                .keyboardType(keyboard)
                .textInputAutocapitalization(keyboard == .numberPad ? .never : .words)
                .autocorrectionDisabled()
                .padding(.horizontal, Spacing.large - 2)
                .frame(minHeight: 50)
                .background(ScorebookColor.surface, in: RoundedRectangle(cornerRadius: Spacing.cornerRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Spacing.cornerRadius, style: .continuous)
                    .strokeBorder(ScorebookColor.divider, lineWidth: 1.5))
                .accessibilityLabel(label)
        }
        .padding(.bottom, Spacing.medium)
    }
}

/// The fields for a player created on the spot: number, name and one handedness choice.
/// Used for a new pitcher (throwing hand), a new hitter or a new pinch hitter (batting side).
struct NewPlayerFields: View {
    @Binding var number: String
    @Binding var name: String

    var body: some View {
        LabeledField(label: "Number", placeholder: "#", text: $number, keyboard: .numberPad)
        LabeledField(label: "Name (optional)", placeholder: "Unknown", text: $name)
    }

    /// The new player, from what was typed. Blank boxes stay unknown.
    static func makePlayer(number: String, name: String, bats: BattingSide? = nil, throwsWith: Hand? = nil) -> Player {
        let number = number.trimmingCharacters(in: .whitespaces)
        let name = name.trimmingCharacters(in: .whitespaces)
        return Player(id: .make(), name: name.isEmpty ? nil : name, number: number.isEmpty ? nil : number,
                      bats: bats, throwsWith: throwsWith)
    }
}

/// The two-way layout for a row of chips: they wrap onto more lines when they do not fit.
struct WrappingChips: Layout {
    var spacing: CGFloat = Spacing.small

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, widest: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(ProposedViewSize(width: width, height: nil))
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: proposal.width ?? widest, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: min(size.width, bounds.width), height: size.height))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
