// Maps a real imported hand's preflop decision(s) to the correct entry among the six
// charted range models (pushFoldRange/openingRange/callingRange/threeBetRange/
// fourBetRange — the same models the Trainer drills) and grades hero's actual action
// against it. This is new logic, not a port: PokerKit's `LeakAnalysisEngine` only ever
// graded push/fold adherence (the one spot where "hero's own position" is the only input
// needed); grading the other five modes needs the *opponent's* position too, which is why
// `handHistory.ts` exposes every seat's position, not just hero's.
//
// Deliberate, disclosed scope limits — mark "not covered" rather than guess:
// - Facing Open and 3-Bet are two independently-opinionated charts on the *same* physical
//   spot (hero facing exactly one open raise) — see ai-docs/RANGES.md's "Two opinions, on
//   purpose". A leak report needs one verdict per decision, and there's no principled way
//   to prefer one chart's opinion over the other's for grading real hands, so this module
//   always grades that spot against Facing Open (`callingRange.ts`'s single-threshold,
//   more-sourced model) — 3-Bet stays a Trainer-only drill. Facing Shove, by contrast, IS
//   structurally distinct (the raise is all-in) and gets its own grading.
// - A hand contributes at most one graded decision. If hero opened and then faced a
//   3-bet, only that second, more specific decision (4-Bet) is graded — not also the
//   opening raise that preceded it.
// - "Effective stack" for a *reactive* decision (facing a shove/open, or facing a 3-bet
//   after opening) is `min(hero, opponent)` starting stack — what's actually at risk. For
//   an *opening* decision (push/fold, opening RFI) there's no specific opponent yet, so
//   this uses hero's own starting stack alone, matching `LeakAnalysisEngine`'s own
//   documented simplification (see its "A note on effective stack" comment).
// - Anything that doesn't cleanly fit — an unusual raise count, an unmappable position, a
//   stack outside a model's charted range — is reported as `covered: false` with a reason,
//   never silently forced into the nearest bucket.

import type { HandAction, ParsedHand } from '../lib/handHistory'
import { positionLabelForSeat } from '../lib/handHistory'
import { holeCardsNotation } from './holeCards'
import { POSITIONS, POSITION_FULL_NAME, type Position } from './position'
import {
  DEFENDING_POSITION_FULL_NAME,
  type DefendingPosition,
  defendingActionOrderIndex,
  positionActionOrderIndex,
} from './defendingPosition'
import { decidePushFold, pushFoldReasoning } from './pushFoldRange'
import { decideOpening, openingReasoning } from './openingRange'
import { decideVsOpen, decideVsShove } from './callingRange'
import { decideFourBet } from './fourBetRange'
import { callVsShoveReasoning, fourBetReasoning, openDefenseReasoning, type TrainerAction, type TrainerMode } from './trainer'

export interface CoveredLeakResult {
  readonly handId: string
  readonly covered: true
  readonly mode: TrainerMode
  readonly handNotation: string
  readonly stackBB: number
  readonly correctAction: TrainerAction
  readonly heroAction: TrainerAction
  readonly isCorrect: boolean
  readonly reasoning: string
  readonly description: string
}

export interface NotCoveredLeakResult {
  readonly handId: string
  readonly covered: false
  readonly reason: string
}

export type LeakResult = CoveredLeakResult | NotCoveredLeakResult

const DECISION_KINDS: ReadonlySet<HandAction['kind']> = new Set(['fold', 'check', 'call', 'bet', 'raise'])

/** Folds a raw hand-history position label ("UTG+1", "MP+1", plus every label
 * `positionLabelForSeat` can return) down to the engine's coarser taxonomy — the same
 * collision `LeakAnalysisEngine.pushFoldPositionMap` documents and accepts, generalized
 * here to every defending position (including BB), not just the push/fold-eligible ones. */
const FOLD_POSITION: Record<string, DefendingPosition> = {
  UTG: 'UTG',
  'UTG+1': 'UTG',
  MP: 'MP',
  'MP+1': 'MP',
  HJ: 'HJ',
  CO: 'CO',
  BTN: 'BTN',
  SB: 'SB',
  BB: 'BB',
}

function foldPosition(label: string | undefined): DefendingPosition | undefined {
  return label !== undefined ? FOLD_POSITION[label] : undefined
}

function isOpeningPosition(p: DefendingPosition): p is Position {
  return (POSITIONS as readonly string[]).includes(p)
}

function notCovered(hand: ParsedHand, reason: string): NotCoveredLeakResult {
  return { handId: hand.handId, covered: false, reason }
}

