// Port of PokerKit/Sources/PokerKit/FourBetRange.swift — hero opened, got 3-bet, decides
// fold/call/4-bet(value)/4-bet(bluff). This codebase's least-certain preflop model: its one
// anchor is a single reported example (cutoff open facing a button 3-bet, continuing 67% —
// 50% call + 17% four-bet, ~100bb), generalized to every other pairing via `threeBetRange`'s
// own numbers. Treat every number here as directional, not precise — see ai-docs/RANGES.md.

import type { HoleCards } from './holeCards'
import { chenScore } from './chenScore'
import { holeCardsNotation } from './holeCards'
import { scoreThreshold } from './pushFoldRange'
import { decideOpening } from './openingRange'
import type { Position } from './position'
import { type DefendingPosition, defendingActionOrderIndex, positionActionOrderIndex } from './defendingPosition'
import { THREE_BET_BLUFF_COMBOS, totalThreeBetPercentage } from './threeBetRange'

export type FourBetAction = 'fourBetValue' | 'fourBetBluff' | 'call' | 'fold'

export interface FourBetDecision {
  readonly action: FourBetAction
  readonly handScore: number
  readonly valueThreshold: number
  readonly callThreshold: number
  readonly totalContinuePercentage: number
  readonly fourBetPercentage: number
  readonly isBluffCombo: boolean
}

/** The one sourced anchor: cutoff (opener) facing a button 3-bet continues 67% of hands
 * (50% call + 17% four-bet), assumed ~100bb. */
const OPENER_CONTINUE_VS_ANCHOR = 67
const FOUR_BET_SHARE_OF_CONTINUE_VS_ANCHOR = 17 / 67
const ANCHOR_OPENER: Position = 'CO'
const ANCHOR_THREE_BETTOR: DefendingPosition = 'BTN'

export const FOUR_BET_BLUFF_COMBOS = THREE_BET_BLUFF_COMBOS
const BLUFF_PERCENTAGE_OF_CANONICAL_HANDS = (FOUR_BET_BLUFF_COMBOS.size / 169) * 100

/** % of hands hero (the original opener) continues with — call or 4-bet, combined —
 * facing a 3-bet from `threeBettor`, or `undefined` for a nonsensical position pairing.
 * Scaled by how wide `threeBetRange` predicts `threeBettor` is 3-betting `opener`,
 * relative to the anchor pairing's predicted width — reuses `threeBetRange`'s own numbers
 * rather than inventing a second opinion on 3-bet width. */
export function totalContinuePercentage(
  opener: Position,
  threeBettor: DefendingPosition,
  effectiveStackBB: number,
): number | undefined {
  if (defendingActionOrderIndex(threeBettor) <= positionActionOrderIndex(opener)) return undefined

  const anchorThreeBetPercentage =
    totalThreeBetPercentage(ANCHOR_THREE_BETTOR, ANCHOR_OPENER, effectiveStackBB) ?? OPENER_CONTINUE_VS_ANCHOR
  const thisThreeBetPercentage =
    totalThreeBetPercentage(threeBettor, opener, effectiveStackBB) ?? anchorThreeBetPercentage

  const ratio = anchorThreeBetPercentage > 0 ? thisThreeBetPercentage / anchorThreeBetPercentage : 1
  return Math.min(Math.max(OPENER_CONTINUE_VS_ANCHOR * ratio, 0), 100)
}

export function decideFourBet(
  hand: HoleCards,
  opener: Position,
  threeBettor: DefendingPosition,
  effectiveStackBB: number,
): FourBetDecision | undefined {
  const totalContinue = totalContinuePercentage(opener, threeBettor, effectiveStackBB)
  if (totalContinue === undefined) return undefined

  const fourBetPercentage = totalContinue * FOUR_BET_SHARE_OF_CONTINUE_VS_ANCHOR
  const handScore = chenScore(hand)

  const wouldHaveOpened = decideOpening(hand, opener, effectiveStackBB).action === 'raise'
  const hasRoomForBluffs = fourBetPercentage > BLUFF_PERCENTAGE_OF_CANONICAL_HANDS
  const isBluffCombo =
    hasRoomForBluffs && FOUR_BET_BLUFF_COMBOS.has(holeCardsNotation(hand)) && wouldHaveOpened && effectiveStackBB >= 40

  const valuePercentage = hasRoomForBluffs ? fourBetPercentage - BLUFF_PERCENTAGE_OF_CANONICAL_HANDS : fourBetPercentage
  const valueThreshold = scoreThreshold(valuePercentage)
  const callThreshold = scoreThreshold(totalContinue)

  const action: FourBetAction =
    handScore >= valueThreshold
      ? 'fourBetValue'
      : isBluffCombo
        ? 'fourBetBluff'
        : handScore >= callThreshold
          ? 'call'
          : 'fold'

  return {
    action,
    handScore,
    valueThreshold,
    callThreshold,
    totalContinuePercentage: totalContinue,
    fourBetPercentage,
    isBluffCombo,
  }
}
