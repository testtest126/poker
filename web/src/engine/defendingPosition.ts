// Port of the `DefendingPosition` half of PokerKit/Sources/PokerKit/CallingRange.swift.

import { POSITIONS, type Position } from './position'

export const DEFENDING_POSITIONS = ['UTG', 'MP', 'HJ', 'CO', 'BTN', 'SB', 'BB'] as const

/** Hero's position when **defending** — reacting to another player's shove or open —
 * rather than acting first. Distinct from `Position` because a defending hero can be the
 * big blind, which `Position` deliberately excludes: the big blind never opens or shoves
 * into an unopened pot, but is exactly who most often *calls* one. */
export type DefendingPosition = (typeof DEFENDING_POSITIONS)[number]

export const DEFENDING_POSITION_FULL_NAME: Record<DefendingPosition, string> = {
  UTG: 'Under the Gun',
  MP: 'Middle Position',
  HJ: 'Hijack',
  CO: 'Cutoff',
  BTN: 'Button',
  SB: 'Small Blind',
  BB: 'Big Blind',
}

/** This position's seat index in the standard UTG-to-BB action order — comparable
 * directly with a `Position`'s own `actionOrderIndex` since both share the same six-case
 * ordering (UTG...SB) before `DefendingPosition` appends BB. */
export function defendingActionOrderIndex(p: DefendingPosition): number {
  return DEFENDING_POSITIONS.indexOf(p)
}

export function positionActionOrderIndex(p: Position): number {
  return POSITIONS.indexOf(p)
}
