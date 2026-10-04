// The field drawing: grass, dirt, foul lines and bases, the nine fielding positions as
// tappable circles, runners, throws and outs. Used by the batting screen (zoomed to the
// infield, with runners' name tags), the in-play sequence (the whole field, fielders tappable)
// and the game overview, at different sizes. Drawn in code, so it is sharp at any size.
//
// The interface (what the drawing is given, what it hands back) is the contract the
// foundation job wrote: `FieldTap`, `FieldRunnerMarker`, and `FieldDrawing`'s initializer and
// properties. Extra options are methods you add on the end, the way SwiftUI's own `.padding()`
// works: `FieldDrawing(...).zoom(.infield).battingTeam(.ours)`. Each returns a changed copy, so
// existing calls never change. The baseball decisions (which bases light, where tags go) are
// in FieldLogic.swift.
//
// How the drawing is laid out: everything is placed in "drawing units", a 320 by 322 square
// with home plate near the bottom middle, the same layout as the approved mockup. The view
// scales that square to fit whatever space it is given.

import SwiftUI
import Model

/// What the scorer tapped on the field drawing.
public enum FieldTap: Equatable, Sendable {
    /// A fielding position, such as the shortstop.
    case position(Position)
    /// A base, such as second.
    case base(Base)
    /// A runner's marker, by who the runner is. Used in the in-play sequence's runner step,
    /// where two markers can sit on the same base (the batter and a runner who scored both
    /// end at home), so the base alone cannot say which runner was meant. Also used for the
    /// name tags of runners standing on base (see `FieldDrawing.baseRunners(_:)`).
    case runner(PlayerID)
    /// Somewhere else on the field, such as where a hit landed. `nearest` is the fielding
    /// area it is closest to, for notation like "1B 7".
    case spot(FieldPoint, nearest: Position)
}

/// A runner to show on the drawing with an arrow from where they started to where they
/// ended up, for the in-play sequence's runner step.
public struct FieldRunnerMarker: Equatable, Sendable, Identifiable {
    public var id: PlayerID { runner }
    public var runner: PlayerID
    /// What to write on the marker, usually a jersey number or last name.
    public var label: String
    public var from: Base
    public var to: RunnerEnd
    /// For a runner put out: the base they were put out at, where the marker is drawn.
    /// Copy it from `RunnerMove.outAt`. Missing means the next base along.
    public var outAt: Base?

    public init(runner: PlayerID, label: String, from: Base, to: RunnerEnd, outAt: Base? = nil) {
        self.runner = runner
        self.label = label
        self.from = from
        self.to = to
        self.outAt = outAt
    }

    /// Makes a marker from a runner's move on a play.
    public init(_ move: RunnerMove, label: String) {
        self.init(runner: move.runner, label: label, from: move.from, to: move.to, outAt: move.outAt)
    }

    /// The base the marker is drawn at: where they ended up, home plate if they scored, or
    /// where they were put out.
    public var endBase: Base {
        if let base = to.base { return base }
        if to == .scored { return .home }
        return outAt ?? Base.allCases.first { $0.order == (from.order + 1) % 4 } ?? .second
    }

    /// How far round the bases the marker's arrow goes, counting home as 0 at the start and
    /// 4 when the runner scores. A batter put out at first ends at 1; a runner from second
    /// who scores ends at 4.
    var endOrder: Int {
        if to == .scored { return 4 }
        let end = endBase.order
        return end == 0 ? 4 : end
    }
}

/// A runner standing on a base between pitches, shown on the batting screen as a name tag
/// beside the base. Tapping the tag hands back `.runner` with this id, which opens the runner
/// actions (steal, pickoff, wild pitch).
public struct FieldBaseRunner: Equatable, Sendable {
    public var runner: PlayerID
    /// What to write on the tag: a last name, or a number for an unnamed opponent.
    public var label: String

    public init(runner: PlayerID, label: String) {
        self.runner = runner
        self.label = label
    }
}

/// How much of the field the drawing shows.
public enum FieldZoom: Sendable {
    /// Foul line to foul line and the whole outfield, with all nine fielders. For the in-play
    /// sequence, where fielders and hit locations are tapped.
    case wholeField
    /// Just the infield, larger, with no fielders. For the batting screen, where the runners
    /// matter and space is tight.
    case infield
}

