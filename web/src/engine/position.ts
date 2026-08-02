// Port of PokerKit/Sources/PokerKit/Position.swift.

export const POSITIONS = ['UTG', 'MP', 'HJ', 'CO', 'BTN', 'SB'] as const

/** Preflop position for an unopened pot, earliest to latest. The Big Blind is
 * deliberately excluded — if action folds around, BB has already won uncontested. */
export type Position = (typeof POSITIONS)[number]

export const POSITION_FULL_NAME: Record<Position, string> = {
  UTG: 'Under the Gun',
  MP: 'Middle Position',
  HJ: 'Hijack',
  CO: 'Cutoff',
  BTN: 'Button',
  SB: 'Small Blind',
}
