// Hand-written PokerStars-format fixtures (not real hand histories), built to exercise
// `classifyHand`'s spot-classification logic end to end through the real parser
// (`parseHandHistory`), not by hand-constructing `ParsedHand` objects directly. Every
// fixture uses one of two anchor hands relied on throughout this codebase's own test
// suite (see e.g. threeBetRange.test.ts's "AA always 3-bets for value" / "72o folds"):
// AA is the top-ranked hand by Chen score and so is guaranteed to fall in the *aggressive*
// bucket of every one of these range models regardless of the exact threshold; 72o is the
// bottom-ranked hand and is guaranteed to fall in the *fold* bucket of every one of them.
// Pairing each anchor with the *opposite* real action produces a guaranteed, threshold-
// independent leak — no need to hand-verify exact percentages to know the fixture is right.
//
// Table shape is fixed across every fixture: 6-max, button always seat 1, so seats map to
// positions 1:1 — Seat 1 BTN, 2 SB, 3 BB, 4 UTG, 5 HJ, 6 CO (see handHistory.test.ts's
// own `positionLabelsForEverySeatAtEachTableSize`, which validates this exact mapping).

import { describe, expect, test } from 'vitest'
import { parseHandHistory } from '../lib/handHistory'
import { analyzeLeaks, classifyHand, type CoveredLeakResult } from './leakFinder'

function buildHand(opts: {
  handId: string
  bigBlind: number
  heroSeat: number
  heroCards: string
  stacks?: Partial<Record<number, number>>
  preflop: string[]
}): string {
  const { handId, bigBlind, heroSeat, heroCards, stacks = {}, preflop } = opts
  const smallBlind = bigBlind / 2
  const names = Array.from({ length: 6 }, (_, i) => (i + 1 === heroSeat ? 'Hero' : `P${i + 1}`))
  const lines = [
    `PokerStars Hand #${handId}: Tournament #700000, $10+$1 USD Hold'em No Limit - Level I (${smallBlind}/${bigBlind}) - 2026/03/01 10:00:00 ET`,
    `Table '700000 1' 6-max Seat #1 is the button`,
  ]
  for (let seat = 1; seat <= 6; seat++) {
    lines.push(`Seat ${seat}: ${names[seat - 1]} (${stacks[seat] ?? 100000} in chips)`)
  }
  lines.push(`${names[1]}: posts small blind ${smallBlind}`)
  lines.push(`${names[2]}: posts big blind ${bigBlind}`)
  lines.push('*** HOLE CARDS ***')
  lines.push(`Dealt to Hero [${heroCards}]`)
  lines.push(...preflop)
  return lines.join('\n')
}

function firstHand(text: string) {
  const file = parseHandHistory(text)
  expect(file.hands.length, 'fixture should parse to exactly one hand').toBe(1)
  return file.hands[0]
}

const AA = 'Ah Ad'
const SEVEN_DEUCE = '7h 2d'

describe('leakFinder: push/fold spots', () => {
  test('AA shoves UTG at 10bb: correct push', () => {
    const hand = firstHand(
      buildHand({ handId: '1', bigBlind: 200, heroSeat: 4, heroCards: AA, stacks: { 4: 2000 }, preflop: ['Hero: raises 1800 to 2000 and is all-in'] }),
    )
    const result = classifyHand(hand)
    expect(result.covered).toBe(true)
    const r = result as CoveredLeakResult
    expect(r.mode).toBe('pushFold')
    expect(r.stackBB).toBeCloseTo(10)
    expect(r.correctAction).toBe('push')
    expect(r.heroAction).toBe('push')
    expect(r.isCorrect).toBe(true)
  })

  test('AA folds UTG at 10bb: missed-shove leak', () => {
    const hand = firstHand(buildHand({ handId: '2', bigBlind: 200, heroSeat: 4, heroCards: AA, stacks: { 4: 2000 }, preflop: ['Hero: folds'] }))
    const r = classifyHand(hand) as CoveredLeakResult
    expect(r.covered).toBe(true)
    expect(r.mode).toBe('pushFold')
    expect(r.correctAction).toBe('push')
    expect(r.heroAction).toBe('fold')
    expect(r.isCorrect).toBe(false)
  })

  test('72o shoves UTG at 10bb: over-shove leak', () => {
    const hand = firstHand(
      buildHand({
        handId: '3',
        bigBlind: 200,
        heroSeat: 4,
        heroCards: SEVEN_DEUCE,
        stacks: { 4: 2000 },
        preflop: ['Hero: raises 1800 to 2000 and is all-in'],
      }),
    )
    const r = classifyHand(hand) as CoveredLeakResult
    expect(r.covered).toBe(true)
    expect(r.mode).toBe('pushFold')
    expect(r.correctAction).toBe('fold')
    expect(r.heroAction).toBe('push')
    expect(r.isCorrect).toBe(false)
  })
})

