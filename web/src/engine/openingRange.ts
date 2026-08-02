// Port of PokerKit/Sources/PokerKit/OpeningRange.swift — see that file's doc comment
// (and ai-docs/RANGES.md) for the full source basis, what's directly sourced vs.
// extrapolated, and the one place this table is tightened below its cited source
// (small blind) out of caution.

import type { HoleCards } from './holeCards'
import { chenScore } from './chenScore'
import { scoreThreshold } from './pushFoldRange'
import type { Position } from './position'

export type OpeningAction = 'raise' | 'fold'

export interface OpeningDecision {
  readonly action: OpeningAction
  readonly handScore: number
  readonly scoreThreshold: number
  readonly openPercentage: number
}

function formatted(value: number): string {
  return value === Math.round(value) ? value.toFixed(0) : value.toFixed(1)
}

export function openingReasoning(d: OpeningDecision): string {
  const pct = d.openPercentage.toFixed(0)
  return d.action === 'raise'
    ? `Hand strength score ${formatted(d.handScore)} clears the open-raise threshold of ${formatted(d.scoreThreshold)} (top ${pct}% of hands) for this position and stack.`
    : `Hand strength score ${formatted(d.handScore)} is below the open-raise threshold of ${formatted(d.scoreThreshold)} (top ${pct}% of hands) for this position and stack.`
}

/** Stack breakpoints (effective bb), ascending — only 3 anchor points (vs.
 * `PushFoldRange`'s 10): the source material backing this table is thinner across stack
 * depths. `openPercentage` linearly interpolates between them and clamps outside [20, 100]. */
const BREAKPOINTS = [20, 40, 100]

/** % of the 169 starting hands to open-raise, indexed by position then aligned 1:1 with
 * `BREAKPOINTS` (20bb, 40bb, 100bb). Narrows as the stack deepens; widens as position
 * gets later. See ai-docs/RANGES.md for the source basis of each column. */
const OPEN_PERCENT_BY_POSITION: Record<Position, number[]> = {
  UTG: [16, 13, 10],
  MP: [24, 21, 18],
  HJ: [27, 24, 21],
  CO: [34, 31, 28],
  BTN: [49, 46, 43],
  SB: [51, 48, 45],
}

export function openPercentage(position: Position, effectiveStackBB: number): number {
  const table = OPEN_PERCENT_BY_POSITION[position]
  const stack = Math.min(Math.max(effectiveStackBB, BREAKPOINTS[0]), BREAKPOINTS[BREAKPOINTS.length - 1])
  const upperIndex = BREAKPOINTS.findIndex((bp) => bp >= stack)
  if (upperIndex === -1) return table[table.length - 1]
  if (BREAKPOINTS[upperIndex] === stack || upperIndex === 0) return table[upperIndex]

  const lowerIndex = upperIndex - 1
  const lowerBB = BREAKPOINTS[lowerIndex]
  const upperBB = BREAKPOINTS[upperIndex]
  const fraction = (stack - lowerBB) / (upperBB - lowerBB)
  return table[lowerIndex] + fraction * (table[upperIndex] - table[lowerIndex])
}

export function decideOpening(hand: HoleCards, position: Position, effectiveStackBB: number): OpeningDecision {
  const percentage = openPercentage(position, effectiveStackBB)
  const threshold = scoreThreshold(percentage)
  const handScore = chenScore(hand)
  return {
    action: handScore >= threshold ? 'raise' : 'fold',
    handScore,
    scoreThreshold: threshold,
    openPercentage: percentage,
  }
}
