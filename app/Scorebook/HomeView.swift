// The home screen, as in the approved mockup (plan/mockups/index.html, SCREENS.home): today's
// date over a big "Scorebook" with the team logo; the game in progress, if there is one, with
// the inning, both scores and a "Resume scoring" bar in our color; then six tiles, words only:
// New game, Teams, Songs, Season stats, Games and Last box score.
//
// Everything else in the app opens from here: the pregame screens and the batting screen
// cover the whole screen; the other pages slide in from the right.

import SwiftUI
import Model
import DesignSystem
import Scoring
import TeamScreens

/// The pages that slide in from the home screen.
enum HomeRoute: Hashable {
    /// Teams and rosters.
    case teams
    /// The song library.
    case songs
    /// The season stats.
    case season
    /// Every saved game.
    case games
    /// One game's box score.
    case boxScore(GameID)
    /// One of our players' season and game log.
    case player(PlayerID)
    /// Backups: make one now, or put one back.
    case backups
}

/// The home screen.
struct HomeView: View {
    @Environment(AppModel.self) private var app
    /// The pages slid in from the home screen, oldest first. A mixed list, because the teams
    /// and songs pages push their own kind of page onto it.
    @State private var path = NavigationPath()
    /// True while the pregame screens are open.
    @State private var settingUpGame = false
    /// True while the batting screen is open.
    @State private var scoring = false
    /// True once the app has opened a game left in progress, so it happens only at launch.
    @State private var checkedForGameInProgress = false
    /// True when "Play ball" saved a new game: the batting screen opens once the pregame
    /// screens have finished sliding away.
    @State private var openGameAfterPregame = false

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.large) {
                    header
                    if let session = app.session, !session.isFinished {
                        ResumeCard(session: session) { scoring = true }
                    }
                    tiles
                    if !app.damagedFiles.isEmpty {
                        Text("\(app.damagedFiles.count) saved file\(app.damagedFiles.count == 1 ? "" : "s") could not be read.")
                            .font(ScorebookFont.caption)
                            .foregroundStyle(ScorebookColor.out)
                    }
                    Button("Backups") { path.append(HomeRoute.backups) }
                        .font(ScorebookFont.body)
                        .tint(ScorebookColor.ourTeamText)
                        .frame(maxWidth: .infinity)
                        .padding(.top, Spacing.small)
                }
                .padding(.horizontal, Spacing.large)
                .padding(.bottom, Spacing.extraLarge)
            }
            .background(ScorebookColor.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: HomeRoute.self) { route in
                HomeDestination(route: route, path: $path)
            }
            // The teams and songs pages link to each other on this same stack.
            .teamScreenDestinations(app.teamScreensData, onRequest: app.handleTeams)
        }
        .tint(ScorebookColor.inPlay)
        .fullScreenCover(isPresented: $settingUpGame, onDismiss: {
            if openGameAfterPregame {
                openGameAfterPregame = false
                scoring = true
            }
        }) {
            PregameCover(onStarted: {
                openGameAfterPregame = true
                settingUpGame = false
            }, onCancel: { settingUpGame = false })
        }
        // Leaving a finished game closes it, so the home screen stops offering to resume it.
        .fullScreenCover(isPresented: $scoring, onDismiss: { app.closeFinishedGame() }) {
            if let session = app.session {
                GameScreen(session: session, onLeave: { scoring = false })
            }
        }
        .alert("Something went wrong", isPresented: Binding(get: { app.problem != nil }, set: { if !$0 { app.problem = nil } })) {
            Button("OK", role: .cancel) { app.problem = nil }
        } message: {
            Text(app.problem ?? "")
        }
        // A name recorded from a player's page.
        .sheet(item: Binding(get: { app.teamsWiring.recordingNameFor.flatMap { id in app.teams.lazy.compactMap { $0.player(id) }.first } },
                             set: { if $0 == nil { app.teamsWiring.recordingNameFor = nil } })) { player in
            NameRecordingSheet(player: player) { kept in
                app.teamsWiring.recordingNameFor = nil
                if let kept { Task { await app.setNameIntroduction(kept, for: player.id) } }
            }
        }
        // A recording that stopped by itself (the 30-second limit, a phone call) is collected,
        // so the recording sheet offers Listen and Keep.
        .onChange(of: app.audio?.isRecording) { _, _ in app.collectRecordingThatStopped() }
        .onChange(of: app.audio?.pendingRecording) { _, _ in app.collectRecordingThatStopped() }
        .task {
            // Resume: if the app was closed in the middle of a game, go straight back to it.
            guard !checkedForGameInProgress else { return }
            checkedForGameInProgress = true
            if let session = app.session, !session.isFinished { scoring = true }
        }
    }

    /// Today's date, the big title and the logo.
    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()).uppercased())
                    .font(ScorebookFont.sectionLabel)
                    .foregroundStyle(ScorebookColor.textSecondary)
                Text("Scorebook")
                    .font(ScorebookFont.largeTitle)
                    .foregroundStyle(ScorebookColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)
            }
            Spacer()
            TeamLogo(size: 58)
        }
        .padding(.top, Spacing.medium)
    }

    /// The six tiles in two columns.
    private var tiles: some View {
        let columns = [GridItem(.flexible(), spacing: Spacing.medium), GridItem(.flexible(), spacing: Spacing.medium)]
        return LazyVGrid(columns: columns, spacing: Spacing.medium) {
            HomeTile(title: "New game", isPrimary: true) { newGame() }
            HomeTile(title: "Teams") { path.append(HomeRoute.teams) }
            HomeTile(title: "Songs") { path.append(HomeRoute.songs) }
            HomeTile(title: "Season stats") { path.append(HomeRoute.season) }
            HomeTile(title: "Games") { path.append(HomeRoute.games) }
            HomeTile(title: "Last box score") {
                if let game = app.lastFinishedGame { path.append(HomeRoute.boxScore(game.id)) } else { path.append(HomeRoute.games) }
            }
        }
    }

    /// New game: the pregame screens, once our team is set up. A game already in progress
    /// must be finished first, so two games are never open at once.
    private func newGame() {
        if let session = app.session, !session.isFinished {
            app.problem = "A game is still in progress. End it first."
        } else if app.ourTeam == nil {
            app.problem = "Set up your team first, in Teams."
        } else {
            app.closeFinishedGame()
            settingUpGame = true
        }
    }
}

