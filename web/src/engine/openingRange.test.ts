// Port of PokerKit/Tests/PokerKitTests/OpeningRangeTests.swift.

import { describe, expect, test } from 'vitest'
import { holeCardsFromCanonical } from './holeCards'
import { decideOpening, openingReasoning, openPercentage } from './openingRange'
import { POSITIONS } from './position'

describe('OpeningRange', () => {
  test('AA always opens', () => {
    const aa = holeCardsFromCanonical('AA')!
    for (const position of POSITIONS) {
      for (const stack of [20, 40, 60, 100]) {
        const decision = decideOpening(aa, position, stack)
        expect(decision.action, `AA should open from ${position} at ${stack}bb`).toBe('raise')
      }
    }
  })

  test('72o folds deep and early (UTG, 100bb)', () => {
    const trash = holeCardsFromCanonical('72o')!
    expect(decideOpening(trash, 'UTG', 100).action).toBe('fold')
  })

  test('widens (never tightens) as the stack shortens', () => {
    const hand = holeCardsFromCanonical('A9s')!
    let lastWasOpen = false
    for (let stack = 100; stack >= 20; stack -= 5) {
      const decision = decideOpening(hand, 'UTG', stack)
      if (lastWasOpen) {
        expect(decision.action, `should not tighten at ${stack}bb`).toBe('raise')
      }
      lastWasOpen = decision.action === 'raise'
    }
  })

  test('widens (never tightens) by position, later positions always >= as wide', () => {
    for (const stack of [20, 40, 60, 100]) {
      for (const handString of ['KQo', 'A9s', '88', 'T9s', 'A5s']) {
        const hand = holeCardsFromCanonical(handString)!
        let sawOpen = false
        for (const position of POSITIONS) {
          const decision = decideOpening(hand, position, stack)
          if (sawOpen) {
            expect(decision.action, `${handString} should still open from ${position} at ${stack}bb`).toBe('raise')
          }
          sawOpen = sawOpen || decision.action === 'raise'
        }
      }
    }
  })

  test('open percentage interpolates between breakpoints (UTG 20/30/40bb)', () => {
    const at20 = openPercentage('UTG', 20)
    const at30 = openPercentage('UTG', 30)
    const at40 = openPercentage('UTG', 40)
    expect(at40).toBeLessThan(at30)
    expect(at30).toBeLessThan(at20)
  })

  test('open percentage clamps outside [20, 100]', () => {
    expect(openPercentage('BTN', 5)).toBe(openPercentage('BTN', 20))
    expect(openPercentage('BTN', 200)).toBe(openPercentage('BTN', 100))
  })

  test('BTN is wider than UTG at the same stack', () => {
    expect(openPercentage('BTN', 100)).toBeGreaterThan(openPercentage('UTG', 100))
  })

  test('SB is wider than BTN at the same stack (deliberately tightened below its cited source — see ai-docs/RANGES.md)', () => {
    for (const stack of [20, 40, 100]) {
      expect(openPercentage('SB', stack), `SB should open wider than BTN at ${stack}bb`).toBeGreaterThan(
        openPercentage('BTN', stack),
      )
    }
  })

  test('reasoning mentions the open-raise threshold', () => {
    const decision = decideOpening(holeCardsFromCanonical('AA')!, 'UTG', 100)
    expect(openingReasoning(decision)).toContain('open-raise threshold')
  })
})