function covered(
  hand: ParsedHand,
  mode: TrainerMode,
  handNotation: string,
  stackBB: number,
  correctAction: TrainerAction,
  heroAction: TrainerAction,
  reasoning: string,
  description: string,
): CoveredLeakResult {
  return {
    handId: hand.handId,
    covered: true,
    mode,
    handNotation,
    stackBB,
    correctAction,
    heroAction,
    isCorrect: correctAction === heroAction,
    reasoning,
    description,
  }
}

/** Classifies and grades hero's preflop decision in `hand` against the charted range
 * models. Never throws — a hand that doesn't map cleanly comes back `covered: false`
 * with a human-readable reason instead of a guessed verdict. */
export function classifyHand(hand: ParsedHand): LeakResult {
  if (!hand.heroHoleCards) return notCovered(hand, 'No hero hole cards recorded for this hand.')
  if (hand.buttonSeat === undefined) return notCovered(hand, "Button seat couldn't be determined.")
  if (!(hand.bigBlind > 0)) return notCovered(hand, 'No big blind size recorded for this hand.')
  if (hand.heroStartingStack === undefined || !(hand.heroStartingStack > 0)) {
    return notCovered(hand, "Hero's starting stack wasn't recorded for this hand.")
  }

  const preflop = hand.actions.filter((a) => a.street === 'preflop')
  const heroActions = preflop.filter((a) => a.player === hand.heroName && DECISION_KINDS.has(a.kind))
  if (heroActions.length === 0) {
    return notCovered(hand, 'Hero had no preflop decision to make (e.g. the pot folded around to an uncontested big blind).')
  }

  const handNotation = holeCardsNotation(hand.heroHoleCards)
  const firstHeroAction = heroActions[0]
  const firstHeroIndex = preflop.indexOf(firstHeroAction)
  const beforeFirst = preflop.slice(0, firstHeroIndex)
  const raisesBeforeFirst = beforeFirst.filter((a) => a.kind === 'raise')

  // Try the deepest, most specific pattern first: hero's first action was itself the
  // hand's first voluntary raise (hero opened), and hero has a second preflop decision —
  // i.e. hero got 3-bet and must respond. That second decision (4-Bet) is what gets
  // graded; the opening raise that preceded it isn't graded separately (see file header).
  if (raisesBeforeFirst.length === 0 && firstHeroAction.kind === 'raise' && heroActions.length >= 2) {
    const secondHeroAction = heroActions[1]
    const secondHeroIndex = preflop.indexOf(secondHeroAction, firstHeroIndex + 1)
    const between = preflop.slice(firstHeroIndex + 1, secondHeroIndex)
    const raisesBetween = between.filter((a) => a.kind === 'raise')
    if (raisesBetween.length === 1) {
      return classifyFourBetSpot(hand, handNotation, raisesBetween[0], secondHeroAction)
    }
  }

  if (raisesBeforeFirst.length === 0) {
    return classifyUnopenedSpot(hand, handNotation, firstHeroAction)
  }
  if (raisesBeforeFirst.length === 1) {
    return classifyFacingSingleRaiseSpot(hand, handNotation, raisesBeforeFirst[0], firstHeroAction)
  }
  return notCovered(hand, 'Hero faced more than one raise before their first decision — not one of the charted spots.')
}

function classifyUnopenedSpot(hand: ParsedHand, handNotation: string, heroAction: HandAction): LeakResult {
  const heroFolded = foldPosition(hand.heroPosition)
  if (!heroFolded) return notCovered(hand, "Hero's position couldn't be mapped to a charted seat.")
  if (!isOpeningPosition(heroFolded)) {
    return notCovered(
      hand,
      "Hero was in the big blind with no raise in front — not one of the charted spots (push/fold and opening cover the player opening the pot, not the big blind's walk/isolate decision).",
    )
  }

  const stackBB = hand.heroStartingStack! / hand.bigBlind
  if (stackBB < 1 || stackBB > 100) {
    return notCovered(hand, `Hero's effective stack (${stackBB.toFixed(1)}bb) is outside the charted 1-100bb range.`)
  }

  const positionName = POSITION_FULL_NAME[heroFolded]
  if (stackBB <= 20) {
    const decision = decidePushFold(hand.heroHoleCards!, heroFolded, stackBB)
    const correctAction: TrainerAction = decision.action === 'push' ? 'push' : 'fold'
    const heroActualAction: TrainerAction = heroAction.kind === 'raise' && heroAction.isAllIn ? 'push' : 'fold'
    return covered(
      hand,
      'pushFold',
      handNotation,
      stackBB,
      correctAction,
      heroActualAction,
      pushFoldReasoning(decision),
      `Unopened pot. Hero in the ${positionName} (${heroFolded}), ${stackBB.toFixed(1)}bb effective.`,
    )
  }

  const decision = decideOpening(hand.heroHoleCards!, heroFolded, stackBB)
  const correctAction: TrainerAction = decision.action === 'raise' ? 'raise' : 'fold'
  const heroActualAction: TrainerAction = heroAction.kind === 'raise' ? 'raise' : 'fold'
  return covered(
    hand,
    'opening',
    handNotation,
    stackBB,
    correctAction,
    heroActualAction,
    openingReasoning(decision),
    `Unopened pot. Hero in the ${positionName} (${heroFolded}), ${stackBB.toFixed(1)}bb effective.`,
  )
}

