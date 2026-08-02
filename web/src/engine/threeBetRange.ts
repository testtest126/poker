// Port of PokerKit/Sources/PokerKit/ThreeBetRange.swift — a more careful, polarized
// (value + bluff) opinion on the 3-bet slice of "facing an open" than `callingRange.ts`'s
// flat single-threshold split. The two *will* disagree on a given spot — see
// ai-docs/RANGES.md's "Two opinions, on purpose" section. Not a replacement for
// `callingRange.ts`; both stay live.

import type { HoleCards } from './holeCards'
import { chenScore } from './chenScore'
import { holeCardsNotation } from './holeCards'
import { scoreThreshold } from './pushFoldRange'
import { openPercentage } from './openingRange'
import type { Position } from './position'
import { type DefendingPosition, defendingActionOrderIndex, positionActionOrderIndex } from './defendingPosition'
import { totalDefensePercentage } from './callingRange'

export type ThreeBetAction = 'threeBetValue' | 'threeBetBluff' | 'call' | 'fold'

export interface ThreeBetDecision {
  readonly action: ThreeBetAction
  readonly handScore: number
  readonly valueThreshold: number
  readonly callThreshold: number
  readonly totalDefensePercentage: number
  readonly threeBetPercentage: number
  readonly isBluffCombo: boolean
}

/** Big blind's 3-bet percentage against a button open at ~100bb — sourced (12-14% cited,
 * this project's anchor is the midpoint, 13%). See ai-docs/RANGES.md. */
const BIG_BLIND_THREE_BET_VS_BUTTON = 13
const SMALL_BLIND_FACTOR = 0.65
const NON_BLIND_FACTOR = 0.5

/** Suited wheel aces — the standard 3-bet blocker-bluff selection (blocks villain's
 * premium pairs/AK, retains real equity if called). Deliberately not scaled by stack or
 * position; only whether it's included at all varies (see `decide`). */
export const THREE_BET_BLUFF_COMBOS = new Set(['A5s', 'A4s', 'A3s', 'A2s'])
const BLUFF_PERCENTAGE_OF_CANONICAL_HANDS = (THREE_BET_BLUFF_COMBOS.size / 169) * 100

export function totalThreeBetPercentage(
  defender: DefendingPosition,
  opener: Position,
  effectiveStackBB: number,
): number | undefined {
  if (defendingActionOrderIndex(defender) <= positionActionOrderIndex(opener)) return undefined

  const openerOpenPct = openPercentage(opener, effectiveStackBB)
  const buttonOpenPct = openPercentage('BTN', effectiveStackBB)
  const bigBlindThreeBet = BIG_BLIND_THREE_BET_VS_BUTTON * (openerOpenPct / buttonOpenPct)

  const factor = defender === 'BB' ? 1.0 : defender === 'SB' ? SMALL_BLIND_FACTOR : NON_BLIND_FACTOR
  return Math.min(Math.max(bigBlindThreeBet * factor, 0), 100)
}

/**
 * Fold/call/3-bet(value)/3-bet(bluff) decision for `hand`, or `undefined` for a
 * nonsensical position pairing.
 *
 * Value is the top of `hand`'s Chen-score ranking, sized so value + the fixed bluff-combo
 * list together equal `totalThreeBetPercentage` — *unless* the total is smaller than the
 * bluff carve-out itself (a very narrow spot), in which case bluffs are dropped entirely
 * and the whole total is value-only, matching the sourced guidance that a tight value
 * range doesn't need bluffs. `PushFoldRange`-style `scoreThreshold` already guarantees at
 * least the single best hand (AA) clears the value threshold even at a 0% carve-out, so no
 * extra guard is needed for that case.
 */
export function decideThreeBet(
  hand: HoleCards,
  defender: DefendingPosition,
  opener: Position,
  effectiveStackBB: number,
): ThreeBetDecision | undefined {
  const threeBetTotal = totalThreeBetPercentage(defender, opener, effectiveStackBB)
  if (threeBetTotal === undefined) return undefined
  const totalDefense = totalDefensePercentage(defender, opener, effectiveStackBB)
  if (totalDefense === undefined) return undefined

  const handScore = chenScore(hand)
  const hasRoomForBluffs = threeBetTotal > BLUFF_PERCENTAGE_OF_CANONICAL_HANDS
  const isBluffCombo = hasRoomForBluffs && THREE_BET_BLUFF_COMBOS.has(holeCardsNotation(hand)) && effectiveStackBB >= 20

  const valuePercentage = hasRoomForBluffs ? threeBetTotal - BLUFF_PERCENTAGE_OF_CANONICAL_HANDS : threeBetTotal
  const valueThreshold = scoreThreshold(valuePercentage)
  const callThreshold = scoreThreshold(Math.max(totalDefense, threeBetTotal))

  const action: ThreeBetAction =
    handScore >= valueThreshold
      ? 'threeBetValue'
      : isBluffCombo
        ? 'threeBetBluff'
        : handScore >= callThreshold
          ? 'call'
          : 'fold'

  return {
    action,
    handScore,
    valueThreshold,
    callThreshold,
    totalDefensePercentage: totalDefense,
    threeBetPercentage: threeBetTotal,
    isBluffCombo,
  }
}
