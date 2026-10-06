// The song library (mockup: SCREENS.songs): every imported song, with a play button, where its
// clip starts, and which of our players use it as a walk-up or warm-up song. Import (top right)
// opens the iPhone's file picker and hands back the chosen files; the audio player copies them
// in. Tapping a song opens its page: start point, volume, rename and who uses it.

import SwiftUI
import UniformTypeIdentifiers
import Model
import DesignSystem

/// Every imported song, and the Import button.
public struct SongLibraryScreen: View {
    public var data: TeamScreensData
    public var onRequest: (TeamScreensRequest) -> Void

    @State private var showsImporter = false

    public init(data: TeamScreensData, onRequest: @escaping (TeamScreensRequest) -> Void) {
        self.data = data
        self.onRequest = onRequest
    }

    /// The songs in alphabetical order.
    private var songs: [Song] {
        data.library.songs.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    public var body: some View {
        List {
            Section {
                VStack(spacing: Spacing.small) {
                    ProblemsBox(problems: data.audio.problems) { onRequest(.dismissProblems) }
                    if data.audio.isImporting {
                        HStack(spacing: Spacing.small) {
                            ProgressView()
                            Text("Copying songs in…").font(ScorebookFont.body)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, Spacing.small)
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            if songs.isEmpty {
                Section {
                    VStack(spacing: Spacing.medium) {
                        Text("No songs yet. Import MP3, M4A, WAV or AAC files.")
                            .font(ScorebookFont.body)
                            .foregroundStyle(ScorebookColor.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        importButton
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            } else {
                Section {
                    ForEach(songs) { song in
                        SongLibraryRow(song: song, usage: TeamWording.usageText(of: song.id, in: data.ourTeam),
                                       isPlaying: data.audio.isPlayingSong(song.id), onRequest: onRequest)
                            .listRowBackground(ScorebookColor.surface)
                    }
                } header: {
                    ListHeader(songs.count == 1 ? "1 song" : "\(songs.count) songs")
                }
            }
        }
        .teamListStyle()
        .navigationTitle("Songs")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showsImporter = true } label: {
                    HStack(spacing: Spacing.extraSmall) {
                        Image(systemName: "folder")
                        Text("Import")
                    }
                }
                .fontWeight(.bold)
                .disabled(data.audio.isImporting)
            }
        }
        .fileImporter(isPresented: $showsImporter, allowedContentTypes: [.audio], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result, !urls.isEmpty {
                onRequest(.importSongs(urls))
            }
        }
    }

    /// The big Import button for an empty library.
    private var importButton: some View {
        Button { showsImporter = true } label: {
            Label("Import songs", systemImage: "folder")
        }
        .buttonStyle(PrimaryButtonStyle())
    }
}

/// One song in the library: play button, title, where it starts and who uses it.
struct SongLibraryRow: View {
    var song: Song
    var usage: String
    var isPlaying: Bool
    var onRequest: (TeamScreensRequest) -> Void

    var body: some View {
        HStack(spacing: Spacing.small) {
            SongPlayButton(isPlaying: isPlaying) {
                onRequest(isPlaying ? .stopPlaying : .playPreview(song.id, from: song.startTime))
            }
            NavigationLink(value: TeamScreensRoute.song(song.id)) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(song.title).font(ScorebookFont.headline).foregroundStyle(ScorebookColor.textPrimary)
                    Text("starts \(TeamWording.clock(song.startTime)) · \(usage)")
                        .font(ScorebookFont.caption)
                        .foregroundStyle(usage == "unassigned" ? ScorebookColor.textSecondary : ScorebookColor.textPrimary.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(minHeight: 52, alignment: .leading)
            }
        }
    }
}
