// UI-layer helper for parsing a compact board-card text field ("AsKdTh") into `Card`s.
// Not part of the engine port — this is purely about turning free-form user typing into
// engine inputs, the same job `EquityCalculatorView`'s board picker does in the iOS app,
// just via a single text field instead of per-card rank/suit menus (simpler to build well
// as a mobile-friendly web form).

import { type Card, cardFromNotation } from '../engine/card'

/** Normalizes free-form input (mixed case, stray whitespace) before token-splitting. */
function normalize(input: string): string {
  return input.replace(/\s+/g, '')
}

/**
 * Parses a run of 2-character card tokens ("2c9d4h") into `Card`s. Returns `undefined`
 * if the length isn't a multiple of 2 or any token fails to parse — never a partial result,
 * so callers can't silently act on a half-parsed board.
 */
export function parseCardString(input: string): Card[] | undefined {
  const normalized = normalize(input)
  if (normalized.length === 0) return []
  if (normalized.length % 2 !== 0) return undefined

  const cards: Card[] = []
  for (let i = 0; i < normalized.length; i += 2) {
    const c = cardFromNotation(normalized.slice(i, i + 2))
    if (!c) return undefined
    cards.push(c)
  }
  return cards
}

/**
 * Uppercases a canonical hand notation's rank characters but not its trailing
 * suited/offsuit flag — `holeCardsFromCanonical` requires a lowercase `s`/`o` ("AKs", not
 * "AKS"). A blanket `.toUpperCase()` on user input would silently invalidate every
 * suited/offsuit hand typed in any case other than already-correct.
 */
export function normalizeHandNotation(input: string): string {
  const trimmed = input.trim()
  if (trimmed.length !== 3) return trimmed.toUpperCase()
  return trimmed.slice(0, 2).toUpperCase() + trimmed.slice(2).toLowerCase()
}
