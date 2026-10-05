// The bottom half of the batting screen, where the thumb lives: the batter with the big Subs
// button beside them, the row of small buttons led by Undo, the 2×2 block of count buttons,
// and the song button across the bottom edge.

import SwiftUI
import Model
import DesignSystem

/// Everything below the field.
struct AtBatControls: View {
    var info: AtBatInfo
    var onAction: (AtBatAction) -> Void

    var body: some View {
        VStack(spacing: Spacing.small) {
            if let redo = info.redoLabel { RedoBar(redoLabel: redo, onAction: onAction) }
            BatterRow(info: info, onAction: onAction)
            ChipRow(info: info, onAction: onAction)
            CountButtons(count: info.situation.count, countAfter: info.countAfter, onAction: onAction)
            SongButton(info: info, onAction: onAction)
        }
    }
}

// MARK: - Redo

/// Shown only right after an undo, when the app hands the screen a redo label: "Undone: 6-3"
/// and a Redo button, so a stray tap on Undo never loses a play for good.
struct RedoBar: View {
    var redoLabel: String
    var onAction: (AtBatAction) -> Void

    var body: some View {
        HStack(spacing: Spacing.small) {
            Text("Undone: \(redoLabel)")
                .font(ScorebookFont.chip)
                .foregroundStyle(ScorebookColor.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button { onAction(.redo) } label: {
                Label("Redo", systemImage: "arrow.uturn.forward")
            }
            .buttonStyle(PlainActionButtonStyle())
            .accessibilityLabel(Text("Redo \(redoLabel)"))
        }
        .padding(.leading, Spacing.medium)
        .padding(.trailing, Spacing.extraSmall)
        .padding(.vertical, Spacing.extraSmall)
        .background(ScorebookColor.surface, in: RoundedRectangle(cornerRadius: Spacing.cornerRadius, style: .continuous))
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}

// MARK: - The batter

/// The batter's number, name and what they have done today, and the Subs button.
/// Tapping the batter opens pinch-hit and batting-side options.
struct BatterRow: View {
    var info: AtBatInfo
    var onAction: (AtBatAction) -> Void

    var body: some View {
        let batter = info.batter
        let ours = info.weAreBatting
        HStack(spacing: Spacing.small) {
            Button { onAction(.openBatterOptions) } label: {
                HStack(spacing: Spacing.small) {
                    PlayerNumberBadge(AtBatWording.badgeNumber(batter), look: info.look, size: 44)
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: Spacing.extraSmall + 2) {
                            Text(AtBatWording.batterName(batter, ours: ours))
                                .font(ScorebookFont.batterName)
                            if AtBatWording.needsName(batter, ours: ours) {
                                Text("Add name")
                                    .font(ScorebookFont.headline)
                                    .foregroundStyle(ScorebookColor.inPlay)
                            }
                            if info.batterIsNonRunner {
                                Text("Non-runner")
                                    .font(ScorebookFont.caption.weight(.bold))
                                    .foregroundStyle(ScorebookColor.onOurTeam)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(ScorebookColor.ourTeamAccent, in: Capsule())
                            }
                        }
                        // The whole day if it fits; on a long day, the latest plate appearances
                        // with "…" in front, so the newest never get cut off.
                        ViewThatFits(in: .horizontal) {
                            todayLine(AtBatWording.today(info.batterHistory))
                            todayLine(AtBatWording.today(info.batterHistory, latest: 4))
                            todayLine(AtBatWording.today(info.batterHistory, latest: 2))
                        }
                    }
                    .font(ScorebookFont.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    Spacer(minLength: 0)
                }
                .foregroundStyle(ScorebookColor.textPrimary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(spokenBatter))
            .accessibilityHint(Text("Pinch hitter and batting side"))
            .accessibilityAddTraits(.isButton)

            // The big Subs button: every kind of change.
            Button { onAction(.openSubstitutions) } label: {
                VStack(spacing: 0) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.title3.weight(.bold))
                    Text("Subs")
                }
                .frame(minWidth: 68, minHeight: 54)
            }
            .buttonStyle(PlainActionButtonStyle())
            .accessibilityLabel(Text("Substitutions"))
            .accessibilityHint(Text("Pitcher, fielders, pinch hitter, pinch runner, add a hitter"))
        }
        .padding(.horizontal, Spacing.small)
        .padding(.vertical, Spacing.extraSmall + 2)
        .background(info.look.soft, in: RoundedRectangle(cornerRadius: Spacing.cornerRadius, style: .continuous))
        // The batter keeps one line at the largest text sizes, so the buttons below stay on screen.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    /// "Bats L · Today: 4-3, 1B 7", with the plate appearances in bold.
    private func todayLine(_ today: String) -> some View {
        Text("\(AtBatWording.bats(info.batter.bats)) · Today: \(Text(today).font(ScorebookFont.caption.weight(.bold)).foregroundStyle(ScorebookColor.textPrimary))")
            .foregroundStyle(ScorebookColor.textSecondary)
            .fixedSize(horizontal: true, vertical: false)
    }

    /// "Batter: number 33, Pat Quinn, bats left, designated non-runner. Today: 4-3, 1B 7."
    private var spokenBatter: String {
        let b = info.batter
        var words = "Batter: "
        if let number = b.number, !number.isEmpty { words += "number \(number), " }
        words += b.name.flatMap { $0.isEmpty ? nil : $0 } ?? "no name yet"
        words += ", \(AtBatWording.batsSpoken(b.bats))"
        if info.batterIsNonRunner { words += ", designated non-runner" }
        words += ". Today: \(AtBatWording.today(info.batterHistory))."
        return words
    }
}

// MARK: - Undo and the small buttons

/// Undo, then HBP, IBB and Foul tip. Right after strike three, the dropped-third-strike chip takes Foul
/// tip's place until the next event (as "Dropped K"); HBP and IBB stay, since the next batter is already up.
struct ChipRow: View {
    var info: AtBatInfo
    var onAction: (AtBatAction) -> Void

