import { GRID_RANKS, gridNotation } from '../engine/preflopGrid'

export function PreflopGridView({ cellClass }: { cellClass: (row: number, col: number) => string }) {
  return (
    <div className="grid grid-cols-[repeat(13,minmax(0,1fr))] gap-0.5">
      {GRID_RANKS.map((_, row) =>
        GRID_RANKS.map((_, col) => {
          const notation = gridNotation(row, col)
          return (
            <div
              key={notation}
              className={`flex aspect-square items-center justify-center rounded-[3px] text-[9px] font-semibold sm:text-xs ${cellClass(row, col)}`}
            >
              {notation}
            </div>
          )
        }),
      )}
    </div>
  )
}
