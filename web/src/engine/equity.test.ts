// Port of the ground-truth checks in PokerKit/Tests/PokerKitTests/EquityTests.swift — same
// cited figures (cardfight.com's published preflop equity pages, fetched while building
// the Swift feature — see ai-docs/EQUITY.md), checked against this independent TypeScript
// implementation. Iteration count and tolerance are wider than the Swift suite's (100,000
// iterations, ±1%) — this port uses a different, faster-but-still-deterministic PRNG (see
// equity.ts's header comment) at a lower iteration count better suited to a JS test runner,
// so the tolerance is opened up slightly (±2%) to match. Deliberately NOT porting the Swift
// suite's flagship *preflop* exact-enumeration test (`C(48,5) = 1,712,304` boards) — the
// engine itself never calls `headsUp` preflop for the same tractability reason the Swift
// source documents, so there's nothing this app needs that computation to prove; the exact
// path is instead checked below with a fast, hand-verifiable postflop case.

import { describe, expect, test } from 'vitest'
import { canonicalVsCanonical, headsUp } from './equity'
import { holeCardsFromCanonical } from './holeCards'

const groundTruthIterations = 20_000
const tolerance = 2.0

function assertApproximately(actual: number, expectedPercent: number, tol = tolerance) {
  const actualPercent = actual * 100
  expect(
    Math.abs(actualPercent - expectedPercent),
    `expected ${expectedPercent}% ± ${tol}%, got ${actualPercent.toFixed(2)}%`,
  ).toBeLessThanOrEqual(tol)
}

describe('ground-truth validation (cardfight.com)', () => {
  test('AA vs KK — cited AA 81.71% / KK 17.82%', () => {
    const result = canonicalVsCanonical('AA', 'KK', [], groundTruthIterations)
    assertApproximately(result.winRate, 81.71)
    assertApproximately(result.loseRate, 17.82)
  })

  test('AKs vs QQ — cited QQ 53.73% / AKs 45.83%', () => {
    const result = canonicalVsCanonical('AKs', 'QQ', [], groundTruthIterations)
    assertApproximately(result.winRate, 45.83)
    assertApproximately(result.loseRate, 53.73)
  })

  test('AKo vs 22 — cited 22 52.34% / AKo 47.04% (the classic "coinflip," not literally 50/50)', () => {
    const result = canonicalVsCanonical('AKo', '22', [], groundTruthIterations)
    assertApproximately(result.winRate, 47.04)
    assertApproximately(result.loseRate, 52.34)
  })

  test('AA vs 72o — cited AA 87.99% / 72o 11.59%', () => {
    const result = canonicalVsCanonical('AA', '72o', [], groundTruthIterations)
    assertApproximately(result.winRate, 87.99)
    assertApproximately(result.loseRate, 11.59)
  })

  test('QQ vs JTs (overpair vs. suited connector) — cited QQ 81.47% / JTs 18.13%', () => {
    const result = canonicalVsCanonical('QQ', 'JTs', [], groundTruthIterations)
    assertApproximately(result.winRate, 81.47)
    assertApproximately(result.loseRate, 18.13)
  })
})

describe('exact enumeration (headsUp)', () => {
  test('a locked board (quad twos + the Ace kicker) ties every hand that does not improve it', () => {
    // Board already has quad twos *and* the Ace kicker — the best possible 5-card hand is
    // "quad twos, Ace kicker" using the board alone, and since Ace is the maximum rank, no
    // hole card combination can ever beat that kicker (only tie it, by being irrelevant).
    // This must be an exact, provable tie regardless of either player's hole cards, as long
    // as neither holds a second Two (impossible — the board already has all four). Zero
    // completions needed (river given) — instant.
    const hero = holeCardsFromCanonical('KQo')! // random cards, strictly below the board's Ace kicker
    const villain = holeCardsFromCanonical('JTo')! // likewise
    const board = [
      { rank: 2 as const, suit: 'spades' as const },
      { rank: 2 as const, suit: 'hearts' as const },
      { rank: 2 as const, suit: 'diamonds' as const },
      { rank: 2 as const, suit: 'clubs' as const },
      { rank: 14 as const, suit: 'hearts' as const },
    ]
    const result = headsUp(hero, villain, board)
    expect(result.isExact).toBe(true)
    expect(result.trials).toBe(1)
    expect(result.tieRate).toBe(1)
  })

  test('a dominated hand with no outs on the river loses with certainty', () => {
    const heroExact = { first: { rank: 14 as const, suit: 'spades' as const }, second: { rank: 13 as const, suit: 'spades' as const } }
    const villainExact = { first: { rank: 14 as const, suit: 'hearts' as const }, second: { rank: 14 as const, suit: 'diamonds' as const } }
    const board = [
      { rank: 2 as const, suit: 'clubs' as const },
      { rank: 7 as const, suit: 'diamonds' as const },
      { rank: 9 as const, suit: 'hearts' as const },
      { rank: 11 as const, suit: 'clubs' as const },
      { rank: 3 as const, suit: 'spades' as const },
    ]
    // Hero: ace-king high. Villain: trip aces. No board pairing helps hero catch up.
    const result = headsUp(heroExact, villainExact, board)
    expect(result.isExact).toBe(true)
    expect(result.trials).toBe(1)
    expect(result.loseRate).toBe(1)
  })
})
