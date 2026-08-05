// Port of PokerKit/Tests/PokerKitTests/HandHistoryParserTests.swift — same fixtures, same
// expected results, so this TS parser inherits the Swift parser's correctness rather than
// re-deriving it from scratch. Fixtures are hand-written, representative PokerStars-format
// sample text (not real hand histories); money amounts are chosen so the pot arithmetic is
// exact and easy to hand-verify in the comments below each fixture.

import { describe, expect, test } from 'vitest'
import { rankSymbol, suitSymbol } from '../engine/card'
import { holeCardsNotation } from '../engine/holeCards'
import {
  heroSawFlop,
  heroWonHand,
  parseHandHistory,
  positionLabelForSeat,
  sessionBountiesWon,
  sessionHandsWithFlopSeen,
  sessionNetChips,
  sessionsFromHands,
} from './handHistory'

/** Hero (severeduck) opens from the cutoff, gets called by the big blind, then wins the
 * pot with an uncalled flop c-bet. 6-max, button on seat 4.
 *
 * Preflop: SB posts 25 (dead), BB posts 50 then calls 50 more to 100 total, hero (CO)
 * raises to 100. Pot after preflop = 25 + 100 + 100 = 225.
 * Flop: hero bets 150, BB folds, bet returned, hero collects the 225 pot.
 * Hero invested 100 (preflop) + 150 (flop, returned) = 250; hero received 150 (returned)
 * + 225 (collected) = 375. Net = +125. */
const heroWinsWithFlopCBet = `PokerStars Hand #250001: Tournament #900001, $10+$1 USD Hold'em No Limit - Level V (25/50) - 2026/02/01 18:05:11 ET
Table '900001 1' 6-max Seat #4 is the button
Seat 1: Player1 (3000 in chips)
Seat 2: Player2 (1500 in chips)
Seat 3: severeduck (2500 in chips)
Seat 4: Player4 (5000 in chips)
Seat 5: Player5 (2000 in chips)
Seat 6: Player6 (1800 in chips)
Player5: posts small blind 25
Player6: posts big blind 50
*** HOLE CARDS ***
Dealt to severeduck [Ah Kd]
Player1: folds
Player2: folds
severeduck: raises 50 to 100
Player4: folds
Player5: folds
Player6: calls 50
*** FLOP *** [2h 7d Jc]
Player6: checks
severeduck: bets 150
Player6: folds
Uncalled bet (150) returned to severeduck
severeduck collected 225 from pot
*** SUMMARY ***
Total pot 225 | Rake 0
Board [2h 7d Jc]
Seat 1: Player1 folded before Flop (didn't bet)
Seat 2: Player2 folded before Flop (didn't bet)
Seat 3: severeduck collected (225)
Seat 4: Player4 (button) folded before Flop (didn't bet)
Seat 5: Player5 (small blind) folded before Flop
Seat 6: Player6 (big blind) folded on the Flop`

/** Hero folds preflop and never sees a flop. Same table shape, button on seat 4, hero on
 * seat 1 (UTG). */
const heroFoldsPreflop = `PokerStars Hand #250002: Tournament #900001, $10+$1 USD Hold'em No Limit - Level V (25/50) - 2026/02/01 18:07:41 ET
Table '900001 1' 6-max Seat #4 is the button
Seat 1: severeduck (2600 in chips)
Seat 2: Player2 (1500 in chips)
Seat 3: Player3 (2500 in chips)
Seat 4: Player4 (5000 in chips)
Seat 5: Player5 (2000 in chips)
Seat 6: Player6 (1800 in chips)
Player5: posts small blind 25
Player6: posts big blind 50
*** HOLE CARDS ***
Dealt to severeduck [7c 2d]
severeduck: folds
Player2: folds
Player3: raises 100 to 150
Player4: folds
Player5: folds
Player6: folds
Uncalled bet (100) returned to Player3
Player3 collected 175 from pot
*** SUMMARY ***
Total pot 175 | Rake 0
Seat 1: severeduck folded before Flop (didn't bet)
Seat 2: Player2 folded before Flop (didn't bet)
Seat 3: Player3 collected (175)
Seat 4: Player4 (button) folded before Flop (didn't bet)
Seat 5: Player5 (small blind) folded before Flop
Seat 6: Player6 (big blind) folded before Flop`

