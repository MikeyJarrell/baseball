// Tests for the field drawing's baseball logic (FieldLogic.swift) and the Strike button's words.
// Written by the designer; run with the ScorebookUI package's tests on an iPhone simulator.

import XCTest
import SwiftUI
@testable import DesignSystem
import Model

@MainActor
final class FieldLogicTests: XCTestCase {
  func testFlyOutBatterTagAtHomeNoPathNoCross() {
    let m = FieldRunnerMarker(runner: "d3", label: "Kowalski", from: .home, to: .out)
    XCTAssertEqual(FieldLogic.tagBase(for: m), .home)
    XCTAssertEqual(FieldLogic.pathOrders(for: m), [])
    XCTAssertFalse(FieldLogic.outAtKnownBase(m))
    XCTAssertEqual(m.endBase, .first) // the stub's contract is unchanged
  }
  func testDoublePlayOutsAtSecondAndFirst() {
    let r = FieldRunnerMarker(runner: "d2", label: "Ortiz", from: .first, to: .out, outAt: .second)
    let b = FieldRunnerMarker(runner: "d3", label: "Kowalski", from: .home, to: .out, outAt: .first)
    XCTAssertEqual(FieldLogic.pathOrders(for: r), [1, 2]); XCTAssertTrue(FieldLogic.outAtKnownBase(r)); XCTAssertEqual(FieldLogic.tagBase(for: r), .second)
    XCTAssertEqual(FieldLogic.pathOrders(for: b), [0, 1]); XCTAssertEqual(FieldLogic.tagBase(for: b), .first)
    XCTAssertEqual(FieldLogic.litBases(occupied: [], baseRunners: [:], markers: [r, b]), [])
  }
  func testSingleRunnerFromSecondScores() {
    let r = FieldRunnerMarker(runner: "d1", label: "Diaz", from: .second, to: .scored)
    let b = FieldRunnerMarker(runner: "d3", label: "Kowalski", from: .home, to: .first)
    XCTAssertEqual(FieldLogic.pathOrders(for: r), [2, 3, 4]); XCTAssertEqual(FieldLogic.tagBase(for: r), .home)
    XCTAssertEqual(FieldLogic.pathOrders(for: b), [0, 1])
    XCTAssertEqual(FieldLogic.litBases(occupied: [], baseRunners: [:], markers: [r, b]), [.first])
  }
  func testRunnerWhoStaysHasNoPath() {
    let r = FieldRunnerMarker(runner: "d1", label: "Diaz", from: .second, to: .second)
    XCTAssertEqual(FieldLogic.pathOrders(for: r), []); XCTAssertEqual(FieldLogic.tagBase(for: r), .second)
  }
  func testHitSpots() {
    // Shallow left field, deep center: fair. Behind home, past the fence, foul: not.
    XCTAssertNotNil(FieldLogic.hitSpot(forTapAt: CGPoint(x: 70, y: 110), zoom: .wholeField))
    XCTAssertNotNil(FieldLogic.hitSpot(forTapAt: CGPoint(x: 160, y: 30), zoom: .wholeField))
    XCTAssertNil(FieldLogic.hitSpot(forTapAt: CGPoint(x: 160, y: 300), zoom: .wholeField))
    XCTAssertNil(FieldLogic.hitSpot(forTapAt: CGPoint(x: 160, y: 5), zoom: .wholeField))
    XCTAssertNil(FieldLogic.hitSpot(forTapAt: CGPoint(x: 30, y: 250), zoom: .wholeField))
    // The batting screen's infield view never gives a hit location.
    XCTAssertNil(FieldLogic.hitSpot(forTapAt: CGPoint(x: 160, y: 180), zoom: .infield))
    let spot = FieldLogic.hitSpot(forTapAt: CGPoint(x: 70, y: 110), zoom: .wholeField)!
    XCTAssertEqual(FieldDrawing.nearestPosition(to: spot), .leftField)
    XCTAssertTrue((0...1).contains(spot.x) && (0...1).contains(spot.y))
  }
  func testStrikeWordsAreDark() {
    XCTAssertEqual(CountButtonStyle(color: ScorebookColor.strike).textColor, ScorebookColor.onStrike)
    XCTAssertEqual(CountButtonStyle(color: ScorebookColor.ball).textColor, .white)
    XCTAssertEqual(CountButtonStyle.strike.textColor, ScorebookColor.onStrike)
  }
}
