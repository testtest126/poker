// Preflop drill engine: deals a random spot (hand + position(s) + stack) for one of the
// six range models this app already has opinions on, and grades a user's answer against
// that model's decision. Not a new source of poker knowledge — it's a quiz layer over
// `pushFoldRange.ts` / `openingRange.ts` / `callingRange.ts` / `threeBetRange.ts` /
// `fourBetRange.ts`, so it inherits exactly those models' confidence levels (see
// ai-docs/RANGES.md). No engine file above is modified by this one.
//
// Deliberate simplification: `threeBetRange`/`fourBetRange` distinguish value 3-bets/
// 4-bets from bluff combos, but this drill collapses both into a single "3-Bet"/"4-Bet"
// answer button — asking a beginner to also classify value-vs-bluff is a second skill,
// not this drill's job. `facingOpen` already has only fold/call/3-bet, so no collapsing
// is needed there.

import { FULL_DECK } from './card'
import { type HoleCards, holeCards, holeCardsNotation } from './holeCards'
import { POSITIONS, type Position } from './position'
import { DEFENDING_POSITIONS, type DefendingPosition, defendingActionOrderIndex, positionActionOrderIndex } from './defendingPosition'
import { decidePushFold, pushFoldReasoning } from './pushFoldRange'
import { decideOpening, openingReasoning } from './openingRange'
import { decideVsShove, decideVsOpen, type CallVsShoveDecision, type OpenDefenseDecision } from './callingRange'
import { decideThreeBet, type ThreeBetDecision } from './threeBetRange'
import { decideFourBet, type FourBetDecision } from './fourBetRange'

export type TrainerMode = 'pushFold' | 'opening' | 'facingShove' | 'facingOpen' | 'threeBet' | 'fourBet'

export const TRAINER_MODES: readonly TrainerMode[] = ['pushFold', 'opening', 'facingShove', 'facingOpen', 'threeBet', 'fourBet']

export const TRAINER_MODE_LABEL: Record<TrainerMode, string> = {
  pushFold: 'Push/Fold',
  opening: 'Opening (RFI)',
  facingShove: 'Facing Shove',
  facingOpen: 'Facing Open',
  threeBet: '3-Bet',
  fourBet: '4-Bet',
}

/** The simplified action set a user picks from — collapses value/bluff 3-bets and
 * 4-bets (see file header) into one button each. */
export type TrainerAction = 'push' | 'raise' | 'call' | 'threeBet' | 'fourBet' | 'fold'

export interface TrainerActionOption {
  readonly action: TrainerAction
  readonly label: string
}

export const TRAINER_MODE_ACTIONS: Record<TrainerMode, readonly TrainerActionOption[]> = {
  pushFold: [
    { action: 'push', label: 'Push' },
    { action: 'fold', label: 'Fold' },
  ],
  opening: [
    { action: 'raise', label: 'Raise' },
    { action: 'fold', label: 'Fold' },
  ],
  facingShove: [
    { action: 'call', label: 'Call' },
    { action: 'fold', label: 'Fold' },
  ],
  facingOpen: [
    { action: 'threeBet', label: '3-Bet' },
    { action: 'call', label: 'Call' },
    { action: 'fold', label: 'Fold' },
  ],
  threeBet: [
    { action: 'threeBet', label: '3-Bet' },
    { action: 'call', label: 'Call' },
    { action: 'fold', label: 'Fold' },
  ],
  fourBet: [
    { action: 'fourBet', label: '4-Bet' },
    { action: 'call', label: 'Call' },
    { action: 'fold', label: 'Fold' },
  ],
}

/** Effective-stack bounds per mode, matching the ranges the Range Explorer UI already
 * uses for these same models — a 1bb push/fold spot and a 100bb opening spot are both
 * meaningful; a 1bb "opening" spot is not. */
const STACK_RANGE_BY_MODE: Record<TrainerMode, readonly [number, number]> = {
  pushFold: [1, 20],
  opening: [20, 100],
  facingShove: [1, 20],
  facingOpen: [20, 100],
  threeBet: [20, 100],
  fourBet: [20, 100],
}

