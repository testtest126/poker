// Port of PokerKit/Sources/PokerKit/Equity.swift — win/tie/lose equity between two hands
// or ranges, built entirely on `bestHand` (no shortcuts, no precomputed equity tables).
// See ai-docs/EQUITY.md (the Swift source's own doc) for the ground-truth numbers this
// is validated against; equity.test.ts checks this port against the same figures.
//
// **PRNG choice differs from the Swift source, on purpose.** `Equity.swift` uses
// SplitMix64 (a 64-bit generator) for reproducible sampling. This port uses mulberry32
// (a simpler, faster 32-bit generator) instead — cross-language bit-for-bit parity with
// the Swift app's random stream was never a requirement (the two apps are independent
// TypeScript/Swift codebases with independent test suites, each validated by tolerance
// against the same published ground truth, not against each other's specific sampled
// trials), and mulberry32 is meaningfully cheaper per call, which matters more here since
// this runs in a browser on a tap, not in a native test runner. Both are "fixed-seed
// deterministic, well-distributed for this purpose" — that's the property that actually
// matters, and both satisfy it.

import { type Card, FULL_DECK, cardKey, rankFromSymbol } from './card'
import type { HoleCards } from './holeCards'
import { bestHand, compareHandStrength } from './handEvaluator'

export interface EquityResult {
  /** Fraction of trials hero's hand strictly beats villain's, 0...1. */
  readonly winRate: number
  /** Fraction of trials hero's and villain's hands are exactly equal (chops the pot). */
  readonly tieRate: number
  /** Fraction of trials villain's hand strictly beats hero's. */
  readonly loseRate: number
  /** How many board completions (exact) or sampled scenarios (Monte Carlo) this is based on. */
  readonly trials: number
  /** `true` for `headsUp` (full enumeration — exact, not an estimate). */
  readonly isExact: boolean
}

/** mulberry32 — a small, fast, deterministic PRNG. See this file's header comment for
 * why it's a different generator than the Swift source's SplitMix64. */
function mulberry32(seed: number): () => number {
  let state = seed >>> 0
  return () => {
    state = (state + 0x6d2b79f5) >>> 0
    let t = state
    t = Math.imul(t ^ (t >>> 15), t | 1)
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61)
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
}

/** Default sample size for Monte Carlo calls that don't specify one. Roughly `±1%`
 * standard error at a 95% confidence interval — plenty for a study tool, and fast enough
 * to feel instant in a browser tap. */
export const DEFAULT_MONTE_CARLO_ITERATIONS = 20_000

/** Fixed default seed so callers who don't pass one still get reproducible results. */
export const DEFAULT_SEED = 0xc0ffee

function heroVillainCards(h: HoleCards): [Card, Card] {
  return [h.first, h.second]
}

/**
 * Exact win/tie/lose equity for `hero` vs. `villain`, given zero or more known board
 * cards. Enumerates every possible completion of the remaining board exhaustively — no
 * sampling error. Throws if `hero`/`villain`/`board` share a card, or `board` has more
 * than 5 cards.
 */
export function headsUp(hero: HoleCards, villain: HoleCards, board: readonly Card[] = []): EquityResult {
  const known = [...heroVillainCards(hero), ...heroVillainCards(villain), ...board]
  const keys = known.map(cardKey)
  if (new Set(keys).size !== keys.length) throw new Error('hero/villain/board share a card')
  if (board.length > 5) throw new Error('board can have at most 5 cards')

  const usedSet = new Set(keys)
  const remaining = FULL_DECK.filter((c) => !usedSet.has(cardKey(c)))
  const needed = 5 - board.length

  let wins = 0
  let ties = 0
  let losses = 0
  let total = 0

  forEachCombination(remaining, needed, (drawn) => {
    const fullBoard = [...board, ...drawn]
    const heroHand = bestHand([...heroVillainCards(hero), ...fullBoard])
    const villainHand = bestHand([...heroVillainCards(villain), ...fullBoard])
    total++
    const cmp = compareHandStrength(heroHand, villainHand)
    if (cmp > 0) wins++
    else if (cmp === 0) ties++
    else losses++
  })

  return { winRate: wins / total, tieRate: ties / total, loseRate: losses / total, trials: total, isExact: true }
}

