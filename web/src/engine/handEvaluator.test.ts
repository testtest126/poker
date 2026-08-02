// Port of PokerKit/Tests/PokerKitTests/HandEvaluatorTests.swift — same test vectors,
// translated 1:1 (rank numbers instead of Swift's named enum cases), so this port is
// checked against the exact same known-good hands as the Swift source.

import { describe, expect, test } from 'vitest'
import type { Card, Rank } from './card'
import { bestHand, compareHandStrength } from './handEvaluator'

function c(rank: Rank, suit: Card['suit']): Card {
  return { rank, suit }
}

const gt = (a: ReturnType<typeof bestHand>, b: ReturnType<typeof bestHand>) => compareHandStrength(a, b) > 0
const eq = (a: ReturnType<typeof bestHand>, b: ReturnType<typeof bestHand>) => compareHandStrength(a, b) === 0

describe('category ordering', () => {
  test('royal flush beats quads', () => {
    const royal = bestHand([c(14, 'spades'), c(13, 'spades'), c(12, 'spades'), c(11, 'spades'), c(10, 'spades')])
    const quads = bestHand([c(14, 'spades'), c(14, 'hearts'), c(14, 'diamonds'), c(14, 'clubs'), c(13, 'spades')])
    expect(royal.category).toBe('straightFlush')
    expect(gt(royal, quads)).toBe(true)
  })

  test('quads beats full house', () => {
    const quads = bestHand([c(2, 'spades'), c(2, 'hearts'), c(2, 'diamonds'), c(2, 'clubs'), c(13, 'spades')])
    const fullHouse = bestHand([c(14, 'spades'), c(14, 'hearts'), c(14, 'diamonds'), c(13, 'clubs'), c(13, 'spades')])
    expect(gt(quads, fullHouse)).toBe(true)
  })

  test('full house beats flush', () => {
    const fullHouse = bestHand([c(2, 'spades'), c(2, 'hearts'), c(2, 'diamonds'), c(3, 'clubs'), c(3, 'spades')])
    const flush = bestHand([c(14, 'spades'), c(13, 'spades'), c(12, 'spades'), c(11, 'spades'), c(9, 'spades')])
    expect(gt(fullHouse, flush)).toBe(true)
  })

  test('flush beats straight', () => {
    const flush = bestHand([c(2, 'spades'), c(4, 'spades'), c(6, 'spades'), c(8, 'spades'), c(10, 'spades')])
    const straight = bestHand([c(14, 'spades'), c(13, 'hearts'), c(12, 'diamonds'), c(11, 'clubs'), c(10, 'spades')])
    expect(gt(flush, straight)).toBe(true)
  })

  test('straight beats trips', () => {
    const straight = bestHand([c(6, 'spades'), c(7, 'hearts'), c(8, 'diamonds'), c(9, 'clubs'), c(10, 'spades')])
    const trips = bestHand([c(14, 'spades'), c(14, 'hearts'), c(14, 'diamonds'), c(13, 'clubs'), c(12, 'spades')])
    expect(gt(straight, trips)).toBe(true)
  })

  test('trips beats two pair', () => {
    const trips = bestHand([c(2, 'spades'), c(2, 'hearts'), c(2, 'diamonds'), c(3, 'clubs'), c(4, 'spades')])
    const twoPair = bestHand([c(14, 'spades'), c(14, 'hearts'), c(13, 'diamonds'), c(13, 'clubs'), c(12, 'spades')])
    expect(gt(trips, twoPair)).toBe(true)
  })

  test('two pair beats pair', () => {
    const twoPair = bestHand([c(2, 'spades'), c(2, 'hearts'), c(3, 'diamonds'), c(3, 'clubs'), c(4, 'spades')])
    const pair = bestHand([c(14, 'spades'), c(14, 'hearts'), c(13, 'diamonds'), c(12, 'clubs'), c(11, 'spades')])
    expect(gt(twoPair, pair)).toBe(true)
  })

  test('pair beats high card', () => {
    const pair = bestHand([c(2, 'spades'), c(2, 'hearts'), c(3, 'diamonds'), c(4, 'clubs'), c(5, 'spades')])
    const highCard = bestHand([c(14, 'spades'), c(13, 'hearts'), c(12, 'diamonds'), c(11, 'clubs'), c(9, 'spades')])
    expect(gt(pair, highCard)).toBe(true)
  })
})