    /// The phone's text size: at the large sizes Undo drops its arrow to leave room for words.
    @Environment(\.dynamicTypeSize) private var textSize

    var body: some View {
        // The first layout that fits: one row with Undo on one line; one row with Undo's words
        // on two lines; at large text sizes, Undo on a row of its own above the others, so its
        // words are never squeezed.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Spacing.small) {
                undoButton
                otherChips
            }
            HStack(spacing: Spacing.small) {
                undoButton.frame(idealWidth: 104)
                otherChips
            }
            VStack(spacing: Spacing.small) {
                undoButton
                HStack(spacing: Spacing.small) { otherChips }
            }
        }
        .buttonStyle(PlainActionButtonStyle())
    }

    /// Undo, saying what it will take back.
    private var undoButton: some View {
        Button { onAction(.undo) } label: {
            Label(info.undoLabel.map { "Undo: \($0)" } ?? "Undo", systemImage: "arrow.uturn.backward")
                .labelStyle(UndoLabelStyle(showsIcon: textSize < .xxLarge))
                // The words wrap onto a second line rather than shrink below the other chips.
                .lineLimit(2)
                .minimumScaleFactor(0.95)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(PlainActionButtonStyle())
        .disabled(info.undoLabel == nil)
        .opacity(info.undoLabel == nil ? 0.5 : 1)
        .accessibilityLabel(Text(info.undoLabel.map { "Undo \($0)" } ?? "Nothing to undo"))
    }

    /// HBP, IBB, and Foul tip or, right after strike three, the dropped-third-strike chip.
    @ViewBuilder private var otherChips: some View {
        Button("HBP") { pitch(.hitByPitch) }
            .accessibilityLabel(Text("Hit by pitch"))
        Button("IBB") { onAction(.record(GameEvent(kind: .intentionalWalk(IntentionalWalk())))) }
            .accessibilityLabel(Text("Intentional walk"))
        if info.situation.droppedThirdStrikePossible {
            Button { onAction(.openInPlay(.droppedThirdStrike)) } label: {
                // "Dropped K" (K is the scorebook strikeout) keeps the chip short, so HBP and
                // IBB fit beside it; it is never cut off.
                HStack(spacing: Spacing.extraSmall) {
                    Text("Dropped K")
                    Image(systemName: "chevron.right").font(.caption.weight(.bold))
                }
                .fixedSize()
            }
            .buttonStyle(WarningChipStyle())
            .accessibilityLabel(Text("Dropped third strike"))
            .accessibilityHint(Text("The catcher did not hold strike three"))
        } else {
            Button("Foul tip") { pitch(.foulTip) }
        }
    }

    /// Hands back one pitch to record.
    private func pitch(_ result: PitchResult) {
        onAction(.record(GameEvent(kind: .pitch(Pitch(result)))))
    }
}

/// Undo's words with or without the curved arrow in front.
struct UndoLabelStyle: LabelStyle {
    var showsIcon: Bool

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Spacing.extraSmall + 2) {
            if showsIcon { configuration.icon }
            configuration.title
        }
    }
}

