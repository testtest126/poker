// Port of the core-logic assertions in PokerKit/Tests/PokerKitTests/FourBetRangeTests.swift
// (reasoning-string assertions aren't ported — this app doesn't surface reasoning text for
// 3-bet/4-bet decisions yet).

import { describe, expect, test } from 'vitest'
import { holeCardsFromCanonical } from './holeCards'
import { decideFourBet, totalContinuePercentage } from './fourBetRange'
import { THREE_BET_BLUFF_COMBOS } from './threeBetRange'
import { decideOpening } from './openingRange'
import { DEFENDING_POSITIONS, defendingActionOrderIndex, positionActionOrderIndex } from './defendingPosition'
import { POSITIONS } from './position'

describe('FourBetRange', () => {
  test('invalid position pairings return undefined', () => {
    for (const opener of POSITIONS) {
      expect(totalContinuePercentage(opener, 'UTG', 100)).toBeUndefined()
    }
    expect(totalContinuePercentage('CO', 'CO', 100)).toBeUndefined()
    expect(decideFourBet(holeCardsFromCanonical('AA')!, 'BTN', 'UTG', 100)).toBeUndefined()
  })

  test('cutoff vs button 3-bet matches the sourced anchor (67% continue, 17% 4-bet)', () => {
    const totalContinue = totalContinuePercentage('CO', 'BTN', 100)!
    expect(Math.abs(totalContinue - 67)).toBeLessThan(0.01)

    const decision = decideFourBet(holeCardsFromCanonical('AA')!, 'CO', 'BTN', 100)!
    const expectedFourBetPercentage = 67 * (17 / 67)
    expect(Math.abs(decision.fourBetPercentage - expectedFourBetPercentage)).toBeLessThan(0.01)
  })

  test('AA always 4-bets for value', () => {
    const aa = holeCardsFromCanonical('AA')!
    for (const opener of POSITIONS) {
      for (const threeBettor of DEFENDING_POSITIONS) {
        if (defendingActionOrderIndex(threeBettor) <= positionActionOrderIndex(opener)) continue
        const decision = decideFourBet(aa, opener, threeBettor, 100)
        expect(decision?.action, `AA should 4-bet for value vs a 3-bet from ${threeBettor} after opening ${opener}`).toBe(
          'fourBetValue',
        )
      }
    }
  })

  test('72o folds', () => {
    const decision = decideFourBet(holeCardsFromCanonical('72o')!, 'UTG', 'BB', 100)!
    expect(decision.action).toBe('fold')
  })

  test('total continue widens against a narrower 3-bet (UTG open < BTN open)', () => {
    const vsUTGOpen = totalContinuePercentage('UTG', 'BB', 100)!
    const vsButtonOpen = totalContinuePercentage('BTN', 'BB', 100)!
    expect(vsUTGOpen, 'Facing a 3-bet should be scarier after opening UTG than BTN').toBeLessThan(vsButtonOpen)
  })

  test('every bluff combo flagged isBluffCombo would also have been opened', () => {
    for (const combo of THREE_BET_BLUFF_COMBOS) {
      const hand = holeCardsFromCanonical(combo)!
      for (const opener of POSITIONS) {
        for (const threeBettor of DEFENDING_POSITIONS) {
          if (defendingActionOrderIndex(threeBettor) <= positionActionOrderIndex(opener)) continue
          const decision = decideFourBet(hand, opener, threeBettor, 100)
          if (!decision) continue
          if (decision.isBluffCombo) {
            const wouldHaveOpened = decideOpening(hand, opener, 100).action === 'raise'
            expect(wouldHaveOpened, `${combo} flagged as a 4-bet bluff from ${opener} but wouldn't have been opened there`).toBe(
              true,
            )
          }
        }
      }
    }
  })

  test('bluff combos do not apply below 40bb', () => {
    const decision = decideFourBet(holeCardsFromCanonical('A5s')!, 'BTN', 'BB', 25)!
    expect(decision.isBluffCombo).toBe(false)
  })

  test('value threshold is at least as tight as the call threshold', () => {
    for (const opener of POSITIONS) {
      for (const threeBettor of DEFENDING_POSITIONS) {
        if (defendingActionOrderIndex(threeBettor) <= positionActionOrderIndex(opener)) continue
        const decision = decideFourBet(holeCardsFromCanonical('AKs')!, opener, threeBettor, 100)!
        expect(decision.valueThreshold).toBeGreaterThanOrEqual(decision.callThreshold)
      }
    }
  })
})
