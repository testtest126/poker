// Port of PokerKit/Sources/PokerKit/PreflopGrid.swift — the classic 13x13 starting-hand
// grid: pairs on the diagonal, suited combos above it, offsuit below. Both axes run A
// down to 2. Purely an enumeration/layout helper — reuses the range models for the actual
// decisions, never introduces a new one.

import { RANKS, type Rank, rankSymbol } from './card'
import type { HoleCards } from './holeCards'
import { holeCardsFromCanonical } from './holeCards'
import { decidePushFold, type PushFoldDecision } from './pushFoldRange'
import { decideOpening, type OpeningDecision } from './openingRange'
import type { Position } from './position'
import type { DefendingPosition } from './defendingPosition'
import { type CallVsShoveDecision, type OpenDefenseDecision, decideVsOpen, decideVsShove } from './callingRange'
import { type ThreeBetDecision, decideThreeBet } from './threeBetRange'
import { type FourBetDecision, decideFourBet } from './fourBetRange'

/** Ranks A...2, in the order the grid's rows and columns are indexed. */
export const GRID_RANKS: readonly Rank[] = [...RANKS].sort((a, b) => b - a)

/** Canonical notation ("AKs", "72o", "TT") for the cell at (row, col), both 0-indexed
 * A...2. Cells above the diagonal (col > row) are suited; below (row > col) are offsuit;
 * the diagonal (row === col) is pairs. */
export function gridNotation(row: number, col: number): string {
  const higher = GRID_RANKS[Math.min(row, col)]
  const lower = GRID_RANKS[Math.max(row, col)]
  if (row === col) return `${rankSymbol(higher)}${rankSymbol(higher)}`
  return row < col ? `${rankSymbol(higher)}${rankSymbol(lower)}s` : `${rankSymbol(higher)}${rankSymbol(lower)}o`
}

/** All 169 canonical starting hands laid out as a 13x13 grid, indexed [row][col]. */
export const gridHands: readonly (readonly HoleCards[])[] = GRID_RANKS.map((_, row) =>
  GRID_RANKS.map((_, col) => holeCardsFromCanonical(gridNotation(row, col))!),
)

export function pushFoldGridDecisions(position: Position, effectiveStackBB: number): PushFoldDecision[][] {
  return gridHands.map((row) => row.map((hand) => decidePushFold(hand, position, effectiveStackBB)))
}

export function openingGridDecisions(position: Position, effectiveStackBB: number): OpeningDecision[][] {
  return gridHands.map((row) => row.map((hand) => decideOpening(hand, position, effectiveStackBB)))
}

/** `undefined` if `caller`/`shover` is a nonsensical position pairing (see `decideVsShove`). */
export function callingGridDecisions(
  caller: DefendingPosition,
  shover: Position,
  effectiveStackBB: number,
): (CallVsShoveDecision[][]) | undefined {
  const first = decideVsShove(gridHands[0][0], caller, shover, effectiveStackBB)
  if (!first) return undefined
  return gridHands.map((row) => row.map((hand) => decideVsShove(hand, caller, shover, effectiveStackBB)!))
}

/** `undefined` if `defender`/`opener` is a nonsensical position pairing (see `decideVsOpen`). */
export function openDefenseGridDecisions(
  defender: DefendingPosition,
  opener: Position,
  effectiveStackBB: number,
): (OpenDefenseDecision[][]) | undefined {
  const first = decideVsOpen(gridHands[0][0], defender, opener, effectiveStackBB)
  if (!first) return undefined
  return gridHands.map((row) => row.map((hand) => decideVsOpen(hand, defender, opener, effectiveStackBB)!))
}

/** `undefined` if `defender`/`opener` is a nonsensical position pairing (see `decideThreeBet`). */
export function threeBetGridDecisions(
  defender: DefendingPosition,
  opener: Position,
  effectiveStackBB: number,
): (ThreeBetDecision[][]) | undefined {
  const first = decideThreeBet(gridHands[0][0], defender, opener, effectiveStackBB)
  if (!first) return undefined
  return gridHands.map((row) => row.map((hand) => decideThreeBet(hand, defender, opener, effectiveStackBB)!))
}

/** `undefined` if `opener`/`threeBettor` is a nonsensical position pairing (see `decideFourBet`). */
export function fourBetGridDecisions(
  opener: Position,
  threeBettor: DefendingPosition,
  effectiveStackBB: number,
): (FourBetDecision[][]) | undefined {
  const first = decideFourBet(gridHands[0][0], opener, threeBettor, effectiveStackBB)
  if (!first) return undefined
  return gridHands.map((row) => row.map((hand) => decideFourBet(hand, opener, threeBettor, effectiveStackBB)!))
}
