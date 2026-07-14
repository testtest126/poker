import Testing
@testable import PokerKit

/// A splitmix64-based deterministic generator so distribution/determinism tests get an
/// exact, reproducible sequence instead of depending on `SystemRandomNumberGenerator`.
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

private func deviation(id: String, position: Position, stack: Double, kind: PushFoldDeviation.Kind) -> PushFoldDeviation {
    PushFoldDeviation(
        handId: id,
        position: position,
        effectiveStackBB: stack,
        hand: HoleCards(canonical: "AA")!,
        recommended: kind == .missedShove ? .push : .fold,
        kind: kind
    )
}

private func makeReport(
    deviations: [PushFoldDeviation],
    applicableSpots: Int,
    minPushFoldSpotsForConfidence: Int = 8
) -> LeakReport {
    LeakReport(
        overallTendencies: PreflopTendencies(handsPlayed: 0, vpipCount: 0, pfrCount: 0, openLimpCount: 0),
        overallShowdown: ShowdownStats(handsPlayed: 0, showdownCount: 0, netChips: 0),
        positionStats: [],
        pushFoldAdherence: PushFoldAdherenceReport(
            applicableSpots: applicableSpots,
            matches: applicableSpots - deviations.count,
            deviations: deviations
        ),
        findings: [],
        minHandsForConfidence: 20,
        minPushFoldSpotsForConfidence: minPushFoldSpotsForConfidence
    )
}

// MARK: - focus(from:)

@Test func focusIsNilWithNoApplicableSpots() {
    let report = makeReport(deviations: [], applicableSpots: 0)
    #expect(DrillGenerator.focus(from: report) == nil)
}

@Test func focusIsNilWhenPlayIsClean() {
    // applicableSpots > 0 but no deviations recorded — the user matched the model
    // every time, so there's nothing leaked to weight a drill toward.
    let report = makeReport(deviations: [], applicableSpots: 10)
    #expect(DrillGenerator.focus(from: report) == nil)
}

@Test func focusPicksThePositionWithTheMostDeviations() throws {
    let deviations = [
        deviation(id: "1", position: .cutoff, stack: 10, kind: .missedShove),
        deviation(id: "2", position: .cutoff, stack: 12, kind: .missedShove),
        deviation(id: "3", position: .cutoff, stack: 14, kind: .missedShove),
        deviation(id: "4", position: .utg, stack: 18, kind: .overShove),
    ]
    let report = makeReport(deviations: deviations, applicableSpots: 20)
    let focus = try #require(DrillGenerator.focus(from: report))

    #expect(focus.position == .cutoff)
    #expect(focus.stackRange == 10...14)
    #expect(focus.dominantKind == .missedShove)
    #expect(focus.deviationCount == 3)
}

@Test func dominantKindReflectsTheMajorityWithinTheRegion() throws {
    let deviations = [
        deviation(id: "1", position: .button, stack: 5, kind: .overShove),
        deviation(id: "2", position: .button, stack: 6, kind: .overShove),
        deviation(id: "3", position: .button, stack: 7, kind: .missedShove),
    ]
    let report = makeReport(deviations: deviations, applicableSpots: 20)
    let focus = try #require(DrillGenerator.focus(from: report))
    #expect(focus.dominantKind == .overShove)
}

@Test func tiedDeviationCountsBreakTowardTheLaterPosition() throws {
    // Deterministic tie-break matters: without it, which position wins would depend on
    // Dictionary's non-stable iteration order and the drill's region could change
    // between runs on the exact same imported hands.
    let deviations = [
        deviation(id: "1", position: .utg, stack: 10, kind: .missedShove),
        deviation(id: "2", position: .button, stack: 10, kind: .missedShove),
    ]
    let report = makeReport(deviations: deviations, applicableSpots: 20)
    let focus = try #require(DrillGenerator.focus(from: report))
    #expect(focus.position == .button)
}

@Test func focusIsTentativeBelowTheConfidenceThreshold() throws {
    let deviations = [deviation(id: "1", position: .cutoff, stack: 10, kind: .missedShove)]
    let report = makeReport(deviations: deviations, applicableSpots: 3, minPushFoldSpotsForConfidence: 8)
    let focus = try #require(DrillGenerator.focus(from: report))
    #expect(focus.isTentative == true)
}

