import Foundation

/// A single push/fold drill spot: hero's hand, position, and effective stack.
public struct PushFoldSpot: Sendable {
    public let hand: HoleCards
    public let position: Position
    public let effectiveStackBB: Int

    public init(hand: HoleCards, position: Position, effectiveStackBB: Int) {
        self.hand = hand
        self.position = position
        self.effectiveStackBB = effectiveStackBB
    }

    public var decision: PushFoldDecision {
        PushFoldRange.decide(hand: hand, position: position, effectiveStackBB: Double(effectiveStackBB))
    }

    public static func random(using generator: inout RandomNumberGenerator) -> PushFoldSpot {
        PushFoldSpot(
            hand: .random(using: &generator),
            position: Position.allCases.randomElement(using: &generator)!,
            effectiveStackBB: Int.random(in: 1...20, using: &generator)
        )
    }

    public static func random() -> PushFoldSpot {
        var rng: RandomNumberGenerator = SystemRandomNumberGenerator()
        return random(using: &rng)
    }
}
