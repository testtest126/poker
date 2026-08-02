import { useMemo, useState } from 'react'
import { PreflopGridView } from '../components/PreflopGridView'
import {
  callingGridDecisions,
  fourBetGridDecisions,
  GRID_RANKS,
  openDefenseGridDecisions,
  openingGridDecisions,
  pushFoldGridDecisions,
  threeBetGridDecisions,
} from '../engine/preflopGrid'
import { POSITIONS, POSITION_FULL_NAME, type Position } from '../engine/position'
import {
  DEFENDING_POSITIONS,
  DEFENDING_POSITION_FULL_NAME,
  defendingActionOrderIndex,
  positionActionOrderIndex,
  type DefendingPosition,
} from '../engine/defendingPosition'

type Mode = 'pushFold' | 'opening' | 'facingShove' | 'facingOpen' | 'threeBet' | 'fourBet'
type ControlLayout = 'position' | 'defenderVsOpener' | 'openerVsThreeBettor'
type DecisionKind = 'single' | 'threeWay' | 'polarized'
type DecisionCell = { action: string }
type Decisions = { kind: DecisionKind; grid: DecisionCell[][] | undefined }

const MODES: {
  mode: Mode
  label: string
  layout: ControlLayout
  stackRange: [number, number]
  defaultStack: number
}[] = [
  { mode: 'pushFold', label: 'Push/Fold', layout: 'position', stackRange: [1, 20], defaultStack: 10 },
  { mode: 'opening', label: 'Opening (RFI)', layout: 'position', stackRange: [20, 100], defaultStack: 50 },
  { mode: 'facingShove', label: 'Facing Shove', layout: 'defenderVsOpener', stackRange: [1, 20], defaultStack: 10 },
  { mode: 'facingOpen', label: 'Facing Open', layout: 'defenderVsOpener', stackRange: [20, 100], defaultStack: 50 },
  { mode: 'threeBet', label: '3-Bet', layout: 'defenderVsOpener', stackRange: [20, 100], defaultStack: 100 },
  { mode: 'fourBet', label: '4-Bet', layout: 'openerVsThreeBettor', stackRange: [20, 100], defaultStack: 100 },
]

function validDefendingPositions(after: Position): DefendingPosition[] {
  return DEFENDING_POSITIONS.filter((p) => defendingActionOrderIndex(p) > positionActionOrderIndex(after))
}