describe('the wheel (A-2-3-4-5)', () => {
  test('is a straight, not ace-high', () => {
    const wheel = bestHand([c(14, 'spades'), c(2, 'hearts'), c(3, 'diamonds'), c(4, 'clubs'), c(5, 'spades')])
    expect(wheel.category).toBe('straight')
    expect(wheel.tiebreakers).toEqual([5])
  })

  test('loses to a six-high straight', () => {
    const wheel = bestHand([c(14, 'spades'), c(2, 'hearts'), c(3, 'diamonds'), c(4, 'clubs'), c(5, 'spades')])
    const sixHigh = bestHand([c(2, 'spades'), c(3, 'hearts'), c(4, 'diamonds'), c(5, 'clubs'), c(6, 'spades')])
    expect(gt(sixHigh, wheel)).toBe(true)
  })

  test('flush is a straight flush, not a high-card flush', () => {
    const wheel = bestHand([c(14, 'spades'), c(2, 'spades'), c(3, 'spades'), c(4, 'spades'), c(5, 'spades')])
    expect(wheel.category).toBe('straightFlush')
    expect(wheel.tiebreakers).toEqual([5])
  })

  test('A-2-3-4-6 (skips 5) is not a straight', () => {
    const notAStraight = bestHand([c(14, 'spades'), c(2, 'hearts'), c(3, 'diamonds'), c(4, 'clubs'), c(6, 'spades')])
    expect(notAStraight.category).toBe('highCard')
  })
})

