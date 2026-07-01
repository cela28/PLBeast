# PLBeast — Retrospective

## Milestone: v1.0 — MVP

**Shipped:** 2026-07-01 (released v1.0.0 → v1.0.1)
**Phases:** 7 (1–6 + 5.1) | **Plans:** 8

### What Was Built
A standalone, minimal WoW addon that predicts the next Pack Leader beast (wyvern → boar → bear)
via CDM-frame reads, shown as a single draggable/scalable icon. Slash-command options window,
spec/talent visibility gating, SavedVariables persistence, and a tag-triggered GitHub Releases
pipeline. Detection was rebuilt in Phase 5.1 to a self-correcting, event-driven model.

### What Worked
- Strict dependency-ordered phases (scaffold → tracking → gating → UI → config → release) each
  produced a runnable increment.
- Static verification + human in-game UAT as the real gate for a runtime (WoW Lua) that can't be
  unit-tested locally.
- Publishing `main` as a curated subset (`PLBeast/` + `.github/`) kept dev-only planning files
  off the public branch and out of release zips.

### What Was Inefficient
- The Phase 5.1 perf refactor shipped a **latent CPU bug**: the OnUpdate throttle used a
  `GetTime() == last` equality guard that never fires (GetTime advances every frame), so the poll
  ran at framerate instead of 1Hz. It reached a public release (v1.0.0) before in-game CPU
  profiling caught it — fixed in v1.0.1.
- Root cause was a **false premise in research** ("GetTime() has 1-second resolution") that
  propagated unchallenged into the plan and code.

### Patterns Established
- WoW poll throttling must use an **elapsed-time threshold** (`now - last < INTERVAL`), never
  equality against `GetTime()`.
- A "match upstream addon exactly" goal needs to capture the *mechanism* (Azor's 1Hz came from its
  Scheduler `interval=1`, not from GetTime), not just the surface code.

### Key Lessons
- Verify performance claims empirically (in-game profiler) before shipping, not just by code read.
- When adopting another project's pattern, confirm which component actually enforces the behavior.
- Default/anchor decisions (boar vs wyvern) are domain calls — surface them to the player early.

### Cost Observations
- Model mix: opus (planning) + sonnet (execution) via GSD quick task.
- v1.0.1 turnaround: diagnosis → fix → in-game re-verify → release in a single session.

## Cross-Milestone Trends

_(First milestone — trends accrue from v1.1 onward.)_
