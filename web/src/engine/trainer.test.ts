import { describe, expect, test } from 'vitest'
import {
  TRAINER_MODES,
  TRAINER_MODE_ACTIONS,
  generateSpot,
  gradeAnswer,
  type TrainerMode,
} from './trainer'
import { decidePushFold } from './pushFoldRange'
import { decideOpening } from './openingRange'
import { decideVsShove, decideVsOpen } from './callingRange'
import { decideThreeBet } from './threeBetRange'
import { decideFourBet } from './fourBetRange'
import { defendingActionOrderIndex, positionActionOrderIndex } from './defendingPosition'

const STACK_RANGE_BY_MODE: Record<TrainerMode, [number, number]> = {
  pushFold: [1, 20],
  opening: [20, 100],
  facingShove: [1, 20],
  facingOpen: [20, 100],
  threeBet: [20, 100],
  fourBet: [20, 100],
}

/** A tiny deterministic PRNG, local to this test file — no relation to `equity.ts`'s
 * mulberry32; determinism (not cross-file sharing) is all these tests need. */
function seededRng(seed: number): () => number {
  let s = seed >>> 0
  return () => {
    s = (s * 1103515245 + 12345) & 0x7fffffff
    return s / 0x7fffffff
  }
}

const CANONICAL_HAND_PATTERN = /^([2-9TJQKA]{2}|[2-9TJQKA]{2}[so])$/

const SAMPLE_SIZE = 300

describe('trainer: generateSpot', () => {
  for (const mode of TRAINER_MODES) {
    test(`${mode}: every spot is internally consistent over ${SAMPLE_SIZE} draws`, () => {
      const rng = seededRng(0xc0ffee + mode.length)
      const actionsSeen = new Set<string>()
      const [minStack, maxStack] = STACK_RANGE_BY_MODE[mode]

      for (let i = 0; i < SAMPLE_SIZE; i++) {
        const spot = generateSpot(mode, rng)

        expect(spot.mode).toBe(mode)
        expect(spot.handNotation).toMatch(CANONICAL_HAND_PATTERN)
        expect(spot.stack).toBeGreaterThanOrEqual(minStack)
        expect(spot.stack).toBeLessThanOrEqual(maxStack)
        expect(spot.reasoning.length).toBeGreaterThan(0)

        const validActions = TRAINER_MODE_ACTIONS[mode].map((o) => o.action)
        expect(validActions, `${spot.correctAction} should be a valid answer for ${mode}`).toContain(spot.correctAction)
        actionsSeen.add(spot.correctAction)

        if (spot.heroPosition && spot.opponentPosition) {
          expect(defendingActionOrderIndex(spot.heroPosition)).toBeGreaterThan(positionActionOrderIndex(spot.opponentPosition))
        }
        if (spot.heroPosition && spot.position && mode === 'fourBet') {
          expect(defendingActionOrderIndex(spot.heroPosition)).toBeGreaterThan(positionActionOrderIndex(spot.position))
        }
      }

      // Across 300 draws spanning the full stack/position range, a single-outcome mode
      // would indicate a bug (e.g. always folding) rather than a real, narrow range.
      expect(actionsSeen.size, `${mode} produced only ${[...actionsSeen]} across ${SAMPLE_SIZE} draws`).toBeGreaterThan(1)
    })

    test(`${mode}: correctAction always matches independently re-deriving the underlying decision`, () => {
      const rng = seededRng(0xdead + mode.length)

      for (let i = 0; i < SAMPLE_SIZE; i++) {
        const spot = generateSpot(mode, rng)

        switch (spot.mode) {
          case 'pushFold': {
            const decision = decidePushFold(spot.hand, spot.position!, spot.stack)
            expect(spot.correctAction).toBe(decision.action === 'push' ? 'push' : 'fold')
            break
          }
          case 'opening': {
            const decision = decideOpening(spot.hand, spot.position!, spot.stack)
            expect(spot.correctAction).toBe(decision.action === 'raise' ? 'raise' : 'fold')
            break
          }
          case 'facingShove': {
            const decision = decideVsShove(spot.hand, spot.heroPosition!, spot.opponentPosition!, spot.stack)!
            expect(spot.correctAction).toBe(decision.action === 'call' ? 'call' : 'fold')
            break
          }
          case 'facingOpen': {
            const decision = decideVsOpen(spot.hand, spot.heroPosition!, spot.opponentPosition!, spot.stack)!
            expect(spot.correctAction).toBe(decision.action)
            break
          }
          case 'threeBet': {
            const decision = decideThreeBet(spot.hand, spot.heroPosition!, spot.opponentPosition!, spot.stack)!
            const expected = decision.action === 'threeBetValue' || decision.action === 'threeBetBluff' ? 'threeBet' : decision.action
            expect(spot.correctAction).toBe(expected)
            break
          }
          case 'fourBet': {
            const decision = decideFourBet(spot.hand, spot.position!, spot.heroPosition!, spot.stack)!
            const expected = decision.action === 'fourBetValue' || decision.action === 'fourBetBluff' ? 'fourBet' : decision.action
            expect(spot.correctAction).toBe(expected)
            break
          }
        }
      }
    })
  }

  test('is deterministic for a given rng sequence', () => {
    const a = generateSpot('threeBet', seededRng(42))
    const b = generateSpot('threeBet', seededRng(42))
    expect(a).toEqual(b)
  })
})

describe('trainer: gradeAnswer', () => {
  for (const mode of TRAINER_MODES) {
    test(`${mode}: correct only for the exact matching action`, () => {
      const rng = seededRng(7 + mode.length)
      for (let i = 0; i < 20; i++) {
        const spot = generateSpot(mode, rng)
        for (const option of TRAINER_MODE_ACTIONS[mode]) {
          expect(gradeAnswer(spot, option.action)).toBe(option.action === spot.correctAction)
        }
      }
    })
  }
})
