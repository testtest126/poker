// Port of PokerKit/Tests/PokerKitTests/CallingRangeTests.swift.

import { describe, expect, test } from 'vitest'
import { holeCardsFromCanonical } from './holeCards'
import { callPercentage, decideVsOpen, decideVsShove, totalDefensePercentage, type OpenDefenseAction } from './callingRange'
import { DEFENDING_POSITIONS, defendingActionOrderIndex, positionActionOrderIndex } from './defendingPosition'
import { POSITIONS } from './position'

describe('facing a shove', () => {
  test('AA always calls a shove', () => {
    const aa = holeCardsFromCanonical('AA')!
    for (const shover of POSITIONS) {
      for (const caller of DEFENDING_POSITIONS) {
        if (defendingActionOrderIndex(caller) <= positionActionOrderIndex(shover)) continue
        for (const stack of [1, 5, 10, 15, 20]) {
          const decision = decideVsShove(aa, caller, shover, stack)
          expect(decision?.action, `AA should call ${shover}'s shove from ${caller} at ${stack}bb`).toBe('call')
        }
      }
    }
  })

  test('72o folds to a UTG shove deep and early', () => {
    const trash = holeCardsFromCanonical('72o')!
    for (const caller of DEFENDING_POSITIONS) {
      if (defendingActionOrderIndex(caller) <= positionActionOrderIndex('UTG')) continue
      const decision = decideVsShove(trash, caller, 'UTG', 20)
      expect(decision?.action, `72o should fold to a UTG shove from ${caller} at 20bb`).toBe('fold')
    }
  })

  test('invalid position pairings return undefined', () => {
    for (const shover of POSITIONS) {
      expect(callPercentage('UTG', shover, 10)).toBeUndefined()
      expect(decideVsShove(holeCardsFromCanonical('AA')!, 'UTG', shover, 10)).toBeUndefined()
    }
    expect(callPercentage('SB', 'SB', 10)).toBeUndefined()
    expect(callPercentage('HJ', 'BTN', 10)).toBeUndefined()
  })

  test('big blind can face a shove from every position', () => {
    for (const shover of POSITIONS) {
      expect(callPercentage('BB', shover, 10)).not.toBeUndefined()
    }
  })

  test('call widens (never tightens) as the stack shortens', () => {
    const hand = holeCardsFromCanonical('A9s')!
    let lastWasCall = false
    for (let stack = 20; stack >= 1; stack--) {
      const decision = decideVsShove(hand, 'BB', 'UTG', stack)!
      if (lastWasCall) {
        expect(decision.action, `should not tighten at ${stack}bb`).toBe('call')
      }
      lastWasCall = decision.action === 'call'
    }
  })

  test('call is tighter against an earlier shover at the same stack', () => {
    const utgPct = callPercentage('BB', 'UTG', 10)!
    const sbPct = callPercentage('BB', 'SB', 10)!
    expect(utgPct).toBeLessThan(sbPct)
  })

  test('BB calls wider than SB against the same shove', () => {
    for (const shover of ['UTG', 'HJ', 'BTN'] as const) {
      const bbPct = callPercentage('BB', shover, 10)!
      const sbPct = callPercentage('SB', shover, 10)!
      expect(bbPct, `BB should call wider than SB against a ${shover} shove`).toBeGreaterThan(sbPct)
    }
  })

  test('a suited hand never loses to its offsuit counterpart', () => {
    for (const [offsuit, suited] of [
      ['A9o', 'A9s'],
      ['KJo', 'KJs'],
      ['T8o', 'T8s'],
      ['76o', '76s'],
    ]) {
      const offsuitDecision = decideVsShove(holeCardsFromCanonical(offsuit)!, 'BB', 'CO', 12)!
      const suitedDecision = decideVsShove(holeCardsFromCanonical(suited)!, 'BB', 'CO', 12)!
      if (offsuitDecision.action === 'call') {
        expect(suitedDecision.action, `${suited} should call whenever ${offsuit} calls`).toBe('call')
      }
    }
  })
})

