// One song (mockup: SCREENS.song): its title and length, the start point, the volume, and who
// uses it. The start point is set by listening: play the song, and tap "Start here" at the hook.
// It can also be set by tapping or dragging along the drawing of the track, and fine-tuned with
// the nudge buttons (one second or a tenth of a second either way). "Play from 0:42" checks it.
// Rename is in the top bar; "Assign to a player" opens the list of our players.

import SwiftUI
import Model
import DesignSystem

/// One song: start point, volume and who uses it.
public struct SongPage: View {
    public var songID: SongID
    public var data: TeamScreensData
    public var onRequest: (TeamScreensRequest) -> Void

    /// The start point while the scorer drags along the track; handed back when they let go.
    @State private var draggedStart: TimeInterval?
    /// The volume while the slider moves; handed back when they let go.
    @State private var draggedVolume: Double?
    @State private var showsRename = false
    @State private var renameText = ""
    @State private var showsAssign = false

    public init(songID: SongID, data: TeamScreensData, onRequest: @escaping (TeamScreensRequest) -> Void) {
        self.songID = songID
        self.data = data
        self.onRequest = onRequest
    }

    public var body: some View {
        if let song = data.library.song(songID) {
            content(song)
        } else {
            ContentUnavailableView("Song not found", systemImage: "music.note",
                                   description: Text("This song is no longer in the library."))
                .teamPageBackground()
        }
    }

    private func content(_ song: Song) -> some View {
        let start = draggedStart ?? song.startTime
        let isPlaying = data.audio.isPlayingSong(song.id)
        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                AdaptiveStack(spacing: Spacing.medium) {
                    SongArt(size: 64)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(song.title).font(ScorebookFont.title).foregroundStyle(ScorebookColor.textPrimary)
                        Text(song.duration.map { "Whole track " + TeamWording.clock($0) } ?? song.fileName)
                            .font(ScorebookFont.caption).foregroundStyle(ScorebookColor.textSecondary)
                    }
                }
                .padding(.top, Spacing.small)

                ProblemsBox(problems: data.audio.problems) { onRequest(.dismissProblems) }
                    .padding(.top, Spacing.small)

                HStack(alignment: .lastTextBaseline) {
                    SectionLabel("Start point")
                    Spacer(minLength: Spacing.small)
                    Text(TeamWording.clockTenths(start))
                        .font(ScorebookFont.scoreboardSmall)
                        .foregroundStyle(ScorebookColor.textPrimary)
                        .padding(.bottom, Spacing.small)
                }
                TrackDrawing(song: song, start: start, playhead: isPlaying ? data.audio.position : nil) { seconds, finished in
                    let clamped = TeamWording.clampedStart(seconds, in: song)
                    if finished {
                        draggedStart = nil
                        onRequest(.setStartPoint(clamped, for: song.id))
                    } else {
                        draggedStart = clamped
                    }
                }
                nudges(song, start: start)
                    .padding(.top, Spacing.medium)
                listeningButtons(song, start: start, isPlaying: isPlaying)
                    .padding(.top, Spacing.medium)

