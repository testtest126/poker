// Port of PokerKit/Sources/PokerKit/ICM.swift — the Independent Chip Model
// (Malmuth-Harville method): converts chip stacks + a payout structure into each player's
// exact tournament $EV. Unlike every range model in this codebase, there's no hand-tuned
// percentage table here — this is exact math, validated against a published worked example
// (see icm.test.ts and ai-docs/ICM.md).

/**
 * Each player's exact ICM $ equity for the given `stacks` and `payouts`.
 *
 * `payouts` is ordered 1st-place-first; a finishing position beyond `payouts.length` pays
 * $0. `stacks` must all be strictly positive — a player with 0 chips has already busted
 * and isn't part of this model's field.
 *
 * **The algorithm**: P(a player finishes 1st) is their share of total remaining chips.
 * Conditional on who finished 1st, P(a remaining player finishes 2nd) is *their* share of
 * the chips remaining after removing the 1st-place finisher — recursively for every
 * subsequent place. A seat's equity sums, over every finishing position, P(finish there) x
 * that position's payout.
 *
 * Computed via bitmask memoization over "which players are still uneliminated" rather than
 * literally enumerating every one of the `n!` finishing orders the definition suggests —
 * the same exact math, just shared across orders that pass through the same remaining-set.
 * `O(2^n * n^2)` instead of `O(n!)` — trivial for realistic final-table sizes.
 */
export function icmEquities(stacks: readonly number[], payouts: readonly number[]): number[] {
  const n = stacks.length
  if (n === 0) return []
  if (!stacks.every((s) => s > 0)) {
    throw new Error('icmEquities requires every stack to be > 0 — remove a busted (0-chip) player instead of zeroing their stack.')
  }
  // JS's bitwise operators work on 32-bit signed integers, capping the bitmask this
  // function uses at 31 players (the Swift source, using a 64-bit Int, supports up to 63)
  // — not a practical limitation for a final-table/bubble tool (realistic use is <=10
  // players; even 20 is already far beyond a real final table), but a hard ceiling worth
  // failing loudly on rather than silently corrupting.
  if (n > 31) {
    throw new Error(`icmEquities supports at most 31 players (bitmask overflow), got ${n}.`)
  }

  function payoutAt(position: number): number {
    return position < payouts.length ? payouts[position] : 0
  }

  const memo = new Map<number, number[]>()

  function popcount(x: number): number {
    let count = 0
    while (x !== 0) {
      count += x & 1
      x >>>= 1
    }
    return count
  }

  function solve(remainingMask: number): number[] {
    if (remainingMask === 0) return new Array(n).fill(0)
    const cached = memo.get(remainingMask)
    if (cached) return cached

    const position = n - popcount(remainingMask)
    let remainingStackSum = 0
    for (let i = 0; i < n; i++) {
      if (remainingMask & (1 << i)) remainingStackSum += stacks[i]
    }

    const result = new Array(n).fill(0)
    for (let i = 0; i < n; i++) {
      if (!(remainingMask & (1 << i))) continue
      const pNext = stacks[i] / remainingStackSum
      const sub = solve(remainingMask & ~(1 << i))
      for (let p = 0; p < n; p++) {
        result[p] += pNext * sub[p]
      }
      result[i] += pNext * payoutAt(position)
    }

    memo.set(remainingMask, result)
    return result
  }

  return solve((1 << n) - 1)
}
