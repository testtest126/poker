# ai-docs

Per-subsystem docs for agents (and humans) working on Poker Study, written to
get oriented fast without re-deriving things from scratch. Each doc is
grounded in the actual code as of when it was written — if the code and a doc
disagree, trust the code and fix the doc.

Start with **[ARCHITECTURE.md](ARCHITECTURE.md)** for the big picture, then
drop into whichever subsystem you're touching:

| Doc | Covers |
| --- | --- |
| [ARCHITECTURE.md](ARCHITECTURE.md) | `PokerKit` vs `app` split, data flow (import → analyze → drill), SwiftData persistence |
| [RANGES.md](RANGES.md) | Chen-score hand strength, the push/fold shove table, `PushFoldRange`/`PushFoldSpot` |
| [HAND-HISTORY.md](HAND-HISTORY.md) | The PokerStars `.txt` parser: what's parsed, defensive skipping, known limitations |
| [LEAK-ANALYSIS.md](LEAK-ANALYSIS.md) | `LeakAnalysisEngine`: VPIP/PFR/limp, push-fold adherence, small-sample confidence gating |
| [DRILLS.md](DRILLS.md) | How "Practice Your Leaks" derives a `DrillFocus` from a leak report and weights spots |
| [PREFLOP-GRID.md](PREFLOP-GRID.md) | The 13×13 grid enumeration and range viewer |
| [BOUNTY.md](BOUNTY.md) | PKO bounty-adjusted shove ranges: the formula, its source, and what it doesn't model |
| [EQUITY.md](EQUITY.md) | `HandEvaluator`/`Equity`: exact + Monte Carlo win/tie/lose calculation, ground-truth validation, performance |
| [TESTING.md](TESTING.md) | Running `swift test` (the Xcode/`DEVELOPER_DIR` requirement) and what CI does |

See also **[AGENTS.md](../AGENTS.md)** (build/test/run, conventions, the
working agreement) and **[CLAUDE.md](../CLAUDE.md)** (this project's
non-negotiable working principles — off-table-only, privacy-first).