                volume(song)
                usedBy(song)
            }
            .padding(.horizontal, Spacing.large)
            .padding(.bottom, Spacing.huge)
            .readableWidth()
        }
        .teamPageBackground()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Rename") {
                    renameText = song.title
                    showsRename = true
                }
            }
        }
        .alert("Rename song", isPresented: $showsRename) {
            TextField("Song name", text: $renameText)
            Button("Cancel", role: .cancel) {}
            Button("Rename") {
                let title = renameText.trimmingCharacters(in: .whitespaces)
                if !title.isEmpty, title != song.title { onRequest(.renameSong(song.id, to: title)) }
            }
        }
        .sheet(isPresented: $showsAssign) {
            AssignSongSheet(song: song, data: data, onRequest: onRequest)
        }
    }

    /// −1 s, −0.1 s, +0.1 s, +1 s.
    private func nudges(_ song: Song, start: TimeInterval) -> some View {
        HStack(spacing: Spacing.small) {
            ForEach([-1.0, -0.1, 0.1, 1.0], id: \.self) { step in
                Button(step < 0 ? "−\(abs(step).formatted()) s" : "+\(step.formatted()) s") {
                    onRequest(.setStartPoint(TeamWording.clampedStart(start + step, in: song), for: song.id))
                }
                .buttonStyle(WideButtonStyle(kind: .quiet, compact: true))
                .lineLimit(1)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .accessibilityLabel(step < 0 ? "Start \(abs(step).formatted()) seconds earlier" : "Start \(step.formatted()) seconds later")
            }
        }
    }

    /// "Play from 0:42", and while the song plays, Stop and "Start here".
    @ViewBuilder
    private func listeningButtons(_ song: Song, start: TimeInterval, isPlaying: Bool) -> some View {
        if isPlaying {
            let position = data.audio.position
            VStack(spacing: Spacing.small) {
                Button {
                    if let position { onRequest(.setStartPoint(TeamWording.clampedStart(position, in: song), for: song.id)) }
                } label: {
                    Label("Start here" + (position.map { " (\(TeamWording.clockTenths($0)))" } ?? ""), systemImage: "flag.fill")
                }
                .buttonStyle(WideButtonStyle(kind: .ours))
                .disabled(position == nil)
                Button { onRequest(.stopPlaying) } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .buttonStyle(WideButtonStyle(kind: .quiet))
            }
        } else {
            VStack(spacing: Spacing.small) {
                Button { onRequest(.playPreview(song.id, from: start)) } label: {
                    Label("Play from \(TeamWording.clock(start))", systemImage: "play.fill")
                }
                .buttonStyle(WideButtonStyle(kind: .ours))
                Button { onRequest(.playPreview(song.id, from: 0)) } label: {
                    Label("Play from the top, to find the hook", systemImage: "backward.end.fill")
                }
                .buttonStyle(WideButtonStyle(kind: .quiet, compact: true))
            }
        }
    }

    /// The volume slider, 40 to 100 percent (lower if the song is already set lower).
    private func volume(_ song: Song) -> some View {
        let value = draggedVolume ?? song.volume
        let lowest = min(0.4, song.volume)
        return VStack(alignment: .leading, spacing: 0) {
            SectionLabel("Volume", trailing: TeamWording.percent(value))
            Card(padding: Spacing.medium) {
                HStack(spacing: Spacing.medium) {
                    Image(systemName: "speaker.fill").accessibilityHidden(true)
                    Slider(value: volumeBinding(value), in: lowest...1, onEditingChanged: { editing in
                        volumeEditingChanged(editing, song: song.id)
                    })
                    .tint(ScorebookColor.ourTeamDeep)
                    .accessibilityLabel("Volume")
                    Image(systemName: "speaker.wave.3.fill").accessibilityHidden(true)
                }
                .foregroundStyle(ScorebookColor.textSecondary)
            }
        }
    }

    /// The slider's value: the volume being dragged, rounded to whole percents.
    private func volumeBinding(_ value: Double) -> Binding<Double> {
        Binding(get: { value }, set: { draggedVolume = ($0 * 100).rounded() / 100 })
    }

    /// Hands back the new volume when the finger lifts from the slider.
    private func volumeEditingChanged(_ editing: Bool, song: SongID) {
        guard !editing, let draggedVolume else { return }
        onRequest(.setVolume(draggedVolume, for: song))
        self.draggedVolume = nil
    }

    /// Our players who use this song, and the button to assign it.
    private func usedBy(_ song: Song) -> some View {
        let (walkUp, warmUp) = TeamWording.users(of: song.id, in: data.ourTeam)
        let users = walkUp.map { ($0, SongSlot.walkUp) } + warmUp.map { ($0, SongSlot.warmUp) }
        return VStack(alignment: .leading, spacing: 0) {
            SectionLabel("Used by")
            Card(padding: 0) {
                if users.isEmpty {
                    Text("Nobody yet")
                        .font(ScorebookFont.body)
                        .foregroundStyle(ScorebookColor.textSecondary)
                        .padding(Spacing.large - 2)
                }
                ForEach(users, id: \.0.id.rawValue) { player, slot in
                    HStack(spacing: Spacing.medium) {
                        NumberBadge(player: player, look: .ours)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(player.displayName).font(ScorebookFont.headline)
                            Text(slot == .walkUp ? "Walk-up" : "Pitcher warm-up")
                                .font(ScorebookFont.caption).foregroundStyle(ScorebookColor.textSecondary)
                        }
                    }
                    .padding(.horizontal, Spacing.large - 2)
                    .frame(minHeight: 56)
                    Divider().padding(.leading, Spacing.large - 2)
                }
                Button { showsAssign = true } label: {
                    Label("Assign to a player", systemImage: "plus")
                        .font(ScorebookFont.headline)
                        .foregroundStyle(ScorebookColor.inPlay)
                        .padding(.horizontal, Spacing.large - 2)
                        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(data.ourTeam == nil)
            }
        }
    }
}

