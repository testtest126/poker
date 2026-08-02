import { describe, expect, test } from 'vitest'
import { holeCards, holeCardsFromCanonical, holeCardsNotation, isPair, isSuited } from './holeCards'

describe('holeCards', () => {
  test('rejects two identical cards', () => {
    const c = { rank: 14 as const, suit: 'spades' as const }
    expect(holeCards(c, c)).toBeUndefined()
  })

  test('isPair / isSuited', () => {
    const pair = holeCards({ rank: 14, suit: 'spades' }, { rank: 14, suit: 'hearts' })!
    expect(isPair(pair)).toBe(true)
    const suited = holeCards({ rank: 14, suit: 'spades' }, { rank: 13, suit: 'spades' })!
    expect(isSuited(suited)).toBe(true)
    expect(isPair(suited)).toBe(false)
  })
})

describe('canonical notation round trip', () => {
  test.each(['AA', 'AKs', 'AKo', 'T9o', '72o', '22'])('%s parses and re-serializes to itself', (notation) => {
    const h = holeCardsFromCanonical(notation)
    expect(h).toBeDefined()
    expect(holeCardsNotation(h!)).toBe(notation)
  })

  test.each(['', 'A', 'AKx', 'XX', 'AAs'])('%s is rejected as invalid', (notation) => {
    expect(holeCardsFromCanonical(notation)).toBeUndefined()
  })
})
