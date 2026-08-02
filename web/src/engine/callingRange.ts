// Port of PokerKit/Sources/PokerKit/CallingRange.swift — see that file's doc comment (and
// ai-docs/RANGES.md) for the full rationale and, critically, the confidence levels: "facing
// a shove, big blind calling" is the one case with a genuine published Nash equivalent;
// everything else here (small blind/non-blind callers, and every "facing an open" number)
// is directional, hand-tuned, and considerably less certain — never presented as more
// precise than that.

import type { HoleCards } from './holeCards'
import { chenScore } from './chenScore'
import { scoreThreshold, shovePercentage } from './pushFoldRange'
import { openPercentage } from './openingRange'
import type { Position } from './position'
import { type DefendingPosition, defendingActionOrderIndex, positionActionOrderIndex } from './defendingPosition'

// MARK: Facing a shove

export type CallVsShoveAction = 'call' | 'fold'

export interface CallVsShoveDecision {
  readonly action: CallVsShoveAction
  readonly handScore: number
  readonly scoreThreshold: number
  readonly callPercentage: number
}

/** Same ten stack breakpoints as `pushFoldRange`, since this model's percentages are
 * discounts *off* its own shove percentages. */
const SHOVE_DISCOUNT_BREAKPOINTS = [1, 2, 3, 5, 7, 10, 12, 15, 17, 20]

/** Fraction of the shover's own shove-percentage that's a profitable call, aligned 1:1
 * with `SHOVE_DISCOUNT_BREAKPOINTS`. Calibrated against one external data point: a
 * published heads-up Nash SB-shove figure of ~50% at 10bb vs. this project's own SB
 * shove figure of 58% at 10bb. See ai-docs/RANGES.md. */
const SHOVE_DISCOUNT_BY_STACK = [0.9, 0.82, 0.75, 0.65, 0.58, 0.52, 0.48, 0.44, 0.41, 0.38]

/** Further discount for callers other than the big blind — this model's least-confident
 * numbers (no source found for any of them, unlike the BB Nash-equivalent case). `UTG` is
 * included only for lookup completeness; it can never be a valid caller. */
const CALLER_POSITION_DISCOUNT: Record<DefendingPosition, number> = {
  BB: 1.0,
  SB: 0.75,
  BTN: 0.55,
  CO: 0.5,
  HJ: 0.45,
  MP: 0.4,
  UTG: 0.35,
}

function interpolate(table: readonly number[], breakpoints: readonly number[], stackIn: number): number {
  const stack = Math.min(Math.max(stackIn, breakpoints[0]), breakpoints[breakpoints.length - 1])
  const upperIndex = breakpoints.findIndex((bp) => bp >= stack)
  if (upperIndex === -1) return table[table.length - 1]
  if (breakpoints[upperIndex] === stack || upperIndex === 0) return table[upperIndex]

  const lowerIndex = upperIndex - 1
  const lowerBB = breakpoints[lowerIndex]
  const upperBB = breakpoints[upperIndex]
  const fraction = (stack - lowerBB) / (upperBB - lowerBB)
  return table[lowerIndex] + fraction * (table[upperIndex] - table[lowerIndex])
}

function shoveDiscount(effectiveStackBB: number): number {
  return interpolate(SHOVE_DISCOUNT_BY_STACK, SHOVE_DISCOUNT_BREAKPOINTS, effectiveStackBB)
}

/** % of hands it's profitable for `caller` to call a shove from `shover`, or `undefined`
 * if `caller` couldn't actually be facing that shove (would have to act before `shover`
 * at an unopened table). */
export function callPercentage(caller: DefendingPosition, shover: Position, effectiveStackBB: number): number | undefined {
  if (defendingActionOrderIndex(caller) <= positionActionOrderIndex(shover)) return undefined
  const shovePct = shovePercentage(shover, effectiveStackBB)
  const discount = shoveDiscount(effectiveStackBB) * CALLER_POSITION_DISCOUNT[caller]
  return Math.min(Math.max(shovePct * discount, 0), 100)
}

