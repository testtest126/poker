# Poker Study — Web

The free, client-side web app. See the repo root's [ROADMAP.md](../ROADMAP.md)
for the vision and [../ai-docs/](../ai-docs/README.md) for how each tool
actually works.

## Stack

Vite + React + TypeScript + Tailwind CSS. Fully client-side — no server, no
account, nothing you enter leaves your device.

## Structure

- `src/engine/` — the domain logic (hand evaluation, equity, preflop
  ranges). A from-scratch TypeScript **port** of the same algorithms
  already validated in `../PokerKit` (Swift) — not a shared/compiled
  library, a faithful re-implementation with its own test suite checked
  against the same published ground-truth numbers. See each file's header
  comment for what it's ported from and any deliberate differences (e.g.
  `equity.ts` uses a different, faster PRNG than the Swift source — see its
  header comment for why that's fine).
- `src/engine/*.test.ts` — Vitest tests.
- `src/components/`, `src/App.tsx` — the UI.

## Local dev

```sh
npm install
npm run dev      # http://localhost:5173
npm test         # Vitest, engine tests
npm run build    # production build (tsc -b && vite build)
```
