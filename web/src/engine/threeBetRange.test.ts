// Port of the core-logic assertions in PokerKit/Tests/PokerKitTests/ThreeBetRangeTests.swift
// (reasoning-string assertions aren't ported — this app doesn't surface reasoning text for
// 3-bet/4-bet decisions yet).

import { describe, expect, test } from 'vitest'
import { holeCardsFromCanonical } from './holeCards'
import { decideThreeBet, THREE_BET_BLUFF_COMBOS, totalThreeBetPercentage } from './threeBetRange'
import { totalDefensePercentage } from './callingRange'
import { DEFENDING_POSITIONS, defendingActionOrderIndex, positionActionOrderIndex } from './defendingPosition'
import { POSITIONS } from './position'

describe('ThreeBetRange', () => {
  test('invalid position pairings return undefined', () => {
    for (const opener of POSITIONS) {
      expect(totalThreeBetPercentage('UTG', opener, 100)).toBeUndefined()
    }
    expect(totalThreeBetPercentage('CO', 'CO', 100)).toBeUndefined()
    expect(totalThreeBetPercentage('HJ', 'BTN', 100)).toBeUndefined()
    expect(decideThreeBet(holeCardsFromCanonical('AA')!, 'UTG', 'BTN', 100)).toBeUndefined()
  })

  test('BB 3-bet vs BTN matches the sourced anchor (13%)', () => {
    expect(totalThreeBetPercentage('BB', 'BTN', 100)).toBe(13)
  })

  test('AA always 3-bets for value', () => {
    const aa = holeCardsFromCanonical('AA')!
    for (const opener of POSITIONS) {
      for (const defender of DEFENDING_POSITIONS) {
        if (defendingActionOrderIndex(defender) <= positionActionOrderIndex(opener)) continue
        const decision = decideThreeBet(aa, defender, opener, 100)
        expect(decision?.action, `AA should 3-bet for value vs ${opener} from ${defender}`).toBe('threeBetValue')
      }
    }
  })

  test('72o folds', () => {
    const decision = decideThreeBet(holeCardsFromCanonical('72o')!, 'BB', 'UTG', 100)!
    expect(decision.action).toBe('fold')
  })

  test('3-bet total widens against a later opener at the same stack', () => {
    const vsUTG = totalThreeBetPercentage('BB', 'UTG', 100)!
    const vsButton = totalThreeBetPercentage('BB', 'BTN', 100)!
    expect(vsUTG).toBeLessThan(vsButton)
  })

  test('bluff combos are 3-bet bluffs when the stack is deep enough', () => {
    for (const combo of THREE_BET_BLUFF_COMBOS) {
      const hand = holeCardsFromCanonical(combo)!
      const decision = decideThreeBet(hand, 'BB', 'BTN', 100)!
      expect(
        decision.action === 'threeBetBluff' || decision.action === 'threeBetValue',
        `${combo} should be in the 3-bet range (bluff or value) at 100bb`,
      ).toBe(true)
      expect(decision.isBluffCombo).toBe(true)
    }
  })

  test('bluff combos do not apply below 20bb', () => {
    const decision = decideThreeBet(holeCardsFromCanonical('A5s')!, 'BB', 'BTN', 15)!
    expect(decision.isBluffCombo).toBe(false)
  })

  test('3-bet percentage never exceeds total defense', () => {
    for (const opener of POSITIONS) {
      for (const defender of DEFENDING_POSITIONS) {
        if (defendingActionOrderIndex(defender) <= positionActionOrderIndex(opener)) continue
        for (const stack of [20, 40, 100]) {
          const decision = decideThreeBet(holeCardsFromCanonical('AKs')!, defender, opener, stack)!
          expect(decision.threeBetPercentage).toBeLessThanOrEqual(decision.totalDefensePercentage)
        }
      }
    }
  })

  test('value threshold is at least as tight as the call threshold', () => {
    for (const opener of POSITIONS) {
      for (const defender of DEFENDING_POSITIONS) {
        if (defendingActionOrderIndex(defender) <= positionActionOrderIndex(opener)) continue
        const decision = decideThreeBet(holeCardsFromCanonical('AKs')!, defender, opener, 100)!
        expect(decision.valueThreshold).toBeGreaterThanOrEqual(decision.callThreshold)
      }
    }
  })

  test('sanity: totalDefensePercentage is still reachable (reused, not re-derived)', () => {
    expect(totalDefensePercentage('BB', 'BTN', 100)).not.toBeUndefined()
  })
})