/// One home-screen tile: a word or two, nothing else.
struct HomeTile: View {
    var title: String
    var isPrimary = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.title3, design: .default, weight: .bold))
                .foregroundStyle(isPrimary ? ScorebookColor.onOurTeam : ScorebookColor.textPrimary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
                .padding(.horizontal, Spacing.large)
                .background(isPrimary ? ScorebookColor.ourTeam : ScorebookColor.surface,
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.06), radius: 3, y: 1)
        }
        .buttonStyle(.plain)
    }
}

/// The game in progress: the inning and outs, both teams and their runs, and "Resume scoring".
struct ResumeCard: View {
    var session: GameSession
    var onResume: () -> Void

    var body: some View {
        let s = session.situation
        Button(action: onResume) {
            VStack(spacing: 0) {
                HStack {
                    Text("● Game in progress").foregroundStyle(ScorebookColor.out)
                    Spacer()
                    Text(inningText(s)).foregroundStyle(ScorebookColor.textSecondary)
                }
                .font(ScorebookFont.sectionLabel)
                .padding(.horizontal, Spacing.large)
                .padding(.top, Spacing.medium)

                HStack(spacing: Spacing.medium) {
                    teamScore(session.setup.away.name, s.score.away)
                    teamScore(session.setup.home.name, s.score.home)
                }
                .padding(.horizontal, Spacing.large)
                .padding(.vertical, Spacing.small)

                HStack {
                    Text("Resume scoring")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .font(.system(.headline, weight: .heavy))
                .foregroundStyle(ScorebookColor.onOurTeam)
                .padding(.horizontal, Spacing.large)
                .padding(.vertical, Spacing.medium)
                .background(ScorebookColor.ourTeam)
            }
            .background(ScorebookColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 3, y: 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Resume scoring: \(session.setup.away.name) \(s.score.away), \(session.setup.home.name) \(s.score.home), \(inningText(s))"))
    }

    /// One team's name and runs.
    private func teamScore(_ name: String, _ runs: Int) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(name).font(.headline).lineLimit(1).minimumScaleFactor(0.7)
            Spacer(minLength: Spacing.small)
            Text("\(runs)").font(ScorebookFont.scoreboard)
        }
        .foregroundStyle(ScorebookColor.textPrimary)
        .frame(maxWidth: .infinity)
    }

    /// "▼ 3rd, 1 out".
    private func inningText(_ s: Situation) -> String {
        let arrow = s.half == .top ? "▲" : "▼"
        return "\(arrow) \(ordinal(s.inning)), \(s.outs) out\(s.outs == 1 ? "" : "s")"
    }
}

/// "1st", "2nd", "3rd", "11th".
func ordinal(_ n: Int) -> String {
    let ones = n % 10, tens = (n / 10) % 10
    let suffix = tens == 1 ? "th" : (ones == 1 ? "st" : ones == 2 ? "nd" : ones == 3 ? "rd" : "th")
    return "\(n)\(suffix)"
}