/// The amber "Dropped K" chip: the gray chip's shape in the warning color.
struct WarningChipStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ScorebookFont.chip)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .foregroundStyle(ScorebookColor.onStrike)
            .padding(.horizontal, Spacing.medium)
            .frame(minHeight: Spacing.minimumTapSize)
            .background(ScorebookColor.warning.opacity(configuration.isPressed ? 0.7 : 1),
                        in: RoundedRectangle(cornerRadius: Spacing.cornerRadius, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: Spacing.cornerRadius, style: .continuous))
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}

// MARK: - The count buttons

/// Ball, Strike, Foul and In play in a 2×2 block, each saying what it will do. Strike records a
/// swinging strike; the small Called button on it records a called strike in one tap.
struct CountButtons: View {
    var count: Count
    /// What each pitch would do to the count, from the rules engine.
    var countAfter: (PitchResult) -> CountChange
    var onAction: (AtBatAction) -> Void

    /// True between a long press on Foul (a foul bunt) and the finger lifting, so the lift does
    /// not record a foul as well. Only what the finger is doing; no game state.
    @State private var heldForBunt = false
    /// Counts foul bunts, so the phone buzzes once for each.
    @State private var buntCount = 0

    /// How wide the Called button is, and how much room the Strike words leave for it.
    private let calledWidth: CGFloat = 66