/// A drawing of the track with a line at the start point. Tap or drag along it to move the start
/// point. Bars after the start point are in our blue; while the song plays, a thin line follows
/// where it is.
struct TrackDrawing: View {
    var song: Song
    var start: TimeInterval
    var playhead: TimeInterval?
    /// Hands back the seconds under the finger, and whether the finger has lifted.
    var onMove: (TimeInterval, _ finished: Bool) -> Void

    private let barCount = 90

    var body: some View {
        let length = TeamWording.timelineLength(of: song)
        let heights = TeamWording.waveformHeights(seed: song.id.rawValue, count: barCount)
        GeometryReader { geometry in
            let width = geometry.size.width
            Canvas { context, size in
                let step = size.width / CGFloat(barCount)
                let startFraction = start / length
                for (i, height) in heights.enumerated() {
                    let barHeight = CGFloat(height) * (size.height - 16)
                    let rect = CGRect(x: CGFloat(i) * step + 1, y: (size.height - barHeight) / 2,
                                      width: max(1, step - 1.4), height: barHeight)
                    let isAfter = Double(i) / Double(barCount) >= startFraction
                    context.fill(Path(roundedRect: rect, cornerRadius: 1),
                                 with: .color(isAfter ? ScorebookColor.ourTeamDeep : ScorebookColor.divider))
                }
                let cueX = CGFloat(startFraction) * size.width
                context.fill(Path(CGRect(x: cueX - 1.5, y: 0, width: 3, height: size.height)), with: .color(ScorebookColor.out))
                if let playhead {
                    let x = CGFloat(min(1, playhead / length)) * size.width
                    context.fill(Path(CGRect(x: x - 1, y: 4, width: 2, height: size.height - 8)),
                                 with: .color(ScorebookColor.textPrimary))
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { onMove(seconds(at: $0.location.x, width: width, length: length), false) }
                    .onEnded { onMove(seconds(at: $0.location.x, width: width, length: length), true) }
            )
        }
        .frame(height: 90)
        .padding(.vertical, Spacing.small)
        .padding(.horizontal, Spacing.small)
        .background(ScorebookColor.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement()
        .accessibilityLabel("Start point")
        .accessibilityValue(TeamWording.clockTenths(start))
        .accessibilityAdjustableAction { direction in
            onMove(start + (direction == .increment ? 1 : -1), true)
        }
    }

    /// The seconds into the track at a point across the drawing.
    private func seconds(at x: CGFloat, width: CGFloat, length: TimeInterval) -> TimeInterval {
        guard width > 0 else { return 0 }
        return Double(min(max(0, x / width), 1)) * length
    }
}
