import Foundation
import Testing
@testable import PokerKit

@Test func formatListIsExhaustiveAndStable() {
    let expected: Set<GameFormat> = [.mttRegular, .mttTurbo, .mttHyper, .pko, .satellite, .cash]
    #expect(Set(GameFormat.allCases) == expected)
    #expect(GameFormat.allCases.count == 6)
}

@Test func everyFormatRoundTripsThroughRawValue() {
    for format in GameFormat.allCases {
        #expect(GameFormat(rawValue: format.rawValue) == format)
    }
}

@Test func everyFormatRoundTripsThroughCodable() throws {
    for format in GameFormat.allCases {
        let encoded = try JSONEncoder().encode(format)
        let decoded = try JSONDecoder().decode(GameFormat.self, from: encoded)
        #expect(decoded == format)
    }
}

@Test func everyFormatHasAProfileMatchingItsOwnCase() {
    for format in GameFormat.allCases {
        #expect(format.profile.format == format)
    }
}

@Test func pkoIsTheOnlyFormatWithBountyEnabledByDefault() {
    for format in GameFormat.allCases {
        #expect(format.profile.bountyEnabled == (format == .pko), "\(format) bountyEnabled should be \(format == .pko)")
    }
}

@Test func cashHasNeitherICMNorBountyByDefault() {
    let cash = GameFormat.cash.profile
    #expect(cash.icmEnabled == false)
    #expect(cash.bountyEnabled == false)
    #expect(cash.icmWeight == 0)
}

@Test func everyNonCashFormatHasICMEnabled() {
    for format in GameFormat.allCases where format != .cash {
        #expect(format.profile.icmEnabled, "\(format) should default to ICM-aware — only cash has no tournament equity to model")
    }
}

@Test func satelliteLeansHardestOnICMOfEveryFormat() {
    let satelliteWeight = GameFormat.satellite.profile.icmWeight
    for format in GameFormat.allCases where format != .satellite {
        #expect(satelliteWeight > format.profile.icmWeight, "Satellite should lean harder on ICM than \(format) — min-cash is close to the entire goal")
    }
}

@Test func pkoLeansLessOnICMThanRegularMTT() {
    // Disclosed judgment call (see ai-docs/FORMATS.md): PKO bounties incentivize looser,
    // more gamble-friendly play, partially offsetting ICM's tightening pressure relative to
    // a same-sized regular freezeout.
    #expect(GameFormat.pko.profile.icmWeight < GameFormat.mttRegular.profile.icmWeight)
}

@Test func defaultStackDepthShrinksAsSpeedIncreases() {
    let regular = GameFormat.mttRegular.profile.defaultStackBB
    let turbo = GameFormat.mttTurbo.profile.defaultStackBB
    let hyper = GameFormat.mttHyper.profile.defaultStackBB
    #expect(hyper < turbo)
    #expect(turbo < regular)
}

@Test func everyICMWeightIsWithinTheDocumentedZeroToOneRange() {
    for format in GameFormat.allCases {
        let weight = format.profile.icmWeight
        #expect(weight >= 0 && weight <= 1, "\(format) icmWeight \(weight) is outside the documented 0...1 range")
    }
}

@Test func bountyFractionIsSetIfAndOnlyIfBountyIsEnabled() {
    for format in GameFormat.allCases {
        let profile = format.profile
        #expect((profile.defaultBountyFractionOfStartingStack != nil) == profile.bountyEnabled, "\(format): defaultBountyFractionOfStartingStack should be set exactly when bountyEnabled is true")
    }
}

@Test func speedIsNilOnlyForCash() {
    for format in GameFormat.allCases {
        #expect((format.profile.speed == nil) == (format == .cash), "\(format) speed-nil-ness should match whether it's .cash")
    }
}

@Test func everyFormatHasAPositiveDefaultStack() {
    for format in GameFormat.allCases {
        #expect(format.profile.defaultStackBB > 0)
    }
}

@Test func pkoBountyFractionMatchesBountyEquitysOwnWorkedExample() {
    // Reuses (doesn't re-derive) the exact figure from BountyEquity's own doc comment — see
    // GameFormat.swift's rationale.
    #expect(GameFormat.pko.profile.defaultBountyFractionOfStartingStack == 0.33)
}