function classifyFacingSingleRaiseSpot(hand: ParsedHand, handNotation: string, raiseAction: HandAction, heroAction: HandAction): LeakResult {
  const heroFolded = foldPosition(hand.heroPosition)
  if (!heroFolded) return notCovered(hand, "Hero's position couldn't be mapped to a charted seat.")

  const opener = hand.seats.find((s) => s.name === raiseAction.player)
  if (!opener) return notCovered(hand, "Couldn't find the raiser's seat.")
  const openerFolded = foldPosition(positionLabelForSeat(hand.seats, hand.buttonSeat!, opener.seat))
  if (!openerFolded || !isOpeningPosition(openerFolded)) {
    return notCovered(hand, "The raiser's position couldn't be mapped to a charted opening seat.")
  }

  if (defendingActionOrderIndex(heroFolded) <= positionActionOrderIndex(openerFolded)) {
    return notCovered(hand, "Hero's position relative to the raiser doesn't match a defending spot.")
  }

  const effectiveStackBB = Math.min(hand.heroStartingStack!, opener.stack) / hand.bigBlind
  const heroName = DEFENDING_POSITION_FULL_NAME[heroFolded]
  const openerName = POSITION_FULL_NAME[openerFolded]

  if (raiseAction.isAllIn) {
    if (effectiveStackBB < 1 || effectiveStackBB > 20) {
      return notCovered(hand, `Effective stack (${effectiveStackBB.toFixed(1)}bb) is outside the charted facing-shove range (1-20bb).`)
    }
    const decision = decideVsShove(hand.heroHoleCards!, heroFolded, openerFolded, effectiveStackBB)
    if (!decision) return notCovered(hand, "This position pairing isn't one the facing-shove chart covers.")
    const correctAction: TrainerAction = decision.action === 'call' ? 'call' : 'fold'
    const heroActualAction: TrainerAction = heroAction.kind === 'fold' ? 'fold' : 'call'
    return covered(
      hand,
      'facingShove',
      handNotation,
      effectiveStackBB,
      correctAction,
      heroActualAction,
      callVsShoveReasoning(decision),
      `${openerName} (${openerFolded}) shoves all-in. Hero in the ${heroName} (${heroFolded}), ${effectiveStackBB.toFixed(1)}bb effective.`,
    )
  }

  if (effectiveStackBB < 20 || effectiveStackBB > 100) {
    return notCovered(hand, `Effective stack (${effectiveStackBB.toFixed(1)}bb) is outside the charted facing-open range (20-100bb).`)
  }
  const decision = decideVsOpen(hand.heroHoleCards!, heroFolded, openerFolded, effectiveStackBB)
  if (!decision) return notCovered(hand, "This position pairing isn't one the facing-open chart covers.")
  const heroActualAction: TrainerAction = heroAction.kind === 'fold' ? 'fold' : heroAction.kind === 'call' ? 'call' : 'threeBet'
  return covered(
    hand,
    'facingOpen',
    handNotation,
    effectiveStackBB,
    decision.action,
    heroActualAction,
    openDefenseReasoning(decision),
    `${openerName} (${openerFolded}) opens. Hero in the ${heroName} (${heroFolded}), ${effectiveStackBB.toFixed(1)}bb effective.`,
  )
}

