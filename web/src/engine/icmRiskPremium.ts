// Port of PokerKit/Sources/PokerKit/ICMRiskPremium.swift — how much tighter an all-in call
// should be than pure chip-EV suggests once ICM is accounted for. An overlay, not a
// mutation: never touches `icmEquities`, just a separate opinion computed from it.
//
// **What this deliberately simplifies away** (all flagged here, not silently assumed):
// - A single all-in confrontation for full stacks — no side pots, no partial/covering
//   stacks, no multi-way all-ins.
// - Busting means $0, not a guaranteed min-cash — the standard simplifying assumption
//   introductory ICM risk-premium explanations use. Slightly *overstates* the true risk
//   premium (a real bust often isn't worth literally $0).
// - No Future Game State — only this one all-in's direct $EV, not the value of a bigger
//   stack for hands afterward.
// - `otherStacks` must be the entire remaining field, matching `icmEquities`'s own scope.

import { icmEquities } from './icm'

export interface ICMRiskAssessment {
  /** The win probability at which calling breaks even in pure chip terms, ignoring ICM:
   * `heroStack / (heroStack + villainStack)`. */
  readonly chipEVRequiredEquity: number
  /** The win probability at which calling breaks even in ICM ($) terms. `NaN` if
   * `payouts` has no positive value to play for. */
  readonly icmRequiredEquity: number
  /** `icmRequiredEquity - chipEVRequiredEquity`. */
  readonly riskPremium: number
  readonly foldEquity: number
  readonly winEquity: number
  readonly loseEquity: number
}

export function assessICMRisk(
  heroStack: number,
  villainStack: number,
  otherStacks: readonly number[],
  payouts: readonly number[],
): ICMRiskAssessment {
  if (!(heroStack > 0 && villainStack > 0)) {
    throw new Error('Both hero and villain need a positive stack to be in a confrontation at all.')
  }
  if (!otherStacks.every((s) => s > 0)) {
    throw new Error('otherStacks must not include already-busted (0-chip) players — omit them instead.')
  }

  const chipEVRequired = heroStack / (heroStack + villainStack)

  const foldStacks = [heroStack, villainStack, ...otherStacks]
  const foldEquity = icmEquities(foldStacks, payouts)[0]

  const winStacks = [heroStack + villainStack, ...otherStacks]
  const winEquity = icmEquities(winStacks, payouts)[0]

  const loseEquity = 0

  const icmRequired = winEquity - loseEquity > 0 ? (foldEquity - loseEquity) / (winEquity - loseEquity) : NaN

  return {
    chipEVRequiredEquity: chipEVRequired,
    icmRequiredEquity: icmRequired,
    riskPremium: icmRequired - chipEVRequired,
    foldEquity,
    winEquity,
    loseEquity,
  }
}