export interface TrainerSpot {
  readonly mode: TrainerMode
  readonly hand: HoleCards
  readonly handNotation: string
  readonly stack: number
  /** `pushFold`/`opening`: hero's own seat, unopened pot. `fourBet`: hero's own seat too —
   * hero is the *original opener*, now facing a 3-bet. `undefined` for `facingShove`/
   * `facingOpen`/`threeBet`, which use `opponentPosition` for the opener/shover instead. */
  readonly position?: Position
  /** The opener/shover hero is reacting to. Present for `facingShove`/`facingOpen`/`threeBet`,
   * where hero is the one facing the raise. */
  readonly opponentPosition?: Position
  /** `facingShove`/`facingOpen`/`threeBet`: hero's own seat (the defender). `fourBet`:
   * the opposite role — this is the *villain* who 3-bet hero's open, not hero's own seat
   * (hero is `position` there instead). Mirrors how the Range Explorer UI reuses this same
   * state slot for both roles depending on mode. */
  readonly heroPosition?: DefendingPosition
  readonly correctAction: TrainerAction
  readonly reasoning: string
}

function formatted(value: number): string {
  return value === Math.round(value) ? value.toFixed(0) : value.toFixed(1)
}

function callVsShoveReasoning(d: CallVsShoveDecision): string {
  const pct = d.callPercentage.toFixed(0)
  return d.action === 'call'
    ? `Hand strength score ${formatted(d.handScore)} clears the call threshold of ${formatted(d.scoreThreshold)} (top ${pct}% of hands profitably call this shove).`
    : `Hand strength score ${formatted(d.handScore)} is below the call threshold of ${formatted(d.scoreThreshold)} (top ${pct}% of hands profitably call this shove).`
}

function openDefenseReasoning(d: OpenDefenseDecision): string {
  const pct = d.totalDefensePercentage.toFixed(0)
  if (d.action === 'threeBet') {
    return `Hand strength score ${formatted(d.handScore)} clears the 3-bet threshold of ${formatted(d.threeBetThreshold)} within this ${pct}% total defense range.`
  }
  if (d.action === 'call') {
    return `Hand strength score ${formatted(d.handScore)} clears the call threshold of ${formatted(d.callThreshold)} but not the 3-bet threshold of ${formatted(d.threeBetThreshold)}, within this ${pct}% total defense range.`
  }
  return `Hand strength score ${formatted(d.handScore)} is below the call threshold of ${formatted(d.callThreshold)} for this ${pct}% total defense range.`
}

function threeBetReasoning(d: ThreeBetDecision): string {
  switch (d.action) {
    case 'threeBetValue':
      return `Hand strength score ${formatted(d.handScore)} clears the value 3-bet threshold of ${formatted(d.valueThreshold)} (~${d.threeBetPercentage.toFixed(0)}% 3-bet range).`
    case 'threeBetBluff':
      return `A designated blocker-bluff combo (A5s-A2s) included in this 3-bet range, independent of its raw hand-strength score.`
    case 'call':
      return `Hand strength score ${formatted(d.handScore)} is below the value 3-bet threshold of ${formatted(d.valueThreshold)} but clears the continue threshold of ${formatted(d.callThreshold)}.`
    case 'fold':
      return `Hand strength score ${formatted(d.handScore)} is below both the 3-bet and continue thresholds for this spot.`
  }
}

function fourBetReasoning(d: FourBetDecision): string {
  switch (d.action) {
    case 'fourBetValue':
      return `Hand strength score ${formatted(d.handScore)} clears the value 4-bet threshold of ${formatted(d.valueThreshold)} (~${d.fourBetPercentage.toFixed(0)}% 4-bet range).`
    case 'fourBetBluff':
      return `A designated blocker-bluff combo (A5s-A2s) included in this 4-bet range, independent of its raw hand-strength score.`
    case 'call':
      return `Hand strength score ${formatted(d.handScore)} is below the value 4-bet threshold of ${formatted(d.valueThreshold)} but clears the continue threshold of ${formatted(d.callThreshold)}.`
    case 'fold':
      return `Hand strength score ${formatted(d.handScore)} is below both the 4-bet and continue thresholds for this spot.`
  }
}

function randomInt(rng: () => number, min: number, max: number): number {
  return Math.floor(rng() * (max - min + 1)) + min
}

function randomElement<T>(rng: () => number, arr: readonly T[]): T {
  return arr[Math.floor(rng() * arr.length)]
}