/** PKO bounty hand: hero (button, seat 2) shoves over a short stack's all-in re-raise,
 * both go to showdown, hero wins the pot and the opponent's bounty. Seats are
 * deliberately non-contiguous (1, 2, 3, 5) to exercise the gap-tolerant position mapping.
 *
 * Preflop: SB posts 25 (dead), ShortStack (BB) posts 50 then raises to 450 (all-in,
 * +400), hero raises to 150 then calls the extra 300 to 450. Pot = 25 + 450 + 450 = 925.
 * Hero invested 450, hero collected 925 back. Net = +475. Bounty: +3.00. */
const heroWinsBountyAtShowdown = `PokerStars Hand #250003: Tournament #900002, $20+$5+$5 USD Hold'em No Limit PKO - Level II (25/50) - 2026/02/02 09:15:00 ET
Table '900002 1' 9-max Seat #2 is the button
Seat 1: Player1 (4000 in chips, $5.00 bounty)
Seat 2: severeduck (3000 in chips, $6.00 bounty)
Seat 3: Player3 (2200 in chips, $5.00 bounty)
Seat 5: ShortStack (450 in chips, $3.00 bounty)
Player3: posts small blind 25
ShortStack: posts big blind 50
*** HOLE CARDS ***
Dealt to severeduck [Kc Kh]
Player1: folds
severeduck: raises 100 to 150
Player3: folds
ShortStack: raises 400 to 450 and is all-in
severeduck: calls 300
*** FLOP *** [2h 7d Jc]
*** TURN *** [2h 7d Jc] [4s]
*** RIVER *** [2h 7d Jc 4s] [9d]
*** SHOW DOWN ***
severeduck: shows [Kc Kh] (a pair of Kings)
ShortStack: shows [Ac Qd] (high card Ace)
severeduck collected 925 from pot
ShortStack finished the tournament in 27th place
severeduck wins $3.00 for eliminating ShortStack and their own bounty increases by $3.00 to $9.00
*** SUMMARY ***
Total pot 925 | Rake 0
Board [2h 7d Jc 4s 9d]
Seat 1: Player1 (cutoff) folded before Flop (didn't bet)
Seat 2: severeduck (button) showed [Kc Kh] and won (925) with a pair of Kings
Seat 3: Player3 (small blind) folded before Flop
Seat 5: ShortStack (big blind) showed [Ac Qd] and lost with high card Ace`

const garbageBlock = `PokerStars Hand #999999: Tournament #1, garbage line with no seats, no button, no hole cards
This is not a valid hand history body at all.`

