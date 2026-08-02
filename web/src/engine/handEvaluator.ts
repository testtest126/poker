// Port of PokerKit/Sources/PokerKit/HandEvaluator.swift — evaluates the best possible
// 5-card poker hand out of 5, 6, or 7 cards. No shortcuts: every category is derived
// from actual rank/suit counts, not a lookup table — same approach as the Swift source,
// see ai-docs/EQUITY.md for why (that project's tests exercise this exact logic).

import type { Card, Rank } from './card'

export const HAND_CATEGORIES = [
  'highCard',
  'pair',
  'twoPair',
  'trips',
  'straight',
  'flush',
  'fullHouse',
  'quads',
  'straightFlush',
] as const

export type HandCategory = (typeof HAND_CATEGORIES)[number]

const CATEGORY_RANK: Record<HandCategory, number> = Object.fromEntries(
  HAND_CATEGORIES.map((c, i) => [c, i]),
) as Record<HandCategory, number>

export const HAND_CATEGORY_LABEL: Record<HandCategory, string> = {
  highCard: 'High Card',
  pair: 'Pair',
  twoPair: 'Two Pair',
  trips: 'Three of a Kind',
  straight: 'Straight',
  flush: 'Flush',
  fullHouse: 'Full House',
  quads: 'Four of a Kind',
  straightFlush: 'Straight Flush',
}

/** A fully comparable strength for one specific best-5-card hand: category, plus enough
 * rank tiebreakers (most significant first) to break every tie the category leaves open. */
export interface HandStrength {
  readonly category: HandCategory
  readonly tiebreakers: readonly number[]
}

/** Negative if `a` is weaker than `b`, positive if stronger, 0 if equal. */
export function compareHandStrength(a: HandStrength, b: HandStrength): number {
  const catDiff = CATEGORY_RANK[a.category] - CATEGORY_RANK[b.category]
  if (catDiff !== 0) return catDiff
  const len = Math.min(a.tiebreakers.length, b.tiebreakers.length)
  for (let i = 0; i < len; i++) {
    const diff = a.tiebreakers[i] - b.tiebreakers[i]
    if (diff !== 0) return diff
  }
  return 0
}

/** The 21 ways to choose 5 indices out of 7, precomputed once — this is the equity
 * engine's hottest inner loop, so avoiding a general combinations generator here matters. */
const SEVEN_CHOOSE_FIVE_INDICES: readonly [number, number, number, number, number][] = (() => {
  const result: [number, number, number, number, number][] = []
  for (let a = 0; a < 7; a++) {
    for (let b = a + 1; b < 7; b++) {
      for (let c = b + 1; c < 7; c++) {
        for (let d = c + 1; d < 7; d++) {
          for (let e = d + 1; e < 7; e++) {
            result.push([a, b, c, d, e])
          }
        }
      }
    }
  }
  return result
})()

/** The best 5-card `HandStrength` achievable from `cards` (5, 6, or 7 of them). */
export function bestHand(cards: readonly Card[]): HandStrength {
  if (cards.length < 5 || cards.length > 7) {
    throw new Error(`bestHand needs 5-7 cards, got ${cards.length}`)
  }

  if (cards.length === 5) {
    return evaluate5(cards[0], cards[1], cards[2], cards[3], cards[4])
  }

  if (cards.length === 7) {
    let best: HandStrength | undefined
    for (const [a, b, c, d, e] of SEVEN_CHOOSE_FIVE_INDICES) {
      const candidate = evaluate5(cards[a], cards[b], cards[c], cards[d], cards[e])
      if (!best || compareHandStrength(candidate, best) > 0) best = candidate
    }
    return best!
  }

  // 6 cards: one skip-index combination each.
  let best: HandStrength | undefined
  for (let skip = 0; skip < 6; skip++) {
    const five = cards.filter((_, i) => i !== skip)
    const candidate = evaluate5(five[0], five[1], five[2], five[3], five[4])
    if (!best || compareHandStrength(candidate, best) > 0) best = candidate
  }
  return best!
}

function evaluate5(a: Card, b: Card, c: Card, d: Card, e: Card): HandStrength {
  const ranks = [a.rank, b.rank, c.rank, d.rank, e.rank].sort((x, y) => y - x)

  const isFlush = a.suit === b.suit && b.suit === c.suit && c.suit === d.suit && d.suit === e.suit

  let straightHigh: number | undefined
  const distinctRanks = new Set(ranks)
  if (distinctRanks.size === 5) {
    if (ranks[0] - ranks[4] === 4) {
      straightHigh = ranks[0]
    } else if (ranks[0] === 14 && ranks[1] === 5 && ranks[2] === 4 && ranks[3] === 3 && ranks[4] === 2) {
      straightHigh = 5 // the wheel: A-2-3-4-5, plays as a 5-high straight
    }
  }

  // Rank counts via a fixed 15-slot array (indices 2...14) rather than a Map — this
  // function runs a lot inside the equity engine's exact enumeration.
  const countByRank = new Array(15).fill(0)
  for (const r of ranks) countByRank[r]++

  const groups: { rank: Rank; count: number }[] = []
  for (let r = 14; r >= 2; r--) {
    if (countByRank[r] > 0) groups.push({ rank: r as Rank, count: countByRank[r] })
  }
  groups.sort((x, y) => (x.count !== y.count ? y.count - x.count : y.rank - x.rank))

  if (straightHigh !== undefined && isFlush) {
    return { category: 'straightFlush', tiebreakers: [straightHigh] }
  }
  if (groups[0].count === 4) {
    return { category: 'quads', tiebreakers: [groups[0].rank, groups[1].rank] }
  }
  if (groups[0].count === 3 && groups.length > 1 && groups[1].count >= 2) {
    return { category: 'fullHouse', tiebreakers: [groups[0].rank, groups[1].rank] }
  }
  if (isFlush) {
    return { category: 'flush', tiebreakers: ranks }
  }
  if (straightHigh !== undefined) {
    return { category: 'straight', tiebreakers: [straightHigh] }
  }
  if (groups[0].count === 3) {
    return { category: 'trips', tiebreakers: [groups[0].rank, ...groups.slice(1).map((g) => g.rank)] }
  }
  if (groups[0].count === 2 && groups.length > 1 && groups[1].count === 2) {
    return { category: 'twoPair', tiebreakers: [groups[0].rank, groups[1].rank, groups[2].rank] }
  }
  if (groups[0].count === 2) {
    return { category: 'pair', tiebreakers: [groups[0].rank, ...groups.slice(1).map((g) => g.rank)] }
  }
  return { category: 'highCard', tiebreakers: ranks }
}
