// Port of PokerKit/Tests/PokerKitTests/PushFoldRangeTests.swift.

import { describe, expect, test } from 'vitest'
import { holeCardsFromCanonical } from './holeCards'
import { decidePushFold, rankedCanonicalScores, scoreThreshold, shovePercentage } from './pushFoldRange'
import { POSITIONS } from './position'

describe('PushFoldRange', () => {
  test('AA always shoves', () => {
    const aa = holeCardsFromCanonical('AA')!
    for (const position of POSITIONS) {
      for (const stack of [1, 5, 10, 15, 20]) {
        const decision = decidePushFold(aa, position, stack)
        expect(decision.action, `AA should push from ${position} at ${stack}bb`).toBe('push')
      }
    }
  })

  test('72o folds deep and early (UTG, 20bb)', () => {
    const trash = holeCardsFromCanonical('72o')!
    expect(decidePushFold(trash, 'UTG', 20).action).toBe('fold')
  })

  test('QQ shoves at UTG 15bb', () => {
    const hand = holeCardsFromCanonical('QQ')!
    expect(decidePushFold(hand, 'UTG', 15).action).toBe('push')
  })

  test('widens (never tightens) as the stack shortens', () => {
    const hand = holeCardsFromCanonical('A9s')!
    let lastWasPush = false
    for (let stack = 20; stack >= 1; stack--) {
      const decision = decidePushFold(hand, 'UTG', stack)
      if (lastWasPush) {
        expect(decision.action, `should not tighten at ${stack}bb`).toBe('push')
      }
      lastWasPush = decision.action === 'push'
    }
  })

  test('widens (never tightens) by position, later positions always >= as wide', () => {
    for (const stack of [5, 10, 15, 20]) {
      for (const handString of ['KQo', 'A9s', '88', 'T9s', 'A5s']) {
        const hand = holeCardsFromCanonical(handString)!
        let sawPush = false
        for (const position of POSITIONS) {
          const decision = decidePushFold(hand, position, stack)
          if (sawPush) {
            expect(decision.action, `${handString} should still push from ${position} at ${stack}bb`).toBe('push')
          }
          sawPush = sawPush || decision.action === 'push'
        }
      }
    }
  })

  test('shove percentage interpolates between breakpoints (UTG 10/11/12bb)', () => {
    const at10 = shovePercentage('UTG', 10)
    const at11 = shovePercentage('UTG', 11)
    const at12 = shovePercentage('UTG', 12)
    expect(at12).toBeLessThan(at11)
    expect(at11).toBeLessThan(at10)
  })

  test('shove percentage clamps outside [1, 20]', () => {
    expect(shovePercentage('BTN', 0.2)).toBe(shovePercentage('BTN', 1))
    expect(shovePercentage('BTN', 40)).toBe(shovePercentage('BTN', 20))
  })

  test('ranked canonical scores cover all 169 hands', () => {
    expect(rankedCanonicalScores.length).toBe(169)
  })

  test('score threshold is monotonic with percentage', () => {
    const narrow = scoreThreshold(10)
    const wide = scoreThreshold(50)
    expect(wide).toBeLessThanOrEqual(narrow)
  })

  test('BTN is wider than UTG at the same stack', () => {
    expect(shovePercentage('BTN', 10)).toBeGreaterThan(shovePercentage('UTG', 10))
  })
})