function classifyFourBetSpot(hand: ParsedHand, handNotation: string, threeBetAction: HandAction, heroSecondAction: HandAction): LeakResult {
  const heroFolded = foldPosition(hand.heroPosition)
  if (!heroFolded || !isOpeningPosition(heroFolded)) {
    return notCovered(hand, "Hero's position couldn't be mapped to a charted opening seat.")
  }

  const threeBettor = hand.seats.find((s) => s.name === threeBetAction.player)
  if (!threeBettor) return notCovered(hand, "Couldn't find the 3-bettor's seat.")
  const threeBettorFolded = foldPosition(positionLabelForSeat(hand.seats, hand.buttonSeat!, threeBettor.seat))
  if (!threeBettorFolded) return notCovered(hand, "The 3-bettor's position couldn't be mapped to a charted seat.")

  const effectiveStackBB = Math.min(hand.heroStartingStack!, threeBettor.stack) / hand.bigBlind
  if (effectiveStackBB < 20 || effectiveStackBB > 100) {
    return notCovered(hand, `Effective stack (${effectiveStackBB.toFixed(1)}bb) is outside the charted 4-bet range (20-100bb).`)
  }

  const decision = decideFourBet(hand.heroHoleCards!, heroFolded, threeBettorFolded, effectiveStackBB)
  if (!decision) return notCovered(hand, "This position pairing isn't one the 4-bet chart covers.")

  const correctAction: TrainerAction = decision.action === 'fourBetValue' || decision.action === 'fourBetBluff' ? 'fourBet' : decision.action
  const heroActualAction: TrainerAction = heroSecondAction.kind === 'fold' ? 'fold' : heroSecondAction.kind === 'call' ? 'call' : 'fourBet'
  const heroName = POSITION_FULL_NAME[heroFolded]
  const threeBettorName = DEFENDING_POSITION_FULL_NAME[threeBettorFolded]

  return covered(
    hand,
    'fourBet',
    handNotation,
    effectiveStackBB,
    correctAction,
    heroActualAction,
    fourBetReasoning(decision),
    `Hero opens from the ${heroName} (${heroFolded}). ${threeBettorName} (${threeBettorFolded}) 3-bets, ${effectiveStackBB.toFixed(1)}bb effective.`,
  )
}

// MARK: - Aggregate report

export interface ModeAccuracy {
  readonly mode: TrainerMode
  readonly total: number
  readonly correct: number
  readonly accuracy: number
}

export interface PositionAccuracy {
  readonly position: string
  readonly total: number
  readonly correct: number
  readonly accuracy: number
}

export interface LeakReport {
  readonly totalHands: number
  readonly coveredCount: number
  readonly notCoveredCount: number
  readonly correctCount: number
  /** `undefined` if no hand was covered — never reported as 0%. */
  readonly accuracy: number | undefined
  readonly byMode: readonly ModeAccuracy[]
  readonly byPosition: readonly PositionAccuracy[]
  /** Every covered, incorrect decision — the Leak Finder's actual "here's what to study" output. */
  readonly misplayedHands: readonly CoveredLeakResult[]
  /** One entry per input hand, same order — covered and not-covered alike — so callers
   * (the Import table) can tag every row without re-running `classifyHand` themselves. */
  readonly results: readonly LeakResult[]
}

export function analyzeLeaks(hands: readonly ParsedHand[]): LeakReport {
  const paired = hands.map((hand) => ({ hand, result: classifyHand(hand) }))
  const coveredResults = paired.filter((p): p is { hand: ParsedHand; result: CoveredLeakResult } => p.result.covered)

  const byModeMap = new Map<TrainerMode, { total: number; correct: number }>()
  const byPositionMap = new Map<string, { total: number; correct: number }>()

  for (const { hand, result } of coveredResults) {
    const modeEntry = byModeMap.get(result.mode) ?? { total: 0, correct: 0 }
    modeEntry.total += 1
    if (result.isCorrect) modeEntry.correct += 1
    byModeMap.set(result.mode, modeEntry)

    const positionKey = hand.heroPosition ?? 'Unknown'
    const positionEntry = byPositionMap.get(positionKey) ?? { total: 0, correct: 0 }
    positionEntry.total += 1
    if (result.isCorrect) positionEntry.correct += 1
    byPositionMap.set(positionKey, positionEntry)
  }

  const correctCount = coveredResults.filter((p) => p.result.isCorrect).length

  return {
    totalHands: hands.length,
    coveredCount: coveredResults.length,
    notCoveredCount: hands.length - coveredResults.length,
    correctCount,
    accuracy: coveredResults.length > 0 ? correctCount / coveredResults.length : undefined,
    byMode: [...byModeMap.entries()].map(([mode, { total, correct }]) => ({ mode, total, correct, accuracy: correct / total })),
    byPosition: [...byPositionMap.entries()].map(([position, { total, correct }]) => ({ position, total, correct, accuracy: correct / total })),
    misplayedHands: coveredResults.filter((p) => !p.result.isCorrect).map((p) => p.result),
    results: paired.map((p) => p.result),
  }
}