describe('handHistory: hero wins with a flop c-bet', () => {
  test('parses header fields', () => {
    const file = parseHandHistory(heroWinsWithFlopCBet)
    expect(file.hands.length).toBe(1)
    const hand = file.hands[0]
    expect(hand.handId).toBe('250001')
    expect(hand.tournamentId).toBe('900001')
    expect(hand.smallBlind).toBe(25)
    expect(hand.bigBlind).toBe(50)
    expect(hand.date).toBeDefined()
  })

  test('parses hero hole cards and stack', () => {
    const hand = parseHandHistory(heroWinsWithFlopCBet).hands[0]
    expect(hand.heroName).toBe('severeduck')
    expect(hand.heroSeat).toBe(3)
    expect(hand.heroStartingStack).toBe(2500)
    expect(hand.heroHoleCards).toBeDefined()
    expect(holeCardsNotation(hand.heroHoleCards!)).toBe('AKo')
  })

  test('detects position for a 6-max table', () => {
    const hand = parseHandHistory(heroWinsWithFlopCBet).hands[0]
    // Button is seat 4; hero on seat 3 is one seat before the button: cutoff.
    expect(hand.heroPosition).toBe('CO')
  })

  test('parses board and actions per street', () => {
    const hand = parseHandHistory(heroWinsWithFlopCBet).hands[0]
    expect(hand.board.map((c) => `${rankSymbol(c.rank)}${suitSymbol(c.suit)}`)).toEqual(['2♥', '7♦', 'J♣'])

    const heroActions = hand.actions.filter((a) => a.player === 'severeduck')
    expect(heroActions.map((a) => a.street)).toEqual(['preflop', 'flop'])
    expect(heroActions.map((a) => a.kind)).toEqual(['raise', 'bet'])
  })

  test('computes hero net chips and result', () => {
    const hand = parseHandHistory(heroWinsWithFlopCBet).hands[0]
    expect(hand.heroNetChips).toBe(125)
    expect(heroWonHand(hand)).toBe(true)
    expect(heroSawFlop(hand)).toBe(true)
    expect(hand.heroBountyWon).toBeUndefined()
  })

  test('every seat is recorded, not just hero', () => {
    const hand = parseHandHistory(heroWinsWithFlopCBet).hands[0]
    expect(hand.seats.length).toBe(6)
    expect(hand.buttonSeat).toBe(4)
    expect(positionLabelForSeat(hand.seats, hand.buttonSeat!, 6)).toBe('BB')
  })
})

describe('handHistory: hero folds preflop', () => {
  test('folded-preflop hand never sees a flop', () => {
    const hand = parseHandHistory(heroFoldsPreflop).hands[0]
    expect(hand.board.length).toBe(0)
    expect(heroSawFlop(hand)).toBe(false)
    expect(hand.heroNetChips).toBe(0)
    expect(heroWonHand(hand)).toBe(false)
    expect(hand.heroPosition).toBe('UTG')
  })
})

describe('handHistory: bounty / PKO hand', () => {
  test('parses bounty and net chips for a knockout hand', () => {
    const hand = parseHandHistory(heroWinsBountyAtShowdown).hands[0]
    expect(hand.heroBountyWon).toBe(3.0)
    expect(hand.heroNetChips).toBe(475)
    expect(heroWonHand(hand)).toBe(true)
  })

  test('an all-in preflop runout still counts as seeing the flop', () => {
    // Both players are all-in preflop, so PokerStars logs zero action lines on the
    // flop/turn/river — hero must still be marked as having seen the flop.
    const hand = parseHandHistory(heroWinsBountyAtShowdown).hands[0]
    expect(heroSawFlop(hand)).toBe(true)
    expect(hand.board.length).toBe(5)
  })

  test('detects position with non-contiguous seat numbers', () => {
    // Seats present are 1, 2, 3, 5 (seat 4 is empty); button is seat 2.
    const hand = parseHandHistory(heroWinsBountyAtShowdown).hands[0]
    expect(hand.heroSeat).toBe(2)
    expect(hand.heroPosition).toBe('BTN')
  })

  test("every player's position is derivable, not just hero's", () => {
    const hand = parseHandHistory(heroWinsBountyAtShowdown).hands[0]
    expect(positionLabelForSeat(hand.seats, hand.buttonSeat!, 1)).toBe('CO')
    expect(positionLabelForSeat(hand.seats, hand.buttonSeat!, 3)).toBe('SB')
    expect(positionLabelForSeat(hand.seats, hand.buttonSeat!, 5)).toBe('BB')
  })
})

describe('handHistory: malformed input', () => {
  test('malformed hand is skipped, not crashed', () => {
    const file = parseHandHistory(garbageBlock)
    expect(file.hands.length).toBe(0)
    expect(file.skipped.length).toBe(1)
    expect(file.skipped[0].reason.length).toBeGreaterThan(0)
  })

  test('file with no recognizable hands produces an empty result', () => {
    const file = parseHandHistory('just some random notes\nnothing poker-shaped here\n')
    expect(file.hands.length).toBe(0)
    expect(file.skipped.length).toBe(0)
  })

  test('malformed hand does not prevent others from parsing', () => {
    const combined = [heroWinsWithFlopCBet, garbageBlock, heroFoldsPreflop].join('\n\n')
    const file = parseHandHistory(combined)
    expect(file.hands.length).toBe(2)
    expect(file.skipped.length).toBe(1)
    expect(new Set(file.hands.map((h) => h.handId))).toEqual(new Set(['250001', '250002']))
  })
})

