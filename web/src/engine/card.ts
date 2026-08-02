// A faithful TypeScript port of PokerKit/Sources/PokerKit/Card.swift — same ranks,
// same suits, same notation. Ported (not shared/compiled) because the web app is a
// separate TypeScript codebase from the Swift iOS app; see ROADMAP.md's "Platform plan"
// for why. Every value here should match the Swift source exactly.

/** Two through Ace, numeric so ranks compare and sort naturally (2...14). */
export type Rank = 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14

export const RANKS: readonly Rank[] = [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14]

/** Single-character notation, e.g. "A", "K", "T", "9". */
export function rankSymbol(rank: Rank): string {
  switch (rank) {
    case 14:
      return 'A'
    case 13:
      return 'K'
    case 12:
      return 'Q'
    case 11:
      return 'J'
    case 10:
      return 'T'
    default:
      return String(rank)
  }
}

/** The inverse of `rankSymbol` — case-insensitive. `undefined` for an invalid symbol. */
export function rankFromSymbol(symbol: string): Rank | undefined {
  switch (symbol.toUpperCase()) {
    case 'A':
      return 14
    case 'K':
      return 13
    case 'Q':
      return 12
    case 'J':
      return 11
    case 'T':
      return 10
    default: {
      const digit = Number(symbol)
      return Number.isInteger(digit) && digit >= 2 && digit <= 9 ? (digit as Rank) : undefined
    }
  }
}

export type Suit = 'clubs' | 'diamonds' | 'hearts' | 'spades'

export const SUITS: readonly Suit[] = ['clubs', 'diamonds', 'hearts', 'spades']

export function suitSymbol(suit: Suit): string {
  switch (suit) {
    case 'clubs':
      return '♣'
    case 'diamonds':
      return '♦'
    case 'hearts':
      return '♥'
    case 'spades':
      return '♠'
  }
}

/** The single-letter suit code used in card notation ("As", "Th", "2c"). */
function suitLetter(suit: Suit): string {
  switch (suit) {
    case 'clubs':
      return 'c'
    case 'diamonds':
      return 'd'
    case 'hearts':
      return 'h'
    case 'spades':
      return 's'
  }
}

function suitFromLetter(letter: string): Suit | undefined {
  switch (letter.toLowerCase()) {
    case 's':
      return 'spades'
    case 'h':
      return 'hearts'
    case 'd':
      return 'diamonds'
    case 'c':
      return 'clubs'
    default:
      return undefined
  }
}

export interface Card {
  readonly rank: Rank
  readonly suit: Suit
}

export function card(rank: Rank, suit: Suit): Card {
  return { rank, suit }
}

export function cardsEqual(a: Card, b: Card): boolean {
  return a.rank === b.rank && a.suit === b.suit
}

/** A stable string key for use in Sets/Maps — Card is a plain object, not reference-equal. */
export function cardKey(c: Card): string {
  return `${c.rank}${c.suit[0]}`
}

/** e.g. "As", "Th", "2c" — the inverse of `cardFromNotation`. */
export function cardNotation(c: Card): string {
  return `${rankSymbol(c.rank)}${suitLetter(c.suit)}`
}

/** Parses a 2-character card notation ("As", "Th", "2c"). `undefined` if invalid. */
export function cardFromNotation(notation: string): Card | undefined {
  if (notation.length !== 2) return undefined
  const rank = rankFromSymbol(notation[0])
  const suit = suitFromLetter(notation[1])
  if (rank === undefined || suit === undefined) return undefined
  return { rank, suit }
}

/** The standard 52-card deck, in a fixed (rank-major) order. */
export const FULL_DECK: readonly Card[] = RANKS.flatMap((rank) => SUITS.map((suit) => card(rank, suit)))
