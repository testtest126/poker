# CHECKLIST.md

<!--
  A definition of done: what to run through before calling any change complete.
  It's the discipline, not the tooling — the actual commands live in AGENTS.md.
-->

Before calling a change "done," go through this. Naming a skipped line beats
skipping it silently (principle 6).

- [ ] **Build** succeeds, if the project has one.
- [ ] **Tests** pass — the ones in `AGENTS.md`, plus any the change warranted.
- [ ] **Lint / format** is clean.
- [ ] **The real behavior was exercised** — run the feature, hit the endpoint,
      look at the screen. Tests passing is not proof it works (principle 1).
      For a bug fix, confirm the test *fails without the fix* first.
- [ ] **Edge cases the change touches** were considered, not just the happy path.
- [ ] **The diff was read**, not just written — does it do only what it claims?
      No debug prints, commented-out code, or unrelated changes left behind.
- [ ] **No secrets or personal data** crept into code, logs, commits, or fixtures.

If a box can't be checked, say which one and why. Don't call it done anyway.
