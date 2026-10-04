// Step five of five: one look at the game and both lineups, including fielders who don't bat
// and positions shared by turns, then "Play ball". Anything odd (an empty position, a third
// non-runner) is a note, never a block.

import SwiftUI
import Model
import DesignSystem

/// The last pregame step: review and "Play ball".
struct ReviewStep: View {
    var draft: PregameDraft
    var onPlayBall: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    /// The setup as it will start, for showing both lineups exactly as they will be.
    private var setup: GameSetup? { draft.setup() }

    var body: some View {
        StepPage(step: 5, title: "Review", buttonTitle: "Play ball", blockedReason: draft.missing,
                 isPlayBall: true, onButton: onPlayBall) {
            Section {
                VStack(alignment: .leading, spacing: Spacing.extraSmall) {
                    Text("\(draft.input.ourTeam.name) \(draft.details.weAreHome ? "vs" : "at") \(draft.opponentName)")
                        .font(.title2.weight(.heavy))
                    Text(summaryLine)
                        .font(ScorebookFont.body)
                        .foregroundStyle(ScorebookColor.textSecondary)
                }
                .padding(.vertical, Spacing.small)
                .cardRow()
            }
            if let setup, let ourSide = setup.ourSide {
                Section {
                    let layout = typeSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(spacing: Spacing.small))
                        : AnyLayout(HStackLayout(alignment: .top, spacing: Spacing.small))
                    layout {
                        teamCard(setup[ourSide], look: .ours)
                        teamCard(setup[ourSide.opponent], look: .theirs)
                    }
                    .bareRow()
                }
            }
            Section {
                ForEach(draft.notes, id: \.self) { note in
                    NoteBox(text: note).bareRow()
                }
                Text("NR marks a designated non-runner.")
                    .font(ScorebookFont.caption)
                    .foregroundStyle(ScorebookColor.textSecondary)
                    .bareRow()
            }
        }
    }

    /// "Sat, Oct 3 · we are home · 9 innings · start 9:00 AM · limit 12:00 PM".
    private var summaryLine: String {
        var parts = [
            PregameWording.day(draft.details.day),
            draft.details.weAreHome ? "we are home" : "we are away",
            "\(draft.details.innings) innings",
            "start \(PregameWording.clock(draft.details.scheduledStart()))",
            "limit \(PregameWording.clock(draft.details.timeLimitEnd()))",
        ]
        if draft.details.isChampionship { parts.append("championship") }
        return parts.joined(separator: " · ")
    }

    /// One team's card: the batting order with positions and NR tags, fielders who don't bat,
    /// positions shared by turns, and the starting pitcher.
    private func teamCard(_ team: GameTeam, look: TeamLook) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(team.name).font(ScorebookFont.headline).padding(.bottom, Spacing.extraSmall)
            ForEach(Array(team.battingOrder.enumerated()), id: \.element) { index, id in
                if let player = team.player(id) {
                    hitterLine(index + 1, player, team: team, look: look)
                }
            }
            Group {
                ForEach(team.defense.filter { !team.battingOrder.contains($0.player) }, id: \.self) { spot in
                    if spot.position != .pitcher, let player = team.player(spot.player) {
                        Text("\(player.lastName) \(spot.position.abbreviation), doesn’t bat")
                    }
                }
                ForEach(team.fieldingRotations, id: \.self) { rotation in
                    let names = rotation.players.compactMap { team.player($0)?.lastName }
                    Text("\(rotation.position.abbreviation): \(names.joined(separator: " odd, ")) even innings")
                }
                if let pitcher = team.startingPitcher.flatMap(team.player) {
                    let hand = PregameWording.handLetter(pitcher.throwsWith).map { " (\($0))" } ?? ""
                    let name = look == .ours ? pitcher.lastName : PregameWording.theirHitter(pitcher)
                    Text("Pitching: \(name)\(hand)")
                }
            }
            .font(ScorebookFont.caption)
            .foregroundStyle(ScorebookColor.textSecondary)
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(Spacing.medium)
        .background(ScorebookColor.surface, in: RoundedRectangle(cornerRadius: Spacing.cornerRadius + 2, style: .continuous))
    }

    /// "1. Moreno 2b NR" or "1. #1 Ortiz".
    private func hitterLine(_ spot: Int, _ player: Player, team: GameTeam, look: TeamLook) -> some View {
        HStack(spacing: Spacing.extraSmall) {
            Text("\(spot).").foregroundStyle(ScorebookColor.textSecondary).monospacedDigit()
            Text(look == .ours ? player.lastName : PregameWording.theirHitter(player))
                .lineLimit(1)
            if let position = team.startingPosition(of: player.id) {
                Text(position.abbreviation).foregroundStyle(ScorebookColor.textSecondary)
            }
            if team.isDesignatedNonRunner(player.id) {
                Text("NR")
                    .font(ScorebookFont.caption.weight(.heavy))
                    .padding(.horizontal, 5)
                    .background(ScorebookColor.sequenceBadge, in: RoundedRectangle(cornerRadius: 4))
                    .foregroundStyle(ScorebookColor.onStrike)
                    .accessibilityLabel(Text("designated non-runner"))
            }
        }
        .font(ScorebookFont.body)
    }
}