describe('leakFinder: opening spots', () => {
  test('AA opens the button at 100bb: correct raise', () => {
    const hand = firstHand(buildHand({ handId: '4', bigBlind: 100, heroSeat: 1, heroCards: AA, stacks: { 1: 10000 }, preflop: ['Hero: raises 100 to 250'] }))
    const r = classifyHand(hand) as CoveredLeakResult
    expect(r.covered).toBe(true)
    expect(r.mode).toBe('opening')
    expect(r.stackBB).toBeCloseTo(100)
    expect(r.correctAction).toBe('raise')
    expect(r.heroAction).toBe('raise')
    expect(r.isCorrect).toBe(true)
  })

  test('72o opens the button at 100bb: over-open leak', () => {
    const hand = firstHand(
      buildHand({ handId: '5', bigBlind: 100, heroSeat: 1, heroCards: SEVEN_DEUCE, stacks: { 1: 10000 }, preflop: ['Hero: raises 100 to 250'] }),
    )
    const r = classifyHand(hand) as CoveredLeakResult
    expect(r.covered).toBe(true)
    expect(r.mode).toBe('opening')
    expect(r.correctAction).toBe('fold')
    expect(r.heroAction).toBe('raise')
    expect(r.isCorrect).toBe(false)
  })
})

describe('leakFinder: facing-shove spots', () => {
  test('AA calls a UTG shove from the BB at ~10bb effective: correct call', () => {
    const hand = firstHand(
      buildHand({
        handId: '6',
        bigBlind: 200,
        heroSeat: 3,
        heroCards: AA,
        stacks: { 3: 3000, 4: 2000 },
        preflop: ['P4: raises 1800 to 2000 and is all-in', 'Hero: calls 2000'],
      }),
    )
    const r = classifyHand(hand) as CoveredLeakResult
    expect(r.covered).toBe(true)
    expect(r.mode).toBe('facingShove')
    expect(r.stackBB).toBeCloseTo(10)
    expect(r.correctAction).toBe('call')
    expect(r.heroAction).toBe('call')
    expect(r.isCorrect).toBe(true)
  })

  test('AA folds to the same shove: missed-call leak', () => {
    const hand = firstHand(
      buildHand({
        handId: '7',
        bigBlind: 200,
        heroSeat: 3,
        heroCards: AA,
        stacks: { 3: 3000, 4: 2000 },
        preflop: ['P4: raises 1800 to 2000 and is all-in', 'Hero: folds'],
      }),
    )
    const r = classifyHand(hand) as CoveredLeakResult
    expect(r.covered).toBe(true)
    expect(r.mode).toBe('facingShove')
    expect(r.correctAction).toBe('call')
    expect(r.heroAction).toBe('fold')
    expect(r.isCorrect).toBe(false)
  })

  test('72o calls the same shove: over-call leak', () => {
    const hand = firstHand(
      buildHand({
        handId: '8',
        bigBlind: 200,
        heroSeat: 3,
        heroCards: SEVEN_DEUCE,
        stacks: { 3: 3000, 4: 2000 },
        preflop: ['P4: raises 1800 to 2000 and is all-in', 'Hero: calls 2000'],
      }),
    )
    const r = classifyHand(hand) as CoveredLeakResult
    expect(r.covered).toBe(true)
    expect(r.mode).toBe('facingShove')
    expect(r.correctAction).toBe('fold')
    expect(r.heroAction).toBe('call')
    expect(r.isCorrect).toBe(false)
  })
})

