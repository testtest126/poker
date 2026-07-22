import Foundation

/// How fast blind levels increase — orthogonal to prize structure (`GameFormat` itself),
/// since a bounty tournament or a satellite can run at any of these speeds. `nil` on
/// `GameFormatProfile.speed` means "not applicable" (cash games don't have blind levels at
/// all), not "unknown."
public enum TournamentSpeed: String, CaseIterable, Codable, Sendable {
    case regular
    case turbo
    case hyper
}

/// One tournament/cash **format** — a name for a prize/structure shape, not a specific
/// tournament. See `GameFormatProfile` for the actual tuning values, and `ai-docs/FORMATS.md`
/// for the full rationale behind every one of them.
public enum GameFormat: String, CaseIterable, Identifiable, Codable, Sendable {
    case mttRegular
    case mttTurbo
    case mttHyper
    case pko
    case satellite
    case cash

    public var id: String { rawValue }

    public var profile: GameFormatProfile { GameFormatProfile.profiles[self]! }
}

/// A format's tuning parameters — **sensible chosen defaults for the other tools to start
/// from, never a mutation of them.** Nothing in `PushFoldRange`, `OpeningRange`,
/// `CallingRange`, `ThreeBetRange`, `FourBetRange`, `BountyEquity`, or `ICM`/`ICMRiskPremium`
/// reads a `GameFormat` — this is a pure config/seed layer a caller (the app) reads *once*,
/// at format-selection time, to pick starting values for those models' own existing
/// parameters (`effectiveStackBB`, `bountyBB`, whether to show the bounty/ICM UI at all). A
/// user changing a stack slider afterward is unaffected by this layer — it only ever seeds
/// defaults, never clamps or overrides a value the user has set.
///
/// **This is design judgment, not ground-truth math** — unlike `ICM`, there's no worked
/// example to validate these numbers against; unlike `PushFoldRange`/`OpeningRange`, there's
/// no single external source being transcribed. Every value here is this project's own
/// disclosed judgment call about what's *typical* for a format, explained in
/// `ai-docs/FORMATS.md`. Tests in `GameFormatTests.swift` check internal consistency (satellite
/// leans harder on ICM than a regular MTT, hyper starts shallower than regular, etc.) — they
/// cannot and do not claim these numbers are "correct" in the way `ICMTests` can for ICM math.
public struct GameFormatProfile: Sendable {
    public let format: GameFormat
    public let title: String
    public let summary: String

    /// A sensible *starting point* for the effective-stack slider in the range/push-fold
    /// tools — not a claim about any specific tournament's actual stack depth.
    public let defaultStackBB: Double

    /// Whether antes are the sensible default assumption for this format. Doesn't feed any
    /// model directly today (no model in this codebase takes an ante-size parameter yet —
    /// same honestly-disclosed gap `BOUNTY.md` already notes for pot-size inputs); carried
    /// here so a future ante-aware model has a format-level default to read.
    public let anteExpected: Bool

    /// Whether the PKO bounty overlay (`BountyEquity`) should default to **on** for this
    /// format.
    public let bountyEnabled: Bool

    /// Seed value for `BountyEquity.bountyBB(fractionOfStartingStack:startingStackBB:)` when
    /// `bountyEnabled` — `nil` otherwise. `0.33` for `.pko` reuses the exact figure already
    /// used as a worked example in `BountyEquity`'s own doc comment ("50% of the buy-in
    /// funds the bounty pool, worth ~33% of a starting stack") rather than inventing a second,
    /// independent guess at a typical PKO bounty size.
    public let defaultBountyFractionOfStartingStack: Double?

    /// Whether the ICM-aware UI/adjustments (`ICMRiskPremium`) should default to **on** —
    /// `false` only for `.cash`, where chips *are* cash, so there's no tournament equity gap
    /// for ICM to model at all.
    public let icmEnabled: Bool

    /// **Ordinal ICM emphasis, `0...1`** — how much this format's typical payout shape
    /// should lean a calling decision away from chip-EV. This is *not* a coefficient plugged
    /// into `ICMRiskPremium`'s math (that module's own required-equity formula has no such
    /// input) — it's a relative "how much should the UI nudge a user toward caution here"
    /// signal, comparable only to other formats' values, not to any absolute scale. `0` means
    /// `icmEnabled == false` (no ICM at all); everything else is this project's own judgment
    /// call, explained format-by-format in `ai-docs/FORMATS.md`.
    public let icmWeight: Double

    /// `nil` for `.cash` — cash games don't have blind levels, so "speed" doesn't apply.
    public let speed: TournamentSpeed?

    fileprivate static let profiles: [GameFormat: GameFormatProfile] = [
        .mttRegular: GameFormatProfile(
            format: .mttRegular,
            title: "Regular MTT",
            summary: "Standard-speed freezeout tournament — the baseline every other format is compared against.",
            defaultStackBB: 100,
            anteExpected: true,
            bountyEnabled: false,
            defaultBountyFractionOfStartingStack: nil,
            icmEnabled: true,
            icmWeight: 0.5,
            speed: .regular
        ),
        .mttTurbo: GameFormatProfile(
            format: .mttTurbo,
            title: "Turbo MTT",
            summary: "Faster blind increases than a regular MTT — stacks get shallow sooner, so play compresses toward push/fold earlier in the tournament.",
            defaultStackBB: 50,
            anteExpected: true,
            bountyEnabled: false,
            defaultBountyFractionOfStartingStack: nil,
            icmEnabled: true,
            icmWeight: 0.5,
            speed: .turbo
        ),
        .mttHyper: GameFormatProfile(
            format: .mttHyper,
            title: "Hyper-Turbo MTT",
            summary: "Very fast blind increases — effectively push/fold territory from early on.",
            defaultStackBB: 20,
            anteExpected: true,
            bountyEnabled: false,
            defaultBountyFractionOfStartingStack: nil,
            icmEnabled: true,
            icmWeight: 0.5,
            speed: .hyper
        ),
        .pko: GameFormatProfile(
            format: .pko,
            title: "PKO (Bounty)",
            summary: "Progressive knockout — busting a covered opponent wins their bounty on top of the pot.",
            defaultStackBB: 100,
            anteExpected: true,
            bountyEnabled: true,
            defaultBountyFractionOfStartingStack: 0.33,
            icmEnabled: true,
            icmWeight: 0.4,
            speed: .regular
        ),
        .satellite: GameFormatProfile(
            format: .satellite,
            title: "Satellite",
            summary: "Pays out entries to a bigger event rather than cash — every seat pays the same, so min-cash (making the target number of seats) is close to the entire goal.",
            defaultStackBB: 100,
            anteExpected: true,
            bountyEnabled: false,
            defaultBountyFractionOfStartingStack: nil,
            icmEnabled: true,
            icmWeight: 0.9,
            speed: .turbo
        ),
        .cash: GameFormatProfile(
            format: .cash,
            title: "Cash Game",
            summary: "No tournament structure — chips are cash 1:1, so ICM and bounty overlays don't apply.",
            defaultStackBB: 100,
            anteExpected: false,
            bountyEnabled: false,
            defaultBountyFractionOfStartingStack: nil,
            icmEnabled: false,
            icmWeight: 0,
            speed: nil
        ),
    ]
}
