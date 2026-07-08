# Roadmap: PLBeast

## Milestones

- ✅ **v1.0 MVP** — Phases 1–6 + 5.1 (shipped 2026-07-01, released as v1.0.0 → v1.0.1)

Full detail archived at [milestones/v1.0-ROADMAP.md](./milestones/v1.0-ROADMAP.md).

## Phases

<details>
<summary>✅ v1.0 MVP (Phases 1–6 + 5.1) — SHIPPED 2026-07-01</summary>

- [x] Phase 1: Addon Scaffold (1/1 plan) — completed 2026-06-18
- [x] Phase 2: Rotation Tracking (1/1 plan) — completed 2026-06-29 (superseded by Phase 5.1)
- [x] Phase 3: Visibility Gating (1/1 plan) — completed 2026-06-19
- [x] Phase 4: Icon UI (2/2 plans) — completed 2026-06-21
- [x] Phase 5: Configuration (1/1 plan) — completed 2026-06-21
- [x] Phase 5.1: Event-Driven Rotation Tracking (1/1 plan, INSERTED) — completed 2026-06-29
- [x] Phase 6: Release Pipeline (1/1 plan) — completed 2026-06-29

Shipped v1.0.0 (2026-06-29), then v1.0.1 (2026-07-01) fixing the per-frame poll CPU
bug and restoring the wyvern default anchor + login/boss-pull reset. In-game UAT 7/7
on the v1.0.1 build.

</details>

- [x] **Phase 7: Text Display Mode** - Colored text labels as alternative to icon; mode toggle, font size, persistence (completed 2026-07-07)

### Phase 7: Text Display Mode

**Goal**: An alternative text-based display mode shows the predicted next beast as a colored text label instead of an icon texture, togglable from the options frame or slash command
**Depends on**: Phase 6
**Requirements**: TEXT-01, TEXT-02, TEXT-03, TEXT-04, TEXT-05, TEXT-06
**Success Criteria** (what must be TRUE):

  1. When text mode is enabled, the addon displays the beast name (Wyvern/Boar/Bear) as colored text instead of the icon texture
  2. Each beast has a distinct, easily readable color that is visually distinguishable at a glance
  3. The text updates in real-time as the rotation prediction changes (same PollPackLeader state machine)
  4. The user can toggle between icon mode and text mode via the options frame or `/plbeast text` command
  5. Text display settings (font size, enabled state) persist across sessions via SavedVariablesPerCharacter
  6. Text display respects the same visibility gating as icon mode (hidden when Pack Leader is not active)

**Plans:** 1/1 plans complete

Plans:

- [x] 07-01-PLAN.md — Text display infrastructure + toggle controls (FontString, colors, options, slash command)

## Progress

| Phase                       | Milestone | Plans Complete | Status   | Completed  |
| --------------------------- | --------- | -------------- | -------- | ---------- |
| 1. Addon Scaffold           | v1.0      | 1/1            | Complete | 2026-06-18 |
| 2. Rotation Tracking        | v1.0      | 1/1            | Complete | 2026-06-29 |
| 3. Visibility Gating        | v1.0      | 1/1            | Complete | 2026-06-19 |
| 4. Icon UI                  | v1.0      | 2/2            | Complete | 2026-06-21 |
| 5. Configuration            | v1.0      | 1/1            | Complete | 2026-06-21 |
| 5.1 Event-Driven Tracking   | v1.0      | 1/1            | Complete | 2026-06-29 |
| 6. Release Pipeline         | v1.0      | 1/1            | Complete | 2026-06-29 |
| 7. Text Display Mode        | —         | 1/1 | Complete    | 2026-07-07 |