/**
 * Fixed-seed Monte Carlo win/tie/lose equity for a hand (or range of hands) on each
 * side. Each trial samples one concrete hand uniformly from `hero`, one from `villain`,
 * and a uniformly random completion of the remaining board — retrying (up to a bounded
 * number of attempts) on any card collision, so the retry logic can never bias the
 * result toward whichever range happened to be listed first.
 */
export function monteCarlo(
  hero: readonly HoleCards[],
  villain: readonly HoleCards[],
  board: readonly Card[] = [],
  iterations: number = DEFAULT_MONTE_CARLO_ITERATIONS,
  seed: number = DEFAULT_SEED,
): EquityResult {
  if (hero.length === 0 || villain.length === 0) throw new Error('both ranges must be non-empty')
  if (board.length > 5) throw new Error('board can have at most 5 cards')

  const rng = mulberry32(seed)
  const needed = 5 - board.length
  const maxAttempts = Math.max(iterations * 50, 10_000)

  let wins = 0
  let ties = 0
  let losses = 0
  let trials = 0
  let attempts = 0

  while (trials < iterations && attempts < maxAttempts) {
    attempts++
    const heroHand = hero[Math.floor(rng() * hero.length)]
    const villainHand = villain[Math.floor(rng() * villain.length)]

    const known = [...heroVillainCards(heroHand), ...heroVillainCards(villainHand), ...board]
    const keys = known.map(cardKey)
    const usedSet = new Set(keys)
    if (usedSet.size !== keys.length) continue // card collision — retry

    const pool = FULL_DECK.filter((c) => !usedSet.has(cardKey(c)))
    if (pool.length < needed) continue

    const drawn: Card[] = []
    for (let i = 0; i < needed; i++) {
      const index = Math.floor(rng() * pool.length)
      drawn.push(pool.splice(index, 1)[0])
    }

    const fullBoard = [...board, ...drawn]
    const heroStrength = bestHand([...heroVillainCards(heroHand), ...fullBoard])
    const villainStrength = bestHand([...heroVillainCards(villainHand), ...fullBoard])
    trials++
    const cmp = compareHandStrength(heroStrength, villainStrength)
    if (cmp > 0) wins++
    else if (cmp === 0) ties++
    else losses++
  }

  return {
    winRate: trials > 0 ? wins / trials : 0,
    tieRate: trials > 0 ? ties / trials : 0,
    loseRate: trials > 0 ? losses / trials : 0,
    trials,
    isExact: false,
  }
}

/**
 * Every concrete `HoleCards` combo for a canonical hand string ("AA", "AKs", "72o") — 6
 * combos for a pair, 4 for suited, 12 for offsuit. `[]` for a malformed notation.
 *
 * This exists because **published "AA vs KK ≈ 82.4%" style equity figures are a
 * combo-weighted average**, not the equity of any single specific suit assignment — see
 * ai-docs/EQUITY.md's "A subtlety: which suits?" section.
 */
export function expandCanonical(notation: string): HoleCards[] {
  const chars = Array.from(notation)
  if (chars.length !== 2 && chars.length !== 3) return []
  const r1 = rankFromSymbol(chars[0])
  const r2 = rankFromSymbol(chars[1])
  if (r1 === undefined || r2 === undefined) return []

  const suits = ['clubs', 'diamonds', 'hearts', 'spades'] as const

  if (chars.length === 2) {
    if (r1 !== r2) return []
    const combos: HoleCards[] = []
    for (let i = 0; i < suits.length; i++) {
      for (let j = i + 1; j < suits.length; j++) {
        combos.push({ first: { rank: r1, suit: suits[i] }, second: { rank: r1, suit: suits[j] } })
      }
    }
    return combos
  }

  if (r1 === r2 || (chars[2] !== 's' && chars[2] !== 'o')) return []
  const suited = chars[2] === 's'
  const combos: HoleCards[] = []
  if (suited) {
    for (const s of suits) {
      combos.push({ first: { rank: r1, suit: s }, second: { rank: r2, suit: s } })
    }
  } else {
    for (const s1 of suits) {
      for (const s2 of suits) {
        if (s1 === s2) continue
        combos.push({ first: { rank: r1, suit: s1 }, second: { rank: r2, suit: s2 } })
      }
    }
  }
  return combos
}

