// The baseball decisions behind the field drawing, kept apart from the drawing itself:
// which bases light up, where a runner's tag and arrow go, whether to draw an out cross,
// and whether a tap counts as a hit location.
//
// These are plain functions: given the same runners they always give the same answer and
// draw nothing, so they can be checked by tests without a screen. ScorebookUI has no test
// target yet; when the lead builder adds one, these are the first things to test.

import CoreGraphics
import Model

enum FieldLogic {
    /// The bases to draw lit: runners standing on base, plus the base where each runner
    /// marker ended up safely, so the runner step shows the bases occupied after the play.
    /// Home plate is never lit; a runner who scores is shown by their tag at home instead.
    static func litBases(occupied: Set<Base>,
                         baseRunners: [Base: FieldBaseRunner],
                         markers: [FieldRunnerMarker]) -> Set<Base> {
        var lit = occupied.union(baseRunners.keys)
        for marker in markers {
            if let base = marker.to.base { lit.insert(base) }
        }
        lit.remove(.home)
        return lit
    }

    /// Whether we know where a runner was put out. A batter who flies out, or a runner put out
    /// with no base recorded, has no out-at base: the drawing then shows no path and no cross.
    static func outAtKnownBase(_ marker: FieldRunnerMarker) -> Bool {
        marker.to == .out && marker.outAt != nil
    }

    /// The base where a runner's tag goes: where they ended up, home plate if they scored,
    /// where they were put out, or, for a runner out with no base recorded (the batter on a
    /// fly out), the base they started from.
    static func tagBase(for marker: FieldRunnerMarker) -> Base {
        if marker.to == .out && marker.outAt == nil { return marker.from }
        return marker.endBase
    }

    /// The bases a runner's arrow passes through, counted round from home (0) to home again (4):
    /// from second to scoring is [2, 3, 4]. Empty when there is nothing to draw: a runner who
    /// stayed put, or one put out with no base recorded.
    static func pathOrders(for marker: FieldRunnerMarker) -> [Int] {
        if marker.to == .out && marker.outAt == nil { return [] }
        let start = marker.from.order, end = marker.endOrder
        guard end > start else { return [] }
        return Array(start...end)
    }

    /// Whether a spot on the drawing (in drawing units) is in fair territory: between the foul
    /// lines and inside the outfield fence. Only these taps count as where a hit landed.
    static func isFairTerritory(_ point: CGPoint) -> Bool {
        let home = Layout.home
        // Between the foul lines: no further sideways from home than it is out in front.
        guard point.y <= home.y, abs(point.x - home.x) <= home.y - point.y else { return false }
        // Inside the fence, the curve from one foul pole to the other.
        return point.y >= fenceY(atX: point.x)
    }

    /// How far up the drawing the outfield fence is at a given distance across, following the
    /// same curve the drawing uses (a curve from the left-field foul pole to the right-field one).
    static func fenceY(atX x: CGFloat) -> CGFloat {
        let left = Layout.leftFoulPole, right = Layout.rightFoulPole, control = Layout.fenceControl
        // The curve moves across at an even pace, so the fraction of the way across is simple.
        let t = min(1, max(0, (x - left.x) / (right.x - left.x)))
        return (1 - t) * (1 - t) * left.y + 2 * t * (1 - t) * control.y + t * t * right.y
    }

    /// The hit location a tap gives: the spot as a field point, or nothing when the drawing is
    /// zoomed to the infield (the batting screen, where taps are never hit locations) or the
    /// tap is outside fair territory.
    static func hitSpot(forTapAt point: CGPoint, zoom: FieldZoom) -> FieldPoint? {
        guard zoom == .wholeField, isFairTerritory(point) else { return nil }
        return Layout.fieldPoint(point)
    }
}