/// The field drawing.
///
/// - `occupiedBases`: bases with a runner on them, drawn lit up.
/// - `highlightedPositions`: fielding positions drawn picked out, such as the fielders in a play.
/// - `tapSequence`: fielders in the order the scorer tapped them; each shows its number in the
///   sequence (6 then 3 shows "1" on the shortstop and "2" on the first baseman), and a dashed
///   arrow shows each throw.
/// - `runnerMarkers`: runners with arrows from where they started to where they ended up.
///   A runner put out gets a red dashed path and a red cross at the base. Tapping a marker
///   hands back `.runner` with that runner's id.
/// - `onTap`: called with whatever the scorer taps. Leave it out for a drawing that only shows.
///
/// More options, each returning a changed copy: `.zoom(_:)`, `.showsFielders(_:)`,
/// `.fielderNames(_:)`, `.baseRunners(_:)`, `.battingTeam(_:)`, `.hitLocation(_:)` and
/// `.errorPositions(_:)`.
public struct FieldDrawing: View {
    public var occupiedBases: Set<Base>
    public var highlightedPositions: Set<Position>
    public var tapSequence: [Position]
    public var runnerMarkers: [FieldRunnerMarker]
    public var onTap: ((FieldTap) -> Void)?

    // The extra options, set through the modifier-style methods below.
    var zoomLevel: FieldZoom = .wholeField
    var fieldersShown: Bool?
    var namesByPosition: [Position: String] = [:]
    var runnersOnBases: [Base: FieldBaseRunner] = [:]
    var teamLook: TeamLook?
    var hitSpot: FieldPoint?
    var positionsWithErrors: Set<Position> = []

    public init(
        occupiedBases: Set<Base> = [],
        highlightedPositions: Set<Position> = [],
        tapSequence: [Position] = [],
        runnerMarkers: [FieldRunnerMarker] = [],
        onTap: ((FieldTap) -> Void)? = nil
    ) {
        self.occupiedBases = occupiedBases
        self.highlightedPositions = highlightedPositions
        self.tapSequence = tapSequence
        self.runnerMarkers = runnerMarkers
        self.onTap = onTap
    }