/** Combo-weighted Monte Carlo equity between two canonical hand notations — expands each
 * into every concrete combo and runs `rangeVsRange` across them. */
export function canonicalVsCanonical(
  hero: string,
  villain: string,
  board: readonly Card[] = [],
  iterations: number = DEFAULT_MONTE_CARLO_ITERATIONS,
  seed: number = DEFAULT_SEED,
): EquityResult {
  return rangeVsRange(expandCanonical(hero), expandCanonical(villain), board, iterations, seed)
}

export function handVsRange(
  hero: HoleCards,
  villainRange: readonly HoleCards[],
  board: readonly Card[] = [],
  iterations: number = DEFAULT_MONTE_CARLO_ITERATIONS,
  seed: number = DEFAULT_SEED,
): EquityResult {
  return monteCarlo([hero], villainRange, board, iterations, seed)
}

export function rangeVsRange(
  heroRange: readonly HoleCards[],
  villainRange: readonly HoleCards[],
  board: readonly Card[] = [],
  iterations: number = DEFAULT_MONTE_CARLO_ITERATIONS,
  seed: number = DEFAULT_SEED,
): EquityResult {
  return monteCarlo(heroRange, villainRange, board, iterations, seed)
}

/**
 * Exact combo-weighted win/tie/lose equity between two ranges — no sampling error, but
 * only tractable when the board isn't empty (see `headsUp`'s own tractability note:
 * preflop enumerates up to `C(48,5) = 1,712,304` boards *per combo pair*). Enumerates
 * every valid (non-overlapping) combo pair and averages equally across pairs — correct,
 * not an approximation, because every valid pair has exactly the same number of possible
 * board completions for a fixed board state, regardless of which cards it uses.
 */
export function exactRangeVsRange(
  heroRange: readonly HoleCards[],
  villainRange: readonly HoleCards[],
  board: readonly Card[] = [],
): EquityResult {
  if (heroRange.length === 0 || villainRange.length === 0) throw new Error('both ranges must be non-empty')

  let winSum = 0
  let tieSum = 0
  let loseSum = 0
  let totalBoardEvaluations = 0
  let validPairs = 0

  for (const heroHand of heroRange) {
    for (const villainHand of villainRange) {
      const combined = new Set(
        [...heroVillainCards(heroHand), ...heroVillainCards(villainHand)].map(cardKey),
      )
      if (combined.size !== 4) continue // combo pair shares a card — can't both be dealt

      const pairResult = headsUp(heroHand, villainHand, board)
      winSum += pairResult.winRate
      tieSum += pairResult.tieRate
      loseSum += pairResult.loseRate
      totalBoardEvaluations += pairResult.trials
      validPairs++
    }
  }

  if (validPairs === 0) return { winRate: 0, tieRate: 0, loseRate: 0, trials: 0, isExact: true }

  return {
    winRate: winSum / validPairs,
    tieRate: tieSum / validPairs,
    loseRate: loseSum / validPairs,
    trials: totalBoardEvaluations,
    isExact: true,
  }
}

export function exactCanonicalVsCanonical(hero: string, villain: string, board: readonly Card[] = []): EquityResult {
  return exactRangeVsRange(expandCanonical(hero), expandCanonical(villain), board)
}

/** Calls `action` once per combination of `k` cards chosen from `pool`, backtracking
 * through a single reused array rather than materializing every combination up front. */
function forEachCombination(pool: readonly Card[], k: number, action: (combo: Card[]) => void): void {
  const current: Card[] = []

  function recurse(startIndex: number, remaining: number): void {
    if (remaining === 0) {
      action(current)
      return
    }
    if (pool.length - startIndex < remaining) return
    for (let i = startIndex; i <= pool.length - remaining; i++) {
      current.push(pool[i])
      recurse(i + 1, remaining - 1)
      current.pop()
    }
  }

  recurse(0, k)
}