    var body: some View {
        Grid(horizontalSpacing: Spacing.screenEdge, verticalSpacing: Spacing.screenEdge) {
            GridRow {
                Button { pitch(.ball) } label: {
                    CountButtonLabel("Ball", hint: AtBatWording.hint(countAfter(.ball)))
                }
                .buttonStyle(CountButtonStyle.ball)
                .accessibilityLabel(Text("Ball"))
                .accessibilityHint(Text(AtBatWording.hint(countAfter(.ball))))

                Button { pitch(.swingingStrike) } label: {
                    // The words keep clear of the Called button: an empty space its width sits
                    // beside them, so they shrink to fit the rest at large text sizes.
                    HStack(spacing: 0) {
                        CountButtonLabel("Strike", hint: AtBatWording.hint(countAfter(.swingingStrike)))
                            .frame(maxWidth: .infinity)
                        Color.clear.frame(width: calledWidth + Spacing.small)
                    }
                }
                .buttonStyle(CountButtonStyle.strike)
                .accessibilityLabel(Text("Strike, swinging"))
                .accessibilityHint(Text(AtBatWording.hint(countAfter(.swingingStrike))))
                .overlay(alignment: .trailing) { calledButton }
            }
            GridRow {
                // A tap is a foul; holding it down is a foul bunt, which is strike three with
                // two strikes. The long press marks itself, so lifting the finger afterward does
                // not also record a foul.
                Button {
                    if heldForBunt { heldForBunt = false } else { pitch(.foul) }
                } label: {
                    CountButtonLabel("Foul", hint: AtBatWording.hint(countAfter(.foul), isFoul: true))
                }
                .buttonStyle(CountButtonStyle.foul)
                .simultaneousGesture(LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                    heldForBunt = true
                    buntCount += 1
                    pitch(.foulBunt)
                })
                .sensoryFeedback(.impact, trigger: buntCount)
                .accessibilityLabel(Text("Foul"))
                .accessibilityHint(Text(AtBatWording.hint(countAfter(.foul), isFoul: true)))
                .accessibilityAction(named: Text("Foul bunt")) { pitch(.foulBunt) }

                Button { onAction(.openInPlay(.ballInPlay)) } label: {
                    CountButtonLabel("In play", hint: AtBatWording.inPlayHint)
                }
                .buttonStyle(CountButtonStyle.inPlay)
                .accessibilityLabel(Text("In play"))
                .accessibilityHint(Text("Out, hit or error: opens the play"))
            }
        }
        .frame(height: Spacing.countButtonHeight * 2 + Spacing.screenEdge)
    }

    /// The small Called button inside the Strike button's right edge.
    private var calledButton: some View {
        Button { pitch(.calledStrike) } label: {
            Text("Called")
                .font(ScorebookFont.chip)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(ScorebookColor.onStrike)
                .frame(width: calledWidth)
                .frame(maxHeight: .infinity)
                .background(ScorebookColor.onStrike.opacity(0.14),
                            in: RoundedRectangle(cornerRadius: Spacing.cornerRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Spacing.cornerRadius, style: .continuous)
                    .strokeBorder(ScorebookColor.onStrike.opacity(0.25), lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(Spacing.small)
        .padding(.bottom, Spacing.extraSmall)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .accessibilityLabel(Text("Called strike"))
        .accessibilityHint(Text(AtBatWording.hint(countAfter(.swingingStrike))))
    }

    /// Hands back one pitch to record.
    private func pitch(_ result: PitchResult) {
        onAction(.record(GameEvent(kind: .pitch(Pitch(result)))))
    }
}

// MARK: - The song button

/// The song spot across the bottom edge: our hitter's walk-up song (play, then a countdown to
/// the fade, tap to fade it out), a way to pick a song for our hitter who has none, our
/// pitcher's warm-up song at the changeover when we take the field (with a button beside it to
/// pick more warm-up songs for him), or an empty gray bar for their hitters.
struct SongButton: View {
    var info: AtBatInfo
    var onAction: (AtBatAction) -> Void

    var body: some View {
        switch info.songSpot {
        case .walkUp(let player, let title, let length):
            walkUpButton(player, title: title, length: length)
        case .noSong(let player):
            Button { onAction(.pickSong(for: player.id)) } label: {
                SongButtonLabel(icon: "plus", title: "No song for \(AtBatWording.shortName(player))",
                                detail: "Tap to pick one", iconFill: ScorebookColor.textSecondary)
            }
            .buttonStyle(QuietBarStyle())
            .accessibilityLabel(Text("No walk-up song for \(player.displayName)"))
            .accessibilityHint(Text("Pick one"))
        case .warmUp(let pitcher, let title):
            let playing = info.songPlayback == .warmUp
            HStack(spacing: Spacing.small) {
                Button { onAction(playing ? .stopSong : .playWarmUp(pitcher)) } label: {
                    SongButtonLabel(icon: playing ? "stop.fill" : "play.fill", title: title,
                                    detail: playing ? "Playing · tap to fade out"
                                                    : "Warm-up for \(AtBatWording.shortName(pitcher)), our pitcher",
                                    iconFill: ScorebookColor.onTheirTeam.opacity(0.25),
                                    iconColor: ScorebookColor.onTheirTeam)
                        .foregroundStyle(ScorebookColor.onTheirTeam)
                }
                .buttonStyle(WarmUpButtonStyle(isActive: playing))
                .accessibilityLabel(Text(playing ? "Fade out warm-up song, \(title)" : "Play warm-up song, \(title)"))
                // Pick more warm-up songs for him, or play a different one now.
                Button { onAction(.pickWarmUpSongs(pitcher)) } label: {
                    Image(systemName: "music.note.list")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(ScorebookColor.onTheirTeam)
                        .frame(width: Spacing.songButtonHeight)
                }
                .buttonStyle(WarmUpButtonStyle(isActive: false))
                .fixedSize(horizontal: true, vertical: false)
                .accessibilityLabel(Text("Warm-up songs for \(pitcher.displayName)"))
            }
        case .noWarmUp(let pitcher):
            Button { onAction(.pickWarmUpSongs(pitcher)) } label: {
                SongButtonLabel(icon: "plus", title: "No warm-up song for \(AtBatWording.shortName(pitcher))",
                                detail: "Tap to pick one", iconFill: ScorebookColor.textSecondary)
            }
            .buttonStyle(QuietBarStyle())
            .accessibilityLabel(Text("No warm-up song for \(pitcher.displayName)"))
            .accessibilityHint(Text("Pick one"))
        case .theirs:
            // An empty gray bar where the song button would be, so a habit tap plays nothing.
            RoundedRectangle(cornerRadius: Spacing.bigButtonCornerRadius, style: .continuous)
                .fill(ScorebookColor.surfaceSecondary)
                .overlay(RoundedRectangle(cornerRadius: Spacing.bigButtonCornerRadius, style: .continuous)
                    .strokeBorder(ScorebookColor.divider, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
                .frame(height: Spacing.songButtonHeight)
                .accessibilityElement()
                .accessibilityLabel(Text("No walk-up song for their hitters"))
        }
    }

    /// Our hitter's walk-up song: play (with the introduction first), then a countdown to the
    /// fade; a tap while playing stops it.
    private func walkUpButton(_ player: Player, title: String, length: TimeInterval) -> some View {
        let playing = info.songPlayback != .idle && info.songPlayback != .warmUp
        let withIntro = info.settings.playIntroductions && player.introduction != nil
        let seconds = Int(length.rounded())
        return Button {
            onAction(playing ? .stopSong : .playWalkUp(player, withIntroduction: withIntro))
        } label: {
            HStack(spacing: Spacing.medium) {
                SongButtonLabel(
                    icon: playing ? "stop.fill" : "play.fill",
                    title: title,
                    detail: playing
                        ? (info.songPlayback == .introduction ? "Introduction · song next" : "Tap to fade out")
                        : (withIntro ? "Introduction, then \(seconds) seconds of song" : "\(seconds) seconds, then fades"),
                    iconFill: ScorebookColor.onOurTeam,
                    iconColor: ScorebookColor.ourTeam
                )
                if playing { SongCountdown(playback: info.songPlayback, length: length) }
            }
            .foregroundStyle(ScorebookColor.onOurTeam)
        }
        .buttonStyle(TeamButtonStyle(.ours, isActive: playing))
        .accessibilityLabel(Text(playing ? "Fade out walk-up song, \(title)" : "Play walk-up song, \(title)"))
    }
}

/// The inside of a song button: a round icon, then the title over a smaller line.
struct SongButtonLabel: View {
    var icon: String
    var title: String
    var detail: String
    var iconFill: Color
    /// The color of the symbol inside the circle.
    var iconColor: Color = ScorebookColor.surface

    var body: some View {
        HStack(spacing: Spacing.medium) {
            Image(systemName: icon)
                .font(.body.weight(.bold))
                .foregroundStyle(iconColor)
                .frame(width: 38, height: 38)
                .background(iconFill, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(ScorebookFont.headline)
                Text(detail).font(ScorebookFont.caption)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.medium)
    }
}

/// The countdown on a playing walk-up song: seconds left over a shrinking bar, or a
/// microphone while the introduction plays. It ticks every second by itself.
struct SongCountdown: View {
    var playback: SongPlayback
    var length: TimeInterval

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let left = secondsLeft(at: context.date)
            VStack(spacing: 3) {
                if playback == .introduction {
                    Image(systemName: "mic.fill").font(.title3.weight(.bold))
                } else {
                    Text("\(left)").font(ScorebookFont.scoreboardSmall)
                }
                // The bar shrinks as the song runs down.
                GeometryReader { geo in
                    Capsule().fill(ScorebookColor.onOurTeam.opacity(0.25))
                        .overlay(alignment: .leading) {
                            Capsule().fill(ScorebookColor.onOurTeam)
                                .frame(width: geo.size.width * fraction(left))
                        }
                }
                .frame(width: 40, height: 4)
            }
            .frame(width: 48)
            .padding(.trailing, Spacing.medium)
            .accessibilityElement()
            .accessibilityLabel(Text(playback == .introduction ? "Introduction playing" : "\(left) seconds left"))
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    /// Whole seconds until the song fades, never below zero.
    private func secondsLeft(at now: Date) -> Int {
        guard case .song(let endsAt) = playback else { return Int(length.rounded()) }
        return max(0, Int(endsAt.timeIntervalSince(now).rounded(.up)))
    }

    /// How much of the bar to fill: all of it during the introduction.
    private func fraction(_ left: Int) -> CGFloat {
        guard playback != .introduction, length > 0 else { return 1 }
        return min(1, CGFloat(Double(left) / length))
    }
}

/// The warm-up song button: the warm-up purple with white words, the same size as the song button.
struct WarmUpButtonStyle: ButtonStyle {
    var isActive: Bool

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: Spacing.bigButtonCornerRadius, style: .continuous)
        return configuration.label
            .frame(maxWidth: .infinity, minHeight: Spacing.songButtonHeight)
            .background(shape.fill(ScorebookColor.warmUpMusic))
            .overlay { if isActive { shape.strokeBorder(ScorebookColor.onTheirTeam.opacity(0.7), lineWidth: 3) } }
            .contentShape(shape)
            .brightness(configuration.isPressed ? -0.08 : 0)
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }
}

/// A quiet gray bar the size of the song button, for "No song for Fisk" and the like.
struct QuietBar: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundStyle(ScorebookColor.textSecondary)
            .frame(maxWidth: .infinity, minHeight: Spacing.songButtonHeight)
            .background(ScorebookColor.surfaceSecondary,
                        in: RoundedRectangle(cornerRadius: Spacing.bigButtonCornerRadius, style: .continuous))
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }
}

/// The same quiet gray bar as a button style.
struct QuietBarStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .modifier(QuietBar())
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(Rectangle())
    }
}
