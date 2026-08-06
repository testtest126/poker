import { useEffect, useState } from 'react'
import type { Card } from '../engine/card'
import { rankSymbol, suitSymbol } from '../engine/card'
import { POSITION_FULL_NAME } from '../engine/position'
import { DEFENDING_POSITION_FULL_NAME } from '../engine/defendingPosition'
import {
  TRAINER_MODES,
  TRAINER_MODE_ACTIONS,
  TRAINER_MODE_LABEL,
  generateSpot,
  gradeAnswer,
  type TrainerAction,
  type TrainerMode,
  type TrainerSpot,
} from '../engine/trainer'

type ModeFilter = TrainerMode | 'mixed'

function randomMode(): TrainerMode {
  return TRAINER_MODES[Math.floor(Math.random() * TRAINER_MODES.length)]
}

function spotDescription(spot: TrainerSpot): string {
  const stack = `${spot.stack}bb effective`
  switch (spot.mode) {
    case 'pushFold':
    case 'opening':
      return `Unopened pot. You're in the ${POSITION_FULL_NAME[spot.position!]} (${spot.position}), ${stack}. Everyone else has folded.`
    case 'facingShove':
      return `${spot.opponentPosition} shoves all-in. You're in the ${DEFENDING_POSITION_FULL_NAME[spot.heroPosition!]} (${spot.heroPosition}), ${stack}.`
    case 'facingOpen':
    case 'threeBet':
      return `${spot.opponentPosition} opens. You're in the ${DEFENDING_POSITION_FULL_NAME[spot.heroPosition!]} (${spot.heroPosition}), ${stack}.`
    case 'fourBet':
      return `You open from the ${POSITION_FULL_NAME[spot.position!]} (${spot.position}). ${DEFENDING_POSITION_FULL_NAME[spot.heroPosition!]} (${spot.heroPosition}) 3-bets you, ${stack}.`
  }
}

function CardView({ card }: { card: Card }) {
  const isRed = card.suit === 'hearts' || card.suit === 'diamonds'
  return (
    <div
      className={`flex h-16 w-12 flex-col items-center justify-center rounded-sm border border-hairline bg-surface font-mono text-xl font-bold ${
        isRed ? 'text-raise' : 'text-text-primary'
      }`}
    >
      <span>{rankSymbol(card.rank)}</span>
      <span>{suitSymbol(card.suit)}</span>
    </div>
  )
}