@Test func focusIsNotTentativeAtOrAboveTheConfidenceThreshold() throws {
    let deviations = [deviation(id: "1", position: .cutoff, stack: 10, kind: .missedShove)]
    let report = makeReport(deviations: deviations, applicableSpots: 8, minPushFoldSpotsForConfidence: 8)
    let focus = try #require(DrillGenerator.focus(from: report))
    #expect(focus.isTentative == false)
}

// MARK: - explanation

@Test func explanationDescribesTheFocusRegion() {
    let focus = DrillFocus(position: .cutoff, stackRange: 10...14, dominantKind: .missedShove, deviationCount: 3, isTentative: false)
    let text = focus.explanation
    #expect(text.contains("missed shoves"))
    #expect(text.contains("10"))
    #expect(text.contains("14"))
    #expect(text.contains("CO"))
    #expect(!text.contains("tentative"))
}

@Test func explanationFlagsTentativeSamples() {
    let focus = DrillFocus(position: .button, stackRange: 5...5, dominantKind: .overShove, deviationCount: 1, isTentative: true)
    #expect(focus.explanation.contains("tentative"))
    #expect(focus.explanation.contains("5bb")) // single-value ranges read as one number
}

// MARK: - spot(focus:using:)

@Test func spotAlwaysMatchesFocusRegionWhenFocusWeightIsOne() {
    var rng: RandomNumberGenerator = SeededGenerator(seed: 42)
    let focus = DrillFocus(position: .cutoff, stackRange: 10...14, dominantKind: .missedShove, deviationCount: 5, isTentative: false)

    for _ in 0..<200 {
        let spot = DrillGenerator.spot(focus: focus, focusWeight: 1.0, using: &rng)
        #expect(spot.position == .cutoff)
        #expect(focus.stackRange.contains(spot.effectiveStackBB))
    }
}

@Test func spotNeverUsesTheFocusRegionWhenFocusWeightIsZero() {
    var rng: RandomNumberGenerator = SeededGenerator(seed: 3)
    let focus = DrillFocus(position: .cutoff, stackRange: 10...14, dominantKind: .missedShove, deviationCount: 5, isTentative: false)

    var sawOutsideFocus = false
    for _ in 0..<200 {
        let spot = DrillGenerator.spot(focus: focus, focusWeight: 0.0, using: &rng)
        if spot.position != .cutoff || !focus.stackRange.contains(spot.effectiveStackBB) {
            sawOutsideFocus = true
        }
    }
    #expect(sawOutsideFocus)
}

@Test func spotIsFullyRandomWhenFocusIsNil() {
    var rng: RandomNumberGenerator = SeededGenerator(seed: 7)
    var seenPositions = Set<Position>()
    for _ in 0..<200 {
        seenPositions.insert(DrillGenerator.spot(focus: nil, using: &rng).position)
    }
    #expect(seenPositions.count > 1)
}

@Test func sameSeedProducesTheSameSpotSequence() {
    let focus = DrillFocus(position: .button, stackRange: 5...10, dominantKind: .overShove, deviationCount: 2, isTentative: false)
    var rngA: RandomNumberGenerator = SeededGenerator(seed: 99)
    var rngB: RandomNumberGenerator = SeededGenerator(seed: 99)
    let spotsA = (0..<50).map { _ in DrillGenerator.spot(focus: focus, using: &rngA) }
    let spotsB = (0..<50).map { _ in DrillGenerator.spot(focus: focus, using: &rngB) }

    for (a, b) in zip(spotsA, spotsB) {
        #expect(a.position == b.position)
        #expect(a.effectiveStackBB == b.effectiveStackBB)
        #expect(a.hand == b.hand)
    }
}

@Test func focusWeightApproximatesTheRequestedProportion() {
    var rng: RandomNumberGenerator = SeededGenerator(seed: 123)
    let focus = DrillFocus(position: .cutoff, stackRange: 10...14, dominantKind: .missedShove, deviationCount: 5, isTentative: false)

    let total = 2000
    var inFocus = 0
    for _ in 0..<total {
        let spot = DrillGenerator.spot(focus: focus, focusWeight: 0.7, using: &rng)
        if spot.position == .cutoff, focus.stackRange.contains(spot.effectiveStackBB) {
            inFocus += 1
        }
    }
    let fraction = Double(inFocus) / Double(total)
    // A little above 0.7 is expected: fully-random draws can land in the focus region
    // by chance too. Tolerance covers that plus sampling noise.
    #expect(abs(fraction - 0.7) < 0.05)
}
