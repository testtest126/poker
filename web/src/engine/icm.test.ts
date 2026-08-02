// Port of PokerKit/Tests/PokerKitTests/ICMTests.swift — same worked examples, same exact
// fractions, same tolerance. See ai-docs/ICM.md for the full by-hand derivation of the
// Wikipedia worked example these fractions come from.

import { describe, expect, test } from 'vitest'
import { icmEquities } from './icm'
import { assessICMRisk } from './icmRiskPremium'

describe('ICM equities', () => {
  test('equal stacks split equally regardless of player count', () => {
    for (let n = 2; n <= 6; n++) {
      const stacks = new Array(n).fill(1000)
      const payouts = [500, 300, 200, 100, 50, 25]
      const equities = icmEquities(stacks, payouts)
      const expectedEach = payouts.slice(0, Math.min(payouts.length, n)).reduce((a, b) => a + b, 0) / n
      for (const equity of equities) {
        expect(Math.abs(equity - expectedEach)).toBeLessThan(1e-9)
      }
    }
  })

  test('two-player equity matches the exact closed form', () => {
    const a = 6000
    const b = 4000
    const payouts = [100, 50]
    const equities = icmEquities([a, b], payouts)
    const expectedA = (a / (a + b)) * payouts[0] + (b / (a + b)) * payouts[1]
    const expectedB = (b / (a + b)) * payouts[0] + (a / (a + b)) * payouts[1]
    expect(Math.abs(equities[0] - expectedA)).toBeLessThan(1e-9)
    expect(Math.abs(equities[1] - expectedB)).toBeLessThan(1e-9)
    expect(Math.abs(equities[0] + equities[1] - (payouts[0] + payouts[1]))).toBeLessThan(1e-9)
  })

  test('three-handed worked example matches the published Wikipedia ICM article', () => {
    // Stacks 50/30/20, payouts 70(1st)/30(2nd) — see ai-docs/ICM.md for the citation and
    // the full by-hand re-derivation of the exact fractions below.
    const stacks = [50, 30, 20]
    const payouts = [70, 30]
    const equities = icmEquities(stacks, payouts)

    // Within the source's own rounding (it publishes to the nearest dollar with "≈").
    expect(Math.abs(equities[0] - 45)).toBeLessThan(0.5)
    expect(Math.abs(equities[1] - 32)).toBeLessThan(0.5)
    expect(Math.abs(equities[2] - 22)).toBeLessThan(0.6)

    // Tight tolerance against the exact fractions independently re-derived by hand.
    expect(Math.abs(equities[0] - 1265 / 28)).toBeLessThan(1e-9)
    expect(Math.abs(equities[1] - 129 / 4)).toBeLessThan(1e-9)
    expect(Math.abs(equities[2] - 158 / 7)).toBeLessThan(1e-9)
    expect(Math.abs(equities.reduce((a, b) => a + b, 0) - 100)).toBeLessThan(1e-9)
  })

  test('three-handed worked example with three paid places matches hand-derived fractions', () => {
    const stacks = [5000, 3000, 2000]
    const payouts = [500, 300, 200]
    const equities = icmEquities(stacks, payouts)
    expect(Math.abs(equities[0] - 5375 / 14)).toBeLessThan(1e-9)
    expect(Math.abs(equities[1] - 655 / 2)).toBeLessThan(1e-9)
    expect(Math.abs(equities[2] - 2020 / 7)).toBeLessThan(1e-9)
    expect(Math.abs(equities.reduce((a, b) => a + b, 0) - 1000)).toBeLessThan(1e-9)
  })

  test('the chip leader is worth less per chip than the short stack (the ICM tax)', () => {
    const stacks = [5000, 3000, 2000]
    const payouts = [500, 300, 200]
    const equities = icmEquities(stacks, payouts)
    const chipLeaderPerChip = equities[0] / stacks[0]
    const shortStackPerChip = equities[2] / stacks[2]
    expect(
      chipLeaderPerChip,
      'A top-heavy payout structure should make the chip leader marginal chip worth less than the short stack',
    ).toBeLessThan(shortStackPerChip)
  })

  test('total equity always equals the total prize pool across varied fields', () => {
    const cases: { stacks: number[]; payouts: number[] }[] = [
      { stacks: [100, 100, 100, 100], payouts: [40, 30, 20, 10] },
      { stacks: [1, 2, 3, 4, 5], payouts: [50, 30, 20] },
      { stacks: [9000, 500, 300, 200], payouts: [60, 25, 15] },
      { stacks: [17, 33], payouts: [70, 30] },
    ]
    for (const c of cases) {
      const equities = icmEquities(c.stacks, c.payouts)
      const expectedTotal = c.payouts.slice(0, c.stacks.length).reduce((a, b) => a + b, 0)
      expect(Math.abs(equities.reduce((a, b) => a + b, 0) - expectedTotal)).toBeLessThan(1e-6)
    }
  })

  test('a single player gets the first-place payout with certainty', () => {
    const equities = icmEquities([12345], [500, 300, 200])
    expect(Math.abs(equities[0] - 500)).toBeLessThan(1e-9)
  })
})

describe('ICM risk premium', () => {
  test('chip-EV breakeven is 50% for equal stacks heads-up', () => {
    const assessment = assessICMRisk(1000, 1000, [], [100])
    expect(Math.abs(assessment.chipEVRequiredEquity - 0.5)).toBeLessThan(1e-9)
  })

  test('chip-EV breakeven favors the shorter stack', () => {
    const shortCalling = assessICMRisk(1000, 4000, [], [100])
    expect(shortCalling.chipEVRequiredEquity).toBeLessThan(0.5)

    const bigCalling = assessICMRisk(4000, 1000, [], [100])
    expect(bigCalling.chipEVRequiredEquity).toBeGreaterThan(0.5)
  })

  test('ICM-required equity exceeds chip-EV near a bubble with other short stacks alive', () => {
    const assessment = assessICMRisk(5000, 5000, [1000, 1000], [50, 30, 15, 5])
    expect(assessment.icmRequiredEquity).toBeGreaterThan(assessment.chipEVRequiredEquity)
    expect(assessment.riskPremium).toBeGreaterThan(0)
  })

  test('ICM-required equity is unaffected when nothing is at stake beyond the confrontation', () => {
    const assessment = assessICMRisk(3000, 7000, [], [100])
    expect(Math.abs(assessment.icmRequiredEquity - assessment.chipEVRequiredEquity)).toBeLessThan(1e-9)
  })

  test('win and lose equity bracket the fold equity', () => {
    const assessment = assessICMRisk(4000, 2000, [3000, 1000], [50, 30, 20])
    expect(assessment.loseEquity).toBeLessThan(assessment.foldEquity)
    expect(assessment.foldEquity).toBeLessThan(assessment.winEquity)
  })
})
