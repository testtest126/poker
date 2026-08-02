import { useMemo, useState } from 'react'
import type { Card } from '../engine/card'
import { cardKey } from '../engine/card'
import { canonicalVsCanonical, exactCanonicalVsCanonical, expandCanonical, type EquityResult } from '../engine/equity'
import { normalizeHandNotation, parseCardString } from '../lib/cardInput'

type Street = 'preflop' | 'flop' | 'turn' | 'river'
type Mode = 'fast' | 'precise'

const STREETS: { street: Street; label: string; boardCount: number }[] = [
  { street: 'preflop', label: 'Preflop', boardCount: 0 },
  { street: 'flop', label: 'Flop', boardCount: 3 },
  { street: 'turn', label: 'Turn', boardCount: 4 },
  { street: 'river', label: 'River', boardCount: 5 },
]

function resolvedBoard(boardCards: Card[] | undefined, boardCount: number): Card[] | undefined {
  if (!boardCards || boardCards.length !== boardCount) return undefined
  const keys = boardCards.map(cardKey)
  if (new Set(keys).size !== keys.length) return undefined
  return boardCards
}

export function EquityCalculator() {
  const [heroNotation, setHeroNotation] = useState('AKs')
  const [villainNotation, setVillainNotation] = useState('QQ')
  const [street, setStreet] = useState<Street>('preflop')
  const [boardText, setBoardText] = useState('')
  const [mode, setMode] = useState<Mode>('fast')
  const [result, setResult] = useState<EquityResult | null>(null)
  const [isCalculating, setIsCalculating] = useState(false)

  const boardCount = STREETS.find((s) => s.street === street)!.boardCount
  const heroCombos = useMemo(() => expandCanonical(normalizeHandNotation(heroNotation)), [heroNotation])
  const villainCombos = useMemo(() => expandCanonical(normalizeHandNotation(villainNotation)), [villainNotation])
  const parsedBoard = useMemo(() => parseCardString(boardText), [boardText])
  const board = resolvedBoard(parsedBoard, boardCount)

  const validationMessage = (() => {
    if (heroNotation.trim() && heroCombos.length === 0) return 'Hero isn\'t a valid hand — try "AKs", "QQ", or "72o".'
    if (villainNotation.trim() && villainCombos.length === 0) return 'Villain isn\'t a valid hand — try "AKs", "QQ", or "72o".'
    if (boardCount > 0 && !board) return `Enter exactly ${boardCount} board card${boardCount === 1 ? '' : 's'} (e.g. "AsKdTh").`
    return null
  })()

  const isReady = heroCombos.length > 0 && villainCombos.length > 0 && (boardCount === 0 || board !== undefined)

  function handleStreetChange(next: Street) {
    setStreet(next)
    setResult(null)
    if (next === 'preflop') setMode('fast')
  }

  function calculate() {
    if (!isReady) return
    setIsCalculating(true)
    setResult(null)
    // A short defer lets the "Calculating…" state actually paint before the synchronous
    // computation below runs — this is plain single-threaded JS (no Web Worker tonight),
    // so without this the UI would freeze silently for the duration of the calculation
    // instead of showing that something's happening.
    setTimeout(() => {
      const hero = normalizeHandNotation(heroNotation)
      const villain = normalizeHandNotation(villainNotation)
      const computed =
        mode === 'precise' && board
          ? exactCanonicalVsCanonical(hero, villain, board)
          : canonicalVsCanonical(hero, villain, board ?? [])
      setResult(computed)
      setIsCalculating(false)
    }, 10)
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold tracking-tight">Equity Calculator</h1>
        <p className="mt-1 text-sm text-slate-600 dark:text-slate-400">
          Win/tie/lose probability for any hand or hand class vs. another — combo-weighted,
          the same "AA vs. KK ≈ 82%" figures you'll see cited elsewhere.
        </p>
      </div>

      <div className="grid gap-4 sm:grid-cols-2">
        <Field label="Hero">
          <input
            value={heroNotation}
            onChange={(e) => {
              setHeroNotation(e.target.value)
              setResult(null)
            }}
            placeholder="e.g. AKs, QQ, 72o"
            className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm uppercase focus:border-indigo-500 focus:outline-none dark:border-slate-700 dark:bg-slate-900"
          />
        </Field>
        <Field label="Villain">
          <input
            value={villainNotation}
            onChange={(e) => {
              setVillainNotation(e.target.value)
              setResult(null)
            }}
            placeholder="e.g. AKs, QQ, 72o"
            className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm uppercase focus:border-indigo-500 focus:outline-none dark:border-slate-700 dark:bg-slate-900"
          />
        </Field>
      </div>

      <Field label="Board">
        <div className="flex flex-wrap gap-1.5">
          {STREETS.map((s) => (
            <button
              key={s.street}
              type="button"
              onClick={() => handleStreetChange(s.street)}
              className={`rounded-md px-3 py-1.5 text-sm font-medium transition-colors ${
                street === s.street
                  ? 'bg-indigo-600 text-white'
                  : 'bg-slate-200 text-slate-700 hover:bg-slate-300 dark:bg-slate-800 dark:text-slate-300 dark:hover:bg-slate-700'
              }`}
            >
              {s.label}
            </button>
          ))}
        </div>
        {boardCount > 0 && (
          <input
            value={boardText}
            onChange={(e) => {
              setBoardText(e.target.value)
              setResult(null)
            }}
            placeholder={`e.g. ${['As', 'Kd', 'Th', '9c', '2s'].slice(0, boardCount).join('')}`}
            className="mt-2 w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:border-indigo-500 focus:outline-none dark:border-slate-700 dark:bg-slate-900"
          />
        )}
      </Field>

      <Field label="Mode">
        <div className="flex gap-1.5">
          {(['fast', 'precise'] as const).map((m) => (
            <button
              key={m}
              type="button"
              disabled={street === 'preflop'}
              onClick={() => {
                setMode(m)
                setResult(null)
              }}
              className={`rounded-md px-3 py-1.5 text-sm font-medium transition-colors disabled:cursor-not-allowed disabled:opacity-40 ${
                mode === m
                  ? 'bg-indigo-600 text-white'
                  : 'bg-slate-200 text-slate-700 hover:bg-slate-300 dark:bg-slate-800 dark:text-slate-300 dark:hover:bg-slate-700'
              }`}
            >
              {m === 'fast' ? 'Fast (Monte Carlo)' : 'Precise (Exact)'}
            </button>
          ))}
        </div>
        {street === 'preflop' && (
          <p className="mt-1 text-xs text-slate-500">
            Precise needs a board — an exact answer across a full hand class preflop is
            intractable in a browser tab. Fast (Monte Carlo) is accurate enough for study
            purposes.
          </p>
        )}
      </Field>

      <div>
        <button
          type="button"
          onClick={calculate}
          disabled={!isReady || isCalculating}
          className="w-full rounded-md bg-indigo-600 px-4 py-2.5 text-sm font-semibold text-white transition-colors hover:bg-indigo-700 disabled:cursor-not-allowed disabled:opacity-40 sm:w-auto"
        >
          {isCalculating ? 'Calculating…' : 'Calculate'}
        </button>
        {validationMessage && <p className="mt-2 text-xs text-slate-500">{validationMessage}</p>}
      </div>

      {result && (
        <div className="space-y-3 rounded-lg border border-slate-200 bg-white p-4 dark:border-slate-800 dark:bg-slate-900">
          <ResultBar label="Hero wins" value={result.winRate} colorClass="bg-emerald-500" />
          <ResultBar label="Tie" value={result.tieRate} colorClass="bg-slate-400" />
          <ResultBar label="Villain wins" value={result.loseRate} colorClass="bg-rose-500" />
          <p className="text-xs text-slate-500">
            {result.isExact
              ? `Exact — ${result.trials.toLocaleString()} board(s) enumerated across every matching combo pair, zero sampling error.`
              : `${result.trials.toLocaleString()} Monte Carlo simulations, fixed seed — same inputs always give the same result.`}{' '}
            Not a solver.
          </p>
        </div>
      )}
    </div>
  )
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div>
      <span className="mb-1 block text-xs font-medium text-slate-500">{label}</span>
      {children}
    </div>
  )
}

function ResultBar({ label, value, colorClass }: { label: string; value: number; colorClass: string }) {
  const pct = (value * 100).toFixed(1)
  return (
    <div>
      <div className="mb-1 flex justify-between text-sm">
        <span>{label}</span>
        <span className="font-semibold tabular-nums">{pct}%</span>
      </div>
      <div className="h-2 w-full overflow-hidden rounded-full bg-slate-100 dark:bg-slate-800">
        <div className={`h-full ${colorClass}`} style={{ width: `${Math.max(Number(pct), 1)}%` }} />
      </div>
    </div>
  )
}
