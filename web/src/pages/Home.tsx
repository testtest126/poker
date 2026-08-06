import type { Page } from '../App'

const CARDS: { page: Page; title: string; description: string }[] = [
  {
    page: 'trainer',
    title: 'Preflop Trainer',
    description: 'Random hand, random spot — fold, call, or raise? Graded against the same charts as Preflop Ranges, with a one-line "why" after every answer.',
  },
  {
    page: 'equity',
    title: 'Equity Calculator',
    description: 'Win/tie/lose probability for any hand or hand class vs. another, on any board — exact math, not a rule of thumb.',
  },
  {
    page: 'ranges',
    title: 'Preflop Ranges',
    description: 'Push/fold, opening, facing shove/open, and 3-bet/4-bet ranges by position and effective stack — a 13×13 grid you can actually read.',
  },
  {
    page: 'icm',
    title: 'ICM Calculator',
    description: 'Exact tournament $EV for any set of stacks and a payout structure — Malmuth-Harville ICM, not a rule of thumb.',
  },
  {
    page: 'import',
    title: 'Import Hand History',
    description: 'Paste or drop a PokerStars .txt export — parsed entirely in your browser, never uploaded anywhere.',
  },
]

export function Home({ onNavigate }: { onNavigate: (p: Page) => void }) {
  return (
    <div className="space-y-8">
      <section className="space-y-3">
        <h1 className="text-3xl font-bold tracking-tight text-text-primary sm:text-4xl">A free, open-source hold'em study tool</h1>
        <p className="max-w-2xl text-text-secondary">
          Preflop ranges and equity math you can see and check — no paywall, no account, nothing you enter leaves your device.
        </p>
      </section>

      <section className="rounded-sm border border-amber-900/60 bg-amber-950/30 p-4 text-sm text-amber-200">
        <p className="font-semibold">What this is — and isn't</p>
        <p className="mt-1">
          This is a <strong>preflop range and equity trainer</strong>, grounded in published charts and exact math.{' '}
          <strong>It does not compute postflop GTO solutions</strong> — that's a real, separate undertaking, and nothing here should be
          read as claiming it. See{' '}
          <a
            className="underline decoration-amber-700 underline-offset-2 transition-colors hover:text-amber-100"
            href="https://github.com/testtest126/poker/blob/main/ROADMAP.md"
            target="_blank"
            rel="noreferrer"
          >
            ROADMAP.md
          </a>{' '}
          for the full picture of what's built and what's next.
        </p>
      </section>

      <section className="grid gap-3 sm:grid-cols-2">
        {CARDS.map((card) => (
          <button
            key={card.page}
            type="button"
            onClick={() => onNavigate(card.page)}
            className="rounded-sm border border-hairline bg-surface p-5 text-left transition-colors hover:border-hairline-strong hover:bg-surface-raised"
          >
            <h2 className="text-lg font-semibold text-text-primary">{card.title}</h2>
            <p className="mt-1 text-sm text-text-secondary">{card.description}</p>
          </button>
        ))}
      </section>
    </div>
  )
}
