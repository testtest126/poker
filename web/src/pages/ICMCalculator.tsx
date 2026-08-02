import { useMemo, useState } from 'react'
import { icmEquities } from '../engine/icm'

interface StackEntry {
  id: number
  name: string
  stack: string
}

let nextId = 4

export function ICMCalculator() {
  const [stacks, setStacks] = useState<StackEntry[]>([
    { id: 1, name: 'Seat 1', stack: '5000' },
    { id: 2, name: 'Seat 2', stack: '3000' },
    { id: 3, name: 'Seat 3', stack: '2000' },
  ])
  const [payouts, setPayouts] = useState<string[]>(['500', '300', '200'])

  const parsedStacks = useMemo(() => {
    const values = stacks.map((s) => Number(s.stack))
    if (!values.every((v) => Number.isFinite(v) && v > 0)) return undefined
    return values
  }, [stacks])

  const parsedPayouts = useMemo(() => {
    const values = payouts.map((p) => Number(p))
    if (!values.every((v) => Number.isFinite(v) && v >= 0)) return undefined
    return values
  }, [payouts])

  const equities = useMemo(() => {
    if (!parsedStacks || parsedStacks.length === 0 || !parsedPayouts) return undefined
    return icmEquities(parsedStacks, parsedPayouts)
  }, [parsedStacks, parsedPayouts])

  const validationMessage = (() => {
    if (stacks.length === 0) return 'Add at least one stack.'
    if (!parsedStacks) return 'Every stack needs a positive number.'
    if (!parsedPayouts) return 'Every payout needs a number (0 or more).'
    return null
  })()

  function updateStack(id: number, patch: Partial<StackEntry>) {
    setStacks((prev) => prev.map((s) => (s.id === id ? { ...s, ...patch } : s)))
  }

  function removeStack(id: number) {
    setStacks((prev) => prev.filter((s) => s.id !== id))
  }

  function addStack() {
    const id = nextId++
    setStacks((prev) => [...prev, { id, name: `Seat ${prev.length + 1}`, stack: '' }])
  }

  function updatePayout(index: number, value: string) {
    setPayouts((prev) => prev.map((p, i) => (i === index ? value : p)))
  }

  function removePayout(index: number) {
    setPayouts((prev) => prev.filter((_, i) => i !== index))
  }

  function addPayout() {
    setPayouts((prev) => [...prev, ''])
  }

  function placeLabel(index: number): string {
    if (index === 0) return '1st'
    if (index === 1) return '2nd'
    if (index === 2) return '3rd'
    return `${index + 1}th`
  }

  const totalChips = parsedStacks?.reduce((a, b) => a + b, 0) ?? 0

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold tracking-tight">ICM Calculator</h1>
        <p className="mt-1 text-sm text-slate-600 dark:text-slate-400">
          Exact tournament $EV for any set of stacks and a payout structure — Malmuth-Harville
          ICM, not a rule of thumb. See{' '}
          <a
            className="underline hover:text-indigo-600 dark:hover:text-indigo-400"
            href="https://github.com/testtest126/poker/blob/main/ai-docs/ICM.md"
            target="_blank"
            rel="noreferrer"
          >
            ai-docs/ICM.md
          </a>{' '}
          for the derivation and worked-example validation.
        </p>
      </div>

      <div>
        <span className="mb-2 block text-xs font-medium text-slate-500">Stacks</span>
        <div className="space-y-2">
          {stacks.map((entry) => (
            <div key={entry.id} className="flex gap-2">
              <input
                value={entry.name}
                onChange={(e) => updateStack(entry.id, { name: e.target.value })}
                placeholder="Name"
                className="min-w-0 flex-1 rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:border-indigo-500 focus:outline-none dark:border-slate-700 dark:bg-slate-900"
              />
              <input
                value={entry.stack}
                onChange={(e) => updateStack(entry.id, { stack: e.target.value })}
                placeholder="Chips"
                inputMode="numeric"
                className="w-28 rounded-md border border-slate-300 bg-white px-3 py-2 text-right text-sm focus:border-indigo-500 focus:outline-none dark:border-slate-700 dark:bg-slate-900"
              />
              <button
                type="button"
                onClick={() => removeStack(entry.id)}
                aria-label={`Remove ${entry.name}`}
                className="rounded-md px-2 text-slate-400 hover:bg-slate-200 hover:text-slate-700 dark:hover:bg-slate-800 dark:hover:text-slate-200"
              >
                ✕
              </button>
            </div>
          ))}
        </div>
        <button
          type="button"
          onClick={addStack}
          className="mt-2 rounded-md bg-slate-200 px-3 py-1.5 text-sm font-medium text-slate-700 hover:bg-slate-300 dark:bg-slate-800 dark:text-slate-300 dark:hover:bg-slate-700"
        >
          + Add Player
        </button>
      </div>

      <div>
        <span className="mb-2 block text-xs font-medium text-slate-500">Payouts</span>
        <div className="space-y-2">
          {payouts.map((amount, index) => (
            <div key={index} className="flex items-center gap-2">
              <span className="w-10 text-sm text-slate-500">{placeLabel(index)}</span>
              <input
                value={amount}
                onChange={(e) => updatePayout(index, e.target.value)}
                placeholder="Amount"
                inputMode="numeric"
                className="flex-1 rounded-md border border-slate-300 bg-white px-3 py-2 text-right text-sm focus:border-indigo-500 focus:outline-none dark:border-slate-700 dark:bg-slate-900"
              />
              <button
                type="button"
                onClick={() => removePayout(index)}
                aria-label={`Remove ${placeLabel(index)} place payout`}
                className="rounded-md px-2 text-slate-400 hover:bg-slate-200 hover:text-slate-700 dark:hover:bg-slate-800 dark:hover:text-slate-200"
              >
                ✕
              </button>
            </div>
          ))}
        </div>
        <button
          type="button"
          onClick={addPayout}
          className="mt-2 rounded-md bg-slate-200 px-3 py-1.5 text-sm font-medium text-slate-700 hover:bg-slate-300 dark:bg-slate-800 dark:text-slate-300 dark:hover:bg-slate-700"
        >
          + Add Place
        </button>
      </div>

      {equities && parsedStacks ? (
        <div className="space-y-3 rounded-lg border border-slate-200 bg-white p-4 dark:border-slate-800 dark:bg-slate-900">
          {stacks.map((entry, i) => {
            const stack = parsedStacks[i]
            const equity = equities[i]
            return (
              <div key={entry.id} className="flex items-baseline justify-between">
                <div>
                  <div className="font-semibold">{entry.name}</div>
                  <div className="text-xs text-slate-500">
                    {((stack / totalChips) * 100).toFixed(1)}% of chips — ${(equity / stack).toFixed(2)}/chip
                  </div>
                </div>
                <div className="tabular-nums font-semibold">${equity.toFixed(2)}</div>
              </div>
            )
          })}
          <div className="flex justify-between border-t border-slate-200 pt-2 text-xs text-slate-500 dark:border-slate-800">
            <span>Total</span>
            <span className="tabular-nums">${equities.reduce((a, b) => a + b, 0).toFixed(2)}</span>
          </div>
          <p className="text-xs text-slate-500">
            Exact math (Malmuth-Harville ICM), not a solver or a hand-tuned estimate.
          </p>
        </div>
      ) : (
        validationMessage && <p className="text-xs text-slate-500">{validationMessage}</p>
      )}
    </div>
  )
}
