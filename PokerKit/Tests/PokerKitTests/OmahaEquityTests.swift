import Testing
@testable import PokerKit

// MARK: - Exact, hand-verifiable (no citation needed)

@Test func heroWithLockedQuadsWinsWithCertaintyOnACompleteBoard() {
    // A fully deterministic, hand-checkable spot: the board already shows two sevens
    // (7d, 7c); hero holds the other two (7s, 7h). Hero's best legal hand is 2 hole sevens
    // + board's 2 sevens + 1 more board card = quad sevens — villain holds no sevens at
    // all, so the best villain can ever reach using the board's pair is a plain pair of
    // sevens. With the board fully specified (needed == 0), `headsUp` runs exactly one
    // trial — an exact result, not a sampled one.
    let hero = OmahaHoleCards(canonical: "7s7h2c3d")!
    let villain = OmahaHoleCards(canonical: "2h3h4d5d")!
    let board = [
        Card(notation: "7d")!, Card(notation: "7c")!, Card(notation: "As")!,
        Card(notation: "Kd")!, Card(notation: "Qh")!,
    ]

    let result = OmahaEquity.headsUp(hero: hero, villain: villain, board: board)
    #expect(result.trials == 1)
    #expect(result.isExact)
    #expect(result.winRate == 1.0)
    #expect(result.tieRate == 0.0)
    #expect(result.loseRate == 0.0)
}

@Test func mirroredSuitHandsOnASuitNeutralBoardTieWithCertainty() {
    // Hero and villain hold the identical 4 ranks (A,K,Q,J), just in different suits
    // (spades vs. hearts) — and the board has zero spades and zero hearts. Neither side can
    // ever complete a flush (at most 2 of their own suit + 0 from the board), so every legal
    // 5-card combination either side can form has an exact same-category, same-tiebreaker
    // mirror on the other side. This is a tie by symmetry, not by coincidence — a stronger,
    // more specific claim than merely "equal win rates," and one that holds with certainty
    // on every one of the (in this case, exactly 1, since the board is fully specified)
    // trials.
    let hero = OmahaHoleCards(canonical: "AsKsQsJs")!
    let villain = OmahaHoleCards(canonical: "AhKhQhJh")!
    let board = [
        Card(notation: "2c")!, Card(notation: "3c")!, Card(notation: "4d")!,
        Card(notation: "5d")!, Card(notation: "6d")!,
    ]

    let result = OmahaEquity.headsUp(hero: hero, villain: villain, board: board)
    #expect(result.trials == 1)
    #expect(result.winRate == 0.0)
    #expect(result.tieRate == 1.0)
    #expect(result.loseRate == 0.0)
}

@Test func equityAlwaysSumsToOne() {
    let hero = OmahaHoleCards(canonical: "AsAhKdKc")!
    let villain = OmahaHoleCards(canonical: "9s8s7h6h")!
    let result = OmahaEquity.monteCarlo(hero: [hero], villain: [villain], iterations: 5_000)
    #expect(abs((result.winRate + result.tieRate + result.loseRate) - 1.0) < 1e-9)
}

@Test func omahaMonteCarloIsDeterministicForAFixedSeed() {
    let hero = OmahaHoleCards(canonical: "AsAhKdKc")!
    let villain = OmahaHoleCards(canonical: "QsQhJdJc")!
    let first = OmahaEquity.monteCarlo(hero: [hero], villain: [villain], iterations: 5_000, seed: 777)
    let second = OmahaEquity.monteCarlo(hero: [hero], villain: [villain], iterations: 5_000, seed: 777)
    #expect(first.winRate == second.winRate)
    #expect(first.trials == second.trials)
}

// MARK: - Validated against published guidance (loose tolerance — see ai-docs/OMAHA.md)

@Test func aacesKingsDoubleSuitedIsOnlyAModestFavoriteOverATopRundown() {
    // Published guidance (see ai-docs/OMAHA.md for sourcing and why the tolerance here is
    // wide): AAKK double-suited is commonly described across multiple PLO strategy sources
    // as "only a 3-2 favorite" (~60%) over a strong double-suited rundown like 8-7-6-5 —
    // illustrating how much closer Omaha equities run than Hold'em's. No single source gave
    // an exact decimal or fully specified which of 8765's two suit-pairing options they
    // used, so this checks a wide, but still meaningful, band around 60% rather than a tight
    // percentage — see OMAHA.md before trusting the exact bound.
    let aakk = OmahaHoleCards(canonical: "AsKsAhKh")!
    let rundown = OmahaHoleCards(canonical: "8s7s6h5h")!

    let result = OmahaEquity.monteCarlo(hero: [aakk], villain: [rundown], iterations: 50_000)
    #expect(result.winRate > 0.52 && result.winRate < 0.68, "AAKKds vs 8765ds should be a modest favorite (~60%, 'only a 3-2 favorite' per multiple sources), got \(result.winRate)")
}

@Test func aacesKingsBeatsAWeakRandomHandMoreConvincinglyThanATopRundown() {
    // An internal-consistency check needing no citation: AAKK should be a clearly bigger
    // favorite over unconnected junk than over one of Omaha's strongest hand shapes (a
    // well-suited rundown) — the model should at least get the *direction* of "which
    // opponent is tougher" right, independent of the exact published number's precision.
    let aakk = OmahaHoleCards(canonical: "AsKsAhKh")!
    let rundown = OmahaHoleCards(canonical: "8s7s6h5h")!
    let junk = OmahaHoleCards(canonical: "7c2d9h3s")!

    let vsRundown = OmahaEquity.monteCarlo(hero: [aakk], villain: [rundown], iterations: 50_000)
    let vsJunk = OmahaEquity.monteCarlo(hero: [aakk], villain: [junk], iterations: 50_000)
    #expect(vsJunk.winRate > vsRundown.winRate, "AAKK should run better against unconnected junk than against a premium rundown")
}
