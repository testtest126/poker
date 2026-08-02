// Port of PokerKit/Sources/PokerKit/HoleCards.swift — two hole cards. Order doesn't
// matter for equality or hand strength; what matters is the pair of ranks and whether
// they share a suit.

import { type Card, type Rank, cardsEqual, rankFromSymbol, rankSymbol } from './card'

export interface HoleCards {
  readonly first: Card
  readonly second: Card
}

/** `undefined` if the two cards are identical (same rank and suit). */
export function holeCards(first: Card, second: Card): HoleCards | undefined {
  if (cardsEqual(first, second)) return undefined
  return { first, second }
}

export function isPair(h: HoleCards): boolean {
  return h.first.rank === h.second.rank
}

export function isSuited(h: HoleCards): boolean {
  return h.first.suit === h.second.suit
}

export function highRank(h: HoleCards): Rank {
  return Math.max(h.first.rank, h.second.rank) as Rank
}

export function lowRank(h: HoleCards): Rank {
  return Math.min(h.first.rank, h.second.rank) as Rank
}

/** Canonical starting-hand notation, e.g. "AA", "AKs", "T9o". */
export function holeCardsNotation(h: HoleCards): string {
  const hi = rankSymbol(highRank(h))
  if (isPair(h)) return `${hi}${hi}`
  const lo = rankSymbol(lowRank(h))
  return `${hi}${lo}${isSuited(h) ? 's' : 'o'}`
}

/**
 * One representative `HoleCards` for a canonical hand string like "AKs", "77", "T9o".
 * Suits are picked arbitrarily (consistent with the requested suited/offsuit flag) —
 * useful for range lookups that only care about the canonical hand, not a specific combo.
 */
export function holeCardsFromCanonical(canonical: string): HoleCards | undefined {
  const chars = Array.from(canonical)
  if (chars.length !== 2 && chars.length !== 3) return undefined
  const r1 = rankFromSymbol(chars[0])
  const r2 = rankFromSymbol(chars[1])
  if (r1 === undefined || r2 === undefined) return undefined

  if (chars.length === 2) {
    if (r1 !== r2) return undefined
    return holeCards({ rank: r1, suit: 'clubs' }, { rank: r2, suit: 'diamonds' })
  }

  const suitedFlag = chars[2]
  if (suitedFlag !== 's' && suitedFlag !== 'o') return undefined
  if (r1 === r2) return undefined
  const a: Card = { rank: r1, suit: 'clubs' }
  const b: Card = { rank: r2, suit: suitedFlag === 's' ? 'clubs' : 'diamonds' }
  return holeCards(a, b)
}
