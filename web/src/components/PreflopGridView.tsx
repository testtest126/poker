import { GRID_RANKS, gridNotation } from '../engine/preflopGrid'

export function PreflopGridView({
  cellClass,
  cellTooltip,
}: {
  cellClass: (row: number, col: number) => string
  cellTooltip?: (row: number, col: number) => string
}) {
  return (
    <div className="grid grid-cols-[repeat(13,minmax(0,1fr))] gap-px overflow-hidden rounded-sm border border-hairline bg-hairline">
      {GRID_RANKS.map((_, row) =>
        GRID_RANKS.map((_, col) => {
          const notation = gridNotation(row, col)
          const tooltip = cellTooltip?.(row, col)
          return (
            <div key={notation} className="group relative">
              <div
                className={`flex aspect-square items-center justify-center font-mono text-[8px] font-semibold tabular-nums transition-colors sm:text-[10px] ${cellClass(row, col)}`}
              >
                {notation}
              </div>
              {tooltip && (
                <div className="pointer-events-none absolute left-1/2 top-full z-10 mt-1 hidden -translate-x-1/2 whitespace-nowrap rounded-sm border border-hairline-strong bg-surface-raised px-2 py-1 font-mono text-[11px] font-medium text-text-primary shadow-lg group-hover:block">
                  {tooltip}
                </div>
              )}
            </div>
          )
        }),
      )}
    </div>
  )
}