export function decideVsShove(
  hand: HoleCards,
  caller: DefendingPosition,
  shover: Position,
  effectiveStackBB: number,
): CallVsShoveDecision | undefined {
  const percentage = callPercentage(caller, shover, effectiveStackBB)
  if (percentage === undefined) return undefined
  const threshold = scoreThreshold(percentage)
  const handScore = chenScore(hand)
  return {
    action: handScore >= threshold ? 'call' : 'fold',
    handScore,
    scoreThreshold: threshold,
    callPercentage: percentage,
  }
}

// MARK: Facing an open

export type OpenDefenseAction = 'threeBet' | 'call' | 'fold'

export interface OpenDefenseDecision {
  readonly action: OpenDefenseAction
  readonly handScore: number
  readonly threeBetThreshold: number
  readonly callThreshold: number
  readonly totalDefensePercentage: number
  readonly threeBetPercentage: number
}

/** Big blind's combined call+3-bet continuing frequency against a button open — sourced
 * (~84%, see ai-docs/RANGES.md), this model's one external anchor; every other
 * position/opener combination scales off it. */
const BIG_BLIND_DEFENSE_VS_BUTTON = 84

/** Small blind's total defense as a fraction of what the big blind would defend against
 * the same open — hand-tuned, no exact ratio sourced. */
const SMALL_BLIND_DEFENSE_FACTOR = 0.65

/** Non-blind defenders' total defense as a fraction of what the big blind would defend —
 * this model's least-confident number; no position-by-position source found at all. */
const NON_BLIND_DEFENSE_FACTOR = 0.5

/** Share of total defense that goes to 3-betting rather than flatting. Hand-tuned, not
 * sourced. Ranks purely by Chen score (value only, no bluffing combos) — a disclosed
 * simplification; see `ThreeBetRange`/`threeBetRange.ts` for a more careful polarized
 * model of this same question. */
function threeBetShare(defender: DefendingPosition): number {
  switch (defender) {
    case 'BB':
      return 0.25
    case 'SB':
      return 0.45
    default:
      return 0.35
  }
}

/** % of hands `defender` should continue with (call or 3-bet, combined) against an open
 * from `opener`, or `undefined` if `defender` couldn't actually be facing that open. */
export function totalDefensePercentage(
  defender: DefendingPosition,
  opener: Position,
  effectiveStackBB: number,
): number | undefined {
  if (defendingActionOrderIndex(defender) <= positionActionOrderIndex(opener)) return undefined

  const openerOpenPct = openPercentage(opener, effectiveStackBB)
  const buttonOpenPct = openPercentage('BTN', effectiveStackBB)
  const bigBlindDefense = BIG_BLIND_DEFENSE_VS_BUTTON * (openerOpenPct / buttonOpenPct)

  const factor = defender === 'BB' ? 1.0 : defender === 'SB' ? SMALL_BLIND_DEFENSE_FACTOR : NON_BLIND_DEFENSE_FACTOR
  return Math.min(Math.max(bigBlindDefense * factor, 0), 100)
}

export function decideVsOpen(
  hand: HoleCards,
  defender: DefendingPosition,
  opener: Position,
  effectiveStackBB: number,
): OpenDefenseDecision | undefined {
  const totalDefense = totalDefensePercentage(defender, opener, effectiveStackBB)
  if (totalDefense === undefined) return undefined

  const threeBetPercentage = totalDefense * threeBetShare(defender)
  const callThreshold = scoreThreshold(totalDefense)
  const threeBetThreshold = scoreThreshold(threeBetPercentage)
  const handScore = chenScore(hand)

  const action: OpenDefenseAction =
    handScore >= threeBetThreshold ? 'threeBet' : handScore >= callThreshold ? 'call' : 'fold'

  return {
    action,
    handScore,
    threeBetThreshold,
    callThreshold,
    totalDefensePercentage: totalDefense,
    threeBetPercentage,
  }
}
