import type { ReactNode } from 'react'
import type { Page } from '../App'

const NAV_ITEMS: { page: Page; label: string }[] = [
  { page: 'home', label: 'Home' },
  { page: 'equity', label: 'Equity Calculator' },
  { page: 'ranges', label: 'Preflop Ranges' },
  { page: 'icm', label: 'ICM Calculator' },
]

export function Layout({
  page,
  onNavigate,
  children,
}: {
  page: Page
  onNavigate: (p: Page) => void
  children: ReactNode
}) {
  return (
    <div className="flex min-h-screen flex-col bg-slate-50 text-slate-900 dark:bg-slate-950 dark:text-slate-100">
      <header className="border-b border-slate-200 dark:border-slate-800">
        <div className="mx-auto flex max-w-4xl flex-wrap items-center gap-x-6 gap-y-2 px-4 py-3">
          <button
            type="button"
            onClick={() => onNavigate('home')}
            className="text-lg font-semibold tracking-tight text-indigo-600 dark:text-indigo-400"
          >
            Poker Study
          </button>
          <nav className="flex flex-wrap gap-1">
            {NAV_ITEMS.map((item) => (
              <button
                key={item.page}
                type="button"
                onClick={() => onNavigate(item.page)}
                className={`rounded-md px-3 py-1.5 text-sm font-medium transition-colors ${
                  page === item.page
                    ? 'bg-indigo-600 text-white'
                    : 'text-slate-600 hover:bg-slate-200 dark:text-slate-300 dark:hover:bg-slate-800'
                }`}
              >
                {item.label}
              </button>
            ))}
          </nav>
        </div>
      </header>

      <main className="mx-auto w-full max-w-4xl flex-1 px-4 py-6">{children}</main>

      <footer className="border-t border-slate-200 px-4 py-4 text-center text-xs text-slate-500 dark:border-slate-800 dark:text-slate-500">
        Free, open source, no account. A GTO-informed preflop/equity/ICM trainer — not a
        postflop solver, and not implying to be one. See{' '}
        <a
          className="underline hover:text-indigo-600 dark:hover:text-indigo-400"
          href="https://github.com/testtest126/poker/blob/main/ROADMAP.md"
          target="_blank"
          rel="noreferrer"
        >
          ROADMAP.md
        </a>
        .
      </footer>
    </div>
  )
}
