// Port of the push/fold- and opening-relevant assertions in
// PokerKit/Tests/PokerKitTests/PreflopGridTests.swift.

import { describe, expect, test } from 'vitest'
import { holeCardsNotation } from './holeCards'
import { GRID_RANKS, gridHands, gridNotation, openingGridDecisions, pushFoldGridDecisions } from './preflopGrid'
import { decidePushFold } from './pushFoldRange'
import { decideOpening } from './openingRange'

describe('PreflopGrid', () => {
  test('enumerates all 169 unique hands', () => {
    const notations = new Set(gridHands.flatMap((row) => row.map((h) => holeCardsNotation(h))))
    expect(notations.size).toBe(169)
  })

  test('notation matches grid position', () => {
    expect(gridNotation(0, 1)).toBe('AKs') // A is index 0, K is index 1 — above diagonal
    expect(gridNotation(1, 0)).toBe('AKo') // below diagonal
    expect(gridNotation(0, 0)).toBe('AA')
  })

  test('upper-right is suited, lower-left is offsuit', () => {
    for (let row = 0; row < GRID_RANKS.length; row++) {
      for (let col = 0; col < GRID_RANKS.length; col++) {
        if (row === col) continue
        const notation = gridNotation(row, col)
        if (row < col) expect(notation.endsWith('s'), notation).toBe(true)
        else expect(notation.endsWith('o'), notation).toBe(true)
      }
    }
  })

  test('grid push/fold decisions match direct PushFoldRange decisions', () => {
    const decisions = pushFoldGridDecisions('CO', 8)
    for (let row = 0; row < GRID_RANKS.length; row++) {
      for (let col = 0; col < GRID_RANKS.length; col++) {
        const expected = decidePushFold(gridHands[row][col], 'CO', 8)
        expect(decisions[row][col].action).toBe(expected.action)
      }
    }
  })

  test('AA always shoves across the grid', () => {
    for (const position of ['UTG', 'MP', 'HJ', 'CO', 'BTN', 'SB'] as const) {
      for (const stack of [1, 5, 10, 15, 20]) {
        expect(pushFoldGridDecisions(position, stack)[0][0].action).toBe('push')
      }
    }
  })

  test('grid opening decisions match direct OpeningRange decisions', () => {
    const decisions = openingGridDecisions('CO', 60)
    for (let row = 0; row < GRID_RANKS.length; row++) {
      for (let col = 0; col < GRID_RANKS.length; col++) {
        const expected = decideOpening(gridHands[row][col], 'CO', 60)
        expect(decisions[row][col].action).toBe(expected.action)
      }
    }
  })
})
