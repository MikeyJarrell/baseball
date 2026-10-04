// The pages that slide in from the home screen: the season stats, the games list, a game's
// box score, a player's season, the teams and songs, and backups. Each hands the screen its
// data from the app model and turns the screen's requests into actions.

import SwiftUI
import UIKit
import Model
import DesignSystem
import BoxScoreText
import BoxScorePicture
import PostgameScreens

/// The page for one route from the home screen.
struct HomeDestination: View {
    @Environment(AppModel.self) private var app
    var route: HomeRoute
    @Binding var path: [HomeRoute]

    var body: some View {
        switch route {
        case .teams:
            TeamsPage(start: .teams)
        case .songs:
            TeamsPage(start: .songs)
        case .season:
            if let totals = app.seasonTotals() {
                SeasonStatsScreen(totals: totals,
                                  minimumPlateAppearances: app.settings.minimumPlateAppearances,
                                  minimumInnings: app.settings.minimumInnings,
                                  onRequest: handle)
            } else {
                EmptyPage(text: "Set up your team in Teams, and the season stats will build up game by game.")
            }
        case .games:
            GamesListScreen(games: app.gameSummaries, unreadableGames: app.damagedFiles.count, onRequest: handle)
        case .boxScore(let id):
            SavedBoxScore(id: id, onRequest: handle)
        case .player(let id):
            if let totals = app.seasonTotals() {
                PlayerSeasonScreen(totals: totals, player: id, onRequest: handle)
            }
        case .backups:
            BackupsPage()
        }
    }

    /// Acts on what the postgame and season screens ask for.
    private func handle(_ request: PostgameRequest) {
        switch request {
        case .done:
            if !path.isEmpty { path.removeLast() }
        case .shareBoxScore:
            break   // the share button in the box score's slot opens the share sheet itself
        case .copyBoxScoreText(let id):
            Task {
                if let box = await app.boxScore(for: id) { UIPasteboard.general.string = BoxScorePrinter.text(box) }
            }
        case .openSeasonStats:
            path.append(.season)
        case .openGame(let id):
            path.append(.boxScore(id))
        case .openPlayer(let id):
            path.append(.player(id))
        case .setMinimumPlateAppearances(let n):
            Task { await app.updateSettings { $0.minimumPlateAppearances = n } }
        case .setMinimumInnings(let n):
            Task { await app.updateSettings { $0.minimumInnings = n } }
        }
    }
}

/// A saved game's box score: the newspaper picture, the share button, and copy as text.
struct SavedBoxScore: View {
    @Environment(AppModel.self) private var app
    var id: GameID
    var onRequest: (PostgameRequest) -> Void
    @State private var box: BoxScore?

    var body: some View {
        Group {
            if let box {
                BoxScorePage(box: box, ourSide: app.ourSide(in: id), showsDoneButton: false, onRequest: onRequest)
            } else {
                ProgressView()
            }
        }
        .task(id: id) { box = await app.boxScore(for: id) }
    }
}

/// The end-of-game screen with the newspaper picture and its share button in the two slots.
struct BoxScorePage: View {
    var box: BoxScore
    var ourSide: TeamSide?
    var showsDoneButton: Bool
    var onRequest: (PostgameRequest) -> Void

    var body: some View {
        EndOfGameScreen(box: box, ourSide: ourSide, showsDoneButton: showsDoneButton, onRequest: onRequest) {
            BoxScorePicture(box)
        } shareButton: {
            BoxScoreShareLink(box)
        }
    }
}

/// A page with nothing to show yet, and a sentence saying how to fill it.
struct EmptyPage: View {
    var text: String

    var body: some View {
        Text(text)
            .font(ScorebookFont.body)
            .foregroundStyle(ScorebookColor.textSecondary)
            .multilineTextAlignment(.center)
            .padding(Spacing.extraLarge)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(ScorebookColor.background)
    }
}

/// Backups: write one now, or put everything back as it was in one. Backups are also made
/// by themselves at the end of every game. They sit in the folder the iPhone Files app shows
/// ("On My iPhone", Scorebook, backups), so they can be copied off the phone.
struct BackupsPage: View {
    @Environment(AppModel.self) private var app
    @State private var files: [URL] = []
    /// The backup the scorer tapped, waiting for them to confirm.
    @State private var restoring: URL?

    var body: some View {
        List {
            Section {
                Button("Back up now") {
                    Task {
                        _ = await app.makeBackup()
                        files = await app.backups()
                    }
                }
            } footer: {
                Text("A backup is also made at the end of every game. In the Files app, backups are under On My iPhone, Scorebook.")
            }
            Section("Put everything back as it was") {
                if files.isEmpty { Text("No backups yet.").foregroundStyle(ScorebookColor.textSecondary) }
                ForEach(files, id: \.self) { file in
                    Button(file.deletingPathExtension().lastPathComponent) { restoring = file }
                }
            }
        }
        .navigationTitle("Backups")
        .task { files = await app.backups() }
        .confirmationDialog("Replace everything in the scorebook with this backup?",
                            isPresented: Binding(get: { restoring != nil }, set: { if !$0 { restoring = nil } }),
                            titleVisibility: .visible) {
            Button("Replace with this backup", role: .destructive) {
                if let file = restoring {
                    Task {
                        await app.restore(from: file)
                        files = await app.backups()
                    }
                }
                restoring = nil
            }
        } message: {
            Text("Teams, games, songs and settings go back to how they were. What is there now is saved first as its own backup.")
        }
    }
}

extension AppModel {
    /// Which side was ours in a saved game, for the box score's colors and logo.
    func ourSide(in id: GameID) -> TeamSide? {
        if let game = finishedGames.first(where: { $0.id == id }) { return game.setup.ourSide }
        if let session, session.game.id == id { return session.setup.ourSide }
        return gameSummaries.first { $0.id == id }.map { $0.weAreHome ? .home : .away }
    }
}