/** Draws two distinct cards from the full 52-card deck — real deal frequency, not a
 * uniform draw over the 169 canonical hand labels (which would over-represent pairs and
 * suited combos relative to how often they're actually dealt). */
function randomHand(rng: () => number): HoleCards {
  const deck = [...FULL_DECK]
  const first = deck.splice(Math.floor(rng() * deck.length), 1)[0]
  const second = deck.splice(Math.floor(rng() * deck.length), 1)[0]
  return holeCards(first, second)!
}

function randomPosition(rng: () => number): Position {
  return randomElement(rng, POSITIONS)
}

/** A random `DefendingPosition` that can legally react to `opener` — i.e. acts after it.
 * Always non-empty: every `Position` has at least one later `DefendingPosition` seat. */
function randomDefenderAfter(rng: () => number, opener: Position): DefendingPosition {
  const valid = DEFENDING_POSITIONS.filter((p) => defendingActionOrderIndex(p) > positionActionOrderIndex(opener))
  return randomElement(rng, valid)
}

/** Deals one random drill spot for `mode`. `rng` defaults to `Math.random`; pass a seeded
 * generator (e.g. in tests) for reproducible spots. */
export function generateSpot(mode: TrainerMode, rng: () => number = Math.random): TrainerSpot {
  const hand = randomHand(rng)
  const handNotation = holeCardsNotation(hand)
  const [minStack, maxStack] = STACK_RANGE_BY_MODE[mode]
  const stack = randomInt(rng, minStack, maxStack)

  switch (mode) {
    case 'pushFold': {
      const position = randomPosition(rng)
      const decision = decidePushFold(hand, position, stack)
      return {
        mode,
        hand,
        handNotation,
        stack,
        position,
        correctAction: decision.action === 'push' ? 'push' : 'fold',
        reasoning: pushFoldReasoning(decision),
      }
    }
    case 'opening': {
      const position = randomPosition(rng)
      const decision = decideOpening(hand, position, stack)
      return {
        mode,
        hand,
        handNotation,
        stack,
        position,
        correctAction: decision.action === 'raise' ? 'raise' : 'fold',
        reasoning: openingReasoning(decision),
      }
    }
    case 'facingShove': {
      const opponentPosition = randomPosition(rng)
      const heroPosition = randomDefenderAfter(rng, opponentPosition)
      const decision = decideVsShove(hand, heroPosition, opponentPosition, stack)!
      return {
        mode,
        hand,
        handNotation,
        stack,
        opponentPosition,
        heroPosition,
        correctAction: decision.action === 'call' ? 'call' : 'fold',
        reasoning: callVsShoveReasoning(decision),
      }
    }
    case 'facingOpen': {
      const opponentPosition = randomPosition(rng)
      const heroPosition = randomDefenderAfter(rng, opponentPosition)
      const decision = decideVsOpen(hand, heroPosition, opponentPosition, stack)!
      return {
        mode,
        hand,
        handNotation,
        stack,
        opponentPosition,
        heroPosition,
        correctAction: decision.action,
        reasoning: openDefenseReasoning(decision),
      }
    }
    case 'threeBet': {
      const opponentPosition = randomPosition(rng)
      const heroPosition = randomDefenderAfter(rng, opponentPosition)
      const decision = decideThreeBet(hand, heroPosition, opponentPosition, stack)!
      const correctAction: TrainerAction = decision.action === 'threeBetValue' || decision.action === 'threeBetBluff' ? 'threeBet' : decision.action
      return {
        mode,
        hand,
        handNotation,
        stack,
        opponentPosition,
        heroPosition,
        correctAction,
        reasoning: threeBetReasoning(decision),
      }
    }
    case 'fourBet': {
      const position = randomPosition(rng)
      const heroPosition = randomDefenderAfter(rng, position)
      const decision = decideFourBet(hand, position, heroPosition, stack)!
      const correctAction: TrainerAction = decision.action === 'fourBetValue' || decision.action === 'fourBetBluff' ? 'fourBet' : decision.action
      return {
        mode,
        hand,
        handNotation,
        stack,
        position,
        heroPosition,
        correctAction,
        reasoning: fourBetReasoning(decision),
      }
    }
  }
}

export function gradeAnswer(spot: TrainerSpot, action: TrainerAction): boolean {
  return action === spot.correctAction
}