export function RangeExplorer() {
  const [mode, setMode] = useState<Mode>('pushFold')
  const [position, setPosition] = useState<Position>('UTG')
  const [opponentPosition, setOpponentPosition] = useState<Position>('UTG')
  const [heroPosition, setHeroPosition] = useState<DefendingPosition>('BB')
  const modeConfig = MODES.find((m) => m.mode === mode)!
  const [stack, setStack] = useState(modeConfig.defaultStack)

  const decisions = useMemo(() => {
    switch (mode) {
      case 'pushFold':
        return { kind: 'single' as const, grid: pushFoldGridDecisions(position, stack) }
      case 'opening':
        return { kind: 'single' as const, grid: openingGridDecisions(position, stack) }
      case 'facingShove':
        return { kind: 'single' as const, grid: callingGridDecisions(heroPosition, opponentPosition, stack) }
      case 'facingOpen':
        return { kind: 'threeWay' as const, grid: openDefenseGridDecisions(heroPosition, opponentPosition, stack) }
      case 'threeBet':
        return { kind: 'polarized' as const, grid: threeBetGridDecisions(heroPosition, opponentPosition, stack) }
      case 'fourBet':
        return { kind: 'polarized' as const, grid: fourBetGridDecisions(position, heroPosition, stack) }
    }
  }, [mode, position, opponentPosition, heroPosition, stack])

  function handleModeChange(next: Mode) {
    const config = MODES.find((m) => m.mode === next)!
    setMode(next)
    setStack(config.defaultStack)
    // Land on a sensible default combo for each mode, same spirit as the iOS app: for
    // 3-bet/4-bet, default to the pairing each model's own sourced anchor was measured at.
    if (next === 'threeBet') {
      setOpponentPosition('BTN')
      setHeroPosition('BB')
    } else if (next === 'fourBet') {
      setPosition('CO')
      setHeroPosition('BTN')
    } else if (next === 'facingShove' || next === 'facingOpen') {
      setHeroPosition('BB')
    }
  }

  function handleOpponentChange(next: Position) {
    setOpponentPosition(next)
    if (defendingActionOrderIndex(heroPosition) <= positionActionOrderIndex(next)) {
      setHeroPosition('BB')
    }
  }

  function handleOpenerChange(next: Position) {
    setPosition(next)
    if (defendingActionOrderIndex(heroPosition) <= positionActionOrderIndex(next)) {
      setHeroPosition('BB')
    }
  }

  const activeCount = decisions.grid ? countActive(decisions) : 0
  const totalCells = GRID_RANKS.length * GRID_RANKS.length
  const activePct = ((activeCount / totalCells) * 100).toFixed(0)

  return (
    <div className="space-y-5">
      <div>
        <h1 className="text-2xl font-bold tracking-tight">Preflop Ranges</h1>
        <p className="mt-1 text-sm text-slate-600 dark:text-slate-400">
          Hand-tuned study aids approximating published charts — not solver output. 3-Bet/4-Bet
          are a separate, more polarized opinion than Facing Open and will deliberately
          disagree with it on the same spot. See{' '}
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

      {modeConfig.layout === 'position' && (
        <PositionPicker label="Position" value={position} onChange={setPosition} />
      )}

      {modeConfig.layout === 'defenderVsOpener' && (
        <div className="space-y-3">
          <PositionPicker
            label={mode === 'facingShove' ? 'Shover' : 'Opener'}
            value={opponentPosition}
            onChange={handleOpponentChange}
          />
          <DefendingPositionPicker
            label="You"
            value={heroPosition}
            options={validDefendingPositions(opponentPosition)}
            onChange={setHeroPosition}
          />
        </div>
      )}

      {modeConfig.layout === 'openerVsThreeBettor' && (
        <div className="space-y-3">
          <PositionPicker label="You Opened" value={position} onChange={handleOpenerChange} />
          <DefendingPositionPicker
            label="3-Bettor"
            value={heroPosition}
            options={validDefendingPositions(position)}
            onChange={setHeroPosition}
          />
        </div>
      )}

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
        {decisions.grid ? summaryText(mode, decisions, activePct) : "This position pairing can't happen at an unopened table."}
      </p>

      {decisions.grid && (
        <>
          <div className="mx-auto max-w-xl">
            <PreflopGridView cellClass={(row, col) => cellClass(decisions, row, col)} />
          </div>

          <div className="flex flex-wrap gap-4 text-xs text-slate-500">{legend(mode)}</div>
        </>
      )}
    </div>
  )
}

function countActive(decisions: Decisions): number {
  if (!decisions.grid) return 0
  return decisions.grid.flat().filter((d) => isActive(decisions.kind, d.action)).length
}

function isActive(kind: DecisionKind, action: string): boolean {
  if (kind === 'single') return action === 'push' || action === 'raise' || action === 'call'
  return action !== 'fold'
}

function cellClass(decisions: Decisions, row: number, col: number): string {
  const action = decisions.grid![row][col].action
  const fold = 'bg-slate-100 text-slate-400 dark:bg-slate-800 dark:text-slate-500'
  if (decisions.kind === 'single') {
    return action === 'fold' ? fold : 'bg-indigo-600 text-white'
  }
  if (decisions.kind === 'threeWay') {
    if (action === 'threeBet') return 'bg-indigo-600 text-white'
    if (action === 'call') return 'bg-teal-600 text-white'
    return fold
  }
  // polarized: value / bluff / call / fold
  if (action === 'threeBetValue' || action === 'fourBetValue') return 'bg-indigo-600 text-white'
  if (action === 'threeBetBluff' || action === 'fourBetBluff') return 'bg-purple-600 text-white'
  if (action === 'call') return 'bg-teal-600 text-white'
  return fold
}

