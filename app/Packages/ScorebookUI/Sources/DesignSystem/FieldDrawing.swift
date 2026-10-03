// The field drawing: a diamond with the nine fielding positions as tappable spots and the
// bases lighting up when occupied. Used by the batting screen, the in-play sequence and the
// game overview, at different sizes.
//
// The interface (what the drawing is given, what it hands back) is the contract written by
// the foundation job. The drawing itself is a plain placeholder; the designer replaces the
// body of `FieldDrawing` and keeps its initializer and `FieldTap`.

import SwiftUI
import Model

/// What the scorer tapped on the field drawing.
public enum FieldTap: Equatable, Sendable {
    /// A fielding position, such as the shortstop.
    case position(Position)
    /// A base, such as second.
    case base(Base)
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

    public init(runner: PlayerID, label: String, from: Base, to: RunnerEnd) {
        self.runner = runner
        self.label = label
        self.from = from
        self.to = to
    }
}

/// The field drawing.
///
/// - `occupiedBases`: bases with a runner on them, drawn lit up.
/// - `highlightedPositions`: fielding positions drawn picked out, such as the fielders in a play.
/// - `tapSequence`: fielders in the order the scorer tapped them; each shows its number in the
///   sequence (6 then 3 shows "1" on the shortstop and "2" on the first baseman).
/// - `runnerMarkers`: runners with arrows from where they started to where they ended up.
/// - `onTap`: called with whatever the scorer taps. Leave it out for a drawing that only shows.
public struct FieldDrawing: View {
    public var occupiedBases: Set<Base>
    public var highlightedPositions: Set<Position>
    public var tapSequence: [Position]
    public var runnerMarkers: [FieldRunnerMarker]
    public var onTap: ((FieldTap) -> Void)?

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
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            ZStack {
                // Grass, tapping anywhere on it reports a spot.
                Rectangle()
                    .fill(ScorebookColor.fieldGrass)
                    .contentShape(Rectangle())
                    .gesture(SpatialTapGesture().onEnded { tap in
                        let point = FieldPoint(x: tap.location.x / size, y: 1 - tap.location.y / size)
                        onTap?(.spot(point, nearest: FieldDrawing.nearestPosition(to: point)))
                    })

                // The infield diamond, base to base.
                Path { path in
                    path.addLines([Base.home, .first, .second, .third, .home].map { point(Self.spot(for: $0), size) })
                }
                .stroke(ScorebookColor.fieldDirt, lineWidth: size * 0.02)

                // Runner arrows.
                ForEach(runnerMarkers) { marker in
                    Path { path in
                        path.move(to: point(Self.spot(for: marker.from), size))
                        path.addLine(to: point(Self.spot(for: marker.to), size))
                    }
                    .stroke(ScorebookColor.highlight, style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                    Text(marker.label)
                        .font(ScorebookFont.caption)
                        .padding(2)
                        .background(ScorebookColor.surface, in: Capsule())
                        .position(point(Self.spot(for: marker.to), size))
                }

                // The bases.
                ForEach(Base.allCases, id: \.self) { base in
                    Rectangle()
                        .fill(occupiedBases.contains(base) ? ScorebookColor.baseOccupied : ScorebookColor.baseEmpty)
                        .frame(width: size * 0.05, height: size * 0.05)
                        .rotationEffect(.degrees(45))
                        .frame(width: max(Spacing.minimumTapSize, size * 0.08), height: max(Spacing.minimumTapSize, size * 0.08))
                        .contentShape(Rectangle())
                        .onTapGesture { onTap?(.base(base)) }
                        .position(point(Self.spot(for: base), size))
                        .accessibilityLabel(Text("\(base.rawValue) base\(occupiedBases.contains(base) ? ", runner on" : "")"))
                }

                // The fielders.
                ForEach(Position.allCases, id: \.self) { position in
                    let order = tapSequence.enumerated().filter { $0.element == position }.map { $0.offset + 1 }
                    let picked = highlightedPositions.contains(position) || !order.isEmpty
                    ZStack(alignment: .topTrailing) {
                        Text(String(position.number))
                            .font(ScorebookFont.headline)
                            .foregroundStyle(picked ? Color.white : ScorebookColor.textPrimary)
                            .frame(width: Spacing.minimumTapSize, height: Spacing.minimumTapSize)
                            .background(picked ? ScorebookColor.highlight : ScorebookColor.surface, in: Circle())
                        if !order.isEmpty {
                            Text(order.map(String.init).joined(separator: ","))
                                .font(ScorebookFont.caption)
                                .padding(3)
                                .background(ScorebookColor.warning, in: Capsule())
                                .offset(x: 8, y: -8)
                        }
                    }
                    .onTapGesture { onTap?(.position(position)) }
                    .position(point(Self.spot(for: position), size))
                    .accessibilityLabel(Text(position.name))
                    .accessibilityAddTraits(onTap == nil ? [] : .isButton)
                }
            }
            .frame(width: size, height: size)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    /// Turns a field point (0 to 1, home plate at the bottom) into a point on screen.
    private func point(_ p: FieldPoint, _ size: CGFloat) -> CGPoint {
        CGPoint(x: p.x * size, y: (1 - p.y) * size)
    }

    // MARK: Where things are on the drawing

    /// Where a fielder stands on the drawing.
    public static func spot(for position: Position) -> FieldPoint {
        switch position {
        case .pitcher: FieldPoint(x: 0.50, y: 0.26)
        case .catcher: FieldPoint(x: 0.50, y: 0.04)
        case .firstBase: FieldPoint(x: 0.74, y: 0.32)
        case .secondBase: FieldPoint(x: 0.63, y: 0.50)
        case .thirdBase: FieldPoint(x: 0.26, y: 0.32)
        case .shortstop: FieldPoint(x: 0.37, y: 0.50)
        case .leftField: FieldPoint(x: 0.17, y: 0.74)
        case .centerField: FieldPoint(x: 0.50, y: 0.87)
        case .rightField: FieldPoint(x: 0.83, y: 0.74)
        }
    }

    /// Where a base is on the drawing.
    public static func spot(for base: Base) -> FieldPoint {
        switch base {
        case .home: FieldPoint(x: 0.50, y: 0.10)
        case .first: FieldPoint(x: 0.67, y: 0.27)
        case .second: FieldPoint(x: 0.50, y: 0.44)
        case .third: FieldPoint(x: 0.33, y: 0.27)
        }
    }

    /// Where a runner's arrow ends: their base, home plate if they scored, or where they
    /// were heading if they were put out (drawn at second as a placeholder).
    static func spot(for end: RunnerEnd) -> FieldPoint {
        spot(for: end.base ?? (end == .scored ? .home : .second))
    }

    /// The fielding area closest to a spot on the field, for hit locations.
    public static func nearestPosition(to point: FieldPoint) -> Position {
        Position.allCases.min { a, b in
            distance(spot(for: a), point) < distance(spot(for: b), point)
        } ?? .centerField
    }

    private static func distance(_ a: FieldPoint, _ b: FieldPoint) -> Double {
        (a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y)
    }
}

#Preview("6-3, nobody on") {
    FieldDrawing(tapSequence: [.shortstop, .firstBase]).padding()
}

#Preview("5-4-3 with a runner on first") {
    FieldDrawing(occupiedBases: [.first], tapSequence: [.thirdBase, .secondBase, .firstBase]).padding()
}

#Preview("Bases loaded, dark") {
    FieldDrawing(occupiedBases: [.first, .second, .third]).padding()
        .preferredColorScheme(.dark)
}
