// Port of PokerKit/Sources/PokerKit/ChenScore.swift — Bill Chen's published starting-hand
// strength heuristic. A well-known, easily verified formula (not a memorized table of
// equities), which is why the range models rank the 169 starting hands with it rather
// than hand-typing 169 equity numbers.

import type { HoleCards } from './holeCards'
import { highRank, isPair, isSuited, lowRank } from './holeCards'
import type { Rank } from './card'

function highCardScore(rank: Rank): number {
  switch (rank) {
    case 14:
      return 10
    case 13:
      return 8
    case 12:
      return 7
    case 11:
      return 6
    case 10:
      return 5
    default:
      return rank / 2
  }
}

/** Number of ranks strictly between the two cards, e.g. AK -> 0, AQ -> 1, A2 -> 11. */
function gapBetween(high: Rank, low: Rank): number {
  return high - low - 1
}

function gapPenalty(gap: number): number {
  switch (gap) {
    case 0:
      return 0
    case 1:
      return 1
    case 2:
      return 2
    case 3:
      return 4
    default:
      return 5
  }
}

/** The formula's components only ever produce a whole number or a half (e.g. 9-high
 * contributes 4.5). Per Chen's rule, a half-point score rounds *up*. */
function roundHalfUp(score: number): number {
  const remainder = Math.abs(score % 1)
  return Math.abs(remainder - 0.5) < 1e-9 ? Math.ceil(score) : score
}

export function chenScore(hand: HoleCards): number {
  if (isPair(hand)) {
    return Math.max(highCardScore(highRank(hand)) * 2, 5)
  }

  let score = highCardScore(highRank(hand))
  if (isSuited(hand)) score += 2

  const gap = gapBetween(highRank(hand), lowRank(hand))
  score -= gapPenalty(gap)

  if (gap <= 1 && highRank(hand) < 12) {
    score += 1
  }

  return roundHalfUp(score)
}
