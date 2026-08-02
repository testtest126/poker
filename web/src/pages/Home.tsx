import type { Page } from '../App'

export function Home({ onNavigate }: { onNavigate: (p: Page) => void }) {
  return (
    <div className="space-y-8">
      <section className="space-y-3">
        <h1 className="text-3xl font-bold tracking-tight sm:text-4xl">
          A free, open-source hold'em study tool
        </h1>
        <p className="max-w-2xl text-slate-600 dark:text-slate-400">
          Preflop ranges and equity math you can see and check — no paywall, no account,
          nothing you enter leaves your device.
        </p>
      </section>

      <section className="rounded-lg border border-amber-300 bg-amber-50 p-4 text-sm text-amber-900 dark:border-amber-800 dark:bg-amber-950 dark:text-amber-200">
        <p className="font-semibold">What this is — and isn't</p>
        <p className="mt-1">
          This is a <strong>preflop range and equity trainer</strong>, grounded in published
          charts and exact math. <strong>It does not compute postflop GTO solutions</strong> —
          that's a real, separate undertaking, and nothing here should be read as claiming
          it. See{' '}
          <a
            className="underline hover:text-amber-950 dark:hover:text-amber-100"
            href="https://github.com/testtest126/poker/blob/main/ROADMAP.md"
            target="_blank"
            rel="noreferrer"
          >
            ROADMAP.md
          </a>{' '}
          for the full picture of what's built and what's next.
        </p>
      </section>

      <section className="grid gap-4 sm:grid-cols-2">
        <button
          type="button"
          onClick={() => onNavigate('equity')}
          className="rounded-lg border border-slate-200 bg-white p-5 text-left shadow-sm transition-shadow hover:shadow-md dark:border-slate-800 dark:bg-slate-900"
        >
          <h2 className="text-lg font-semibold">Equity Calculator</h2>
          <p className="mt-1 text-sm text-slate-600 dark:text-slate-400">
            Win/tie/lose probability for any hand or hand class vs. another, on any board —
            exact math, not a rule of thumb.
          </p>
        </button>

        <button
          type="button"
          onClick={() => onNavigate('ranges')}
          className="rounded-lg border border-slate-200 bg-white p-5 text-left shadow-sm transition-shadow hover:shadow-md dark:border-slate-800 dark:bg-slate-900"
        >
          <h2 className="text-lg font-semibold">Preflop Ranges</h2>
          <p className="mt-1 text-sm text-slate-600 dark:text-slate-400">
            Push/fold and opening (raise-first-in) ranges by position and effective stack — a
            13×13 grid you can actually read.
          </p>
        </button>
      </section>
    </div>
  )
}