describe('leakFinder: facing-open spots', () => {
  test('AA 3-bets a UTG open from the BB at 100bb: correct threeBet', () => {
    const hand = firstHand(
      buildHand({
        handId: '9',
        bigBlind: 100,
        heroSeat: 3,
        heroCards: AA,
        stacks: { 3: 10000, 4: 10000 },
        preflop: ['P4: raises 100 to 250', 'Hero: raises 250 to 800'],
      }),
    )
    const r = classifyHand(hand) as CoveredLeakResult
    expect(r.covered).toBe(true)
    expect(r.mode).toBe('facingOpen')
    expect(r.stackBB).toBeCloseTo(100)
    expect(r.correctAction).toBe('threeBet')
    expect(r.heroAction).toBe('threeBet')
    expect(r.isCorrect).toBe(true)
  })

  test('AA folds to the same open: missed-defense leak', () => {
    const hand = firstHand(
      buildHand({
        handId: '10',
        bigBlind: 100,
        heroSeat: 3,
        heroCards: AA,
        stacks: { 3: 10000, 4: 10000 },
        preflop: ['P4: raises 100 to 250', 'Hero: folds'],
      }),
    )
    const r = classifyHand(hand) as CoveredLeakResult
    expect(r.covered).toBe(true)
    expect(r.mode).toBe('facingOpen')
    expect(r.correctAction).toBe('threeBet')
    expect(r.heroAction).toBe('fold')
    expect(r.isCorrect).toBe(false)
  })

  test('72o 3-bets the same open: over-defense leak', () => {
    const hand = firstHand(
      buildHand({
        handId: '11',
        bigBlind: 100,
        heroSeat: 3,
        heroCards: SEVEN_DEUCE,
        stacks: { 3: 10000, 4: 10000 },
        preflop: ['P4: raises 100 to 250', 'Hero: raises 250 to 800'],
      }),
    )
    const r = classifyHand(hand) as CoveredLeakResult
    expect(r.covered).toBe(true)
    expect(r.mode).toBe('facingOpen')
    expect(r.correctAction).toBe('fold')
    expect(r.heroAction).toBe('threeBet')
    expect(r.isCorrect).toBe(false)
  })
})

describe('leakFinder: 4-bet spots', () => {
  test('hero (AA) opens CO, gets 3-bet by BTN, 4-bets at 100bb: correct fourBet', () => {
    const hand = firstHand(
      buildHand({
        handId: '12',
        bigBlind: 100,
        heroSeat: 6,
        heroCards: AA,
        stacks: { 6: 10000, 1: 10000 },
        preflop: ['Hero: raises 100 to 250', 'P1: raises 250 to 800', 'Hero: raises 800 to 2000 and is all-in'],
      }),
    )
    const r = classifyHand(hand) as CoveredLeakResult
    expect(r.covered).toBe(true)
    expect(r.mode).toBe('fourBet')
    expect(r.stackBB).toBeCloseTo(100)
    expect(r.correctAction).toBe('fourBet')
    expect(r.heroAction).toBe('fourBet')
    expect(r.isCorrect).toBe(true)
    // The opening raise itself isn't separately graded — only the 4-bet decision.
    expect(r.handId).toBe('12')
  })

  test('hero (AA) folds to the 3-bet instead: missed-4-bet leak', () => {
    const hand = firstHand(
      buildHand({
        handId: '13',
        bigBlind: 100,
        heroSeat: 6,
        heroCards: AA,
        stacks: { 6: 10000, 1: 10000 },
        preflop: ['Hero: raises 100 to 250', 'P1: raises 250 to 800', 'Hero: folds'],
      }),
    )
    const r = classifyHand(hand) as CoveredLeakResult
    expect(r.covered).toBe(true)
    expect(r.mode).toBe('fourBet')
    expect(r.correctAction).toBe('fourBet')
    expect(r.heroAction).toBe('fold')
    expect(r.isCorrect).toBe(false)
  })

  test('hero (72o) 4-bets over the 3-bet instead: over-4-bet leak', () => {
    const hand = firstHand(
      buildHand({
        handId: '14',
        bigBlind: 100,
        heroSeat: 6,
        heroCards: SEVEN_DEUCE,
        stacks: { 6: 10000, 1: 10000 },
        preflop: ['Hero: raises 100 to 250', 'P1: raises 250 to 800', 'Hero: raises 800 to 2000 and is all-in'],
      }),
    )
    const r = classifyHand(hand) as CoveredLeakResult
    expect(r.covered).toBe(true)
    expect(r.mode).toBe('fourBet')
    expect(r.correctAction).toBe('fold')
    expect(r.heroAction).toBe('fourBet')
    expect(r.isCorrect).toBe(false)
  })
})