describe('facing an open', () => {
  test('AA always 3-bets an open', () => {
    const aa = holeCardsFromCanonical('AA')!
    for (const opener of POSITIONS) {
      for (const defender of DEFENDING_POSITIONS) {
        if (defendingActionOrderIndex(defender) <= positionActionOrderIndex(opener)) continue
        const decision = decideVsOpen(aa, defender, opener, 40)
        expect(decision?.action, `AA should 3-bet ${opener}'s open from ${defender}`).toBe('threeBet')
      }
    }
  })

  test('72o folds to an open from early position', () => {
    const trash = holeCardsFromCanonical('72o')!
    expect(decideVsOpen(trash, 'BB', 'UTG', 100)!.action).toBe('fold')
  })

  test('invalid position pairings return undefined', () => {
    for (const opener of POSITIONS) {
      expect(totalDefensePercentage('UTG', opener, 40)).toBeUndefined()
    }
    expect(totalDefensePercentage('CO', 'CO', 40)).toBeUndefined()
    expect(totalDefensePercentage('HJ', 'BTN', 40)).toBeUndefined()
  })

  test('big blind can face an open from every position', () => {
    for (const opener of POSITIONS) {
      expect(totalDefensePercentage('BB', opener, 40)).not.toBeUndefined()
    }
  })

  test('defense widens against a later opener at the same stack', () => {
    const vsUTG = totalDefensePercentage('BB', 'UTG', 40)!
    const vsButton = totalDefensePercentage('BB', 'BTN', 40)!
    expect(vsUTG).toBeLessThan(vsButton)
  })

  test('BB defends wider than SB against the same open', () => {
    for (const opener of ['UTG', 'HJ', 'BTN'] as const) {
      const bbPct = totalDefensePercentage('BB', opener, 40)!
      const sbPct = totalDefensePercentage('SB', opener, 40)!
      expect(bbPct, `BB should defend wider than SB against a ${opener} open`).toBeGreaterThan(sbPct)
    }
  })

  test('3-bet threshold is at least as tight as the call threshold', () => {
    for (const opener of POSITIONS) {
      for (const defender of DEFENDING_POSITIONS) {
        if (defendingActionOrderIndex(defender) <= positionActionOrderIndex(opener)) continue
        const decision = decideVsOpen(holeCardsFromCanonical('AKs')!, defender, opener, 40)!
        expect(decision.threeBetThreshold).toBeGreaterThanOrEqual(decision.callThreshold)
      }
    }
  })

  test('a defending suited hand never loses to its offsuit counterpart', () => {
    const strength = (a: OpenDefenseAction) => (a === 'fold' ? 0 : a === 'call' ? 1 : 2)
    for (const [offsuit, suited] of [
      ['A9o', 'A9s'],
      ['KJo', 'KJs'],
      ['T8o', 'T8s'],
      ['76o', '76s'],
    ]) {
      const offsuitDecision = decideVsOpen(holeCardsFromCanonical(offsuit)!, 'BB', 'CO', 40)!
      const suitedDecision = decideVsOpen(holeCardsFromCanonical(suited)!, 'BB', 'CO', 40)!
      expect(
        strength(suitedDecision.action),
        `${suited} should defend at least as much as ${offsuit}`,
      ).toBeGreaterThanOrEqual(strength(offsuitDecision.action))
    }
  })
})

describe('DefendingPosition shares action order with Position', () => {
  test('the six shared cases have matching indices, BB is last', () => {
    const shared: [string, string][] = [
      ['UTG', 'UTG'],
      ['MP', 'MP'],
      ['HJ', 'HJ'],
      ['CO', 'CO'],
      ['BTN', 'BTN'],
      ['SB', 'SB'],
    ]
    for (const [defending, position] of shared) {
      expect(defendingActionOrderIndex(defending as never)).toBe(positionActionOrderIndex(position as never))
    }
    expect(defendingActionOrderIndex('BB')).toBe(POSITIONS.length)
  })
})
