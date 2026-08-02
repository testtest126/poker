// Port of PokerKit/Sources/PokerKit/PushFoldRange.swift — see that file's doc comment
// (and ai-docs/RANGES.md) for the full rationale: a hand-tuned study aid approximating
// the shape of published unopened shove charts, not solver output.

import { RANKS, card } from './card'
import type { HoleCards } from './holeCards'
import { holeCards } from './holeCards'
import { chenScore } from './chenScore'
import type { Position } from './position'

export type PushFoldAction = 'push' | 'fold'

export interface PushFoldDecision {
  readonly action: PushFoldAction
  readonly handScore: number
  readonly scoreThreshold: number
  readonly shovePercentage: number
}

function formatted(value: number): string {
  return value === Math.round(value) ? value.toFixed(0) : value.toFixed(1)
}

export function pushFoldReasoning(d: PushFoldDecision): string {
  const pct = d.shovePercentage.toFixed(0)
  return d.action === 'push'
    ? `Hand strength score ${formatted(d.handScore)} clears the shove threshold of ${formatted(d.scoreThreshold)} (top ${pct}% of hands) for this position and stack.`
    : `Hand strength score ${formatted(d.handScore)} is below the shove threshold of ${formatted(d.scoreThreshold)} (top ${pct}% of hands) for this position and stack.`
}

/** Stack breakpoints (effective bb), ascending. `shovePercentage` linearly interpolates
 * between them and clamps outside [1, 20]. */
const BREAKPOINTS = [1, 2, 3, 5, 7, 10, 12, 15, 17, 20]

/** % of the 169 starting hands to shove, indexed by position then aligned 1:1 with
 * `BREAKPOINTS`. Widens as the stack shortens; widens as position gets later. */
const SHOVE_PERCENT_BY_POSITION: Record<Position, number[]> = {
  UTG: [90, 60, 47, 33, 25, 18, 15, 11, 9, 7],
  MP: [93, 66, 53, 39, 30, 22, 18, 14, 11, 9],
  HJ: [95, 71, 59, 45, 35, 26, 22, 17, 14, 11],
  CO: [97, 78, 67, 53, 43, 33, 28, 22, 18, 15],
  BTN: [99, 88, 78, 66, 56, 45, 38, 31, 26, 22],
  SB: [100, 96, 90, 80, 70, 58, 50, 41, 35, 30],
}

/** All 169 canonical starting hands, ranked by Chen score, highest first. Computed once
 * from the formula rather than memorized. */
export const rankedCanonicalScores: readonly number[] = (() => {
  const scores: number[] = []
  for (let i = 0; i < RANKS.length; i++) {
    const high = RANKS[i]
    scores.push(chenScore(holeCards(card(high, 'clubs'), card(high, 'diamonds'))!))
    for (let j = 0; j < i; j++) {
      const low = RANKS[j]
      scores.push(chenScore(holeCards(card(high, 'clubs'), card(low, 'clubs'))!)) // suited
      scores.push(chenScore(holeCards(card(high, 'clubs'), card(low, 'diamonds'))!)) // offsuit
    }
  }
  return scores.sort((a, b) => b - a)
})()

function interpolate(table: readonly number[], breakpoints: readonly number[], effectiveStackBB: number): number {
  const stack = Math.min(Math.max(effectiveStackBB, breakpoints[0]), breakpoints[breakpoints.length - 1])
  const upperIndex = breakpoints.findIndex((bp) => bp >= stack)
  if (upperIndex === -1) return table[table.length - 1]
  if (breakpoints[upperIndex] === stack || upperIndex === 0) return table[upperIndex]

  const lowerIndex = upperIndex - 1
  const lowerBB = breakpoints[lowerIndex]
  const upperBB = breakpoints[upperIndex]
  const fraction = (stack - lowerBB) / (upperBB - lowerBB)
  return table[lowerIndex] + fraction * (table[upperIndex] - table[lowerIndex])
}

export function shovePercentage(position: Position, effectiveStackBB: number): number {
  return interpolate(SHOVE_PERCENT_BY_POSITION[position], BREAKPOINTS, effectiveStackBB)
}

/** The minimum Chen score that falls within the given shove percentage. */
export function scoreThreshold(percentage: number): number {
  const count = Math.min(
    Math.max(Math.round((rankedCanonicalScores.length * percentage) / 100), 1),
    rankedCanonicalScores.length,
  )
  return rankedCanonicalScores[count - 1]
}

export function decidePushFold(hand: HoleCards, position: Position, effectiveStackBB: number): PushFoldDecision {
  const percentage = shovePercentage(position, effectiveStackBB)
  const threshold = scoreThreshold(percentage)
  const handScore = chenScore(hand)
  return {
    action: handScore >= threshold ? 'push' : 'fold',
    handScore,
    scoreThreshold: threshold,
    shovePercentage: percentage,
  }
}