describe('leakFinder: spots that are not covered', () => {
  test('big blind walk/isolate over limpers is not a charted spot', () => {
    const hand = firstHand(
      buildHand({
        handId: '15',
        bigBlind: 100,
        heroSeat: 3,
        heroCards: AA,
        preflop: ['P4: folds', 'P5: folds', 'P6: folds', 'P1: folds', 'P2: calls 50', 'Hero: checks'],
      }),
    )
    const r = classifyHand(hand)
    expect(r.covered).toBe(false)
    expect(r.covered === false && r.reason).toMatch(/big blind/i)
  })

  test('facing more than one raise before ever acting is not a charted spot', () => {
    const hand = firstHand(
      buildHand({
        handId: '16',
        bigBlind: 100,
        heroSeat: 6,
        heroCards: AA,
        preflop: ['P4: raises 100 to 250', 'P5: raises 250 to 800', 'Hero: folds'],
      }),
    )
    const r = classifyHand(hand)
    expect(r.covered).toBe(false)
    expect(r.covered === false && r.reason).toMatch(/more than one raise/i)
  })

  test('an effective stack outside every chart\'s range is not covered', () => {
    const hand = firstHand(
      buildHand({ handId: '17', bigBlind: 100, heroSeat: 4, heroCards: AA, stacks: { 4: 15000 }, preflop: ['Hero: raises 100 to 250'] }),
    )
    const r = classifyHand(hand)
    expect(r.covered).toBe(false)
    expect(r.covered === false && r.reason).toMatch(/1-100bb/)
  })

  test('a hand with no hero decision at all is not covered', () => {
    // Hero posts the big blind and everyone folds before hero ever needs to act.
    const hand = firstHand(
      buildHand({ handId: '18', bigBlind: 100, heroSeat: 3, heroCards: AA, preflop: ['P4: folds', 'P5: folds', 'P6: folds', 'P1: folds', 'P2: folds'] }),
    )
    const r = classifyHand(hand)
    expect(r.covered).toBe(false)
  })
})

describe('leakFinder: analyzeLeaks aggregate report', () => {
  test('aggregates covered/not-covered counts, per-mode and per-position accuracy, and misplays', () => {
    const texts = [
      buildHand({ handId: '20', bigBlind: 200, heroSeat: 4, heroCards: AA, stacks: { 4: 2000 }, preflop: ['Hero: raises 1800 to 2000 and is all-in'] }), // pushFold correct
      buildHand({ handId: '21', bigBlind: 200, heroSeat: 4, heroCards: AA, stacks: { 4: 2000 }, preflop: ['Hero: folds'] }), // pushFold leak
      buildHand({ handId: '22', bigBlind: 100, heroSeat: 1, heroCards: AA, stacks: { 1: 10000 }, preflop: ['Hero: raises 100 to 250'] }), // opening correct
      buildHand({
        handId: '23',
        bigBlind: 100,
        heroSeat: 6,
        heroCards: AA,
        preflop: ['P4: raises 100 to 250', 'P5: raises 250 to 800', 'Hero: folds'],
      }), // not covered
    ]
    const hands = texts.map((t) => firstHand(t))
    const report = analyzeLeaks(hands)

    expect(report.totalHands).toBe(4)
    expect(report.coveredCount).toBe(3)
    expect(report.notCoveredCount).toBe(1)
    expect(report.correctCount).toBe(2)
    expect(report.accuracy).toBeCloseTo(2 / 3)

    const pushFoldStats = report.byMode.find((m) => m.mode === 'pushFold')!
    expect(pushFoldStats.total).toBe(2)
    expect(pushFoldStats.correct).toBe(1)

    const openingStats = report.byMode.find((m) => m.mode === 'opening')!
    expect(openingStats.total).toBe(1)
    expect(openingStats.correct).toBe(1)

    const utgStats = report.byPosition.find((p) => p.position === 'UTG')!
    expect(utgStats.total).toBe(2)
    expect(utgStats.correct).toBe(1)

    expect(report.misplayedHands.length).toBe(1)
    expect(report.misplayedHands[0].handId).toBe('21')
  })

  test('results carries one entry per input hand, in order', () => {
    const texts = [
      buildHand({ handId: '30', bigBlind: 200, heroSeat: 4, heroCards: AA, stacks: { 4: 2000 }, preflop: ['Hero: raises 1800 to 2000 and is all-in'] }),
      buildHand({
        handId: '31',
        bigBlind: 100,
        heroSeat: 6,
        heroCards: AA,
        preflop: ['P4: raises 100 to 250', 'P5: raises 250 to 800', 'Hero: folds'],
      }),
    ]
    const hands = texts.map((t) => firstHand(t))
    const report = analyzeLeaks(hands)
    expect(report.results.length).toBe(2)
    expect(report.results.map((r) => r.handId)).toEqual(['30', '31'])
    expect(report.results[0].covered).toBe(true)
    expect(report.results[1].covered).toBe(false)
  })

  test('an empty hand list reports undefined accuracy, not 0%', () => {
    const report = analyzeLeaks([])
    expect(report.totalHands).toBe(0)
    expect(report.accuracy).toBeUndefined()
    expect(report.byMode).toEqual([])
    expect(report.misplayedHands).toEqual([])
  })
})