    public var body: some View {
        let area = zoomLevel == .infield ? Layout.infieldArea : Layout.wholeFieldArea
        GeometryReader { geo in
            let map = Mapper(area: area, size: geo.size)
            ZStack(alignment: .topLeading) {
                ground(map)
                throwArrows(map)
                runnerPaths(map)
                bases(map)
                if showFielders {
                    fielders(map)
                }
                hitMarker(map)
                runnerTags(map)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(area.width / area.height, contentMode: .fit)
        // Zoomed in, the outfield reaches past the frame; keep it inside.
        .clipped()
    }

    /// Whether the fielder circles are drawn.
    private var showFielders: Bool { fieldersShown ?? (zoomLevel == .wholeField) }

    /// The color for runners and lit bases: the batting team's, or neutral amber if not given.
    private var runnerFill: Color { teamLook?.fill ?? ScorebookColor.baseOccupied }
    private var runnerText: Color { teamLook?.onFill ?? ScorebookColor.onStrike }

    // MARK: Grass, dirt and lines

    /// The grass, the infield dirt, the infield grass, the foul lines and the mound.
    /// Tapping anywhere on the ground reports a spot, for where a hit landed.
    private func ground(_ map: Mapper) -> some View {
        ZStack(alignment: .topLeading) {
            if zoomLevel == .infield {
                // Zoomed in, the grass fills the whole frame.
                Rectangle().fill(ScorebookColor.fieldGrass)
            }
            // The outfield: from home plate out along both foul lines, joined by the fence.
            Path { p in
                p.move(to: map.point(Layout.home))
                p.addLine(to: map.point(Layout.leftFoulPole))
                p.addQuadCurve(to: map.point(Layout.rightFoulPole), control: map.point(Layout.fenceControl))
                p.closeSubpath()
            }
            .fill(ScorebookColor.fieldGrass)
            // The infield dirt: a fan from behind home plate out past the bases.
            Path { p in
                p.move(to: map.point(CGPoint(x: 160, y: 296)))
                p.addLine(to: map.point(CGPoint(x: 62, y: 198)))
                p.addQuadCurve(to: map.point(CGPoint(x: 258, y: 198)), control: map.point(CGPoint(x: 160, y: 34)))
                p.closeSubpath()
            }
            .fill(ScorebookColor.fieldDirt)
            // The infield grass inside the base paths.
            Path { p in
                p.addLines([CGPoint(x: 160, y: 261), CGPoint(x: 216, y: 205), CGPoint(x: 160, y: 149), CGPoint(x: 104, y: 205)].map(map.point))
                p.closeSubpath()
            }
            .fill(ScorebookColor.fieldGrassInfield)
            // The dirt circle around home plate.
            Circle().fill(ScorebookColor.fieldDirt)
                .frame(width: 34 * map.scale, height: 34 * map.scale)
                .position(map.point(Layout.home))
            // The foul lines.
            Path { p in
                p.move(to: map.point(Layout.leftFoulPole)); p.addLine(to: map.point(Layout.home))
                p.addLine(to: map.point(Layout.rightFoulPole))
            }
            .stroke(ScorebookColor.fieldChalk, lineWidth: max(1, 2 * map.scale))
            // The pitcher's mound.
            Circle().fill(ScorebookColor.fieldDirt)
                .overlay(Circle().stroke(ScorebookColor.fieldOutline, lineWidth: 1))
                .frame(width: 18 * map.scale, height: 18 * map.scale)
                .position(map.point(Layout.mound))
        }
        .contentShape(Rectangle())
        .gesture(SpatialTapGesture().onEnded { tap in
            // Only a tap in fair territory on the whole field counts as where a hit landed.
            guard let onTap, let spot = FieldLogic.hitSpot(forTapAt: map.unit(tap.location), zoom: zoomLevel) else { return }
            onTap(.spot(spot, nearest: FieldDrawing.nearestPosition(to: spot)))
        })
        .accessibilityHidden(true)
    }

    // MARK: Bases

    /// The three bases and home plate. A lit base takes the batting team's color.
    private func bases(_ map: Mapper) -> some View {
        let lit = FieldLogic.litBases(occupied: occupiedBases, baseRunners: runnersOnBases, markers: runnerMarkers)
        let side = 16 * map.scale
        return ZStack(alignment: .topLeading) {
            // Home plate, drawn as the five-sided plate.
            Path { p in
                p.addLines([CGPoint(x: 152, y: 271), CGPoint(x: 168, y: 271), CGPoint(x: 168, y: 277), CGPoint(x: 160, y: 284), CGPoint(x: 152, y: 277)].map(map.point))
                p.closeSubpath()
            }
            .fill(ScorebookColor.baseEmpty)
            .overlay(Path { p in
                p.addLines([CGPoint(x: 152, y: 271), CGPoint(x: 168, y: 271), CGPoint(x: 168, y: 277), CGPoint(x: 160, y: 284), CGPoint(x: 152, y: 277)].map(map.point))
                p.closeSubpath()
            }.stroke(ScorebookColor.fieldOutline, lineWidth: 1))
            ForEach([Base.first, .second, .third], id: \.self) { base in
                let isLit = lit.contains(base)
                let square = RoundedRectangle(cornerRadius: 2 * map.scale)
                Button { onTap?(.base(base)) } label: {
                    // An occupied base is filled in the batting team's color with a thick dark
                    // outline; an empty base is only an outline, so the two differ in sun.
                    square.fill(isLit ? runnerFill : Color.clear)
                        .overlay(square.stroke(isLit ? ScorebookColor.baseOccupiedOutline : ScorebookColor.baseEmptyOutline,
                                               lineWidth: isLit ? max(2.5, 3.5 * map.scale) : max(1.5, 2 * map.scale)))
                        .frame(width: side, height: side)
                        .rotationEffect(.degrees(45))
                        .frame(width: max(Spacing.minimumTapSize, side * 2), height: max(Spacing.minimumTapSize, side * 2))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(onTap == nil)
                .position(map.point(Layout.base(base)))
                .accessibilityLabel(Text("\(base.rawValue) base\(isLit ? ", runner on" : "")"))
            }
        }
    }

    // MARK: Fielders and throws

    /// The nine fielders as numbered circles. A tapped fielder turns blue with an amber badge
    /// giving its place in the tap sequence; a fielder charged with an error turns red.
    private func fielders(_ map: Mapper) -> some View {
        let radius = 19 * map.scale
        let numberSize = max(11, 19 * map.scale)
        return ZStack(alignment: .topLeading) {
            ForEach(Position.allCases, id: \.self) { position in
                let order = tapSequence.enumerated().filter { $0.element == position }.map { $0.offset + 1 }
                let isError = positionsWithErrors.contains(position)
                let isPicked = isError || highlightedPositions.contains(position) || !order.isEmpty
                let fill = isError ? ScorebookColor.out : (isPicked ? ScorebookColor.highlight : ScorebookColor.surface)
                Button { onTap?(.position(position)) } label: {
                    VStack(spacing: 1) {
                        ZStack(alignment: .topTrailing) {
                            Text(String(position.number))
                                .font(.system(size: numberSize, weight: .heavy))
                                .foregroundStyle(isPicked ? Color.white : ScorebookColor.textPrimary)
                                .frame(width: radius * 2, height: radius * 2)
                                .background(fill, in: Circle())
                                .overlay(Circle().stroke(isPicked ? fill : ScorebookColor.textPrimary, lineWidth: max(1.5, 2.5 * map.scale)))
                            if !order.isEmpty && !isError {
                                Text(order.map(String.init).joined(separator: ","))
                                    .font(.system(size: max(10, 12 * map.scale), weight: .heavy))
                                    .foregroundStyle(Color.black)
                                    .padding(.horizontal, 5 * map.scale)
                                    .frame(minWidth: 18 * map.scale, minHeight: 18 * map.scale)
                                    .background(ScorebookColor.sequenceBadge, in: Capsule())
                                    .overlay(Capsule().stroke(ScorebookColor.surface, lineWidth: 1.5))
                                    .offset(x: 8 * map.scale, y: -8 * map.scale)
                            }
                        }
                        if let name = namesByPosition[position] {
                            Text(name)
                                .font(.system(size: max(9, 11 * map.scale), weight: .bold))
                                .foregroundStyle(ScorebookColor.textPrimary)
                                .lineLimit(1)
                                .fixedSize()
                        }
                    }
                    .frame(minWidth: max(Spacing.minimumTapSize, radius * 2.8), minHeight: max(Spacing.minimumTapSize, radius * 2.8))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(onTap == nil)
                // Names hang below the circle, so the circle itself stays on the fielder's spot.
                .position(map.point(Layout.position(position)).offset(dy: namesByPosition[position] == nil ? 0 : 7 * map.scale))
                .accessibilityLabel(Text("\(position.name.capitalized), \(position.number)"))
                .accessibilityValue(Text(isError ? "error" : order.isEmpty ? "" : "tapped \(order.map(String.init).joined(separator: " and "))"))
            }
        }
    }

    /// A dashed blue arrow for each throw in the tap sequence: shortstop to first base for a 6-3.
    private func throwArrows(_ map: Mapper) -> some View {
        let pairs = zip(tapSequence, tapSequence.dropFirst()).filter { $0 != $1 }
        return ZStack {
            ForEach(Array(pairs.enumerated()), id: \.offset) { _, pair in
                let start = Layout.position(pair.0), end = Layout.position(pair.1)
                let (from, to) = Layout.trim(start, end, startBy: 23, endBy: 26)
                Path { p in p.move(to: map.point(from)); p.addLine(to: map.point(to)) }
                    .stroke(ScorebookColor.highlight, style: StrokeStyle(lineWidth: max(2, 3 * map.scale), lineCap: .round, dash: [6 * map.scale, 5 * map.scale]))
                Arrowhead(tip: map.point(to), from: map.point(from), size: 9 * map.scale)
                    .fill(ScorebookColor.highlight)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: Runners

    /// Each runner marker's path round the bases: solid with an arrowhead in the batting
    /// team's color for a runner who reached safely, red and dashed with a cross for one put out.
    private func runnerPaths(_ map: Mapper) -> some View {
        ZStack {
            ForEach(runnerMarkers) { marker in
                let points = FieldLogic.pathOrders(for: marker).map(Layout.base(order:))
                if marker.to == .out {
                    if points.count > 1 {
                        Path { p in p.addLines(points.map(map.point)) }
                            .stroke(ScorebookColor.out, style: StrokeStyle(lineWidth: max(2, 4 * map.scale), lineCap: .round, dash: [3 * map.scale, 7 * map.scale]))
                    }
                    if FieldLogic.outAtKnownBase(marker) {
                        OutCross(center: map.point(Layout.base(marker.endBase)), size: 9 * map.scale)
                            .stroke(ScorebookColor.out, style: StrokeStyle(lineWidth: max(2.5, 4 * map.scale), lineCap: .round))
                    }
                } else if points.count > 1 {
                    Path { p in p.addLines(points.map(map.point)) }
                        .stroke(runnerFill, style: StrokeStyle(lineWidth: max(2.5, 5 * map.scale), lineCap: .round, lineJoin: .round))
                    Arrowhead(tip: map.point(points[points.count - 1]), from: map.point(points[points.count - 2]), size: 12 * map.scale)
                        .fill(runnerFill)
                }
            }
        }
        .allowsHitTesting(false)
    }

    /// Name tags: one for each runner marker at the base where they ended up, and one for each
    /// runner standing on base. Tags that land on the same base sit side by side, so each can
    /// be tapped.
    private func runnerTags(_ map: Mapper) -> some View {
        // Every tag to draw: who, what it says, where, and whether it is a runner put out.
        let tags: [(id: PlayerID, label: String, base: Base, isOut: Bool)] =
            runnerMarkers.map { ($0.runner, $0.to == .out ? "\($0.label) out" : $0.label, FieldLogic.tagBase(for: $0), $0.to == .out) }
            + runnersOnBases.sorted { $0.key.order < $1.key.order }.map { ($0.value.runner, $0.value.label, $0.key, false) }
        // Tags grow with the drawing, but only up to a point: on an iPad the drawing is three
        // times its iPhone size, and tags that big crowd the bases.
        let tagScale = min(map.scale, 1.6)
        let fontSize = max(12, 14 * tagScale)
        return ZStack(alignment: .topLeading) {
            ForEach(Array(tags.enumerated()), id: \.offset) { _, tag in
                let sameBase = tags.filter { $0.base == tag.base }
                let index = sameBase.firstIndex { $0.id == tag.id } ?? 0
                let spread = (CGFloat(index) - CGFloat(sameBase.count - 1) / 2) * 76 * tagScale
                Button { onTap?(.runner(tag.id)) } label: {
                    Text(tag.label)
                        .font(.system(size: fontSize, weight: .bold))
                        .lineLimit(1)
                        .fixedSize()
                        .foregroundStyle(tag.isOut ? ScorebookColor.out : runnerText)
                        .padding(.horizontal, 10 * tagScale)
                        .frame(minHeight: 28 * tagScale)
                        .background {
                            if tag.isOut {
                                Capsule().fill(ScorebookColor.surface)
                                    .overlay(Capsule().strokeBorder(ScorebookColor.out, style: StrokeStyle(lineWidth: 2, dash: [4, 3])))
                            } else {
                                Capsule().fill(runnerFill).overlay(Capsule().strokeBorder(Color.black.opacity(0.85), lineWidth: 1.5))
                            }
                        }
                        .frame(minWidth: Spacing.minimumTapSize, minHeight: Spacing.minimumTapSize)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(onTap == nil)
                .position(map.point(Layout.tagSpot(tag.base, fieldersShown: showFielders)).offset(dx: spread))
                .accessibilityLabel(Text(tag.isOut ? "\(tag.label) at \(tag.base.rawValue)" : "Runner \(tag.label), \(tag.base == .home ? "scored" : "on \(tag.base.rawValue)")"))
            }
        }
    }

    /// A blue dot where the scorer said a hit landed.
    private func hitMarker(_ map: Mapper) -> some View {
        ZStack {
            if let hitSpot {
                let center = map.point(Layout.unitPoint(hitSpot))
                Circle().stroke(ScorebookColor.highlight.opacity(0.5), lineWidth: 2)
                    .frame(width: 32 * map.scale, height: 32 * map.scale).position(center)
                Circle().fill(ScorebookColor.highlight)
                    .overlay(Circle().stroke(Color.white, lineWidth: 3))
                    .frame(width: 18 * map.scale, height: 18 * map.scale).position(center)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(hitSpot == nil)
        .accessibilityLabel(Text("Where the ball landed"))
    }

    // MARK: Where things are on the drawing

    /// Where a fielder stands on the drawing, as a field point (0 to 1 across, 0 at home
    /// plate to 1 at the deepest part of the outfield).
    public static func spot(for position: Position) -> FieldPoint {
        Layout.fieldPoint(Layout.position(position))
    }

    /// Where a base is on the drawing, as a field point.
    public static func spot(for base: Base) -> FieldPoint {
        Layout.fieldPoint(Layout.base(base))
    }

    /// The fielding area closest to a spot on the field, for hit locations: a ball landing in
    /// shallow left is nearest the left fielder, so the notation reads "1B 7". The catcher is
    /// left out, since no hit lands behind home plate.
    public static func nearestPosition(to point: FieldPoint) -> Position {
        Position.allCases.filter { $0 != .catcher }.min { a, b in
            distance(spot(for: a), point) < distance(spot(for: b), point)
        } ?? .centerField
    }

    private static func distance(_ a: FieldPoint, _ b: FieldPoint) -> Double {
        (a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y)
    }
}

// MARK: - Options

extension FieldDrawing {
    /// Shows the whole field or just the infield. The batting screen uses `.infield`.
    public func zoom(_ zoom: FieldZoom) -> FieldDrawing {
        var copy = self; copy.zoomLevel = zoom; return copy
    }

    /// Shows or hides the nine fielder circles. By default they show on the whole field and
    /// hide when zoomed to the infield.
    public func showsFielders(_ shown: Bool) -> FieldDrawing {
        var copy = self; copy.fieldersShown = shown; return copy
    }

    /// Writes a short name under each fielder, such as "Ortiz" under the shortstop.
    /// Use it when our team is in the field; their fielders are known by position only.
    public func fielderNames(_ names: [Position: String]) -> FieldDrawing {
        var copy = self; copy.namesByPosition = names; return copy
    }

    /// Runners standing on base, each with a tappable name tag. The bases light up by themselves.
    public func baseRunners(_ runners: [Base: FieldBaseRunner]) -> FieldDrawing {
        var copy = self; copy.runnersOnBases = runners; return copy
    }

    /// Colors runners, their arrows and lit bases in the batting team's color, so our runners
    /// are powder blue and theirs slate.
    public func battingTeam(_ look: TeamLook) -> FieldDrawing {
        var copy = self; copy.teamLook = look; return copy
    }

    /// Marks where a hit landed with a blue dot.
    public func hitLocation(_ point: FieldPoint?) -> FieldDrawing {
        var copy = self; copy.hitSpot = point; return copy
    }

    /// Fielders charged with an error on this play, drawn red: the shortstop for an E6.
    public func errorPositions(_ positions: Set<Position>) -> FieldDrawing {
        var copy = self; copy.positionsWithErrors = positions; return copy
    }
}

// MARK: - Layout in drawing units

/// Where everything sits, in drawing units: a 320 by 322 square, home plate at the bottom middle,
/// 100 units diagonally from home to first. These match the approved mockup.
enum Layout {
    static let home = CGPoint(x: 160, y: 276)
    static let mound = CGPoint(x: 160, y: 207)
    static let leftFoulPole = CGPoint(x: 10, y: 126)
    static let rightFoulPole = CGPoint(x: 310, y: 126)
    /// The point that bends the outfield fence into its curve between the two foul poles.
    static let fenceControl = CGPoint(x: 160, y: -92)

    /// The part of the drawing shown for each zoom level.
    static let wholeFieldArea = CGRect(x: 0, y: 0, width: 320, height: 322)
    static let infieldArea = CGRect(x: 22, y: 90, width: 276, height: 224)

    /// Where each base is.
    static func base(_ base: Base) -> CGPoint {
        switch base {
        case .home: home
        case .first: CGPoint(x: 231, y: 205)
        case .second: CGPoint(x: 160, y: 134)
        case .third: CGPoint(x: 89, y: 205)
        }
    }

    /// Where each fielder stands.
    static func position(_ position: Position) -> CGPoint {
        switch position {
        case .pitcher: mound
        case .catcher: CGPoint(x: 160, y: 302)
        case .firstBase: CGPoint(x: 238, y: 174)
        case .secondBase: CGPoint(x: 204, y: 127)
        case .thirdBase: CGPoint(x: 82, y: 174)
        case .shortstop: CGPoint(x: 116, y: 127)
        case .leftField: CGPoint(x: 64, y: 78)
        case .centerField: CGPoint(x: 160, y: 50)
        case .rightField: CGPoint(x: 256, y: 78)
        }
    }

    /// Where a runner's name tag sits for each base: beside it, out of the base paths' way.
    /// With the fielders drawn, the tag for second sits higher, above the shortstop and second
    /// baseman, and the tag for home sits in front of the plate, clear of the catcher.
    static func tagSpot(_ base: Base, fieldersShown: Bool = false) -> CGPoint {
        switch base {
        case .first: CGPoint(x: 244, y: 240)
        case .second: CGPoint(x: 160, y: fieldersShown ? 94 : 110)
        case .third: CGPoint(x: 76, y: 240)
        // With the fielders drawn, the catcher stands behind the plate, so the tag sits in front of it.
        case .home: CGPoint(x: 160, y: fieldersShown ? 252 : 297)
        }
    }

    /// A base by how far round it is from home: 0 and 4 are home plate, 1 first, 2 second, 3 third.
    static func base(order: Int) -> CGPoint {
        base(Base.allCases.first { $0.order == order % 4 } ?? .home)
    }

    /// A line from one spot to another, shortened at both ends so it starts and stops at the
    /// edge of a fielder's circle instead of its middle.
    static func trim(_ a: CGPoint, _ b: CGPoint, startBy: CGFloat, endBy: CGFloat) -> (CGPoint, CGPoint) {
        let dx = b.x - a.x, dy = b.y - a.y
        let length = max(1, (dx * dx + dy * dy).squareRoot())
        let ux = dx / length, uy = dy / length
        return (CGPoint(x: a.x + ux * startBy, y: a.y + uy * startBy),
                CGPoint(x: b.x - ux * endBy, y: b.y - uy * endBy))
    }

    /// A drawing-unit point as a field point: 0 to 1 across from the left-field side, and
    /// 0 at home plate to 1 at the deepest part of center field.
    static func fieldPoint(_ p: CGPoint) -> FieldPoint {
        FieldPoint(x: Double(min(1, max(0, p.x / 320))), y: Double(min(1, max(0, (home.y - p.y) / (home.y - 20)))))
    }

    /// The reverse: a field point as a drawing-unit point.
    static func unitPoint(_ p: FieldPoint) -> CGPoint {
        CGPoint(x: CGFloat(p.x) * 320, y: home.y - CGFloat(p.y) * (home.y - 20))
    }
}

/// The mapper: turns drawing units into points on screen for a given view size, keeping the
/// drawing's shape and centering it.
struct Mapper {
    let area: CGRect
    let size: CGSize

    /// Screen points per drawing unit.
    var scale: CGFloat { max(0.01, min(size.width / area.width, size.height / area.height)) }

    private var origin: CGPoint {
        CGPoint(x: (size.width - area.width * scale) / 2 - area.minX * scale,
                y: (size.height - area.height * scale) / 2 - area.minY * scale)
    }

    /// A drawing-unit point on screen.
    func point(_ p: CGPoint) -> CGPoint {
        CGPoint(x: origin.x + p.x * scale, y: origin.y + p.y * scale)
    }

    /// A screen point back in drawing units, for taps.
    func unit(_ p: CGPoint) -> CGPoint {
        CGPoint(x: (p.x - origin.x) / scale, y: (p.y - origin.y) / scale)
    }
}

extension CGPoint {
    /// The same point moved by the given amounts.
    func offset(dx: CGFloat = 0, dy: CGFloat = 0) -> CGPoint {
        CGPoint(x: x + dx, y: y + dy)
    }
}

/// A filled triangle pointing at `tip`, coming from the direction of `from`: the head of a
/// throw or runner arrow.
struct Arrowhead: Shape {
    var tip: CGPoint
    var from: CGPoint
    var size: CGFloat

    func path(in rect: CGRect) -> Path {
        let dx = tip.x - from.x, dy = tip.y - from.y
        let length = max(1, (dx * dx + dy * dy).squareRoot())
        let ux = dx / length, uy = dy / length
        let back = CGPoint(x: tip.x - ux * size, y: tip.y - uy * size)
        var path = Path()
        path.move(to: tip)
        path.addLine(to: CGPoint(x: back.x - uy * size * 0.6, y: back.y + ux * size * 0.6))
        path.addLine(to: CGPoint(x: back.x + uy * size * 0.6, y: back.y - ux * size * 0.6))
        path.closeSubpath()
        return path
    }
}

/// A red cross marking where a runner was put out.
struct OutCross: Shape {
    var center: CGPoint
    var size: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: center.offset(dx: -size, dy: -size)); path.addLine(to: center.offset(dx: size, dy: size))
        path.move(to: center.offset(dx: size, dy: -size)); path.addLine(to: center.offset(dx: -size, dy: size))
        return path
    }
}

// MARK: - Previews

/// Our fielders' names, for previews where our team is in the field.
private let previewNames: [Position: String] = [
    .pitcher: "Fischer", .catcher: "Whitaker", .firstBase: "Kowalski", .secondBase: "Nakamura",
    .thirdBase: "Ramos", .shortstop: "Ortiz", .leftField: "Hartley", .centerField: "Diaz", .rightField: "Brooks",
]

#Preview("6-3, nobody on") {
    FieldDrawing(tapSequence: [.shortstop, .firstBase], onTap: { _ in })
        .padding()
        .background(ScorebookColor.background)
}

#Preview("5-4-3 with a runner on first, our fielders") {
    FieldDrawing(occupiedBases: [.first], tapSequence: [.thirdBase, .secondBase, .firstBase], onTap: { _ in })
        .fielderNames(previewNames)
        .battingTeam(.theirs)
        .padding()
        .background(ScorebookColor.background)
}

#Preview("Bases loaded, batting screen") {
    FieldDrawing(onTap: { _ in })
        .zoom(.infield)
        .battingTeam(.ours)
        .baseRunners([
            .first: FieldBaseRunner(runner: "d2", label: "Ortiz"),
            .second: FieldBaseRunner(runner: "d1", label: "Diaz"),
            .third: FieldBaseRunner(runner: "d5", label: "Ramos"),
        ])
        .frame(height: 260)
}

#Preview("Bases loaded, dark") {
    FieldDrawing(occupiedBases: [.first, .second, .third])
        .zoom(.infield)
        .battingTeam(.theirs)
        .baseRunners([
            .first: FieldBaseRunner(runner: "m4", label: "#22"),
            .second: FieldBaseRunner(runner: "m2", label: "Thompson"),
            .third: FieldBaseRunner(runner: "m1", label: "Reyes"),
        ])
        .frame(height: 260)
        .preferredColorScheme(.dark)
}

#Preview("Runner outcomes: single, runner from second scores") {
    FieldDrawing(
        runnerMarkers: [
            FieldRunnerMarker(runner: "d1", label: "Diaz", from: .second, to: .scored),
            FieldRunnerMarker(runner: "d3", label: "Kowalski", from: .home, to: .first),
        ],
        onTap: { _ in }
    )
    .zoom(.infield)
    .battingTeam(.ours)
    .frame(height: 280)
}

#Preview("Runner outcomes: 5-4-3 double play") {
    FieldDrawing(
        tapSequence: [.thirdBase, .secondBase, .firstBase],
        runnerMarkers: [
            FieldRunnerMarker(runner: "d2", label: "Ortiz", from: .first, to: .out, outAt: .second),
            FieldRunnerMarker(runner: "d3", label: "Kowalski", from: .home, to: .out, outAt: .first),
        ],
        onTap: { _ in }
    )
    .battingTeam(.ours)
    .padding()
    .background(ScorebookColor.background)
}

#Preview("Runner outcomes, dark: two runners score") {
    FieldDrawing(
        runnerMarkers: [
            FieldRunnerMarker(runner: "d5", label: "Ramos", from: .third, to: .scored),
            FieldRunnerMarker(runner: "d1", label: "Diaz", from: .second, to: .scored),
            FieldRunnerMarker(runner: "d3", label: "Kowalski", from: .home, to: .second),
        ],
        onTap: { _ in }
    )
    .zoom(.infield)
    .battingTeam(.ours)
    .frame(height: 280)
    .preferredColorScheme(.dark)
}

#Preview("Error by the shortstop, single to left") {
    VStack {
        FieldDrawing(onTap: { _ in }).errorPositions([.shortstop])
        FieldDrawing(onTap: { _ in }).hitLocation(FieldPoint(x: 0.22, y: 0.6))
    }
    .padding()
    .background(ScorebookColor.background)
}

#Preview("Largest text size") {
    FieldDrawing(tapSequence: [.shortstop, .firstBase], onTap: { _ in })
        .fielderNames(previewNames)
        .padding()
        .background(ScorebookColor.background)
        .environment(\.dynamicTypeSize, .accessibility5)
}