describe('handHistory: session grouping', () => {
  test('groups hands into sessions by tournament id', () => {
    const combined = [heroWinsWithFlopCBet, heroFoldsPreflop, heroWinsBountyAtShowdown].join('\n\n')
    const file = parseHandHistory(combined)
    const sessions = sessionsFromHands(file.hands)
    expect(sessions.length).toBe(2)

    const session900001 = sessions.find((s) => s.tournamentId === '900001')
    expect(session900001?.hands.length).toBe(2)
    expect(session900001 ? sessionNetChips(session900001) : undefined).toBe(125)
    expect(session900001 ? sessionHandsWithFlopSeen(session900001) : undefined).toBe(1)

    const session900002 = sessions.find((s) => s.tournamentId === '900002')
    expect(session900002?.hands.length).toBe(1)
    expect(session900002 ? sessionBountiesWon(session900002) : undefined).toBe(3.0)
  })
})

describe('handHistory: position mapping across table sizes', () => {
  function minimalHand(handId: string, seats: { seat: number; name: string }[], buttonSeat: number, heroSeat: number): string {
    const heroName = seats.find((s) => s.seat === heroSeat)!.name
    const lines = [
      `PokerStars Hand #${handId}: Tournament #999000, $5+$0.50 USD Hold'em No Limit - Level I (10/20) - 2026/01/01 12:00:00 ET`,
      `Table '999000 1' 9-max Seat #${buttonSeat} is the button`,
    ]
    for (const seat of [...seats].sort((a, b) => a.seat - b.seat)) {
      lines.push(`Seat ${seat.seat}: ${seat.name} (1500 in chips)`)
    }
    lines.push('*** HOLE CARDS ***')
    lines.push(`Dealt to ${heroName} [2c 3d]`)
    return lines.join('\n')
  }

  test('position labels for every seat at each table size', () => {
    const expectedLabelsByCount: Record<number, string[]> = {
      2: ['BTN', 'BB'],
      3: ['BTN', 'SB', 'BB'],
      4: ['BTN', 'SB', 'BB', 'CO'],
      5: ['BTN', 'SB', 'BB', 'HJ', 'CO'],
      6: ['BTN', 'SB', 'BB', 'UTG', 'HJ', 'CO'],
      7: ['BTN', 'SB', 'BB', 'UTG', 'MP', 'HJ', 'CO'],
      8: ['BTN', 'SB', 'BB', 'UTG', 'UTG+1', 'MP', 'HJ', 'CO'],
      9: ['BTN', 'SB', 'BB', 'UTG', 'UTG+1', 'MP', 'MP+1', 'HJ', 'CO'],
    }

    for (const [countStr, expectedLabels] of Object.entries(expectedLabelsByCount)) {
      const count = Number(countStr)
      const seats = Array.from({ length: count }, (_, i) => ({ seat: i + 1, name: `Player${i + 1}` }))
      // Button fixed at seat 1: rotation is a no-op, so expectedLabels lines up seat-for-seat.
      for (let seat = 1; seat <= count; seat++) {
        const text = minimalHand(`${count}0${seat}`, seats, 1, seat)
        const hand = parseHandHistory(text).hands[0]
        expect(hand, `seat ${seat} of ${count} should parse`).toBeDefined()
        expect(hand.heroPosition, `seat ${seat} of ${count} expected ${expectedLabels[seat - 1]}, got ${hand.heroPosition}`).toBe(
          expectedLabels[seat - 1],
        )
      }
    }
  })
})