export function Trainer() {
  const [modeFilter, setModeFilter] = useState<ModeFilter>('mixed')
  const [spot, setSpot] = useState<TrainerSpot>(() => generateSpot(randomMode()))
  const [selected, setSelected] = useState<TrainerAction | null>(null)
  const [score, setScore] = useState({ correct: 0, total: 0 })
  const [streak, setStreak] = useState(0)
  const [bestStreak, setBestStreak] = useState(0)

  function dealNewSpot(filter: ModeFilter) {
    setSpot(generateSpot(filter === 'mixed' ? randomMode() : filter))
    setSelected(null)
  }

  useEffect(() => {
    dealNewSpot(modeFilter)
    setScore({ correct: 0, total: 0 })
    setStreak(0)
    setBestStreak(0)
    // Switching drill categories starts a fresh session — same reasoning the Range
    // Explorer uses when it resets the stack slider on a mode change.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [modeFilter])

  function handleAnswer(action: TrainerAction) {
    if (selected) return
    setSelected(action)
    const correct = gradeAnswer(spot, action)
    setScore((s) => ({ correct: s.correct + (correct ? 1 : 0), total: s.total + 1 }))
    setStreak((s) => {
      const next = correct ? s + 1 : 0
      setBestStreak((b) => Math.max(b, next))
      return next
    })
  }

  const accuracy = score.total > 0 ? Math.round((score.correct / score.total) * 100) : null

  return (
    <div className="space-y-5">
      <div>
        <h1 className="text-xl font-semibold tracking-tight text-text-primary">Preflop Trainer</h1>
        <p className="mt-1 text-sm text-text-secondary">
          Drills the same hand-tuned charts as Preflop Ranges — it grades you against those charts, not against a solver. See{' '}
          <a
            className="underline decoration-hairline-strong underline-offset-2 transition-colors hover:text-text-primary"
            href="https://github.com/testtest126/poker/blob/main/ai-docs/RANGES.md"
            target="_blank"
            rel="noreferrer"
          >
            ai-docs/RANGES.md
          </a>{' '}
          for the source basis of every answer.
        </p>
      </div>

      <div className="flex flex-wrap gap-x-5 gap-y-1 border-b border-hairline text-sm">
        <button
          type="button"
          onClick={() => setModeFilter('mixed')}
          className={`border-b-2 py-2 font-medium transition-colors ${
            modeFilter === 'mixed' ? 'border-accent-bright text-text-primary' : 'border-transparent text-text-secondary hover:text-text-primary'
          }`}
        >
          Mixed
        </button>
        {TRAINER_MODES.map((m) => (
          <button
            key={m}
            type="button"
            onClick={() => setModeFilter(m)}
            className={`border-b-2 py-2 font-medium transition-colors ${
              modeFilter === m ? 'border-accent-bright text-text-primary' : 'border-transparent text-text-secondary hover:text-text-primary'
            }`}
          >
            {TRAINER_MODE_LABEL[m]}
          </button>
        ))}
      </div>

      <div className="flex flex-wrap items-center gap-x-6 gap-y-1 text-sm">
        <span className="text-text-secondary">
          Score:{' '}
          <span className="font-mono font-semibold tabular-nums text-text-primary">
            {score.correct}/{score.total}
          </span>
          {accuracy !== null && <span className="ml-1 font-mono tabular-nums text-text-secondary">({accuracy}%)</span>}
        </span>
        <span className="text-text-secondary">
          Streak: <span className="font-mono font-semibold tabular-nums text-text-primary">{streak}</span>
          {bestStreak > 0 && <span className="ml-1 font-mono tabular-nums text-text-secondary">(best {bestStreak})</span>}
        </span>
      </div>

      <div className="space-y-4 rounded-sm border border-hairline bg-surface p-5">
        <div className="text-xs font-medium text-text-tertiary">{TRAINER_MODE_LABEL[spot.mode]}</div>

        <div className="flex justify-center gap-2">
          <CardView card={spot.hand.first} />
          <CardView card={spot.hand.second} />
        </div>

        <p className="text-center text-sm text-text-secondary">{spotDescription(spot)}</p>

        <div className="flex flex-wrap justify-center gap-2">
          {TRAINER_MODE_ACTIONS[spot.mode].map((option) => {
            const isSelected = selected === option.action
            const isCorrectAnswer = option.action === spot.correctAction
            let className = 'rounded-sm border border-hairline bg-surface-raised px-4 py-2 text-sm font-semibold text-text-secondary transition-colors hover:border-hairline-strong hover:text-text-primary'
            if (selected) {
              if (isCorrectAnswer) {
                className = 'rounded-sm border border-accent bg-accent/20 px-4 py-2 text-sm font-semibold text-accent-bright'
              } else if (isSelected) {
                className = 'rounded-sm border border-raise bg-raise/20 px-4 py-2 text-sm font-semibold text-raise'
              } else {
                className = 'rounded-sm border border-hairline bg-surface px-4 py-2 text-sm font-semibold text-text-tertiary'
              }
            }
            return (
              <button key={option.action} type="button" onClick={() => handleAnswer(option.action)} disabled={selected !== null} className={className}>
                {option.label}
              </button>
            )
          })}
        </div>

        {selected && (
          <div className="space-y-3 border-t border-hairline pt-4 text-center">
            <p className={`text-sm font-semibold ${selected === spot.correctAction ? 'text-accent-bright' : 'text-raise'}`}>
              {selected === spot.correctAction ? 'Correct' : `Not quite — the chart says ${TRAINER_MODE_ACTIONS[spot.mode].find((o) => o.action === spot.correctAction)?.label}`}
            </p>
            <p className="text-sm text-text-secondary">{spot.reasoning}</p>
            <button
              type="button"
              onClick={() => dealNewSpot(modeFilter)}
              className="rounded-sm bg-accent px-4 py-2 text-sm font-semibold text-text-primary transition-colors hover:bg-accent/80"
            >
              Next Hand
            </button>
          </div>
        )}
      </div>
    </div>
  )
}