describe('kicker tie-breaks within a category', () => {
  test('higher pair beats lower pair', () => {
    const acePair = bestHand([c(14, 'spades'), c(14, 'hearts'), c(2, 'diamonds'), c(3, 'clubs'), c(4, 'spades')])
    const kingPair = bestHand([c(13, 'spades'), c(13, 'hearts'), c(12, 'diamonds'), c(11, 'clubs'), c(10, 'spades')])
    expect(gt(acePair, kingPair)).toBe(true)
  })

  test('same pair, higher kicker wins', () => {
    const jackKicker = bestHand([c(2, 'spades'), c(2, 'hearts'), c(11, 'diamonds'), c(4, 'clubs'), c(3, 'spades')])
    const tenKicker = bestHand([c(2, 'clubs'), c(2, 'diamonds'), c(10, 'spades'), c(4, 'hearts'), c(3, 'diamonds')])
    expect(gt(jackKicker, tenKicker)).toBe(true)
  })

  test('higher top pair in two pair wins', () => {
    const acesAndTwos = bestHand([c(14, 'spades'), c(14, 'hearts'), c(2, 'diamonds'), c(2, 'clubs'), c(13, 'spades')])
    const kingsAndQueens = bestHand([c(13, 'clubs'), c(13, 'diamonds'), c(12, 'spades'), c(12, 'hearts'), c(14, 'clubs')])
    expect(gt(acesAndTwos, kingsAndQueens)).toBe(true)
  })

  test('same top pair, higher second pair wins', () => {
    const acesAndKings = bestHand([c(14, 'spades'), c(14, 'hearts'), c(13, 'diamonds'), c(13, 'clubs'), c(2, 'spades')])
    const acesAndQueens = bestHand([c(14, 'clubs'), c(14, 'diamonds'), c(12, 'spades'), c(12, 'hearts'), c(3, 'clubs')])
    expect(gt(acesAndKings, acesAndQueens)).toBe(true)
  })

  test('full house trips rank breaks the tie', () => {
    const acesFullOfTwos = bestHand([c(14, 'spades'), c(14, 'hearts'), c(14, 'diamonds'), c(2, 'clubs'), c(2, 'spades')])
    const kingsFullOfQueens = bestHand([c(13, 'clubs'), c(13, 'diamonds'), c(13, 'hearts'), c(12, 'spades'), c(12, 'clubs')])
    expect(gt(acesFullOfTwos, kingsFullOfQueens)).toBe(true)
  })

  test('same trips, higher pair breaks the full house tie (7-card path)', () => {
    const acesFullOfKings = bestHand([
      c(14, 'spades'), c(14, 'hearts'), c(14, 'diamonds'),
      c(13, 'clubs'), c(13, 'spades'), c(2, 'clubs'), c(3, 'diamonds'),
    ])
    const acesFullOfQueens = bestHand([
      c(14, 'clubs'), c(14, 'diamonds'), c(14, 'hearts'),
      c(12, 'spades'), c(12, 'hearts'), c(2, 'spades'), c(3, 'clubs'),
    ])
    expect(gt(acesFullOfKings, acesFullOfQueens)).toBe(true)
  })

  test('flush high card breaks the tie', () => {
    const aceHighFlush = bestHand([c(14, 'spades'), c(11, 'spades'), c(8, 'spades'), c(5, 'spades'), c(2, 'spades')])
    const kingHighFlush = bestHand([c(13, 'hearts'), c(12, 'hearts'), c(9, 'hearts'), c(6, 'hearts'), c(3, 'hearts')])
    expect(gt(aceHighFlush, kingHighFlush)).toBe(true)
  })

  test('high card kickers break the tie in order', () => {
    const higherSecondCard = bestHand([c(14, 'spades'), c(11, 'hearts'), c(8, 'diamonds'), c(5, 'clubs'), c(2, 'spades')])
    const lowerSecondCard = bestHand([c(14, 'clubs'), c(10, 'diamonds'), c(9, 'spades'), c(6, 'hearts'), c(3, 'clubs')])
    expect(gt(higherSecondCard, lowerSecondCard)).toBe(true)
  })

  test('identical ranks are equal regardless of suit', () => {
    const a = bestHand([c(14, 'spades'), c(13, 'hearts'), c(12, 'diamonds'), c(11, 'clubs'), c(9, 'spades')])
    const b = bestHand([c(14, 'hearts'), c(13, 'clubs'), c(12, 'spades'), c(11, 'diamonds'), c(9, 'hearts')])
    expect(eq(a, b)).toBe(true)
  })
})

describe('7-card best-of selection', () => {
  test('picks the best five, ignoring the rest', () => {
    const hand = bestHand([
      c(2, 'clubs'), c(3, 'diamonds'), // "hole cards" — junk, no pair, no flush help
      c(4, 'spades'), c(6, 'spades'), c(8, 'spades'), c(10, 'spades'), c(12, 'spades'),
    ])
    expect(hand.category).toBe('flush')
    expect(hand.tiebreakers).toEqual([12, 10, 8, 6, 4])
  })

  test('finds the straight flush over the simple flush', () => {
    const hand = bestHand([
      c(9, 'spades'), c(14, 'hearts'),
      c(5, 'spades'), c(6, 'spades'), c(7, 'spades'), c(8, 'spades'), c(2, 'diamonds'),
    ])
    expect(hand.category).toBe('straightFlush')
    expect(hand.tiebreakers).toEqual([9])
  })

  test('6-card hand picks the best five', () => {
    const hand = bestHand([
      c(2, 'clubs'),
      c(14, 'spades'), c(14, 'hearts'), c(14, 'diamonds'), c(13, 'clubs'), c(13, 'spades'),
    ])
    expect(hand.category).toBe('fullHouse')
    expect(hand.tiebreakers).toEqual([14, 13])
  })
})
