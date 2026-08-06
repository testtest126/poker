import type { ReactNode } from 'react'
import type { Page } from '../App'

const NAV_ITEMS: { page: Page; label: string }[] = [
  { page: 'home', label: 'Home' },
  { page: 'trainer', label: 'Trainer' },
  { page: 'equity', label: 'Equity Calculator' },
  { page: 'ranges', label: 'Preflop Ranges' },
  { page: 'icm', label: 'ICM Calculator' },
  { page: 'import', label: 'Import' },
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
    <div className="flex min-h-screen flex-col bg-canvas font-sans text-text-primary">
      <header className="border-b border-hairline bg-surface">
        <div className="mx-auto flex max-w-4xl flex-wrap items-center gap-x-8 gap-y-1 px-4">
          <button
            type="button"
            onClick={() => onNavigate('home')}
            className="flex items-center gap-2 py-3 text-[13px] font-semibold tracking-[0.08em] text-text-primary"
          >
            <span className="h-1.5 w-1.5 rounded-full bg-accent-bright" aria-hidden="true" />
            POKER STUDY
          </button>
          <nav className="flex flex-wrap gap-6 text-sm">
            {NAV_ITEMS.map((item) => (
              <button
                key={item.page}
                type="button"
                onClick={() => onNavigate(item.page)}
                className={`border-b-2 py-3 font-medium transition-colors ${
                  page === item.page
                    ? 'border-accent-bright text-text-primary'
                    : 'border-transparent text-text-secondary hover:text-text-primary'
                }`}
              >
                {item.label}
              </button>
            ))}
          </nav>
        </div>
      </header>

      <main className="mx-auto w-full max-w-4xl flex-1 px-4 py-6">{children}</main>

      <footer className="border-t border-hairline px-4 py-4 text-center text-xs text-text-tertiary">
        Free, open source, no account. A GTO-informed preflop/equity/ICM trainer — not a
        postflop solver, and not implying to be one. See{' '}
        <a className="underline transition-colors hover:text-text-secondary" href="https://github.com/testtest126/poker/blob/main/ROADMAP.md" target="_blank" rel="noreferrer">
          ROADMAP.md
        </a>
        .
      </footer>
    </div>
  )
}
