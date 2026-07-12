# Poker Study — working principles

Lean, deliberately. This is a solo project; keep the rigor, skip the ceremony.

## 1. Off-table only, non-negotiable

This app is study/prep software, not a real-time assistant. It never reads live
table state, never runs during a hand, and is never an overlay. If a feature
idea only makes sense while a hand is in progress, it's the wrong feature —
reject it, don't compromise on it. Hand-history import operates on histories
from hands that have already finished.

## 2. Verify, don't assume

- `PokerKit` builds and tests green — from commit one, and every commit after.
- New domain logic (range parsing, ICM math, leak detection) gets a real test,
  not just a compile check. Poker math is easy to get subtly wrong; a bad ICM
  formula is worse than no ICM formula.

## 3. Privacy-first

Hand histories and stats are personal. On-device by default; no server, no
account, nothing phoned home. If a feature ever needs a server, that's a
deliberate decision to revisit this file for, not a default.

## 4. Process

Solo / small. Small focused commits over big ones. Branch for real changes,
keep `main` buildable at all times.
