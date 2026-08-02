import { useMemo, useState } from 'react'
import { PreflopGridView } from '../components/PreflopGridView'
import { GRID_RANKS, openingGridDecisions, pushFoldGridDecisions } from '../engine/preflopGrid'
import { POSITIONS, POSITION_FULL_NAME, type Position } from '../engine/position'

type Mode = 'pushFold' | 'opening'

const MODES: { mode: Mode; label: string; stackRange: [number, number]; defaultStack: number }[] = [
  { mode: 'pushFold', label: 'Push/Fold', stackRange: [1, 20], defaultStack: 10 },
  { mode: 'opening', label: 'Opening (RFI)', stackRange: [20, 100], defaultStack: 50 },
]

export function RangeExplorer() {
  const [mode, setMode] = useState<Mode>('pushFold')
  const [position, setPosition] = useState<Position>('UTG')
  const modeConfig = MODES.find((m) => m.mode === mode)!
  const [stack, setStack] = useState(modeConfig.defaultStack)

  const decisions = useMemo(() => {
    return mode === 'pushFold' ? pushFoldGridDecisions(position, stack) : openingGridDecisions(position, stack)
  }, [mode, position, stack])

  const activeCount = decisions.flat().filter((d) => d.action === 'push' || d.action === 'raise').length
  const activePct = ((activeCount / (GRID_RANKS.length * GRID_RANKS.length)) * 100).toFixed(0)

  function handleModeChange(next: Mode) {
    setMode(next)
    const config = MODES.find((m) => m.mode === next)!
    setStack(config.defaultStack)
  }

  return (
    <div className="space-y-5">
      <div>
        <h1 className="text-2xl font-bold tracking-tight">Preflop Ranges</h1>
        <p className="mt-1 text-sm text-slate-600 dark:text-slate-400">
          Hand-tuned study aids approximating published charts — not solver output. See{' '}
          <a
            className="underline hover:text-indigo-600 dark:hover:text-indigo-400"
            href="https://github.com/testtest126/poker/blob/main/ai-docs/RANGES.md"
            target="_blank"
            rel="noreferrer"
          >
            ai-docs/RANGES.md
          </a>{' '}
          for the source basis of every number.
        </p>
      </div>

      <div className="flex flex-wrap gap-1.5">
        {MODES.map((m) => (
          <button
            key={m.mode}
            type="button"
            onClick={() => handleModeChange(m.mode)}
            className={`rounded-md px-3 py-1.5 text-sm font-medium transition-colors ${
              mode === m.mode
                ? 'bg-indigo-600 text-white'
                : 'bg-slate-200 text-slate-700 hover:bg-slate-300 dark:bg-slate-800 dark:text-slate-300 dark:hover:bg-slate-700'
            }`}
          >
            {m.label}
          </button>
        ))}
      </div>

      <div>
        <span className="mb-1 block text-xs font-medium text-slate-500">Position</span>
        <div className="flex flex-wrap gap-1.5">
          {POSITIONS.map((p) => (
            <button
              key={p}
              type="button"
              title={POSITION_FULL_NAME[p]}
              onClick={() => setPosition(p)}
              className={`rounded-md px-3 py-1.5 text-sm font-medium transition-colors ${
                position === p
                  ? 'bg-indigo-600 text-white'
                  : 'bg-slate-200 text-slate-700 hover:bg-slate-300 dark:bg-slate-800 dark:text-slate-300 dark:hover:bg-slate-700'
              }`}
            >
              {p}
            </button>
          ))}
        </div>
      </div>

      <div>
        <div className="mb-1 flex justify-between text-xs font-medium text-slate-500">
          <span>Effective Stack</span>
          <span className="tabular-nums">{stack} bb</span>
        </div>
        <input
          type="range"
          min={modeConfig.stackRange[0]}
          max={modeConfig.stackRange[1]}
          value={stack}
          onChange={(e) => setStack(Number(e.target.value))}
          className="w-full accent-indigo-600"
        />
      </div>

      <p className="text-sm font-semibold text-slate-700 dark:text-slate-300">
        {activePct}% of hands to {mode === 'pushFold' ? 'shove' : 'open'}
      </p>

      <div className="mx-auto max-w-xl">
        <PreflopGridView
          cellClass={(row, col) => {
            const active = decisions[row][col].action === 'push' || decisions[row][col].action === 'raise'
            return active
              ? 'bg-indigo-600 text-white'
              : 'bg-slate-100 text-slate-400 dark:bg-slate-800 dark:text-slate-500'
          }}
        />
      </div>

      <div className="flex flex-wrap gap-4 text-xs text-slate-500">
        <LegendSwatch colorClass="bg-indigo-600" label={mode === 'pushFold' ? 'Shove' : 'Raise'} />
        <LegendSwatch colorClass="bg-slate-100 dark:bg-slate-800" label="Fold" />
      </div>
    </div>
  )
}

function LegendSwatch({ colorClass, label }: { colorClass: string; label: string }) {
  return (
    <div className="flex items-center gap-1.5">
      <span className={`h-3 w-3 rounded-sm border border-slate-300 dark:border-slate-700 ${colorClass}`} />
      {label}
    </div>
  )
}