function summaryText(mode: Mode, decisions: Decisions, activePct: string): string {
  const flat = decisions.grid!.flat()
  const total = flat.length
  switch (mode) {
    case 'pushFold':
      return `${activePct}% of hands to shove`
    case 'opening':
      return `${activePct}% of hands to open`
    case 'facingShove':
      return `${activePct}% of hands to call`
    case 'facingOpen': {
      const threeBetPct = ((flat.filter((d) => d.action === 'threeBet').length / total) * 100).toFixed(0)
      return `${activePct}% of hands to defend (${threeBetPct}% 3-bet)`
    }
    case 'threeBet': {
      const valuePct = ((flat.filter((d) => d.action === 'threeBetValue').length / total) * 100).toFixed(0)
      const bluffPct = ((flat.filter((d) => d.action === 'threeBetBluff').length / total) * 100).toFixed(0)
      return `${activePct}% of hands to defend (${valuePct}% value, ${bluffPct}% bluff)`
    }
    case 'fourBet': {
      const valuePct = ((flat.filter((d) => d.action === 'fourBetValue').length / total) * 100).toFixed(0)
      const bluffPct = ((flat.filter((d) => d.action === 'fourBetBluff').length / total) * 100).toFixed(0)
      return `${activePct}% of hands to continue (${valuePct}% value, ${bluffPct}% bluff)`
    }
  }
}

function legend(mode: Mode) {
  const swatch = (colorClass: string, label: string) => (
    <div key={label} className="flex items-center gap-1.5">
      <span className={`h-3 w-3 rounded-sm border border-slate-300 dark:border-slate-700 ${colorClass}`} />
      {label}
    </div>
  )
  const fold = swatch('bg-slate-100 dark:bg-slate-800', 'Fold')
  switch (mode) {
    case 'pushFold':
      return [swatch('bg-indigo-600', 'Shove'), fold]
    case 'opening':
      return [swatch('bg-indigo-600', 'Raise'), fold]
    case 'facingShove':
      return [swatch('bg-indigo-600', 'Call'), fold]
    case 'facingOpen':
      return [swatch('bg-indigo-600', '3-Bet'), swatch('bg-teal-600', 'Call'), fold]
    case 'threeBet':
      return [swatch('bg-indigo-600', '3-Bet Value'), swatch('bg-purple-600', '3-Bet Bluff'), swatch('bg-teal-600', 'Call'), fold]
    case 'fourBet':
      return [swatch('bg-indigo-600', '4-Bet Value'), swatch('bg-purple-600', '4-Bet Bluff'), swatch('bg-teal-600', 'Call'), fold]
  }
}

function PositionPicker({ label, value, onChange }: { label: string; value: Position; onChange: (p: Position) => void }) {
  return (
    <div>
      <span className="mb-1 block text-xs font-medium text-slate-500">{label}</span>
      <div className="flex flex-wrap gap-1.5">
        {POSITIONS.map((p) => (
          <button
            key={p}
            type="button"
            title={POSITION_FULL_NAME[p]}
            onClick={() => onChange(p)}
            className={`rounded-md px-3 py-1.5 text-sm font-medium transition-colors ${
              value === p
                ? 'bg-indigo-600 text-white'
                : 'bg-slate-200 text-slate-700 hover:bg-slate-300 dark:bg-slate-800 dark:text-slate-300 dark:hover:bg-slate-700'
            }`}
          >
            {p}
          </button>
        ))}
      </div>
    </div>
  )
}

function DefendingPositionPicker({
  label,
  value,
  options,
  onChange,
}: {
  label: string
  value: DefendingPosition
  options: DefendingPosition[]
  onChange: (p: DefendingPosition) => void
}) {
  return (
    <div>
      <span className="mb-1 block text-xs font-medium text-slate-500">{label}</span>
      <div className="flex flex-wrap gap-1.5">
        {options.map((p) => (
          <button
            key={p}
            type="button"
            title={DEFENDING_POSITION_FULL_NAME[p]}
            onClick={() => onChange(p)}
            className={`rounded-md px-3 py-1.5 text-sm font-medium transition-colors ${
              value === p
                ? 'bg-indigo-600 text-white'
                : 'bg-slate-200 text-slate-700 hover:bg-slate-300 dark:bg-slate-800 dark:text-slate-300 dark:hover:bg-slate-700'
            }`}
          >
            {p}
          </button>
        ))}
      </div>
    </div>
  )
}
